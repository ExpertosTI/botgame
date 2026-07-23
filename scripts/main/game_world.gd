extends Node3D

@onready var players_root: Node3D = $Players
@onready var objectives_root: Node3D = $Objectives
@onready var map_root: Node3D = $MapRoot
@onready var hud: CanvasLayer = $HUD
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

const BEAST_SCENE := preload("res://scenes/player/beast.tscn")
const EXPLORER_SCENE := preload("res://scenes/player/explorer.tscn")
const OBJECTIVE_SCENE := preload("res://scenes/objectives/beast_objective.tscn")
const MAP_BUILDER_SCRIPT := preload("res://scripts/maps/map_builder.gd")
const PRACTICE_AI_SCRIPT := preload("res://scripts/ai/practice_ai.gd")

var _builder: MapBuilder


func _ready() -> void:
	spawner.spawn_function = Callable(self, "_spawn_player_custom")

	GameManager.match_started.connect(_on_match_started)
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.objective_destroyed.connect(_on_objective_destroyed)
	GameManager.lives_changed.connect(_on_lives_changed)

	_builder = MAP_BUILDER_SCRIPT.new()
	map_root.add_child(_builder)
	await _builder.build(NetworkManager.selected_map, objectives_root)
	GameManager.current_map = NetworkManager.selected_map
	_builder.attach_systems(map_root, NetworkManager.selected_map)

	# Esperar un frame tras construir el mapa (Web GL Compatibility)
	await get_tree().process_frame

	if not multiplayer.has_multiplayer_peer():
		push_error("[GameWorld] Sin multiplayer peer — abortando partida")
		return

	if multiplayer.is_server():
		var roles := _build_roles()
		if NetworkManager.is_solo_practice:
			# Offline: sin RPC/Spawner (evita freeze con peers fantasma 9001+)
			_apply_match_setup(roles, GameManager.beast_variant, NetworkManager.selected_map)
			_spawn_objectives_local(_pack_objective_positions())
			_spawn_players_local()
			await get_tree().process_frame
			GameManager.start_match()
			if hud:
				hud.show_match_hud()
		else:
			_sync_match_setup.rpc(roles, GameManager.beast_variant, NetworkManager.selected_map)
			_spawn_objectives.rpc(_pack_objective_positions())
			_spawn_players_network()
			GameManager.start_match()
			_notify_match_started.rpc()


func _pack_objective_positions() -> Array:
	var packed: Array = []
	var need := GameManager.level_core_count if GameManager.level_core_count > 0 else GameManager.OBJECTIVES_TO_WIN
	var positions: Array = _builder.objective_positions.duplicate()
	var guard := 0
	while positions.size() < need and not positions.is_empty() and guard < 32:
		guard += 1
		positions.append(
			positions[positions.size() % _builder.objective_positions.size()]
			+ Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		)
	for i in mini(need, positions.size()):
		var pos: Vector3 = positions[i]
		packed.append([pos.x, pos.y, pos.z])
	return packed


func _spawn_player_custom(data: Variant) -> Node:
	return _make_player(data)


func _make_player(data: Variant) -> Node:
	var info: Dictionary = data
	var role: int = info.get("role", GameManager.Role.EXPLORER)
	var scene := BEAST_SCENE if role == GameManager.Role.BEAST else EXPLORER_SCENE
	var player := scene.instantiate()
	var pid := int(info.get("id", 0))
	player.name = str(pid)
	player.position = info.get("pos", Vector3.ZERO)
	var is_bot := NetworkManager.is_bot_peer(pid)
	if is_bot:
		player.set_meta("is_bot", true)
	if NetworkManager.is_solo_practice:
		player.set_multiplayer_authority(1)
	else:
		player.set_multiplayer_authority(pid if pid > 0 else 1)
	return player


func _apply_match_setup(roles: Dictionary, beast_variant: int, map_id: String) -> void:
	GameManager.beast_variant = beast_variant as GameManager.BeastVariant
	GameManager.current_map = map_id
	var normalized: Dictionary = {}
	for k in roles:
		normalized[int(k)] = int(roles[k]) as GameManager.Role
	GameManager.setup_match(normalized)


@rpc("authority", "call_local", "reliable")
func _sync_match_setup(roles: Dictionary, beast_variant: int, map_id: String) -> void:
	_apply_match_setup(roles, beast_variant, map_id)


func _spawn_objectives_local(positions: Array) -> void:
	for child in objectives_root.get_children():
		child.queue_free()
	var map_id := GameManager.current_map
	var i := 0
	for pos in positions:
		var obj := OBJECTIVE_SCENE.instantiate()
		obj.position = pos if pos is Vector3 else Vector3(pos[0], pos[1], pos[2])
		objectives_root.add_child(obj)
		if obj is BeastObjective:
			var v := ObjectiveVariants.for_map(map_id, i)
			(obj as BeastObjective).call_deferred("apply_variant", v)
		i += 1


@rpc("authority", "call_local", "reliable")
func _spawn_objectives(positions: Array) -> void:
	_spawn_objectives_local(positions)


@rpc("authority", "call_local", "reliable")
func _notify_match_started() -> void:
	if not GameManager.match_active:
		GameManager.start_match()
	if hud:
		hud.show_match_hud()


func _build_roles() -> Dictionary:
	var roles: Dictionary = {}
	for peer_id in NetworkManager.players:
		var role_str: String = NetworkManager.players[peer_id].get("role", "explorer")
		if role_str == "beast":
			roles[int(peer_id)] = GameManager.Role.BEAST
		else:
			roles[int(peer_id)] = GameManager.Role.EXPLORER
	if not roles.values().has(GameManager.Role.BEAST) and not roles.is_empty():
		var ids: Array = roles.keys()
		ids.sort()
		roles[int(ids[0])] = GameManager.Role.BEAST
	return roles


func _spawn_players_network() -> void:
	for peer_id in NetworkManager.players:
		var role := GameManager.get_role(int(peer_id))
		var pos := _get_spawn_position(role, int(peer_id))
		var data := {"id": int(peer_id), "role": role, "pos": pos}
		spawner.spawn(data)


func _spawn_players_local() -> void:
	## Práctica: instancia directa (sin MultiplayerSpawner).
	for peer_id in NetworkManager.players:
		var pid := int(peer_id)
		var role := GameManager.get_role(pid)
		var pos := _get_spawn_position(role, pid)
		var data := {"id": pid, "role": role, "pos": pos}
		var node := _make_player(data)
		players_root.add_child(node, true)
		if NetworkManager.is_bot_peer(pid):
			_attach_practice_ai(node, role == GameManager.Role.BEAST)


func _attach_practice_ai(player: Node, beast: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	var ai: PracticeAI = PRACTICE_AI_SCRIPT.new() as PracticeAI
	ai.name = "PracticeAI"
	player.add_child(ai)
	ai.setup(player as CharacterBody3D, beast)


func _get_spawn_position(role: GameManager.Role, peer_id: int) -> Vector3:
	if role == GameManager.Role.BEAST:
		var beast_spawns := get_tree().get_nodes_in_group("beast_spawn")
		if not beast_spawns.is_empty():
			return beast_spawns[0].global_position
		return Vector3(0, 1.2, -15)
	var spawns := get_tree().get_nodes_in_group("explorer_spawns")
	if spawns.is_empty():
		return Vector3(randf_range(-5, 5), 1.0, 15)
	var explorers: Array = []
	for pid in NetworkManager.players:
		if GameManager.get_role(int(pid)) != GameManager.Role.BEAST:
			explorers.append(int(pid))
	explorers.sort()
	var idx := explorers.find(peer_id)
	if idx < 0:
		idx = abs(peer_id) % spawns.size()
	return spawns[idx % spawns.size()].global_position


func _on_match_started() -> void:
	if hud:
		hud.show_match_hud()


func _on_match_ended(winner: String) -> void:
	if hud:
		hud.show_result(winner)


func _on_objective_destroyed(remaining: int) -> void:
	if hud:
		hud.update_objectives(remaining)


func _on_lives_changed(peer_id: int, lives: int) -> void:
	if hud:
		hud.update_lives(peer_id, lives)

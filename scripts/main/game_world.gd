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

var _builder: MapBuilder


func _ready() -> void:
	spawner.spawn_function = Callable(self, "_spawn_player_custom")
	# Con spawn_function custom no hace falta lista de escenas spawnable

	GameManager.match_started.connect(_on_match_started)
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.objective_destroyed.connect(_on_objective_destroyed)
	GameManager.lives_changed.connect(_on_lives_changed)

	_builder = MAP_BUILDER_SCRIPT.new()
	map_root.add_child(_builder)
	await _builder.build(NetworkManager.selected_map, objectives_root)
	GameManager.current_map = NetworkManager.selected_map

	if multiplayer.is_server():
		var roles := _build_roles()
		_sync_match_setup.rpc(roles, GameManager.beast_variant, NetworkManager.selected_map)
		var packed: Array = []
		for pos in _builder.objective_positions:
			packed.append([pos.x, pos.y, pos.z])
		_spawn_objectives.rpc(packed)
		_spawn_players()
		GameManager.start_match()
		_notify_match_started.rpc()


func _spawn_player_custom(data: Variant) -> Node:
	## data: { id, role }
	var info: Dictionary = data
	var role: int = info.get("role", GameManager.Role.EXPLORER)
	var scene := BEAST_SCENE if role == GameManager.Role.BEAST else EXPLORER_SCENE
	var player := scene.instantiate()
	player.name = str(info.get("id", 0))
	player.position = info.get("pos", Vector3.ZERO)
	player.set_multiplayer_authority(int(info.get("id", 1)))
	return player


@rpc("authority", "call_local", "reliable")
func _sync_match_setup(roles: Dictionary, beast_variant: int, map_id: String) -> void:
	GameManager.beast_variant = beast_variant as GameManager.BeastVariant
	GameManager.current_map = map_id
	# Convert keys to int (RPC may stringify)
	var normalized: Dictionary = {}
	for k in roles:
		normalized[int(k)] = int(roles[k]) as GameManager.Role
	GameManager.setup_match(normalized)


@rpc("authority", "call_local", "reliable")
func _spawn_objectives(positions: Array) -> void:
	for child in objectives_root.get_children():
		child.queue_free()
	for pos in positions:
		var obj := OBJECTIVE_SCENE.instantiate()
		obj.position = pos if pos is Vector3 else Vector3(pos[0], pos[1], pos[2])
		objectives_root.add_child(obj, true)


@rpc("authority", "call_local", "reliable")
func _notify_match_started() -> void:
	if not GameManager.match_active:
		GameManager.start_match()
	hud.show_match_hud()


func _build_roles() -> Dictionary:
	var roles: Dictionary = {}
	for peer_id in NetworkManager.players:
		var role_str: String = NetworkManager.players[peer_id].get("role", "explorer")
		if role_str == "beast":
			roles[peer_id] = GameManager.Role.BEAST
		else:
			roles[peer_id] = GameManager.Role.EXPLORER
	if not roles.values().has(GameManager.Role.BEAST) and not roles.is_empty():
		var ids := roles.keys()
		ids.sort()
		roles[ids[0]] = GameManager.Role.BEAST
	return roles


func _spawn_players() -> void:
	for peer_id in NetworkManager.players:
		var role := GameManager.get_role(peer_id)
		var pos := _get_spawn_position(role, peer_id)
		var data := {"id": peer_id, "role": role, "pos": pos}
		# spawn_function handles instantiation + replication
		spawner.spawn(data)


func _get_spawn_position(role: GameManager.Role, peer_id: int) -> Vector3:
	if role == GameManager.Role.BEAST:
		var beast_spawns := get_tree().get_nodes_in_group("beast_spawn")
		if not beast_spawns.is_empty():
			return beast_spawns[0].global_position
		return Vector3(0, 1.2, -15)
	var spawns := get_tree().get_nodes_in_group("explorer_spawns")
	if spawns.is_empty():
		return Vector3(randf_range(-5, 5), 1.0, 15)
	# Índice estable entre exploradores (no peer_id crudo)
	var explorers: Array = []
	for pid in NetworkManager.players:
		if GameManager.get_role(int(pid)) != GameManager.Role.BEAST:
			explorers.append(int(pid))
	explorers.sort()
	var idx := explorers.find(peer_id)
	if idx < 0:
		idx = peer_id % spawns.size()
	return spawns[idx % spawns.size()].global_position


func _on_match_started() -> void:
	hud.show_match_hud()


func _on_match_ended(winner: String) -> void:
	hud.show_result(winner)


func _on_objective_destroyed(remaining: int) -> void:
	hud.update_objectives(remaining)


func _on_lives_changed(peer_id: int, lives: int) -> void:
	hud.update_lives(peer_id, lives)

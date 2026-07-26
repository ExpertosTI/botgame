extends Node

## Lógica central de partida: vidas, objetivos y victoria.

signal match_started
signal match_ended(winner: String)  # "explorers" | "beast"
signal objective_destroyed(remaining: int)
signal explorer_eliminated(peer_id: int)
signal lives_changed(peer_id: int, lives: int)

enum Role { BEAST, EXPLORER }
enum BeastVariant { CLASSIC, MECHA, SHADOW }
enum ExplorerVariant { ROBOT_BLUE, ROBOT_PINK, ROBOT_GREEN, ROBOT_YELLOW }

const EXPLORER_LIVES := 2
const OBJECTIVES_TO_WIN := 5

var match_active := false
var match_timer := 0.0
var objectives_remaining := OBJECTIVES_TO_WIN
var explorer_lives: Dictionary = {}  # peer_id -> lives
var player_roles: Dictionary = {}    # peer_id -> Role
var beast_variant: BeastVariant = BeastVariant.MECHA
var explorer_variants: Dictionary = {}  # peer_id -> ExplorerVariant (color)
var explorer_loadouts: Dictionary = {}  # peer_id -> loadout id (armas)
var explorer_characters: Dictionary = {}  # peer_id -> CharacterCatalog index
var easy_beast_mode := false
var current_map: String = "lab_neon"
## Overrides de campaña (ProgressionManager.apply_level_rules)
var level_core_count := OBJECTIVES_TO_WIN
var level_match_time := -1.0
var level_beast_hp_mult := 1.0
## Si el host envió reglas de nivel en el start match
var level_rules_locked := false

var _explorer_variant_list := [
	ExplorerVariant.ROBOT_BLUE,
	ExplorerVariant.ROBOT_PINK,
	ExplorerVariant.ROBOT_GREEN,
	ExplorerVariant.ROBOT_YELLOW,
]
var _timer_sync_accum := 0.0


func _process(delta: float) -> void:
	if not match_active:
		return
	# Solo el servidor (o solo/práctica) cuenta el tiempo
	if not NetworkManager.is_match_authority():
		return
	match_timer -= delta
	_timer_sync_accum += delta
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		if _timer_sync_accum >= 0.5:
			_timer_sync_accum = 0.0
			_sync_timer.rpc(match_timer)
	elif _timer_sync_accum >= 0.5:
		_timer_sync_accum = 0.0
	if match_timer <= 0.0:
		## Si el último núcleo cayó en el mismo tick, ganan los robots.
		if objectives_remaining <= 0:
			end_match("explorers")
		else:
			end_match("beast")


@rpc("authority", "call_remote", "unreliable")
func _sync_timer(remaining: float) -> void:
	match_timer = remaining


func setup_match(roles: Dictionary) -> void:
	if not level_rules_locked:
		ProgressionManager.apply_level_rules()
	player_roles = roles
	explorer_lives.clear()
	explorer_variants.clear()
	explorer_loadouts.clear()
	explorer_characters.clear()
	objectives_remaining = level_core_count if level_core_count > 0 else OBJECTIVES_TO_WIN
	var match_time := 240.0
	if NetworkManager.config:
		match_time = float(NetworkManager.config.match_time_seconds)
	# easy_beast_mode ya viene sincronizado desde el lobby
	if level_match_time > 0.0:
		match_time = level_match_time
	match_timer = match_time
	match_active = false
	_timer_sync_accum = 0.0
	level_rules_locked = false

	var variant_idx := 0
	for peer_id in roles:
		if roles[peer_id] == Role.EXPLORER:
			explorer_lives[peer_id] = EXPLORER_LIVES
			var info: Dictionary = NetworkManager.players.get(peer_id, {})
			var skin: int = int(info.get("skin", variant_idx))
			var loadout: int = int(info.get("loadout", 0))
			explorer_characters[peer_id] = skin
			# Mantener variante color 0-3 para tint de cápsula
			explorer_variants[peer_id] = _explorer_variant_list[clampi(skin % 4, 0, 3)]
			explorer_loadouts[peer_id] = clampi(loadout, 0, 3)
			variant_idx += 1


func start_match() -> void:
	match_active = true
	_timer_sync_accum = 0.0
	MatchStats.begin_match()
	AudioDirector.start_match_music()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_sync_timer.rpc(match_timer)
	match_started.emit()


func get_role(peer_id: int) -> Role:
	return player_roles.get(peer_id, Role.EXPLORER)


func is_beast(peer_id: int) -> bool:
	return get_role(peer_id) == Role.BEAST


func register_objective_destroyed() -> void:
	if not match_active:
		return
	if not NetworkManager.is_match_authority():
		return
	objectives_remaining -= 1
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_sync_objectives.rpc(objectives_remaining)
	else:
		_sync_objectives(objectives_remaining)
	if objectives_remaining <= 0:
		end_match("explorers")


@rpc("authority", "call_local", "reliable")
func _sync_objectives(remaining: int) -> void:
	objectives_remaining = remaining
	objective_destroyed.emit(remaining)


func damage_explorer(peer_id: int) -> void:
	if not match_active or not explorer_lives.has(peer_id):
		return
	if not NetworkManager.is_match_authority():
		return
	explorer_lives[peer_id] -= 1
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_sync_lives.rpc(peer_id, explorer_lives[peer_id])
	else:
		_sync_lives(peer_id, explorer_lives[peer_id])
	if explorer_lives[peer_id] <= 0:
		explorer_eliminated.emit(peer_id)
		_check_beast_victory()


@rpc("authority", "call_local", "reliable")
func _sync_lives(peer_id: int, lives: int) -> void:
	explorer_lives[peer_id] = lives
	lives_changed.emit(peer_id, lives)


func _check_beast_victory() -> void:
	for peer_id in explorer_lives:
		if explorer_lives[peer_id] > 0:
			return
	end_match("beast")


func handle_peer_left(peer_id: int) -> void:
	## Abandono mid-match: sin esto la Bestia ausente dejaba la partida colgada
	## y un robot desconectado seguía contando como vivo.
	if not match_active:
		return
	if not NetworkManager.is_match_authority():
		return
	var role = player_roles.get(peer_id, null)
	if role == null:
		role = player_roles.get(str(peer_id), null)
	if role == Role.BEAST:
		end_match("explorers")
		return
	if role == Role.EXPLORER:
		if explorer_lives.has(peer_id):
			explorer_lives[peer_id] = 0
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
				_sync_lives.rpc(peer_id, 0)
			else:
				_sync_lives(peer_id, 0)
			lives_changed.emit(peer_id, 0)
			explorer_eliminated.emit(peer_id)
			_despawn_explorer_body(peer_id)
		_check_beast_victory()


func _despawn_explorer_body(peer_id: int) -> void:
	## Sin esto el robot desconectado sigue sólido y los bots lo cazan.
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_despawn_explorer_rpc.rpc(peer_id)
	else:
		_despawn_explorer_rpc(peer_id)


@rpc("authority", "call_local", "reliable")
func _despawn_explorer_rpc(peer_id: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("player_characters"):
		if n is ExplorerPlayer and (n as ExplorerPlayer).peer_id == peer_id:
			(n as ExplorerPlayer).force_eliminate()


func end_match(winner: String) -> void:
	if not match_active:
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_end_match_rpc.rpc(winner)
	elif NetworkManager.is_match_authority():
		_apply_end_match(winner)


@rpc("authority", "call_local", "reliable")
func _end_match_rpc(winner: String) -> void:
	_apply_end_match(winner)


func _apply_end_match(winner: String) -> void:
	if not match_active:
		return
	match_active = false
	# Sin esto, los proyectiles y destellos en vuelo sobreviven al cambio de
	# escena y aparecen flotando en el menú.
	FxPool.release_all()
	AudioDirector.set_walking(false)
	MatchStats.end_match(winner)
	ProgressionManager.on_match_ended(winner, current_map)
	AudioDirector.play_win(winner == "explorers")
	AudioDirector.start_menu_music()
	match_ended.emit(winner)


## Salir a menú / conexión perdida: no cuenta victoria ni avanza campaña.
func abort_match() -> void:
	if not match_active:
		FxPool.release_all()
		AudioDirector.set_walking(false)
		return
	match_active = false
	FxPool.release_all()
	AudioDirector.set_walking(false)
	MatchStats.reset()
	AudioDirector.start_menu_music()


func get_remaining_time() -> float:
	return maxf(match_timer, 0.0)


func get_beast_variant_name() -> String:
	match beast_variant:
		BeastVariant.CLASSIC: return "Bestia Clásica"
		BeastVariant.MECHA: return "Mecha Destructor"
		BeastVariant.SHADOW: return "Sombra Digital"
	return "Bestia"


func get_explorer_color(variant: ExplorerVariant) -> Color:
	match variant:
		ExplorerVariant.ROBOT_BLUE: return Color(0.25, 0.55, 1.0)
		ExplorerVariant.ROBOT_PINK: return Color(1.0, 0.4, 0.7)
		ExplorerVariant.ROBOT_GREEN: return Color(0.25, 0.85, 0.45)
		ExplorerVariant.ROBOT_YELLOW: return Color(1.0, 0.85, 0.2)
	return Color.WHITE


func get_beast_colors() -> Dictionary:
	## body, visor, accent
	match beast_variant:
		BeastVariant.CLASSIC:
			return {"body": Color(0.75, 0.12, 0.15), "visor": Color(0.95, 0.2, 0.15), "accent": Color(0.4, 0.05, 0.05)}
		BeastVariant.MECHA:
			return {"body": Color(0.28, 0.3, 0.35), "visor": Color(1.0, 0.15, 0.2), "accent": Color(0.9, 0.5, 0.1)}
		BeastVariant.SHADOW:
			return {"body": Color(0.18, 0.1, 0.28), "visor": Color(0.7, 0.2, 1.0), "accent": Color(0.4, 0.0, 0.6)}
	return {"body": Color.DARK_RED, "visor": Color.RED, "accent": Color.BLACK}

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
var explorer_variants: Dictionary = {}  # peer_id -> ExplorerVariant
var easy_beast_mode := false
var current_map: String = "lab_neon"

var _explorer_variant_list := [
	ExplorerVariant.ROBOT_BLUE,
	ExplorerVariant.ROBOT_PINK,
	ExplorerVariant.ROBOT_GREEN,
	ExplorerVariant.ROBOT_YELLOW,
]


func _process(delta: float) -> void:
	if not match_active:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	match_timer -= delta
	if match_timer <= 0.0:
		end_match("beast")


func setup_match(roles: Dictionary) -> void:
	player_roles = roles
	explorer_lives.clear()
	explorer_variants.clear()
	objectives_remaining = OBJECTIVES_TO_WIN
	var match_time := 240.0
	if NetworkManager.config:
		match_time = float(NetworkManager.config.match_time_seconds)
		easy_beast_mode = NetworkManager.config.easy_beast_mode
	match_timer = match_time
	match_active = false

	var variant_idx := 0
	for peer_id in roles:
		if roles[peer_id] == Role.EXPLORER:
			explorer_lives[peer_id] = EXPLORER_LIVES
			explorer_variants[peer_id] = _explorer_variant_list[variant_idx % _explorer_variant_list.size()]
			variant_idx += 1


func start_match() -> void:
	match_active = true
	match_started.emit()


func get_role(peer_id: int) -> Role:
	return player_roles.get(peer_id, Role.EXPLORER)


func is_beast(peer_id: int) -> bool:
	return get_role(peer_id) == Role.BEAST


func register_objective_destroyed() -> void:
	if not match_active:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	objectives_remaining -= 1
	_sync_objectives.rpc(objectives_remaining)
	if objectives_remaining <= 0:
		end_match("explorers")


@rpc("authority", "call_local", "reliable")
func _sync_objectives(remaining: int) -> void:
	objectives_remaining = remaining
	objective_destroyed.emit(remaining)


func damage_explorer(peer_id: int) -> void:
	if not match_active or not explorer_lives.has(peer_id):
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	explorer_lives[peer_id] -= 1
	_sync_lives.rpc(peer_id, explorer_lives[peer_id])
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


func end_match(winner: String) -> void:
	if not match_active:
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_end_match_rpc.rpc(winner)
	else:
		_apply_end_match(winner)


@rpc("authority", "call_local", "reliable")
func _end_match_rpc(winner: String) -> void:
	_apply_end_match(winner)


func _apply_end_match(winner: String) -> void:
	if not match_active:
		return
	match_active = false
	match_ended.emit(winner)


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

extends Control

@onready var player_list: VBoxContainer = $VBox/PlayerList
@onready var ready_button: Button = $VBox/ReadyButton
@onready var start_button: Button = $VBox/StartButton
@onready var role_beast_button: Button = $VBox/RoleRow/BeastRoleButton
@onready var role_robot_button: Button = $VBox/RoleRow/RobotRoleButton
@onready var beast_variant_option: OptionButton = $VBox/BeastVariantOption
@onready var map_option: OptionButton = $VBox/MapOption
@onready var status_label: Label = $VBox/StatusLabel
@onready var easy_check: CheckBox = $VBox/EasyBeastCheck

const GAME_SCENE := "res://scenes/main/game.tscn"

var local_ready := false


func _ready() -> void:
	ready_button.pressed.connect(_on_ready_pressed)
	start_button.pressed.connect(_on_start_pressed)
	role_beast_button.pressed.connect(_on_pick_beast)
	role_robot_button.pressed.connect(_on_pick_robot)
	easy_check.toggled.connect(_on_easy_toggled)

	NetworkManager.players_updated.connect(_refresh_player_list)
	NetworkManager.player_connected.connect(func(_a, _b): _refresh_player_list())
	NetworkManager.player_disconnected.connect(func(_a): _refresh_player_list())
	NetworkManager.lobby_settings_changed.connect(_on_settings_changed)
	NetworkManager.match_start_requested.connect(_on_match_start)

	_setup_options()
	_refresh_player_list()
	# Servidor dedicado: permanece en lobby vacío hasta que haya jugadores
	if NetworkManager.is_dedicated_server:
		status_label.text = "Servidor dedicado activo — esperando jugadores"
		ready_button.visible = false
		role_beast_button.visible = false
		role_robot_button.visible = false


func _setup_options() -> void:
	beast_variant_option.clear()
	beast_variant_option.add_item("Mecha Destructor", GameManager.BeastVariant.MECHA)
	beast_variant_option.add_item("Bestia Clásica", GameManager.BeastVariant.CLASSIC)
	beast_variant_option.add_item("Sombra Digital", GameManager.BeastVariant.SHADOW)
	beast_variant_option.item_selected.connect(_on_beast_variant_selected)

	map_option.clear()
	for map_id in NetworkManager.MAP_IDS:
		map_option.add_item(NetworkManager.MAP_NAMES[map_id])
	map_option.item_selected.connect(_on_map_selected)

	easy_check.button_pressed = GameManager.easy_beast_mode


func _on_beast_variant_selected(index: int) -> void:
	var variant := beast_variant_option.get_item_id(index)
	NetworkManager.set_beast_variant.rpc(variant)


func _on_map_selected(index: int) -> void:
	var map_id: String = NetworkManager.MAP_IDS[index]
	NetworkManager.set_selected_map.rpc(map_id)


func _on_easy_toggled(on: bool) -> void:
	GameManager.easy_beast_mode = on
	if NetworkManager.config:
		NetworkManager.config.easy_beast_mode = on


func _on_pick_beast() -> void:
	NetworkManager.set_player_role.rpc(multiplayer.get_unique_id(), "beast")


func _on_pick_robot() -> void:
	NetworkManager.set_player_role.rpc(multiplayer.get_unique_id(), "explorer")


func _on_ready_pressed() -> void:
	local_ready = not local_ready
	ready_button.text = "¡Listo!" if local_ready else "Marcar listo"
	NetworkManager.set_player_ready.rpc(multiplayer.get_unique_id(), local_ready)
	_check_can_start()


func _on_start_pressed() -> void:
	if NetworkManager.get_player_count() < 2:
		status_label.text = "Se necesitan al menos 2 jugadores"
		return
	if not NetworkManager.all_players_ready():
		status_label.text = "Todos deben estar listos"
		return
	if not NetworkManager.has_exactly_one_beast():
		status_label.text = "Debe haber exactamente 1 Bestia"
		return
	NetworkManager.request_start_match.rpc_id(1)


func _on_match_start(_map_id: String) -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_changed() -> void:
	var map_idx := NetworkManager.MAP_IDS.find(NetworkManager.selected_map)
	if map_idx >= 0 and map_option.selected != map_idx:
		map_option.select(map_idx)
	_refresh_player_list()


func _refresh_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for peer_id in NetworkManager.players:
		var info: Dictionary = NetworkManager.players[peer_id]
		var label := Label.new()
		var role_raw: String = info.get("role", "")
		var role := "Bestia" if role_raw == "beast" else ("Robot" if role_raw == "explorer" else "Sin rol")
		var ready_text := " [LISTO]" if info.get("ready", false) else ""
		label.text = "%s — %s%s" % [info.get("name", "?"), role, ready_text]
		player_list.add_child(label)
	_check_can_start()


func _check_can_start() -> void:
	if NetworkManager.is_dedicated_server:
		return
	var count := NetworkManager.get_player_count()
	var ok := count >= 2 and NetworkManager.all_players_ready() and NetworkManager.has_exactly_one_beast()
	start_button.disabled = not ok
	status_label.text = "%d jugadores | listos %d | mapa: %s" % [
		count, _count_ready(), NetworkManager.MAP_NAMES.get(NetworkManager.selected_map, "?")
	]


func _count_ready() -> int:
	var n := 0
	for info in NetworkManager.players.values():
		if info.get("ready", false):
			n += 1
	return n

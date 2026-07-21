extends Control

@onready var player_list: VBoxContainer = %PlayerList
@onready var ready_button: Button = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var role_beast_button: Button = %BeastRoleButton
@onready var role_robot_button: Button = %RobotRoleButton
@onready var beast_variant_option: OptionButton = %BeastVariantOption
@onready var map_option: OptionButton = %MapOption
@onready var status_label: Label = %StatusLabel
@onready var easy_check: CheckBox = %EasyBeastCheck
@onready var title: Label = %Title
@onready var wait_label: Label = %WaitLabel
@onready var atmosphere: ColorRect = %Atmosphere
@onready var map_hint: Label = %MapHint

const GAME_SCENE := "res://scenes/main/game.tscn"

var local_ready := false
var _pulse_t := 0.0


func _ready() -> void:
	GameTheme.apply(self)
	_style_ui()
	_setup_atmosphere()

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
	if NetworkManager.is_dedicated_server:
		status_label.text = "Servidor dedicado — esperando tripulación"
		ready_button.visible = false
		role_beast_button.visible = false
		role_robot_button.visible = false


func _style_ui() -> void:
	GameTheme.style_title(title, 36)
	GameTheme.style_muted(wait_label, 15)
	GameTheme.style_danger(role_beast_button)
	GameTheme.style_primary(role_robot_button)
	GameTheme.style_primary(start_button)
	role_beast_button.text = "SOY LA BESTIA"
	role_robot_button.text = "SOY ROBOT"
	ready_button.text = "MARCAR LISTO"
	start_button.text = "EMPEZAR PARTIDA"
	map_hint.add_theme_color_override("font_color", GameTheme.C_MUTED)


func _setup_atmosphere() -> void:
	if OS.has_feature("web") or OS.get_name() == "Web":
		atmosphere.color = Color(0.04, 0.07, 0.1, 1)
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ui_atmosphere.gdshader")
	atmosphere.material = mat


func _process(delta: float) -> void:
	_pulse_t += delta
	var pulse := 0.65 + 0.35 * sin(_pulse_t * 2.4)
	wait_label.modulate.a = pulse
	var dots := int(_pulse_t * 2.0) % 4
	wait_label.text = "Esperando tripulación" + ".".repeat(dots)


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
	_update_map_hint()


func _update_map_hint() -> void:
	var mid: String = NetworkManager.selected_map
	match mid:
		"containers":
			map_hint.text = "Ciudad de contenedores — pasillos estrechos, emboscadas."
		"ruins":
			map_hint.text = "Ruinas del núcleo — plataforma elevada, combate vertical."
		_:
			map_hint.text = "Laboratorio neon — arena abierta, luces frías."


func _on_beast_variant_selected(index: int) -> void:
	NetworkManager.set_beast_variant.rpc(beast_variant_option.get_item_id(index))


func _on_map_selected(index: int) -> void:
	NetworkManager.set_selected_map.rpc(NetworkManager.MAP_IDS[index])
	_update_map_hint()


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
	ready_button.text = "¡LISTO!" if local_ready else "MARCAR LISTO"
	if local_ready:
		GameTheme.style_primary(ready_button)
	else:
		ready_button.remove_theme_stylebox_override("normal")
		ready_button.remove_theme_stylebox_override("hover")
		ready_button.remove_theme_stylebox_override("pressed")
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
	_update_map_hint()
	_refresh_player_list()


func _refresh_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for peer_id in NetworkManager.players:
		var info: Dictionary = NetworkManager.players[peer_id]
		var card := GameTheme.make_player_card(
			str(info.get("name", "?")),
			str(info.get("role", "")),
			bool(info.get("ready", false))
		)
		player_list.add_child(card)
	_check_can_start()


func _check_can_start() -> void:
	if NetworkManager.is_dedicated_server:
		return
	var count := NetworkManager.get_player_count()
	var ok := count >= 2 and NetworkManager.all_players_ready() and NetworkManager.has_exactly_one_beast()
	start_button.disabled = not ok
	var ready_n := _count_ready()
	status_label.text = "%d / %d en sala  ·  %d listos  ·  mapa: %s" % [
		count, NetworkManager.config.max_players if NetworkManager.config else 5,
		ready_n, NetworkManager.MAP_NAMES.get(NetworkManager.selected_map, "?")
	]
	if ok:
		status_label.add_theme_color_override("font_color", GameTheme.C_CYAN)
		status_label.text += "  ·  ¡pueden despegar!"
	else:
		status_label.add_theme_color_override("font_color", GameTheme.C_AMBER)


func _count_ready() -> int:
	var n := 0
	for info in NetworkManager.players.values():
		if info.get("ready", false):
			n += 1
	return n

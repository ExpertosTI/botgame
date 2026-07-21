extends Control

@onready var join_button: Button = %JoinButton
@onready var host_button: Button = %HostButton
@onready var name_input: LineEdit = %NameInput
@onready var address_input: LineEdit = %AddressInput
@onready var status_label: Label = %StatusLabel
@onready var title_label: Label = %TitleLabel
@onready var subtitle: Label = %Subtitle
@onready var stage_root: Node3D = %StageRoot
@onready var atmosphere: ColorRect = %Atmosphere
@onready var online_mode_button: Button = %OnlineModeButton
@onready var solo_mode_button: Button = %SoloModeButton
@onready var online_panel: Control = %OnlinePanel
@onready var solo_panel: Control = %SoloPanel
@onready var solo_name_input: LineEdit = %SoloNameInput
@onready var solo_start_button: Button = %SoloStartButton
@onready var solo_hint: Label = %SoloHint
@onready var mute_check: CheckBox = %MuteCheck
@onready var credits_button: Button = %CreditsButton
@onready var legal_label: Label = %LegalLabel

const LOBBY_SCENE := "res://scenes/main/lobby.tscn"
const CREW_SCRIPT := preload("res://scripts/player/crew_visual.gd")
const BG_SHADER := preload("res://shaders/ui_mobile_bg.gdshader")

var _spin_nodes: Array[Node3D] = []
var _hero: TextureRect
var _chip_nodes: Array[Control] = []
var _anim_t := 0.0
var _mobile := false
var _mode := "online"


func _ready() -> void:
	if NetworkManager.is_dedicated_server:
		get_tree().change_scene_to_file("res://scenes/main/server_main.tscn")
		return

	_mobile = _is_mobile_layout()
	GameTheme.apply(self)
	_style_ui()
	_setup_atmosphere()
	_spawn_showcase()
	_start_ui_motion()
	call_deferred("_adapt_layout")

	join_button.pressed.connect(_on_join_pressed)
	host_button.pressed.connect(_on_host_pressed)
	online_mode_button.pressed.connect(_set_mode.bind("online"))
	solo_mode_button.pressed.connect(_set_mode.bind("solo"))
	solo_start_button.pressed.connect(_on_solo_start_pressed)
	mute_check.toggled.connect(_on_mute_toggled)
	credits_button.pressed.connect(_on_credits_pressed)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_started.connect(_on_server_started)

	name_input.text = SettingsManager.preferred_name if SettingsManager.preferred_name else "Robot"
	solo_name_input.text = name_input.text
	address_input.text = NetworkManager.get_default_server_url()
	address_input.placeholder_text = "wss://botgame.renace.tech/ws"
	mute_check.button_pressed = SettingsManager.muted
	legal_label.text = "%s · v%s" % [GameBrand.copyright_line(), GameBrand.VERSION]
	title_label.text = GameBrand.GAME_TITLE
	_set_mode("online")


func _is_mobile_layout() -> bool:
	if OS.has_feature("mobile"):
		return true
	var sz := get_viewport().get_visible_rect().size
	return sz.x < 820 or sz.y > sz.x


func _style_ui() -> void:
	var title_size := 40 if _mobile else 46
	GameTheme.style_title(title_label, title_size)
	GameTheme.style_muted(subtitle, 16 if _mobile else 17)
	GameTheme.style_primary(join_button)
	GameTheme.style_primary(solo_start_button)
	join_button.text = "▶  ENTRAR ONLINE"
	host_button.text = "Sala local (LAN)"
	solo_start_button.text = "▶  EMPEZAR PRÁCTICA"
	online_mode_button.text = "🌐  ONLINE"
	solo_mode_button.text = "🎯  CAMPAÑA"
	status_label.add_theme_color_override("font_color", GameTheme.C_AMBER)
	join_button.custom_minimum_size = Vector2(0, 72 if _mobile else 52)
	join_button.add_theme_font_size_override("font_size", 26 if _mobile else 22)
	solo_start_button.custom_minimum_size = Vector2(0, 72 if _mobile else 52)
	solo_start_button.add_theme_font_size_override("font_size", 26 if _mobile else 22)
	name_input.custom_minimum_size = Vector2(0, 58 if _mobile else 44)
	name_input.add_theme_font_size_override("font_size", 20 if _mobile else 16)
	solo_name_input.custom_minimum_size = Vector2(0, 58 if _mobile else 44)
	address_input.custom_minimum_size = Vector2(0, 52 if _mobile else 44)
	GameTheme.style_muted(solo_hint, 15)
	GameTheme.style_muted(legal_label, 12)
	credits_button.text = "ℹ  Créditos · legal · privacidad"
	if _mobile:
		host_button.visible = false
		var addr_label := online_panel.get_node_or_null("AddrLabel") as Control
		if addr_label:
			addr_label.visible = false
		address_input.visible = false


func _set_mode(mode: String) -> void:
	_mode = mode
	var online := mode == "online"
	online_panel.visible = online
	solo_panel.visible = not online
	if online:
		GameTheme.style_primary(online_mode_button)
		solo_mode_button.remove_theme_stylebox_override("normal")
		solo_mode_button.remove_theme_stylebox_override("hover")
		solo_mode_button.remove_theme_stylebox_override("pressed")
		subtitle.text = "Multijugador · 1 Bestia vs 1–3 Robots · VPS o LAN"
		status_label.text = ""
	else:
		GameTheme.style_primary(solo_mode_button)
		online_mode_button.remove_theme_stylebox_override("normal")
		online_mode_button.remove_theme_stylebox_override("hover")
		online_mode_button.remove_theme_stylebox_override("pressed")
		subtitle.text = "Campaña solitaria · bots · desbloqueos reales"
		var lv := ProgressionManager.level_name()
		status_label.text = "%s · victorias %d" % [lv, ProgressionManager.wins_total]
		solo_hint.text = "Elige rol en el hangar y practica el nivel actual contra bots.\n%s · núcleos y tiempo del nivel." % lv


func _setup_atmosphere() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	atmosphere.material = mat


func _spawn_showcase() -> void:
	var stage_wrap := get_node_or_null("Main/Col/StageWrap") as Control
	if OS.has_feature("web") or OS.get_name() == "Web" or stage_root == null:
		if stage_wrap:
			_fill_web_stage(stage_wrap)
		return

	var robot: Node3D = CREW_SCRIPT.new()
	robot.is_beast = false
	robot.position = Vector3(-1.15, 0, 0)
	stage_root.add_child(robot)
	robot.apply_colors(Color(0.15, 0.75, 0.85), Color(0.7, 0.95, 1.0), Color(0.1, 0.35, 0.4))
	robot.set_player_name("ROBOT")

	var beast: Node3D = CREW_SCRIPT.new()
	beast.is_beast = true
	beast.body_scale = 1.05
	beast.position = Vector3(1.25, 0, 0.2)
	stage_root.add_child(beast)
	beast.apply_colors(Color(0.55, 0.08, 0.12), Color(1.0, 0.35, 0.2), Color(0.9, 0.55, 0.1))
	beast.set_player_name("BESTIA")
	_spin_nodes = [robot, beast]


func _fill_web_stage(stage_wrap: Control) -> void:
	var cap := stage_wrap.get_node_or_null("VBox/StageCaption") as Label
	if cap:
		cap.visible = not _mobile
		cap.text = "BESTIA VS ROBOTS"
	var view := stage_wrap.get_node_or_null("VBox/StageView") as Control
	if view:
		view.visible = false
	var vbox := stage_wrap.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return

	_hero = TextureRect.new()
	_hero.texture = UiIcons.tex(UiIcons.MENU_HERO)
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero.custom_minimum_size = Vector2(0, 260 if _mobile else 240)
	_hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.clip_contents = true
	vbox.add_child(_hero)

	_hero.pivot_offset = Vector2(180, 120)
	var ken := create_tween().set_loops()
	ken.tween_property(_hero, "scale", Vector2(1.05, 1.05), 3.2).set_trans(Tween.TRANS_SINE)
	ken.tween_property(_hero, "scale", Vector2.ONE, 3.2).set_trans(Tween.TRANS_SINE)

	var grid := GridContainer.new() if _mobile else null
	var row: Container
	if _mobile:
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(grid)
		row = grid
	else:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 8)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(h)
		row = h

	for item in [
		[UiIcons.skin_tex(0), "Robot", GameTheme.C_CYAN],
		[UiIcons.beast_tex(GameManager.BeastVariant.CLASSIC), "Bestia", GameTheme.C_CRIMSON],
		[UiIcons.loadout_tex(0), "Arsenal", Color(1.0, 0.75, 0.2)],
		[UiIcons.map_tex("lab_neon"), "Mapas", Color(0.45, 0.7, 1.0)],
	]:
		var chip := _make_chip(item[0], item[1], item[2])
		row.add_child(chip)
		_chip_nodes.append(chip)

	var tip := Label.new()
	tip.text = "Online · o Campaña solitaria vs bots"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 16 if _mobile else 15)
	tip.add_theme_color_override("font_color", GameTheme.C_MUTED)
	vbox.add_child(tip)


func _make_chip(tex: Texture2D, label: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	if _mobile:
		chip.custom_minimum_size = Vector2(0, 128)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		chip.custom_minimum_size = Vector2(90, 100)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override(
		"panel",
		GameTheme.panel_style(Color(0.05, 0.08, 0.1, 0.95), accent.darkened(0.15), 12, 2)
	)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	chip.add_child(col)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.custom_minimum_size = Vector2(72 if _mobile else 56, 64 if _mobile else 48)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tr)
	var lb := Label.new()
	lb.text = label
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 16 if _mobile else 12)
	lb.add_theme_color_override("font_color", GameTheme.C_TEXT)
	col.add_child(lb)
	return chip


func _start_ui_motion() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(join_button, "modulate", Color(0.85, 1.0, 0.95), 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(join_button, "modulate", Color.WHITE, 0.85).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_anim_t += delta
	for i in _spin_nodes.size():
		var n := _spin_nodes[i]
		if is_instance_valid(n):
			n.rotate_y(delta * (0.55 if i == 0 else -0.4))
	for i in _chip_nodes.size():
		var c := _chip_nodes[i]
		if is_instance_valid(c):
			var a := 0.88 + 0.12 * sin(_anim_t * 2.0 + i)
			c.modulate = Color(a, a, a, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_adapt_layout()


func _adapt_layout() -> void:
	_mobile = _is_mobile_layout()
	var stage := get_node_or_null("Main/Col/StageWrap") as Control
	var form := get_node_or_null("Main/Col/FormWrap") as Control
	var col := get_node_or_null("Main/Col") as VBoxContainer
	if col == null:
		return
	if _mobile:
		if form and col.get_child(0) != form:
			col.move_child(form, 0)
	else:
		if stage and col.get_child(0) != stage:
			col.move_child(stage, 0)
	if is_instance_valid(_hero):
		_hero.custom_minimum_size = Vector2(0, 260 if _mobile else 240)


func _on_join_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Jugador"
	SettingsManager.preferred_name = player_name
	SettingsManager.save_settings()
	var address := address_input.text.strip_edges()
	status_label.text = "Conectando al hangar…"
	var err: Error = NetworkManager.join_game(address, player_name)
	if err != OK:
		status_label.text = "Error al conectar (%s)" % error_string(err)


func _on_host_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Anfitrión"
	status_label.text = "Abriendo sala local…"
	var err: Error = NetworkManager.host_listen_server(player_name)
	if err != OK:
		status_label.text = "Error al crear servidor local"


func _on_solo_start_pressed() -> void:
	var player_name := solo_name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Practicante"
	SettingsManager.preferred_name = player_name
	SettingsManager.save_settings()
	status_label.text = "Preparando campaña solitaria…"
	var err: Error = NetworkManager.start_solo_practice(player_name)
	if err != OK:
		status_label.text = "No se pudo iniciar práctica"


func _on_mute_toggled(on: bool) -> void:
	SettingsManager.set_muted(on)


func _on_credits_pressed() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Créditos y legal"
	dlg.dialog_text = (
		"%s v%s\n%s\n\n%s\n\n%s\n\nFuentes: ver assets/fonts/LICENSE.txt (SIL OFL).\nPrivacidad: %s\nSoporte: %s"
		% [
			GameBrand.GAME_TITLE,
			GameBrand.VERSION,
			GameBrand.copyright_line(),
			GameBrand.DISCLAIMER,
			GameBrand.store_subtitle(),
			GameBrand.PRIVACY_URL,
			GameBrand.SUPPORT_URL,
		]
	)
	dlg.ok_button_text = "Cerrar"
	add_child(dlg)
	dlg.popup_centered(Vector2i(420, 360))
	dlg.confirmed.connect(dlg.queue_free)
	dlg.close_requested.connect(dlg.queue_free)


func _on_server_started() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connected() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connection_failed() -> void:
	if NetworkManager.last_reject_reason != "":
		status_label.text = NetworkManager.last_reject_reason
	else:
		status_label.text = "No se pudo conectar al VPS. Revisa la URL."

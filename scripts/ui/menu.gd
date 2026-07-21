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
@onready var main_scroll: ScrollContainer = $Main

const LOBBY_SCENE := "res://scenes/main/lobby.tscn"
const CREW_SCRIPT := preload("res://scripts/player/crew_visual.gd")
const HERO_SHADER := preload("res://shaders/ui_hero_motion.gdshader")
const BG_SHADER := preload("res://shaders/ui_mobile_bg.gdshader")

var _spin_nodes: Array[Node3D] = []
var _hero: TextureRect
var _pulse_fx: TextureRect
var _mobile := false
var _chip_nodes: Array[Control] = []
var _anim_t := 0.0


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
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_started.connect(_on_server_started)

	name_input.text = "Robot"
	address_input.text = NetworkManager.get_default_server_url()
	address_input.placeholder_text = "wss://botgame.renace.tech/ws"


func _is_mobile_layout() -> bool:
	if OS.has_feature("mobile"):
		return true
	var sz := DisplayServer.window_get_size()
	return sz.x < 820 or sz.y > sz.x


func _style_ui() -> void:
	var title_size := 36 if _mobile else 48
	GameTheme.style_title(title_label, title_size)
	GameTheme.style_muted(subtitle, 15 if _mobile else 17)
	GameTheme.style_primary(join_button)
	join_button.text = "▶  ENTRAR A LA PARTIDA"
	host_button.text = "Probar en local"
	status_label.add_theme_color_override("font_color", GameTheme.C_AMBER)
	join_button.custom_minimum_size = Vector2(0, 64 if _mobile else 52)
	name_input.custom_minimum_size = Vector2(0, 52 if _mobile else 44)
	address_input.custom_minimum_size = Vector2(0, 48 if _mobile else 44)
	if _mobile:
		host_button.visible = false  # local host poco útil en móvil web


func _setup_atmosphere() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	atmosphere.material = mat


func _spawn_showcase() -> void:
	if stage_root == null:
		return
	var stage_wrap := get_node_or_null("Main/Col/StageWrap") as Control
	# Web / móvil: arte 2D animado (sin SubViewport 3D)
	if OS.has_feature("web") or OS.get_name() == "Web" or _mobile:
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

	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.4
	cyl.bottom_radius = 2.6
	cyl.height = 0.12
	pad.mesh = cyl
	pad.position = Vector3(0, -0.05, 0)
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.08, 0.12, 0.15)
	pad_mat.emission_enabled = true
	pad_mat.emission = Color(0.1, 0.5, 0.45)
	pad_mat.emission_energy_multiplier = 0.35
	pad.material_override = pad_mat
	stage_root.add_child(pad)


func _fill_web_stage(stage_wrap: Control) -> void:
	var cap := stage_wrap.get_node_or_null("VBox/StageCaption") as Label
	if cap:
		cap.text = "⚔️  BESTIA VS ROBOTS"
		cap.add_theme_font_size_override("font_size", 14)
	var view := stage_wrap.get_node_or_null("VBox/StageView") as Control
	if view:
		view.visible = false
	var vbox := stage_wrap.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return

	var hero_wrap := Control.new()
	hero_wrap.custom_minimum_size = Vector2(0, 160 if _mobile else 220)
	hero_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_wrap.clip_contents = true
	vbox.add_child(hero_wrap)

	_hero = TextureRect.new()
	_hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero.texture = UiIcons.tex(UiIcons.MENU_HERO)
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hero_mat := ShaderMaterial.new()
	hero_mat.shader = HERO_SHADER
	_hero.material = hero_mat
	hero_wrap.add_child(_hero)

	_pulse_fx = TextureRect.new()
	_pulse_fx.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pulse_fx.custom_minimum_size = Vector2(96, 96)
	_pulse_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pulse_fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pulse_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulse_fx.texture = _make_pulse_anim()
	_pulse_fx.modulate = Color(1, 1, 1, 0.65)
	hero_wrap.add_child(_pulse_fx)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8 if _mobile else 10)
	vbox.add_child(row)

	for item in [
		[UiIcons.skin_tex(0), "Robot"],
		[UiIcons.beast_tex(GameManager.BeastVariant.CLASSIC), "Bestia"],
		[UiIcons.loadout_tex(0), "Arsenal"],
		[UiIcons.map_tex("lab_neon"), "Mapas"],
	]:
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(72 if _mobile else 88, 84 if _mobile else 96)
		chip.add_theme_stylebox_override(
			"panel",
			GameTheme.panel_style(Color(0.06, 0.1, 0.12, 0.9), GameTheme.C_CYAN.darkened(0.3), 8, 1)
		)
		var chip_col := VBoxContainer.new()
		chip_col.alignment = BoxContainer.ALIGNMENT_CENTER
		chip.add_child(chip_col)
		var tr := TextureRect.new()
		tr.texture = item[0]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size = Vector2(52 if _mobile else 64, 44 if _mobile else 52)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_col.add_child(tr)
		var lb := Label.new()
		lb.text = item[1]
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 11 if _mobile else 12)
		lb.add_theme_color_override("font_color", GameTheme.C_MUTED)
		chip_col.add_child(lb)
		row.add_child(chip)
		_chip_nodes.append(chip)

	var tip := Label.new()
	tip.text = "Táctil · DISPARO · sabotea núcleos\nElige rol y arsenal en la sala."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 13 if _mobile else 15)
	tip.add_theme_color_override("font_color", GameTheme.C_MUTED)
	vbox.add_child(tip)


func _make_pulse_anim() -> AnimatedTexture:
	var anim := AnimatedTexture.new()
	anim.frames = 4
	for i in 4:
		var path := "res://assets/ui/fx/pulse_%d.png" % i
		if ResourceLoader.exists(path):
			anim.set_frame_texture(i, load(path) as Texture2D)
			anim.set_frame_duration(i, 0.12)
	anim.oneshot = false
	anim.pause = false
	return anim


func _start_ui_motion() -> void:
	# Pulso CTA
	var tw := create_tween().set_loops()
	tw.tween_property(join_button, "modulate", Color(1.08, 1.08, 1.08, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(join_button, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)
	# Título
	title_label.pivot_offset = title_label.size * 0.5
	var tw2 := create_tween().set_loops()
	tw2.tween_property(title_label, "scale", Vector2(1.02, 1.02), 1.1).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(title_label, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_anim_t += delta
	for i in _spin_nodes.size():
		var n := _spin_nodes[i]
		if is_instance_valid(n):
			n.rotate_y(delta * (0.55 if i == 0 else -0.4))
	# Chips flotando
	for i in _chip_nodes.size():
		var c := _chip_nodes[i]
		if is_instance_valid(c):
			c.position.y = sin(_anim_t * 2.2 + i * 0.9) * 3.0
	if is_instance_valid(_pulse_fx):
		_pulse_fx.rotation = _anim_t * 0.4
		_pulse_fx.modulate.a = 0.35 + 0.35 * (0.5 + 0.5 * sin(_anim_t * 3.0))


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
	# En pantallas anchas: arte arriba del formulario; en móvil CTA primero
	if _mobile:
		if form and col.get_child(0) != form:
			col.move_child(form, 0)
		if stage:
			stage.custom_minimum_size = Vector2(0, 210)
	else:
		if stage and col.get_child(0) != stage:
			col.move_child(stage, 0)
		if stage:
			stage.custom_minimum_size = Vector2(0, 280)


func _on_join_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Jugador"
	var address := address_input.text.strip_edges()
	status_label.text = "Conectando al hangar…"
	var err := NetworkManager.join_game(address, player_name)
	if err != OK:
		status_label.text = "Error al conectar (%s)" % error_string(err)


func _on_host_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Anfitrión"
	status_label.text = "Abriendo sala local…"
	var err := NetworkManager.host_listen_server(player_name)
	if err != OK:
		status_label.text = "Error al crear servidor local"


func _on_server_started() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connected() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connection_failed() -> void:
	if NetworkManager.last_reject_reason != "":
		status_label.text = NetworkManager.last_reject_reason
	else:
		status_label.text = "No se pudo conectar al VPS. Revisa la URL."

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
const BG_SHADER := preload("res://shaders/ui_mobile_bg.gdshader")

var _spin_nodes: Array[Node3D] = []
var _hero: TextureRect
var _chip_nodes: Array[Control] = []
var _anim_t := 0.0
var _mobile := false
var _mode := "online"
var _join_timeout: SceneTreeTimer = null
var _pick_skin := 0
var _pick_role := "explorer"
var _pick_beast_variant := GameManager.BeastVariant.MECHA
var _pick_map_idx := 0
var _dyn_robots: HBoxContainer
var _dyn_beasts: HBoxContainer
var _dyn_maps: HBoxContainer
var _dyn_status: Label


func _ready() -> void:
	if NetworkManager.is_dedicated_server:
		get_tree().change_scene_to_file("res://scenes/main/server_main.tscn")
		return

	_mobile = _is_mobile_layout()
	GameTheme.apply(self)
	_setup_cinematic_bg()
	_style_ui()
	_lift_brand_header()
	_setup_atmosphere()
	_spawn_showcase()
	_start_ui_motion()
	call_deferred("_adapt_layout")
	AudioDirector.start_menu_music()
	_build_hub_modes()

	join_button.pressed.connect(_on_join_pressed)
	host_button.pressed.connect(_on_host_pressed)
	online_mode_button.pressed.connect(func(): AudioDirector.play_ui("click"); _set_mode("online"))
	solo_mode_button.pressed.connect(func(): AudioDirector.play_ui("click"); _set_mode("solo"))
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
	# Marca una sola vez en legal; el hangar habla de misión, no repite el título
	title_label.text = "HANGAR"
	_pick_skin = _default_mesh_skin()
	_set_mode("online")


func _default_mesh_skin() -> int:
	return CharacterCatalog.default_explorer_skin()


func _setup_cinematic_bg() -> void:
	## Vídeo de fondo como la landing (mute; AudioDirector lleva la música).
	if get_node_or_null("CinematicBg") != null:
		return
	var player := VideoStreamPlayer.new()
	player.name = "CinematicBg"
	player.set_anchors_preset(Control.PRESET_FULL_RECT)
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.volume_db = -80.0
	player.z_index = -2
	var candidates: Array[String] = []
	if OS.has_feature("web") or OS.get_name() == "Web":
		candidates = [
			"res://assets/video/intro/chadrine_intro.webm",
			"res://assets/video/intro/chadrine_intro.mp4",
		]
	else:
		candidates = [
			"res://assets/video/intro/chadrine_intro.mp4",
			"res://assets/video/intro/chadrine_intro.webm",
		]
	var ok := false
	for path in candidates:
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream == null:
			continue
		player.stream = stream
		add_child(player)
		move_child(player, 0)
		player.play()
		ok = true
		# Loop: al terminar, reinicia
		if not player.finished.is_connected(_on_cinematic_loop):
			player.finished.connect(_on_cinematic_loop)
		break
	if not ok:
		player.queue_free()
		_setup_keyart_bg()
	# Atmósfera más transparente para que se vea el vídeo
	if atmosphere:
		atmosphere.modulate = Color(1, 1, 1, 0.42)
		atmosphere.z_index = -1


func _on_cinematic_loop() -> void:
	var player := get_node_or_null("CinematicBg") as VideoStreamPlayer
	if player and player.stream:
		player.play()


func _setup_keyart_bg() -> void:
	var art_path := "res://assets/art/chadrine_keyart.png"
	if not ResourceLoader.exists(art_path):
		return
	var tex := load(art_path) as Texture2D
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.name = "KeyartBg"
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = Color(1, 1, 1, 0.85)
	tr.z_index = -2
	add_child(tr)
	move_child(tr, 0)
	if atmosphere:
		atmosphere.modulate = Color(1, 1, 1, 0.5)
		atmosphere.z_index = -1


func _is_mobile_layout() -> bool:
	if OS.has_feature("mobile"):
		return true
	var sz := get_viewport().get_visible_rect().size
	return sz.x < 820 or sz.y > sz.x


func _style_ui() -> void:
	var title_size := 36 if _mobile else 42
	GameTheme.style_title(title_label, title_size)
	GameTheme.style_muted(subtitle, 15 if _mobile else 17)
	subtitle.text = "Elige tripulación · lanza la misión"
	GameTheme.style_primary(join_button)
	GameTheme.style_primary(solo_start_button)
	join_button.text = "ENTRAR AL COMBATE"
	host_button.text = "Sala LAN"
	solo_start_button.text = "LANZAR MISIÓN"
	online_mode_button.text = "ONLINE"
	solo_mode_button.text = "CAMPAÑA"
	status_label.add_theme_color_override("font_color", GameTheme.C_AMBER)
	join_button.custom_minimum_size = Vector2(0, 76 if _mobile else 58)
	join_button.add_theme_font_size_override("font_size", 24 if _mobile else 22)
	solo_start_button.custom_minimum_size = Vector2(0, 76 if _mobile else 58)
	solo_start_button.add_theme_font_size_override("font_size", 24 if _mobile else 22)
	online_mode_button.custom_minimum_size = Vector2(0, 58 if _mobile else 52)
	solo_mode_button.custom_minimum_size = Vector2(0, 58 if _mobile else 52)
	name_input.custom_minimum_size = Vector2(0, 58 if _mobile else 44)
	name_input.add_theme_font_size_override("font_size", 20 if _mobile else 16)
	name_input.placeholder_text = "Callsign"
	solo_name_input.custom_minimum_size = Vector2(0, 58 if _mobile else 44)
	solo_name_input.placeholder_text = "Callsign"
	address_input.custom_minimum_size = Vector2(0, 48 if _mobile else 40)
	GameTheme.style_muted(solo_hint, 14)
	GameTheme.style_muted(legal_label, 11)
	credits_button.text = "Créditos"
	mute_check.text = "Audio apagado"
	_style_hangar_panels()
	_tone_down_form_labels()
	# Web / móvil: URL del VPS va por defecto; no parece formulario de hosting
	host_button.visible = not _mobile and not OS.has_feature("web")
	var addr_label := online_panel.get_node_or_null("AddrLabel") as Control
	if addr_label:
		addr_label.visible = false
	if _mobile or OS.has_feature("web"):
		address_input.visible = false


func _style_hangar_panels() -> void:
	var stage := get_node_or_null("Main/Col/StageWrap") as PanelContainer
	var form := get_node_or_null("Main/Col/FormWrap") as PanelContainer
	if stage:
		stage.add_theme_stylebox_override(
			"panel",
			GameTheme.panel_style(Color(0.04, 0.07, 0.09, 0.48), GameTheme.C_CYAN, 14, 2)
		)
	if form:
		form.add_theme_stylebox_override(
			"panel",
			GameTheme.panel_style(Color(0.05, 0.08, 0.1, 0.62), GameTheme.C_AMBER.darkened(0.25), 14, 2)
		)


func _tone_down_form_labels() -> void:
	for path in ["NameLabel", "AddrLabel"]:
		var lb := online_panel.get_node_or_null(path) as Label
		if lb == null:
			continue
		lb.visible = path == "NameLabel"
		if lb.visible:
			lb.text = "CALLSIGN"
			GameTheme.style_muted(lb, 12)


func _lift_brand_header() -> void:
	## Marca arriba del hangar: primer viewport = juego, no formulario.
	var col := get_node_or_null("Main/Col") as VBoxContainer
	var form := get_node_or_null("Main/Col/FormWrap/Margin/Form") as VBoxContainer
	if col == null or form == null:
		return
	if col.get_node_or_null("BrandHeader") != null:
		return
	var brand := VBoxContainer.new()
	brand.name = "BrandHeader"
	brand.add_theme_constant_override("separation", 2)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.remove_child(title_label)
	form.remove_child(subtitle)
	brand.add_child(title_label)
	brand.add_child(subtitle)
	col.add_child(brand)
	col.move_child(brand, 0)


func _build_hub_modes() -> void:
	## Submodos opcionales (Platformer/FPS/City) — solo si alguno está en el build.
	var any_extra := false
	for mid in [ModeRouter.MODE_PLATFORMER, ModeRouter.MODE_FPS, ModeRouter.MODE_CITY]:
		if ModeRouter.mode_available(mid):
			any_extra = true
			break
	if not any_extra:
		return
	var host: Control = online_mode_button.get_parent() as Control
	if host == null:
		return
	var row := HBoxContainer.new()
	row.name = "HubModesRow"
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var modes := [
		{"id": ModeRouter.MODE_PLATFORMER, "label": "PLATFORMER"},
		{"id": ModeRouter.MODE_FPS, "label": "FPS"},
		{"id": ModeRouter.MODE_CITY, "label": "CITY"},
	]
	for m in modes:
		var b := Button.new()
		var mid: String = str(m["id"])
		var available := ModeRouter.mode_available(mid)
		b.text = str(m["label"]) if available else ("%s · LOCK" % str(m["label"]))
		b.disabled = not available
		b.tooltip_text = "" if available else "Modo opcional no incluido en este build"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(func():
			AudioDirector.play_ui("confirm")
			ModeRouter.start_mode(mid)
		)
		row.add_child(b)
	var parent := host.get_parent()
	if parent:
		var idx := host.get_index()
		parent.add_child(row)
		parent.move_child(row, idx + 1)


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
		subtitle.text = "ONLINE · 1 Bestia vs 1–3 Robots"
		status_label.text = ""
	else:
		GameTheme.style_primary(solo_mode_button)
		online_mode_button.remove_theme_stylebox_override("normal")
		online_mode_button.remove_theme_stylebox_override("hover")
		online_mode_button.remove_theme_stylebox_override("pressed")
		subtitle.text = "CAMPAÑA · elige teatro · lanza con bots"
		var lv := ProgressionManager.level_name()
		status_label.text = "%s · %d victorias" % [lv, ProgressionManager.wins_total]
		solo_hint.text = "TEATRO libre arriba · abajo: LANZAR MISIÓN\n%s" % lv
		# Solo sugerir mapa del nivel si aún no eligió
		if _pick_map_idx < 0 or _pick_map_idx >= NetworkManager.MAP_IDS.size():
			_pick_map_idx = NetworkManager.MAP_IDS.find(ProgressionManager.force_campaign_map())
			if _pick_map_idx < 0:
				_pick_map_idx = 0
	_rebuild_dynamic_pickers()
	_update_pick_status()


func _setup_atmosphere() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	atmosphere.material = mat


func _spawn_showcase() -> void:
	var stage_wrap := get_node_or_null("Main/Col/StageWrap") as Control
	if stage_wrap == null:
		return
	# Menú web y desktop: selección dinámica (sin chips estáticos viejos)
	_fill_dynamic_stage(stage_wrap)


func _fill_dynamic_stage(stage_wrap: Control) -> void:
	var cap := stage_wrap.get_node_or_null("VBox/StageCaption") as Label
	if cap:
		cap.text = "HANGAR · TRIPULACIÓN"
		GameTheme.style_muted(cap, 12)
		cap.visible = true

	var view := stage_wrap.get_node_or_null("VBox/StageView") as SubViewportContainer
	var sv := stage_wrap.get_node_or_null("VBox/StageView/SubViewport") as SubViewport
	if view and sv:
		view.visible = true
		view.custom_minimum_size = Vector2(0, 280 if _mobile else 340)
		sv.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		sv.size = Vector2i(640, 400)
		sv.transparent_bg = false

	var vbox := stage_wrap.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return

	for c in vbox.get_children():
		if str(c.name).begins_with("Dyn"):
			c.queue_free()

	# Preferir mapa ya elegido / seleccionado en red; si no, el del nivel de campaña
	var prefer := NetworkManager.selected_map
	var idx := NetworkManager.MAP_IDS.find(prefer)
	if idx < 0:
		idx = NetworkManager.MAP_IDS.find(ProgressionManager.force_campaign_map())
	_pick_map_idx = idx if idx >= 0 else 0

	_dyn_status = Label.new()
	_dyn_status.name = "DynStatus"
	_dyn_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dyn_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if GameTheme.font_title():
		_dyn_status.add_theme_font_override("font", GameTheme.font_title())
	_dyn_status.add_theme_font_size_override("font_size", 15 if _mobile else 16)
	_dyn_status.add_theme_color_override("font_color", GameTheme.C_CYAN)
	vbox.add_child(_dyn_status)

	vbox.add_child(_section_label("DynLblRobots", "ROBOTS"))
	_dyn_robots = _add_hscroll(vbox, "DynRobots")
	vbox.add_child(_section_label("DynLblBeasts", "BESTIAS"))
	_dyn_beasts = _add_hscroll(vbox, "DynBeasts")
	vbox.add_child(_section_label("DynLblMaps", "TEATRO"))
	_dyn_maps = _add_hscroll(vbox, "DynMaps")

	_rebuild_dynamic_pickers()
	_update_pick_status()
	call_deferred("_update_3d_stage_preview")


func _update_3d_stage_preview() -> void:
	var world := get_node_or_null("Main/Col/StageWrap/VBox/StageView/SubViewport/World") as Node3D
	if world == null:
		return

	var pedestal := world.get_node_or_null("Pedestal") as MeshInstance3D
	if pedestal == null:
		pedestal = MeshInstance3D.new()
		pedestal.name = "Pedestal"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.2
		cyl.bottom_radius = 1.35
		cyl.height = 0.22
		pedestal.mesh = cyl
		pedestal.position = Vector3(0, -0.1, 0)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.08, 0.12, 0.18, 1.0)
		pmat.metallic = 0.7
		pmat.roughness = 0.25
		pmat.emission_enabled = true
		pmat.emission = Color(0.1, 0.7, 0.8, 1.0)
		pmat.emission_energy_multiplier = 0.45
		pedestal.material_override = pmat
		world.add_child(pedestal)

	var container := world.get_node_or_null("ModelPivot") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "ModelPivot"
		world.add_child(container)

	_spin_nodes.clear()
	_spin_nodes.append(container)

	while container.get_child_count() > 0:
		var ch := container.get_child(0)
		container.remove_child(ch)
		ch.free()

	var attached := CharacterCatalog.attach_mesh(container, _pick_skin, 1.0)
	if attached != null:
		CharacterCatalog.fit_for_showcase(attached, 2.1)
		CharacterCatalog.attach_showcase_loadout(attached, _pick_role)
		CharacterCatalog.play_showcase_motion(attached)
		# Luces más fuertes para que el modelo no se vea “plano”
		var key := world.get_node_or_null("KeyLight") as DirectionalLight3D
		if key:
			key.light_energy = 1.55
		var fill := world.get_node_or_null("Fill") as OmniLight3D
		if fill:
			fill.light_energy = 3.2
		var rim := world.get_node_or_null("Rim") as OmniLight3D
		if rim:
			rim.light_energy = 2.8
		var cam := world.get_node_or_null("Camera3D") as Camera3D
		if cam:
			cam.position = Vector3(0, 1.35, 3.6)
			cam.look_at(Vector3(0, 0.95, 0))
			cam.fov = 38.0
		return

	# Fallback procedural tintado (crew sin GLB)
	var entry := CharacterCatalog.get_entry(_pick_skin)
	var tint: Color = entry.get("tint", Color(0.25, 0.55, 1.0))
	var mesh_inst := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.35
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.25
	if _pick_role == "beast":
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 1.7, 1.2)
		mesh_inst.mesh = box
		mesh_inst.position.y = 0.95
	else:
		var caps := CapsuleMesh.new()
		caps.radius = 0.42
		caps.height = 1.5
		mesh_inst.mesh = caps
		mesh_inst.position.y = 0.85
	mesh_inst.material_override = mat
	container.add_child(mesh_inst)


func _section_label(node_name: String, text: String) -> Label:
	var lb := Label.new()
	lb.name = node_name
	lb.text = text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if GameTheme.font_title():
		lb.add_theme_font_override("font", GameTheme.font_title())
	lb.add_theme_font_size_override("font_size", 13)
	lb.add_theme_color_override("font_color", GameTheme.C_AMBER)
	return lb


func _add_hscroll(vbox: VBoxContainer, row_name: String) -> HBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = row_name + "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 156 if _mobile else 148)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 10)
	scroll.add_child(row)
	return row


func _menu_explorer_indices() -> Array:
	## Solo roster 3D — sin cápsulas legacy en el hangar.
	var with_mesh: Array = []
	for idx in CharacterCatalog.explorer_indices():
		var i := int(idx)
		var mesh := str(CharacterCatalog.get_entry(i).get("mesh", ""))
		if not mesh.is_empty() and ResourceLoader.exists(mesh):
			with_mesh.append(i)
	if with_mesh.is_empty():
		return CharacterCatalog.explorer_indices()
	return with_mesh


func _menu_beast_indices() -> Array:
	var with_mesh: Array = []
	var legacy: Array = []
	for idx in CharacterCatalog.beast_indices():
		var i := int(idx)
		var mesh := str(CharacterCatalog.get_entry(i).get("mesh", ""))
		if not mesh.is_empty() and ResourceLoader.exists(mesh):
			with_mesh.append(i)
		else:
			legacy.append(i)
	var out: Array = []
	out.append_array(with_mesh)
	out.append_array(legacy)
	return out


func _rebuild_dynamic_pickers() -> void:
	if _dyn_robots == null or _dyn_beasts == null or _dyn_maps == null:
		return
	for c in _dyn_robots.get_children():
		c.queue_free()
	for c in _dyn_beasts.get_children():
		c.queue_free()
	for c in _dyn_maps.get_children():
		c.queue_free()
	_chip_nodes.clear()

	for idx in _menu_explorer_indices():
		var i := int(idx)
		var locked := not CharacterCatalog.is_unlocked(i)
		var selected := i == _pick_skin and _pick_role == "explorer"
		var card := VisualPicker.make_skin_card(i, selected, locked)
		card.custom_minimum_size = Vector2(92, 130)
		card.set_meta("picked", selected)
		_wire_menu_card(card, func(): _on_pick_robot(i))
		_dyn_robots.add_child(card)
		_chip_nodes.append(card)

	for idx in _menu_beast_indices():
		var i := int(idx)
		var locked := not CharacterCatalog.is_unlocked(i)
		var selected := _pick_role == "beast" and i == _pick_skin
		var card := VisualPicker.make_skin_card(i, selected, locked)
		card.custom_minimum_size = Vector2(100, 130)
		card.set_meta("picked", selected)
		_wire_menu_card(card, func(): _on_pick_beast_entry(i))
		_dyn_beasts.add_child(card)
		_chip_nodes.append(card)

	for mi in NetworkManager.MAP_IDS.size():
		var mid: String = NetworkManager.MAP_IDS[mi]
		var locked := false
		if _mode == "solo":
			# Campaña solitaria: todos los teatros para probar
			locked = false
		else:
			locked = not ProgressionManager.is_map_unlocked(mid)
		var selected := mi == _pick_map_idx
		var card := VisualPicker.make_map_card(mid, selected, locked)
		card.custom_minimum_size = Vector2(118, 130)
		card.set_meta("picked", selected)
		_wire_menu_card(card, func(): _on_pick_map(mi))
		_dyn_maps.add_child(card)
		_chip_nodes.append(card)


func _beast_variant_for_entry(e: Dictionary) -> int:
	match str(e.get("id", "")):
		"beast_mecha":
			return GameManager.BeastVariant.MECHA
		"beast_shadow":
			return GameManager.BeastVariant.SHADOW
		_:
			return GameManager.BeastVariant.CLASSIC


func _wire_menu_card(card: PanelContainer, cb: Callable) -> void:
	card.gui_input.connect(func(ev: InputEvent):
		if card.get_meta("locked", false):
			return
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			AudioDirector.play_ui("click")
			cb.call()
		elif ev is InputEventScreenTouch and ev.pressed:
			AudioDirector.play_ui("click")
			cb.call()
	)


func _on_pick_robot(skin: int) -> void:
	if not CharacterCatalog.is_unlocked(skin):
		return
	_pick_role = "explorer"
	_pick_skin = skin
	_rebuild_dynamic_pickers()
	_update_pick_status()
	call_deferred("_update_3d_stage_preview")


func _on_pick_beast_entry(catalog_i: int) -> void:
	if not CharacterCatalog.is_unlocked(catalog_i):
		return
	_pick_role = "beast"
	_pick_skin = catalog_i
	_pick_beast_variant = _beast_variant_for_entry(CharacterCatalog.get_entry(catalog_i)) as GameManager.BeastVariant
	_rebuild_dynamic_pickers()
	_update_pick_status()
	call_deferred("_update_3d_stage_preview")


func _on_pick_map(map_idx: int) -> void:
	if map_idx < 0 or map_idx >= NetworkManager.MAP_IDS.size():
		return
	var mid: String = NetworkManager.MAP_IDS[map_idx]
	if _mode != "solo" and not ProgressionManager.is_map_unlocked(mid):
		return
	_pick_map_idx = map_idx
	NetworkManager.selected_map = mid
	_rebuild_dynamic_pickers()
	_update_pick_status()


func _update_pick_status() -> void:
	if _dyn_status == null:
		return
	var who := CharacterCatalog.display_name(_pick_skin)
	var map_id: String = NetworkManager.MAP_IDS[_pick_map_idx] if _pick_map_idx < NetworkManager.MAP_IDS.size() else "lab_neon"
	var map_name: String = str(NetworkManager.MAP_NAMES.get(map_id, map_id))
	if _pick_role == "beast":
		_dyn_status.text = "DESPLEGAR · BESTIA «%s» · %s" % [who, map_name]
	else:
		_dyn_status.text = "DESPLEGAR · ROBOT «%s» · %s" % [who, map_name]


func _apply_menu_picks_to_network() -> void:
	if NetworkManager.players.has(1):
		NetworkManager.players[1]["role"] = _pick_role
		NetworkManager.players[1]["skin"] = _pick_skin
		NetworkManager.players[1]["ready"] = true
	GameManager.beast_variant = _pick_beast_variant
	if _pick_map_idx >= 0 and _pick_map_idx < NetworkManager.MAP_IDS.size():
		NetworkManager.selected_map = NetworkManager.MAP_IDS[_pick_map_idx]
	elif _mode == "solo":
		NetworkManager.selected_map = ProgressionManager.force_campaign_map()


func _start_ui_motion() -> void:
	# Pulso CTA principal
	var tw := create_tween().set_loops()
	tw.tween_property(join_button, "modulate", Color(0.88, 1.0, 0.96), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(join_button, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(solo_start_button, "modulate", Color(0.88, 1.0, 0.96), 0.9).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(solo_start_button, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)
	# Título: glow respirando
	var tw3 := create_tween().set_loops()
	tw3.tween_property(title_label, "modulate", Color(0.92, 1.0, 1.0), 1.4).set_trans(Tween.TRANS_SINE)
	tw3.tween_property(title_label, "modulate", Color.WHITE, 1.4).set_trans(Tween.TRANS_SINE)
	# Keyart: leve ken-burns
	if is_instance_valid(_hero):
		_hero.scale = Vector2(1.02, 1.02)
		var tw4 := create_tween().set_loops()
		tw4.tween_property(_hero, "scale", Vector2(1.08, 1.08), 5.5).set_trans(Tween.TRANS_SINE)
		tw4.tween_property(_hero, "scale", Vector2(1.02, 1.02), 5.5).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_anim_t += delta
	for i in _spin_nodes.size():
		var n := _spin_nodes[i]
		if is_instance_valid(n):
			n.rotate_y(delta * (0.55 if i == 0 else -0.4))
	for i in _chip_nodes.size():
		var c := _chip_nodes[i]
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			continue
		var selected: bool = bool(c.get_meta("picked", false))
		var base := 0.9 + 0.1 * sin(_anim_t * 2.2 + i * 0.35)
		if selected:
			base = 0.95 + 0.05 * sin(_anim_t * 4.0)
			c.modulate = Color(1.0, base, base * 0.95 + 0.05, 1.0)
		else:
			c.modulate = Color(base, base, base, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_adapt_layout()


func _adapt_layout() -> void:
	_mobile = _is_mobile_layout()
	var brand := get_node_or_null("Main/Col/BrandHeader") as Control
	var stage := get_node_or_null("Main/Col/StageWrap") as Control
	var col := get_node_or_null("Main/Col") as VBoxContainer
	if col == null:
		return
	# Orden: marca → hangar → misión (nunca formulario arriba)
	if brand:
		col.move_child(brand, 0)
	if stage:
		col.move_child(stage, 1 if brand else 0)
	if is_instance_valid(_hero):
		_hero.custom_minimum_size = Vector2(0, 220 if _mobile else 240)
		if _hero.size.x > 1.0:
			_hero.pivot_offset = Vector2(_hero.size.x * 0.5, _hero.size.y * 0.5)


func _on_join_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Jugador"
	SettingsManager.preferred_name = player_name
	SettingsManager.save_settings()
	var address := address_input.text.strip_edges()
	if address.is_empty():
		address = NetworkManager.get_default_server_url()
		address_input.text = address
	status_label.text = "Conectando a %s …" % address
	join_button.disabled = true
	var err: Error = NetworkManager.join_game(address, player_name)
	if err != OK:
		join_button.disabled = false
		status_label.text = "Error al conectar (%s)" % error_string(err)
		return
	_arm_join_timeout()


func _arm_join_timeout() -> void:
	_join_timeout = get_tree().create_timer(12.0)
	_join_timeout.timeout.connect(_on_join_timeout)


func _on_join_timeout() -> void:
	if get_tree().current_scene != self:
		return
	# Si ya entramos al lobby, esta escena ya no es current
	if not join_button.disabled:
		return
	join_button.disabled = false
	if NetworkManager.last_reject_reason != "":
		status_label.text = NetworkManager.last_reject_reason
	else:
		status_label.text = "Tiempo agotado. Revisa wss://botgame.renace.tech/ws y recarga."
	NetworkManager.disconnect_from_game()


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
	status_label.text = "Iniciando nivel…"
	solo_start_button.disabled = true
	# Aplicar picks (mapa incluido) ANTES de crear la sesión solo
	_apply_menu_picks_to_network()
	if not NetworkManager.match_start_requested.is_connected(_on_solo_match_start):
		NetworkManager.match_start_requested.connect(_on_solo_match_start, CONNECT_ONE_SHOT)
	var err: Error = NetworkManager.start_solo_practice(player_name)
	if err != OK:
		solo_start_button.disabled = false
		status_label.text = "No se pudo iniciar práctica"
		return
	# Reaplicar por si disconnect_from_game limpió algo del peer 1
	_apply_menu_picks_to_network()
	NetworkManager.request_start_match()


func _on_solo_match_start(_map_id: String) -> void:
	solo_start_button.disabled = false
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")


func _on_mute_toggled(on: bool) -> void:
	SettingsManager.set_muted(on)


func _on_credits_pressed() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Créditos y legal"
	dlg.dialog_text = (
		"%s v%s\n%s\n\n%s\n\n%s\n\nAssets: Kenney CC0 + KayKit (assets/CREDITS.md).\nModos: Asimétrico · Platformer · FPS · City Builder.\nFuentes: assets/fonts/LICENSE.txt (SIL OFL).\nPrivacidad: %s\nSoporte: %s"
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
	# Campaña one-click navega a game vía match_start_requested (no lobby)
	if NetworkManager.is_solo_practice:
		return
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connected() -> void:
	join_button.disabled = false
	NetworkManager.submit_role(_pick_role)
	NetworkManager.submit_skin(_pick_skin)
	if _pick_role == "beast":
		NetworkManager.submit_beast_variant(int(_pick_beast_variant))
	if _pick_map_idx >= 0 and _pick_map_idx < NetworkManager.MAP_IDS.size():
		NetworkManager.selected_map = NetworkManager.MAP_IDS[_pick_map_idx]
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connection_failed() -> void:
	join_button.disabled = false
	if NetworkManager.last_reject_reason != "":
		status_label.text = NetworkManager.last_reject_reason
	else:
		status_label.text = "No se pudo conectar al VPS. Revisa la URL."

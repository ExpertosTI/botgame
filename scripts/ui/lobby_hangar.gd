class_name LobbyHangar
extends PanelContainer

## Preview 3D del roster (Web + desktop).

const CREW_SCRIPT := preload("res://scripts/player/crew_visual.gd")

const SKIN_COLORS := [
	[Color(0.2, 0.45, 0.95), Color(0.55, 0.85, 1.0), Color(0.15, 0.35, 0.7)],
	[Color(0.95, 0.35, 0.65), Color(1.0, 0.7, 0.85), Color(0.6, 0.15, 0.4)],
	[Color(0.2, 0.8, 0.4), Color(0.6, 1.0, 0.75), Color(0.1, 0.45, 0.25)],
	[Color(0.95, 0.8, 0.15), Color(1.0, 0.95, 0.55), Color(0.55, 0.4, 0.05)],
]

var _use_3d := false
var _viewport: SubViewport
var _stage: Node3D
var _crew: Node3D
var _portrait: TextureRect
var _label: Label
var _spin := 0.0
var _role := "explorer"
var _skin := 0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override(
		"panel",
		GameTheme.panel_style(Color(0.03, 0.06, 0.08, 0.55), GameTheme.C_CYAN.darkened(0.35), 12, 2)
	)
	# 3D también en Web (mismo roster GLB que la landing / menú)
	_use_3d = true
	_setup_3d()
	show_selection("explorer", CharacterCatalog.index_of_id("blocky_a"))
	set_process(true)


func _setup_2d() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.custom_minimum_size = Vector2(120, 110)
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_portrait)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", GameTheme.C_CYAN)
	col.add_child(_label)


func _setup_3d() -> void:
	var wrap := SubViewportContainer.new()
	wrap.stretch = true
	wrap.custom_minimum_size = Vector2(0, 220)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(wrap)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(560, 280)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	wrap.add_child(_viewport)

	var world := Node3D.new()
	_viewport.add_child(world)
	_stage = world

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, 35, 0)
	light.light_energy = 1.15
	world.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.2, 1.5, 1.4)
	fill.light_color = Color(0.35, 0.85, 0.9)
	fill.light_energy = 1.4
	fill.omni_range = 8.0
	world.add_child(fill)

	var cam := Camera3D.new()
	cam.position = Vector3(1.8, 1.05, 2.0)
	cam.fov = 34.0
	world.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.8, 0), Vector3.UP)

	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.25
	cyl.height = 0.08
	pad.mesh = cyl
	pad.position = Vector3(0, -0.02, 0)
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.07, 0.1, 0.13)
	pad_mat.emission_enabled = true
	pad_mat.emission = Color(0.1, 0.55, 0.5)
	pad_mat.emission_energy_multiplier = 0.45
	pad.material_override = pad_mat
	world.add_child(pad)


func _process(delta: float) -> void:
	_spin += delta * 0.7
	if _use_3d and is_instance_valid(_crew):
		_crew.rotation.y = _spin
	elif is_instance_valid(_portrait):
		_portrait.rotation = sin(_spin * 1.2) * 0.04
		_portrait.scale = Vector2.ONE * (1.0 + 0.03 * sin(_spin * 2.0))


func show_selection(role: String, skin: int) -> void:
	_role = role
	_skin = skin
	if _use_3d:
		_rebuild_crew(role == "beast", skin)
	else:
		_update_2d(role, skin)


func _update_2d(role: String, skin: int) -> void:
	if _portrait == null:
		return
	if role == "beast":
		var bidx := skin
		var be := CharacterCatalog.get_entry(bidx)
		if str(be.get("role", "")) != "beast":
			match int(GameManager.beast_variant):
				GameManager.BeastVariant.MECHA:
					bidx = CharacterCatalog.index_of_id("beast_mecha")
				GameManager.BeastVariant.SHADOW:
					bidx = CharacterCatalog.index_of_id("beast_shadow")
				_:
					bidx = CharacterCatalog.index_of_id("beast_classic")
		_portrait.texture = UiIcons.catalog_tex(bidx)
		if _label:
			_label.text = CharacterCatalog.display_name(bidx)
			_label.add_theme_color_override("font_color", GameTheme.C_CRIMSON)
	else:
		var entry: Dictionary = CharacterCatalog.get_entry(skin)
		_portrait.texture = UiIcons.catalog_tex(skin)
		if _label:
			var nm := CharacterCatalog.display_name(skin)
			if nm == "?" or nm.is_empty():
				nm = WeaponDefs.explorer_skin_name(skin)
			_label.text = nm
			var tint: Color = entry.get("tint", GameTheme.C_CYAN) if not entry.is_empty() else GameTheme.C_CYAN
			_label.add_theme_color_override("font_color", tint)


func _rebuild_crew(is_beast: bool, skin: int) -> void:
	if not _use_3d or _stage == null:
		return
	if is_instance_valid(_crew):
		_crew.queue_free()
		_crew = null
	# Preferir mesh del catálogo; fallback cápsula
	var wrap := Node3D.new()
	_stage.add_child(wrap)
	_crew = wrap
	var cat_idx := skin
	if is_beast:
		var be := CharacterCatalog.get_entry(skin)
		if str(be.get("role", "")) != "beast":
			match int(GameManager.beast_variant):
				GameManager.BeastVariant.MECHA:
					cat_idx = CharacterCatalog.index_of_id("beast_mecha")
				GameManager.BeastVariant.SHADOW:
					cat_idx = CharacterCatalog.index_of_id("beast_shadow")
				_:
					cat_idx = CharacterCatalog.index_of_id("beast_classic")
	var attached := CharacterCatalog.attach_mesh(wrap, cat_idx, 1.0 if is_beast else 0.9)
	if attached == null:
		var crew_n: Node3D = CREW_SCRIPT.new()
		crew_n.is_beast = is_beast
		crew_n.body_scale = 1.05 if is_beast else 1.0
		wrap.add_child(crew_n)
		var entry := CharacterCatalog.get_entry(cat_idx)
		var tint: Color = entry.get("tint", Color(0.25, 0.55, 1.0))
		if is_beast:
			crew_n.apply_colors(tint, Color(1.0, 0.35, 0.2), tint.lightened(0.2))
			crew_n.set_player_name(CharacterCatalog.display_name(cat_idx))
		else:
			crew_n.apply_colors(tint, Color(0.75, 0.95, 1.0), tint.lightened(0.15))
			crew_n.set_player_name(CharacterCatalog.display_name(cat_idx))
	else:
		CharacterCatalog.fit_for_showcase(attached, 1.85)
		var role := "beast" if is_beast else "explorer"
		CharacterCatalog.attach_showcase_loadout(attached, role)
		CharacterCatalog.play_showcase_motion(attached)
		var tag := Label3D.new()
		tag.text = CharacterCatalog.display_name(cat_idx)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 42
		tag.position = Vector3(0, 1.85, 0)
		wrap.add_child(tag)

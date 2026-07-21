class_name LobbyHangar
extends SubViewportContainer

## Preview 3D ligero del personaje elegido (robot / bestia).

const CREW_SCRIPT := preload("res://scripts/player/crew_visual.gd")

const SKIN_COLORS := [
	[Color(0.2, 0.45, 0.95), Color(0.55, 0.85, 1.0), Color(0.15, 0.35, 0.7)],
	[Color(0.95, 0.35, 0.65), Color(1.0, 0.7, 0.85), Color(0.6, 0.15, 0.4)],
	[Color(0.2, 0.8, 0.4), Color(0.6, 1.0, 0.75), Color(0.1, 0.45, 0.25)],
	[Color(0.95, 0.8, 0.15), Color(1.0, 0.95, 0.55), Color(0.55, 0.4, 0.05)],
]

var _viewport: SubViewport
var _stage: Node3D
var _crew: Node3D
var _spin := 0.0


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(0, 180)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(420, 220)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not (OS.has_feature("web") or OS.get_name() == "Web"):
		_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)

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
	cam.position = Vector3(0, 1.05, 2.55)
	cam.look_at(Vector3(0, 0.75, 0))
	cam.fov = 38.0
	world.add_child(cam)

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

	_rebuild_crew(false, 0)
	set_process(true)


func _process(delta: float) -> void:
	_spin += delta * 0.7
	if is_instance_valid(_crew):
		_crew.rotation.y = _spin


func _rebuild_crew(is_beast: bool, skin: int) -> void:
	if is_instance_valid(_crew):
		_crew.queue_free()
		_crew = null
	_crew = CREW_SCRIPT.new()
	_crew.is_beast = is_beast
	_crew.body_scale = 1.05 if is_beast else 1.0
	_stage.add_child(_crew)
	if is_beast:
		_crew.apply_colors(Color(0.55, 0.08, 0.12), Color(1.0, 0.35, 0.2), Color(0.9, 0.55, 0.1))
		_crew.set_player_name("BESTIA")
	else:
		var c: Array = SKIN_COLORS[clampi(skin, 0, 3)]
		_crew.apply_colors(c[0], c[1], c[2])
		_crew.set_player_name("ROBOT")


func show_selection(role: String, skin: int) -> void:
	_rebuild_crew(role == "beast", skin)

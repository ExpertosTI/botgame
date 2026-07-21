class_name MapBuilder
extends Node3D

## Arenas con modo lite en Web (menos luces/sombras/fog).

signal map_ready

var objectives_root: Node3D
var objective_positions: Array[Vector3] = []
var _lite := false


func build(map_id: String, objectives_parent: Node3D) -> void:
	objectives_root = objectives_parent
	_lite = OS.has_feature("web") or OS.get_name() == "Web"
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame

	match map_id:
		"containers":
			_build_containers()
		"ruins":
			_build_ruins()
		_:
			_build_lab_neon()
	map_ready.emit()


func _env(sky_top: Color, sky_h: Color, ambient: Color, fog: Color, fog_dens: float = 0.012) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_h
	sky_mat.ground_bottom_color = sky_h.darkened(0.4)
	sky_mat.ground_horizon_color = sky_h
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 1.0 if _lite else 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	# Glow/fog son caros en HTML5 / GL Compatibility
	env.glow_enabled = not _lite
	if not _lite:
		env.glow_intensity = 0.4
		env.glow_bloom = 0.1
	env.fog_enabled = not _lite
	if not _lite:
		env.fog_light_color = fog
		env.fog_density = fog_dens * 0.7
	we.environment = env
	add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, 35, 0)
	light.light_energy = 1.35 if _lite else 1.2
	light.light_color = Color(0.95, 0.97, 1.0)
	light.shadow_enabled = not _lite
	add_child(light)


func _accent_light(pos: Vector3, color: Color, energy: float = 3.0, rng: float = 10.0) -> void:
	if _lite:
		return  # emisión de neones basta en web
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = color
	o.light_energy = energy * 0.7
	o.omni_range = rng
	o.omni_attenuation = 1.6
	add_child(o)


func _neon_tube(pos: Vector3, size: Vector3, color: Color) -> void:
	var csg := CSGBox3D.new()
	csg.use_collision = false
	csg.size = size
	csg.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.2 if _lite else 4.0
	csg.material = mat
	add_child(csg)


func _floor(size: Vector3, color: Color, use_grid: bool = true) -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = 0.08
	if use_grid and not _lite:
		mat.albedo_texture = ProcTextures.grid(64, 16, color.lightened(0.35), color)
		mat.uv1_scale = Vector3(size.x * 0.35, size.z * 0.35, 1)
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = Vector3(0, -size.y * 0.5, 0)
	add_child(body)


func _wall(pos: Vector3, size: Vector3, color: Color = Color(0.18, 0.22, 0.28)) -> void:
	var csg := CSGBox3D.new()
	csg.use_collision = true
	csg.size = size
	csg.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	csg.material = mat
	add_child(csg)


func _box(pos: Vector3, size: Vector3, color: Color, metallic: float = 0.15) -> void:
	var csg := CSGBox3D.new()
	csg.use_collision = true
	csg.size = size
	csg.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.metallic = metallic
	csg.material = mat
	add_child(csg)


func _spawn(group: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.position = pos
	m.add_to_group(group)
	add_child(m)


func _set_objectives(positions: Array) -> void:
	objective_positions.clear()
	for p in positions:
		objective_positions.append(p)


func _explorer_spawns_ring(z: float = 15.0) -> void:
	# Hasta 4 robots
	_spawn("explorer_spawns", Vector3(-6, 1, z))
	_spawn("explorer_spawns", Vector3(-2, 1, z + 1.5))
	_spawn("explorer_spawns", Vector3(2, 1, z + 1.5))
	_spawn("explorer_spawns", Vector3(6, 1, z))


func _build_lab_neon() -> void:
	_env(Color(0.06, 0.1, 0.2), Color(0.2, 0.28, 0.4), Color(0.45, 0.55, 0.75), Color(0.15, 0.35, 0.45), 0.014)
	_floor(Vector3(40, 0.3, 40), Color(0.1, 0.14, 0.2))
	_wall(Vector3(0, 2, -20), Vector3(40, 4, 0.5), Color(0.12, 0.16, 0.22))
	_wall(Vector3(0, 2, 20), Vector3(40, 4, 0.5), Color(0.12, 0.16, 0.22))
	_wall(Vector3(20, 2, 0), Vector3(0.5, 4, 40), Color(0.12, 0.16, 0.22))
	_wall(Vector3(-20, 2, 0), Vector3(0.5, 4, 40), Color(0.12, 0.16, 0.22))
	_box(Vector3(-8, 1.5, -5), Vector3(2, 3, 2), Color(0.15, 0.35, 0.55), 0.4)
	_box(Vector3(8, 1.5, 5), Vector3(2, 3, 2), Color(0.15, 0.35, 0.55), 0.4)
	_box(Vector3(-6, 1, 6), Vector3(1.5, 2, 1.5), Color(0.12, 0.28, 0.45), 0.35)
	_box(Vector3(6, 1, -6), Vector3(1.5, 2, 1.5), Color(0.12, 0.28, 0.45), 0.35)
	_neon_tube(Vector3(0, 3.6, 0), Vector3(18, 0.08, 0.08), Color(0.2, 0.95, 0.9))
	_neon_tube(Vector3(-12, 3.4, -8), Vector3(0.08, 0.08, 10), Color(0.3, 0.7, 1.0))
	_accent_light(Vector3(0, 3.2, 0), Color(0.25, 0.9, 0.85), 3.0, 12.0)
	_spawn("beast_spawn", Vector3(0, 1.2, -15))
	_explorer_spawns_ring(15.0)
	_set_objectives([
		Vector3(-12, 0.5, -8), Vector3(12, 0.5, -8),
		Vector3(-12, 0.5, 8), Vector3(12, 0.5, 8), Vector3(0, 0.5, 0),
	])


func _build_containers() -> void:
	_env(Color(0.18, 0.14, 0.1), Color(0.4, 0.28, 0.18), Color(0.65, 0.52, 0.4), Color(0.35, 0.25, 0.15), 0.01)
	_floor(Vector3(48, 0.3, 36), Color(0.22, 0.2, 0.16), true)
	_wall(Vector3(0, 2.5, -18), Vector3(48, 5, 0.6), Color(0.32, 0.2, 0.14))
	_wall(Vector3(0, 2.5, 18), Vector3(48, 5, 0.6), Color(0.32, 0.2, 0.14))
	_wall(Vector3(24, 2.5, 0), Vector3(0.6, 5, 36), Color(0.32, 0.2, 0.14))
	_wall(Vector3(-24, 2.5, 0), Vector3(0.6, 5, 36), Color(0.32, 0.2, 0.14))
	var colors := [Color(0.78, 0.22, 0.16), Color(0.18, 0.42, 0.72), Color(0.85, 0.68, 0.18)]
	var step := 2 if _lite else 1
	for i in range(-3, 4, step):
		_box(Vector3(-10, 1.2, i * 4.5), Vector3(3, 2.4, 2.2), colors[abs(i) % 3], 0.25)
		_box(Vector3(10, 1.2, i * 4.5), Vector3(3, 2.4, 2.2), colors[(abs(i) + 1) % 3], 0.25)
	_box(Vector3(0, 1.2, -6), Vector3(4, 2.4, 2.5), Color(0.28, 0.5, 0.28), 0.2)
	_box(Vector3(0, 1.2, 8), Vector3(5, 2.4, 2.5), Color(0.5, 0.28, 0.4), 0.2)
	_neon_tube(Vector3(0, 4.2, 0), Vector3(20, 0.06, 0.06), Color(1.0, 0.7, 0.2))
	_accent_light(Vector3(0, 3.5, 0), Color(1.0, 0.65, 0.25), 2.8, 14.0)
	_spawn("beast_spawn", Vector3(0, 1.2, -14))
	_explorer_spawns_ring(14.0)
	_set_objectives([
		Vector3(-16, 0.5, -10), Vector3(16, 0.5, -10),
		Vector3(-16, 0.5, 10), Vector3(16, 0.5, 10), Vector3(0, 0.5, 0),
	])


func _build_ruins() -> void:
	_env(Color(0.1, 0.08, 0.16), Color(0.32, 0.22, 0.28), Color(0.5, 0.4, 0.55), Color(0.25, 0.12, 0.2), 0.016)
	_floor(Vector3(44, 0.3, 44), Color(0.18, 0.16, 0.2))
	_wall(Vector3(0, 2.5, -22), Vector3(44, 5, 0.6), Color(0.26, 0.2, 0.3))
	_wall(Vector3(0, 2.5, 22), Vector3(44, 5, 0.6), Color(0.26, 0.2, 0.3))
	_wall(Vector3(22, 2.5, 0), Vector3(0.6, 5, 44), Color(0.26, 0.2, 0.3))
	_wall(Vector3(-22, 2.5, 0), Vector3(0.6, 5, 44), Color(0.26, 0.2, 0.3))
	_box(Vector3(0, 1.5, 0), Vector3(10, 3, 10), Color(0.3, 0.25, 0.35), 0.1)
	_box(Vector3(0, 3.2, 0), Vector3(6, 0.4, 6), Color(0.45, 0.3, 0.5), 0.2)
	_box(Vector3(0, 0.5, 8), Vector3(4, 1, 3), Color(0.35, 0.3, 0.4))
	_box(Vector3(0, 1.2, 5.5), Vector3(4, 1, 2.5), Color(0.35, 0.3, 0.4))
	_box(Vector3(0, 0.5, -8), Vector3(4, 1, 3), Color(0.35, 0.3, 0.4))
	if not _lite:
		_box(Vector3(-9, 1, -4), Vector3(3, 2, 3), Color(0.4, 0.25, 0.3))
		_box(Vector3(9, 1, 4), Vector3(3, 2, 3), Color(0.4, 0.25, 0.3))
	_neon_tube(Vector3(0, 4.0, 0), Vector3(8, 0.1, 0.1), Color(0.95, 0.25, 0.55))
	_accent_light(Vector3(0, 4.2, 0), Color(0.9, 0.3, 0.55), 3.5, 10.0)
	_spawn("beast_spawn", Vector3(0, 1.2, -18))
	_explorer_spawns_ring(18.0)
	_set_objectives([
		Vector3(-14, 0.5, -12), Vector3(14, 0.5, -12),
		Vector3(-14, 0.5, 12), Vector3(14, 0.5, 12),
		Vector3(0, 3.6, 0),
	])

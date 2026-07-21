class_name MapBuilder
extends Node3D

## Arenas con atmósfera: fog, grillas, neones y luces de acento.

signal map_ready

var objectives_root: Node3D
var objective_positions: Array[Vector3] = []


func build(map_id: String, objectives_parent: Node3D) -> void:
	objectives_root = objectives_parent
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
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.15
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = fog_dens
	env.ssao_enabled = false
	we.environment = env
	add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, 35, 0)
	light.light_energy = 1.25
	light.light_color = Color(0.95, 0.97, 1.0)
	light.shadow_enabled = true
	add_child(light)


func _accent_light(pos: Vector3, color: Color, energy: float = 3.0, rng: float = 10.0) -> void:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = rng
	o.omni_attenuation = 1.4
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
	mat.emission_energy_multiplier = 4.5
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
	if use_grid:
		mat.albedo_texture = ProcTextures.grid(128, 16, color.lightened(0.35), color)
		mat.uv1_scale = Vector3(size.x * 0.5, size.z * 0.5, 1)
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = Vector3(0, -size.y * 0.5, 0)
	add_child(body)


func _wall(pos: Vector3, size: Vector3, color: Color = Color(0.18, 0.22, 0.28), emissive: bool = false) -> void:
	var csg := CSGBox3D.new()
	csg.use_collision = true
	csg.size = size
	csg.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.6
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


func _build_lab_neon() -> void:
	_env(Color(0.06, 0.1, 0.2), Color(0.2, 0.28, 0.4), Color(0.45, 0.55, 0.75), Color(0.15, 0.35, 0.45), 0.014)
	_floor(Vector3(40, 0.3, 40), Color(0.1, 0.14, 0.2))
	_wall(Vector3(0, 2, -20), Vector3(40, 4, 0.5), Color(0.12, 0.16, 0.22))
	_wall(Vector3(0, 2, 20), Vector3(40, 4, 0.5), Color(0.12, 0.16, 0.22))
	_wall(Vector3(20, 2, 0), Vector3(0.5, 4, 40), Color(0.12, 0.16, 0.22))
	_wall(Vector3(-20, 2, 0), Vector3(0.5, 4, 40), Color(0.12, 0.16, 0.22))
	# Columnas + neones
	_box(Vector3(-8, 1.5, -5), Vector3(2, 3, 2), Color(0.15, 0.35, 0.55), 0.4)
	_box(Vector3(8, 1.5, 5), Vector3(2, 3, 2), Color(0.15, 0.35, 0.55), 0.4)
	_box(Vector3(-6, 1, 6), Vector3(1.5, 2, 1.5), Color(0.12, 0.28, 0.45), 0.35)
	_box(Vector3(6, 1, -6), Vector3(1.5, 2, 1.5), Color(0.12, 0.28, 0.45), 0.35)
	_neon_tube(Vector3(0, 3.6, 0), Vector3(18, 0.08, 0.08), Color(0.2, 0.95, 0.9))
	_neon_tube(Vector3(-12, 3.4, -8), Vector3(0.08, 0.08, 10), Color(0.3, 0.7, 1.0))
	_neon_tube(Vector3(12, 3.4, 8), Vector3(0.08, 0.08, 10), Color(0.3, 0.7, 1.0))
	_accent_light(Vector3(0, 3.2, 0), Color(0.25, 0.9, 0.85), 4.0, 14.0)
	_accent_light(Vector3(-10, 2.5, -6), Color(0.2, 0.5, 1.0), 2.5, 9.0)
	_accent_light(Vector3(10, 2.5, 6), Color(0.2, 0.5, 1.0), 2.5, 9.0)
	_spawn("beast_spawn", Vector3(0, 1.2, -15))
	_spawn("explorer_spawns", Vector3(-5, 1, 15))
	_spawn("explorer_spawns", Vector3(0, 1, 17))
	_spawn("explorer_spawns", Vector3(5, 1, 15))
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
	for i in range(-3, 4):
		_box(Vector3(-10, 1.2, i * 4.5), Vector3(3, 2.4, 2.2), colors[abs(i) % 3], 0.25)
		_box(Vector3(10, 1.2, i * 4.5), Vector3(3, 2.4, 2.2), colors[(abs(i) + 1) % 3], 0.25)
	_box(Vector3(0, 1.2, -6), Vector3(4, 2.4, 2.5), Color(0.28, 0.5, 0.28), 0.2)
	_box(Vector3(0, 1.2, 8), Vector3(5, 2.4, 2.5), Color(0.5, 0.28, 0.4), 0.2)
	_neon_tube(Vector3(0, 4.2, 0), Vector3(20, 0.06, 0.06), Color(1.0, 0.7, 0.2))
	_accent_light(Vector3(0, 3.5, 0), Color(1.0, 0.65, 0.25), 3.5, 16.0)
	_accent_light(Vector3(-10, 2.8, 0), Color(1.0, 0.35, 0.2), 2.0, 8.0)
	_spawn("beast_spawn", Vector3(0, 1.2, -14))
	_spawn("explorer_spawns", Vector3(-8, 1, 14))
	_spawn("explorer_spawns", Vector3(0, 1, 15))
	_spawn("explorer_spawns", Vector3(8, 1, 14))
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
	_box(Vector3(-9, 1, -4), Vector3(3, 2, 3), Color(0.4, 0.25, 0.3))
	_box(Vector3(9, 1, 4), Vector3(3, 2, 3), Color(0.4, 0.25, 0.3))
	_neon_tube(Vector3(0, 4.0, 0), Vector3(8, 0.1, 0.1), Color(0.95, 0.25, 0.55))
	_accent_light(Vector3(0, 4.2, 0), Color(0.9, 0.3, 0.55), 4.5, 12.0)
	_accent_light(Vector3(-8, 2.0, -6), Color(0.6, 0.2, 0.4), 2.0, 8.0)
	_spawn("beast_spawn", Vector3(0, 1.2, -18))
	_spawn("explorer_spawns", Vector3(-6, 1, 18))
	_spawn("explorer_spawns", Vector3(0, 1, 19))
	_spawn("explorer_spawns", Vector3(6, 1, 18))
	_set_objectives([
		Vector3(-14, 0.5, -12), Vector3(14, 0.5, -12),
		Vector3(-14, 0.5, 12), Vector3(14, 0.5, 12),
		Vector3(0, 3.6, 0),
	])

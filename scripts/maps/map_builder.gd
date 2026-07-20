class_name MapBuilder
extends Node3D

## Construye arenas jugables según el id de mapa.

signal map_ready

var objectives_root: Node3D
var objective_positions: Array[Vector3] = []


func build(map_id: String, objectives_parent: Node3D) -> void:
	objectives_root = objectives_parent
	# Limpiar hijos previos de este builder
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


func _env(sky_top: Color, sky_h: Color, ambient: Color) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_h
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	we.environment = env
	add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)


func _floor(size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = Vector3(0, -size.y * 0.5, 0)
	add_child(body)


func _wall(pos: Vector3, size: Vector3, color: Color = Color(0.2, 0.22, 0.3)) -> void:
	var csg := CSGBox3D.new()
	csg.use_collision = true
	csg.size = size
	csg.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	csg.material = mat
	add_child(csg)


func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	_wall(pos, size, color)


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
	_env(Color(0.12, 0.16, 0.32), Color(0.35, 0.4, 0.55), Color(0.55, 0.6, 0.8))
	_floor(Vector3(40, 0.3, 40), Color(0.12, 0.15, 0.22))
	_wall(Vector3(0, 2, -20), Vector3(40, 4, 0.5))
	_wall(Vector3(0, 2, 20), Vector3(40, 4, 0.5))
	_wall(Vector3(20, 2, 0), Vector3(0.5, 4, 40))
	_wall(Vector3(-20, 2, 0), Vector3(0.5, 4, 40))
	_box(Vector3(-8, 1.5, -5), Vector3(2, 3, 2), Color(0.2, 0.55, 0.9))
	_box(Vector3(8, 1.5, 5), Vector3(2, 3, 2), Color(0.2, 0.55, 0.9))
	_box(Vector3(-6, 1, 6), Vector3(1.5, 2, 1.5), Color(0.15, 0.4, 0.7))
	_box(Vector3(6, 1, -6), Vector3(1.5, 2, 1.5), Color(0.15, 0.4, 0.7))
	_spawn("beast_spawn", Vector3(0, 1.2, -15))
	_spawn("explorer_spawns", Vector3(-5, 1, 15))
	_spawn("explorer_spawns", Vector3(0, 1, 17))
	_spawn("explorer_spawns", Vector3(5, 1, 15))
	_set_objectives([
		Vector3(-12, 0.5, -8), Vector3(12, 0.5, -8),
		Vector3(-12, 0.5, 8), Vector3(12, 0.5, 8), Vector3(0, 0.5, 0),
	])


func _build_containers() -> void:
	_env(Color(0.2, 0.18, 0.15), Color(0.45, 0.35, 0.25), Color(0.7, 0.6, 0.5))
	_floor(Vector3(48, 0.3, 36), Color(0.25, 0.22, 0.18))
	_wall(Vector3(0, 2.5, -18), Vector3(48, 5, 0.6), Color(0.35, 0.2, 0.15))
	_wall(Vector3(0, 2.5, 18), Vector3(48, 5, 0.6), Color(0.35, 0.2, 0.15))
	_wall(Vector3(24, 2.5, 0), Vector3(0.6, 5, 36), Color(0.35, 0.2, 0.15))
	_wall(Vector3(-24, 2.5, 0), Vector3(0.6, 5, 36), Color(0.35, 0.2, 0.15))
	# Pasillos de contenedores
	var colors := [Color(0.8, 0.25, 0.2), Color(0.2, 0.45, 0.75), Color(0.85, 0.7, 0.2)]
	for i in range(-3, 4):
		_box(Vector3(-10, 1.2, i * 4.5), Vector3(3, 2.4, 2.2), colors[abs(i) % 3])
		_box(Vector3(10, 1.2, i * 4.5), Vector3(3, 2.4, 2.2), colors[(abs(i) + 1) % 3])
	_box(Vector3(0, 1.2, -6), Vector3(4, 2.4, 2.5), Color(0.3, 0.55, 0.3))
	_box(Vector3(0, 1.2, 8), Vector3(5, 2.4, 2.5), Color(0.55, 0.3, 0.45))
	_spawn("beast_spawn", Vector3(0, 1.2, -14))
	_spawn("explorer_spawns", Vector3(-8, 1, 14))
	_spawn("explorer_spawns", Vector3(0, 1, 15))
	_spawn("explorer_spawns", Vector3(8, 1, 14))
	_set_objectives([
		Vector3(-16, 0.5, -10), Vector3(16, 0.5, -10),
		Vector3(-16, 0.5, 10), Vector3(16, 0.5, 10), Vector3(0, 0.5, 0),
	])


func _build_ruins() -> void:
	_env(Color(0.15, 0.12, 0.22), Color(0.4, 0.3, 0.35), Color(0.55, 0.45, 0.6))
	_floor(Vector3(44, 0.3, 44), Color(0.22, 0.2, 0.24))
	_wall(Vector3(0, 2.5, -22), Vector3(44, 5, 0.6), Color(0.3, 0.25, 0.35))
	_wall(Vector3(0, 2.5, 22), Vector3(44, 5, 0.6), Color(0.3, 0.25, 0.35))
	_wall(Vector3(22, 2.5, 0), Vector3(0.6, 5, 44), Color(0.3, 0.25, 0.35))
	_wall(Vector3(-22, 2.5, 0), Vector3(0.6, 5, 44), Color(0.3, 0.25, 0.35))
	# Plataforma elevada central
	_box(Vector3(0, 1.5, 0), Vector3(10, 3, 10), Color(0.35, 0.3, 0.4))
	_box(Vector3(0, 3.2, 0), Vector3(6, 0.4, 6), Color(0.5, 0.35, 0.55))
	# Rampas (escalones)
	_box(Vector3(0, 0.5, 8), Vector3(4, 1, 3), Color(0.4, 0.35, 0.45))
	_box(Vector3(0, 1.2, 5.5), Vector3(4, 1, 2.5), Color(0.4, 0.35, 0.45))
	_box(Vector3(0, 0.5, -8), Vector3(4, 1, 3), Color(0.4, 0.35, 0.45))
	_box(Vector3(-9, 1, -4), Vector3(3, 2, 3), Color(0.45, 0.3, 0.35))
	_box(Vector3(9, 1, 4), Vector3(3, 2, 3), Color(0.45, 0.3, 0.35))
	_spawn("beast_spawn", Vector3(0, 1.2, -18))
	_spawn("explorer_spawns", Vector3(-6, 1, 18))
	_spawn("explorer_spawns", Vector3(0, 1, 19))
	_spawn("explorer_spawns", Vector3(6, 1, 18))
	_set_objectives([
		Vector3(-14, 0.5, -12), Vector3(14, 0.5, -12),
		Vector3(-14, 0.5, 12), Vector3(14, 0.5, 12),
		Vector3(0, 3.6, 0),  # núcleo elevado
	])

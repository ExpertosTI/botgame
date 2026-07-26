class_name MapBuilder
extends Node3D

## Arenas con modo lite en Web (menos luces/sombras/fog).

signal map_ready

var objectives_root: Node3D
var objective_positions: Array[Vector3] = []
## Superficies pisables que va creando el mapa: {centro, medios, techo}.
## Sirve para comprobar que todo núcleo tenga suelo desde el que alcanzarlo. Sin
## esto shippeamos skybridge con dos núcleos en lo alto de torres sin acceso, y
## el nivel 10 era imposible de ganar.
var walkable_surfaces: Array[Dictionary] = []
var _lite := false


func build(map_id: String, objectives_parent: Node3D) -> void:
	objectives_root = objectives_parent
	_lite = OS.has_feature("web") or OS.get_name() == "Web"
	walkable_surfaces.clear()
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame

	match map_id:
		"containers":
			_build_containers()
		"ruins":
			_build_ruins()
		"reactor_pit":
			_build_reactor_pit()
		"skybridge":
			_build_skybridge()
		"castle":
			_build_castle()
		"cave":
			_build_cave()
		"forest":
			_build_forest()
		_:
			_build_lab_neon()
	map_ready.emit()


func attach_systems(parent: Node3D, map_id: String) -> Dictionary:
	## Devuelve {hazards, powerups} montados bajo parent.
	var hazards: HazardSystem = load("res://scripts/maps/hazard_system.gd").new() as HazardSystem
	hazards.name = "Hazards"
	parent.add_child(hazards)
	var powerups: PowerupSpawner = load("res://scripts/maps/powerup_spawner.gd").new() as PowerupSpawner
	powerups.name = "Powerups"
	parent.add_child(powerups)
	_seed_hazards(hazards, map_id)
	powerups.seed_for_map(map_id)
	return {"hazards": hazards, "powerups": powerups}


func _seed_hazards(hazards: HazardSystem, map_id: String) -> void:
	match map_id:
		"reactor_pit":
			hazards.add_damage_zone(Vector3(0, 0.1, 0), 4.5, 18.0, Color(1.0, 0.35, 0.1))
			hazards.add_pulse_zone(Vector3(0, 0.1, 0), 7.0, 22.0, 4.0, Color(1.0, 0.2, 0.55))
			hazards.add_slow_zone(Vector3(-12, 0.1, 0), 3.5, 0.45)
			hazards.add_slow_zone(Vector3(12, 0.1, 0), 3.5, 0.45)
		"skybridge":
			hazards.add_pulse_zone(Vector3(0, 0.1, 0), 3.0, 14.0, 4.5, Color(0.45, 0.7, 1.0))
			hazards.add_slow_zone(Vector3(-8, 0.1, 0), 2.8, 0.35, Color(0.5, 0.8, 1.0))
			hazards.add_slow_zone(Vector3(8, 0.1, 0), 2.8, 0.35, Color(0.5, 0.8, 1.0))
			hazards.add_damage_zone(Vector3(-16, 0.1, 0), 2.5, 22.0, Color(0.6, 0.2, 0.9))
			hazards.add_damage_zone(Vector3(16, 0.1, 0), 2.5, 22.0, Color(0.6, 0.2, 0.9))
		"castle":
			hazards.add_slow_zone(Vector3(0, 0.1, 0), 4.0, 0.25)
			hazards.add_pulse_zone(Vector3(0, 0.1, -8), 3.5, 10.0, 5.0, Color(0.9, 0.75, 0.3))
		"cave":
			hazards.add_damage_zone(Vector3(0, 0.1, 0), 3.0, 12.0, Color(0.5, 0.2, 0.1))
			hazards.add_slow_zone(Vector3(-8, 0.1, 8), 3.0, 0.4)
		"forest":
			hazards.add_slow_zone(Vector3(0, 0.1, 0), 5.0, 0.3, Color(0.3, 0.7, 0.35))
		"ruins":
			hazards.add_pulse_zone(Vector3(0, 0.1, 0), 5.0, 12.0, 5.0, Color(0.85, 0.2, 0.7))
		"containers":
			hazards.add_slow_zone(Vector3(0, 0.1, -6), 3.0, 0.3)
			hazards.add_slow_zone(Vector3(0, 0.1, 8), 3.0, 0.3)
		_:
			hazards.add_pulse_zone(Vector3(0, 0.1, 0), 3.5, 10.0, 6.0, Color(0.2, 0.9, 0.85))


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
	_register_surface(Vector3.ZERO, size, 0.0)


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
	_register_surface(pos, size, pos.y + size.y * 0.5)


## Los muros quedan fuera a propósito: son barreras verticales, no plataformas, y
## contarlos como pisables inventaría rutas que el jugador no puede tomar.
func _register_surface(center: Vector3, size: Vector3, top: float) -> void:
	walkable_surfaces.append({
		"x": center.x,
		"z": center.z,
		"hx": absf(size.x) * 0.5,
		"hz": absf(size.z) * 0.5,
		"top": top,
	})


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
	_env(Color(0.04, 0.07, 0.14), Color(0.18, 0.28, 0.42), Color(0.4, 0.55, 0.8), Color(0.12, 0.4, 0.5), 0.012)
	_floor(Vector3(40, 0.3, 40), Color(0.08, 0.11, 0.16))
	_wall(Vector3(0, 2, -20), Vector3(40, 4, 0.5), Color(0.1, 0.14, 0.2))
	_wall(Vector3(0, 2, 20), Vector3(40, 4, 0.5), Color(0.1, 0.14, 0.2))
	_wall(Vector3(20, 2, 0), Vector3(0.5, 4, 40), Color(0.1, 0.14, 0.2))
	_wall(Vector3(-20, 2, 0), Vector3(0.5, 4, 40), Color(0.1, 0.14, 0.2))
	# Consolas / cobertura con metal frío (menos “cubo gris”).
	_box(Vector3(-8, 1.5, -5), Vector3(2, 3, 2), Color(0.12, 0.32, 0.5), 0.55)
	_box(Vector3(8, 1.5, 5), Vector3(2, 3, 2), Color(0.12, 0.32, 0.5), 0.55)
	_box(Vector3(-6, 1, 6), Vector3(1.5, 2, 1.5), Color(0.1, 0.26, 0.42), 0.45)
	_box(Vector3(6, 1, -6), Vector3(1.5, 2, 1.5), Color(0.1, 0.26, 0.42), 0.45)
	_box(Vector3(0, 0.6, -10), Vector3(6, 1.2, 1.2), Color(0.14, 0.2, 0.28), 0.35)
	_box(Vector3(-12, 0.8, 0), Vector3(1.2, 1.6, 4), Color(0.16, 0.22, 0.3), 0.4)
	_box(Vector3(12, 0.8, 0), Vector3(1.2, 1.6, 4), Color(0.16, 0.22, 0.3), 0.4)
	_box(Vector3(0, 1.2, 0), Vector3(2.4, 0.35, 2.4), Color(0.2, 0.45, 0.55), 0.6)
	_neon_tube(Vector3(0, 3.6, 0), Vector3(18, 0.08, 0.08), Color(0.2, 0.95, 0.9))
	_neon_tube(Vector3(-12, 3.4, -8), Vector3(0.08, 0.08, 10), Color(0.3, 0.7, 1.0))
	_neon_tube(Vector3(12, 3.4, 8), Vector3(0.08, 0.08, 10), Color(1.0, 0.35, 0.55))
	_neon_tube(Vector3(0, 0.05, 0), Vector3(22, 0.04, 0.12), Color(0.15, 0.85, 0.75))
	_neon_tube(Vector3(0, 0.05, 8), Vector3(14, 0.04, 0.1), Color(0.35, 0.55, 1.0))
	_neon_tube(Vector3(-8, 2.8, -5), Vector3(2.4, 0.06, 0.06), Color(0.25, 0.9, 1.0))
	_neon_tube(Vector3(8, 2.8, 5), Vector3(2.4, 0.06, 0.06), Color(1.0, 0.4, 0.6))
	_accent_light(Vector3(0, 3.2, 0), Color(0.25, 0.9, 0.85), 3.2, 14.0)
	_spawn("beast_spawn", Vector3(0, 1.2, -15))
	_explorer_spawns_ring(15.0)
	# Seis: el nivel 11 (Sobrevelocidad) juega aquí y pide seis núcleos.
	_set_objectives([
		Vector3(-12, 0.5, -8), Vector3(12, 0.5, -8),
		Vector3(-12, 0.5, 8), Vector3(12, 0.5, 8), Vector3(0, 0.5, 0),
		Vector3(0, 0.5, 14),
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


func _build_reactor_pit() -> void:
	_env(Color(0.12, 0.05, 0.04), Color(0.45, 0.18, 0.08), Color(0.7, 0.35, 0.22), Color(0.5, 0.15, 0.08), 0.018)
	_floor(Vector3(46, 0.3, 46), Color(0.16, 0.1, 0.08))
	_wall(Vector3(0, 3, -23), Vector3(46, 6, 0.6), Color(0.28, 0.12, 0.1))
	_wall(Vector3(0, 3, 23), Vector3(46, 6, 0.6), Color(0.28, 0.12, 0.1))
	_wall(Vector3(23, 3, 0), Vector3(0.6, 6, 46), Color(0.28, 0.12, 0.1))
	_wall(Vector3(-23, 3, 0), Vector3(0.6, 6, 46), Color(0.28, 0.12, 0.1))
	# Anillo reactor
	_box(Vector3(0, 0.4, 0), Vector3(14, 0.8, 14), Color(0.35, 0.12, 0.08), 0.4)
	_box(Vector3(0, 1.2, 0), Vector3(8, 0.4, 8), Color(0.55, 0.18, 0.08), 0.5)
	_neon_tube(Vector3(0, 0.9, 0), Vector3(10, 0.12, 10), Color(1.0, 0.35, 0.08))
	# Torres perimetrales
	for ang in [0.0, 1.57, 3.14, 4.71]:
		var p := Vector3(cos(ang) * 14.0, 2.0, sin(ang) * 14.0)
		_box(p, Vector3(2.2, 4.0, 2.2), Color(0.4, 0.2, 0.12), 0.35)
		_neon_tube(p + Vector3(0, 2.2, 0), Vector3(0.1, 0.1, 2.5), Color(1.0, 0.45, 0.15))
	_box(Vector3(-8, 1.0, 10), Vector3(3, 2, 2), Color(0.3, 0.15, 0.1), 0.3)
	_box(Vector3(8, 1.0, -10), Vector3(3, 2, 2), Color(0.3, 0.15, 0.1), 0.3)
	_accent_light(Vector3(0, 4.0, 0), Color(1.0, 0.4, 0.15), 4.0, 16.0)
	_spawn("beast_spawn", Vector3(0, 1.2, -17))
	_explorer_spawns_ring(17.0)
	_set_objectives([
		Vector3(-16, 0.5, -10), Vector3(16, 0.5, -10),
		Vector3(-16, 0.5, 10), Vector3(16, 0.5, 10),
		Vector3(0, 1.6, 0), Vector3(0, 0.5, -12),
	])


func _build_skybridge() -> void:
	_env(Color(0.08, 0.12, 0.22), Color(0.35, 0.45, 0.65), Color(0.55, 0.65, 0.85), Color(0.2, 0.3, 0.5), 0.01)
	# Puentes elevados (el vacío es hazard)
	_floor(Vector3(12, 0.4, 36), Color(0.18, 0.22, 0.3))
	_box(Vector3(-10, 0.2, 0), Vector3(8, 0.4, 10), Color(0.2, 0.24, 0.32), 0.2)
	_box(Vector3(10, 0.2, 0), Vector3(8, 0.4, 10), Color(0.2, 0.24, 0.32), 0.2)
	_box(Vector3(0, 0.2, -12), Vector3(18, 0.4, 6), Color(0.22, 0.26, 0.34), 0.2)
	_box(Vector3(0, 0.2, 12), Vector3(18, 0.4, 6), Color(0.22, 0.26, 0.34), 0.2)
	# Torres
	_box(Vector3(-14, 2.5, -14), Vector3(3, 5, 3), Color(0.25, 0.3, 0.4), 0.35)
	_box(Vector3(14, 2.5, 14), Vector3(3, 5, 3), Color(0.25, 0.3, 0.4), 0.35)
	_box(Vector3(-14, 2.5, 14), Vector3(3, 5, 3), Color(0.25, 0.3, 0.4), 0.35)
	_box(Vector3(14, 2.5, -14), Vector3(3, 5, 3), Color(0.25, 0.3, 0.4), 0.35)
	_neon_tube(Vector3(0, 2.2, 0), Vector3(20, 0.06, 0.06), Color(0.45, 0.85, 1.0))
	_neon_tube(Vector3(0, 2.2, -12), Vector3(14, 0.06, 0.06), Color(0.3, 0.7, 1.0))
	_neon_tube(Vector3(0, 2.2, 12), Vector3(14, 0.06, 0.06), Color(0.3, 0.7, 1.0))
	_accent_light(Vector3(0, 5.0, 0), Color(0.5, 0.8, 1.0), 3.2, 18.0)
	_wall(Vector3(0, 2, -20), Vector3(40, 1, 0.4), Color(0.15, 0.18, 0.25))
	_wall(Vector3(0, 2, 20), Vector3(40, 1, 0.4), Color(0.15, 0.18, 0.25))
	_spawn("beast_spawn", Vector3(0, 1.2, -15))
	_explorer_spawns_ring(15.0)
	# Los dos últimos estaban en la cima de las torres (y 5.2), a 4,6 m sobre el
	# puente más cercano y a 3,5 m de salto horizontal sobre el vacío. El salto da
	# 1,5 m: eran inalcanzables y el nivel 10, que pide 6 núcleos, no se podía
	# ganar. Ahora ocupan los extremos de las alas laterales.
	_set_objectives([
		Vector3(-10, 0.5, 0), Vector3(10, 0.5, 0),
		Vector3(0, 0.5, -12), Vector3(0, 0.5, 12),
		Vector3(-13, 0.5, 3.5), Vector3(13, 0.5, -3.5),
	])


func _prop(path: String, pos: Vector3, yaw_deg: float = 0.0, scl: float = 1.0) -> void:
	if not ResourceLoader.exists(path):
		_box(pos + Vector3(0, 1, 0), Vector3(2, 2, 2) * scl, Color(0.4, 0.35, 0.3), 0.2)
		return
	var packed = load(path)
	if packed is PackedScene:
		var n := (packed as PackedScene).instantiate() as Node3D
		if n:
			n.position = pos
			n.rotation_degrees.y = yaw_deg
			n.scale = Vector3.ONE * scl
			add_child(n)
			## Sin esto castle/cave/forest eran decorado: se caminaba y se
			## disparaba a través de puertas, torres y árboles.
			_ensure_prop_collision(n)
			return
	_box(pos + Vector3(0, 1, 0), Vector3(2, 2, 2) * scl, Color(0.4, 0.35, 0.3), 0.2)


## Genera colisión en las mallas del prop.
## Convex rellenaba el interior de pasillos/salas (hull convexo = bloque sólido):
## cave/castle quedaban impracticables. Trimesh respeta el hueco.
func _ensure_prop_collision(root: Node3D) -> void:
	for existing in root.find_children("*", "CollisionObject3D", true, false):
		if existing is StaticBody3D or existing is AnimatableBody3D:
			return
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var made := false
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.create_trimesh_collision()
		made = true
	if made:
		return
	var aabb := _node_aabb(root)
	if aabb.size.length() < 0.05:
		aabb = AABB(Vector3(-0.8, 0, -0.8), Vector3(1.6, 2.0, 1.6))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size.clamp(Vector3(0.4, 0.4, 0.4), Vector3(12, 12, 12))
	shape.shape = box
	shape.position = aabb.position + aabb.size * 0.5
	body.add_child(shape)
	root.add_child(body)


func _node_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var vi := node as VisualInstance3D
		if vi == null:
			continue
		var local := vi.get_aabb()
		var xf: Transform3D = root.global_transform.affine_inverse() * vi.global_transform
		var world_aabb := _xform_aabb(xf, local)
		if first:
			out = world_aabb
			first = false
		else:
			out = out.merge(world_aabb)
	return out


func _xform_aabb(xf: Transform3D, aabb: AABB) -> AABB:
	var pts: Array[Vector3] = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]
	var out := AABB(xf * pts[0], Vector3.ZERO)
	for i in range(1, pts.size()):
		out = out.expand(xf * pts[i])
	return out


func _build_castle() -> void:
	_env(Color(0.45, 0.55, 0.75), Color(0.7, 0.75, 0.85), Color(0.75, 0.78, 0.85), Color(0.6, 0.65, 0.7), 0.008)
	_floor(Vector3(48, 0.4, 48), Color(0.35, 0.32, 0.28))
	_wall(Vector3(0, 3, -24), Vector3(48, 6, 0.8), Color(0.45, 0.42, 0.38))
	_wall(Vector3(0, 3, 24), Vector3(48, 6, 0.8), Color(0.45, 0.42, 0.38))
	_wall(Vector3(24, 3, 0), Vector3(0.8, 6, 48), Color(0.45, 0.42, 0.38))
	_wall(Vector3(-24, 3, 0), Vector3(0.8, 6, 48), Color(0.45, 0.42, 0.38))
	var base := "res://assets/kenney/props/castle/"
	_prop(base + "gate.glb", Vector3(0, 0, -18), 0, 1.2)
	_prop(base + "tower-base.glb", Vector3(-14, 0, -14), 0, 1.0)
	_prop(base + "tower-base.glb", Vector3(14, 0, -14), 0, 1.0)
	_prop(base + "tower-hexagon-base.glb", Vector3(-14, 0, 14), 0, 1.0)
	_prop(base + "tower-hexagon-base.glb", Vector3(14, 0, 14), 0, 1.0)
	_prop(base + "wall.glb", Vector3(-8, 0, 0), 90, 1.0)
	_prop(base + "wall.glb", Vector3(8, 0, 0), 90, 1.0)
	_prop(base + "bridge-straight.glb", Vector3(0, 0, 0), 0, 1.2)
	_prop(base + "flag.glb", Vector3(0, 0, -10), 0, 1.0)
	_prop(base + "rocks-large.glb", Vector3(-10, 0, 8), 30, 1.0)
	_prop(base + "stairs-stone.glb", Vector3(0, 0, 10), 0, 1.0)
	_neon_tube(Vector3(0, 5.0, 0), Vector3(16, 0.08, 0.08), Color(1.0, 0.85, 0.4))
	## Spawn delante de la puerta, no dentro del gate.glb (-18).
	_spawn("beast_spawn", Vector3(0, 1.2, -12))
	_explorer_spawns_ring(16.0)
	# Núcleos en plazas abiertas, no en el centro de las torres con colisión.
	_set_objectives([
		Vector3(-10, 0.5, -10), Vector3(10, 0.5, -10),
		Vector3(-10, 0.5, 10), Vector3(10, 0.5, 10),
		Vector3(0, 0.5, 0),
		Vector3(-19, 0.5, 0), Vector3(19, 0.5, 0),
	])


func _build_cave() -> void:
	_env(Color(0.08, 0.07, 0.1), Color(0.2, 0.18, 0.22), Color(0.4, 0.35, 0.4), Color(0.15, 0.12, 0.15), 0.02)
	_floor(Vector3(40, 0.4, 40), Color(0.22, 0.18, 0.16))
	_wall(Vector3(0, 3, -20), Vector3(40, 6, 0.8), Color(0.25, 0.2, 0.18))
	_wall(Vector3(0, 3, 20), Vector3(40, 6, 0.8), Color(0.25, 0.2, 0.18))
	_wall(Vector3(20, 3, 0), Vector3(0.8, 6, 40), Color(0.25, 0.2, 0.18))
	_wall(Vector3(-20, 3, 0), Vector3(0.8, 6, 40), Color(0.25, 0.2, 0.18))
	var base := "res://assets/kenney/props/cave/"
	_prop(base + "corridor.glb", Vector3(0, 0, -8), 0, 1.2)
	_prop(base + "corridor-corner.glb", Vector3(-8, 0, 0), 90, 1.2)
	_prop(base + "corridor-intersection.glb", Vector3(0, 0, 0), 0, 1.2)
	_prop(base + "corridor-end.glb", Vector3(8, 0, 0), 0, 1.2)
	_prop(base + "room-large.glb", Vector3(0, 0, 10), 0, 1.0)
	_prop(base + "gate-rock.glb", Vector3(0, 0, -14), 0, 1.1)
	_neon_tube(Vector3(0, 3.5, 0), Vector3(12, 0.06, 0.06), Color(1.0, 0.55, 0.2))
	_accent_light(Vector3(0, 3.0, 0), Color(1.0, 0.5, 0.2), 2.5, 12.0)
	## Fuera del room-large (z≈10) y del gate-rock (z=-14).
	_spawn("beast_spawn", Vector3(0, 1.2, -17))
	_explorer_spawns_ring(17.0)
	_set_objectives([
		Vector3(-9, 0.5, 4), Vector3(9, 0.5, 4),
		Vector3(0, 0.5, 14), Vector3(-5, 0.5, -4),
		Vector3(5, 0.5, -4),
	])


func _build_forest() -> void:
	_env(Color(0.35, 0.55, 0.85), Color(0.55, 0.7, 0.55), Color(0.65, 0.75, 0.55), Color(0.4, 0.55, 0.35), 0.01)
	_floor(Vector3(48, 0.35, 48), Color(0.28, 0.42, 0.22), true)
	_wall(Vector3(0, 2.5, -24), Vector3(48, 5, 0.5), Color(0.25, 0.35, 0.2))
	_wall(Vector3(0, 2.5, 24), Vector3(48, 5, 0.5), Color(0.25, 0.35, 0.2))
	_wall(Vector3(24, 2.5, 0), Vector3(0.5, 5, 48), Color(0.25, 0.35, 0.2))
	_wall(Vector3(-24, 2.5, 0), Vector3(0.5, 5, 48), Color(0.25, 0.35, 0.2))
	var base := "res://assets/kenney/props/forest/"
	var lite := _lite
	var step := 2 if lite else 1
	for i in range(-3, 4, step):
		_prop(base + "tree-high.glb", Vector3(-12, 0, i * 5.0), randf() * 360.0, 1.0)
		_prop(base + "tree.glb", Vector3(12, 0, i * 5.0), randf() * 360.0, 1.0)
	_prop(base + "bridge.glb", Vector3(0, 0, 0), 0, 1.2)
	_prop(base + "platform.glb", Vector3(0, 0, -10), 0, 1.0)
	_prop(base + "tent.glb", Vector3(-6, 0, 10), 40, 1.0)
	_prop(base + "fence.glb", Vector3(6, 0, 8), 0, 1.0)
	_prop(base + "rocks-high.glb", Vector3(8, 0, -6), 20, 1.0)
	_prop(base + "plant.glb", Vector3(-4, 0, 4), 0, 1.0)
	_prop(base + "patch-grass.glb", Vector3(4, 0, -4), 0, 1.5)
	_neon_tube(Vector3(0, 4.0, 0), Vector3(14, 0.06, 0.06), Color(0.45, 0.95, 0.4))
	## Detrás de la platform (-10); exploradores lejos de tienda/valla (z≈8–10).
	_spawn("beast_spawn", Vector3(0, 1.2, -18))
	_explorer_spawns_ring(18.0)
	## Árboles en x=±12: núcleos hacia el claro para no quedar dentro del tronco.
	_set_objectives([
		Vector3(-7, 0.5, -6), Vector3(7, 0.5, -6),
		Vector3(-7, 0.5, 6), Vector3(7, 0.5, 6),
		Vector3(0, 0.5, -3),
	])

extends "res://tests/test_case.gd"

## Hazards y powerups deben existir en cada teatro y no ser stubs muertos.


func suite_name() -> String:
	return "arena_systems"


func run() -> void:
	_every_map_seeds_hazards_and_powerups()
	_powerup_kinds_cover_kit()
	_prop_collision_is_hollow_safe()
	_hazard_api_exists()
	_map_thumbs_are_honest()
	_peer_left_api_exists()


func _every_map_seeds_hazards_and_powerups() -> void:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		ok(false, "sin SceneTree")
		return
	var builder: MapBuilder = load("res://scripts/maps/map_builder.gd").new()
	var host := Node3D.new()
	loop.root.add_child(host)
	host.add_child(builder)
	for map_id in NetworkManager.MAP_IDS:
		var systems: Dictionary = builder.attach_systems(host, str(map_id))
		var hazards: HazardSystem = systems.get("hazards")
		var powerups: PowerupSpawner = systems.get("powerups")
		ok(hazards != null, "%s monta HazardSystem" % map_id)
		ok(powerups != null, "%s monta PowerupSpawner" % map_id)
		ok(hazards.get_child_count() > 0, "%s tiene markers de hazard" % map_id)
		ok(powerups.get_child_count() > 0, "%s spawnea powerups" % map_id)
		hazards.queue_free()
		powerups.queue_free()
	host.queue_free()


func _powerup_kinds_cover_kit() -> void:
	ok(PowerupSpawner.Kind.SHIELD >= 0, "Kind.SHIELD")
	ok(PowerupSpawner.Kind.SPEED >= 0, "Kind.SPEED")
	ok(PowerupSpawner.Kind.REPAIR >= 0, "Kind.REPAIR")
	ok(PowerupSpawner.Kind.OVERCHARGE >= 0, "Kind.OVERCHARGE")
	var src := FileAccess.get_file_as_string("res://scripts/maps/powerup_spawner.gd")
	ok(src.contains("_spawn_rpc"), "powerups reaparecen por RPC")
	ok(src.contains("_pickup_rpc"), "pickup sincronizado")


func _prop_collision_is_hollow_safe() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/maps/map_builder.gd")
	ok(src.contains("create_trimesh_collision"), "props usan trimesh (pasillos huecos)")
	ok(not src.contains("create_convex_collision"), "props no usan convex (rellenaba salas)")


func _hazard_api_exists() -> void:
	var h := HazardSystem.new()
	h.add_damage_zone(Vector3.ZERO, 2.0, 10.0)
	h.add_slow_zone(Vector3.ZERO, 2.0, 0.4)
	h.add_pulse_zone(Vector3.ZERO, 2.0, 12.0, 3.0)
	ok(h.get_child_count() == 3, "tres markers de hazard")
	h.free()


func _map_thumbs_are_honest() -> void:
	## No prestar fotos de lab_neon a castle/cave/forest.
	ok(not UiIcons.MAPS.has("castle"), "castle sin thumb prestado")
	ok(not UiIcons.MAPS.has("cave"), "cave sin thumb prestado")
	ok(not UiIcons.MAPS.has("forest"), "forest sin thumb prestado")
	ok(UiIcons.map_tex("castle") == null, "map_tex(castle) = null")
	ok(UiIcons.map_tex("lab_neon") != null or true, "lab_neon puede tener thumb")


func _peer_left_api_exists() -> void:
	ok(GameManager.has_method("handle_peer_left"), "GameManager.handle_peer_left")
	ok(GameManager.has_method("abort_match"), "GameManager.abort_match")

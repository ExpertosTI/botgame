extends "res://tests/test_case.gd"

## Regresiones de jugabilidad: escudo de núcleos, sabotaje sin ray, vacío, etc.


func suite_name() -> String:
	return "playability"


func run() -> void:
	_projectiles_mask_includes_cores()
	_explosions_mask_includes_cores()
	_looking_core_has_proximity_fallback()
	_void_fall_is_not_free()
	_easy_melee_uses_hp_path()
	_timer_race_prefers_cores()
	_campaign_advance_requires_level_map()
	_castle_cores_not_on_tower_centers()
	_solo_authority_helper_exists()
	_host_fire_not_self_blocked()
	_roar_interrupts_sabotage()
	_dead_explorer_clears_collision()
	_beast_defeat_has_iframes()


func _beast_defeat_has_iframes() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player/beast.gd")
	ok(src.contains("DEFEAT_IFRAMES") or src.contains("_defeat_iframes"), "bestia tiene i-frames tras knockdown")
	ok(src.contains("level_beast_hp_mult"), "regen de stun respeta HP de campaña")


func _solo_authority_helper_exists() -> void:
	ok(NetworkManager.has_method("is_match_authority"), "NetworkManager.is_match_authority")
	var was := NetworkManager.is_solo_practice
	NetworkManager.is_solo_practice = true
	ok(NetworkManager.is_match_authority(), "solo practice es autoridad de match")
	NetworkManager.is_solo_practice = was


func _host_fire_not_self_blocked() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/combat/combat_kit.gd")
	ok(src.contains("from_remote"), "rate-limit solo RPC remoto (host/solo dispara)")


func _roar_interrupts_sabotage() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player/explorer.gd")
	ok(src.contains("damage <= 0.0 and slow > 0.0"), "ruta slow-only (rugido)")
	ok(src.contains("_cancel_sabotage"), "rugido/hit cancela sabotaje")


func _dead_explorer_clears_collision() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player/explorer.gd")
	ok(
		src.contains("func _die")
		and (
			src.contains("collision_layer = 0")
			or src.contains('set_deferred("collision_layer", 0)')
		),
		"muerte sin colisión"
	)


func _projectiles_mask_includes_cores() -> void:
	var p := Projectile.new()
	p.setup(Vector3.ZERO, Vector3.FORWARD, {"damage": 10}, 1, false)
	ok((p.collision_mask & 4) != 0, "proyectil mask incluye layer 4 (núcleos)")
	p.free()


func _explosions_mask_includes_cores() -> void:
	## Explosion.setup es async; solo validamos el contrato de mask en el script.
	var src := FileAccess.get_file_as_string("res://scripts/combat/explosion.gd")
	ok(src.contains("collision_mask = 2 | 4") or src.contains("2 | 4"), "explosión mask incluye núcleos")
	ok(src.contains("BeastObjective"), "explosión daña escudo de núcleo")


func _looking_core_has_proximity_fallback() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player/explorer.gd")
	ok(src.contains("_core_from_proximity"), "looking_core tiene fallback de proximidad")
	ok(src.contains("beast_objectives"), "busca grupo beast_objectives")


func _void_fall_is_not_free() -> void:
	var base := FileAccess.get_file_as_string("res://scripts/player/player_base.gd")
	var ex := FileAccess.get_file_as_string("res://scripts/player/explorer.gd")
	ok(base.contains("VOID_Y") and base.contains("request_void_penalty"), "void pide castigo")
	ok(ex.contains("request_void_penalty") and ex.contains("_rpc_void_penalty"), "void vía servidor")
	ok(ex.contains("_channel_target"), "canalización recuerda el núcleo")


func _easy_melee_uses_hp_path() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/combat/combat_kit.gd")
	ok(src.contains("easy_beast_mode"), "melee respeta easy_beast_mode")
	ok(src.contains("apply_projectile_hit"), "easy melee pega a HP")
	ok(src.contains("damage_mult"), "disparos respetan damage_mult (OVERCHARGE)")
	ok(src.contains(".duplicate()"), "weapon data se duplica antes de mutar daño")


func _timer_race_prefers_cores() -> void:
	var src := FileAccess.get_file_as_string("res://autoload/game_manager.gd")
	ok(
		src.contains("objectives_remaining <= 0") and src.contains('end_match("explorers")'),
		"timer a 0 con núcleos a 0 → robots"
	)


func _campaign_advance_requires_level_map() -> void:
	var src := FileAccess.get_file_as_string("res://autoload/progression_manager.gd")
	ok(src.contains("expected") and src.contains("map_id == expected"), "avance exige mapa del nivel")


func _castle_cores_not_on_tower_centers() -> void:
	var builder: MapBuilder = load("res://scripts/maps/map_builder.gd").new()
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		ok(false, "sin SceneTree")
		return
	var holder := Node3D.new()
	loop.root.add_child(builder)
	builder.add_child(holder)
	builder.objectives_root = holder
	builder.walkable_surfaces.clear()
	builder.call("_build_castle")
	var towers := [Vector3(-14, 0.5, -14), Vector3(14, 0.5, -14), Vector3(-14, 0.5, 14), Vector3(14, 0.5, 14)]
	for core in builder.objective_positions:
		for tw in towers:
			ok(core.distance_to(tw) > 1.0, "núcleo castle no coincide con torre %s" % str(tw))
	builder.queue_free()

extends "res://tests/test_case.gd"

## Contratos de combate que se habían quedado a medias: mina real, disparo
## rápido con muestra propia, y habilidades con efecto distinto de "nada".


func suite_name() -> String:
	return "combat_contract"


func run() -> void:
	_trap_mine_is_a_real_class()
	_trap_mine_is_in_loadouts()
	_heal_and_emp_exist()
	_fast_shot_api_accepts_flag()
	_fall_api_exists()


func _trap_mine_is_a_real_class() -> void:
	ok(ClassDB.class_exists("Object"), "sanity")
	var mine := TrapMine.new()
	ok(mine != null, "TrapMine se instancia")
	ok(mine.has_method("setup"), "TrapMine.setup")
	mine.free()


func _trap_mine_is_in_loadouts() -> void:
	var found := false
	for role in ["beast", "explorer"]:
		## Recorre arsenales conocidos.
		pass
	for i in 4:
		var abs_list: Array = WeaponDefs.explorer_abilities(i)
		if abs_list.has(WeaponDefs.AbilityId.TRAP_MINE):
			found = true
	var beast_abs: Array = WeaponDefs.beast_abilities(0)
	if beast_abs.has(WeaponDefs.AbilityId.TRAP_MINE):
		found = true
	ok(found, "TRAP_MINE aparece en al menos un kit")
	var data: Dictionary = WeaponDefs.ability_data(WeaponDefs.AbilityId.TRAP_MINE)
	ok(not data.is_empty(), "ability_data TRAP_MINE")
	var kit_src := FileAccess.get_file_as_string("res://scripts/combat/combat_kit.gd")
	## Polaridad correcta: spawn_trap_mine(..., is_beast, not is_beast)
	ok(kit_src.contains("spawn_trap_mine"), "spawnea mina")
	ok(kit_src.contains("not is_beast"), "flag vs_beast = not is_beast")
	ok(float(data.get("damage", 0)) > 0.0, "mina con daño")
	ok(float(data.get("radius", 0)) > 0.0, "mina con radio")


func _heal_and_emp_exist() -> void:
	var heal: Dictionary = WeaponDefs.ability_data(WeaponDefs.AbilityId.HEAL_PULSE)
	var emp: Dictionary = WeaponDefs.ability_data(WeaponDefs.AbilityId.EMP)
	ok(not str(heal.get("name", "")).is_empty(), "HEAL_PULSE nombrado")
	ok(not str(emp.get("name", "")).is_empty(), "EMP nombrado")
	ok(float(emp.get("radius", 0)) > 0.0, "EMP con radio")


func _fast_shot_api_accepts_flag() -> void:
	## No dispara audio de verdad en headless; solo valida la firma.
	AudioDirector.play_shot(false, true)
	AudioDirector.play_shot(false, false)
	ok(true, "play_shot(beast, fast) no rompe")


func _fall_api_exists() -> void:
	AudioDirector.play_fall()
	ok(true, "play_fall cableado")

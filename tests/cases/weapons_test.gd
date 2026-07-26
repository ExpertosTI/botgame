extends "res://tests/test_case.gd"

## Contrato de datos de armas/habilidades: cada id resuelve, cada loadout
## tiene 4 ranuras y los proyectiles traen la física mínima que pide
## CombatKit._server_fire().

const SLOTS := 4


func suite_name() -> String:
	return "weapons"


func run() -> void:
	_weapon_data_complete()
	_ability_data_complete()
	_loadouts_have_four_valid_slots()
	_names_are_unique()


func _weapon_data_complete() -> void:
	for id in WeaponDefs.WeaponId.values():
		var d := WeaponDefs.weapon_data(id)
		var label := "arma %d" % id
		neq(str(d.get("name", "?")), "?", "%s sin nombre" % label)
		gt(float(d.get("cooldown", 0.0)), 0.0, "%s sin cooldown" % label)
		var type_s := str(d.get("type", ""))
		ok(
			type_s in ["melee", "projectile", "shotgun", "grenade", "explosion", "roar"],
			"%s tiene type desconocido '%s'" % [label, type_s]
		)
		ok(d.has("color"), "%s sin color (el VFX lo necesita)" % label)
		match type_s:
			"projectile":
				gt(float(d.get("speed", 0.0)), 0.0, "%s sin speed" % label)
				gt(float(d.get("lifetime", 0.0)), 0.0, "%s sin lifetime" % label)
				gt(float(d.get("radius", 0.0)), 0.0, "%s sin radius" % label)
			"shotgun":
				gt(float(d.get("pellets", 0)), 0.0, "%s sin pellets" % label)
				gt(float(d.get("spread", 0.0)), 0.0, "%s sin spread" % label)
				gt(float(d.get("speed", 0.0)), 0.0, "%s sin speed" % label)
			"grenade":
				gt(float(d.get("fuse", 0.0)), 0.0, "%s sin fuse" % label)
				gt(float(d.get("radius", 0.0)), 0.0, "%s sin radius de explosión" % label)
			"explosion", "roar":
				gt(float(d.get("radius", 0.0)), 0.0, "%s sin radius" % label)
			"melee":
				gt(float(d.get("range", 0.0)), 0.0, "%s sin range" % label)


func _ability_data_complete() -> void:
	for id in WeaponDefs.AbilityId.values():
		var d := WeaponDefs.ability_data(id)
		var label := "habilidad %d" % id
		neq(str(d.get("name", "?")), "?", "%s sin nombre" % label)
		gt(float(d.get("cooldown", 0.0)), 0.0, "%s sin cooldown" % label)
		ok(d.has("color"), "%s sin color (el HUD lo usa)" % label)


func _loadouts_have_four_valid_slots() -> void:
	var weapon_ids := WeaponDefs.WeaponId.values()
	var ability_ids := WeaponDefs.AbilityId.values()

	for variant in range(3):
		var wl := WeaponDefs.beast_loadout(variant)
		eq(wl.size(), SLOTS, "bestia %d: armas != %d" % [variant, SLOTS])
		for w in wl:
			ok(w in weapon_ids, "bestia %d referencia arma inválida %s" % [variant, str(w)])
		var al := WeaponDefs.beast_abilities(variant)
		eq(al.size(), SLOTS, "bestia %d: habilidades != %d" % [variant, SLOTS])
		for a in al:
			ok(a in ability_ids, "bestia %d referencia habilidad inválida %s" % [variant, str(a)])

	for loadout in range(SLOTS):
		var wl := WeaponDefs.explorer_loadout(loadout)
		eq(wl.size(), SLOTS, "arsenal %d: armas != %d" % [loadout, SLOTS])
		for w in wl:
			ok(w in weapon_ids, "arsenal %d referencia arma inválida %s" % [loadout, str(w)])
		var al := WeaponDefs.explorer_abilities(loadout)
		eq(al.size(), SLOTS, "arsenal %d: habilidades != %d" % [loadout, SLOTS])
		for a in al:
			ok(a in ability_ids, "arsenal %d referencia habilidad inválida %s" % [loadout, str(a)])
		# La primera ranura es la que arranca seleccionada en el HUD.
		neq(
			str(WeaponDefs.weapon_data(wl[0]).get("name", "?")),
			"?",
			"arsenal %d: arma inicial sin datos" % loadout
		)


func _names_are_unique() -> void:
	var seen: Dictionary = {}
	for loadout in range(SLOTS):
		var n := WeaponDefs.explorer_loadout_name(loadout)
		ok(not seen.has(n), "nombre de arsenal duplicado: %s" % n)
		seen[n] = true

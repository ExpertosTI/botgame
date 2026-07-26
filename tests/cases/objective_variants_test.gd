extends "res://tests/test_case.gd"

## Contratos de variantes de núcleo: Lab Neon enseña las tres mecánicas,
## y cada Kind tiene reglas que el sabotaje y el HUD dependen de cumplir.


func suite_name() -> String:
	return "objective_variants"


func run() -> void:
	_lab_neon_teaches_all_kinds()
	_named_maps_have_real_variants()
	_mults_and_labels_are_stable()
	_shielded_blocks_until_broken()
	_relay_blocks_when_closed()
	_overcharge_constants_are_lethal_enough()
	_hints_are_nonempty()


func _named_maps_have_real_variants() -> void:
	## No solo Lab Neon: los teatros que anuncian mecánicas deben cumplirlas.
	ok(
		ObjectiveVariants.for_map("reactor_pit", 0) == ObjectiveVariants.Kind.OVERCHARGED,
		"reactor_pit[0] = Sobrecarga"
	)
	ok(
		ObjectiveVariants.for_map("reactor_pit", 1) == ObjectiveVariants.Kind.SHIELDED,
		"reactor_pit[1+] = Blindado"
	)
	ok(
		ObjectiveVariants.for_map("skybridge", 0) == ObjectiveVariants.Kind.TIMED_RELAY,
		"skybridge pares = Relé"
	)
	ok(
		ObjectiveVariants.for_map("ruins", 4) == ObjectiveVariants.Kind.SHIELDED,
		"ruins pedestal = Blindado"
	)
	for map_id in ["containers", "castle", "cave", "forest"]:
		var kinds := {}
		for i in 6:
			kinds[ObjectiveVariants.for_map(map_id, i)] = true
		ok(kinds.size() >= 2, "%s mezcla al menos 2 variantes de núcleo" % map_id)
		ok(
			not (kinds.size() == 1 and kinds.has(ObjectiveVariants.Kind.STANDARD)),
			"%s no puede ser solo Estándar" % map_id
		)


func _lab_neon_teaches_all_kinds() -> void:
	var seen := {}
	for i in 4:
		var k := ObjectiveVariants.for_map("lab_neon", i)
		seen[k] = true
	ok(seen.has(ObjectiveVariants.Kind.STANDARD), "lab_neon debe incluir Estándar")
	ok(seen.has(ObjectiveVariants.Kind.SHIELDED), "lab_neon debe incluir Blindado")
	ok(seen.has(ObjectiveVariants.Kind.TIMED_RELAY), "lab_neon debe incluir Relé")
	ok(seen.has(ObjectiveVariants.Kind.OVERCHARGED), "lab_neon debe incluir Sobrecarga")


func _mults_and_labels_are_stable() -> void:
	eq(ObjectiveVariants.label(ObjectiveVariants.Kind.SHIELDED), "Blindado", "label Blindado")
	eq(ObjectiveVariants.label(ObjectiveVariants.Kind.TIMED_RELAY), "Relé", "label Relé")
	eq(ObjectiveVariants.label(ObjectiveVariants.Kind.OVERCHARGED), "Sobrecarga", "label Sobrecarga")
	ok(ObjectiveVariants.sabotage_mult(ObjectiveVariants.Kind.SHIELDED) > 1.0, "Blindado más lento")
	ok(ObjectiveVariants.sabotage_mult(ObjectiveVariants.Kind.TIMED_RELAY) < 1.0, "Relé más rápido en ventana")


func _shielded_blocks_until_broken() -> void:
	var obj := BeastObjective.new()
	## Sin escena: aplicamos estado a mano como haría apply_variant.
	obj.variant = ObjectiveVariants.Kind.SHIELDED
	obj.is_active = true
	obj.shield_max = ObjectiveVariants.SHIELD_HP
	obj.shield_hp = ObjectiveVariants.SHIELD_HP
	ok(not obj.can_accept_sabotage(), "con escudo no se canaliza")
	obj.shield_hp = 0.0
	ok(obj.can_accept_sabotage(), "sin escudo sí se canaliza")
	obj.free()


func _relay_blocks_when_closed() -> void:
	var obj := BeastObjective.new()
	obj.variant = ObjectiveVariants.Kind.TIMED_RELAY
	obj.is_active = true
	obj.relay_open = false
	ok(not obj.can_accept_sabotage(), "Relé cerrado bloquea")
	obj.relay_open = true
	ok(obj.can_accept_sabotage(), "Relé abierto permite")
	obj.free()


func _overcharge_constants_are_lethal_enough() -> void:
	ok(ObjectiveVariants.OVERCHARGE_RADIUS >= 4.0, "radio de detonación jugable")
	ok(ObjectiveVariants.OVERCHARGE_DAMAGE >= 20.0, "daño que se nota al pegarse")


func _hints_are_nonempty() -> void:
	for k in [
		ObjectiveVariants.Kind.STANDARD,
		ObjectiveVariants.Kind.SHIELDED,
		ObjectiveVariants.Kind.TIMED_RELAY,
		ObjectiveVariants.Kind.OVERCHARGED,
	]:
		ok(not ObjectiveVariants.hint(k).is_empty(), "hint para kind %d" % k)

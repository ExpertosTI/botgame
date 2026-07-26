extends "res://tests/test_case.gd"

## Pool de combate y caché de mallas/materiales.
##
## Lo que protege: que disparar en ráfaga no cree nodos sin techo (era la fuga
## de memoria del navegador) y que los materiales se compartan de verdad en vez
## de generar un StandardMaterial3D por chispa.


func suite_name() -> String:
	return "fx_pool"


func run() -> void:
	_materials_are_shared()
	_meshes_are_shared()
	_projectiles_are_recycled()
	_projectiles_respect_the_cap()
	_oneshots_respect_the_cap()
	FxPool.release_all()


func _materials_are_shared() -> void:
	var a := FxAssets.emissive(Color(0.3, 0.9, 1.0), 3.0)
	var b := FxAssets.emissive(Color(0.3, 0.9, 1.0), 3.0)
	ok(a == b, "el mismo color/energía debe devolver el mismo material")
	var near := FxAssets.emissive(Color(0.31, 0.9, 1.0), 3.0)
	ok(a == near, "colores casi iguales deben caer en el mismo bucket")
	var other := FxAssets.emissive(Color(1.0, 0.2, 0.1), 3.0)
	ok(a != other, "colores distintos deben dar materiales distintos")
	ok(a.emission_enabled, "el material de FX debe ser emisivo")
	eq(
		a.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED,
		"los FX deben ser opacos: la transparencia paga ordenación en WebGL"
	)


func _meshes_are_shared() -> void:
	var a := FxAssets.sphere(0.12)
	var b := FxAssets.sphere(0.12)
	ok(a == b, "el mismo radio debe devolver la misma malla")
	ok(a == FxAssets.sphere(0.13), "radios casi iguales deben compartir malla")
	ok(a != FxAssets.sphere(0.9), "radios muy distintos no deben compartir malla")
	ok(FxAssets.ring_mesh() == FxAssets.ring_mesh(), "el toro del anillo debe ser único")
	# Pocos segmentos a propósito: son destellos de milésimas, no props.
	ok(a.radial_segments <= 12, "la esfera de FX no debería ser densa")


func _projectiles_are_recycled() -> void:
	FxPool.release_all()
	var first := FxPool.acquire_projectile()
	ok(first != null, "el pool debe entregar un proyectil")
	var before: Dictionary = FxPool.stats()
	eq(int(before["proj_live"]), 1, "el proyectil entregado debe contar como vivo")
	FxPool.release_projectile(first)
	var after: Dictionary = FxPool.stats()
	eq(int(after["proj_live"]), 0, "al liberarlo no debe seguir vivo")
	gt(float(after["proj_free"]), 0.0, "al liberarlo debe quedar disponible")
	var second := FxPool.acquire_projectile()
	ok(second == first, "la siguiente petición debe reutilizar el mismo nodo")
	FxPool.release_projectile(second)


func _projectiles_respect_the_cap() -> void:
	FxPool.release_all()
	var handed: Array = []
	# Pedimos el triple del techo: si no hubiera reciclaje, crecería sin freno.
	for _i in range(FxPool.MAX_PROJECTILES * 3):
		var p := FxPool.acquire_projectile()
		if p != null and not handed.has(p):
			handed.append(p)
	var live := int(FxPool.stats()["proj_live"])
	ok(
		live <= FxPool.MAX_PROJECTILES,
		"proyectiles vivos (%d) por encima del techo (%d)" % [live, FxPool.MAX_PROJECTILES]
	)
	ok(
		handed.size() <= FxPool.MAX_PROJECTILES,
		"se crearon %d nodos distintos con techo %d" % [handed.size(), FxPool.MAX_PROJECTILES]
	)
	FxPool.release_all()
	eq(int(FxPool.stats()["proj_live"]), 0, "release_all debe dejar el pool vacío")


func _oneshots_respect_the_cap() -> void:
	FxPool.release_all()
	for i in range(FxPool.MAX_ONESHOTS * 3):
		FxPool.flash(Vector3(float(i), 0.0, 0.0), Color(0.4, 0.9, 1.0), 0.3)
	var live := int(FxPool.stats()["fx_live"])
	ok(
		live <= FxPool.MAX_ONESHOTS,
		"destellos vivos (%d) por encima del techo (%d)" % [live, FxPool.MAX_ONESHOTS]
	)
	FxPool.burst(Vector3.ZERO, Color(1.0, 0.5, 0.1), 2.0, 12)
	FxPool.ring(Vector3.ZERO, Color(1.0, 0.4, 0.05), 3.0)
	ok(
		int(FxPool.stats()["fx_live"]) <= FxPool.MAX_ONESHOTS,
		"burst/ring tampoco deben pasarse del techo"
	)
	FxPool.release_all()
	eq(int(FxPool.stats()["fx_live"]), 0, "release_all debe apagar los destellos")

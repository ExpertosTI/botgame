extends "res://tests/test_case.gd"

## Los mapas tienen que ser ganables.
##
## Skybridge se publicó con dos de sus seis núcleos en la cima de unas torres a
## 4,6 m sobre el puente más cercano y con 3,5 m de vacío en medio. El salto da
## 1,5 m. El nivel 10 pide seis núcleos, así que ganar era imposible y el jugador
## solo podía esperar a que el reloj le diera la derrota. Nadie se enteró porque
## nada comprobaba los mapas.

const MAP_BUILDER := preload("res://scripts/maps/map_builder.gd")

## Altura de salto real: v²/2g con jump_velocity 6.4 y gravity 14 ≈ 1,46 m.
const JUMP_REACH := 1.45
## Cuánto puede estar el núcleo por encima del suelo desde el que se le apunta.
## No hace falta subirse encima: basta verlo dentro del alcance de interacción.
const MAX_CORE_HEIGHT_OVER_GROUND := 4.0
## Margen horizontal entre el núcleo y el borde de la superficie pisable.
const MAX_CORE_GAP := 2.5


func suite_name() -> String:
	return "maps"


func run() -> void:
	for map_id in NetworkManager.MAP_IDS:
		_check_map(str(map_id))
	_every_campaign_level_has_enough_cores()
	_objective_positions_are_unique()
	_prop_maps_cores_clear_of_landmarks()


func _prop_maps_cores_clear_of_landmarks() -> void:
	## Tras añadir colisión a props, los núcleos no pueden vivir en el centro
	## de torres/árboles o el jugador queda embutido.
	var forest := _build("forest")
	if forest:
		for pos in forest.objective_positions:
			ok(absf(pos.x) < 11.0, "forest núcleo lejos de la hilera de árboles (±12): %s" % str(pos))
		_free(forest)
	var castle := _build("castle")
	if castle:
		var towers := [
			Vector3(-14, 0.5, -14), Vector3(14, 0.5, -14),
			Vector3(-14, 0.5, 14), Vector3(14, 0.5, 14),
		]
		for pos in castle.objective_positions:
			for tw in towers:
				ok(pos.distance_to(tw) > 2.0, "castle núcleo fuera de torre %s" % str(tw))
		_free(castle)


func _objective_positions_are_unique() -> void:
	for map_id in NetworkManager.MAP_IDS:
		var builder := _build(str(map_id))
		if builder == null:
			continue
		var seen := {}
		for pos in builder.objective_positions:
			var key := "%0.1f,%0.1f,%0.1f" % [pos.x, pos.y, pos.z]
			ok(not seen.has(key), "%s tiene núcleo duplicado en %s" % [map_id, key])
			seen[key] = true
		_free(builder)


func _build(map_id: String) -> MapBuilder:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	var builder: MapBuilder = MAP_BUILDER.new()
	var holder := Node3D.new()
	loop.root.add_child(builder)
	builder.add_child(holder)
	# build() es async por el `await process_frame` inicial, pero la construcción
	# en sí es síncrona: se invoca el constructor concreto directamente para que
	# la suite siga sin esperar frames.
	builder.walkable_surfaces.clear()
	builder.objectives_root = holder
	builder.call("_build_" + _builder_suffix(map_id))
	return builder


func _builder_suffix(map_id: String) -> String:
	return "lab_neon" if map_id == "lab_neon" else map_id


func _free(builder: MapBuilder) -> void:
	if builder != null and is_instance_valid(builder):
		builder.queue_free()


func _check_map(map_id: String) -> void:
	var builder := _build(map_id)
	if builder == null:
		ok(false, "no se pudo construir el mapa %s" % map_id)
		return

	var cores: Array = builder.objective_positions
	var needed := _max_cores_for(map_id)
	ok(
		cores.size() >= needed,
		"%s ofrece %d núcleos y el nivel más exigente pide %d" % [map_id, cores.size(), needed]
	)
	ok(not builder.walkable_surfaces.is_empty(), "%s no registró ninguna superficie pisable" % map_id)

	var reachable := _reachable_surfaces(builder)
	ok(not reachable.is_empty(), "%s: ningún suelo alcanzable desde los spawns" % map_id)

	for i in cores.size():
		var core: Vector3 = cores[i]
		ok(
			_core_is_reachable(core, reachable),
			"%s: el núcleo %d en %s no tiene suelo alcanzable desde el que sabotearlo"
			% [map_id, i + 1, str(core)]
		)
	_free(builder)


## Recorre las superficies desde los spawns: se llega a otra si está pegada
## (hueco horizontal pequeño) y no queda más alto que un salto. Bajar es gratis.
func _reachable_surfaces(builder: MapBuilder) -> Array:
	var all: Array = builder.walkable_surfaces
	var reached: Array = []
	var pending: Array = []

	for marker in builder.get_children():
		if not (marker is Marker3D):
			continue
		if not (marker.is_in_group("explorer_spawns") or marker.is_in_group("beast_spawn")):
			continue
		var idx := _surface_under(marker.position, all)
		if idx >= 0 and not reached.has(idx):
			reached.append(idx)
			pending.append(idx)

	while not pending.is_empty():
		var from: Dictionary = all[pending.pop_back()]
		for i in all.size():
			if reached.has(i):
				continue
			var to: Dictionary = all[i]
			if float(to["top"]) - float(from["top"]) > JUMP_REACH:
				continue
			if _gap(from, to) > MAX_CORE_GAP:
				continue
			reached.append(i)
			pending.append(i)

	var out: Array = []
	for i in reached:
		out.append(all[i])
	return out


## Distancia horizontal entre dos rectángulos (0 si se solapan).
func _gap(a: Dictionary, b: Dictionary) -> float:
	var dx: float = maxf(0.0, absf(float(a["x"]) - float(b["x"])) - float(a["hx"]) - float(b["hx"]))
	var dz: float = maxf(0.0, absf(float(a["z"]) - float(b["z"])) - float(a["hz"]) - float(b["hz"]))
	return sqrt(dx * dx + dz * dz)


func _surface_under(pos: Vector3, surfaces: Array) -> int:
	var best := -1
	var best_top := -INF
	for i in surfaces.size():
		var s: Dictionary = surfaces[i]
		if absf(pos.x - float(s["x"])) > float(s["hx"]):
			continue
		if absf(pos.z - float(s["z"])) > float(s["hz"]):
			continue
		var top := float(s["top"])
		if top <= pos.y + 0.6 and top > best_top:
			best_top = top
			best = i
	return best


func _core_is_reachable(core: Vector3, reachable: Array) -> bool:
	var probe := {"x": core.x, "z": core.z, "hx": 0.0, "hz": 0.0}
	for s in reachable:
		var top := float(s["top"])
		if core.y - top > MAX_CORE_HEIGHT_OVER_GROUND or top - core.y > JUMP_REACH:
			continue
		if _gap(probe, s) <= MAX_CORE_GAP:
			return true
	return false


func _max_cores_for(map_id: String) -> int:
	## Partida libre siempre pide OBJECTIVES_TO_WIN; la campaña puede pedir más.
	var needed: int = GameManager.OBJECTIVES_TO_WIN
	for level in ProgressionManager.CAMPAIGN:
		if str(level.get("map", "")) == map_id:
			needed = maxi(needed, int(level.get("cores", 0)))
	return needed


func _every_campaign_level_has_enough_cores() -> void:
	for level in ProgressionManager.CAMPAIGN:
		var map_id := str(level.get("map", ""))
		ok(
			map_id in NetworkManager.MAP_IDS,
			"el nivel %s apunta al mapa desconocido '%s'" % [str(level.get("id", "?")), map_id]
		)
		ok(
			int(level.get("cores", 0)) > 0 and int(level.get("time", 0)) > 0,
			"el nivel %s no declara núcleos o reloj" % str(level.get("id", "?"))
		)

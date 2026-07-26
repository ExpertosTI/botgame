extends Node

## Pool de proyectiles y destellos de combate.
##
## Antes, cada disparo instanciaba un Area3D con su CollisionShape3D, SphereShape3D,
## MeshInstance3D, SphereMesh y StandardMaterial3D nuevos, más un destello con otro
## mesh+material, más un Tween por efecto. Con la escopeta (5 perdigones) o el
## lanzallamas (3 perdigones cada 0.12 s) eso son cientos de nodos y RIDs por
## segundo: el recolector no llega, la memoria sube y WebGL se atraganta.
##
## Aquí los nodos se reciclan y los one-shot los anima este _process con lerps,
## sin crear Tweens. Los nodos viven bajo este autoload, que comparte el World3D
## de la raíz: sobreviven al cambio de escena en vez de quedar huérfanos.

const PROJECTILE_SCRIPT := preload("res://scripts/combat/projectile.gd")

## Techos duros. Al llegar, se recicla el más viejo en vez de seguir creando:
## en Web es mejor perder un destello que perder el frame rate.
const MAX_PROJECTILES := 64
const MAX_ONESHOTS := 72
const WEB_MAX_PROJECTILES := 36
const WEB_MAX_ONESHOTS := 40

var _free_projectiles: Array[Area3D] = []
var _live_projectiles: Array[Area3D] = []
var _free_oneshots: Array[MeshInstance3D] = []
var _live_oneshots: Array[MeshInstance3D] = []

var _cap_projectiles := MAX_PROJECTILES
var _cap_oneshots := MAX_ONESHOTS
var _created_projectiles := 0
var _created_oneshots := 0


func _ready() -> void:
	var web := OS.has_feature("web") or OS.get_name() == "Web"
	_cap_projectiles = WEB_MAX_PROJECTILES if web else MAX_PROJECTILES
	_cap_oneshots = WEB_MAX_ONESHOTS if web else MAX_ONESHOTS


# ---------------------------------------------------------------- proyectiles


func acquire_projectile() -> Area3D:
	# Techo alcanzado y nada libre: el más viejo cede su turno. recycle_now() lo
	# devuelve a _free_projectiles, así que después se toma por la vía normal;
	# reusarlo aquí directamente lo dejaba en las dos listas y el conteo de vivos
	# crecía sin freno pese al techo.
	if _free_projectiles.is_empty() and _live_projectiles.size() >= _cap_projectiles:
		var oldest := _live_projectiles[0]
		if oldest != null and is_instance_valid(oldest) and oldest.has_method("recycle_now"):
			oldest.call("recycle_now")
		if not _live_projectiles.is_empty() and _live_projectiles[0] == oldest:
			_live_projectiles.remove_at(0)

	var node: Area3D
	if not _free_projectiles.is_empty():
		node = _free_projectiles.pop_back()
	else:
		node = _build_projectile()
	if node == null:
		return null
	if not _live_projectiles.has(node):
		_live_projectiles.append(node)
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.visible = true
	return node


func release_projectile(node: Area3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	_live_projectiles.erase(node)
	if _free_projectiles.has(node):
		return
	node.visible = false
	node.monitoring = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_free_projectiles.append(node)


func _build_projectile() -> Area3D:
	var node := Area3D.new()
	node.set_script(PROJECTILE_SCRIPT)
	node.name = "Projectile%d" % _created_projectiles
	_created_projectiles += 1
	add_child(node)
	return node


# ------------------------------------------------------------------ one-shots
#
# Destellos, chispas y anillos: mismo nodo, distinta malla y animación. Se
# apagan escalando a cero (no bajando alfa) para poder compartir materiales
# opacos, que además ahorran ordenación por transparencia en WebGL.


func flash(pos: Vector3, color: Color, size: float = 0.35, duration: float = 0.12) -> void:
	var node := _acquire_oneshot()
	if node == null:
		return
	node.mesh = FxAssets.sphere(size)
	node.material_override = FxAssets.emissive(color, 5.0)
	node.global_position = pos
	node.rotation = Vector3.ZERO
	_animate(node, Vector3.ONE * 0.4, Vector3.ONE * 2.2, pos, pos, duration)


func burst(pos: Vector3, color: Color, radius: float = 1.2, count: int = 10) -> void:
	var n := count
	if OS.has_feature("web") or OS.get_name() == "Web":
		n = mini(count, 5)
	n = mini(n, maxi(_cap_oneshots - _live_oneshots.size(), 1))
	var mat := FxAssets.emissive(color, 3.5)
	for _i in n:
		var node := _acquire_oneshot()
		if node == null:
			return
		node.mesh = FxAssets.sphere(0.08)
		node.material_override = mat
		node.global_position = pos
		node.rotation = Vector3.ZERO
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.2), randf_range(-1.0, 1.0)).normalized()
		var dest := pos + dir * randf_range(radius * 0.4, radius)
		_animate(node, Vector3.ONE, Vector3.ONE * 0.05, pos, dest, 0.28)


func ring(pos: Vector3, color: Color, radius: float = 3.0) -> void:
	var node := _acquire_oneshot()
	if node == null:
		return
	node.mesh = FxAssets.ring_mesh()
	node.material_override = FxAssets.emissive(color, 4.0)
	node.global_position = pos + Vector3.UP * 0.15
	node.rotation_degrees = Vector3(90, 0, 0)
	_animate(node, Vector3.ONE * 0.2, Vector3.ONE * maxf(radius * 1.4, 0.5), node.global_position, node.global_position, 0.35)


func _acquire_oneshot() -> MeshInstance3D:
	var node: MeshInstance3D
	if not _free_oneshots.is_empty():
		node = _free_oneshots.pop_back()
	elif _live_oneshots.size() >= _cap_oneshots:
		node = _live_oneshots.pop_front()
	else:
		node = MeshInstance3D.new()
		node.name = "Fx%d" % _created_oneshots
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_created_oneshots += 1
		add_child(node)
	if node == null:
		return null
	if not _live_oneshots.has(node):
		_live_oneshots.append(node)
	node.visible = true
	return node


func _animate(
	node: MeshInstance3D,
	from_scale: Vector3,
	to_scale: Vector3,
	from_pos: Vector3,
	to_pos: Vector3,
	duration: float
) -> void:
	node.scale = from_scale
	# La animación va en metadatos del propio nodo: se reutilizan en cada ciclo,
	# así que no hay Tween ni diccionario nuevo por efecto.
	node.set_meta("fx_t", 0.0)
	node.set_meta("fx_dur", maxf(duration, 0.02))
	node.set_meta("fx_s0", from_scale)
	node.set_meta("fx_s1", to_scale)
	node.set_meta("fx_p0", from_pos)
	node.set_meta("fx_p1", to_pos)


func _process(delta: float) -> void:
	if _live_oneshots.is_empty():
		return
	var i := _live_oneshots.size() - 1
	while i >= 0:
		var node := _live_oneshots[i]
		if node == null or not is_instance_valid(node):
			_live_oneshots.remove_at(i)
			i -= 1
			continue
		var t := float(node.get_meta("fx_t", 0.0)) + delta
		var dur := float(node.get_meta("fx_dur", 0.2))
		if t >= dur:
			node.visible = false
			_live_oneshots.remove_at(i)
			if not _free_oneshots.has(node):
				_free_oneshots.append(node)
			i -= 1
			continue
		node.set_meta("fx_t", t)
		var k := t / dur
		node.scale = (node.get_meta("fx_s0") as Vector3).lerp(node.get_meta("fx_s1") as Vector3, k)
		var p0 := node.get_meta("fx_p0") as Vector3
		var p1 := node.get_meta("fx_p1") as Vector3
		if p0 != p1:
			node.global_position = p0.lerp(p1, k)
		i -= 1


## Al terminar una partida o cambiar de escena: nada de proyectiles zombis
## volando en el menú.
func release_all() -> void:
	for node in _live_projectiles.duplicate():
		if node != null and is_instance_valid(node) and node.has_method("recycle_now"):
			node.call("recycle_now")
	_live_projectiles.clear()
	for node in _live_oneshots:
		if node != null and is_instance_valid(node):
			node.visible = false
			if not _free_oneshots.has(node):
				_free_oneshots.append(node)
	_live_oneshots.clear()


## Para el overlay de debug.
func stats() -> Dictionary:
	return {
		"proj_live": _live_projectiles.size(),
		"proj_free": _free_projectiles.size(),
		"fx_live": _live_oneshots.size(),
		"fx_free": _free_oneshots.size(),
	}

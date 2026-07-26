class_name FxAssets
extends RefCounted

## Mallas y materiales compartidos del combate.
##
## Antes cada disparo, chispa y explosión creaba su propio SphereMesh +
## StandardMaterial3D. Con un bláster a 0.28 s y escopetas de 5 perdigones eso
## son decenas de RIDs nuevos por segundo, y en WebGL cada material transparente
## además paga ordenación por profundidad.
##
## Aquí se cachea por "bucket" (color y radio cuantizados) y todo es opaco: los
## VFX se apagan escalando a cero en vez de bajando alfa, así el material puede
## compartirse entre instancias.

const COLOR_STEPS := 12.0
const RADIUS_STEP := 0.04

static var _materials: Dictionary = {}
static var _spheres: Dictionary = {}
static var _torus: TorusMesh = null
static var _quads: Dictionary = {}


static func _color_key(color: Color) -> int:
	## Cuantiza a ~12 pasos por canal: colores casi iguales comparten material.
	var r := int(clampf(color.r, 0.0, 1.0) * COLOR_STEPS)
	var g := int(clampf(color.g, 0.0, 1.0) * COLOR_STEPS)
	var b := int(clampf(color.b, 0.0, 1.0) * COLOR_STEPS)
	return r * 169 + g * 13 + b


## Material emisivo opaco compartido. `energy` se redondea a 0.5.
static func emissive(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var e := roundf(clampf(energy, 0.0, 8.0) * 2.0) / 2.0
	var key := "%d_%.1f" % [_color_key(color), e]
	var cached: StandardMaterial3D = _materials.get(key)
	if cached != null:
		return cached
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = e
	# Sin sombras ni GI: son destellos de un cuarto de segundo.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_receive_shadows = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_materials[key] = mat
	return mat


static func sphere(radius: float) -> SphereMesh:
	var r := maxf(roundf(radius / RADIUS_STEP) * RADIUS_STEP, RADIUS_STEP)
	var key := "%.2f" % r
	var cached: SphereMesh = _spheres.get(key)
	if cached != null:
		return cached
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	# Baja resolución a propósito: son destellos, no props.
	mesh.radial_segments = 8
	mesh.rings = 4
	_spheres[key] = mesh
	return mesh


static func ring_mesh() -> TorusMesh:
	if _torus != null:
		return _torus
	_torus = TorusMesh.new()
	_torus.inner_radius = 0.08
	_torus.outer_radius = 0.22
	_torus.rings = 12
	_torus.ring_segments = 6
	return _torus


static func quad(size: float) -> QuadMesh:
	var s := maxf(roundf(size / RADIUS_STEP) * RADIUS_STEP, RADIUS_STEP)
	var key := "%.2f" % s
	var cached: QuadMesh = _quads.get(key)
	if cached != null:
		return cached
	var mesh := QuadMesh.new()
	mesh.size = Vector2(s, s)
	_quads[key] = mesh
	return mesh


## Diagnóstico para el overlay de debug.
static func cache_counts() -> Dictionary:
	return {
		"materials": _materials.size(),
		"spheres": _spheres.size(),
		"quads": _quads.size(),
	}

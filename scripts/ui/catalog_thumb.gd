class_name CatalogThumb
extends SubViewportContainer

## Mini preview 3D del roster (sin JPG planos).


var _pivot: Node3D
var _spin := randf() * TAU
var _do_spin := false


func setup(catalog_index: int, px: float = 96.0, spin: bool = false) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px, px)
	_do_spin = spin

	var sv := SubViewport.new()
	var res := int(clampf(px * 1.5, 96.0, 160.0))
	sv.size = Vector2i(res, res)
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if spin else SubViewport.UPDATE_WHEN_VISIBLE
	)
	sv.msaa_3d = Viewport.MSAA_DISABLED
	add_child(sv)

	var world := Node3D.new()
	sv.add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 30, 0)
	key.light_energy = 1.2
	key.shadow_enabled = false
	world.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.0, 1.4, 1.2)
	fill.light_color = Color(0.4, 0.85, 0.9)
	fill.light_energy = 1.2
	fill.omni_range = 6.0
	world.add_child(fill)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.95, 2.35)
	cam.fov = 36.0
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.7, 0))

	_pivot = Node3D.new()
	world.add_child(_pivot)

	var entry := CharacterCatalog.get_entry(catalog_index)
	var is_beast := str(entry.get("role", "")) == "beast"
	var attached := CharacterCatalog.attach_mesh(_pivot, catalog_index, 1.0 if is_beast else 0.95)
	if attached:
		CharacterCatalog.fit_for_showcase(attached, 1.7)
		CharacterCatalog.attach_showcase_loadout(attached, "beast" if is_beast else "explorer")
		if spin:
			CharacterCatalog.play_showcase_motion(attached)
		else:
			CharacterCatalog.play_locomotion(attached, false, false)
	else:
		_add_fallback_capsule(entry, is_beast)

	_pivot.rotation.y = _spin
	set_process(spin)


func _add_fallback_capsule(entry: Dictionary, is_beast: bool) -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28 if is_beast else 0.22
	cap.height = 1.1 if is_beast else 1.0
	mi.mesh = cap
	mi.position = Vector3(0, 0.55, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = entry.get("tint", Color(0.3, 0.6, 0.95)) as Color
	mi.material_override = mat
	_pivot.add_child(mi)


func _process(delta: float) -> void:
	if not _do_spin or not is_instance_valid(_pivot):
		return
	_spin += delta * 0.85
	_pivot.rotation.y = _spin

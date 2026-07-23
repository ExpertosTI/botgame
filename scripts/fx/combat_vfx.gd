class_name CombatVfx
extends RefCounted

## VFX de combate reutilizables (esferas, rings, sparks, shake).


static func burst(parent: Node, pos: Vector3, color: Color, radius: float = 1.2, count: int = 10) -> void:
	if parent == null:
		return
	var root := parent.get_tree().current_scene
	if root == null:
		root = parent
	var lite := OS.has_feature("web") or OS.get_name() == "Web"
	var n := mini(count, 5 if lite else count)
	for i in n:
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.06 + randf() * 0.05
		mesh.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.5
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = mat
		root.add_child(mesh)
		mesh.global_position = pos
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
		var dest := pos + dir * randf_range(radius * 0.4, radius)
		var tw := mesh.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mesh, "global_position", dest, 0.28)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
		tw.chain().tween_callback(mesh.queue_free)


static func ring(parent: Node, pos: Vector3, color: Color, radius: float = 3.0) -> void:
	if parent == null:
		return
	var root := parent.get_tree().current_scene
	if root == null:
		root = parent
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.22
	mesh.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	root.add_child(mesh)
	mesh.global_position = pos + Vector3.UP * 0.15
	mesh.rotation_degrees = Vector3(90, 0, 0)
	var tw := mesh.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mesh, "scale", Vector3.ONE * (radius * 1.4), 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mesh.queue_free)


static func flash(parent: Node, pos: Vector3, color: Color, size: float = 0.35) -> void:
	if parent == null:
		return
	var root := parent.get_tree().current_scene
	if root == null:
		root = parent
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	root.add_child(mesh)
	mesh.global_position = pos
	var tw := mesh.create_tween()
	tw.tween_property(mesh, "scale", Vector3.ONE * 2.4, 0.08)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(mesh.queue_free)


static func shake_camera(cam: Camera3D, strength: float = 0.18, duration: float = 0.18) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	var base := cam.position
	var tw := cam.create_tween()
	var steps := 5
	for i in steps:
		var off := Vector3(
			randf_range(-strength, strength),
			randf_range(-strength * 0.6, strength * 0.6),
			randf_range(-strength * 0.3, strength * 0.3)
		)
		tw.tween_property(cam, "position", base + off, duration / float(steps))
	tw.tween_property(cam, "position", base, 0.05)


static func damage_vignette(layer: CanvasLayer, color: Color = Color(0.9, 0.1, 0.15, 0.35)) -> void:
	if layer == null:
		return
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.35)
	tw.tween_callback(rect.queue_free)

class_name Explosion
extends Area3D

var damage := 30.0
var radius := 4.0
var owner_peer := 0
var hurts_explorers := false
var hurts_beast := true
var _done := false


func setup(pos: Vector3, p_radius: float, p_damage: float, peer: int, vs_explorers: bool, vs_beast: bool) -> void:
	global_position = pos
	radius = p_radius
	damage = p_damage
	owner_peer = peer
	hurts_explorers = vs_explorers
	hurts_beast = vs_beast
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	add_child(col)
	_spawn_vfx()
	# Esperar un frame para overlaps
	await get_tree().physics_frame
	await get_tree().physics_frame
	_apply_damage()
	await get_tree().create_timer(0.45).timeout
	queue_free()


func _spawn_vfx() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.1, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	add_child(mesh)
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE * (radius * 2.2), 0.25)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)


func _apply_damage() -> void:
	if _done or not multiplayer.is_server():
		return
	_done = true
	for body in get_overlapping_bodies():
		if body is BeastPlayer and hurts_beast:
			var b := body as BeastPlayer
			if b.peer_id != owner_peer:
				b.apply_damage.rpc(damage, 0.3, 1.0, owner_peer)
		elif body is ExplorerPlayer and hurts_explorers:
			var e := body as ExplorerPlayer
			if e.peer_id != owner_peer:
				e.apply_projectile_hit.rpc(e.peer_id, damage, 0.0, 0.0)

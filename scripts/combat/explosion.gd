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
	collision_mask = 2 | 4  # players + núcleos Blindados
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
	CombatVfx.burst(self, global_position, Color(1.0, 0.55, 0.1), radius * 0.9, 12)
	CombatVfx.ring(self, global_position, Color(1.0, 0.4, 0.05), radius)
	AudioDirector.play_explosion()
	# La bola de fuego es otro one-shot del pool: no hace falta malla ni material
	# propios que morirán en 0.3 s.
	FxPool.flash(global_position, Color(1.0, 0.5, 0.08), maxf(radius * 0.45, 0.3), 0.3)


func _apply_damage() -> void:
	if _done or not NetworkManager.is_match_authority():
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
				e.apply_projectile_hit.rpc(e.peer_id, damage, 0.0, 0.0, owner_peer)
		elif body is BeastObjective and hurts_beast:
			(body as BeastObjective).apply_shield_damage(damage)

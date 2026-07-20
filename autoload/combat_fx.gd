extends Node

## FX de combate. Las réplicas se hacen UNA vez desde el servidor.

const PROJECTILE_SCRIPT := preload("res://scripts/combat/projectile.gd")
const EXPLOSION_SCRIPT := preload("res://scripts/combat/explosion.gd")


func replicate_shot(from: Vector3, dir: Vector3, data: Dictionary, peer: int, vs_explorers: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_shot_rpc.rpc(from, dir, data, peer, vs_explorers)
	else:
		_shot_rpc(from, dir, data, peer, vs_explorers)


@rpc("authority", "call_local", "reliable")
func _shot_rpc(from: Vector3, dir: Vector3, data: Dictionary, peer: int, vs_explorers: bool) -> void:
	_local_muzzle(from, data.get("color", Color.WHITE))
	_local_projectile(from, dir, data, peer, vs_explorers)


func replicate_explosion(pos: Vector3, radius: float, damage: float, peer: int, vs_explorers: bool, vs_beast: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_explosion_rpc.rpc(pos, radius, damage, peer, vs_explorers, vs_beast)
	else:
		_explosion_rpc(pos, radius, damage, peer, vs_explorers, vs_beast)


@rpc("authority", "call_local", "reliable")
func _explosion_rpc(pos: Vector3, radius: float, damage: float, peer: int, vs_explorers: bool, vs_beast: bool) -> void:
	_local_explosion(pos, radius, damage, peer, vs_explorers, vs_beast)


func spawn_explosion(pos: Vector3, radius: float, damage: float, peer: int, vs_explorers: bool, vs_beast: bool) -> void:
	## Llamar solo desde servidor (p.ej. proyectil al impactar).
	replicate_explosion(pos, radius, damage, peer, vs_explorers, vs_beast)


func spawn_projectile(from: Vector3, dir: Vector3, data: Dictionary, peer: int, vs_explorers: bool = false) -> void:
	replicate_shot(from, dir, data, peer, vs_explorers)


func spawn_muzzle_flash(pos: Vector3, color: Color) -> void:
	_local_muzzle(pos, color)


func _local_projectile(from: Vector3, dir: Vector3, data: Dictionary, peer: int, vs_explorers: bool) -> void:
	var p := Area3D.new()
	p.set_script(PROJECTILE_SCRIPT)
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(p, true)
	p.setup(from, dir, data, peer, vs_explorers)


func _local_explosion(pos: Vector3, radius: float, damage: float, peer: int, vs_explorers: bool, vs_beast: bool) -> void:
	var e := Area3D.new()
	e.set_script(EXPLOSION_SCRIPT)
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(e, true)
	e.setup(pos, radius, damage, peer, vs_explorers, vs_beast)


func _local_muzzle(pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mesh.material_override = mat
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(mesh)
	mesh.global_position = pos
	var tween := mesh.create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE * 2.2, 0.07)
	tween.tween_callback(mesh.queue_free)

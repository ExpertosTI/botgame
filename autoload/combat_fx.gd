extends Node

## FX de combate + puerta de disparo (ruta fija /root/CombatFx para RPC).

const PROJECTILE_SCRIPT := preload("res://scripts/combat/projectile.gd")
const EXPLOSION_SCRIPT := preload("res://scripts/combat/explosion.gd")


func request_weapon_fire(weapon_id: int, origin: Vector3, dir: Vector3, peer: int, beast: bool) -> void:
	## Clientes → servidor por autoload (evita RPCs rotos en CombatKit dinámico).
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_run_weapon_fire(weapon_id, origin, dir, peer, beast)
		else:
			_rpc_weapon_fire.rpc_id(1, weapon_id, origin, dir, peer, beast)
	else:
		_run_weapon_fire(weapon_id, origin, dir, peer, beast)


func request_ability(ability_id: int, peer: int) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_run_ability(ability_id, peer)
		else:
			_rpc_ability.rpc_id(1, ability_id, peer)
	else:
		_run_ability(ability_id, peer)


@rpc("any_peer", "reliable")
func _rpc_ability(ability_id: int, peer: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer:
		peer = sender
	_run_ability(ability_id, peer)


func _run_ability(ability_id: int, peer: int) -> void:
	var player := _find_player(peer)
	if player and player.combat:
		player.combat.execute_server_ability(ability_id)


@rpc("any_peer", "reliable")
func _rpc_weapon_fire(weapon_id: int, origin: Vector3, dir: Vector3, peer: int, beast: bool) -> void:
	if not multiplayer.is_server():
		return
	# Anti-spoof básico: el peer debe coincidir con el sender
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer:
		peer = sender
	_run_weapon_fire(weapon_id, origin, dir, peer, beast)


func _run_weapon_fire(weapon_id: int, origin: Vector3, dir: Vector3, peer: int, beast: bool) -> void:
	var player := _find_player(peer)
	if player and player.combat:
		player.combat.execute_server_fire(weapon_id, origin, dir, peer, beast)
	else:
		# Fallback sin kit (aún spawnea FX)
		_fallback_fire(weapon_id, origin, dir, peer, beast)


func _find_player(peer: int) -> PlayerBase:
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is PlayerBase and (node as PlayerBase).peer_id == peer:
			return node as PlayerBase
	return null


func _fallback_fire(weapon_id: int, origin: Vector3, dir: Vector3, peer: int, beast: bool) -> void:
	var data: Dictionary = WeaponDefs.weapon_data(weapon_id)
	var vs_explorers := beast
	match data.get("type", ""):
		"projectile", "shotgun", "grenade":
			replicate_shot(origin, dir, data, peer, vs_explorers)
		"explosion":
			replicate_explosion(origin, float(data.get("radius", 5.0)), float(data.get("damage", 30)), peer, vs_explorers, not vs_explorers)


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

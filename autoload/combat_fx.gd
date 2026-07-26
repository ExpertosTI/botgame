extends Node

## FX de combate + puerta de disparo (ruta fija /root/CombatFx para RPC).

const EXPLOSION_SCRIPT := preload("res://scripts/combat/explosion.gd")


func request_weapon_fire(weapon_id: int, origin: Vector3, dir: Vector3, peer: int, beast: bool) -> void:
	## Clientes → servidor por autoload (evita RPCs rotos en CombatKit dinámico).
	if NetworkManager.is_match_authority():
		_run_weapon_fire(weapon_id, origin, dir, peer, beast)
	elif multiplayer.has_multiplayer_peer():
		_rpc_weapon_fire.rpc_id(1, weapon_id, origin, dir, peer, beast)
	else:
		_run_weapon_fire(weapon_id, origin, dir, peer, beast)


func request_ability(ability_id: int, peer: int) -> void:
	if NetworkManager.is_match_authority():
		_run_ability(ability_id, peer)
	elif multiplayer.has_multiplayer_peer():
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
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_shot_rpc.rpc(from, dir, data, peer, vs_explorers)
	else:
		_shot_rpc(from, dir, data, peer, vs_explorers)


@rpc("authority", "call_local", "reliable")
func _shot_rpc(from: Vector3, dir: Vector3, data: Dictionary, peer: int, vs_explorers: bool) -> void:
	_local_projectile(from, dir, data, peer, vs_explorers)


## El fogonazo es de la ráfaga, no del perdigón: la escopeta llamaba a _shot_rpc
## cinco veces y encendía cinco destellos en el mismo punto.
##
## Lleva el peer del tirador porque la animación de disparo se lanza aquí: es el
## único punto por el que pasa una vez cada disparo y que ven todas las
## máquinas, así que también anima al tirador en las pantallas de los demás.
func replicate_muzzle(from: Vector3, color: Color, peer: int = 0) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_muzzle_rpc.rpc(from, color, peer)
	else:
		_muzzle_rpc(from, color, peer)


@rpc("authority", "call_local", "unreliable")
func _muzzle_rpc(from: Vector3, color: Color, peer: int = 0) -> void:
	_local_muzzle(from, color)
	if peer != 0:
		var shooter := _find_player(peer)
		if shooter:
			shooter.play_action("shoot")


func replicate_explosion(pos: Vector3, radius: float, damage: float, peer: int, vs_explorers: bool, vs_beast: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_explosion_rpc.rpc(pos, radius, damage, peer, vs_explorers, vs_beast)
	else:
		_explosion_rpc(pos, radius, damage, peer, vs_explorers, vs_beast)


@rpc("authority", "call_local", "reliable")
func _explosion_rpc(pos: Vector3, radius: float, damage: float, peer: int, vs_explorers: bool, vs_beast: bool) -> void:
	_local_explosion(pos, radius, damage, peer, vs_explorers, vs_beast)


func replicate_melee(peer: int, weapon_id: int, _beast: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_melee_rpc.rpc(peer, weapon_id)
	else:
		_melee_rpc(peer, weapon_id)


@rpc("authority", "call_local", "reliable")
func _melee_rpc(peer: int, weapon_id: int) -> void:
	var player := _find_player(peer)
	if player:
		## Telegraph corto: un anillo antes del golpe para que el Robot lea el melee.
		CombatVfx.ring(player, player.global_position, Color(1.0, 0.45, 0.2), 1.6)
		player.play_action("shoot")
		if player.combat:
			player.combat.apply_melee_hits(weapon_id)


func replicate_roar(peer: int, weapon_id: int) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_roar_rpc.rpc(peer, weapon_id)
	else:
		_roar_rpc(peer, weapon_id)


@rpc("authority", "call_local", "reliable")
func _roar_rpc(peer: int, weapon_id: int) -> void:
	var player := _find_player(peer)
	if player and player.combat:
		player.combat.apply_roar_hits(weapon_id)


func replicate_ability(peer: int, ability_id: int) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_ability_fx_rpc.rpc(peer, ability_id)
	else:
		_ability_fx_rpc(peer, ability_id)


@rpc("authority", "call_local", "reliable")
func _ability_fx_rpc(peer: int, ability_id: int) -> void:
	var player := _find_player(peer)
	if player and player.combat:
		player.combat.apply_ability_effects(ability_id)


func spawn_explosion(pos: Vector3, radius: float, damage: float, peer: int, vs_explorers: bool, vs_beast: bool) -> void:
	replicate_explosion(pos, radius, damage, peer, vs_explorers, vs_beast)


func spawn_trap_mine(
	pos: Vector3,
	peer: int,
	damage: float,
	radius: float,
	vs_explorers: bool,
	vs_beast: bool
) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_trap_rpc.rpc(pos, peer, damage, radius, vs_explorers, vs_beast)
	else:
		_trap_rpc(pos, peer, damage, radius, vs_explorers, vs_beast)


@rpc("authority", "call_local", "reliable")
func _trap_rpc(
	pos: Vector3,
	peer: int,
	damage: float,
	radius: float,
	vs_explorers: bool,
	vs_beast: bool
) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var mine := TrapMine.new()
	root.add_child(mine, true)
	mine.setup(pos, peer, damage, radius, vs_explorers, vs_beast)


func spawn_projectile(from: Vector3, dir: Vector3, data: Dictionary, peer: int, vs_explorers: bool = false) -> void:
	replicate_shot(from, dir, data, peer, vs_explorers)


func spawn_muzzle_flash(pos: Vector3, color: Color) -> void:
	_local_muzzle(pos, color)


func _local_projectile(from: Vector3, dir: Vector3, data: Dictionary, peer: int, vs_explorers: bool) -> void:
	var p := FxPool.acquire_projectile()
	if p == null:
		return
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
	## Un destello, no dos: antes esto pintaba el flash del pool y además su
	## propia esfera con material nuevo, exactamente encima.
	FxPool.flash(pos, color, 0.24, 0.1)


## Pings tácticos. kind: 0=Ayuda, 1=Bestia, 2=Saboteando.
const PING_TTL := 2.6
const PING_RATE := 1.1
var _ping_cd := 0.0
var _ping_markers: Array = []


func _process(delta: float) -> void:
	_ping_cd = maxf(_ping_cd - delta, 0.0)
	_tick_ping_markers(delta)


func request_ping(peer: int, kind: int, pos: Vector3) -> void:
	if _ping_cd > 0.0:
		return
	_ping_cd = PING_RATE
	if NetworkManager.is_match_authority():
		_run_ping(peer, kind, pos)
	elif multiplayer.has_multiplayer_peer():
		_rpc_ping.rpc_id(1, peer, kind, pos)
	else:
		_run_ping(peer, kind, pos)


@rpc("any_peer", "reliable")
func _rpc_ping(peer: int, kind: int, pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer:
		peer = sender
	_run_ping(peer, kind, pos)


func _run_ping(peer: int, kind: int, pos: Vector3) -> void:
	kind = clampi(kind, 0, 2)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_ping_rpc.rpc(peer, kind, pos)
	else:
		_ping_rpc(peer, kind, pos)


@rpc("authority", "call_local", "unreliable")
func _ping_rpc(peer: int, kind: int, pos: Vector3) -> void:
	_spawn_ping_marker(peer, kind, pos)
	AudioDirector.play_ui("click")


func _spawn_ping_marker(peer: int, kind: int, pos: Vector3) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var lab := Label3D.new()
	lab.text = _ping_label(kind)
	lab.font_size = 56
	lab.modulate = _ping_color(kind)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = pos + Vector3(0, 1.6, 0)
	root.add_child(lab)
	CombatVfx.ring(root, pos, _ping_color(kind), 1.8)
	_ping_markers.append({"node": lab, "t": PING_TTL, "kind": kind, "pos": pos, "peer": peer})


func _tick_ping_markers(delta: float) -> void:
	var i := 0
	while i < _ping_markers.size():
		var m: Dictionary = _ping_markers[i]
		m["t"] = float(m["t"]) - delta
		var node: Label3D = m["node"]
		if node == null or not is_instance_valid(node) or float(m["t"]) <= 0.0:
			if node != null and is_instance_valid(node):
				node.queue_free()
			_ping_markers.remove_at(i)
			continue
		node.modulate.a = clampf(float(m["t"]) / PING_TTL, 0.0, 1.0)
		_ping_markers[i] = m
		i += 1


func _ping_label(kind: int) -> String:
	match kind:
		1:
			return "BESTIA AQUÍ"
		2:
			return "SABOTEANDO"
		_:
			return "AYUDA"


func _ping_color(kind: int) -> Color:
	match kind:
		1:
			return Color(1.0, 0.35, 0.2)
		2:
			return Color(0.95, 0.85, 0.25)
		_:
			return Color(0.35, 0.85, 1.0)


func active_pings() -> Array:
	return _ping_markers

class_name PracticeAI
extends Node

## IA de campaña: caza, sabotaje, kiting y uso de habilidades.

var body: CharacterBody3D
var is_beast := false
var aggression := 1.0
var _fire_cd := 0.0
var _ability_cd := 0.0
var _repath_t := 0.0
var _wander_dir := Vector3.FORWARD
var _sabotage_hold := 0.0
var _state := "hunt"
var _state_t := 0.0

## Esquiva de obstáculos. No hay navmesh, así que los bots iban en línea recta y
## se quedaban empotrados contra contenedores, torres y esquinas hasta que el
## objetivo se movía. Con esto tantean con rayos y rodean.
const PROBE_LEN := 3.2
const PROBE_ANGLES := [0.0, 0.45, -0.45, 0.9, -0.9, 1.35, -1.35, 1.8, -1.8]
## Altura a la que se tantea: por debajo del pecho, para no confundir un cajón
## saltable con un muro.
const PROBE_LOW := 0.35
const PROBE_HIGH := 1.5
var _stuck_t := 0.0
var _stuck_cycles := 0
var _last_pos := Vector3.ZERO
var _detour_sign := 1.0
var _detour_t := 0.0
var _reverse_t := 0.0


func setup(player: CharacterBody3D, beast: bool) -> void:
	body = player
	is_beast = beast
	player.set_meta("is_bot", true)
	player.set_multiplayer_authority(1)
	aggression = 0.85 if GameManager.easy_beast_mode and beast else 1.0
	if ProgressionManager.campaign_mode:
		aggression += float(ProgressionManager.selected_level) * 0.04


func _physics_process(delta: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not GameManager.match_active:
		return
	if body is ExplorerPlayer and not (body as ExplorerPlayer).is_alive():
		return

	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_ability_cd = maxf(_ability_cd - delta, 0.0)
	_repath_t -= delta
	_state_t -= delta
	_track_stuck(delta)
	if is_beast:
		_tick_beast(delta)
	else:
		_tick_robot(delta)


func _tick_beast(delta: float) -> void:
	var target := _nearest_alive_explorer()
	if target == null:
		_state = "wander"
		_wander(delta, 4.5 * aggression)
		return
	var dist := body.global_position.distance_to(target.global_position)
	_face_toward(target.global_position)

	# Habilidades situacionales
	if _ability_cd <= 0.0 and body is PlayerBase:
		var kit := (body as PlayerBase).combat
		if kit:
			if dist > 9.0 and kit.abilities.size() > 1:
				kit.use_ability(1)  # leap / cloak / spikes
				_ability_cd = 2.4
			elif dist < 3.5 and kit.abilities.size() > 2:
				kit.use_ability(2)
				_ability_cd = 3.0
			elif dist < 6.0 and kit.abilities.size() > 0 and randf() < 0.35:
				kit.use_ability(0)
				_ability_cd = 2.0

	if dist > 2.2:
		var spd := (6.4 if not GameManager.easy_beast_mode else 5.3) * aggression
		_move_toward(target.global_position, spd, delta)
		_state = "chase"
	else:
		_brake(delta)
		_state = "melee"
	if dist < 9.0 and _fire_cd <= 0.0:
		_bot_fire()
		_fire_cd = (0.45 if dist < 3.0 else 0.95) / maxf(aggression, 0.5)


func _tick_robot(delta: float) -> void:
	var beast := _find_beast()
	var core := _nearest_core()
	var pickup := _nearest_powerup()
	var threat := 0.0
	if beast:
		threat = body.global_position.distance_to(beast.global_position)

	# Huir / kite
	if beast and threat < 7.8:
		_state = "flee"
		var flee := body.global_position + (body.global_position - beast.global_position).normalized() * 7.0
		_face_toward(beast.global_position)
		_move_toward(flee, 6.8 * aggression, delta)
		if _fire_cd <= 0.0:
			_bot_fire()
			_fire_cd = 0.55
		if _ability_cd <= 0.0 and body is PlayerBase:
			var kit := (body as PlayerBase).combat
			if kit and kit.abilities.size() > 0:
				kit.use_ability(0)  # dash
				if kit.abilities.size() > 1 and threat < 5.0:
					kit.use_ability(1)  # shield
				_ability_cd = 2.2
		_cancel_bot_sabotage()
		return

	# Recoger powerup cercano
	if pickup and body.global_position.distance_to(pickup.global_position) < 10.0 and (core == null or threat > 10.0):
		_state = "loot"
		_face_toward(pickup.global_position)
		_move_toward(pickup.global_position, 6.0, delta)
		return

	if core == null:
		if beast:
			_state = "kite"
			_face_toward(beast.global_position)
			if threat > 11.0:
				_move_toward(beast.global_position, 5.2, delta)
			else:
				_wander(delta, 5.5)
			if _fire_cd <= 0.0 and threat < 16.0:
				_bot_fire()
				_fire_cd = 0.65
		else:
			_wander(delta, 5.5)
		return

	var dist := body.global_position.distance_to(core.global_position)
	_face_toward(core.global_position)
	_state = "sabotage"
	var obj := core as BeastObjective
	## Blindado con escudo: el bot dispara hasta romperlo, no se queda pegado.
	if obj != null and not obj.can_accept_sabotage():
		_cancel_bot_sabotage()
		if dist > 7.0:
			_move_toward(core.global_position, 5.4 * aggression, delta)
		else:
			_brake(delta)
			if _fire_cd <= 0.0:
				_bot_fire()
		return
	if dist > 2.2:
		_move_toward(core.global_position, 5.9 * aggression, delta)
		_cancel_bot_sabotage()
	else:
		_brake(delta)
		_bot_sabotage(delta)
		if beast and threat < 12.0 and _fire_cd <= 0.0:
			_face_toward(beast.global_position)
			_bot_fire()
			_fire_cd = 0.8


func _bot_fire() -> void:
	if body is PlayerBase:
		var p := body as PlayerBase
		if p.combat:
			p.combat.fire(p.get_aim_origin(), p.get_aim_dir())


## El bot canaliza como el jugador. Antes llamaba a `sabotage()` directo al
## segundo y medio, saltándose el temporizador de 1,8 s y la interrupción por
## daño: jugando de Bestia era imposible defender un núcleo porque el bot no
## pagaba el precio que sí paga un humano.
func _bot_sabotage(delta: float) -> void:
	var core := _nearest_core()
	if core == null or not (core is BeastObjective):
		return
	if not (body is ExplorerPlayer):
		return
	var ex := body as ExplorerPlayer
	_sabotage_hold += delta
	if not ex.is_sabotaging:
		_aim_interact_ray()
		ex.call("_try_sabotage")
	if ex.is_sabotaging:
		# El temporizador del propio explorador termina el trabajo y dispara
		# _on_sabotage_complete, con sus stats y su sonido.
		return

	# Salvavidas: si el rayo de interacción no llega a enganchar el núcleo (el bot
	# no encara tan fino como una persona), se remata a mano — pero solo tras el
	# mismo tiempo que le costaría al jugador, nunca antes.
	var obj := core as BeastObjective
	if not obj.can_accept_sabotage():
		return
	var channel: float = ex.sabotage_time * float(obj.sabotage_time_mult)
	if _sabotage_hold >= channel * 1.6:
		_sabotage_hold = 0.0
		obj.sabotage.rpc()
		MatchStats.record_core(ex.peer_id)


func _cancel_bot_sabotage() -> void:
	_sabotage_hold = 0.0
	if body is ExplorerPlayer:
		var ex := body as ExplorerPlayer
		if ex.is_sabotaging and ex.has_method("_cancel_sabotage"):
			ex.call("_cancel_sabotage")


func _aim_interact_ray() -> void:
	if not (body is ExplorerPlayer):
		return
	var ex := body as ExplorerPlayer
	var ray: RayCast3D = ex.get_node_or_null("CameraPivot/Camera3D/InteractRay") as RayCast3D
	if ray == null:
		return
	var core := _nearest_core()
	if core == null:
		return
	_face_toward(core.global_position)
	ray.force_raycast_update()


func _face_toward(world_pos: Vector3) -> void:
	var flat := Vector3(world_pos.x, body.global_position.y, world_pos.z)
	if flat.distance_to(body.global_position) < 0.15:
		return
	var dir := flat - body.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	body.rotation.y = atan2(-dir.x, -dir.z)
	if body is PlayerBase:
		var pivot: Node3D = (body as PlayerBase).camera_pivot
		if pivot:
			var to := world_pos - (body as PlayerBase).camera.global_position
			var pitch := atan2(-to.y, Vector2(to.x, to.z).length())
			pivot.rotation.x = clampf(pitch, -0.9, 0.55)


## Lleva la cuenta de cuánto avanza de verdad. Si pide moverse y no se mueve, es
## que hay algo delante que los rayos no vieron (una esquina, otro bot), así que
## se fuerza un rodeo temporal en vez de seguir empujando la pared.
func _track_stuck(delta: float) -> void:
	_detour_t = maxf(_detour_t - delta, 0.0)
	_reverse_t = maxf(_reverse_t - delta, 0.0)
	var moved := body.global_position.distance_to(_last_pos)
	_last_pos = body.global_position
	if _state == "idle":
		_stuck_t = 0.0
		return
	## También en sabotage: acercarse al núcleo suele atascar contra props.
	if moved < 0.025:
		_stuck_t += delta
		if _stuck_t > 0.55:
			_stuck_t = 0.0
			_stuck_cycles += 1
			_detour_sign = 1.0 if randf() < 0.5 else -1.0
			_detour_t = 0.9 + mini(float(_stuck_cycles) * 0.25, 1.2)
			if _stuck_cycles >= 3:
				_reverse_t = 0.55
				_stuck_cycles = 0
				if body.is_on_floor() and body is PlayerBase:
					body.velocity.y = (body as PlayerBase).jump_velocity * 0.85
	else:
		_stuck_t = 0.0
		if moved > 0.08:
			_stuck_cycles = 0


func _space() -> PhysicsDirectSpaceState3D:
	return body.get_world_3d().direct_space_state


func _path_blocked(from: Vector3, dir: Vector3, height: float) -> bool:
	var origin := from + Vector3(0, height, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * PROBE_LEN)
	query.exclude = [body.get_rid()]
	query.collision_mask = 1  # mundo / props
	return not _space().intersect_ray(query).is_empty()


## Devuelve la dirección libre más parecida a la deseada.
func _steer(desired: Vector3) -> Vector3:
	var from := body.global_position
	if _reverse_t > 0.0:
		desired = -desired
	elif _detour_t > 0.0:
		desired = desired.rotated(Vector3.UP, 1.35 * _detour_sign)
	for angle in PROBE_ANGLES:
		var candidate := desired.rotated(Vector3.UP, float(angle))
		if not _path_blocked(from, candidate, PROBE_HIGH):
			return candidate
	## Todo cerrado: empuja perpendicular para salir de rincones.
	return desired.rotated(Vector3.UP, 1.57 * _detour_sign)


## Un cajón a la altura de la rodilla se salta; un muro no. Se distingue mirando
## si el rayo bajo choca y el alto no.
func _should_hop(dir: Vector3) -> bool:
	if not body.is_on_floor():
		return false
	var from := body.global_position
	return _path_blocked(from, dir, PROBE_LOW) and not _path_blocked(from, dir, PROBE_HIGH)


func _move_toward(world_pos: Vector3, speed: float, delta: float) -> void:
	var dir := world_pos - body.global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		_brake(delta)
		return
	dir = _steer(dir.normalized())
	var avoid := _hazard_avoid()
	if avoid != Vector3.ZERO:
		dir = (dir + avoid * 1.35).normalized()
	if _should_hop(dir) and body is PlayerBase:
		body.velocity.y = (body as PlayerBase).jump_velocity
	if not body.is_on_floor():
		body.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	var mult := 1.0
	if body is PlayerBase and (body as PlayerBase).combat:
		mult = (body as PlayerBase).combat.speed_mult
	body.velocity.x = dir.x * speed * mult
	body.velocity.z = dir.z * speed * mult
	if body is PlayerBase:
		(body as PlayerBase).set_locomotion(true, speed > 5.5)
	body.move_and_slide()


func _hazard_avoid() -> Vector3:
	var tree := body.get_tree()
	if tree == null:
		return Vector3.ZERO
	for n in tree.get_nodes_in_group("hazard_systems"):
		if n.has_method("danger_push"):
			return n.danger_push(body.global_position)
	## Fallback: buscar por nombre si el grupo aún no está.
	var hazards := tree.root.find_child("Hazards", true, false)
	if hazards and hazards.has_method("danger_push"):
		return hazards.danger_push(body.global_position)
	return Vector3.ZERO


func _brake(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	body.velocity.x = move_toward(body.velocity.x, 0, 20.0 * delta)
	body.velocity.z = move_toward(body.velocity.z, 0, 20.0 * delta)
	if body is PlayerBase:
		(body as PlayerBase).set_locomotion(false)
	body.move_and_slide()


func _wander(delta: float, speed: float) -> void:
	if _repath_t <= 0.0:
		_repath_t = randf_range(1.0, 2.4)
		var a := randf() * TAU
		_wander_dir = Vector3(cos(a), 0, sin(a))
	var dest := body.global_position + _wander_dir * 4.0
	_face_toward(dest)
	_move_toward(dest, speed, delta)


func _nearest_alive_explorer() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in body.get_tree().get_nodes_in_group("player_characters"):
		if n == body:
			continue
		if n is ExplorerPlayer and (n as ExplorerPlayer).is_alive():
			var d := body.global_position.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
	return best


func _find_beast() -> Node3D:
	for n in body.get_tree().get_nodes_in_group("player_characters"):
		if n is BeastPlayer:
			return n
	return null


func _nearest_core() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in body.get_tree().get_nodes_in_group("beast_objectives"):
		if n is BeastObjective and (n as BeastObjective).is_active:
			## Preferir núcleos ya canalizables; si todos están cerrados/blindados,
			## aún así ir al más cercano para romper escudo o esperar Relé.
			var d := body.global_position.distance_to(n.global_position)
			if (n as BeastObjective).can_accept_sabotage():
				d *= 0.55
			if d < best_d:
				best_d = d
				best = n
	return best


func _nearest_powerup() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	var powers := body.get_tree().get_nodes_in_group("powerups")
	for a in powers:
		if not is_instance_valid(a):
			continue
		var d := body.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best
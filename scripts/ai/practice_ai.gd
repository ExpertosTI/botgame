class_name PracticeAI
extends Node

## IA simple para campaña / práctica solitaria.

var body: CharacterBody3D
var is_beast := false
var _fire_cd := 0.0
var _repath_t := 0.0
var _wander_dir := Vector3.FORWARD
var _sabotage_hold := 0.0


func setup(player: CharacterBody3D, beast: bool) -> void:
	body = player
	is_beast = beast
	player.set_meta("is_bot", true)
	# En offline todos bajo autoridad local (peer 1)
	player.set_multiplayer_authority(1)


func _physics_process(delta: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not GameManager.match_active:
		return
	if body is ExplorerPlayer and not (body as ExplorerPlayer).alive:
		return

	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_repath_t -= delta
	if is_beast:
		_tick_beast(delta)
	else:
		_tick_robot(delta)


func _tick_beast(delta: float) -> void:
	var target := _nearest_alive_explorer()
	if target == null:
		_wander(delta, 4.5)
		return
	_face_toward(target.global_position)
	var dist := body.global_position.distance_to(target.global_position)
	if dist > 2.4:
		_move_toward(target.global_position, 6.2 if not GameManager.easy_beast_mode else 5.2, delta)
	else:
		_brake(delta)
	if dist < 8.0 and _fire_cd <= 0.0:
		_bot_fire()
		_fire_cd = 0.55 if dist < 3.0 else 1.1


func _tick_robot(delta: float) -> void:
	var beast := _find_beast()
	var core := _nearest_core()
	# Huir si la bestia está cerca
	if beast and body.global_position.distance_to(beast.global_position) < 7.5:
		var flee := body.global_position + (body.global_position - beast.global_position).normalized() * 6.0
		_face_toward(beast.global_position)
		_move_toward(flee, 6.6, delta)
		if _fire_cd <= 0.0:
			_bot_fire()
			_fire_cd = 0.7
		_cancel_bot_sabotage()
		return

	if core == null:
		_wander(delta, 5.5)
		return

	var dist := body.global_position.distance_to(core.global_position)
	_face_toward(core.global_position)
	if dist > 2.2:
		_move_toward(core.global_position, 5.8, delta)
		_cancel_bot_sabotage()
	else:
		_brake(delta)
		_bot_sabotage(delta)


func _bot_fire() -> void:
	if body is PlayerBase:
		var p := body as PlayerBase
		if p.combat:
			p.combat.fire(p.get_aim_origin(), p.get_aim_dir())


func _bot_sabotage(delta: float) -> void:
	var core := _nearest_core()
	if core == null or not (core is BeastObjective):
		return
	_sabotage_hold += delta
	# Barra visual vía explorer si existe
	if body is ExplorerPlayer:
		var ex := body as ExplorerPlayer
		if not ex.is_sabotaging:
			_aim_interact_ray()
			ex.call("_try_sabotage")
	# Fallback fiable: sabotaje directo tras tiempo de canalización
	if _sabotage_hold >= 1.8:
		_sabotage_hold = 0.0
		(core as BeastObjective).sabotage()
		if body is ExplorerPlayer and (body as ExplorerPlayer).is_sabotaging:
			(body as ExplorerPlayer).call("_cancel_sabotage")


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
	# Orientar cuerpo/cámara hacia el núcleo
	_face_toward(core.global_position)
	ray.force_raycast_update()


func _face_toward(world_pos: Vector3) -> void:
	var flat := Vector3(world_pos.x, body.global_position.y, world_pos.z)
	if flat.distance_to(body.global_position) < 0.05:
		return
	body.look_at(flat, Vector3.UP)
	if body is PlayerBase:
		var pivot: Node3D = (body as PlayerBase).camera_pivot
		if pivot:
			var to := world_pos - (body as PlayerBase).camera.global_position
			var pitch := atan2(-to.y, Vector2(to.x, to.z).length())
			pivot.rotation.x = clampf(pitch, -0.9, 0.55)


func _move_toward(world_pos: Vector3, speed: float, delta: float) -> void:
	var dir := world_pos - body.global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		_brake(delta)
		return
	dir = dir.normalized()
	if not body.is_on_floor():
		body.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	var mult := 1.0
	if body is PlayerBase and (body as PlayerBase).combat:
		mult = (body as PlayerBase).combat.speed_mult
	body.velocity.x = dir.x * speed * mult
	body.velocity.z = dir.z * speed * mult
	if body is PlayerBase and (body as PlayerBase).crew:
		(body as PlayerBase).crew.set_moving(true)
	body.move_and_slide()


func _brake(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	body.velocity.x = move_toward(body.velocity.x, 0, 20.0 * delta)
	body.velocity.z = move_toward(body.velocity.z, 0, 20.0 * delta)
	if body is PlayerBase and (body as PlayerBase).crew:
		(body as PlayerBase).crew.set_moving(false)
	body.move_and_slide()


func _wander(delta: float, speed: float) -> void:
	if _repath_t <= 0.0:
		_repath_t = randf_range(1.2, 2.8)
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
		if n is ExplorerPlayer and (n as ExplorerPlayer).alive:
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
			var d := body.global_position.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
	return best

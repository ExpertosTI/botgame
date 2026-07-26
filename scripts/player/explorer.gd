class_name ExplorerPlayer
extends PlayerBase

## El HUD lo usa para avisar de que un golpe tiró abajo el sabotaje.
signal sabotage_interrupted

@export var sabotage_time := 1.8

@onready var sabotage_timer: Timer = $SabotageTimer
@onready var interact_ray: RayCast3D = $CameraPivot/Camera3D/InteractRay

var lives := GameManager.EXPLORER_LIVES
var is_sabotaging := false
var alive := true
var _respawning := false
var variant: GameManager.ExplorerVariant = GameManager.ExplorerVariant.ROBOT_BLUE
var hp := 100.0  # daño de explosiones/proyectiles bestia; 0 = pierde una vida
## Núcleo que se está canalizando: sin esto, al girar un pelo al terminar el
## hold, looking_core() fallaba y el sabotaje completo no destruía nada.
var _channel_target: BeastObjective = null


func _ready() -> void:
	super._ready()
	sabotage_timer.wait_time = sabotage_time
	sabotage_timer.timeout.connect(_on_sabotage_complete)
	if GameManager.explorer_variants.has(peer_id):
		variant = GameManager.explorer_variants[peer_id]
	if GameManager.explorer_lives.has(peer_id):
		lives = GameManager.explorer_lives[peer_id]
	move_speed = 6.4
	_apply_robot_visuals()
	var loadout_id := 0
	if GameManager.explorer_loadouts.has(peer_id):
		loadout_id = int(GameManager.explorer_loadouts[peer_id])
	elif NetworkManager.players.has(peer_id):
		loadout_id = int(NetworkManager.players[peer_id].get("loadout", 0))
	combat.setup(self, false, loadout_id)


func _apply_robot_visuals() -> void:
	if crew == null:
		return
	crew.is_beast = false
	var cat_idx := int(GameManager.explorer_characters.get(peer_id, int(NetworkManager.players.get(peer_id, {}).get("skin", 0))))
	var entry := CharacterCatalog.get_entry(cat_idx)
	var color: Color = entry.get("tint", GameManager.get_explorer_color(variant)) if not entry.is_empty() else GameManager.get_explorer_color(variant)
	crew.apply_colors(color, Color(0.75, 0.95, 1.0), color.lightened(0.2))
	var pname: String = str(NetworkManager.players.get(peer_id, {}).get("name", "Robot"))
	crew.set_player_name(pname)
	# Diferir mesh un frame: evita freeze al spawnear en Web
	call_deferred("_attach_catalog_mesh", cat_idx, 0.85)


func _attach_catalog_mesh(cat_idx: int, scale_mult: float) -> void:
	var mesh_parent: Node3D = get_node_or_null("Mesh") as Node3D
	if mesh_parent == null:
		return
	var existing := mesh_parent.get_node_or_null("CatalogMesh")
	if existing:
		mesh_parent.remove_child(existing)
		existing.free()
	var attached := CharacterCatalog.attach_mesh(mesh_parent, cat_idx, scale_mult)
	if attached and crew:
		# Ocultar cápsula vieja por completo: solo el GLB 3D
		crew.visible = false
		if crew.name_label:
			# Etiqueta sobre el mesh
			var tag := Label3D.new()
			tag.name = "CatalogName"
			tag.text = str(NetworkManager.players.get(peer_id, {}).get("name", "Robot"))
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.font_size = 48
			tag.outline_size = 8
			tag.position = Vector3(0, 2.05, 0)
			attached.add_child(tag)


func is_alive() -> bool:
	return alive and not _respawning


func _physics_process(delta: float) -> void:
	if not alive or _respawning:
		return
	super._physics_process(delta)
	if has_meta("is_bot") and get_meta("is_bot"):
		return
	if not is_multiplayer_authority():
		return
	## Side-cam: al mantener FIRE cerca de un núcleo, girar hacia él (el stick
	## de mirada no hace yaw y sin esto HOLD no engancha).
	if _side_cam and InputManager.action_primary_held:
		_face_nearest_core(delta)

	# Mantener cerca de núcleo listo = sabotear; si el Blindado aún tiene
	# escudo o el Relé está cerrado, el disparo debe salir (si no, nunca se
	# rompe el escudo porque el hold se come el input).
	var core := looking_core()
	var can_channel := core != null and core.can_accept_sabotage()
	if can_channel and InputManager.action_primary_held:
		_try_sabotage()
	else:
		if is_sabotaging:
			_cancel_sabotage()
		if InputManager.action_primary_just or (InputManager.action_primary_held and _auto_fire_ready()):
			combat.fire(get_aim_origin(), get_aim_dir())

	if is_sabotaging and not _channel_still_valid():
		_cancel_sabotage()
		sabotage_interrupted.emit()

	# Granada rápida (arma granada)
	if InputManager.action_secondary_just:
		_fire_grenade()


func _auto_fire_ready() -> bool:
	# Solo bláster hace hold-to-fire
	return combat.current_weapon_id() == WeaponDefs.WeaponId.BLASTER and combat.can_fire()


func _fire_grenade() -> void:
	var grenade_idx := -1
	for i in combat.weapons.size():
		if combat.weapons[i] == WeaponDefs.WeaponId.GRENADE:
			grenade_idx = i
			break
	if grenade_idx < 0:
		return
	var prev := combat.weapon_index
	combat.select_weapon(grenade_idx)
	combat.fire(get_aim_origin(), get_aim_dir())
	combat.select_weapon(prev)


func looking_at_core() -> bool:
	return looking_core() != null


func can_channel_core() -> bool:
	var core := looking_core()
	return core != null and core.can_accept_sabotage()


func looking_core() -> BeastObjective:
	## Cámara lateral: InteractRay cuelga de la cámara y apunta al cuerpo, nunca
	## al núcleo delante. Sin proximidad el sabotaje en web/móvil está muerto.
	var from_ray := _core_from_interact_ray()
	if from_ray != null:
		return from_ray
	return _core_from_proximity()


func _core_from_interact_ray() -> BeastObjective:
	if interact_ray == null or not interact_ray.is_colliding():
		return null
	var collider := interact_ray.get_collider()
	if collider is BeastObjective and (collider as BeastObjective).is_active:
		return collider as BeastObjective
	return null


func _core_from_proximity() -> BeastObjective:
	var best: BeastObjective = null
	var best_d := 3.4
	var origin := global_position + Vector3(0, 1.0, 0)
	var forward := -transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3(0, 0, -1)
	else:
		forward = forward.normalized()
	## Side-cam: el yaw solo sigue el movimiento; tolerancia amplia.
	var min_dot := -0.25 if _side_cam else 0.15
	for node in get_tree().get_nodes_in_group("beast_objectives"):
		if not (node is BeastObjective):
			continue
		var core := node as BeastObjective
		if not core.is_active:
			continue
		var to := core.global_position - origin
		var d := to.length()
		if d > best_d:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length_squared() > 0.01 and forward.dot(flat.normalized()) < min_dot:
			continue
		best_d = d
		best = core
	return best


func _face_nearest_core(delta: float) -> void:
	var core := _channel_target if is_instance_valid(_channel_target) else _core_from_proximity()
	if core == null:
		return
	var flat := core.global_position - global_position
	flat.y = 0.0
	if flat.length_squared() < 0.04:
		return
	var yaw := atan2(flat.x, flat.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 10.0, 0.0, 1.0))


func _channel_still_valid() -> bool:
	var core := _channel_target if is_instance_valid(_channel_target) else looking_core()
	if core == null or not core.can_accept_sabotage():
		return false
	return global_position.distance_to(core.global_position) <= 4.0


func get_sabotage_progress() -> float:
	if not is_sabotaging or sabotage_timer.is_stopped():
		return 0.0
	var total := maxf(sabotage_timer.wait_time, 0.001)
	return clampf(1.0 - sabotage_timer.time_left / total, 0.0, 1.0)


func _try_sabotage() -> void:
	if is_sabotaging:
		return
	var core := looking_core()
	if core == null or not core.can_accept_sabotage():
		return
	is_sabotaging = true
	_channel_target = core
	sabotage_timer.wait_time = sabotage_time * float(core.sabotage_time_mult)
	sabotage_timer.start()
	_start_sabotage_vfx.rpc()


func _cancel_sabotage() -> void:
	is_sabotaging = false
	_channel_target = null
	sabotage_timer.stop()
	_stop_sabotage_vfx.rpc()


@rpc("any_peer", "call_local", "reliable")
func _start_sabotage_vfx() -> void:
	if crew and crew.visible:
		crew.play_sabotage_pulse(true)
	else:
		CombatVfx.ring(self, global_position + Vector3.UP * 0.4, Color(0.3, 1.0, 0.85), 1.6)


@rpc("any_peer", "call_local", "reliable")
func _stop_sabotage_vfx() -> void:
	if crew and crew.visible:
		crew.play_sabotage_pulse(false)


func _on_sabotage_complete() -> void:
	is_sabotaging = false
	_stop_sabotage_vfx.rpc()
	var core := _channel_target if is_instance_valid(_channel_target) else looking_core()
	_channel_target = null
	if core != null and core.can_accept_sabotage():
		MatchStats.record_core(peer_id)
		AudioDirector.play_core()
		core.sabotage.rpc()


## Caída al vacío: el castigo lo aplica la autoridad de match para que
## GameManager.lives y la victoria no se desincronicen.
func request_void_penalty() -> void:
	if not alive or _respawning:
		return
	if NetworkManager.is_match_authority():
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			take_hit.rpc(peer_id)
		else:
			take_hit(peer_id)
	elif multiplayer.has_multiplayer_peer():
		_rpc_void_penalty.rpc_id(1)
	else:
		_lose_life(0)


@rpc("any_peer", "reliable")
func _rpc_void_penalty() -> void:
	if not NetworkManager.is_match_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer_id:
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		take_hit.rpc(peer_id)
	else:
		take_hit(peer_id)


@rpc("any_peer", "call_local", "reliable")
func take_hit(target_peer_id: int) -> void:
	if target_peer_id != peer_id:
		return
	if _respawning or not alive:
		return
	if combat and combat.cloaked:
		combat.clear_buff("cloak")
	var killer := _find_beast_peer()
	MatchStats.record_damage(killer, peer_id, 50.0)
	AudioDirector.play_hit()
	_lose_life(killer)


@rpc("any_peer", "call_local", "reliable")
func apply_projectile_hit(target_peer_id: int, damage: float, slow: float, slow_dur: float, from_peer: int = 0) -> void:
	if target_peer_id != peer_id or not alive or _respawning:
		return
	if combat and combat.cloaked:
		combat.clear_buff("cloak")
	if combat and combat.shielded:
		damage *= 0.2
	if damage <= 0.0 and slow > 0.0:
		# El rugido (0 dmg + slow) también debe cortar canalización.
		if is_sabotaging:
			_cancel_sabotage()
			sabotage_interrupted.emit()
		if combat:
			combat.apply_slow(slow, slow_dur)
		return
	hp -= damage
	MatchStats.record_damage(from_peer, peer_id, damage)
	AudioDirector.play_hit()
	# Recibir un impacto corta la canalización. Sin esto se podía sabotear
	# tranquilamente con la Bestia disparándote encima: la presión, que es lo
	# único que la Bestia aporta al bucle, no significaba nada.
	if is_sabotaging:
		_cancel_sabotage()
		sabotage_interrupted.emit()
	if is_multiplayer_authority() and camera:
		CombatVfx.shake_camera(camera, 0.1, 0.12)
	if crew:
		crew.play_hit()
	play_action("hit")
	if slow > 0.0 and combat:
		combat.apply_slow(slow, slow_dur)
	if hp <= 0.0:
		hp = 100.0
		_lose_life(from_peer)


func _lose_life(killer_peer: int = 0) -> void:
	if not alive:
		return
	if combat and combat.shielded:
		# Escudo salva un golpe letal
		combat.clear_buff("shield")
		hp = 50.0
		return
	lives -= 1
	## Solo la autoridad de match toca GameManager; clientes bajan `lives` vía RPC.
	if NetworkManager.is_match_authority():
		GameManager.damage_explorer(peer_id)
	if crew:
		crew.play_hit()
	_knockback()
	if lives <= 0:
		if killer_peer > 0:
			MatchStats.record_elimination(killer_peer, peer_id)
		AudioDirector.play_death()
		_die()
	else:
		hp = 100.0
		_respawn_fx()


func _find_beast_peer() -> int:
	for n in get_tree().get_nodes_in_group("player_characters"):
		if n is BeastPlayer:
			return (n as BeastPlayer).peer_id
	return 0

func _knockback() -> void:
	var knock_dir := -global_transform.basis.z
	velocity = knock_dir * 8.0 + Vector3.UP * 3.0


func _respawn_fx() -> void:
	## Fantasma real: sin colisión ni input, no un invisible que sigue pegando.
	if _respawning:
		return
	_respawning = true
	visible = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if is_sabotaging:
		_cancel_sabotage()
	AudioDirector.set_walking(false)
	var saved_process := is_physics_processing()
	set_physics_process(false)
	await get_tree().create_timer(2.0).timeout
	_respawning = false
	if lives <= 0 or not is_instance_valid(self):
		return
	visible = true
	collision_layer = 2
	collision_mask = 1
	velocity = Vector3.ZERO
	reset_action_pose()
	global_position = _get_spawn_position()
	set_physics_process(saved_process or true)


func force_eliminate() -> void:
	## Desconexión / forfeit: quitar cuerpo vivo del mundo.
	if not alive:
		collision_layer = 0
		collision_mask = 0
		return
	lives = 0
	_die()


func _die() -> void:
	alive = false
	_respawning = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if is_sabotaging:
		_cancel_sabotage()
	if is_multiplayer_authority():
		# El bucle de pasos se apaga desde el movimiento, y aquí el movimiento
		# deja de ejecutarse: sin esto, un cadáver seguiría caminando de oído.
		AudioDirector.set_walking(false)
	# Caer al suelo antes de desaparecer: morir de golpe, sin transición, era
	# uno de los motivos por los que el combate no se leía. El cuerpo no puede
	# hacer nada mientras tanto porque _physics_process ya sale si no está vivo.
	var fall := play_action("die")
	if fall > 0.0:
		await get_tree().create_timer(minf(fall, 1.6)).timeout
	visible = false
	set_physics_process(false)


func _get_spawn_position() -> Vector3:
	var spawns := get_tree().get_nodes_in_group("explorer_spawns")
	if spawns.is_empty():
		return global_position
	var n: int = spawns.size()
	var idx: int = absi(peer_id) % maxi(n, 1)
	return spawns[idx].global_position

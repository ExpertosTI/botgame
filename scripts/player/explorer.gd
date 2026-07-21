class_name ExplorerPlayer
extends PlayerBase

@export var sabotage_time := 1.8

@onready var sabotage_timer: Timer = $SabotageTimer
@onready var interact_ray: RayCast3D = $CameraPivot/Camera3D/InteractRay

var lives := GameManager.EXPLORER_LIVES
var is_sabotaging := false
var alive := true
var variant: GameManager.ExplorerVariant = GameManager.ExplorerVariant.ROBOT_BLUE
var hp := 100.0  # daño de explosiones/proyectiles bestia; 0 = pierde una vida


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
	var color := GameManager.get_explorer_color(variant)
	crew.apply_colors(color, Color(0.75, 0.95, 1.0), color.lightened(0.2))
	var pname: String = str(NetworkManager.players.get(peer_id, {}).get("name", "Robot"))
	crew.set_player_name(pname)


func is_alive() -> bool:
	return alive


func _physics_process(delta: float) -> void:
	if not alive:
		return
	super._physics_process(delta)
	if has_meta("is_bot") and get_meta("is_bot"):
		return
	if not is_multiplayer_authority():
		return

	# Mantener cerca de núcleo = sabotear; si no, disparar
	var near_core := _looking_at_core()
	if near_core and InputManager.action_primary_held:
		_try_sabotage()
	else:
		if is_sabotaging:
			_cancel_sabotage()
		if InputManager.action_primary_just or (InputManager.action_primary_held and not near_core and _auto_fire_ready()):
			combat.fire(get_aim_origin(), get_aim_dir())

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


func _looking_at_core() -> bool:
	if not interact_ray.is_colliding():
		return false
	var collider := interact_ray.get_collider()
	return collider is BeastObjective and collider.is_active


func get_sabotage_progress() -> float:
	if not is_sabotaging or sabotage_timer.is_stopped():
		return 0.0
	var total := maxf(sabotage_timer.wait_time, 0.001)
	return clampf(1.0 - sabotage_timer.time_left / total, 0.0, 1.0)


func _try_sabotage() -> void:
	if is_sabotaging:
		return
	if not _looking_at_core():
		return
	is_sabotaging = true
	sabotage_timer.start()
	_start_sabotage_vfx.rpc()


func _cancel_sabotage() -> void:
	is_sabotaging = false
	sabotage_timer.stop()
	_stop_sabotage_vfx.rpc()


@rpc("any_peer", "call_local", "reliable")
func _start_sabotage_vfx() -> void:
	if crew:
		crew.play_sabotage_pulse(true)


@rpc("any_peer", "call_local", "reliable")
func _stop_sabotage_vfx() -> void:
	if crew:
		crew.play_sabotage_pulse(false)


func _on_sabotage_complete() -> void:
	is_sabotaging = false
	_stop_sabotage_vfx.rpc()
	if not interact_ray.is_colliding():
		return
	var collider := interact_ray.get_collider()
	if collider is BeastObjective and collider.is_active:
		collider.sabotage.rpc()


@rpc("any_peer", "call_local", "reliable")
func take_hit(target_peer_id: int) -> void:
	if target_peer_id != peer_id:
		return
	_lose_life()


@rpc("any_peer", "call_local", "reliable")
func apply_projectile_hit(target_peer_id: int, damage: float, slow: float, slow_dur: float) -> void:
	if target_peer_id != peer_id or not alive:
		return
	if combat and combat.shielded:
		damage *= 0.2
	if damage <= 0.0 and slow > 0.0:
		if combat:
			combat.apply_slow(slow, slow_dur)
		return
	hp -= damage
	if crew:
		crew.play_hit()
	if slow > 0.0 and combat:
		combat.apply_slow(slow, slow_dur)
	if hp <= 0.0:
		hp = 100.0
		_lose_life()


func _lose_life() -> void:
	if not alive:
		return
	if combat and combat.shielded:
		# Escudo salva un golpe letal
		combat.clear_buff("shield")
		hp = 50.0
		return
	lives -= 1
	GameManager.damage_explorer(peer_id)
	if crew:
		crew.play_hit()
	_knockback()
	if lives <= 0:
		_die()
	else:
		hp = 100.0
		_respawn_fx()


func _knockback() -> void:
	var knock_dir := -global_transform.basis.z
	velocity = knock_dir * 8.0 + Vector3.UP * 3.0


func _respawn_fx() -> void:
	visible = false
	await get_tree().create_timer(2.0).timeout
	if lives > 0:
		visible = true
		global_position = _get_spawn_position()


func _die() -> void:
	alive = false
	visible = false
	set_physics_process(false)


func _get_spawn_position() -> Vector3:
	var spawns := get_tree().get_nodes_in_group("explorer_spawns")
	if spawns.is_empty():
		return global_position
	var idx := peer_id % spawns.size()
	return spawns[idx].global_position

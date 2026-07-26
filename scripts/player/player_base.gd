class_name PlayerBase
extends CharacterBody3D

@export var move_speed := 6.0
@export var sprint_multiplier := 1.55
## Con gravedad 14 (project.godot) este salto llega ~1,4 m — suficiente para
## cajas de Lab Neon sin sentirse flotante.
@export var jump_velocity := 6.4
@export var mouse_sensitivity := 0.003
@export var touch_look_sensitivity := 0.004

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var mesh: Node3D = $Mesh
@onready var crew: CrewVisual = $Mesh/CrewVisual

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var peer_id: int = 1
var combat: CombatKit

## Sync de red (WebSocket): ~15 Hz, unreliable_ordered
const SYNC_HZ := 15.0
const VOID_Y := -25.0
const VOID_LOCK_S := 1.6
## Coyote: permite saltar unos ms después de dejar el borde (Jolt + CSG).
const COYOTE_S := 0.12

var _sync_accum := 0.0
var _remote_pos := Vector3.ZERO
var _remote_yaw := 0.0
var _has_remote := false
## Móvil / Web: cámara lateral fija (mejor jugabilidad táctil)
var _side_cam := false
## Para distinguir un aterrizaje real de bajar un bordillo.
var _was_grounded := true
var _air_time := 0.0
var _coyote := 0.0
var _void_lock := 0.0


func _ready() -> void:
	peer_id = name.to_int() if name.is_valid_int() else multiplayer.get_unique_id()
	add_to_group("player_characters")
	## Ajustes CharacterBody3D que Jolt aprovecha mejor que el default.
	floor_snap_length = 0.22
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.05
	combat = CombatKit.new()
	combat.name = "CombatKit"
	add_child(combat)

	var bot := has_meta("is_bot") and bool(get_meta("is_bot"))
	if not is_multiplayer_authority() or bot:
		camera.current = false
		set_process_input(false)
	else:
		_side_cam = (
			DisplayServer.is_touchscreen_available()
			or OS.has_feature("mobile")
			or OS.has_feature("web")
		)
		if _side_cam:
			_apply_side_camera_rig()
		elif not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		InputManager.look_delta.connect(_on_touch_look)


func _apply_side_camera_rig() -> void:
	## Cámara a un costado, cerca, mirando al personaje.
	camera_pivot.rotation = Vector3(0, 0, 0)
	camera.position = Vector3(5.2, 2.0, 0.0)
	camera.fov = 58.0
	camera.look_at_from_position(camera.global_position, global_position + Vector3(0, 1.05, 0), Vector3.UP)


func _exit_tree() -> void:
	if InputManager.look_delta.is_connected(_on_touch_look):
		InputManager.look_delta.disconnect(_on_touch_look)


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _side_cam:
		var sens := mouse_sensitivity * SettingsManager.look_sensitivity
		_apply_look(event.relative * sens)
	## ui_cancel lo maneja el HUD (pausa). No togglear capture aquí: pelea con
	## pause_menu y deja la mirada rota tras Continuar.
	## Cambio de arma: solo vía InputManager.weapon_cycle_just (evita doble ciclo Q).
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			combat.cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			combat.cycle_weapon(-1)


func _on_touch_look(delta: Vector2) -> void:
	if not is_multiplayer_authority():
		return
	if _side_cam:
		# Pitch + yaw suave: sin yaw no se apunta/sabotea parado.
		var sens := touch_look_sensitivity * SettingsManager.look_sensitivity
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - delta.y * sens * 0.35,
			-0.35,
			0.28
		)
		rotate_y(-delta.x * sens * 0.55)
		return
	_apply_look(delta * touch_look_sensitivity * SettingsManager.look_sensitivity)


func _apply_look(rel: Vector2) -> void:
	if _side_cam:
		return
	rotate_y(-rel.x)
	camera_pivot.rotate_x(-rel.y)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -1.2, 0.8)


func _physics_process(delta: float) -> void:
	if _void_lock > 0.0:
		_void_lock = maxf(_void_lock - delta, 0.0)
	if has_meta("is_bot") and get_meta("is_bot"):
		_check_void_fall()
		return  # PracticeAI controla movimiento
	if is_multiplayer_authority():
		_authority_move(delta)
		if _side_cam:
			_update_side_camera()
		_maybe_sync(delta)
	else:
		_apply_remote_pose(delta)


func _update_side_camera() -> void:
	## Mantiene la cámara al costado del jugador mirando el torso.
	if camera == null or camera_pivot == null:
		return
	var target := global_position + Vector3(0, 1.1, 0)
	var desired_local := Vector3(5.2, 2.0 + camera_pivot.rotation.x * -1.2, 0.0)
	camera.position = camera.position.lerp(desired_local, 0.2)
	camera.look_at_from_position(camera.global_position, target, Vector3.UP)


func _authority_move(delta: float) -> void:
	_handle_combat_input()

	if is_on_floor():
		_coyote = COYOTE_S
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		velocity.y -= gravity * delta

	if InputManager.jump_just and (is_on_floor() or _coyote > 0.0):
		velocity.y = jump_velocity
		_coyote = 0.0
		AudioDirector.play_jump()
		play_action("jump")

	var input_dir := InputManager.move_vector
	var direction := Vector3.ZERO
	if _side_cam:
		var right := camera.global_transform.basis.x
		var fwd := -camera.global_transform.basis.z
		right.y = 0.0
		fwd.y = 0.0
		if right.length_squared() > 0.001:
			right = right.normalized()
		if fwd.length_squared() > 0.001:
			fwd = fwd.normalized()
		direction = right * input_dir.x + fwd * (-input_dir.y)
		if direction.length() > 0.15:
			direction = direction.normalized()
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), clampf(delta * 14.0, 0.0, 1.0))
		else:
			direction = Vector3.ZERO
	else:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var speed := move_speed * (combat.speed_mult if combat else 1.0)
	if InputManager.sprint_held:
		speed *= sprint_multiplier

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	var moving := direction.length() > 0.1
	set_locomotion(moving, InputManager.sprint_held)

	move_and_slide()
	_update_body_audio(moving)
	_check_void_fall()


## Solo suena para quien juega en esta máquina: el audio del juego no es
## posicional, así que reproducir los pasos de los demás sería ruido sin
## información.
func _update_body_audio(moving: bool) -> void:
	var grounded := is_on_floor()
	if grounded and not _was_grounded and _air_time > 0.25:
		# El umbral evita que bajar un escalón suene a aterrizaje.
		AudioDirector.play_land()
	_air_time = 0.0 if grounded else _air_time + get_physics_process_delta_time()
	_was_grounded = grounded
	AudioDirector.set_walking(moving and grounded, InputManager.sprint_held)


func _check_void_fall() -> void:
	if global_position.y >= VOID_Y:
		return
	## Evita perder varias vidas en el mismo hueco si el spawn todavía está bajo.
	if _void_lock > 0.0:
		global_position = _void_spawn_position()
		velocity = Vector3.ZERO
		return
	AudioDirector.play_fall()
	global_position = _void_spawn_position()
	velocity = Vector3.ZERO
	_void_lock = VOID_LOCK_S
	## Solo el authority dispara el castigo; el servidor aplica vidas/HP.
	if not is_multiplayer_authority():
		return
	if not GameManager.match_active:
		return
	if self is ExplorerPlayer and (self as ExplorerPlayer).alive:
		(self as ExplorerPlayer).request_void_penalty()
	elif self is BeastPlayer:
		(self as BeastPlayer).apply_damage.rpc(45.0, 0.0, 0.0, 0)


func _void_spawn_position() -> Vector3:
	if self is BeastPlayer:
		var beast_spawns := get_tree().get_nodes_in_group("beast_spawn")
		if not beast_spawns.is_empty():
			var lair := beast_spawns[0] as Node3D
			if lair != null:
				return lair.global_position + Vector3(0, 0.5, 0)
	var spawns := get_tree().get_nodes_in_group("explorer_spawns")
	if not spawns.is_empty():
		# Tipado explícito: abs()/:= con Variant tumba PlayerBase entero en export
		# headless (beast/explorer/combat_fx dejan de compilar → WS 502).
		var n: int = spawns.size()
		var idx: int = absi(peer_id) % maxi(n, 1)
		var spawn := spawns[idx] as Node3D
		if spawn != null:
			return spawn.global_position + Vector3(0, 0.5, 0)
	return Vector3(0, 2, 0)


func set_locomotion(moving: bool, sprint: bool = false) -> void:
	## Propaga walk/idle al GLB del catálogo y al fallback CrewVisual.
	if crew and is_instance_valid(crew):
		if crew.visible:
			crew.set_moving(moving)
	var cat := _catalog_mesh()
	if cat:
		CharacterCatalog.play_locomotion(cat, moving, sprint)


func _catalog_mesh() -> Node3D:
	if mesh == null:
		return null
	return mesh.get_node_or_null("CatalogMesh") as Node3D


@rpc("any_peer", "reliable")
func apply_hazard_slow(amount: float, duration: float) -> void:
	## Solo el authority mueve el cuerpo: el servidor hace rpc_id(authority).
	## "authority" RPC impedía que el servidor lo enviara a clientes remotos.
	if combat:
		combat.apply_slow(amount, duration)


func set_cloak_visual(alpha: float) -> void:
	## CatalogMesh es el cuerpo real; CrewVisual suele estar oculto. Sin esto el
	## camouflage marcaba cloaked=true pero el GLB seguía opaco.
	var a := clampf(alpha, 0.05, 1.0)
	if crew and is_instance_valid(crew) and crew.visible:
		crew.modulate_alpha(a)
	var cat := _catalog_mesh()
	if cat:
		_set_geom_transparency(cat, 1.0 - a)


func _set_geom_transparency(node: Node, transparency: float) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = transparency
	for child in node.get_children():
		_set_geom_transparency(child, transparency)


## Animación puntual sobre la locomoción: disparar, encajar un tiro, saltar,
## morir. Los personajes de KayKit son mallas estáticas y ahí no pasa nada, que
## es justo por lo que esto no puede dar por hecho que haya clip.
func play_action(action: String) -> float:
	var cat := _catalog_mesh()
	if cat == null:
		return 0.0
	return CharacterCatalog.play_action(cat, action)


func reset_action_pose() -> void:
	var cat := _catalog_mesh()
	if cat != null:
		CharacterCatalog.reset_actions(cat)


func _process(delta: float) -> void:
	var cat := _catalog_mesh()
	if cat:
		CharacterCatalog.tick_locomotion(cat, delta)


func _maybe_sync(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	_sync_accum += delta
	if _sync_accum < 1.0 / SYNC_HZ:
		return
	_sync_accum = 0.0
	var cat := _catalog_mesh()
	var moving := false
	if cat and bool(cat.get_meta("cat_moving", false)):
		moving = true
	elif crew != null and crew.visible:
		moving = crew.is_moving()
	_recv_state.rpc(global_position, rotation.y, velocity, moving)


@rpc("any_peer", "unreliable_ordered", "call_remote")
func _recv_state(pos: Vector3, yaw: float, vel: Vector3, moving: bool) -> void:
	# Incluye servidor dedicado (para melee/hits) + otros clientes
	_remote_pos = pos
	_remote_yaw = yaw
	velocity = vel
	_has_remote = true
	set_locomotion(moving, vel.length() > move_speed * 1.2)


func _apply_remote_pose(delta: float) -> void:
	if not _has_remote:
		return
	# Servidor headless: snap (preciso para combate). Clientes: lerp suave.
	var snap := NetworkManager.is_dedicated_server or OS.has_feature("dedicated_server")
	if snap:
		global_position = _remote_pos
		rotation.y = _remote_yaw
	else:
		global_position = global_position.lerp(_remote_pos, clampf(delta * 18.0, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, _remote_yaw, clampf(delta * 18.0, 0.0, 1.0))


func _handle_combat_input() -> void:
	if combat == null:
		return
	if InputManager.ability_1_just:
		combat.use_ability(0)
	if InputManager.ability_2_just:
		combat.use_ability(1)
	if InputManager.ability_3_just:
		combat.use_ability(2)
	if InputManager.ability_4_just:
		combat.use_ability(3)
	if InputManager.weapon_cycle_just:
		combat.cycle_weapon(1)
	if InputManager.ping_just:
		_issue_ping()


func _issue_ping() -> void:
	var kind := 0  # Ayuda
	if self is BeastPlayer:
		kind = 1
	elif self is ExplorerPlayer and (self as ExplorerPlayer).is_sabotaging:
		kind = 2
	var pos := global_position + get_aim_dir() * 6.0
	pos.y = global_position.y
	## Si miramos un núcleo, anclar el ping ahí (más útil para coordinación).
	if self is ExplorerPlayer:
		var core := (self as ExplorerPlayer).looking_core()
		if core != null:
			pos = core.global_position
			if kind == 0:
				kind = 2
	CombatFx.request_ping(peer_id, kind, pos)


func get_aim_origin() -> Vector3:
	if _side_cam:
		return global_position + Vector3(0, 1.15, 0) + (-transform.basis.z * 0.55)
	return camera.global_position + (-camera.global_transform.basis.z * 0.8)


func get_aim_dir() -> Vector3:
	if _side_cam:
		return _assisted(-transform.basis.z)
	return -camera.global_transform.basis.z


## Con cámara lateral el cuerpo apunta en horizontal y el stick que gira es el
## mismo que mueve: sin ayuda no hay forma de acertar a algo que esté por encima
## o por debajo. Los bots no la reciben —ya encaran a su objetivo— y en
## escritorio con ratón tampoco, porque allí se apunta libre.
func _assisted(dir: Vector3) -> Vector3:
	if has_meta("is_bot"):
		return dir
	var targets := _assist_targets()
	if targets.is_empty():
		return dir
	return AimAssist.best_direction(get_aim_origin(), dir, targets)


func _assist_targets() -> Array:
	var out: Array = []
	var origin := get_aim_origin()
	var want_explorers := self is BeastPlayer
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node == self:
			continue
		if want_explorers:
			if not (node is ExplorerPlayer) or not (node as ExplorerPlayer).is_alive():
				continue
		elif not (node is BeastPlayer):
			continue
		var point: Vector3 = (node as Node3D).global_position + Vector3(0, AimAssist.CHEST_OFFSET, 0)
		if _has_line_of_sight(origin, point, node as Node3D):
			out.append(point)
	## Side-cam también necesita imán a núcleos Blindados (romper escudo).
	if self is ExplorerPlayer:
		for node in get_tree().get_nodes_in_group("beast_objectives"):
			if not (node is BeastObjective):
				continue
			var core := node as BeastObjective
			if not core.is_active or core.shield_hp <= 0.0:
				continue
			var cpoint := core.global_position + Vector3(0, 0.8, 0)
			if _has_line_of_sight(origin, cpoint, core):
				out.append(cpoint)
	return out


## Sin esto el imán apuntaría a través de las paredes y los disparos acabarían
## clavados en el muro que hay entre medias.
func _has_line_of_sight(from: Vector3, to: Vector3, target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid(), target.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

class_name PlayerBase
extends CharacterBody3D

@export var move_speed := 6.0
@export var sprint_multiplier := 1.55
@export var jump_velocity := 5.5
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
var _sync_accum := 0.0
var _remote_pos := Vector3.ZERO
var _remote_yaw := 0.0
var _has_remote := false
## Móvil / Web: cámara lateral fija (mejor jugabilidad táctil)
var _side_cam := false


func _ready() -> void:
	peer_id = name.to_int() if name.is_valid_int() else multiplayer.get_unique_id()
	add_to_group("player_characters")
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
	if event.is_action_pressed("ui_cancel") and not _side_cam:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("weapon_next"):
		combat.cycle_weapon(1)
	if event.is_action_pressed("weapon_prev"):
		combat.cycle_weapon(-1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			combat.cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			combat.cycle_weapon(-1)


func _on_touch_look(delta: Vector2) -> void:
	if not is_multiplayer_authority():
		return
	if _side_cam:
		# Solo pitch suave; el yaw lo marca el stick de movimiento
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - delta.y * touch_look_sensitivity * 0.35 * SettingsManager.look_sensitivity,
			-0.35,
			0.28
		)
		return
	_apply_look(delta * touch_look_sensitivity * SettingsManager.look_sensitivity)


func _apply_look(rel: Vector2) -> void:
	if _side_cam:
		return
	rotate_y(-rel.x)
	camera_pivot.rotate_x(-rel.y)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -1.2, 0.8)


func _physics_process(delta: float) -> void:
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

	if not is_on_floor():
		velocity.y -= gravity * delta

	if InputManager.jump_just and is_on_floor():
		velocity.y = jump_velocity

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

	set_locomotion(direction.length() > 0.1, InputManager.sprint_held)

	move_and_slide()
	_check_void_fall()


func _check_void_fall() -> void:
	if global_position.y >= VOID_Y:
		return
	global_position = _void_spawn_position()
	velocity = Vector3.ZERO


func _void_spawn_position() -> Vector3:
	if self is BeastPlayer:
		var beast_spawns := get_tree().get_nodes_in_group("beast_spawn")
		if not beast_spawns.is_empty():
			return beast_spawns[0].global_position + Vector3(0, 0.5, 0)
	var spawns := get_tree().get_nodes_in_group("explorer_spawns")
	if not spawns.is_empty():
		var idx := abs(peer_id) % spawns.size()
		return spawns[idx].global_position + Vector3(0, 0.5, 0)
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


func get_aim_origin() -> Vector3:
	return camera.global_position + (-camera.global_transform.basis.z * 0.8)


func get_aim_dir() -> Vector3:
	return -camera.global_transform.basis.z

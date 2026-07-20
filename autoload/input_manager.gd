extends Node

## Abstracción de input: teclado/ratón + joystick táctil.

signal look_delta(delta: Vector2)

var move_vector := Vector2.ZERO
var look_vector := Vector2.ZERO
var action_primary_held := false
var action_primary_just := false
var action_secondary_just := false
var sprint_held := false
var jump_just := false
var dash_just := false
var weapon_cycle_just := false
var ability_1_just := false
var ability_2_just := false
var ability_3_just := false
var ability_4_just := false

var touch_enabled := false
var _touch_move := Vector2.ZERO
var _touch_look := Vector2.ZERO
var _touch_action := false
var _touch_secondary := false
var _touch_sprint := false
var _touch_jump := false
var _touch_dash := false
var _touch_weapon := false
var _touch_ability := [-1]  # set to index when pressed
var _action_was_held := false
var _secondary_was := false


func _ready() -> void:
	touch_enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web")


func _process(_delta: float) -> void:
	action_primary_just = false
	action_secondary_just = false
	jump_just = false
	dash_just = false
	weapon_cycle_just = false
	ability_1_just = false
	ability_2_just = false
	ability_3_just = false
	ability_4_just = false

	var kb_move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch_move.length() > 0.05:
		move_vector = _touch_move
	else:
		move_vector = kb_move

	var held := Input.is_action_pressed("action_primary") or _touch_action
	action_primary_just = held and not _action_was_held
	action_primary_held = held
	_action_was_held = held

	var sec := Input.is_action_pressed("action_secondary") or _touch_secondary
	action_secondary_just = sec and not _secondary_was
	_secondary_was = sec
	_touch_secondary = false

	sprint_held = Input.is_action_pressed("sprint") or _touch_sprint
	if Input.is_action_just_pressed("jump") or _touch_jump:
		jump_just = true
		_touch_jump = false
	if Input.is_action_just_pressed("dash") or _touch_dash:
		dash_just = true
		ability_1_just = true  # dash suele ser ability 0
		_touch_dash = false
	if Input.is_action_just_pressed("weapon_next") or _touch_weapon:
		weapon_cycle_just = true
		_touch_weapon = false
	if Input.is_action_just_pressed("ability_1"):
		ability_1_just = true
	if Input.is_action_just_pressed("ability_2"):
		ability_2_just = true
	if Input.is_action_just_pressed("ability_3"):
		ability_3_just = true
	if Input.is_action_just_pressed("ability_4"):
		ability_4_just = true

	if _touch_ability[0] >= 0:
		match _touch_ability[0]:
			0: ability_1_just = true
			1: ability_2_just = true
			2: ability_3_just = true
			3: ability_4_just = true
		_touch_ability[0] = -1


func set_touch_move(v: Vector2) -> void:
	_touch_move = v.limit_length(1.0)


func set_touch_look(delta: Vector2) -> void:
	_touch_look = delta
	look_delta.emit(delta)


func set_touch_action(pressed: bool) -> void:
	_touch_action = pressed


func set_touch_secondary() -> void:
	_touch_secondary = true


func set_touch_sprint(pressed: bool) -> void:
	_touch_sprint = pressed


func request_jump() -> void:
	_touch_jump = true


func request_dash() -> void:
	_touch_dash = true


func request_weapon_cycle() -> void:
	_touch_weapon = true


func request_ability(index: int) -> void:
	_touch_ability[0] = index


func consume_look() -> Vector2:
	var v := _touch_look
	_touch_look = Vector2.ZERO
	return v

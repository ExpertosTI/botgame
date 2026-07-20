extends Control

## Joystick virtual + botones combate para móvil / Web táctil.

@onready var stick_base: Control = $StickBase
@onready var stick_knob: Control = $StickBase/Knob
@onready var look_zone: Control = $LookZone
@onready var btn_action: Button = $Buttons/ActionButton
@onready var btn_sprint: Button = $Buttons/SprintButton
@onready var btn_jump: Button = $Buttons/JumpButton
@onready var btn_dash: Button = $Buttons/DashButton
@onready var btn_grenade: Button = $Buttons/GrenadeButton
@onready var btn_weapon: Button = $Buttons/WeaponButton
@onready var btn_a2: Button = $Abilities/Ability2
@onready var btn_a3: Button = $Abilities/Ability3
@onready var btn_a4: Button = $Abilities/Ability4

var _stick_touch_index := -1
var _look_touch_index := -1
var _stick_center := Vector2.ZERO
var _stick_radius := 70.0


func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.get_name() == "Web"
	call_deferred("_init_stick")
	btn_action.button_down.connect(func(): InputManager.set_touch_action(true))
	btn_action.button_up.connect(func(): InputManager.set_touch_action(false))
	btn_sprint.button_down.connect(func(): InputManager.set_touch_sprint(true))
	btn_sprint.button_up.connect(func(): InputManager.set_touch_sprint(false))
	btn_jump.pressed.connect(func(): InputManager.request_jump())
	btn_dash.pressed.connect(func(): InputManager.request_ability(0))
	btn_grenade.pressed.connect(func(): InputManager.set_touch_secondary())
	btn_weapon.pressed.connect(func(): InputManager.request_weapon_cycle())
	btn_a2.pressed.connect(func(): InputManager.request_ability(1))
	btn_a3.pressed.connect(func(): InputManager.request_ability(2))
	btn_a4.pressed.connect(func(): InputManager.request_ability(3))


func _init_stick() -> void:
	_stick_center = stick_base.size * 0.5
	_stick_radius = minf(stick_base.size.x, stick_base.size.y) * 0.45
	stick_knob.position = _stick_center - stick_knob.size * 0.5


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos: Vector2 = event.position
	if event.pressed:
		if _stick_touch_index < 0 and _in_control(stick_base, pos):
			_stick_touch_index = event.index
			_update_stick(pos)
		elif _look_touch_index < 0 and _in_control(look_zone, pos):
			_look_touch_index = event.index
	else:
		if event.index == _stick_touch_index:
			_stick_touch_index = -1
			InputManager.set_touch_move(Vector2.ZERO)
			stick_knob.position = _stick_center - stick_knob.size * 0.5
		if event.index == _look_touch_index:
			_look_touch_index = -1


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _stick_touch_index:
		_update_stick(event.position)
	elif event.index == _look_touch_index:
		InputManager.set_touch_look(event.relative)


func _update_stick(screen_pos: Vector2) -> void:
	var local := stick_base.get_global_transform_with_canvas().affine_inverse() * screen_pos
	var offset := local - _stick_center
	if offset.length() > _stick_radius:
		offset = offset.normalized() * _stick_radius
	stick_knob.position = _stick_center + offset - stick_knob.size * 0.5
	InputManager.set_touch_move(Vector2(offset.x / _stick_radius, offset.y / _stick_radius))


func _in_control(ctrl: Control, screen_pos: Vector2) -> bool:
	return ctrl.get_global_rect().has_point(screen_pos)

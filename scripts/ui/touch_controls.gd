extends Control

## Joystick virtual + botones combate — layout pensado para pulgares en móvil.

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
var _stick_radius := 80.0
var _pulse_t := 0.0


func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.get_name() == "Web"
	GameTheme.apply(self)
	_style_buttons()
	call_deferred("_layout_for_screen")
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


func _style_buttons() -> void:
	GameTheme.style_danger(btn_action)
	GameTheme.style_primary(btn_dash)
	btn_action.text = "🔫\nDISPARO"
	btn_sprint.text = "💨"
	btn_jump.text = "⬆"
	btn_dash.text = "⚡"
	btn_grenade.text = "💣"
	btn_weapon.text = "🔄"
	btn_a2.text = "2"
	btn_a3.text = "3"
	btn_a4.text = "4"
	btn_action.add_theme_font_size_override("font_size", 18)
	for b in [btn_sprint, btn_jump, btn_dash, btn_grenade, btn_weapon, btn_a2, btn_a3, btn_a4]:
		b.add_theme_font_size_override("font_size", 22)


func _layout_for_screen() -> void:
	var h := get_viewport_rect().size.y
	var scale := clampf(h / 720.0, 0.85, 1.35)
	# Stick más grande para pulgar izquierdo
	var stick_s := 170.0 * scale
	stick_base.offset_left = 16.0
	stick_base.offset_top = -stick_s - 48.0
	stick_base.offset_right = 16.0 + stick_s
	stick_base.offset_bottom = -48.0
	stick_base.modulate = Color(0.2, 0.85, 0.9, 0.4)
	stick_knob.modulate = Color(1, 1, 1, 0.85)
	stick_knob.size = Vector2(64 * scale, 64 * scale)

	# Zona look + botones derecha
	var fire := 120.0 * scale
	btn_action.offset_left = 140.0 * scale
	btn_action.offset_top = 130.0 * scale
	btn_action.offset_right = btn_action.offset_left + fire
	btn_action.offset_bottom = btn_action.offset_top + fire

	_place(btn_sprint, 20 * scale, 170 * scale, 78 * scale)
	_place(btn_jump, 160 * scale, 20 * scale, 78 * scale)
	_place(btn_dash, 40 * scale, 50 * scale, 78 * scale)
	_place(btn_grenade, 250 * scale, 40 * scale, 72 * scale)
	_place(btn_weapon, 250 * scale, 170 * scale, 72 * scale)

	# Habilidades más arriba para no tapar disparo
	var abl := $Abilities as Control
	abl.offset_top = -100.0 * scale
	abl.offset_bottom = -40.0 * scale


func _place(btn: Button, x: float, y: float, s: float) -> void:
	btn.offset_left = x
	btn.offset_top = y
	btn.offset_right = x + s
	btn.offset_bottom = y + s


func _init_stick() -> void:
	_stick_center = stick_base.size * 0.5
	_stick_radius = minf(stick_base.size.x, stick_base.size.y) * 0.42
	stick_knob.position = _stick_center - stick_knob.size * 0.5


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_t += delta
	# Pulso suave en DISPARO para localizarlo
	var p := 0.92 + 0.08 * sin(_pulse_t * 3.0)
	btn_action.scale = Vector2(p, p)
	btn_action.pivot_offset = btn_action.size * 0.5


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
		# Sensibilidad look un poco más alta en móvil
		InputManager.set_touch_look(event.relative * 1.25)


func _update_stick(screen_pos: Vector2) -> void:
	var local := stick_base.get_global_transform_with_canvas().affine_inverse() * screen_pos
	var offset := local - _stick_center
	if offset.length() > _stick_radius:
		offset = offset.normalized() * _stick_radius
	stick_knob.position = _stick_center + offset - stick_knob.size * 0.5
	InputManager.set_touch_move(Vector2(offset.x / _stick_radius, offset.y / _stick_radius))


func _in_control(ctrl: Control, screen_pos: Vector2) -> bool:
	return ctrl.get_global_rect().has_point(screen_pos)

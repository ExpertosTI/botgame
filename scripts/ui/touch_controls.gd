extends Control

## Joystick virtual + botones combate — layout pensado para pulgares en móvil landscape.

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
	## Pausable: el HUD padre es ALWAYS (pausa); sin esto el stick apunta en pausa.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.get_name() == "Web"
	GameTheme.apply(self)
	_style_buttons()
	call_deferred("_layout_for_screen")
	call_deferred("_init_stick")
	get_viewport().size_changed.connect(_layout_for_screen)
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
	GameTheme.style_touch(btn_dash, GameTheme.C_CYAN)
	GameTheme.style_touch(btn_sprint, GameTheme.C_AMBER)
	GameTheme.style_touch(btn_jump, GameTheme.C_CYAN)
	GameTheme.style_touch(btn_grenade, GameTheme.C_AMBER)
	GameTheme.style_touch(btn_weapon, GameTheme.C_MUTED)
	GameTheme.style_touch(btn_a2, GameTheme.C_CYAN)
	GameTheme.style_touch(btn_a3, GameTheme.C_CYAN)
	GameTheme.style_touch(btn_a4, GameTheme.C_CYAN)
	btn_action.text = "FIRE"
	btn_sprint.text = "RUN"
	btn_jump.text = "JUMP"
	btn_dash.text = "DASH"
	btn_grenade.text = "NADE"
	btn_weapon.text = "GUN"
	btn_a2.text = "2"
	btn_a3.text = "3"
	btn_a4.text = "4"
	stick_base.modulate = Color(0.15, 0.9, 0.85, 0.55)
	stick_knob.modulate = Color(0.85, 1.0, 0.98, 0.92)


func _layout_for_screen() -> void:
	var sz := get_viewport_rect().size
	var landscape := sz.x >= sz.y
	## Escala por el lado corto: en landscape móvil los botones deben ser gordos.
	var short_side := minf(sz.x, sz.y)
	var scale := clampf(short_side / 390.0, 0.95, 1.55)
	if landscape:
		scale = clampf(short_side / 360.0, 1.05, 1.65)

	var stick_s := (188.0 if landscape else 170.0) * scale
	var margin := 20.0 * scale
	stick_base.offset_left = margin
	stick_base.offset_top = -stick_s - margin
	stick_base.offset_right = margin + stick_s
	stick_base.offset_bottom = -margin
	stick_base.modulate = Color(0.2, 0.85, 0.9, 0.45)
	stick_knob.modulate = Color(1, 1, 1, 0.9)
	var knob_s := 72.0 * scale
	stick_knob.size = Vector2(knob_s, knob_s)

	var buttons := $Buttons as Control
	var cluster_w := (360.0 if landscape else 300.0) * scale
	var cluster_h := (340.0 if landscape else 300.0) * scale
	buttons.offset_left = -cluster_w - 8.0
	buttons.offset_top = -cluster_h - 8.0
	buttons.offset_right = -10.0
	buttons.offset_bottom = -10.0

	look_zone.offset_left = -cluster_w - 40.0 * scale
	look_zone.offset_top = -cluster_h - 40.0 * scale
	look_zone.offset_right = -8.0
	look_zone.offset_bottom = -8.0

	var fire := (138.0 if landscape else 120.0) * scale
	var side := (92.0 if landscape else 78.0) * scale
	var side_sm := (84.0 if landscape else 72.0) * scale

	btn_action.offset_left = cluster_w - fire - 16.0 * scale
	btn_action.offset_top = cluster_h - fire - 18.0 * scale
	btn_action.offset_right = btn_action.offset_left + fire
	btn_action.offset_bottom = btn_action.offset_top + fire
	btn_action.add_theme_font_size_override("font_size", int(22 * scale))

	## Cluster pulgar derecho: JUMP arriba, DASH izq, RUN abajo-izq, FIRE grande.
	_place(btn_jump, cluster_w - side - 28.0 * scale, 12.0 * scale, side)
	_place(btn_dash, 18.0 * scale, 28.0 * scale, side)
	_place(btn_sprint, 18.0 * scale, cluster_h - side - 28.0 * scale, side)
	_place(btn_grenade, cluster_w * 0.42, 18.0 * scale, side_sm)
	_place(btn_weapon, cluster_w * 0.42, cluster_h - side_sm - 24.0 * scale, side_sm)

	for b in [btn_sprint, btn_jump, btn_dash, btn_grenade, btn_weapon]:
		b.add_theme_font_size_override("font_size", int(15 * scale))

	var abl := $Abilities as Control
	var abl_h := 56.0 * scale
	abl.offset_top = -abl_h - 14.0 * scale
	abl.offset_bottom = -12.0 * scale
	abl.offset_left = -150.0 * scale
	abl.offset_right = 150.0 * scale
	for b in [btn_a2, btn_a3, btn_a4]:
		b.custom_minimum_size = Vector2(72 * scale, 48 * scale)
		b.add_theme_font_size_override("font_size", int(16 * scale))

	call_deferred("_init_stick")


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
	_update_action_label()
	var p := 0.92 + 0.08 * sin(_pulse_t * 3.0)
	btn_action.scale = Vector2(p, p)
	btn_action.pivot_offset = btn_action.size * 0.5


func _update_action_label() -> void:
	var near_core := false
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is ExplorerPlayer and (node as ExplorerPlayer).peer_id == my_id:
			var ex := node as ExplorerPlayer
			near_core = ex.can_channel_core() or ex.is_sabotaging
			break
	if near_core:
		btn_action.text = "HOLD"
		btn_action.modulate = Color(0.35, 1.0, 0.75)
	else:
		btn_action.text = "FIRE"
		btn_action.modulate = Color.WHITE


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

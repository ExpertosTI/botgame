extends CanvasLayer

## Pausa in-game (Esc / botón). Obligatorio para tiendas móviles.

signal resumed
signal quit_requested

var _panel: PanelContainer
var _open := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.06, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	col.add_child(title)

	var sub := Label.new()
	sub.text = GameBrand.GAME_TITLE + " · v" + GameBrand.VERSION
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)

	var sens_l := Label.new()
	sens_l.text = "Sensibilidad mirada"
	col.add_child(sens_l)
	var sens := HSlider.new()
	sens.min_value = 0.4
	sens.max_value = 2.0
	sens.step = 0.05
	sens.value = SettingsManager.look_sensitivity
	sens.value_changed.connect(func(v: float): SettingsManager.set_look_sensitivity(v))
	col.add_child(sens)

	var mute := CheckBox.new()
	mute.text = "Silenciar audio"
	mute.button_pressed = SettingsManager.muted
	mute.toggled.connect(func(on: bool): SettingsManager.set_muted(on))
	col.add_child(mute)

	var resume := Button.new()
	resume.text = "▶  CONTINUAR"
	resume.custom_minimum_size = Vector2(0, 52)
	resume.pressed.connect(close_pause)
	col.add_child(resume)

	var quit := Button.new()
	quit.text = "Salir al menú"
	quit.custom_minimum_size = Vector2(0, 44)
	quit.pressed.connect(_on_quit)
	col.add_child(quit)

	var legal := Label.new()
	legal.text = GameBrand.copyright_line()
	legal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legal.add_theme_font_size_override("font_size", 11)
	col.add_child(legal)

	call_deferred("_style", title, sub, resume, quit, legal)


func _style(title: Label, sub: Label, resume: Button, quit: Button, legal: Label) -> void:
	GameTheme.apply(_panel)
	GameTheme.style_title(title, 28)
	GameTheme.style_muted(sub, 13)
	GameTheme.style_primary(resume)
	GameTheme.style_muted(legal, 11)


func open_pause() -> void:
	if _open:
		return
	_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_pause() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	resumed.emit()


func toggle_pause() -> void:
	if _open:
		close_pause()
	else:
		open_pause()


func is_open() -> bool:
	return _open


func _on_quit() -> void:
	close_pause()
	quit_requested.emit()
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/main/menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Solo si estamos en partida (padre HUD lo controla también)
		pass

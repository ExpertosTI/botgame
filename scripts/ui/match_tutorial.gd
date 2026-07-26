class_name MatchTutorial
extends CanvasLayer

## Tutorial interactivo de la primera partida (Lab Neon / práctica).
##
## No es un muro de texto: cada paso espera una acción real. Se guarda aparte
## del panel "¿Cómo se juega?" para no marcarlo visto con un tip de 5 segundos.

signal finished

enum Step {
	MOVE,
	FIRE,
	CORE,
	CHANNEL,
	ABILITY,
	DONE,
}

var _role := "explorer"
var _step: int = Step.MOVE
var _panel: PanelContainer
var _label: Label
var _skip: Button
var _moved := 0.0
var _fired := false
var _saw_core := false
var _channeled := false
var _used_ability := false
var _active := false


static func present(host: Node, role: String) -> MatchTutorial:
	var t := MatchTutorial.new()
	t._role = role
	host.add_child(t)
	t._start()
	return t


func _start() -> void:
	if SettingsManager.match_tutorial_done:
		queue_free()
		return
	_active = true
	layer = 85
	_build()
	_set_step(Step.MOVE if _role != "beast" else Step.MOVE)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.18)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -220
	_panel.offset_right = 220
	_panel.offset_top = -150
	_panel.offset_bottom = -24
	GameTheme.apply(_panel)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", GameTheme.C_CYAN)
	col.add_child(_label)

	_skip = Button.new()
	_skip.text = "Saltar tutorial"
	_skip.custom_minimum_size = Vector2(0, 36)
	GameTheme.style_touch(_skip, GameTheme.C_MUTED)
	_skip.pressed.connect(_finish)
	col.add_child(_skip)


func _process(delta: float) -> void:
	if not _active:
		return
	_track(delta)
	_advance_if_ready()


func _track(delta: float) -> void:
	if InputManager.move_vector.length() > 0.25:
		_moved += delta
	if InputManager.action_primary_just or InputManager.action_primary_held:
		_fired = true
	if InputManager.dash_just or InputManager.ability_1_just or InputManager.ability_2_just \
			or InputManager.ability_3_just or InputManager.ability_4_just:
		_used_ability = true
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is ExplorerPlayer and (node as ExplorerPlayer).is_multiplayer_authority():
			var ex := node as ExplorerPlayer
			if ex.is_sabotaging:
				_channeled = true
			if ex.looking_core() != null:
				_saw_core = true
		if node is BeastPlayer and (node as BeastPlayer).is_multiplayer_authority():
			if InputManager.action_primary_just:
				_fired = true


func _advance_if_ready() -> void:
	match _step:
		Step.MOVE:
			if _moved >= 0.7:
				_set_step(Step.FIRE)
		Step.FIRE:
			if _fired:
				_set_step(Step.CORE if _role != "beast" else Step.ABILITY)
		Step.CORE:
			if _saw_core:
				_set_step(Step.CHANNEL)
		Step.CHANNEL:
			if _channeled:
				_set_step(Step.ABILITY)
		Step.ABILITY:
			if _used_ability:
				_set_step(Step.DONE)
		Step.DONE:
			_finish()


func _set_step(s: int) -> void:
	_step = s
	if _label == null:
		return
	if _role == "beast":
		match s:
			Step.MOVE:
				_label.text = "BESTIA · Muévete con el stick o WASD"
			Step.FIRE:
				_label.text = "Dispara o usa Garras (clic / DISPARO)"
			Step.ABILITY:
				_label.text = "Usa G (dash) o 1-4. Orbes y zonas del teatro cuentan."
			_:
				_label.text = "Caza robots. Interrumpe el sabotaje."
		return
	match s:
		Step.MOVE:
			_label.text = "ROBOT · Muévete con el stick o WASD"
		Step.FIRE:
			_label.text = "Dispara (clic / DISPARO). Sigue la flecha al núcleo."
		Step.CORE:
			_label.text = "Acércate a un núcleo. Mira la etiqueta (Blindado / Relé…)."
		Step.CHANNEL:
			_label.text = "Mantén pulsado para canalizar. Si te pegan, se corta."
		Step.ABILITY:
			_label.text = "Prueba G o 1-4. Recoge orbes; evita zonas rojas/azules."
		_:
			_label.text = "Listo. Sabotea todos los núcleos."


func _finish() -> void:
	if not _active:
		return
	_active = false
	SettingsManager.mark_match_tutorial_done()
	finished.emit()
	queue_free()

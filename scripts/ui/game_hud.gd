extends CanvasLayer

const PAUSE_SCRIPT := preload("res://scripts/ui/pause_menu.gd")

@onready var match_panel: Control = $MatchPanel
@onready var result_panel: Control = $ResultPanel
@onready var timer_label: Label = $MatchPanel/TopBar/TimerChip/TimerLabel
@onready var objectives_label: Label = $MatchPanel/TopBar/ObjChip/ObjectivesLabel
@onready var lives_container: VBoxContainer = $MatchPanel/LivesPanel/LivesMargin/LivesContainer
@onready var result_label: Label = $ResultPanel/Center/ResultCard/ResultCol/ResultLabel
@onready var unlock_label: Label = %UnlockLabel
@onready var level_label: Label = %LevelLabel
@onready var back_button: Button = $ResultPanel/Center/ResultCard/ResultCol/BackButton
@onready var rematch_button: Button = $ResultPanel/Center/ResultCard/ResultCol/RematchButton
@onready var combat_label: Label = $MatchPanel/CombatPanel/CombatMargin/CombatLabel
@onready var controls_hint: Label = $MatchPanel/ControlsHint
@onready var sabotage_panel: Control = %SabotagePanel
@onready var sabotage_bar: ProgressBar = %SabotageBar

var _timer_active := false
var _local_combat: CombatKit = null
var _local_explorer: ExplorerPlayer = null
var _pause: Node
var _pause_btn: Button
var _tip_label: Label
var _disconnect_shown := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameTheme.apply(match_panel)
	GameTheme.apply(result_panel)
	match_panel.visible = false
	result_panel.visible = false
	if sabotage_panel:
		sabotage_panel.visible = false
	back_button.pressed.connect(_on_back_pressed)
	rematch_button.pressed.connect(_on_rematch_pressed)
	GameTheme.style_primary(rematch_button)
	if timer_label and GameTheme.font_title():
		timer_label.add_theme_font_override("font", GameTheme.font_title())
		timer_label.add_theme_font_size_override("font_size", 28)
		timer_label.add_theme_color_override("font_color", GameTheme.C_CYAN)
	if controls_hint:
		GameTheme.style_muted(controls_hint, 13)
		if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
			controls_hint.text = "Joystick · DISPARO · mantén en núcleo para sabotear · ⏸ pausa"
		else:
			controls_hint.text = "WASD · Click · Q arma · G dash · Esc pausa · Mantén en núcleo"
	if unlock_label:
		unlock_label.add_theme_color_override("font_color", GameTheme.C_AMBER)
	if level_label:
		GameTheme.style_muted(level_label, 14)

	_pause = PAUSE_SCRIPT.new()
	add_child(_pause)
	_pause.quit_requested.connect(_on_back_pressed)

	_make_pause_button()
	_make_tip()
	NetworkManager.server_lost.connect(_on_server_lost)


func _make_pause_button() -> void:
	_pause_btn = Button.new()
	_pause_btn.text = "⏸"
	_pause_btn.custom_minimum_size = Vector2(52, 52)
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.offset_left = -68
	_pause_btn.offset_top = 10
	_pause_btn.offset_right = -12
	_pause_btn.offset_bottom = 62
	_pause_btn.pressed.connect(_toggle_pause)
	match_panel.add_child(_pause_btn)


func _make_tip() -> void:
	_tip_label = Label.new()
	_tip_label.visible = false
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tip_label.offset_left = -220
	_tip_label.offset_right = 220
	_tip_label.offset_top = 70
	_tip_label.offset_bottom = 130
	_tip_label.add_theme_font_size_override("font_size", 15)
	match_panel.add_child(_tip_label)


func _toggle_pause() -> void:
	if result_panel.visible:
		return
	if _pause and _pause.has_method("toggle_pause"):
		_pause.toggle_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if result_panel.visible:
			return
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _timer_active or get_tree().paused:
		return
	var time_left := GameManager.get_remaining_time()
	var mins := int(time_left) / 60
	var secs := int(time_left) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	_update_combat_hud()
	_update_sabotage_hud()


func _update_combat_hud() -> void:
	if combat_label == null:
		return
	if _local_combat == null:
		_find_local_combat()
	if _local_combat:
		var extra := ""
		var beast := _find_local_beast()
		if beast:
			extra = "\nHP Bestia: %d%%" % int(beast.get_hp_ratio() * 100.0)
		combat_label.text = _local_combat.get_hud_text() + extra


func _update_sabotage_hud() -> void:
	if sabotage_panel == null or sabotage_bar == null:
		return
	if _local_explorer == null:
		_find_local_explorer()
	if _local_explorer == null or not _local_explorer.is_sabotaging:
		sabotage_panel.visible = false
		return
	sabotage_panel.visible = true
	sabotage_bar.value = _local_explorer.get_sabotage_progress()


func _find_local_combat() -> void:
	var my_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is PlayerBase and (node as PlayerBase).peer_id == my_id:
			_local_combat = (node as PlayerBase).combat
			if node is ExplorerPlayer:
				_local_explorer = node as ExplorerPlayer
			return


func _find_local_explorer() -> void:
	var my_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is ExplorerPlayer and (node as ExplorerPlayer).peer_id == my_id:
			_local_explorer = node as ExplorerPlayer
			return


func _find_local_beast() -> BeastPlayer:
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is BeastPlayer:
			return node as BeastPlayer
	return null


func show_match_hud() -> void:
	match_panel.visible = true
	result_panel.visible = false
	_timer_active = true
	objectives_label.text = "NÚCLEOS  %d" % GameManager.objectives_remaining
	_build_lives_display()
	_show_level_tip()


func _show_level_tip() -> void:
	if _tip_label == null:
		return
	var tip := ""
	if ProgressionManager.campaign_mode or NetworkManager.is_solo_practice:
		tip = ProgressionManager.level_tip()
	if tip.is_empty() and not SettingsManager.tutorial_seen:
		tip = "Robots: sabotea núcleos. Bestia: elimina robots. Esc/⏸ = pausa."
	if tip.is_empty():
		_tip_label.visible = false
		return
	_tip_label.text = "💡 " + tip
	_tip_label.visible = true
	_tip_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(_tip_label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func(): _tip_label.visible = false)
	SettingsManager.mark_tutorial_seen()


func update_objectives(remaining: int) -> void:
	objectives_label.text = "NÚCLEOS  %d" % remaining


func update_lives(peer_id: int, lives: int) -> void:
	var label := lives_container.get_node_or_null("Lives_%d" % peer_id) as Label
	if label:
		label.text = "%s  %s" % [
			NetworkManager.players.get(peer_id, {}).get("name", "Robot"),
			"●".repeat(maxi(lives, 0)) + "○".repeat(maxi(GameManager.EXPLORER_LIVES - lives, 0))
		]


func show_result(winner: String) -> void:
	_timer_active = false
	if _pause and _pause.has_method("close_pause"):
		_pause.close_pause()
	if sabotage_panel:
		sabotage_panel.visible = false
	result_panel.visible = true
	match winner:
		"explorers":
			result_label.text = "¡LOS ROBOTS GANAN!"
			result_label.add_theme_color_override("font_color", GameTheme.C_CYAN)
		"beast":
			result_label.text = "¡LA BESTIA GANA!"
			result_label.add_theme_color_override("font_color", GameTheme.C_CRIMSON)
	if GameTheme.font_title():
		result_label.add_theme_font_override("font", GameTheme.font_title())
		result_label.add_theme_font_size_override("font_size", 36)
	if unlock_label:
		var msg := ProgressionManager.last_unlock_message
		if ProgressionManager.campaign_complete and msg.is_empty():
			msg = "¡Campaña completada!"
		unlock_label.text = msg
		unlock_label.visible = not msg.is_empty()
	if level_label:
		if NetworkManager.is_solo_practice or ProgressionManager.campaign_mode:
			level_label.text = "%s · v%s · wins %d" % [
				ProgressionManager.level_name(),
				GameBrand.VERSION,
				ProgressionManager.wins_total,
			]
		else:
			level_label.text = "Partidas %d · victorias %d · v%s" % [
				ProgressionManager.matches_played,
				ProgressionManager.wins_total,
				GameBrand.VERSION,
			]
	if NetworkManager.is_solo_practice:
		rematch_button.text = "Otro intento"
	else:
		rematch_button.text = "Jugar otra"


func _build_lives_display() -> void:
	for child in lives_container.get_children():
		child.queue_free()
	for peer_id in GameManager.explorer_lives:
		var label := Label.new()
		label.name = "Lives_%d" % peer_id
		var lives: int = GameManager.explorer_lives[peer_id]
		label.text = "%s  %s" % [
			NetworkManager.players.get(peer_id, {}).get("name", "Robot"),
			"●".repeat(lives) + "○".repeat(GameManager.EXPLORER_LIVES - lives)
		]
		label.add_theme_font_size_override("font_size", 16)
		lives_container.add_child(label)


func _on_server_lost() -> void:
	if _disconnect_shown or NetworkManager.is_solo_practice:
		return
	_disconnect_shown = true
	_timer_active = false
	if _pause and _pause.has_method("close_pause"):
		_pause.close_pause()
	result_panel.visible = true
	result_label.text = "Conexión perdida"
	result_label.add_theme_color_override("font_color", GameTheme.C_AMBER)
	if unlock_label:
		unlock_label.text = "El servidor se desconectó. Vuelve al menú e inténtalo de nuevo."
		unlock_label.visible = true
	rematch_button.visible = false


func _on_back_pressed() -> void:
	if _pause and _pause.has_method("close_pause"):
		_pause.close_pause()
	get_tree().paused = false
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/main/menu.tscn")


func _on_rematch_pressed() -> void:
	get_tree().paused = false
	NetworkManager.request_return_to_lobby()

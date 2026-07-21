extends CanvasLayer

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


func _ready() -> void:
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
	if unlock_label:
		unlock_label.add_theme_color_override("font_color", GameTheme.C_AMBER)
	if level_label:
		GameTheme.style_muted(level_label, 14)


func _process(_delta: float) -> void:
	if not _timer_active:
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
		unlock_label.text = msg
		unlock_label.visible = not msg.is_empty()
	if level_label:
		if NetworkManager.is_solo_practice or ProgressionManager.campaign_mode:
			level_label.text = "Campaña · %s · wins %d%s" % [
				ProgressionManager.level_name(),
				ProgressionManager.wins_total,
				" · práctica" if NetworkManager.is_solo_practice else "",
			]
		else:
			level_label.text = "Partidas %d · victorias robots %d" % [
				ProgressionManager.matches_played,
				ProgressionManager.wins_total,
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


func _on_back_pressed() -> void:
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/main/menu.tscn")


func _on_rematch_pressed() -> void:
	NetworkManager.request_return_to_lobby()

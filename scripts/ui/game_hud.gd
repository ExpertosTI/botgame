extends CanvasLayer

@onready var match_panel: Control = $MatchPanel
@onready var result_panel: Control = $ResultPanel
@onready var timer_label: Label = $MatchPanel/TimerLabel
@onready var objectives_label: Label = $MatchPanel/ObjectivesLabel
@onready var lives_container: VBoxContainer = $MatchPanel/LivesContainer
@onready var result_label: Label = $ResultPanel/ResultLabel
@onready var back_button: Button = $ResultPanel/BackButton
@onready var rematch_button: Button = $ResultPanel/RematchButton
@onready var combat_label: Label = $MatchPanel/CombatLabel

var _timer_active := false
var _local_combat: CombatKit = null


func _ready() -> void:
	match_panel.visible = false
	result_panel.visible = false
	back_button.pressed.connect(_on_back_pressed)
	rematch_button.pressed.connect(_on_rematch_pressed)
	if combat_label == null:
		combat_label = Label.new()
		combat_label.name = "CombatLabel"
		combat_label.position = Vector2(10, 130)
		match_panel.add_child(combat_label)


func _process(_delta: float) -> void:
	if not _timer_active:
		return
	var time_left := GameManager.get_remaining_time()
	var mins := int(time_left) / 60
	var secs := int(time_left) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	_update_combat_hud()


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


func _find_local_combat() -> void:
	var my_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is PlayerBase and (node as PlayerBase).peer_id == my_id:
			_local_combat = (node as PlayerBase).combat
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
	objectives_label.text = "Núcleos: %d" % GameManager.objectives_remaining
	_build_lives_display()


func update_objectives(remaining: int) -> void:
	objectives_label.text = "Núcleos: %d" % remaining


func update_lives(peer_id: int, lives: int) -> void:
	var label := lives_container.get_node_or_null("Lives_%d" % peer_id) as Label
	if label:
		label.text = "%s: %s" % [
			NetworkManager.players.get(peer_id, {}).get("name", "Robot"),
			"♥".repeat(maxi(lives, 0)) + "♡".repeat(maxi(GameManager.EXPLORER_LIVES - lives, 0))
		]


func show_result(winner: String) -> void:
	_timer_active = false
	result_panel.visible = true
	match winner:
		"explorers":
			result_label.text = "¡Los Robots Ganan!"
			result_label.modulate = Color(0.35, 0.85, 1.0)
		"beast":
			result_label.text = "¡La Bestia Gana!"
			result_label.modulate = Color(1.0, 0.35, 0.35)


func _build_lives_display() -> void:
	for child in lives_container.get_children():
		child.queue_free()
	for peer_id in GameManager.explorer_lives:
		var label := Label.new()
		label.name = "Lives_%d" % peer_id
		var lives: int = GameManager.explorer_lives[peer_id]
		label.text = "%s: %s" % [
			NetworkManager.players.get(peer_id, {}).get("name", "Robot"),
			"♥".repeat(lives) + "♡".repeat(GameManager.EXPLORER_LIVES - lives)
		]
		lives_container.add_child(label)


func _on_back_pressed() -> void:
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/main/menu.tscn")


func _on_rematch_pressed() -> void:
	# Reset ready flags y volver al lobby
	for pid in NetworkManager.players:
		NetworkManager.players[pid]["ready"] = false
	get_tree().change_scene_to_file("res://scenes/main/lobby.tscn")

class_name KillFeed
extends Control

## Feed de eventos de combate (esquina).

const MAX_LINES := 5

var _box: VBoxContainer
var _lines: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 12
	offset_top = -220
	offset_right = 360
	offset_bottom = -80
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	add_child(_box)
	MatchStats.stats_updated.connect(_on_stats)
	GameManager.objective_destroyed.connect(_on_core)
	GameManager.explorer_eliminated.connect(_on_elim)


func push(text: String, color: Color = Color(0.85, 0.9, 1.0)) -> void:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", color)
	lab.modulate.a = 1.0
	_box.add_child(lab)
	_lines.append(lab)
	while _lines.size() > MAX_LINES:
		var old: Label = _lines.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := lab.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(lab, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func():
		if is_instance_valid(lab):
			_lines.erase(lab)
			lab.queue_free()
	)


func _on_stats() -> void:
	pass


func _on_core(remaining: int) -> void:
	push("Núcleo saboteado · quedan %d" % remaining, Color(1.0, 0.55, 0.2))


func _on_elim(peer_id: int) -> void:
	var n: String = str(NetworkManager.players.get(peer_id, {}).get("name", "Robot"))
	push("%s eliminado" % n, Color(1.0, 0.35, 0.4))

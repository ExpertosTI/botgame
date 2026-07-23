extends Control

## Intro al arrancar; Skip → hub.
## Web: preferir WebM (MP4 suele fallar en HTML5). Fallback keyart.


func _ready() -> void:
	if NetworkManager.is_dedicated_server:
		get_tree().change_scene_to_file("res://scenes/main/server_main.tscn")
		return
	var skip_btn := $SkipButton as Button
	skip_btn.pressed.connect(_finish)
	var player := $Video as VideoStreamPlayer
	var ok := false
	var candidates: Array[String] = []
	if OS.has_feature("web") or OS.get_name() == "Web":
		candidates = [
			"res://assets/video/intro/chadrine_intro.webm",
			"res://assets/video/intro/chadrine_intro.mp4",
		]
	else:
		candidates = [
			"res://assets/video/intro/chadrine_intro.mp4",
			"res://assets/video/intro/chadrine_intro.webm",
		]
	for path in candidates:
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream == null or player == null:
			continue
		player.stream = stream
		if not player.finished.is_connected(_finish):
			player.finished.connect(_finish)
		player.play()
		ok = player.is_playing()
		if ok:
			break
	if not ok:
		_show_keyart_fallback()
		get_tree().create_timer(3.0).timeout.connect(_finish)


func _show_keyart_fallback() -> void:
	var art_path := "res://assets/art/chadrine_keyart.png"
	if not ResourceLoader.exists(art_path):
		return
	var tex := load(art_path) as Texture2D
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(tr)
	move_child(tr, 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	ModeRouter.intro_seen_session = true
	get_tree().change_scene_to_file(ModeRouter.HUB_SCENE)

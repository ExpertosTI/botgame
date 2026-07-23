extends Control

## Intro al arrancar; Skip → hub. Fallback a keyart si el MP4 no carga.


func _ready() -> void:
	if NetworkManager.is_dedicated_server:
		get_tree().change_scene_to_file("res://scenes/main/server_main.tscn")
		return
	var skip_btn := $SkipButton as Button
	skip_btn.pressed.connect(_finish)
	var path := "res://assets/video/intro/chadrine_intro.mp4"
	var player := $Video as VideoStreamPlayer
	var ok := false
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream != null and player:
			player.stream = stream
			if not player.finished.is_connected(_finish):
				player.finished.connect(_finish)
			player.play()
			ok = player.is_playing()
	if not ok:
		_show_keyart_fallback()
		get_tree().create_timer(2.5).timeout.connect(_finish)


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

extends Control

## Intro al arrancar; Skip → hub.
## Web: NUNCA VideoStreamPlayer (OOB WASM en móvil). Solo splash + avanzar.

var _finished := false


func _ready() -> void:
	if NetworkManager.is_dedicated_server:
		# call_deferred: change_scene en _ready pega remove_child ("Parent busy").
		get_tree().change_scene_to_file.call_deferred("res://scenes/main/server_main.tscn")
		return
	var skip_btn := $SkipButton as Button
	skip_btn.pressed.connect(_finish)
	if OS.has_feature("web") or OS.get_name() == "Web":
		## Vídeo HTML5 en iPhone/Chrome DevTools = memory access out of bounds.
		_show_keyart_fallback()
		skip_btn.text = "JUGAR →"
		get_tree().create_timer(1.4).timeout.connect(_finish)
		return
	var player := $Video as VideoStreamPlayer
	var ok := false
	var candidates: Array[String] = [
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
	## Icono del juego centrado (no keyart AI).
	var art_path := "res://assets/ui/splash_chadrine.png"
	if not ResourceLoader.exists(art_path):
		art_path = "res://icon.png"
	if not ResourceLoader.exists(art_path):
		art_path = "res://icon.svg"
	if not ResourceLoader.exists(art_path):
		return
	var tex := load(art_path) as Texture2D
	if tex == null:
		return
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	move_child(wrap, 1)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(220, 220)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(tr)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	ModeRouter.intro_seen_session = true
	## Parar vídeo si existía (desktop) antes del cambio de escena.
	var player := get_node_or_null("Video") as VideoStreamPlayer
	if player:
		player.stop()
		player.stream = null
	get_tree().change_scene_to_file(ModeRouter.HUB_SCENE)

extends CanvasLayer

## Overlay de diagnóstico. F3 lo abre y cierra; en Web también responde a
## ?debug=1 en la URL y al arranque con --debug-hud.
##
## Existe para no volver a discutir el rendimiento a ciegas: mide lo que se nos
## fue de las manos antes (nodos que no se liberaban, proyectiles sin techo,
## draw calls de FX) y la latencia real al servidor.

const REFRESH_HZ := 4.0

var _label: Label
var _accum := 0.0
var _worst_frame_ms := 0.0
var _visible_now := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_visible_now = _wants_debug_at_boot()
	_label.visible = _visible_now
	set_process(true)


func _build() -> void:
	var panel := PanelContainer.new()
	panel.name = "DebugPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-360, 8)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.82)
	style.border_color = Color(0.2, 0.85, 0.9, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_label = Label.new()
	_label.name = "DebugText"
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)
	# El panel se muestra/oculta a través de la etiqueta para no recalcular el
	# layout del CanvasLayer completo cada vez.
	_label.visible = false


func _wants_debug_at_boot() -> bool:
	if "--debug-hud" in OS.get_cmdline_user_args() or "--debug-hud" in OS.get_cmdline_args():
		return true
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("location.search", true)).contains("debug=1")
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F3:
		_visible_now = not _visible_now
		_label.visible = _visible_now
		_worst_frame_ms = 0.0
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var frame_ms := delta * 1000.0
	_worst_frame_ms = maxf(_worst_frame_ms, frame_ms)
	if not _visible_now:
		return
	_accum += delta
	if _accum < 1.0 / REFRESH_HZ:
		return
	_accum = 0.0
	_label.text = _report()
	_worst_frame_ms = 0.0


func _report() -> String:
	var lines: PackedStringArray = []
	lines.append("CHADRINE %s · %s" % [GameBrand.VERSION, _renderer()])
	lines.append(
		"fps %d  frame %.1f ms  peor %.1f ms"
		% [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0), _worst_frame_ms]
	)
	lines.append(
		"draw %d  objetos %d  prim %.0fk"
		% [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0,
		]
	)
	lines.append(
		"nodos %d  huérfanos %d  recursos %d"
		% [
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		]
	)
	lines.append(
		"mem %.1f MB  vram %.1f MB"
		% [
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		]
	)
	var pool: Dictionary = FxPool.stats()
	var cache: Dictionary = FxAssets.cache_counts()
	lines.append(
		"proyectiles %d/%d  fx %d/%d  mat %d  malla %d"
		% [
			int(pool["proj_live"]), int(pool["proj_live"]) + int(pool["proj_free"]),
			int(pool["fx_live"]), int(pool["fx_live"]) + int(pool["fx_free"]),
			int(cache["materials"]), int(cache["spheres"]),
		]
	)
	var audio: Dictionary = AudioDirector.cache_stats()
	lines.append("audio: %d wav en caché · %d bips en cola" % [int(audio["streams"]), int(audio["pending"])])
	lines.append(_net_line())
	if GameManager.match_active:
		lines.append(
			"partida: núcleos %d  reloj %.0fs  mapa %s"
			% [GameManager.objectives_remaining, GameManager.get_remaining_time(), GameManager.current_map]
		)
	lines.append("F3 para cerrar")
	return "\n".join(lines)


func _renderer() -> String:
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))


func _net_line() -> String:
	if NetworkManager.is_solo_practice:
		return "red: práctica offline · %d jugadores" % NetworkManager.get_player_count()
	if not NetworkManager.multiplayer.has_multiplayer_peer():
		return "red: sin conexión"
	if NetworkManager.multiplayer.is_server():
		return "red: servidor · %d jugadores" % NetworkManager.get_player_count()
	var rtt := NetworkManager.rtt_ms
	var rtt_s := "midiendo" if rtt < 0.0 else "%.0f ms" % rtt
	return "red: cliente · rtt %s · %d jugadores" % [rtt_s, NetworkManager.get_player_count()]

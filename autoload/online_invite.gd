extends CanvasLayer

## En práctica solitaria: vigila el lobby online y ofrece unirse.

signal invite_accepted(player_name: String)

const POLL_SEC := 4.0
const SNOOZE_SEC := 90.0

var _http: HTTPRequest
var _poll_t := 0.0
var _known: Dictionary = {}  # name -> true
var _snoozed: Dictionary = {}  # name -> unix time until
var _bootstrapped := false
var _panel: PanelContainer
var _title: Label
var _body: Label
var _pending_name := ""
var _busy := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_http_done)
	_build_ui()
	_panel.visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.name = "InviteRoot"
	add_child(root)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -210.0
	_panel.offset_right = 210.0
	_panel.offset_top = 16.0
	_panel.offset_bottom = 210.0
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	_title = Label.new()
	_title.text = "Jugador online"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	col.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 15)
	col.add_child(_body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)

	var yes := Button.new()
	yes.text = "Jugar online"
	yes.custom_minimum_size = Vector2(140, 44)
	yes.pressed.connect(_on_accept)
	row.add_child(yes)

	var no := Button.new()
	no.text = "Ahora no"
	no.custom_minimum_size = Vector2(120, 44)
	no.pressed.connect(_on_dismiss)
	row.add_child(no)

	call_deferred("_style_panel", yes, no)


func _style_panel(yes: Button, no: Button) -> void:
	if Engine.is_editor_hint():
		return
	GameTheme.apply(_panel)
	GameTheme.style_primary(yes)
	_title.add_theme_color_override("font_color", GameTheme.C_CYAN)
	_body.add_theme_color_override("font_color", GameTheme.C_TEXT)


func _process(delta: float) -> void:
	if NetworkManager.is_dedicated_server:
		return
	if not NetworkManager.is_solo_practice:
		_panel.visible = false
		_bootstrapped = false
		_known.clear()
		return
	_poll_t -= delta
	if _poll_t > 0.0 or _busy or _panel.visible:
		return
	_poll_t = POLL_SEC
	_request_presence()


func _presence_url() -> String:
	var u := NetworkManager.get_default_server_url()
	u = u.replace("wss://", "https://").replace("ws://", "http://")
	if u.ends_with("/ws"):
		u = u.substr(0, u.length() - 3)
	return u.rstrip("/") + "/api/presence"


func _request_presence() -> void:
	if _busy:
		return
	_busy = true
	var err: Error = _http.request(_presence_url())
	if err != OK:
		_busy = false


func _on_http_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if code != 200:
		return
	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var players: Array = data.get("players", [])
	var now := Time.get_unix_time_from_system()
	var fresh: Array[String] = []
	var seen_now: Dictionary = {}
	for p in players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var n := str(p.get("name", "")).strip_edges()
		if n.is_empty():
			continue
		seen_now[n] = true
		if _known.has(n):
			continue
		# Primera vez que vemos este nombre mientras estamos en práctica
		if _snoozed.has(n) and float(_snoozed[n]) > now:
			continue
		fresh.append(n)
	# Primera muestra: memorizar sin avisar (evita spam al entrar a práctica)
	if not _bootstrapped:
		_known = seen_now.duplicate()
		_bootstrapped = true
		return
	for n in seen_now.keys():
		_known[n] = true
	# Limpiar names que ya no están (pueden volver a avisar si reconectan)
	var drop: Array = []
	for n in _known.keys():
		if not seen_now.has(n):
			drop.append(n)
	for n in drop:
		_known.erase(n)
	if fresh.is_empty() or _panel.visible:
		return
	_show_invite(fresh[0])


func _show_invite(player_name: String) -> void:
	_pending_name = player_name
	_title.text = "¡Alguien se conectó!"
	_body.text = "%s está en el hangar online.\n¿Quieres salir de la práctica y jugar con esa persona?" % player_name
	_panel.visible = true


func _on_dismiss() -> void:
	if not _pending_name.is_empty():
		_snoozed[_pending_name] = Time.get_unix_time_from_system() + SNOOZE_SEC
	_pending_name = ""
	_panel.visible = false


func _on_accept() -> void:
	var who := _pending_name
	_panel.visible = false
	_pending_name = ""
	invite_accepted.emit(who)
	_switch_to_online(who)


func _switch_to_online(invitee: String) -> void:
	var my_name := NetworkManager.local_player_name
	if my_name.is_empty():
		my_name = "Jugador"
	# Salir de offline e ir al VPS
	NetworkManager.disconnect_from_game()
	GameManager.match_active = false
	var err: Error = NetworkManager.join_game("", my_name)
	if err != OK:
		push_warning("[OnlineInvite] No se pudo conectar: %s" % error_string(err))
		get_tree().change_scene_to_file("res://scenes/main/menu.tscn")
		return
	# Esperar connection_succeeded → lobby (ya conectado en NetworkManager)
	if not NetworkManager.connection_succeeded.is_connected(_go_lobby):
		NetworkManager.connection_succeeded.connect(_go_lobby, CONNECT_ONE_SHOT)
	if not NetworkManager.connection_failed.is_connected(_go_menu_fail):
		NetworkManager.connection_failed.connect(_go_menu_fail, CONNECT_ONE_SHOT)
	print("[OnlineInvite] Uniéndose online por invitación de ", invitee)


func _go_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/main/lobby.tscn")


func _go_menu_fail() -> void:
	get_tree().change_scene_to_file("res://scenes/main/menu.tscn")

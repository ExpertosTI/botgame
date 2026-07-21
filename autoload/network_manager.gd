extends Node

## Multijugador por WebSocket (WebApp + APK + VPS).

signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal players_updated
signal server_started
signal connection_failed
signal connection_succeeded
signal join_rejected(reason: String)
signal lobby_settings_changed
signal match_start_requested(map_id: String)

const CONFIG_PATH := "res://config/server_config.tres"
const MAX_PLAYERS_DEFAULT := 5

var peer: WebSocketMultiplayerPeer = null
var players: Dictionary = {}  # peer_id -> { name, role, ready }
var local_player_name := "Jugador"
var selected_map: String = "lab_neon"
var is_dedicated_server := false
var config: ServerConfig = null
var last_reject_reason := ""
var _join_confirmed := false

const MAP_IDS := ["lab_neon", "containers", "ruins"]
const MAP_NAMES := {
	"lab_neon": "Laboratorio Neon",
	"containers": "Ciudad de Contenedores",
	"ruins": "Ruinas del Núcleo",
}


func _ready() -> void:
	config = load(CONFIG_PATH) as ServerConfig
	if config == null:
		config = ServerConfig.new()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Arranque headless: godot --headless --path . -- --server
	if _wants_dedicated_server():
		start_dedicated_server()


func _wants_dedicated_server() -> bool:
	return "--server" in OS.get_cmdline_user_args() or "--server" in OS.get_cmdline_args()


func start_dedicated_server(port: int = -1) -> Error:
	is_dedicated_server = true
	if port < 0:
		port = config.websocket_port
	peer = WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("No se pudo crear servidor WebSocket en puerto %d: %s" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	print("[Server] WebSocket escuchando en puerto ", port)
	server_started.emit()
	return OK


func host_listen_server(player_name: String = "Anfitrión", port: int = -1) -> Error:
	## Modo desarrollo: el PC hace de servidor y también juega.
	is_dedicated_server = false
	local_player_name = player_name
	if port < 0:
		port = config.websocket_port
	peer = WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_add_player(1, player_name)
	server_started.emit()
	return OK


func join_game(address: String = "", player_name: String = "Jugador") -> Error:
	is_dedicated_server = false
	_join_confirmed = false
	last_reject_reason = ""
	local_player_name = player_name
	if address.is_empty():
		address = config.server_url
	# Acepta host puro o URL completa
	if not address.begins_with("ws://") and not address.begins_with("wss://"):
		if ":" in address and not address.contains("/"):
			address = "ws://%s" % address
		else:
			address = "ws://%s:%d" % [address, config.websocket_port]

	peer = WebSocketMultiplayerPeer.new()
	var err := peer.create_client(address)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func disconnect_from_game() -> void:
	if peer:
		peer.close()
		peer = null
	players.clear()
	_join_confirmed = false
	multiplayer.multiplayer_peer = null


func is_host() -> bool:
	## En dedicated server, el "host" de lobby es el servidor (peer 1).
	## Los clientes usan RPC al servidor para acciones de lobby.
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func can_start_match() -> bool:
	return is_host()


func get_player_count() -> int:
	return players.size()


func get_default_server_url() -> String:
	return config.server_url


func _add_player(id: int, player_name: String) -> void:
	players[id] = {
		"name": player_name,
		"role": "",
		"ready": false,
		"skin": 0,
		"loadout": 0,
	}
	player_connected.emit(id, players[id])
	players_updated.emit()


## Tras RPC, Godot a veces convierte claves int→String; normalizamos siempre.
func _normalize_players(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in raw:
		var pid := int(k)
		var info: Variant = raw[k]
		if typeof(info) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = (info as Dictionary).duplicate(true)
		d["ready"] = bool(d.get("ready", false))
		d["skin"] = int(d.get("skin", 0))
		d["loadout"] = int(d.get("loadout", 0))
		d["role"] = str(d.get("role", ""))
		d["name"] = str(d.get("name", "?"))
		out[pid] = d
	return out


func get_player(peer_id: int) -> Dictionary:
	if players.has(peer_id):
		return players[peer_id]
	var as_str := str(peer_id)
	if players.has(as_str):
		return players[as_str]
	return {}


func _broadcast_lobby() -> void:
	if not multiplayer.is_server():
		return
	# call_local en _sync_full_state actualiza también al servidor
	_sync_full_state.rpc(players, selected_map, GameManager.beast_variant)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		# Sync lista y settings al nuevo peer
		_sync_full_state.rpc_id(id, players, selected_map, GameManager.beast_variant)


@rpc("authority", "call_local", "reliable")
func _sync_full_state(remote_players: Dictionary, map_id: String, beast_variant: int) -> void:
	players = _normalize_players(remote_players)
	selected_map = map_id
	GameManager.beast_variant = beast_variant as GameManager.BeastVariant
	players_updated.emit()
	lobby_settings_changed.emit()
	var my_id := multiplayer.get_unique_id()
	if not is_dedicated_server and players.has(my_id) and not _join_confirmed:
		_join_confirmed = true
		connection_succeeded.emit()


@rpc("any_peer", "reliable")
func register_player(id: int, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var cap: int = config.max_players if config else MAX_PLAYERS_DEFAULT
	if players.size() >= cap:
		_reject_join.rpc_id(id, "Sala llena (máximo %d jugadores)" % cap)
		if peer:
			peer.disconnect_peer(id)
		return
	_add_player(id, player_name)
	_broadcast_lobby()



@rpc("authority", "reliable")
func _reject_join(reason: String) -> void:
	last_reject_reason = reason
	join_rejected.emit(reason)
	disconnect_from_game()
	connection_failed.emit()


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	players.erase(str(id))
	player_disconnected.emit(id)
	players_updated.emit()
	if multiplayer.is_server():
		_broadcast_lobby()


func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	register_player.rpc_id(1, my_id, local_player_name)
	# connection_succeeded se emite al recibir sync con nuestro id


func _on_connection_failed() -> void:
	peer = null
	connection_failed.emit()


func _on_server_disconnected() -> void:
	players.clear()
	peer = null
	players_updated.emit()


func submit_role(role: String) -> void:
	var id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		set_player_role(id, role)
	else:
		set_player_role.rpc_id(1, id, role)


func submit_ready(ready: bool) -> void:
	var id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		set_player_ready(id, ready)
	else:
		set_player_ready.rpc_id(1, id, ready)


func submit_skin(skin: int) -> void:
	var id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		set_player_skin(id, skin)
	else:
		set_player_skin.rpc_id(1, id, skin)


func submit_loadout(loadout: int) -> void:
	var id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		set_player_loadout(id, loadout)
	else:
		set_player_loadout.rpc_id(1, id, loadout)


func submit_map(map_id: String) -> void:
	if multiplayer.is_server():
		set_selected_map(map_id)
	else:
		set_selected_map.rpc_id(1, map_id)


func submit_beast_variant(variant: int) -> void:
	if multiplayer.is_server():
		set_beast_variant(variant)
	else:
		set_beast_variant.rpc_id(1, variant)


@rpc("any_peer", "reliable")
func set_player_role(peer_id: int, role: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	# sender 0 = llamada local en listen-server
	if sender != 0 and sender != peer_id:
		return
	peer_id = int(peer_id)
	if not players.has(peer_id):
		return
	if role == "beast":
		for pid in players:
			if players[pid].get("role", "") == "beast" and int(pid) != peer_id:
				players[pid]["role"] = "explorer"
				players[pid]["ready"] = false
	players[peer_id]["role"] = role
	players[peer_id]["ready"] = false
	_broadcast_lobby()


@rpc("any_peer", "reliable")
func set_player_ready(peer_id: int, ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer_id:
		return
	peer_id = int(peer_id)
	if not players.has(peer_id):
		return
	players[peer_id]["ready"] = ready
	_broadcast_lobby()


@rpc("any_peer", "reliable")
func set_selected_map(map_id: String) -> void:
	if not multiplayer.is_server():
		return
	if map_id in MAP_IDS:
		selected_map = map_id
		_broadcast_lobby()


@rpc("any_peer", "reliable")
func set_player_skin(peer_id: int, skin: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer_id:
		return
	peer_id = int(peer_id)
	if not players.has(peer_id):
		return
	players[peer_id]["skin"] = clampi(skin, 0, 3)
	_broadcast_lobby()


@rpc("any_peer", "reliable")
func set_player_loadout(peer_id: int, loadout: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer_id:
		return
	peer_id = int(peer_id)
	if not players.has(peer_id):
		return
	players[peer_id]["loadout"] = clampi(loadout, 0, 3)
	_broadcast_lobby()


@rpc("any_peer", "reliable")
func set_beast_variant(variant: int) -> void:
	if not multiplayer.is_server():
		return
	GameManager.beast_variant = variant as GameManager.BeastVariant
	_broadcast_lobby()



func all_players_ready() -> bool:
	if players.is_empty():
		return false
	for info in players.values():
		if not info.get("ready", false):
			return false
	return true


func has_exactly_one_beast() -> bool:
	var beasts := 0
	for info in players.values():
		if info.get("role", "") == "beast":
			beasts += 1
	return beasts == 1


func count_explorers() -> int:
	var n := 0
	for info in players.values():
		if info.get("role", "") != "beast":
			n += 1
	return n


@rpc("any_peer", "reliable")
func request_start_match() -> void:
	if not multiplayer.is_server():
		return
	if players.size() < 2:
		return
	if not all_players_ready():
		return
	if not has_exactly_one_beast():
		return
	# Roles por defecto: quien no eligió es explorer
	for pid in players:
		if players[pid].get("role", "") == "":
			players[pid]["role"] = "explorer"
	_do_start_match.rpc(selected_map)


@rpc("authority", "call_local", "reliable")
func _do_start_match(map_id: String) -> void:
	selected_map = map_id
	match_start_requested.emit(map_id)

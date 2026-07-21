extends Node

## HTTP mínimo en el servidor dedicado: GET /api/presence → JSON de lobby.
## Puerto 8081 (Traefik PathPrefix /api/presence).

const LISTEN_PORT := 8081

var _tcp: TCPServer
var _clients: Array = []  # StreamPeerTCP


func _ready() -> void:
	# Esperar a que NetworkManager decida si es dedicated
	call_deferred("_maybe_start")


func _maybe_start() -> void:
	if not NetworkManager.is_dedicated_server:
		return
	_tcp = TCPServer.new()
	var err: Error = _tcp.listen(LISTEN_PORT)
	if err != OK:
		push_error("[Presence] No se pudo escuchar en %d: %s" % [LISTEN_PORT, error_string(err)])
		return
	print("[Presence] HTTP lobby en puerto ", LISTEN_PORT)


func _process(_delta: float) -> void:
	if _tcp == null:
		return
	while _tcp.is_connection_available():
		var c := _tcp.take_connection()
		if c:
			_clients.append(c)
	var i := 0
	while i < _clients.size():
		var c: StreamPeerTCP = _clients[i]
		c.poll()
		var st := c.get_status()
		if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
			_clients.remove_at(i)
			continue
		if st == StreamPeerTCP.STATUS_CONNECTED and c.get_available_bytes() > 0:
			_handle_client(c)
			_clients.remove_at(i)
			continue
		i += 1


func _handle_client(c: StreamPeerTCP) -> void:
	var raw := c.get_utf8_string(c.get_available_bytes())
	var body := _build_json()
	var resp := "HTTP/1.1 200 OK\r\n"
	resp += "Content-Type: application/json; charset=utf-8\r\n"
	resp += "Access-Control-Allow-Origin: *\r\n"
	resp += "Cache-Control: no-store\r\n"
	resp += "Connection: close\r\n"
	resp += "Content-Length: %d\r\n\r\n" % body.to_utf8_buffer().size()
	resp += body
	c.put_data(resp.to_utf8_buffer())
	c.disconnect_from_host()


func _build_json() -> String:
	var list: Array = []
	for pid in NetworkManager.players:
		var info: Dictionary = NetworkManager.players[pid]
		list.append({
			"id": int(pid),
			"name": str(info.get("name", "?")),
			"role": str(info.get("role", "")),
			"ready": bool(info.get("ready", false)),
		})
	var payload := {
		"count": list.size(),
		"players": list,
		"ts": Time.get_unix_time_from_system(),
	}
	return JSON.stringify(payload)

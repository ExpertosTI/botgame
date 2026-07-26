extends "res://tests/test_case.gd"

## Reglas del lobby: exactamente una bestia, todos listos, y normalización de
## la tabla de jugadores (los RPC de Godot convierten claves int→String).


var _saved_players: Dictionary = {}
var _saved_solo := false


func suite_name() -> String:
	return "lobby_rules"


func run() -> void:
	_saved_players = NetworkManager.players.duplicate(true)
	_saved_solo = NetworkManager.is_solo_practice

	_ready_and_beast_counting()
	_role_swap_keeps_a_single_beast()
	_normalize_players_repairs_rpc_payloads()
	_map_selection_rejects_unknown_ids()

	NetworkManager.players = _saved_players
	NetworkManager.is_solo_practice = _saved_solo


func _make_player(pname: String, role: String, ready: bool, skin := 0, loadout := 0) -> Dictionary:
	return {"name": pname, "role": role, "ready": ready, "skin": skin, "loadout": loadout}


func _ready_and_beast_counting() -> void:
	var n := NetworkManager
	n.players = {}
	ok(not n.all_players_ready(), "un lobby vacío no puede estar listo")

	n.players = {
		1: _make_player("Host", "beast", true),
		2: _make_player("R1", "explorer", true),
		3: _make_player("R2", "explorer", false),
	}
	ok(not n.all_players_ready(), "con un jugador sin listo no se arranca")
	eq(n.count_explorers(), 2, "conteo de robots incorrecto")
	ok(n.has_exactly_one_beast(), "debe detectar la única bestia")

	n.players[3]["ready"] = true
	ok(n.all_players_ready(), "con todos listos sí se arranca")

	n.players[3]["role"] = "beast"
	ok(not n.has_exactly_one_beast(), "dos bestias deben invalidar el arranque")

	n.players = {1: _make_player("Solo", "explorer", true)}
	ok(not n.has_exactly_one_beast(), "sin bestia no se arranca")
	eq(n.count_explorers(), 1, "un jugador sin rol cuenta como robot")


func _role_swap_keeps_a_single_beast() -> void:
	## set_player_role solo corre en el servidor; emulamos con peer offline.
	var n := NetworkManager
	var had_peer := push_offline_peer()
	n.players = {
		1: _make_player("A", "beast", true),
		2: _make_player("B", "explorer", true),
	}
	n.set_player_role(2, "beast")
	eq(str(n.players[1]["role"]), "explorer", "la bestia anterior debe pasar a robot")
	eq(str(n.players[2]["role"]), "beast", "el nuevo rol no se aplicó")
	ok(not bool(n.players[1]["ready"]), "quien pierde el rol de bestia deja de estar listo")
	ok(n.has_exactly_one_beast(), "tras el cambio debe seguir habiendo una sola bestia")
	pop_peer(had_peer)


func _normalize_players_repairs_rpc_payloads() -> void:
	var n := NetworkManager
	var raw := {
		"1": {"name": "Host", "role": "beast", "ready": "true"},
		"2": {"name": "R1"},
		"basura": 42,
	}
	var clean := n._normalize_players(raw)
	eq(clean.size(), 2, "las entradas no-diccionario deben descartarse")
	ok(clean.has(1), "las claves String deben volver a int")
	eq(typeof(clean[2]["ready"]), TYPE_BOOL, "ready debe quedar como bool")
	eq(typeof(clean[2]["skin"]), TYPE_INT, "skin debe quedar como int")
	eq(typeof(clean[2]["loadout"]), TYPE_INT, "loadout debe quedar como int")
	eq(str(clean[2]["role"]), "", "un rol ausente debe quedar vacío, no null")

	n.players = clean
	ok(not n.get_player(1).is_empty(), "get_player debe resolver por int")
	ok(n.get_player(99).is_empty(), "un peer inexistente debe devolver vacío")


func _map_selection_rejects_unknown_ids() -> void:
	var n := NetworkManager
	var had_peer := push_offline_peer()
	var previous := n.selected_map
	n.set_selected_map("containers")
	eq(n.selected_map, "containers", "un teatro válido debe aplicarse")
	n.set_selected_map("mapa_que_no_existe")
	eq(n.selected_map, "containers", "un teatro inválido no debe cambiar la selección")
	eq(NetworkManager.MAP_IDS.size(), NetworkManager.MAP_NAMES.size(), "cada teatro necesita nombre")
	for mid in NetworkManager.MAP_IDS:
		has_key(NetworkManager.MAP_NAMES, mid, "teatro sin nombre legible")
	n.selected_map = previous
	pop_peer(had_peer)

extends "res://tests/test_case.gd"

## Práctica en solitario: la sala que se arma con bots.
##
## Durante mucho tiempo la práctica fue 1 contra 1 (tú y un bot), así que la
## fantasía del juego —una Bestia contra una tripulación— no existía en ningún
## sitio salvo en una sala online con gente dentro. Estos casos fijan que la
## sala offline se parezca a una partida de verdad.

var _saved_peer: MultiplayerPeer = null
var _saved_solo := false
var _saved_campaign := false


func suite_name() -> String:
	return "practice"


func run() -> void:
	_hazard_avoid_and_unstuck_api()
	_saved_solo = NetworkManager.is_solo_practice
	_saved_campaign = ProgressionManager.campaign_mode
	_saved_peer = push_offline_peer()

	_crew_fills_the_room("explorer")
	_crew_fills_the_room("beast")
	_allies_are_distinguishable()
	_bots_never_exceed_the_room()

	NetworkManager.players.clear()
	NetworkManager.is_solo_practice = _saved_solo
	ProgressionManager.campaign_mode = _saved_campaign
	pop_peer(_saved_peer)


func _hazard_avoid_and_unstuck_api() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ai/practice_ai.gd")
	ok(src.contains("_reverse_t"), "bots revierten si se atascan")
	ok(src.contains("PROBE_LEN := 3.2") or src.contains("PROBE_LEN := 3"), "probe más largo")
	ok(src.contains("collision_mask = 1"), "probe solo mundo/props")


func _arm(role: String) -> void:
	NetworkManager.players.clear()
	NetworkManager.is_solo_practice = true
	NetworkManager.call("_add_player", 1, "Humano")
	NetworkManager.players[1]["role"] = role
	NetworkManager.prepare_solo_bots()


func _roles() -> Dictionary:
	var out := {"explorer": 0, "beast": 0, "bots": 0}
	for pid in NetworkManager.players:
		var info: Dictionary = NetworkManager.players[pid]
		var role := str(info.get("role", ""))
		if out.has(role):
			out[role] = int(out[role]) + 1
		if NetworkManager.is_bot_peer(int(pid)):
			out["bots"] = int(out["bots"]) + 1
	return out


func _crew_fills_the_room(human_role: String) -> void:
	_arm(human_role)
	var counts := _roles()
	eq(int(counts["beast"]), 1, "con humano %s debe haber exactamente 1 Bestia" % human_role)
	ok(
		int(counts["explorer"]) >= 3,
		"con humano %s la tripulación quedó en %d robots; la práctica volvería a ser 1 contra 1"
			% [human_role, int(counts["explorer"])]
	)
	ok(NetworkManager.has_exactly_one_beast(), "la regla de una sola Bestia debe cumplirse en práctica")


func _allies_are_distinguishable() -> void:
	## El color es el nombre: dos robots idénticos en pantalla no se distinguen.
	_arm("explorer")
	var seen: Array = []
	var repeated := 0
	for pid in NetworkManager.players:
		var info: Dictionary = NetworkManager.players[pid]
		if str(info.get("role", "")) != "explorer":
			continue
		var skin := int(info.get("skin", -1))
		if seen.has(skin):
			repeated += 1
		else:
			seen.append(skin)
	var available: int = CharacterCatalog.explorer_indices().size()
	if available >= seen.size() + repeated:
		eq(repeated, 0, "hay %d robots repitiendo aspecto y %d disponibles" % [repeated, available])


func _bots_never_exceed_the_room() -> void:
	var cap: int = NetworkManager.config.max_players if NetworkManager.config else NetworkManager.MAX_PLAYERS_DEFAULT
	for role in ["explorer", "beast"]:
		_arm(str(role))
		ok(
			NetworkManager.get_player_count() <= cap,
			"la práctica con humano %s arma %d jugadores y la sala admite %d"
				% [role, NetworkManager.get_player_count(), cap]
		)
	# Volver a armar no debe acumular bots de la vez anterior.
	var before := NetworkManager.get_player_count()
	NetworkManager.prepare_solo_bots()
	eq(NetworkManager.get_player_count(), before, "rearmar la práctica duplicó los bots")

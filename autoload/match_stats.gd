extends Node

## Estadísticas por partida: daño, bajas, sabotaje, MVP.

signal stats_updated
signal damage_recorded(from_peer: int, to_peer: int, amount: float)
signal elimination_recorded(killer: int, victim: int)

var active := false
var started_at_ms := 0
var winner := ""
## peer_id -> Dictionary
var peers: Dictionary = {}


func reset() -> void:
	active = false
	started_at_ms = 0
	winner = ""
	peers.clear()
	stats_updated.emit()


func begin_match() -> void:
	reset()
	active = true
	started_at_ms = Time.get_ticks_msec()
	for peer_id in GameManager.player_roles:
		_ensure(peer_id)
	stats_updated.emit()


func end_match(match_winner: String) -> void:
	if not active:
		return
	active = false
	winner = match_winner
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_sync_final.rpc(peers.duplicate(true), winner, started_at_ms)
	stats_updated.emit()


@rpc("authority", "call_remote", "reliable")
func _sync_final(remote_peers: Dictionary, match_winner: String, start_ms: int) -> void:
	peers = remote_peers
	winner = match_winner
	started_at_ms = start_ms
	active = false
	stats_updated.emit()


func _ensure(peer_id: int) -> Dictionary:
	if not peers.has(peer_id):
		var role := GameManager.get_role(peer_id)
		var info: Dictionary = NetworkManager.players.get(peer_id, {})
		peers[peer_id] = {
			"name": str(info.get("name", "Jugador %d" % peer_id)),
			"role": role,
			"damage_dealt": 0.0,
			"damage_taken": 0.0,
			"eliminations": 0,
			"deaths": 0,
			"cores_sabotaged": 0,
			"ability_uses": 0,
			"shots_fired": 0,
			"score": 0,
		}
	return peers[peer_id]


func record_damage(from_peer: int, to_peer: int, amount: float) -> void:
	if amount <= 0.0:
		return
	if from_peer > 0:
		var a := _ensure(from_peer)
		a["damage_dealt"] = float(a["damage_dealt"]) + amount
	if to_peer > 0:
		var b := _ensure(to_peer)
		b["damage_taken"] = float(b["damage_taken"]) + amount
	_recompute_scores()
	damage_recorded.emit(from_peer, to_peer, amount)


func record_elimination(killer_peer: int, victim_peer: int) -> void:
	if killer_peer > 0:
		var k := _ensure(killer_peer)
		k["eliminations"] = int(k["eliminations"]) + 1
	if victim_peer > 0:
		var v := _ensure(victim_peer)
		v["deaths"] = int(v["deaths"]) + 1
	_recompute_scores()
	elimination_recorded.emit(killer_peer, victim_peer)


func record_core(peer_id: int) -> void:
	if peer_id <= 0:
		return
	var s := _ensure(peer_id)
	s["cores_sabotaged"] = int(s["cores_sabotaged"]) + 1
	_recompute_scores()


func record_ability(peer_id: int) -> void:
	if peer_id <= 0:
		return
	var s := _ensure(peer_id)
	s["ability_uses"] = int(s["ability_uses"]) + 1
	_recompute_scores()


func record_shot(peer_id: int) -> void:
	if peer_id <= 0:
		return
	var s := _ensure(peer_id)
	s["shots_fired"] = int(s["shots_fired"]) + 1


func _recompute_scores() -> void:
	for peer_id in peers:
		var s: Dictionary = peers[peer_id]
		var score := 0.0
		score += float(s["damage_dealt"]) * 0.35
		score += float(s["eliminations"]) * 120.0
		score += float(s["cores_sabotaged"]) * 200.0
		score += float(s["ability_uses"]) * 8.0
		score -= float(s["deaths"]) * 40.0
		s["score"] = int(maxi(0, int(round(score))))
	stats_updated.emit()


func duration_seconds() -> float:
	if started_at_ms <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - started_at_ms) / 1000.0


func sorted_peers() -> Array:
	var ids: Array = peers.keys()
	ids.sort_custom(func(a, b): return int(peers[a]["score"]) > int(peers[b]["score"]))
	return ids


func mvp_peer() -> int:
	var ids := sorted_peers()
	if ids.is_empty():
		return 0
	return int(ids[0])


func mvp_name() -> String:
	var pid := mvp_peer()
	if pid == 0 or not peers.has(pid):
		return ""
	return str(peers[pid]["name"])


func scoreboard_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for peer_id in sorted_peers():
		var s: Dictionary = peers[peer_id]
		var role := "Bestia" if int(s["role"]) == GameManager.Role.BEAST else "Robot"
		lines.append("%s · %s · %d pts · DMG %d · KO %d · núcleos %d" % [
			s["name"],
			role,
			int(s["score"]),
			int(s["damage_dealt"]),
			int(s["eliminations"]),
			int(s["cores_sabotaged"]),
		])
	return lines


func local_summary() -> String:
	var my_id := 1
	if multiplayer.has_multiplayer_peer():
		my_id = multiplayer.get_unique_id()
	if not peers.has(my_id):
		var lines := scoreboard_lines()
		return "\n".join(lines) if not lines.is_empty() else ""
	var s: Dictionary = peers[my_id]
	return "Tú · %d pts · daño %d · KO %d · núcleos %d" % [
		int(s["score"]),
		int(s["damage_dealt"]),
		int(s["eliminations"]),
		int(s["cores_sabotaged"]),
	]

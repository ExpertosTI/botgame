extends "res://tests/test_case.gd"

## Campaña y desbloqueos. Cada caso restaura el estado real del jugador al
## salir: el runner corre contra el mismo user:// que el juego.

var _snapshot: Dictionary = {}


func suite_name() -> String:
	return "progression"


func run() -> void:
	_snapshot = _capture()
	_campaign_table_is_coherent()
	_level_gating()
	_loadout_and_beast_gating()
	_campaign_advances_only_from_the_frontier()
	_restore(_snapshot)


func _capture() -> Dictionary:
	var p := ProgressionManager
	return {
		"campaign_index": p.campaign_index,
		"selected_level": p.selected_level,
		"wins_total": p.wins_total,
		"matches_played": p.matches_played,
		"campaign_complete": p.campaign_complete,
		"best_score": p.best_score,
		"maps": p.unlocked_maps.duplicate(),
		"loadouts": p.unlocked_loadouts.duplicate(),
		"beasts": p.unlocked_beasts.duplicate(),
		"campaign_mode": p.campaign_mode,
	}


func _restore(snap: Dictionary) -> void:
	var p := ProgressionManager
	p.campaign_index = int(snap["campaign_index"])
	p.selected_level = int(snap["selected_level"])
	p.wins_total = int(snap["wins_total"])
	p.matches_played = int(snap["matches_played"])
	p.campaign_complete = bool(snap["campaign_complete"])
	p.best_score = int(snap["best_score"])
	p.unlocked_maps = (snap["maps"] as Array).duplicate()
	p.unlocked_loadouts = (snap["loadouts"] as Array).duplicate()
	p.unlocked_beasts = (snap["beasts"] as Array).duplicate()
	p.campaign_mode = bool(snap["campaign_mode"])
	p.save_progress()


func _campaign_table_is_coherent() -> void:
	var levels: Array = ProgressionManager.CAMPAIGN
	gt(float(levels.size()), 5.0, "la campaña necesita al menos 6 niveles")
	var prev_time := INF
	var prev_hp := 0.0
	for i in levels.size():
		var lv: Dictionary = levels[i]
		var label := "nivel %d" % (i + 1)
		eq(int(lv.get("id", -1)), i + 1, "%s: id fuera de orden" % label)
		ok(
			str(lv.get("map", "")) in NetworkManager.MAP_IDS,
			"%s apunta a un mapa inexistente: %s" % [label, str(lv.get("map", ""))]
		)
		gt(float(lv.get("time", 0.0)), 30.0, "%s: tiempo irrisorio" % label)
		in_range(float(lv.get("cores", 0)), 1.0, 12.0, "%s: núcleos fuera de rango" % label)
		in_range(float(lv.get("beast_hp", 0.0)), 0.5, 3.0, "%s: multiplicador de HP absurdo" % label)
		neq(str(lv.get("tip", "")), "", "%s sin tip de onboarding" % label)
		var lname := str(lv.get("name", ""))
		ok(not lname.contains("Skybridge"), "%s: nombre EN Skybridge" % label)
		ok(not lname.contains("Overclock"), "%s: nombre EN Overclock" % label)
		ok(not lname.contains("Neon Pressure"), "%s: nombre EN Neon Pressure" % label)
		in_range(
			float(lv.get("unlock_loadout", -1)), 0.0, 3.0,
			"%s: unlock_loadout fuera de rango" % label
		)
		# La dificultad tiene que subir: menos reloj y más HP de bestia.
		ok(float(lv.get("time", 0.0)) <= prev_time, "%s no reduce el reloj" % label)
		ok(float(lv.get("beast_hp", 0.0)) >= prev_hp, "%s no sube la dureza de la bestia" % label)
		prev_time = float(lv.get("time", 0.0))
		prev_hp = float(lv.get("beast_hp", 0.0))


func _level_gating() -> void:
	var p := ProgressionManager
	p.campaign_index = 2
	p.selected_level = 0
	ok(p.is_level_unlocked(0), "nivel 1 debe estar abierto")
	ok(p.is_level_unlocked(2), "el nivel frontera debe estar abierto")
	ok(not p.is_level_unlocked(3), "el nivel siguiente a la frontera debe estar cerrado")
	ok(not p.is_level_unlocked(-1), "índice negativo no debe estar abierto")
	ok(p.select_level(1), "seleccionar un nivel abierto debe funcionar")
	eq(p.selected_level, 1, "select_level no aplicó")
	ok(not p.select_level(9), "seleccionar un nivel cerrado debe fallar")
	eq(p.selected_level, 1, "un select_level fallido no debe mover la selección")


func _loadout_and_beast_gating() -> void:
	var p := ProgressionManager
	p.unlocked_loadouts = [0]
	ok(p.is_loadout_unlocked(0), "el arsenal inicial debe estar abierto")
	ok(not p.is_loadout_unlocked(3), "el arsenal 3 no debe estar abierto de salida")
	p.unlocked_beasts = [GameManager.BeastVariant.CLASSIC]
	ok(p.is_beast_unlocked(GameManager.BeastVariant.CLASSIC), "bestia clásica debe estar abierta")
	ok(
		not p.is_beast_unlocked(GameManager.BeastVariant.SHADOW),
		"la Sombra debe ganarse"
	)
	# Todos los teatros están abiertos por diseño (ver docs/GDD.md).
	var was_solo := NetworkManager.is_solo_practice
	NetworkManager.is_solo_practice = false
	for mid in NetworkManager.MAP_IDS:
		ok(p.is_map_unlocked(mid), "teatro %s debería estar disponible" % mid)
	NetworkManager.is_solo_practice = was_solo


func _campaign_advances_only_from_the_frontier() -> void:
	var p := ProgressionManager
	p.campaign_mode = true
	p.campaign_index = 3
	p.selected_level = 1
	p._advance_campaign()
	eq(p.campaign_index, 3, "repetir un nivel viejo no debe avanzar la campaña")
	ok(p.last_unlock_message.contains("replay"), "un replay debe avisarlo en el mensaje")

	p.selected_level = 3
	p._advance_campaign()
	eq(p.campaign_index, 4, "ganar en la frontera debe abrir el nivel siguiente")
	eq(p.selected_level, 4, "tras avanzar, el nivel nuevo queda seleccionado")

	p.campaign_index = p.CAMPAIGN.size() - 1
	p.selected_level = p.campaign_index
	p.campaign_complete = false
	p._advance_campaign()
	ok(p.campaign_complete, "ganar el último nivel debe cerrar la campaña")

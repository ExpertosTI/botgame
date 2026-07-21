extends Node

## Progresión local: campaña, desbloqueos y nivel de dificultad.

signal progress_changed

const SAVE_PATH := "user://botgame_progress.cfg"

## Niveles de campaña (mapas + reglas).
const CAMPAIGN := [
	{"id": 1, "name": "Nivel 1 · Hangar Neon", "map": "lab_neon", "time": 240, "cores": 4, "beast_hp": 1.0, "unlock_loadout": 1},
	{"id": 2, "name": "Nivel 2 · Contenedores", "map": "containers", "time": 210, "cores": 5, "beast_hp": 1.15, "unlock_loadout": 2},
	{"id": 3, "name": "Nivel 3 · Ruinas", "map": "ruins", "time": 180, "cores": 5, "beast_hp": 1.3, "unlock_loadout": 3},
	{"id": 4, "name": "Nivel 4 · Neon Hard", "map": "lab_neon", "time": 150, "cores": 6, "beast_hp": 1.45, "unlock_loadout": 3},
	{"id": 5, "name": "Nivel 5 · Final", "map": "ruins", "time": 120, "cores": 6, "beast_hp": 1.6, "unlock_loadout": 3},
]

var campaign_index := 0  # 0-based, nivel actual desbloqueado (máx jugable)
var wins_total := 0
var matches_played := 0
var unlocked_maps: Array = ["lab_neon"]
var unlocked_loadouts: Array = [0, 1]
var unlocked_beasts: Array = [0, 1]  # CLASSIC, MECHA
var last_unlock_message := ""
var campaign_mode := false


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_defaults()
		save_progress()
		return
	campaign_index = int(cfg.get_value("meta", "campaign_index", 0))
	wins_total = int(cfg.get_value("meta", "wins_total", 0))
	matches_played = int(cfg.get_value("meta", "matches_played", 0))
	unlocked_maps = cfg.get_value("unlock", "maps", ["lab_neon"])
	unlocked_loadouts = cfg.get_value("unlock", "loadouts", [0, 1])
	unlocked_beasts = cfg.get_value("unlock", "beasts", [0, 1])
	_normalize()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "campaign_index", campaign_index)
	cfg.set_value("meta", "wins_total", wins_total)
	cfg.set_value("meta", "matches_played", matches_played)
	cfg.set_value("unlock", "maps", unlocked_maps)
	cfg.set_value("unlock", "loadouts", unlocked_loadouts)
	cfg.set_value("unlock", "beasts", unlocked_beasts)
	cfg.save(SAVE_PATH)


func _defaults() -> void:
	campaign_index = 0
	wins_total = 0
	matches_played = 0
	unlocked_maps = ["lab_neon"]
	unlocked_loadouts = [0, 1]
	unlocked_beasts = [0, 1]


func _normalize() -> void:
	if unlocked_maps.is_empty():
		unlocked_maps = ["lab_neon"]
	if unlocked_loadouts.is_empty():
		unlocked_loadouts = [0]
	campaign_index = clampi(campaign_index, 0, CAMPAIGN.size() - 1)


func current_level() -> Dictionary:
	return CAMPAIGN[clampi(campaign_index, 0, CAMPAIGN.size() - 1)]


func level_name() -> String:
	return str(current_level().get("name", "Nivel"))


func is_map_unlocked(map_id: String) -> bool:
	return map_id in unlocked_maps


func is_loadout_unlocked(loadout: int) -> bool:
	return loadout in unlocked_loadouts


func is_beast_unlocked(variant: int) -> bool:
	return variant in unlocked_beasts


func max_campaign_level() -> int:
	return campaign_index + 1  # 1-based display


func apply_level_rules() -> void:
	## Ajusta GameManager según nivel de campaña (solo si campaign_mode).
	if not campaign_mode:
		GameManager.level_core_count = GameManager.OBJECTIVES_TO_WIN
		GameManager.level_match_time = -1.0
		GameManager.level_beast_hp_mult = 1.0
		return
	var lv := current_level()
	GameManager.level_core_count = int(lv.get("cores", 5))
	GameManager.level_match_time = float(lv.get("time", 240))
	GameManager.level_beast_hp_mult = float(lv.get("beast_hp", 1.0))
	GameManager.current_map = str(lv.get("map", "lab_neon"))


func on_match_ended(winner: String, map_id: String) -> void:
	matches_played += 1
	last_unlock_message = ""
	var robots_won := winner == "explorers"
	if robots_won:
		wins_total += 1
		_unlock_rewards(map_id)
		if campaign_mode:
			_advance_campaign()
	save_progress()
	progress_changed.emit()


func _unlock_rewards(map_id: String) -> void:
	var msgs: PackedStringArray = []
	# Desbloquear siguiente mapa de la lista
	var order := ["lab_neon", "containers", "ruins"]
	var idx := order.find(map_id)
	if idx >= 0 and idx + 1 < order.size():
		var nxt: String = order[idx + 1]
		if not is_map_unlocked(nxt):
			unlocked_maps.append(nxt)
			msgs.append("Mapa: %s" % NetworkManager.MAP_NAMES.get(nxt, nxt))
	# Loadouts
	for lo in range(4):
		if not is_loadout_unlocked(lo) and wins_total >= lo:
			unlocked_loadouts.append(lo)
			msgs.append("Arsenal #%d" % (lo + 1))
	# Bestia sombra tras 2 victorias
	if wins_total >= 2 and not is_beast_unlocked(GameManager.BeastVariant.SHADOW):
		unlocked_beasts.append(GameManager.BeastVariant.SHADOW)
		msgs.append("Bestia: Sombra")
	if not msgs.is_empty():
		last_unlock_message = "Desbloqueado · " + " · ".join(msgs)


func _advance_campaign() -> void:
	if campaign_index < CAMPAIGN.size() - 1:
		campaign_index += 1
		var lv := current_level()
		var mid: String = str(lv.get("map", "lab_neon"))
		if not is_map_unlocked(mid):
			unlocked_maps.append(mid)
		var ulo: int = int(lv.get("unlock_loadout", 0))
		if not is_loadout_unlocked(ulo):
			unlocked_loadouts.append(ulo)
		last_unlock_message = "¡Nivel %d desbloqueado! %s" % [campaign_index + 1, lv.get("name", "")]


func force_campaign_map() -> String:
	var mid: String = str(current_level().get("map", "lab_neon"))
	if not is_map_unlocked(mid):
		unlocked_maps.append(mid)
	return mid

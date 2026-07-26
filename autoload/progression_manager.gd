extends Node

## Progresión local: campaña ampliada, desbloqueos y nivel de dificultad.

signal progress_changed

const SAVE_PATH := "user://botgame_progress.cfg"
const BACKUP_PATH := "user://botgame_progress.bak.cfg"
## 1 = builds ≤ 1.3.x (sin campo de versión). Subir al cambiar el formato y
## añadir la migración correspondiente en _migrate().
const SCHEMA_VERSION := 2

## 12 niveles — 5 mapas + reglas crecientes + briefings duales.
const CAMPAIGN := [
	{
		"id": 1, "name": "Nivel 1 · Primer Hangar", "map": "lab_neon", "time": 240, "cores": 3, "beast_hp": 0.9, "unlock_loadout": 1,
		"tip": "Mantén pulsado cerca de un núcleo para sabotear.",
		"brief_crew": "El hangar abre. Tres núcleos. Canaliza y no te dejes pillar.",
		"brief_beast": "Eres el protocolo. Los robots vienen a por los núcleos. Interrúmpelos.",
		"win_crew": "Hangar silenciado. El protocolo tiembla.",
		"win_beast": "Tripulación neutralizada. El hangar sigue bajo control.",
		"loss_crew": "El reloj te ganó. Vuelve a canalizar más rápido.",
		"loss_beast": "Dejaste caer demasiados núcleos. Aprieta más.",
	},
	{
		"id": 2, "name": "Nivel 2 · Contenedores", "map": "containers", "time": 220, "cores": 4, "beast_hp": 1.0, "unlock_loadout": 1,
		"tip": "Usa pasillos estrechos para emboscar o escapar.",
		"brief_crew": "Pasillos de acero. Emboscadas cortas. Cuatro núcleos.",
		"brief_beast": "Ciérrales los corredores. Ellos necesitan tiempo; tú no.",
		"win_crew": "Los contenedores quedan a oscuras.",
		"win_beast": "Nadie sale del laberinto de cajas.",
		"loss_crew": "Os atraparon en un pasillo. Separad y reintentad.",
		"loss_beast": "Te rodearon. Corta antes de que canalicen.",
	},
	{
		"id": 3, "name": "Nivel 3 · Ruinas", "map": "ruins", "time": 200, "cores": 4, "beast_hp": 1.1, "unlock_loadout": 2,
		"tip": "Combate vertical: mira arriba y abajo.",
		"brief_crew": "Ruinas altas. Mira el eje vertical. Blindados aparecen.",
		"brief_beast": "Controla las plataformas. El que está arriba ve primero.",
		"win_crew": "Las ruinas ceden. Siguiente sector.",
		"win_beast": "Las ruinas siguen siendo tuya.",
		"loss_crew": "Caíste desde arriba. Usa la altura a tu favor.",
		"loss_beast": "Te flanquearon en vertical.",
	},
	{
		"id": 4, "name": "Nivel 4 · Presión Neon", "map": "lab_neon", "time": 180, "cores": 5, "beast_hp": 1.2, "unlock_loadout": 2,
		"tip": "Coordina: uno distrae, otro sabotea. Recoge powerups.",
		"brief_crew": "Cinco núcleos. Uno distrae, otro canaliza. Usad el ping.",
		"brief_beast": "Presión neon. No dejes que canalicen en pareja.",
		"win_crew": "Neon apagado. Acto I cerrado.",
		"win_beast": "La presión sostuvo el hangar.",
		"loss_crew": "Sin coordinación no hay sabotaje.",
		"loss_beast": "Te dividieron. Vuelve a cazar en grupo.",
	},
	{
		"id": 5, "name": "Nivel 5 · Pozo Reactor", "map": "reactor_pit", "time": 170, "cores": 5, "beast_hp": 1.3, "unlock_loadout": 2,
		"tip": "El núcleo central quema. Rodéalo, no lo cruce.",
		"brief_crew": "El pozo quema. Rodéalo. Cuidado con Sobrecarga.",
		"brief_beast": "El centro es trampa. Empújalos al pozo.",
		"win_crew": "Reactor en silencio.",
		"win_beast": "El pozo sigue vivo.",
		"loss_crew": "El calor os fundió. Más distancia.",
		"loss_beast": "Cruzaron el anillo. No otra vez.",
	},
	{
		"id": 6, "name": "Nivel 6 · Castillo", "map": "castle", "time": 160, "cores": 5, "beast_hp": 1.35, "unlock_loadout": 3,
		"tip": "Torres y murallas — emboscadas en la puerta.",
		"brief_crew": "Murallas y puertas. Emboscad en la entrada.",
		"brief_beast": "La puerta es el cuello de botella. Guárdala.",
		"win_crew": "El castillo cae.",
		"win_beast": "Las murallas aguantaron.",
		"loss_crew": "Os pillaron en la puerta.",
		"loss_beast": "Flanquearon la muralla.",
	},
	{
		"id": 7, "name": "Nivel 7 · Cueva", "map": "cave", "time": 150, "cores": 5, "beast_hp": 1.4, "unlock_loadout": 3,
		"tip": "Corredores estrechos. Escucha los pasos.",
		"brief_crew": "Cueva estrecha. Escucha. Relés en la oscuridad.",
		"brief_beast": "En la cueva el sonido te delata. Acecha.",
		"win_crew": "La cueva queda vacía.",
		"win_beast": "Nadie salió de la oscuridad.",
		"loss_crew": "Os oyeron venir.",
		"loss_beast": "Se os escaparon por un túnel.",
	},
	{
		"id": 8, "name": "Nivel 8 · Bosque", "map": "forest", "time": 145, "cores": 5, "beast_hp": 1.45, "unlock_loadout": 3,
		"tip": "Árboles = cobertura. Sabotea y muévete.",
		"brief_crew": "Cobertura entre árboles. Sabotea y muévete.",
		"brief_beast": "El bosque esconde. Usa el camuflaje si lo tienes.",
		"win_crew": "El bosque calla. Acto II cerrado.",
		"win_beast": "El bosque sigue cazando.",
		"loss_crew": "Os encontraron entre los árboles.",
		"loss_beast": "Se ocultaron demasiado bien.",
	},
	{
		"id": 9, "name": "Nivel 9 · Laberinto", "map": "containers", "time": 135, "cores": 5, "beast_hp": 1.5, "unlock_loadout": 3,
		"tip": "La bestia es más dura: prioriza distancia.",
		"brief_crew": "Bestia más dura. Distancia y núcleos primero.",
		"brief_beast": "Eres más fuerte. No des respiro.",
		"win_crew": "Laberinto resuelto.",
		"win_beast": "El laberinto os cerró.",
		"loss_crew": "Priorizad núcleos, no duelos.",
		"loss_beast": "Os reagruparon. Rompe el grupo.",
	},
	{
		"id": 10, "name": "Nivel 10 · Puente Celeste", "map": "skybridge", "time": 120, "cores": 6, "beast_hp": 1.6, "unlock_loadout": 3,
		"tip": "Puentes estrechos. Cuidado con las zonas violeta.",
		"brief_crew": "Seis núcleos en puentes. No caigas al vacío.",
		"brief_beast": "Empújalos al vacío. Los puentes son tuyos.",
		"win_crew": "Puentes tomados.",
		"win_beast": "Nadie cruzó vivo.",
		"loss_crew": "El vacío os ganó.",
		"loss_beast": "Cruzaron los puentes.",
	},
	{
		"id": 11, "name": "Nivel 11 · Sobrevelocidad", "map": "lab_neon", "time": 110, "cores": 6, "beast_hp": 1.7, "unlock_loadout": 3,
		"tip": "Reloj corto: no pelees de más.",
		"brief_crew": "Sobrevelocidad. Reloj corto. Núcleos, no ego.",
		"brief_beast": "Reloj a tu favor. Retrásalos.",
		"win_crew": "Sobrevelocidad superada.",
		"win_beast": "El reloj os mató.",
		"loss_crew": "Perdisteis tiempo peñando.",
		"loss_beast": "Canalizaron demasiado rápido.",
	},
	{
		"id": 12, "name": "Nivel 12 · Protocolo Final", "map": "castle", "time": 95, "cores": 7, "beast_hp": 1.9, "unlock_loadout": 3,
		"tip": "Último protocolo en el castillo. Gana.",
		"brief_crew": "Protocolo final. Siete núcleos. Todo o nada.",
		"brief_beast": "Última defensa. No dejes caer CHADRINE.",
		"win_crew": "CHADRINE liberado. Final Tripulación.",
		"win_beast": "Protocolo intacto. Final Bestia.",
		"loss_crew": "El protocolo aguantó. Otra vez.",
		"loss_beast": "El castillo cayó. Reclámalo.",
	},
]

var campaign_index := 0  # máximo desbloqueado (0-based)
var selected_level := 0  # nivel que se jugará ahora
var wins_total := 0
var matches_played := 0
var campaign_complete := false
var unlocked_maps: Array = [
	"lab_neon", "containers", "ruins", "reactor_pit",
	"skybridge", "castle", "cave", "forest",
]
var unlocked_loadouts: Array = [0, 1]
var unlocked_beasts: Array = [0, 1]
var last_unlock_message := ""
var campaign_mode := false
var best_score := 0


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	if _read_from(SAVE_PATH):
		return
	if _read_from(BACKUP_PATH):
		push_warning("[progresión] save principal ilegible; restaurado desde el respaldo")
		save_progress()
		return
	_defaults()
	save_progress()


func _read_from(path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	var schema := int(cfg.get_value("meta", "schema_version", 1))
	if schema > SCHEMA_VERSION:
		# Save de una build más nueva: no lo degradamos, arrancamos limpio.
		push_warning("[progresión] save de schema %d (esta build lee %d)" % [schema, SCHEMA_VERSION])
		return false
	campaign_index = int(cfg.get_value("meta", "campaign_index", 0))
	selected_level = int(cfg.get_value("meta", "selected_level", campaign_index))
	wins_total = int(cfg.get_value("meta", "wins_total", 0))
	matches_played = int(cfg.get_value("meta", "matches_played", 0))
	campaign_complete = bool(cfg.get_value("meta", "campaign_complete", false))
	best_score = int(cfg.get_value("meta", "best_score", 0))
	unlocked_maps = _as_array(cfg.get_value("unlock", "maps", all_map_ids()))
	unlocked_loadouts = _as_array(cfg.get_value("unlock", "loadouts", [0, 1]))
	unlocked_beasts = _as_array(cfg.get_value("unlock", "beasts", [0, 1]))
	_migrate(schema)
	_normalize()
	return true


func _as_array(value: Variant) -> Array:
	## Un save corrupto puede traer cualquier cosa; nunca dejamos pasar no-Array.
	if value is Array:
		return (value as Array).duplicate()
	return []


func _migrate(from_schema: int) -> void:
	if from_schema >= SCHEMA_VERSION:
		return
	if from_schema < 2:
		# 1 → 2: los teatros dejaron de ser desbloqueables (ver docs/GDD.md).
		unlocked_maps = all_map_ids()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema_version", SCHEMA_VERSION)
	cfg.set_value("meta", "campaign_index", campaign_index)
	cfg.set_value("meta", "selected_level", selected_level)
	cfg.set_value("meta", "wins_total", wins_total)
	cfg.set_value("meta", "matches_played", matches_played)
	cfg.set_value("meta", "campaign_complete", campaign_complete)
	cfg.set_value("meta", "best_score", best_score)
	cfg.set_value("unlock", "maps", unlocked_maps)
	cfg.set_value("unlock", "loadouts", unlocked_loadouts)
	cfg.set_value("unlock", "beasts", unlocked_beasts)
	# Respaldo del último save bueno antes de sobreescribir: si el proceso muere
	# a mitad de escritura (Web recargando), load_progress() se recupera.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	cfg.save(SAVE_PATH)


func all_map_ids() -> Array:
	return NetworkManager.MAP_IDS.duplicate()


func _defaults() -> void:
	campaign_index = 0
	selected_level = 0
	wins_total = 0
	matches_played = 0
	campaign_complete = false
	best_score = 0
	unlocked_maps = all_map_ids()
	unlocked_loadouts = [0, 1]
	unlocked_beasts = [0, 1]


func _normalize() -> void:
	# Los teatros están todos abiertos por diseño: la progresión vive en niveles
	# de campaña, arsenales y bestias, no en esconder mapas.
	unlocked_maps = all_map_ids()
	if unlocked_loadouts.is_empty():
		unlocked_loadouts = [0]
	if unlocked_beasts.is_empty():
		unlocked_beasts = [GameManager.BeastVariant.CLASSIC]
	campaign_index = clampi(campaign_index, 0, CAMPAIGN.size() - 1)
	selected_level = clampi(selected_level, 0, campaign_index)
	wins_total = maxi(wins_total, 0)
	matches_played = maxi(matches_played, 0)
	best_score = maxi(best_score, 0)


func current_level() -> Dictionary:
	return CAMPAIGN[clampi(selected_level, 0, CAMPAIGN.size() - 1)]


func level_name() -> String:
	return str(current_level().get("name", "Nivel"))


func level_tip() -> String:
	return str(current_level().get("tip", ""))


func level_briefing(role: String) -> String:
	return CampaignScript.briefing(current_level(), role)


func level_outro(role: String, won: bool) -> String:
	return CampaignScript.outro(current_level(), role, won)


func level_act() -> String:
	return CampaignScript.act_for(selected_level)


func is_level_unlocked(idx: int) -> bool:
	return idx >= 0 and idx <= campaign_index


func select_level(idx: int) -> bool:
	if not is_level_unlocked(idx):
		return false
	selected_level = idx
	save_progress()
	progress_changed.emit()
	return true


func is_map_unlocked(map_id: String) -> bool:
	## Todos los teatros del build están siempre disponibles.
	return map_id in NetworkManager.MAP_IDS


func is_loadout_unlocked(loadout: int) -> bool:
	return loadout in unlocked_loadouts


func is_beast_unlocked(variant: int) -> bool:
	return variant in unlocked_beasts


func max_campaign_level() -> int:
	return campaign_index + 1


func total_levels() -> int:
	return CAMPAIGN.size()


func apply_level_rules() -> void:
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
	var mvp := MatchStats.mvp_peer()
	if mvp > 0 and MatchStats.peers.has(mvp):
		var sc := int(MatchStats.peers[mvp]["score"])
		if sc > best_score:
			best_score = sc
	var expected := str(current_level().get("map", "")) if campaign_mode else ""
	var map_ok := expected.is_empty() or map_id == expected
	var local_id := 1
	if multiplayer.has_multiplayer_peer():
		local_id = multiplayer.get_unique_id()
	var robots_won := winner == "explorers"
	var beast_won := winner == "beast"
	if robots_won:
		wins_total += 1
		_unlock_rewards(map_id)
		if campaign_mode:
			if map_ok:
				_advance_campaign()
			else:
				last_unlock_message = "Victoria en práctica — el nivel pide %s" % expected
		AudioDirector.play_ui("unlock")
	elif campaign_mode and beast_won:
		## Voz Bestia: si jugaste Bestia en el teatro del nivel, el nivel cuenta.
		if map_ok and GameManager.is_beast(local_id):
			_advance_campaign()
			last_unlock_message = "Nivel superado como Bestia"
			AudioDirector.play_ui("unlock")
		else:
			last_unlock_message = "La Bestia gana — reintenta el nivel para avanzar"
	save_progress()
	progress_changed.emit()


func _unlock_rewards(_map_id: String) -> void:
	var msgs: PackedStringArray = []
	for lo in range(4):
		if not is_loadout_unlocked(lo) and wins_total >= lo:
			unlocked_loadouts.append(lo)
			msgs.append("Arsenal #%d" % (lo + 1))
	if wins_total >= 2 and not is_beast_unlocked(GameManager.BeastVariant.SHADOW):
		unlocked_beasts.append(GameManager.BeastVariant.SHADOW)
		msgs.append("Bestia: Sombra")
	if not msgs.is_empty():
		last_unlock_message = "Desbloqueado · " + " · ".join(msgs)


func _advance_campaign() -> void:
	# Solo avanza si jugaste el nivel más alto desbloqueado
	if selected_level < campaign_index:
		last_unlock_message = "Nivel completado (replay)"
		return
	if campaign_index < CAMPAIGN.size() - 1:
		campaign_index += 1
		selected_level = campaign_index
		var lv := current_level()
		var ulo: int = int(lv.get("unlock_loadout", 0))
		if not is_loadout_unlocked(ulo):
			unlocked_loadouts.append(ulo)
		last_unlock_message = "¡Nivel %d desbloqueado! %s" % [campaign_index + 1, lv.get("name", "")]
	else:
		campaign_complete = true
		last_unlock_message = "¡Campaña completada! Modo libre al máximo."


func force_campaign_map() -> String:
	return str(current_level().get("map", "lab_neon"))

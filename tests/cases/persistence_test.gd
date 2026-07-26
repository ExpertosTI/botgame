extends "res://tests/test_case.gd"

## Serialización de progreso y ajustes: migración desde saves viejos,
## tolerancia a archivos corruptos y saneado de rangos.

const TMP_V1 := "user://chadrine_test_v1.cfg"
const TMP_FUTURE := "user://chadrine_test_future.cfg"
const TMP_CORRUPT := "user://chadrine_test_corrupt.cfg"

var _snapshot: Dictionary = {}


func suite_name() -> String:
	return "persistence"


func run() -> void:
	_snapshot = _capture()
	_round_trip_keeps_everything()
	_migrates_a_pre_schema_save()
	_rejects_a_future_schema()
	_survives_a_corrupt_payload()
	_settings_clamp_out_of_range_values()
	_restore()
	_cleanup()


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
		"look": SettingsManager.look_sensitivity,
		"master": SettingsManager.master_volume,
		"name": SettingsManager.preferred_name,
	}


func _restore() -> void:
	var p := ProgressionManager
	p.campaign_index = int(_snapshot["campaign_index"])
	p.selected_level = int(_snapshot["selected_level"])
	p.wins_total = int(_snapshot["wins_total"])
	p.matches_played = int(_snapshot["matches_played"])
	p.campaign_complete = bool(_snapshot["campaign_complete"])
	p.best_score = int(_snapshot["best_score"])
	p.unlocked_maps = (_snapshot["maps"] as Array).duplicate()
	p.unlocked_loadouts = (_snapshot["loadouts"] as Array).duplicate()
	p.unlocked_beasts = (_snapshot["beasts"] as Array).duplicate()
	p.save_progress()
	SettingsManager.look_sensitivity = float(_snapshot["look"])
	SettingsManager.master_volume = float(_snapshot["master"])
	SettingsManager.preferred_name = str(_snapshot["name"])
	SettingsManager.save_settings()


func _cleanup() -> void:
	for path in [TMP_V1, TMP_FUTURE, TMP_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _round_trip_keeps_everything() -> void:
	var p := ProgressionManager
	p.campaign_index = 5
	p.selected_level = 4
	p.wins_total = 7
	p.matches_played = 19
	p.best_score = 4321
	p.unlocked_loadouts = [0, 1, 2]
	p.unlocked_beasts = [0, 1, 2]
	p.save_progress()

	p.campaign_index = 0
	p.wins_total = 0
	p.best_score = 0
	p.unlocked_loadouts = []
	p.load_progress()

	eq(p.campaign_index, 5, "campaign_index no sobrevivió al guardado")
	eq(p.selected_level, 4, "selected_level no sobrevivió al guardado")
	eq(p.wins_total, 7, "wins_total no sobrevivió al guardado")
	eq(p.matches_played, 19, "matches_played no sobrevivió al guardado")
	eq(p.best_score, 4321, "best_score no sobrevivió al guardado")
	eq(p.unlocked_loadouts.size(), 3, "los arsenales no sobrevivieron al guardado")
	ok(FileAccess.file_exists(p.BACKUP_PATH), "guardar debe dejar un respaldo del save previo")


func _migrates_a_pre_schema_save() -> void:
	## Save de 1.3.x: sin schema_version y con un solo teatro abierto.
	var old := ConfigFile.new()
	old.set_value("meta", "campaign_index", 3)
	old.set_value("meta", "selected_level", 3)
	old.set_value("meta", "wins_total", 4)
	old.set_value("unlock", "maps", ["lab_neon"])
	old.set_value("unlock", "loadouts", [0, 1])
	old.set_value("unlock", "beasts", [0])
	old.save(TMP_V1)

	var p := ProgressionManager
	ok(p._read_from(TMP_V1), "un save sin schema_version debe poder leerse")
	eq(p.campaign_index, 3, "la migración perdió el avance de campaña")
	eq(
		p.unlocked_maps.size(), NetworkManager.MAP_IDS.size(),
		"la migración debe abrir todos los teatros del build"
	)
	eq(p.unlocked_beasts.size(), 1, "la migración no debe regalar bestias")


func _rejects_a_future_schema() -> void:
	var future := ConfigFile.new()
	future.set_value("meta", "schema_version", ProgressionManager.SCHEMA_VERSION + 5)
	future.set_value("meta", "campaign_index", 11)
	future.save(TMP_FUTURE)
	ok(
		not ProgressionManager._read_from(TMP_FUTURE),
		"un save de una build futura no debe cargarse a medias"
	)


func _survives_a_corrupt_payload() -> void:
	var bad := ConfigFile.new()
	bad.set_value("meta", "schema_version", ProgressionManager.SCHEMA_VERSION)
	bad.set_value("meta", "campaign_index", 999)
	bad.set_value("meta", "selected_level", -40)
	bad.set_value("meta", "wins_total", -3)
	bad.set_value("unlock", "loadouts", "esto no es un array")
	bad.set_value("unlock", "beasts", 7)
	bad.save(TMP_CORRUPT)

	var p := ProgressionManager
	ok(p._read_from(TMP_CORRUPT), "un save con basura debe cargarse saneado, no reventar")
	eq(p.campaign_index, p.CAMPAIGN.size() - 1, "campaign_index debe recortarse al último nivel")
	in_range(float(p.selected_level), 0.0, float(p.campaign_index), "selected_level fuera de rango")
	eq(p.wins_total, 0, "wins_total negativo debe saneársele")
	ok(p.unlocked_loadouts is Array, "loadouts debe quedar como Array")
	ok(not p.unlocked_loadouts.is_empty(), "siempre debe quedar un arsenal jugable")
	ok(not p.unlocked_beasts.is_empty(), "siempre debe quedar una bestia jugable")


func _settings_clamp_out_of_range_values() -> void:
	var s := SettingsManager
	s.look_sensitivity = 99.0
	s.master_volume = -5.0
	s.preferred_name = "   " 
	s.save_settings()
	in_range(s.look_sensitivity, 0.4, 2.0, "la sensibilidad debe recortarse")
	in_range(s.master_volume, 0.0, 1.0, "el volumen debe recortarse")
	neq(s.preferred_name, "", "un nombre vacío debe caer al valor por defecto")

	s.preferred_name = "NombreExageradamenteLargoQueRompeElHUD"
	s.save_settings()
	ok(
		s.preferred_name.length() <= s.NAME_MAX_LEN,
		"el nombre debe recortarse a %d caracteres" % s.NAME_MAX_LEN
	)

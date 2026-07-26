extends Node

## Ajustes persistentes (sensibilidad, audio, tutorial).

signal settings_changed

const SAVE_PATH := "user://botgame_settings.cfg"
const SCHEMA_VERSION := 2
const NAME_MAX_LEN := 16

var master_volume := 1.0
var sfx_volume := 1.0
var music_volume := 0.7
var muted := false
var look_sensitivity := 1.0
var tutorial_seen := false
## Primera partida guiada (pasos MOVE→FIRE→CORE). Distinto del panel de reglas.
var match_tutorial_done := false
var preferred_name := "Robot"


func _ready() -> void:
	load_settings()
	_apply_audio()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if int(cfg.get_value("meta", "schema_version", 1)) > SCHEMA_VERSION:
		push_warning("[ajustes] archivo de una build más nueva; se usan valores por defecto")
		return
	master_volume = float(cfg.get_value("audio", "master", 1.0))
	sfx_volume = float(cfg.get_value("audio", "sfx", 1.0))
	music_volume = float(cfg.get_value("audio", "music", 0.7))
	muted = bool(cfg.get_value("audio", "muted", false))
	look_sensitivity = float(cfg.get_value("input", "look_sensitivity", 1.0))
	tutorial_seen = bool(cfg.get_value("meta", "tutorial_seen", false))
	match_tutorial_done = bool(cfg.get_value("meta", "match_tutorial_done", false))
	preferred_name = str(cfg.get_value("meta", "preferred_name", "Robot"))
	_clamp_values()


func _clamp_values() -> void:
	## Un archivo editado a mano no debe poder romper el audio ni la cámara.
	master_volume = clampf(master_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	look_sensitivity = clampf(look_sensitivity, 0.4, 2.0)
	preferred_name = preferred_name.strip_edges().substr(0, NAME_MAX_LEN)
	if preferred_name.is_empty():
		preferred_name = "Robot"


func save_settings() -> void:
	_clamp_values()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema_version", SCHEMA_VERSION)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("input", "look_sensitivity", look_sensitivity)
	cfg.set_value("meta", "tutorial_seen", tutorial_seen)
	cfg.set_value("meta", "match_tutorial_done", match_tutorial_done)
	cfg.set_value("meta", "preferred_name", preferred_name)
	cfg.save(SAVE_PATH)
	_apply_audio()
	settings_changed.emit()


func set_muted(on: bool) -> void:
	muted = on
	save_settings()


func toggle_mute() -> void:
	set_muted(not muted)


func set_look_sensitivity(v: float) -> void:
	look_sensitivity = clampf(v, 0.4, 2.0)
	save_settings()


func mark_tutorial_seen() -> void:
	tutorial_seen = true
	save_settings()


func mark_match_tutorial_done() -> void:
	match_tutorial_done = true
	save_settings()


func _apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	if muted:
		AudioServer.set_bus_mute(master, true)
	else:
		AudioServer.set_bus_mute(master, false)
		AudioServer.set_bus_volume_db(master, linear_to_db(clampf(master_volume, 0.001, 1.0)))

extends "res://tests/test_case.gd"

## Muestras de sonido reales.
##
## Hasta ahora todo el audio eran ondas sintetizadas: el juego sonaba a
## calculadora y era lo primero que lo delataba como boceto. Ahora hay muestras
## CC0 en `assets/audio`. Lo que estos casos protegen es la parte frágil del
## cambio: que los archivos estén donde el código los busca, que entren en el
## export, y que si alguno falta el juego siga sonando en vez de quedarse mudo.

const AUDIO_DIR := "res://assets/audio"


func suite_name() -> String:
	return "audio_samples"


func run() -> void:
	_every_declared_sample_exists_on_disk()
	_the_sounds_the_game_asks_for_are_declared()
	_audio_is_not_excluded_from_the_export()
	_a_missing_sample_falls_back_instead_of_going_silent()
	_muted_plays_nothing()
	_credits_name_the_source()


func _every_declared_sample_exists_on_disk() -> void:
	## Se comprueba el archivo, no el recurso importado: en un entorno headless
	## sin pasada de importación no hay .import, y aun así el archivo debe estar.
	for key in AudioDirector.SAMPLES:
		var path := str(AudioDirector.SAMPLES[key])
		ok(FileAccess.file_exists(path), "falta la muestra '%s' en %s" % [key, path])


func _the_sounds_the_game_asks_for_are_declared() -> void:
	## Si alguien renombra una clave en el diccionario pero no en quien la pide,
	## el fallo es silencioso: se cae al respaldo procedural y nadie se entera
	## hasta que el juego vuelve a sonar a pitidos.
	var used := [
		"shot_robot",
		"shot_beast",
		"hurt",
		"hit_confirm",
		"death",
		"explosion",
		"ability",
		"core_tick",
		"core_down",
		"step",
		"land",
		"jump_a",
		"jump_b",
		"jump_c",
		"ui_click",
		"ui_confirm",
		"ui_error",
		"ui_unlock",
		"ambience",
	]
	for key in used:
		ok(AudioDirector.SAMPLES.has(key), "el código pide la muestra '%s' y no está declarada" % key)


func _audio_is_not_excluded_from_the_export() -> void:
	## El sonido vivía en `modes/`, que está excluido del export: si se hubiera
	## referenciado allí en vez de copiarlo, el juego publicado saldría mudo.
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	ok(not cfg.is_empty(), "no se pudo leer export_presets.cfg")
	for line in cfg.split("\n"):
		if not line.begins_with("exclude_filter"):
			continue
		ok(
			not line.contains("assets/audio"),
			"el export excluye assets/audio; el juego publicado se quedaría sin sonido"
		)
	for key in AudioDirector.SAMPLES:
		var path := str(AudioDirector.SAMPLES[key])
		ok(path.begins_with(AUDIO_DIR), "la muestra '%s' apunta fuera de assets/audio: %s" % [key, path])


func _a_missing_sample_falls_back_instead_of_going_silent() -> void:
	var saved: Dictionary = AudioDirector._samples.duplicate()
	var was_muted: bool = SettingsManager.muted
	SettingsManager.muted = false
	for key in AudioDirector.SAMPLES:
		AudioDirector._samples[key] = null
	AudioDirector._stream_cache.clear()
	AudioDirector.play_shot(false)
	AudioDirector.play_hit()
	AudioDirector.play_ui("confirm")
	ok(
		int(AudioDirector.cache_stats()["streams"]) > 0,
		"sin muestras, el respaldo procedural debería haber horneado algo"
	)
	AudioDirector._samples = saved
	SettingsManager.muted = was_muted


func _muted_plays_nothing() -> void:
	var saved: Dictionary = AudioDirector._samples.duplicate()
	var was_muted: bool = SettingsManager.muted
	SettingsManager.muted = true
	for key in AudioDirector.SAMPLES:
		AudioDirector._samples[key] = null
	AudioDirector._stream_cache.clear()
	AudioDirector.play_shot(true)
	AudioDirector.play_ui("click")
	eq(
		int(AudioDirector.cache_stats()["streams"]),
		0,
		"silenciado no debería sintetizarse nada: es trabajo de CPU que nadie oye"
	)
	AudioDirector._samples = saved
	SettingsManager.muted = was_muted


func _credits_name_the_source() -> void:
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	ok(credits.contains("assets/audio"), "los créditos deben documentar el origen del sonido")
	ok(credits.contains("Kenney"), "las muestras son de Kenney y hay que citarlo")

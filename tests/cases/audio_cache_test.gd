extends "res://tests/test_case.gd"

## Caché del audio procedural de respaldo.
##
## El juego suena con muestras reales, pero lo sintetizado sigue ahí para cuando
## una muestra no llegó al export. Esa ruta se sigue pagando en CPU: sin caché,
## cada disparo horneaba un AudioStreamWAV nuevo muestra a muestra en GDScript, y
## con cinco jugadores disparando eso es trabajo por frame que en WebAssembly se
## paga caro. Estos casos fijan que se reutilicen.


func suite_name() -> String:
	return "audio_cache"


func run() -> void:
	var was_muted: bool = SettingsManager.muted
	var saved_samples: Dictionary = AudioDirector._samples.duplicate()
	# Silenciado no se sintetiza nada, así que la caché no se llenaría.
	SettingsManager.muted = false
	_force_procedural()
	_identical_tones_are_reused()
	_nearby_frequencies_collapse()
	_shots_do_not_grow_the_cache_forever()
	_noise_keeps_some_variety()
	_delayed_beeps_do_not_leak_timers()
	AudioDirector._samples = saved_samples
	SettingsManager.muted = was_muted


## Marca todas las muestras como ausentes. Esta suite mide el respaldo, y si
## dependiera de si los .ogg están importados en la máquina que ejecuta los
## tests, pasaría o fallaría por motivos ajenos a lo que quiere comprobar.
func _force_procedural() -> void:
	for key in AudioDirector.SAMPLES:
		AudioDirector._samples[key] = null


func _identical_tones_are_reused() -> void:
	var a: AudioStreamWAV = AudioDirector._make_tone(440.0, 0.05, 0.2, false)
	var b: AudioStreamWAV = AudioDirector._make_tone(440.0, 0.05, 0.2, false)
	ok(a != null, "el generador de tonos no devolvió nada")
	ok(a == b, "dos tonos idénticos deben ser el mismo recurso, no dos copias")
	var loop: AudioStreamWAV = AudioDirector._make_tone(440.0, 0.05, 0.2, true)
	ok(loop != a, "el tono en bucle es otro recurso: lleva loop_mode distinto")
	eq(loop.loop_mode, AudioStreamWAV.LOOP_FORWARD, "el tono de música debe ir en bucle")


func _nearby_frequencies_collapse() -> void:
	## play_shot() sortea la frecuencia en un rango continuo: sin cuantizar, cada
	## disparo sería una clave nueva y la caché no serviría para nada.
	var a: AudioStreamWAV = AudioDirector._make_tone(1000.0, 0.035, 0.16, false)
	var b: AudioStreamWAV = AudioDirector._make_tone(1004.0, 0.035, 0.16, false)
	ok(a == b, "frecuencias a menos de un paso de cuantización deben compartir WAV")
	var far: AudioStreamWAV = AudioDirector._make_tone(1200.0, 0.035, 0.16, false)
	ok(far != a, "frecuencias claramente distintas no deben colapsar en el mismo WAV")


func _shots_do_not_grow_the_cache_forever() -> void:
	for i in 400:
		AudioDirector.play_shot(i % 2 == 0)
	for i in 40:
		AudioDirector.play_hit()
		AudioDirector.play_explosion()
	var streams: int = int(AudioDirector.cache_stats()["streams"])
	ok(
		streams <= AudioDirector.MAX_CACHED_STREAMS,
		"la caché de audio (%d) pasó su techo (%d)" % [streams, AudioDirector.MAX_CACHED_STREAMS]
	)
	# 440 llamadas y un puñado de WAV: eso es lo que buscábamos.
	ok(streams < 60, "480 sonidos no deberían dejar %d WAV distintos en memoria" % streams)


func _noise_keeps_some_variety() -> void:
	## Un solo WAV de impacto para toda la partida suena a error de software, así
	## que el ruido conserva varias versiones horneadas.
	var seen: Array = []
	for i in 60:
		var s: AudioStreamWAV = AudioDirector._make_noise(0.04, 0.2, 140.0, 0.45)
		if not seen.has(s):
			seen.append(s)
	ok(seen.size() > 1, "el ruido de impacto quedó reducido a un único sonido")
	ok(
		seen.size() <= AudioDirector.NOISE_VARIANTS,
		"hay %d variantes de ruido y el máximo declarado es %d" % [seen.size(), AudioDirector.NOISE_VARIANTS]
	)


func _delayed_beeps_do_not_leak_timers() -> void:
	## Los bips diferidos se resuelven en _process con una cola propia; antes cada
	## uno creaba un Timer y una lambda, y una explosión encadena tres.
	AudioDirector._pending.clear()
	AudioDirector.play_explosion()
	ok(int(AudioDirector.cache_stats()["pending"]) > 0, "el bip diferido debe quedar en cola")
	AudioDirector._process(1.0)
	eq(int(AudioDirector.cache_stats()["pending"]), 0, "la cola de bips diferidos debe vaciarse")

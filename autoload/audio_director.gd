extends Node

## Audio del juego: muestras reales con respaldo procedural.
##
## Durante mucho tiempo todo el sonido eran ondas sintetizadas aquí mismo, y el
## juego sonaba a calculadora. Ahora hay muestras CC0 (Kenney, MIT) en
## `assets/audio`. Lo procedural sigue vivo a propósito, como red: si una
## muestra no llegó a importarse en el export, se oye el bip de siempre en vez
## de silencio, que es mucho peor de diagnosticar.

enum BusKind { SFX, MUSIC, UI }

## Cada entrada es la muestra que sustituye a un sonido antes sintetizado. La
## clave es el nombre lógico que usa el juego, no el del archivo original.
const SAMPLES := {
	"shot_robot": "res://assets/audio/sfx/shot_robot.ogg",
	"shot_robot_fast": "res://assets/audio/sfx/shot_robot_fast.ogg",
	"shot_beast": "res://assets/audio/sfx/shot_beast.ogg",
	"hurt": "res://assets/audio/sfx/hurt.ogg",
	"hit_confirm": "res://assets/audio/sfx/hit_confirm.ogg",
	"death": "res://assets/audio/sfx/death.ogg",
	"explosion": "res://assets/audio/sfx/explosion.ogg",
	"ability": "res://assets/audio/sfx/ability.ogg",
	"jump_a": "res://assets/audio/sfx/jump_a.ogg",
	"jump_b": "res://assets/audio/sfx/jump_b.ogg",
	"jump_c": "res://assets/audio/sfx/jump_c.ogg",
	"land": "res://assets/audio/sfx/land.ogg",
	"step": "res://assets/audio/sfx/step.ogg",
	"fall": "res://assets/audio/sfx/fall.ogg",
	"ui_click": "res://assets/audio/sfx/ui_click.ogg",
	"ui_confirm": "res://assets/audio/sfx/ui_confirm.ogg",
	"ui_error": "res://assets/audio/sfx/ui_error.ogg",
	"ui_unlock": "res://assets/audio/sfx/ui_unlock.ogg",
	"core_tick": "res://assets/audio/sfx/core_tick.ogg",
	"core_down": "res://assets/audio/sfx/core_down.ogg",
	"ambience": "res://assets/audio/music/ambience.ogg",
}

## Un disparo repetido con la misma muestra exacta suena a bucle de metralleta
## de juguete; variar el tono lo suficiente para notarlo, pero no tanto como
## para que parezca otra arma.
const PITCH_JITTER := 0.07

## Los WAV se hornean una vez y se reutilizan. Antes cada disparo construía un
## AudioStreamWAV nuevo llenando el buffer muestra a muestra en GDScript (~770
## iteraciones por bip, ~4000 por explosión); con cinco jugadores disparando eso
## era trabajo de CPU y basura de recursos constante, y en WebAssembly se nota.
const TONE_HZ_STEP := 25.0
## El ruido sí necesita variedad (si no, todos los impactos suenan idénticos), así
## que se hornean unas pocas versiones y se sortea entre ellas.
const NOISE_VARIANTS := 4
const MAX_CACHED_STREAMS := 64

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
## Los pasos tienen reproductor propio porque son un bucle que vive mientras el
## jugador anda; con los compartidos, cualquier disparo lo habría cortado.
var _steps: AudioStreamPlayer
var _stream_cache: Dictionary = {}
## Muestras ya resueltas. Guarda también los fallos (como null) para no repetir
## el intento de carga en cada disparo cuando un archivo no está.
var _samples: Dictionary = {}
## Bips diferidos. Antes cada uno creaba un Timer y una lambda por llamada; una
## explosión o una victoria encadenan tres.
var _pending: Array[Dictionary] = []


func _ready() -> void:
	## Nunca AudioServer.add_bus: en Godot 4.6 web release → OOB (godot#115560).
	## Layout = solo Master (default_bus_layout.tres).
	var web := WebSafe.is_web()
	## Web: diferir players hasta el primer sonido (menos alloc al boot).
	if web:
		SettingsManager.settings_changed.connect(_on_settings)
		_on_settings()
		return
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.max_polyphony = 1
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	add_child(_music)
	_steps = AudioStreamPlayer.new()
	_steps.bus = "Master"
	_steps.volume_db = -14.0
	add_child(_steps)
	SettingsManager.settings_changed.connect(_on_settings)
	_on_settings()


func _ensure_web_players() -> void:
	if not WebSafe.is_web():
		return
	while _players.size() < 4:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.max_polyphony = 1
		add_child(p)
		_players.append(p)
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.bus = "Master"
		add_child(_music)
	if _steps == null:
		_steps = AudioStreamPlayer.new()
		_steps.bus = "Master"
		_steps.volume_db = -14.0
		add_child(_steps)


func _web_bus(_logical: String) -> String:
	## Todos los buses lógicos → Master (layout sin SFX/Music/UI).
	return "Master"


func _on_settings() -> void:
	var mute := SettingsManager.muted
	var master_lin := clampf(SettingsManager.master_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(0, mute)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master_lin, 0.001, 1.0)))
	if _music != null and is_instance_valid(_music):
		_music.volume_db = linear_to_db(clampf(SettingsManager.music_volume * 0.55, 0.001, 1.0)) - 6.0


func play_ui(kind: String = "click") -> void:
	match kind:
		"confirm":
			if _play_sample("ui_confirm", "UI", -4.0):
				return
			_beep(720.0, 0.07, 0.22, "UI")
			_beep(980.0, 0.09, 0.18, "UI", 0.05)
		"error":
			if _play_sample("ui_error", "UI", -3.0):
				return
			_beep(180.0, 0.14, 0.28, "UI")
		"unlock":
			if _play_sample("ui_unlock", "UI", -3.0):
				return
			_beep(520.0, 0.06, 0.2, "UI")
			_beep(780.0, 0.08, 0.18, "UI", 0.06)
			_beep(1040.0, 0.12, 0.16, "UI", 0.12)
		_:
			if _play_sample("ui_click", "UI", -6.0):
				return
			_beep(440.0, 0.045, 0.18, "UI")


func play_shot(beast: bool = false, fast: bool = false) -> void:
	if beast:
		if _play_sample("shot_beast", "SFX", -3.0):
			return
		_noise_burst(0.05, 0.22, 90.0, 0.35)
	elif fast:
		if _play_sample("shot_robot_fast", "SFX", -5.0):
			return
		_beep(randf_range(1100.0, 1700.0), 0.025, 0.14, "SFX")
	else:
		if _play_sample("shot_robot", "SFX", -5.0):
			return
		_beep(randf_range(880.0, 1400.0), 0.035, 0.16, "SFX")


func play_hit() -> void:
	if _play_sample("hurt", "SFX", -2.0):
		return
	_noise_burst(0.04, 0.2, 140.0, 0.45)


## Lo oye quien acierta, no quien recibe. Tiene que ser distinto de play_shot():
## antes disparar y acertar sonaban igual, así que en un tiroteo no había forma
## de saber si le estabas dando a algo.
func play_hit_confirm() -> void:
	if _play_sample("hit_confirm", "UI", -4.0):
		return
	_beep(1500.0, 0.045, 0.14, "UI")


func play_explosion() -> void:
	if _play_sample("explosion", "SFX", 0.0):
		return
	_noise_burst(0.18, 0.35, 60.0, 0.7)
	_beep(90.0, 0.12, 0.25, "SFX", 0.02)


func play_ability() -> void:
	if _play_sample("ability", "SFX", -4.0):
		return
	_beep(360.0, 0.08, 0.2, "SFX")
	_beep(540.0, 0.1, 0.16, "SFX", 0.05)


## Un golpe de sabotaje sobre un núcleo.
func play_core() -> void:
	if _play_sample("core_tick", "SFX", -4.0):
		return
	_beep(300.0, 0.1, 0.22, "SFX")
	_beep(600.0, 0.14, 0.18, "SFX", 0.08)


## Núcleo caído: tiene que oírse desde el otro extremo del mapa, es la señal de
## que la partida acaba de moverse.
func play_core_down() -> void:
	if _play_sample("core_down", "SFX", 1.0):
		return
	play_explosion()


func play_death() -> void:
	if _play_sample("death", "SFX", -2.0):
		return
	_beep(220.0, 0.16, 0.28, "SFX")
	_beep(110.0, 0.22, 0.3, "SFX", 0.1)


## El cuerpo en movimiento: pasos, salto y aterrizaje. Sin esto el personaje se
## desplazaba en silencio absoluto y la escena parecía una maqueta.
##
## La muestra de pasos es un bucle continuo, no una pisada suelta, así que se
## enciende y se apaga con el movimiento en vez de dispararse por zancada.
func set_walking(active: bool, sprinting: bool = false) -> void:
	_ensure_web_players()
	if _steps == null:
		return
	if not active or SettingsManager.muted:
		if _steps.playing:
			_steps.stop()
		return
	_steps.pitch_scale = 1.35 if sprinting else 1.0
	if _steps.playing:
		return
	var stream := _sample("step")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_steps.stream = stream
	_steps.play()


func play_jump() -> void:
	var variants := ["jump_a", "jump_b", "jump_c"]
	_play_sample(variants[randi() % variants.size()], "SFX", -10.0)


func play_land() -> void:
	_play_sample("land", "SFX", -10.0)


func play_fall() -> void:
	if _play_sample("fall", "SFX", -6.0):
		return
	_noise_burst(0.12, 0.18, 40.0, 0.25)


func play_win(robots: bool) -> void:
	if robots:
		_beep(523.0, 0.1, 0.2, "SFX")
		_beep(659.0, 0.1, 0.2, "SFX", 0.1)
		_beep(784.0, 0.18, 0.22, "SFX", 0.2)
	else:
		_beep(392.0, 0.12, 0.24, "SFX")
		_beep(311.0, 0.16, 0.26, "SFX", 0.12)
		_beep(196.0, 0.22, 0.3, "SFX", 0.24)


func start_menu_music() -> void:
	if _start_loop_sample("ambience", -6.0):
		return
	_start_loop_tone(196.0, 0.04)


func start_match_music() -> void:
	## Más grave y más bajo que en el menú: durante la partida el ambiente tiene
	## que dejar sitio a los disparos, que son la información útil.
	if _start_loop_sample("ambience", -11.0, 0.85):
		return
	_start_loop_tone(110.0, 0.055)


func stop_music() -> void:
	if _music:
		_music.stop()


## Devuelve la muestra pedida, o null si no existe. El resultado se recuerda en
## los dos casos: sin memorizar los fallos, cada disparo volvería a preguntar al
## sistema de archivos por un recurso que ya sabemos que no está.
func _sample(key: String) -> AudioStream:
	if _samples.has(key):
		return _samples[key] as AudioStream
	var path := str(SAMPLES.get(key, ""))
	var res: AudioStream = null
	if not path.is_empty() and ResourceLoader.exists(path):
		res = load(path) as AudioStream
	_samples[key] = res
	return res


func _play_sample(key: String, bus: String, volume_db: float = 0.0, jitter: bool = true) -> bool:
	if SettingsManager.muted:
		# Devuelve true para que quien llama no caiga al respaldo procedural, que
		# también está silenciado: sin esto se hacía el trabajo dos veces.
		return true
	var stream := _sample(key)
	if stream == null:
		return false
	var p := _free_player()
	if p == null:
		return false
	p.bus = _web_bus(bus)
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER) if jitter else 1.0
	p.play()
	return true


func _start_loop_sample(key: String, volume_db: float, pitch: float = 1.0) -> bool:
	if SettingsManager.muted:
		return true
	_ensure_web_players()
	if _music == null:
		return false
	var stream := _sample(key)
	if stream == null:
		return false
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.volume_db = volume_db
	_music.pitch_scale = pitch
	_music.play()
	return true


func _start_loop_tone(hz: float, amp: float) -> void:
	if SettingsManager.muted:
		return
	_ensure_web_players()
	if _music == null:
		return
	var stream := _make_tone(hz, 1.2, amp, true)
	_music.stream = stream
	_music.volume_db = 0.0
	_music.pitch_scale = 1.0
	_music.play()


func _beep(hz: float, dur: float, amp: float, bus: String, delay: float = 0.0) -> void:
	if SettingsManager.muted:
		return
	if delay > 0.0:
		_pending.append({"t": delay, "hz": hz, "dur": dur, "amp": amp, "bus": bus})
		return
	var p := _free_player()
	if p == null:
		return
	p.bus = _web_bus(bus)
	# Los reproductores son compartidos y las muestras los dejan con su propio
	# volumen y tono; sin reponerlos, un bip heredaría el ajuste del disparo
	# anterior.
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	p.stream = _make_tone(hz, dur, amp, false)
	p.play()


func _process(delta: float) -> void:
	if _pending.is_empty():
		return
	var i := _pending.size() - 1
	while i >= 0:
		var job: Dictionary = _pending[i]
		job["t"] = float(job["t"]) - delta
		if float(job["t"]) <= 0.0:
			_pending.remove_at(i)
			_beep(float(job["hz"]), float(job["dur"]), float(job["amp"]), str(job["bus"]), 0.0)
		i -= 1


func _noise_burst(dur: float, amp: float, base_hz: float, grit: float) -> void:
	if SettingsManager.muted:
		return
	var p := _free_player()
	if p == null:
		return
	p.bus = _web_bus("SFX")
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	p.stream = _make_noise(dur, amp, base_hz, grit)
	p.play()


func _free_player() -> AudioStreamPlayer:
	_ensure_web_players()
	for p in _players:
		if not p.playing:
			return p
	return _players[0] if not _players.is_empty() else null


## Reutiliza el WAV si ya existe uno equivalente. La frecuencia se cuantiza porque
## play_shot() la sortea en un rango continuo: sin esto, cada disparo sería una
## clave distinta y la caché no serviría de nada.
func _make_tone(hz: float, dur: float, amp: float, loop: bool) -> AudioStreamWAV:
	var q_hz := roundf(hz / TONE_HZ_STEP) * TONE_HZ_STEP
	var key := "t|%.0f|%.3f|%.3f|%d" % [q_hz, dur, amp, 1 if loop else 0]
	var cached: AudioStreamWAV = _stream_cache.get(key)
	if cached != null:
		return cached
	var baked := _bake_tone(q_hz, dur, amp, loop)
	_store(key, baked)
	return baked


func _make_noise(dur: float, amp: float, base_hz: float, grit: float) -> AudioStreamWAV:
	var variant := randi() % NOISE_VARIANTS
	var key := "n|%.3f|%.3f|%.0f|%.2f|%d" % [dur, amp, base_hz, grit, variant]
	var cached: AudioStreamWAV = _stream_cache.get(key)
	if cached != null:
		return cached
	var baked := _bake_noise(dur, amp, base_hz, grit)
	_store(key, baked)
	return baked


func _store(key: String, stream: AudioStreamWAV) -> void:
	# El juego usa un puñado de sonidos fijos, así que el techo no debería llegar a
	# tocarse; está para que un parámetro inesperado no convierta la caché en una
	# fuga de memoria silenciosa.
	if _stream_cache.size() >= MAX_CACHED_STREAMS:
		_stream_cache.clear()
	_stream_cache[key] = stream


func cache_stats() -> Dictionary:
	var missing := 0
	for key in _samples:
		if _samples[key] == null:
			missing += 1
	return {
		"streams": _stream_cache.size(),
		"pending": _pending.size(),
		"samples": _samples.size() - missing,
		"samples_missing": missing,
	}


func _bake_tone(hz: float, dur: float, amp: float, loop: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := 1.0
		if not loop:
			var attack := mini(0.012, dur * 0.2)
			var release := mini(0.05, dur * 0.35)
			if t < attack:
				env = t / attack
			elif t > dur - release:
				env = maxf((dur - t) / release, 0.0)
		var sample := sin(TAU * hz * t) * amp * env
		# Soft clip
		sample = clampf(sample, -1.0, 1.0)
		var s16 := int(sample * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = n
	return stream


func _bake_noise(dur: float, amp: float, base_hz: float, grit: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var env := 1.0 - (t / dur)
		env *= env
		phase += TAU * (base_hz + randf_range(-40.0, 40.0)) / float(rate)
		var sample := (sin(phase) * (1.0 - grit) + (randf() * 2.0 - 1.0) * grit) * amp * env
		sample = clampf(sample, -1.0, 1.0)
		var s16 := int(sample * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

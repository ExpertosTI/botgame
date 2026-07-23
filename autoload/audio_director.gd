extends Node

## Audio procedural (sin assets): UI, combate, ambiente.

enum BusKind { SFX, MUSIC, UI }

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_phase := 0.0
var _match_music := false


func _ready() -> void:
	_ensure_buses()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.max_polyphony = 1
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	SettingsManager.settings_changed.connect(_on_settings)
	_on_settings()


func _ensure_buses() -> void:
	_add_bus_if_missing("SFX")
	_add_bus_if_missing("Music")
	_add_bus_if_missing("UI")


func _add_bus_if_missing(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _on_settings() -> void:
	var sfx_i := AudioServer.get_bus_index("SFX")
	var mus_i := AudioServer.get_bus_index("Music")
	var ui_i := AudioServer.get_bus_index("UI")
	var mute := SettingsManager.muted
	var master_lin := clampf(SettingsManager.master_volume, 0.0, 1.0)
	if sfx_i >= 0:
		AudioServer.set_bus_mute(sfx_i, mute)
		AudioServer.set_bus_volume_db(sfx_i, linear_to_db(clampf(SettingsManager.sfx_volume * master_lin, 0.001, 1.0)))
	if mus_i >= 0:
		AudioServer.set_bus_mute(mus_i, mute)
		AudioServer.set_bus_volume_db(mus_i, linear_to_db(clampf(SettingsManager.music_volume * master_lin * 0.55, 0.001, 1.0)))
	if ui_i >= 0:
		AudioServer.set_bus_mute(ui_i, mute)
		AudioServer.set_bus_volume_db(ui_i, linear_to_db(clampf(SettingsManager.sfx_volume * master_lin, 0.001, 1.0)))


func play_ui(kind: String = "click") -> void:
	match kind:
		"confirm":
			_beep(720.0, 0.07, 0.22, "UI")
			_beep(980.0, 0.09, 0.18, "UI", 0.05)
		"error":
			_beep(180.0, 0.14, 0.28, "UI")
		"unlock":
			_beep(520.0, 0.06, 0.2, "UI")
			_beep(780.0, 0.08, 0.18, "UI", 0.06)
			_beep(1040.0, 0.12, 0.16, "UI", 0.12)
		_:
			_beep(440.0, 0.045, 0.18, "UI")


func play_shot(beast: bool = false) -> void:
	if beast:
		_noise_burst(0.05, 0.22, 90.0, 0.35)
	else:
		_beep(randf_range(880.0, 1400.0), 0.035, 0.16, "SFX")


func play_hit() -> void:
	_noise_burst(0.04, 0.2, 140.0, 0.45)


func play_explosion() -> void:
	_noise_burst(0.18, 0.35, 60.0, 0.7)
	_beep(90.0, 0.12, 0.25, "SFX", 0.02)


func play_ability() -> void:
	_beep(360.0, 0.08, 0.2, "SFX")
	_beep(540.0, 0.1, 0.16, "SFX", 0.05)


func play_core() -> void:
	_beep(300.0, 0.1, 0.22, "SFX")
	_beep(600.0, 0.14, 0.18, "SFX", 0.08)


func play_death() -> void:
	_beep(220.0, 0.16, 0.28, "SFX")
	_beep(110.0, 0.22, 0.3, "SFX", 0.1)


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
	_match_music = false
	_start_loop_tone(196.0, 0.04)


func start_match_music() -> void:
	_match_music = true
	_start_loop_tone(110.0, 0.055)


func stop_music() -> void:
	if _music:
		_music.stop()


func _start_loop_tone(hz: float, amp: float) -> void:
	if SettingsManager.muted:
		return
	var stream := _make_tone(hz, 1.2, amp, true)
	_music.stream = stream
	_music.play()


func _beep(hz: float, dur: float, amp: float, bus: String, delay: float = 0.0) -> void:
	if SettingsManager.muted:
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(func(): _beep(hz, dur, amp, bus, 0.0))
		return
	var p := _free_player()
	if p == null:
		return
	p.bus = bus
	p.stream = _make_tone(hz, dur, amp, false)
	p.play()


func _noise_burst(dur: float, amp: float, base_hz: float, grit: float) -> void:
	if SettingsManager.muted:
		return
	var p := _free_player()
	if p == null:
		return
	p.bus = "SFX"
	p.stream = _make_noise(dur, amp, base_hz, grit)
	p.play()


func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0] if not _players.is_empty() else null


func _make_tone(hz: float, dur: float, amp: float, loop: bool) -> AudioStreamWAV:
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


func _make_noise(dur: float, amp: float, base_hz: float, grit: float) -> AudioStreamWAV:
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

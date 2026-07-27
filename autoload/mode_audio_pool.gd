extends Node

## Autoload `Audio` de los submodos (platformer, FPS, city builder).
##
## Los tres venían de proyectos Kenney distintos, cada uno con su propio
## autoload `Audio`, y al fusionarlos en CHADRINE ninguno quedó registrado: todos
## sus scripts fallaban con «Identifier "Audio" not declared». Esta es la versión
## única, y además respeta el mute y el volumen de SettingsManager, que los
## originales ignoraban.
##
## Vive en autoload/ y no en modes/ a propósito: el export excluye `modes/*`, así
## que un autoload alojado ahí no viajaría en el PCK y la build de producción
## moriría al arrancar aunque en local todo pase. Lo vigila
## tests/cases/export_contract_test.gd.

const NUM_PLAYERS := 12
const WEB_NUM_PLAYERS := 4
const DEFAULT_DB := -10.0

var _available: Array[AudioStreamPlayer] = []
var _queue: Array[Dictionary] = []
var _booted := false


func _ready() -> void:
	## Web: no alloc al boot — se crean en el primer play().
	if WebSafe.is_web():
		return
	_boot_players(NUM_PLAYERS)


func _boot_players(n: int) -> void:
	if _booted:
		return
	_booted = true
	for i in n:
		var p := AudioStreamPlayer.new()
		p.volume_db = DEFAULT_DB
		p.bus = "Master"
		p.finished.connect(_on_stream_finished.bind(p))
		add_child(p)
		_available.append(p)


func _on_stream_finished(player: AudioStreamPlayer) -> void:
	if not _available.has(player):
		_available.append(player)


## `sound_path` acepta varias rutas separadas por comas y elige una al azar,
## como los scripts originales de Kenney.
func play(sound_path: String, volume_db: float = DEFAULT_DB) -> void:
	if sound_path.is_empty():
		return
	if WebSafe.is_web() and not _booted:
		_boot_players(WEB_NUM_PLAYERS)
	var options := sound_path.split(",")
	if options.is_empty():
		return
	var chosen := "res://" + options[randi() % options.size()].strip_edges()
	_queue.append({"path": chosen, "volume": volume_db})


func _process(_delta: float) -> void:
	if _queue.is_empty() or _available.is_empty():
		return
	var item: Dictionary = _queue.pop_front()
	var player: AudioStreamPlayer = _available.pop_front()
	var path := str(item.get("path", ""))
	if not ResourceLoader.exists(path):
		_available.append(player)
		return
	var stream := load(path) as AudioStream
	if stream == null:
		_available.append(player)
		return
	player.stream = stream
	player.volume_db = float(item.get("volume", DEFAULT_DB)) + _settings_offset_db()
	player.pitch_scale = randf_range(0.9, 1.1)
	if SettingsManager.muted:
		_available.append(player)
		return
	player.play()


func _settings_offset_db() -> float:
	var sfx := clampf(SettingsManager.sfx_volume, 0.001, 1.0)
	return linear_to_db(sfx)

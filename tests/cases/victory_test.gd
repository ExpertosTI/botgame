extends "res://tests/test_case.gd"

## Condiciones de victoria y derrota. Corre con OfflineMultiplayerPeer, que es
## exactamente el transporte de la práctica/campaña en solitario.

var _saved_progress: Dictionary = {}
var _saved_players: Dictionary = {}
var _saved_peer: MultiplayerPeer = null
var _saved_campaign := false
## Los lambdas de GDScript capturan las locales por valor: el ganador tiene que
## aterrizar en un miembro para que el assert lo vea.
var _winner := ""
var _ends := 0


func suite_name() -> String:
	return "victory"


func run() -> void:
	_enter_offline()
	_robots_win_by_emptying_the_cores()
	_beast_wins_by_eliminating_the_crew()
	_beast_wins_when_the_clock_runs_out()
	_end_match_is_idempotent()
	_exit_offline()


func _enter_offline() -> void:
	_saved_players = NetworkManager.players.duplicate(true)
	_saved_campaign = ProgressionManager.campaign_mode
	_saved_progress = {
		"campaign_index": ProgressionManager.campaign_index,
		"selected_level": ProgressionManager.selected_level,
		"wins_total": ProgressionManager.wins_total,
		"matches_played": ProgressionManager.matches_played,
		"maps": ProgressionManager.unlocked_maps.duplicate(),
		"loadouts": ProgressionManager.unlocked_loadouts.duplicate(),
		"beasts": ProgressionManager.unlocked_beasts.duplicate(),
	}
	ProgressionManager.campaign_mode = false
	_saved_peer = push_offline_peer()


func _exit_offline() -> void:
	GameManager.match_active = false
	pop_peer(_saved_peer)
	NetworkManager.players = _saved_players
	ProgressionManager.campaign_mode = _saved_campaign
	ProgressionManager.campaign_index = int(_saved_progress["campaign_index"])
	ProgressionManager.selected_level = int(_saved_progress["selected_level"])
	ProgressionManager.wins_total = int(_saved_progress["wins_total"])
	ProgressionManager.matches_played = int(_saved_progress["matches_played"])
	ProgressionManager.unlocked_maps = (_saved_progress["maps"] as Array).duplicate()
	ProgressionManager.unlocked_loadouts = (_saved_progress["loadouts"] as Array).duplicate()
	ProgressionManager.unlocked_beasts = (_saved_progress["beasts"] as Array).duplicate()
	ProgressionManager.save_progress()


## Un 1 bestia vs 2 robots listo para jugar.
func _boot_match(cores := 3) -> void:
	_winner = ""
	NetworkManager.players = {
		1: {"name": "Bestia", "role": "beast", "ready": true, "skin": 0, "loadout": 0},
		2: {"name": "R1", "role": "explorer", "ready": true, "skin": 0, "loadout": 0},
		3: {"name": "R2", "role": "explorer", "ready": true, "skin": 1, "loadout": 1},
	}
	GameManager.match_active = false
	GameManager.level_rules_locked = true
	GameManager.level_core_count = cores
	GameManager.level_match_time = 60.0
	GameManager.level_beast_hp_mult = 1.0
	GameManager.setup_match({
		1: GameManager.Role.BEAST,
		2: GameManager.Role.EXPLORER,
		3: GameManager.Role.EXPLORER,
	})
	GameManager.start_match()
	GameManager.match_ended.connect(_record_winner, CONNECT_ONE_SHOT)


func _record_winner(w: String) -> void:
	_winner = w


func _robots_win_by_emptying_the_cores() -> void:
	_boot_match(3)
	eq(GameManager.objectives_remaining, 3, "setup_match no aplicó los núcleos del nivel")
	eq(GameManager.explorer_lives.size(), 2, "solo los robots deben tener vidas")
	eq(int(GameManager.explorer_lives[2]), GameManager.EXPLORER_LIVES, "vidas iniciales incorrectas")

	GameManager.register_objective_destroyed()
	eq(GameManager.objectives_remaining, 2, "sabotear un núcleo debe descontar uno")
	ok(GameManager.match_active, "la partida no puede terminar con núcleos vivos")
	GameManager.register_objective_destroyed()
	GameManager.register_objective_destroyed()
	eq(_winner, "explorers", "vaciar los núcleos debe dar la victoria a los robots")
	ok(not GameManager.match_active, "la partida debe cerrarse al ganar")


func _beast_wins_by_eliminating_the_crew() -> void:
	_boot_match(5)
	for _i in GameManager.EXPLORER_LIVES:
		GameManager.damage_explorer(2)
	ok(GameManager.match_active, "con un robot vivo la partida sigue")
	eq(_winner, "", "la bestia no gana mientras quede tripulación")
	for _i in GameManager.EXPLORER_LIVES:
		GameManager.damage_explorer(3)
	eq(_winner, "beast", "sin robots vivos gana la bestia")
	eq(int(GameManager.explorer_lives[3]), 0, "las vidas no deben quedar negativas al cerrar")


func _beast_wins_when_the_clock_runs_out() -> void:
	_boot_match(5)
	GameManager.match_timer = 0.05
	GameManager._process(0.2)
	eq(_winner, "beast", "agotar el reloj debe dar la victoria a la bestia")
	close_to(GameManager.get_remaining_time(), 0.0, 0.001, "el reloj no debe mostrarse negativo")


func _end_match_is_idempotent() -> void:
	_boot_match(5)
	_ends = 0
	GameManager.match_ended.connect(_count_end)
	GameManager.end_match("beast")
	GameManager.end_match("explorers")
	GameManager.end_match("beast")
	eq(_ends, 1, "end_match repetido no debe emitir varias veces")
	GameManager.match_ended.disconnect(_count_end)


func _count_end(_w: String) -> void:
	_ends += 1

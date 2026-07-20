extends Node

## Escena del servidor dedicado headless.
## Arranca: godot --headless --path . -- --server

@onready var status: Label = $StatusLabel


func _ready() -> void:
	if not NetworkManager.is_dedicated_server:
		var err := NetworkManager.start_dedicated_server()
		if err != OK and status:
			status.text = "Error al iniciar servidor"
			return
	NetworkManager.match_start_requested.connect(_on_match_start)
	if status:
		status.text = "Servidor dedicado OK — puerto %d" % NetworkManager.config.websocket_port
	print("[ServerMain] Esperando jugadores...")


func _on_match_start(_map_id: String) -> void:
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")

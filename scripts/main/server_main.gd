extends Node

## Escena del servidor dedicado headless.
## Arranca: godot --headless --path . -- --server

@onready var status: Label = $StatusLabel


func _ready() -> void:
	# Asegurar servidor aunque el autoload no haya pillado --server
	if not NetworkManager.is_dedicated_server:
		var err := NetworkManager.start_dedicated_server()
		if err != OK:
			push_error("[ServerMain] No se pudo abrir WebSocket: %s" % error_string(err))
			if status:
				status.text = "Error al iniciar servidor"
			return
	NetworkManager.match_start_requested.connect(_on_match_start)
	var port := NetworkManager.config.websocket_port if NetworkManager.config else 7777
	if status:
		status.text = "Servidor dedicado OK — puerto %d" % port
	print("[ServerMain] Esperando jugadores en puerto ", port)


func _on_match_start(_map_id: String) -> void:
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")

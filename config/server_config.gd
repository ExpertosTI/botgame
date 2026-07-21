class_name ServerConfig
extends Resource

## URL pública del servidor (WebSocket).
## En producción: wss://tu-dominio.com/ws
## En local: ws://127.0.0.1:7777

@export var server_url: String = "ws://127.0.0.1:7777"
@export var websocket_port: int = 7777
@export var max_players: int = 5  # 1 bestia + hasta 4 robots
@export var match_time_seconds: int = 240
@export var easy_beast_mode: bool = false

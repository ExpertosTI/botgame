extends Control

@onready var join_button: Button = $VBox/JoinButton
@onready var host_button: Button = $VBox/HostButton
@onready var name_input: LineEdit = $VBox/NameInput
@onready var address_input: LineEdit = $VBox/AddressInput
@onready var status_label: Label = $VBox/StatusLabel

const LOBBY_SCENE := "res://scenes/main/lobby.tscn"


func _ready() -> void:
	# Si el proceso es servidor dedicado, no mostrar menú
	if NetworkManager.is_dedicated_server:
		get_tree().change_scene_to_file("res://scenes/main/server_main.tscn")
		return

	join_button.pressed.connect(_on_join_pressed)
	host_button.pressed.connect(_on_host_pressed)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_started.connect(_on_server_started)

	name_input.text = "Robot"
	address_input.text = NetworkManager.get_default_server_url()
	address_input.placeholder_text = "ws://tu-vps:7777 o wss://tu-dominio.com/ws"


func _on_join_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Jugador"
	var address := address_input.text.strip_edges()
	status_label.text = "Conectando..."
	var err := NetworkManager.join_game(address, player_name)
	if err != OK:
		status_label.text = "Error al conectar (%s)" % error_string(err)


func _on_host_pressed() -> void:
	## Solo para pruebas locales (listen server)
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Anfitrión"
	status_label.text = "Creando servidor local..."
	var err := NetworkManager.host_listen_server(player_name)
	if err != OK:
		status_label.text = "Error al crear servidor local"


func _on_server_started() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connected() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connection_failed() -> void:
	status_label.text = "No se pudo conectar al VPS. Revisa la URL."

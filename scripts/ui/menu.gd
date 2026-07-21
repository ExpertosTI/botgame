extends Control

@onready var join_button: Button = %JoinButton
@onready var host_button: Button = %HostButton
@onready var name_input: LineEdit = %NameInput
@onready var address_input: LineEdit = %AddressInput
@onready var status_label: Label = %StatusLabel
@onready var title_label: Label = %TitleLabel
@onready var subtitle: Label = %Subtitle
@onready var stage_root: Node3D = %StageRoot
@onready var atmosphere: ColorRect = %Atmosphere

const LOBBY_SCENE := "res://scenes/main/lobby.tscn"
const CREW_SCRIPT := preload("res://scripts/player/crew_visual.gd")

var _spin_nodes: Array[Node3D] = []


func _ready() -> void:
	if NetworkManager.is_dedicated_server:
		get_tree().change_scene_to_file("res://scenes/main/server_main.tscn")
		return

	GameTheme.apply(self)
	_style_ui()
	_setup_atmosphere()
	_spawn_showcase()
	call_deferred("_adapt_layout")

	join_button.pressed.connect(_on_join_pressed)
	host_button.pressed.connect(_on_host_pressed)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_started.connect(_on_server_started)

	name_input.text = "Robot"
	address_input.text = NetworkManager.get_default_server_url()
	address_input.placeholder_text = "wss://botgame.renace.tech/ws"


func _style_ui() -> void:
	GameTheme.style_title(title_label, 48)
	GameTheme.style_muted(subtitle, 17)
	GameTheme.style_primary(join_button)
	join_button.text = "ENTRAR A LA PARTIDA"
	host_button.text = "Probar en local"
	status_label.add_theme_color_override("font_color", GameTheme.C_AMBER)


func _setup_atmosphere() -> void:
	# Shader full-screen es caro en móviles; en web usamos color sólido
	if OS.has_feature("web") or OS.get_name() == "Web":
		atmosphere.color = Color(0.04, 0.07, 0.1, 1)
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ui_atmosphere.gdshader")
	atmosphere.material = mat


func _spawn_showcase() -> void:
	if stage_root == null:
		return
	# En Web: no SubViewport 3D (ralentiza la carga inicial ~mucho)
	var stage_wrap := get_node_or_null("Main/StageWrap") as Control
	if OS.has_feature("web") or OS.get_name() == "Web":
		if stage_wrap:
			stage_wrap.visible = false
		return

	var robot: Node3D = CREW_SCRIPT.new()
	robot.is_beast = false
	robot.position = Vector3(-1.15, 0, 0)
	stage_root.add_child(robot)
	robot.apply_colors(Color(0.15, 0.75, 0.85), Color(0.7, 0.95, 1.0), Color(0.1, 0.35, 0.4))
	robot.set_player_name("ROBOT")

	var beast: Node3D = CREW_SCRIPT.new()
	beast.is_beast = true
	beast.body_scale = 1.05
	beast.position = Vector3(1.25, 0, 0.2)
	stage_root.add_child(beast)
	beast.apply_colors(Color(0.55, 0.08, 0.12), Color(1.0, 0.35, 0.2), Color(0.9, 0.55, 0.1))
	beast.set_player_name("BESTIA")

	_spin_nodes = [robot, beast]

	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.4
	cyl.bottom_radius = 2.6
	cyl.height = 0.12
	pad.mesh = cyl
	pad.position = Vector3(0, -0.05, 0)
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.08, 0.12, 0.15)
	pad_mat.emission_enabled = true
	pad_mat.emission = Color(0.1, 0.5, 0.45)
	pad_mat.emission_energy_multiplier = 0.35
	pad.material_override = pad_mat
	stage_root.add_child(pad)


func _process(delta: float) -> void:
	for i in _spin_nodes.size():
		var n := _spin_nodes[i]
		if is_instance_valid(n):
			n.rotate_y(delta * (0.55 if i == 0 else -0.4))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_adapt_layout()


func _adapt_layout() -> void:
	var stage := get_node_or_null("Main/StageWrap") as Control
	if stage:
		stage.visible = size.x >= 760



func _on_join_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Jugador"
	var address := address_input.text.strip_edges()
	status_label.text = "Conectando al hangar…"
	var err := NetworkManager.join_game(address, player_name)
	if err != OK:
		status_label.text = "Error al conectar (%s)" % error_string(err)


func _on_host_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Anfitrión"
	status_label.text = "Abriendo sala local…"
	var err := NetworkManager.host_listen_server(player_name)
	if err != OK:
		status_label.text = "Error al crear servidor local"


func _on_server_started() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connected() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connection_failed() -> void:
	if last_reject_reason != "":
		status_label.text = last_reject_reason
	else:
		status_label.text = "No se pudo conectar al VPS. Revisa la URL."

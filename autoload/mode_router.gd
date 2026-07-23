extends Node

## Enruta entre hub CHADRINE y submodos locales (Kenney).

signal mode_changed(mode_id: String)

const MODE_ASYMMETRIC := "asymmetric"
const MODE_PLATFORMER := "platformer"
const MODE_FPS := "fps"
const MODE_CITY := "city_builder"

const HUB_SCENE := "res://scenes/main/menu.tscn"
const INTRO_SCENE := "res://scenes/main/intro.tscn"

const MODE_SCENES := {
	MODE_PLATFORMER: "res://modes/platformer/scenes/main.tscn",
	MODE_FPS: "res://modes/fps/scenes/main.tscn",
	MODE_CITY: "res://modes/city_builder/scenes/main.tscn",
}

var current_mode := MODE_ASYMMETRIC
var intro_seen_session := false


func mode_title(mode_id: String) -> String:
	match mode_id:
		MODE_PLATFORMER: return "Platformer"
		MODE_FPS: return "FPS"
		MODE_CITY: return "City Builder"
		_: return "Asimétrico · Bestia vs Robots"


func start_mode(mode_id: String) -> void:
	current_mode = mode_id
	mode_changed.emit(mode_id)
	if mode_id == MODE_ASYMMETRIC:
		return
	if NetworkManager.has_method("disconnect_from_game"):
		NetworkManager.disconnect_from_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var path: String = MODE_SCENES.get(mode_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("ModeRouter: modo no instalado %s" % mode_id)
		_toast_missing_mode(mode_id)
		return_to_hub()
		return
	get_tree().change_scene_to_file(path)


func mode_available(mode_id: String) -> bool:
	if mode_id == MODE_ASYMMETRIC:
		return true
	var path: String = MODE_SCENES.get(mode_id, "")
	return not path.is_empty() and ResourceLoader.exists(path)


func _toast_missing_mode(mode_id: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var dlg := AcceptDialog.new()
	dlg.title = mode_title(mode_id)
	dlg.dialog_text = (
		"El modo «%s» no está en este build.\n\nEl núcleo asimétrico (ONLINE / CAMPAÑA) sí está disponible.\nLos submodos Kenney se publican como capa opcional."
		% mode_title(mode_id)
	)
	tree.root.add_child(dlg)
	dlg.popup_centered(Vector2(420, 200))
	dlg.confirmed.connect(dlg.queue_free)
	dlg.close_requested.connect(dlg.queue_free)


func return_to_hub() -> void:
	current_mode = MODE_ASYMMETRIC
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	if NetworkManager.has_method("disconnect_from_game"):
		NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file(HUB_SCENE)
	mode_changed.emit(MODE_ASYMMETRIC)


func go_intro_or_hub() -> void:
	if intro_seen_session or not ResourceLoader.exists("res://assets/video/intro/chadrine_intro.mp4"):
		get_tree().change_scene_to_file(HUB_SCENE)
	else:
		get_tree().change_scene_to_file(INTRO_SCENE)

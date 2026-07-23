class_name HubReturnOverlay
extends CanvasLayer

## Botón / Esc para volver al hub desde submodos Kenney.


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	var btn := Button.new()
	btn.text = "← Hub CHADRINE"
	btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	btn.offset_left = 12
	btn.offset_top = 12
	btn.offset_right = 180
	btn.offset_bottom = 48
	btn.pressed.connect(_go_hub)
	add_child(btn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_hub()
		get_viewport().set_input_as_handled()


func _go_hub() -> void:
	ModeRouter.return_to_hub()

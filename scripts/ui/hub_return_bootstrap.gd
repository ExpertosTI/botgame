extends Node

## Inyecta overlay "volver al hub" en escenas de submodo.

const OVERLAY := preload("res://scripts/ui/hub_return_overlay.gd")


func _ready() -> void:
	call_deferred("_attach")


func _attach() -> void:
	var overlay: CanvasLayer = OVERLAY.new()
	overlay.name = "HubReturn"
	get_tree().current_scene.add_child(overlay)

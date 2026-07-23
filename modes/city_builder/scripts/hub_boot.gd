extends Node

## Añade overlay de vuelta al hub en City Builder.


func _ready() -> void:
	var overlay := load("res://scripts/ui/hub_return_overlay.gd").new()
	get_parent().add_child.call_deferred(overlay)

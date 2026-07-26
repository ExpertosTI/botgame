extends Node

## Añade overlay de vuelta al hub en escenas FPS / City.


const HUB_RETURN_OVERLAY := preload("res://scripts/ui/hub_return_overlay.gd")


func _ready() -> void:
	# Tipo explícito: load() devuelve Variant y `:=` no puede inferir de ahí.
	var overlay: HubReturnOverlay = HUB_RETURN_OVERLAY.new()
	get_parent().add_child.call_deferred(overlay)

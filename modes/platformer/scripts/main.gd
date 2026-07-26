extends Node3D

const HUB_RETURN_OVERLAY := preload("res://scripts/ui/hub_return_overlay.gd")


func _ready() -> void:
	# RenderingServer.get_current_rendering_method() no existe en 4.3; el método
	# activo se lee del ajuste de proyecto.
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	if method == "gl_compatibility":
		# Baja el sol y el fondo para acercar el look de Compatibility al de
		# Forward+ (distinto espacio de color y luces con sombra).
		$Sun.light_energy = 0.24
		$Sun.shadow_opacity = 0.85
		$Environment.environment.background_energy_multiplier = 0.25
	# preload + tipado explícito: load() devuelve Variant y `:=` no infiere.
	var overlay: HubReturnOverlay = HUB_RETURN_OVERLAY.new()
	add_child(overlay)

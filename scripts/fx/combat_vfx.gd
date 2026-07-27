class_name CombatVfx
extends RefCounted

## Fachada de VFX de combate. El trabajo real lo hace FxPool (nodos reciclados,
## materiales compartidos, animación por lerp sin Tweens); aquí se mantiene la
## firma con `parent` porque hay una quincena de llamadas repartidas por
## combate, habilidades, explosiones y mapas.


static func burst(_parent: Node, pos: Vector3, color: Color, radius: float = 1.2, count: int = 10) -> void:
	if WebSafe.is_web():
		count = mini(count, 4)
	FxPool.burst(pos, color, radius, count)


static func ring(_parent: Node, pos: Vector3, color: Color, radius: float = 3.0) -> void:
	FxPool.ring(pos, color, radius)


static func flash(_parent: Node, pos: Vector3, color: Color, size: float = 0.35) -> void:
	FxPool.flash(pos, color, size)


static func shake_camera(cam: Camera3D, strength: float = 0.18, duration: float = 0.18) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	if WebSafe.is_web():
		## Sacudida con tween encadenado en web móvil → skip; el hit se oye igual.
		return
	# Un solo Tween por sacudida (no por partícula) y siempre sobre la misma
	# cámara: si ya había uno corriendo se descarta para no acumular offsets.
	if cam.has_meta("shake_tween"):
		var old := cam.get_meta("shake_tween") as Tween
		if old != null and old.is_valid():
			old.kill()
	var base: Vector3 = cam.get_meta("shake_base", cam.position)
	cam.set_meta("shake_base", base)
	var tw := cam.create_tween()
	cam.set_meta("shake_tween", tw)
	var steps := 5
	for i in steps:
		var off := Vector3(
			randf_range(-strength, strength),
			randf_range(-strength * 0.6, strength * 0.6),
			randf_range(-strength * 0.3, strength * 0.3)
		)
		tw.tween_property(cam, "position", base + off, duration / float(steps))
	tw.tween_property(cam, "position", base, 0.05)


static func damage_vignette(layer: CanvasLayer, color: Color = Color(0.9, 0.1, 0.15, 0.35)) -> void:
	if layer == null:
		return
	# Un único ColorRect reutilizado: los impactos encadenados apilaban uno nuevo
	# por golpe y cada uno con su Tween.
	var rect := layer.get_node_or_null("DamageVignette") as ColorRect
	if rect == null:
		rect = ColorRect.new()
		rect.name = "DamageVignette"
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(rect)
	if rect.has_meta("vignette_tween"):
		var old := rect.get_meta("vignette_tween") as Tween
		if old != null and old.is_valid():
			old.kill()
	rect.color = color
	var tw := rect.create_tween()
	rect.set_meta("vignette_tween", tw)
	tw.tween_property(rect, "color:a", 0.0, 0.35)

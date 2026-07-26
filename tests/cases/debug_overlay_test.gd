extends "res://tests/test_case.gd"

## Overlay de diagnóstico (F3).
##
## Existe por una razón concreta: el overlay solo se dibuja cuando alguien pulsa
## F3, así que una constante de Performance mal escrita o una clave que ya no
## está en FxPool.stats() no daría error hasta que el bug esté en producción y
## alguien intente medirlo. Aquí se fuerza el reporte completo en cada CI.


func suite_name() -> String:
	return "debug_overlay"


func run() -> void:
	_overlay_is_registered()
	_report_renders_without_errors()
	_report_survives_an_active_match()


func _overlay() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("DebugOverlay") if loop != null else null


func _overlay_is_registered() -> void:
	var node := _overlay()
	ok(node != null, "DebugOverlay debe estar declarado como autoload")
	if node == null:
		return
	ok(node is CanvasLayer, "el overlay tiene que ser un CanvasLayer para pintar sobre el juego")
	ok(node.has_method("_report"), "falta el generador del reporte")


func _report_renders_without_errors() -> void:
	var node := _overlay()
	if node == null:
		return
	var text := str(node.call("_report"))
	neq(text, "", "el reporte no puede salir vacío")
	# Cada línea es una familia de métricas que nos costó un bug: si alguna
	# desaparece del reporte, el overlay dejó de medir eso.
	for needle in ["fps", "draw", "nodos", "mem", "proyectiles", "red:"]:
		ok(text.contains(needle), "el reporte ya no incluye '%s'" % needle)
	ok(text.contains(GameBrand.VERSION), "el reporte debe decir qué build se está midiendo")


func _report_survives_an_active_match() -> void:
	var node := _overlay()
	if node == null:
		return
	# La rama de partida activa lee objectives_remaining, el reloj y el mapa; se
	# fuerza para que no quede sin ejecutar nunca en CI.
	var previous := GameManager.match_active
	GameManager.match_active = true
	var text := str(node.call("_report"))
	GameManager.match_active = previous
	ok(text.contains("partida:"), "con partida activa el reporte debe incluir el estado de la partida")

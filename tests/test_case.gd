extends RefCounted

## Base de los casos en tests/cases/. Sin dependencias externas: el runner
## corre como escena headless para que los autoloads estén vivos.
##
## Se extiende por ruta (`extends "res://tests/test_case.gd"`) en vez de
## class_name para no depender del cache de clases globales en CI limpio.

var failures: PackedStringArray = []
var checks := 0


## Nombre legible del caso; sobreescribible.
func suite_name() -> String:
	return get_script().resource_path.get_file().get_basename()


## Los casos son RefCounted, así que no tienen `multiplayer` propio. Este es el
## mismo MultiplayerAPI que ven los autoloads.
func mp() -> MultiplayerAPI:
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.multiplayer if loop != null else null


## Emula el transporte de la práctica en solitario (OfflineMultiplayerPeer) y
## devuelve el peer anterior para restaurarlo.
func push_offline_peer() -> MultiplayerPeer:
	var api := mp()
	var previous := api.multiplayer_peer if api != null else null
	if api != null:
		api.multiplayer_peer = OfflineMultiplayerPeer.new()
	return previous


func pop_peer(previous: MultiplayerPeer) -> void:
	var api := mp()
	if api != null:
		api.multiplayer_peer = previous


## Punto de entrada. Puede ser `await`-able.
func run() -> void:
	fail("run() no implementado en %s" % suite_name())


func fail(msg: String) -> void:
	failures.append(msg)


func ok(condition: bool, msg: String) -> bool:
	checks += 1
	if not condition:
		fail(msg)
	return condition


func eq(actual: Variant, expected: Variant, msg: String) -> bool:
	checks += 1
	if actual != expected:
		fail("%s — esperado <%s>, obtenido <%s>" % [msg, str(expected), str(actual)])
		return false
	return true


func neq(actual: Variant, forbidden: Variant, msg: String) -> bool:
	checks += 1
	if actual == forbidden:
		fail("%s — no debía ser <%s>" % [msg, str(forbidden)])
		return false
	return true


func close_to(actual: float, expected: float, tolerance: float, msg: String) -> bool:
	checks += 1
	if absf(actual - expected) > tolerance:
		fail("%s — esperado %.4f ±%.4f, obtenido %.4f" % [msg, expected, tolerance, actual])
		return false
	return true


func gt(actual: float, floor_value: float, msg: String) -> bool:
	checks += 1
	if actual <= floor_value:
		fail("%s — esperado > %s, obtenido %s" % [msg, str(floor_value), str(actual)])
		return false
	return true


func in_range(actual: float, lo: float, hi: float, msg: String) -> bool:
	checks += 1
	if actual < lo or actual > hi:
		fail("%s — esperado en [%s, %s], obtenido %s" % [msg, str(lo), str(hi), str(actual)])
		return false
	return true


func has_key(dict: Dictionary, key: Variant, msg: String) -> bool:
	checks += 1
	if not dict.has(key):
		fail("%s — falta la clave <%s>" % [msg, str(key)])
		return false
	return true

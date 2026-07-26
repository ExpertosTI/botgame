extends "res://tests/test_case.gd"

## Imán de puntería para táctil y web.
##
## El riesgo de una ayuda así es pasarse: si corrige demasiado, el juego apunta
## por ti y deja de tener mérito; si corrige a través de una pared o a la
## espalda, se siente roto. Estos casos fijan los límites.


func suite_name() -> String:
	return "aim_assist"


func run() -> void:
	_corrects_small_errors()
	_ignores_targets_outside_the_cone()
	_ignores_targets_too_far()
	_prefers_the_closest_to_the_crosshair()
	_reaches_targets_at_another_height()
	_without_targets_it_changes_nothing()


func _origin() -> Vector3:
	return Vector3.ZERO


func _corrects_small_errors() -> void:
	## Error fino: lo que un stick virtual no permite afinar.
	var target := Vector3(1.0, 0.0, -10.0)  # ~5,7° a la derecha
	var out := AimAssist.best_direction(_origin(), Vector3.FORWARD, [target])
	var expected := target.normalized()
	ok(out.angle_to(expected) < 0.01, "el imán debería haber corregido hacia el blanco cercano")


func _ignores_targets_outside_the_cone() -> void:
	## Un enemigo a 60° no es a quien estabas apuntando.
	var target := Vector3(17.0, 0.0, -10.0)
	var out := AimAssist.best_direction(_origin(), Vector3.FORWARD, [target])
	ok(
		out.angle_to(Vector3.FORWARD) < 0.001,
		"el imán no puede girar el disparo hacia algo fuera del cono"
	)


func _ignores_targets_too_far() -> void:
	var far := Vector3(0.0, 0.0, -(AimAssist.RANGE + 12.0))
	var out := AimAssist.best_direction(_origin(), Vector3.FORWARD, [far])
	ok(out.angle_to(Vector3.FORWARD) < 0.001, "fuera de alcance no debe haber corrección")


func _prefers_the_closest_to_the_crosshair() -> void:
	var casi := Vector3(0.5, 0.0, -10.0)
	var lejano := Vector3(2.8, 0.0, -10.0)
	var out := AimAssist.best_direction(_origin(), Vector3.FORWARD, [lejano, casi])
	ok(
		out.angle_to(casi.normalized()) < 0.01,
		"con dos blancos en el cono debe elegir el más alineado, no el primero de la lista"
	)


func _reaches_targets_at_another_height() -> void:
	## El motivo principal de existir: la cámara lateral no tiene eje vertical.
	var arriba := Vector3(0.0, 2.5, -10.0)
	var out := AimAssist.best_direction(_origin(), Vector3.FORWARD, [arriba])
	ok(out.y > 0.2, "el imán debe poder levantar el disparo hacia un blanco más alto")
	ok(out.angle_to(arriba.normalized()) < 0.01, "y apuntar exactamente al blanco")


func _without_targets_it_changes_nothing() -> void:
	var out := AimAssist.best_direction(_origin(), Vector3.FORWARD, [])
	eq(out, Vector3.FORWARD, "sin blancos la dirección debe salir intacta")

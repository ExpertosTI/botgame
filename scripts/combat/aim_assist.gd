class_name AimAssist
extends RefCounted

## Asistencia de puntería para táctil y web.
##
## Con la cámara lateral se dispara hacia donde encara el cuerpo, y el cuerpo lo
## orienta el mismo stick que sirve para moverse. No hay eje vertical de
## apuntado. Con eso, acertar a un enemigo que esté en otra altura o cruzando en
## diagonal era cuestión de suerte, y las armas rápidas (el railgun vuela a 48
## m/s) resultaban inservibles en un móvil.
##
## La ayuda es un imán de cono estrecho: si ya estás mirando casi al enemigo, la
## dirección se corrige hasta él. Fuera del cono no hace nada, así que sigue
## habiendo que apuntar; lo que se perdona es el error fino que un stick no
## permite corregir.

const RANGE := 28.0
const CONE_DEG := 20.0
## Altura del pecho respecto al origen del personaje: disparar a los pies hacía
## que los proyectiles se estrellaran contra el suelo.
const CHEST_OFFSET := 0.9


## Elige la mejor corrección para `dir` entre los blancos dados. Es pura a
## propósito (sin nodos ni física) para poder probarla en la suite; el filtrado
## de vivos, bandos y línea de visión lo hace quien llama.
static func best_direction(
	origin: Vector3,
	dir: Vector3,
	targets: Array,
	max_range: float = RANGE,
	cone_deg: float = CONE_DEG
) -> Vector3:
	if targets.is_empty() or dir.length_squared() < 0.0001:
		return dir
	var aim := dir.normalized()
	var cone := deg_to_rad(cone_deg)
	var best := aim
	var best_angle := cone
	for t in targets:
		var to_target: Vector3 = (t as Vector3) - origin
		var distance := to_target.length()
		if distance > max_range or distance < 0.2:
			continue
		var candidate := to_target / distance
		var angle := aim.angle_to(candidate)
		if angle < best_angle:
			best_angle = angle
			best = candidate
	return best

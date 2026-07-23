class_name TipBank
extends RefCounted

## Tips rotativos para menú, lobby y HUD.

const GENERAL := [
	"Los núcleos blindados tardan más en sabotear.",
	"Recoge orbes: escudo, turbo, reparación y sobrecarga.",
	"El Pozo Reactor quema el centro — rodéalo.",
	"Railgun perfora a distancia; granada limpia pasillos.",
	"Dash (G) + Escudo salvan de la Bestia en melee.",
	"MVP se gana con daño, KOs y núcleos — no solo ganar.",
	"En Skybridge los flancos violeta hacen daño.",
	"Soporte lleva Pulso de cura y Rayo Hielo.",
	"La Bestia Sombra usa Orbe Vacío y minas.",
	"Pausa → volumen SFX/música y sensibilidad.",
]

const BEAST := [
	"Rugido ralentiza packs de robots.",
	"Furia + Slam = wipe en contenedores.",
	"Camuflaje para emboscar saboteadores.",
	"Corta el sabotaje: prioriza robots en núcleo.",
]

const ROBOT := [
	"Uno atrae, otro sabotea — no pelees de más.",
	"EMP aturde a la Bestia cerca del núcleo.",
	"Mina tras una esquina castiga persecuciones.",
	"Si te quedan 1 vida, prioriza núcleos lejanos.",
]


static func random_general() -> String:
	return GENERAL[randi() % GENERAL.size()]


static func random_for_role(beast: bool) -> String:
	var pool: Array = BEAST if beast else ROBOT
	if randf() < 0.45:
		return GENERAL[randi() % GENERAL.size()]
	return pool[randi() % pool.size()]


static func loading_blurb(map_id: String) -> String:
	match map_id:
		"reactor_pit":
			return "Pozo Reactor · evita el magma central y los pulsos."
		"skybridge":
			return "Puente Celeste · núcleos en torres, flancos peligrosos."
		"containers":
			return "Contenedores · emboscadas en pasillos cortos."
		"ruins":
			return "Ruinas · núcleo elevado y combates verticales."
		_:
			return "Laboratorio Neon · arena abierta, neones fríos."

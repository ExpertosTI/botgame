class_name ObjectiveVariants
extends RefCounted

## Variantes de núcleos: no son solo un multiplicador de tiempo.
##
## - Blindado: hay que romper el escudo a tiros antes de canalizar.
## - Relé: solo se sabotea en ventanas abiertas (amarillo = abierto).
## - Sobrecarga: al caer, detona y castiga a quien esté encima.
##
## El enum se llama Kind y no Variant: `Variant` es el tipo comodín del motor.

enum Kind {
	STANDARD,
	SHIELDED,
	TIMED_RELAY,
	OVERCHARGED,
}

const SHIELD_HP := 80.0
const RELAY_OPEN_S := 3.2
const RELAY_CLOSED_S := 2.4
const OVERCHARGE_RADIUS := 5.5
const OVERCHARGE_DAMAGE := 28.0


static func for_map(map_id: String, index: int) -> Kind:
	match map_id:
		"lab_neon":
			## Vertical slice: el primer hangar enseña las tres mecánicas.
			match index % 4:
				0:
					return Kind.STANDARD
				1:
					return Kind.SHIELDED
				2:
					return Kind.TIMED_RELAY
				_:
					return Kind.OVERCHARGED
		"reactor_pit":
			return Kind.OVERCHARGED if index == 0 else Kind.SHIELDED
		"skybridge":
			return Kind.TIMED_RELAY if index % 2 == 0 else Kind.STANDARD
		"ruins":
			return Kind.SHIELDED if index == 4 else Kind.STANDARD
		"containers":
			match index % 3:
				0:
					return Kind.STANDARD
				1:
					return Kind.SHIELDED
				_:
					return Kind.OVERCHARGED
		"castle":
			if index % 3 == 0:
				return Kind.TIMED_RELAY
			if index % 3 == 1:
				return Kind.SHIELDED
			return Kind.STANDARD
		"cave":
			if index == 0:
				return Kind.OVERCHARGED
			return Kind.SHIELDED if index % 2 == 0 else Kind.TIMED_RELAY
		"forest":
			if index % 4 == 0:
				return Kind.TIMED_RELAY
			if index % 4 == 2:
				return Kind.SHIELDED
			return Kind.STANDARD
		_:
			return Kind.STANDARD


static func sabotage_mult(variant: Kind) -> float:
	match variant:
		Kind.SHIELDED:
			return 1.45
		Kind.TIMED_RELAY:
			return 0.85
		Kind.OVERCHARGED:
			return 1.25
		_:
			return 1.0


static func tint(variant: Kind) -> Color:
	match variant:
		Kind.SHIELDED:
			return Color(0.35, 0.7, 1.0)
		Kind.TIMED_RELAY:
			return Color(0.95, 0.85, 0.25)
		Kind.OVERCHARGED:
			return Color(1.0, 0.35, 0.15)
		_:
			return Color(0.95, 0.22, 0.28)


static func label(variant: Kind) -> String:
	match variant:
		Kind.SHIELDED:
			return "Blindado"
		Kind.TIMED_RELAY:
			return "Relé"
		Kind.OVERCHARGED:
			return "Sobrecarga"
		_:
			return "Estándar"


static func hint(variant: Kind) -> String:
	match variant:
		Kind.SHIELDED:
			return "Dispara el escudo, luego canaliza"
		Kind.TIMED_RELAY:
			return "Espera la ventana amarilla"
		Kind.OVERCHARGED:
			return "Al caer detona cerca"
		_:
			return "Mantén pulsado para sabotear"

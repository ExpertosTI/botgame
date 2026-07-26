class_name ObjectiveVariants
extends RefCounted

## Variantes de núcleos según mapa / nivel de campaña.
##
## El enum se llama Kind y no Variant: `Variant` es el tipo comodín del motor,
## así que `-> Variant` no anotaba el enum sino "cualquier cosa", y quien hacía
## `var v := for_map(...)` no compilaba.

enum Kind {
	STANDARD,
	SHIELDED,
	TIMED_RELAY,
	OVERCHARGED,
}


static func for_map(map_id: String, index: int) -> Kind:
	match map_id:
		"reactor_pit":
			return Kind.OVERCHARGED if index == 0 else Kind.SHIELDED
		"skybridge":
			return Kind.TIMED_RELAY if index % 2 == 0 else Kind.STANDARD
		"ruins":
			return Kind.SHIELDED if index == 4 else Kind.STANDARD
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

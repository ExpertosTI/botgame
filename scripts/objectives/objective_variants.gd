class_name ObjectiveVariants
extends RefCounted

## Variantes de núcleos según mapa / nivel de campaña.

enum Variant {
	STANDARD,
	SHIELDED,
	TIMED_RELAY,
	OVERCHARGED,
}


static func for_map(map_id: String, index: int) -> Variant:
	match map_id:
		"reactor_pit":
			return Variant.OVERCHARGED if index == 0 else Variant.SHIELDED
		"skybridge":
			return Variant.TIMED_RELAY if index % 2 == 0 else Variant.STANDARD
		"ruins":
			return Variant.SHIELDED if index == 4 else Variant.STANDARD
		_:
			return Variant.STANDARD


static func sabotage_mult(variant: Variant) -> float:
	match variant:
		Variant.SHIELDED:
			return 1.45
		Variant.TIMED_RELAY:
			return 0.85
		Variant.OVERCHARGED:
			return 1.25
		_:
			return 1.0


static func tint(variant: Variant) -> Color:
	match variant:
		Variant.SHIELDED:
			return Color(0.35, 0.7, 1.0)
		Variant.TIMED_RELAY:
			return Color(0.95, 0.85, 0.25)
		Variant.OVERCHARGED:
			return Color(1.0, 0.35, 0.15)
		_:
			return Color(0.95, 0.22, 0.28)


static func label(variant: Variant) -> String:
	match variant:
		Variant.SHIELDED:
			return "Blindado"
		Variant.TIMED_RELAY:
			return "Relé"
		Variant.OVERCHARGED:
			return "Sobrecarga"
		_:
			return "Estándar"

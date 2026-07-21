class_name UiIcons
extends RefCounted

## Rutas de arte UI para lobby / menú.


const ROBOT_SKINS := [
	"res://assets/ui/robot_azul.png",
	"res://assets/ui/robot_rosa.png",
	"res://assets/ui/robot_verde.png",
	"res://assets/ui/robot_amarillo.png",
]

const ROBOT_EMOJI := ["🔵", "💗", "🟢", "🟡"]

const LOADOUTS := [
	"res://assets/ui/weapon_blaster.png",
	"res://assets/ui/weapon_shotgun.png",
	"res://assets/ui/weapon_grenade.png",
	"res://assets/ui/weapon_ice.png",
]

const LOADOUT_EMOJI := ["🔫", "💥", "💣", "❄️"]

const MAPS := {
	"lab_neon": "res://assets/ui/map_neon.jpg",
	"containers": "res://assets/ui/map_containers.jpg",
	"ruins": "res://assets/ui/map_ruins.jpg",
}

const MAP_EMOJI := {
	"lab_neon": "🧪",
	"containers": "📦",
	"ruins": "🏚️",
}

const MENU_HERO := "res://assets/ui/menu_hero.jpg"


static func tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func skin_tex(skin: int) -> Texture2D:
	return tex(ROBOT_SKINS[clampi(skin, 0, ROBOT_SKINS.size() - 1)])


static func loadout_tex(loadout: int) -> Texture2D:
	return tex(LOADOUTS[clampi(loadout, 0, LOADOUTS.size() - 1)])


static func map_tex(map_id: String) -> Texture2D:
	return tex(str(MAPS.get(map_id, MAPS["lab_neon"])))


static func beast_tex(variant: int) -> Texture2D:
	match variant:
		GameManager.BeastVariant.MECHA:
			return tex("res://assets/ui/beast_mecha.png")
		GameManager.BeastVariant.SHADOW:
			return tex("res://assets/ui/beast_shadow.png")
		_:
			return tex("res://assets/ui/beast_classic.png")


static func beast_emoji(variant: int) -> String:
	match variant:
		GameManager.BeastVariant.MECHA:
			return "🦾"
		GameManager.BeastVariant.SHADOW:
			return "👻"
		_:
			return "👹"

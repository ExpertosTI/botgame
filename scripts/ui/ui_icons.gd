class_name UiIcons
extends RefCounted

## Arte UI: skins base + retratos únicos (baratos, sin freeze en Web).


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
	"reactor_pit": "res://assets/ui/map_neon.jpg",
	"skybridge": "res://assets/ui/map_ruins.jpg",
	"castle": "res://assets/ui/map_containers.jpg",
	"cave": "res://assets/ui/map_ruins.jpg",
	"forest": "res://assets/ui/map_neon.jpg",
}

const MAP_EMOJI := {
	"lab_neon": "🧪",
	"containers": "📦",
	"ruins": "🏚️",
	"reactor_pit": "☢️",
	"skybridge": "🌉",
	"castle": "🏰",
	"cave": "🪨",
	"forest": "🌲",
}

const MENU_HERO := "res://assets/ui/menu_hero.jpg"

static var _catalog_cache: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func skin_tex(skin: int) -> Texture2D:
	return tex(ROBOT_SKINS[clampi(skin, 0, ROBOT_SKINS.size() - 1)])


static func catalog_tex(index: int) -> Texture2D:
	if _catalog_cache.has(index):
		return _catalog_cache[index] as Texture2D
	var entry: Dictionary = CharacterCatalog.get_entry(index)
	if entry.is_empty():
		return skin_tex(0)
	var id := str(entry.get("id", ""))
	var out: Texture2D = null
	match id:
		"crew_blue":
			out = tex(ROBOT_SKINS[0])
		"crew_pink":
			out = tex(ROBOT_SKINS[1])
		"crew_green":
			out = tex(ROBOT_SKINS[2])
		"crew_yellow":
			out = tex(ROBOT_SKINS[3])
		"beast_classic":
			out = beast_tex(int(GameManager.BeastVariant.CLASSIC))
		"beast_mecha":
			out = beast_tex(int(GameManager.BeastVariant.MECHA))
		"beast_shadow":
			out = beast_tex(int(GameManager.BeastVariant.SHADOW))
		_:
			out = _badge_tex(index, entry)
	if out == null:
		out = _badge_tex(index, entry)
	_catalog_cache[index] = out
	return out


static func _badge_tex(index: int, entry: Dictionary) -> Texture2D:
	## Badge único y barato (GradientTexture2D). Nunca pixel loops (congelaba Web).
	var tint: Color = entry.get("tint", Color(0.5, 0.7, 0.9))
	var g := Gradient.new()
	var a := tint.lightened(0.35)
	var b := tint.darkened(0.25)
	# Variación por índice para que no se vean clones
	var shift := float(index % 7) * 0.04
	a = a.lightened(shift)
	b = b.darkened(shift * 0.5)
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([a, tint, b])

	var tex2d := GradientTexture2D.new()
	tex2d.gradient = g
	tex2d.width = 96
	tex2d.height = 96
	tex2d.fill_from = Vector2(0.35, 0.25)
	tex2d.fill_to = Vector2(0.75, 0.9)
	var style: int = absi(str(entry.get("id", "x")).hash()) % 3
	match style:
		0:
			tex2d.fill = GradientTexture2D.FILL_RADIAL
		1:
			tex2d.fill = GradientTexture2D.FILL_LINEAR
		_:
			tex2d.fill = GradientTexture2D.FILL_RADIAL
			tex2d.fill_from = Vector2(0.5, 0.15)
			tex2d.fill_to = Vector2(0.5, 1.0)
	return tex2d


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

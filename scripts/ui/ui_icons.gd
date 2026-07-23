class_name UiIcons
extends RefCounted

## Arte UI: skins base + retratos únicos por entrada del catálogo.


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
	## Solo las 4 cápsulas originales (índices 0–3).
	return tex(ROBOT_SKINS[clampi(skin, 0, ROBOT_SKINS.size() - 1)])


static func catalog_tex(index: int) -> Texture2D:
	## Retrato único por personaje: PNG real si existe, badge tintado si no.
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
			out = beast_tex(GameManager.BeastVariant.CLASSIC)
		"beast_mecha":
			out = beast_tex(GameManager.BeastVariant.MECHA)
		"beast_shadow":
			out = beast_tex(GameManager.BeastVariant.SHADOW)
		_:
			out = _badge_tex(index, entry)
	if out == null:
		out = _badge_tex(index, entry)
	_catalog_cache[index] = out
	return out


static func _badge_tex(index: int, entry: Dictionary) -> Texture2D:
	var tint: Color = entry.get("tint", Color(0.5, 0.7, 0.9))
	var id := str(entry.get("id", "x"))
	var name := str(entry.get("name", "?"))
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bg := tint.darkened(0.55)
	bg.a = 1.0
	img.fill(bg)

	var cx := size / 2
	var cy := size / 2
	var style := abs(id.hash()) % 4
	for y in size:
		for x in size:
			var dx := float(x - cx)
			var dy := float(y - cy)
			var inside := false
			match style:
				0: # círculo (blocky)
					inside = dx * dx + dy * dy < 42.0 * 42.0
				1: # diamante (kay)
					inside = abs(dx) + abs(dy) < 48.0
				2: # escudo (skel / warrior)
					inside = abs(dx) < 36.0 and dy > -40.0 and dy < 44.0 and (dy < 20.0 or abs(dx) < 28.0 - (dy - 20.0) * 0.4)
				_: # hex soft
					inside = maxf(abs(dx), abs(dy) * 0.85) < 40.0
			if inside:
				var edge := 1.0
				if style == 0:
					edge = clampf(1.0 - (sqrt(dx * dx + dy * dy) / 42.0), 0.35, 1.0)
				var c := tint.lightened(0.08 * edge)
				# franja superior única por índice
				if y < 28 + (index % 5) * 3 and x > 16 and x < size - 16:
					c = tint.lightened(0.35)
				img.set_pixel(x, y, c)
			elif abs(dx) < 54 and abs(dy) < 54 and (abs(dx) > 50 or abs(dy) > 50):
				img.set_pixel(x, y, Color(1, 1, 1, 0.35))

	# Iniciales legibles (bloques 5x7)
	var initials := _initials(name)
	_blit_text(img, initials, 64 - initials.length() * 10, 92, Color(0.05, 0.08, 0.1, 1.0))

	var tex_out := ImageTexture.create_from_image(img)
	return tex_out


static func _initials(name: String) -> String:
	var parts := name.strip_edges().split(" ", false)
	if parts.is_empty():
		return "?"
	if parts.size() == 1:
		return str(parts[0]).substr(0, mini(2, str(parts[0]).length())).to_upper()
	return (str(parts[0])[0] + str(parts[parts.size() - 1])[0]).to_upper()


static func _blit_text(img: Image, text: String, ox: int, oy: int, color: Color) -> void:
	for i in text.length():
		_blit_char(img, text[i], ox + i * 20, oy, color)


static func _blit_char(img: Image, ch: String, ox: int, oy: int, color: Color) -> void:
	## Bitmap 5x7 mínimo para A–Z / 0–9
	var glyphs := {
		"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
		"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
		"C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
		"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
		"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
		"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
		"G": ["01111", "10000", "10000", "10111", "10001", "10001", "01110"],
		"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
		"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
		"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
		"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
		"M": ["10001", "11011", "10101", "10001", "10001", "10001", "10001"],
		"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
		"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
		"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
		"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
		"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
		"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
		"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
		"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
		"W": ["10001", "10001", "10001", "10001", "10101", "11011", "10001"],
		"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
		"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
		"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
		"?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
	}
	var rows: Array = glyphs.get(ch.to_upper(), glyphs["?"])
	var scale := 2
	for r in rows.size():
		var row: String = str(rows[r])
		for c in row.length():
			if row[c] == "1":
				for py in scale:
					for px in scale:
						var xx := ox + c * scale + px
						var yy := oy + r * scale + py
						if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
							img.set_pixel(xx, yy, color)


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

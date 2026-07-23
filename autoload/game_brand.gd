class_name GameBrand
extends RefCounted

## Identidad del producto (tiendas / créditos / legal).

const GAME_TITLE := "CHADRINE"
const GAME_SHORT := "CHADRINE"
const TAGLINE := "Hub · Asimétrico · Platformer · FPS · City"
const PUBLISHER := "Renace Tech"
const DEVELOPER := "Expertos TI / Renace"
const VERSION := "1.2.0"
const VERSION_CODE := 120
const COPYRIGHT_YEAR := "2026"
const SUPPORT_URL := "https://botgame.renace.tech"
const PRIVACY_URL := "https://botgame.renace.tech/privacy"
const PACKAGE_ID := "tech.renace.chadrine"

const DISCLAIMER := (
	"CHADRINE y sus personajes son obras originales. "
	+ "Inspiración estética de silueta cápsula; no afiliado a Among Us ni Innersloth. "
	+ "Todos los derechos reservados."
)


static func copyright_line() -> String:
	return "© %s %s. %s." % [COPYRIGHT_YEAR, PUBLISHER, DEVELOPER]


static func store_subtitle() -> String:
	return "%s · %s" % [GAME_TITLE, TAGLINE]

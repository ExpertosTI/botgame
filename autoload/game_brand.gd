class_name GameBrand
extends RefCounted

## Identidad del producto (tiendas / créditos / legal).

const GAME_TITLE := "Bestia vs Robots"
const GAME_SHORT := "BvR"
const PUBLISHER := "Renace Tech"
const DEVELOPER := "Expertos TI / Renace"
const VERSION := "1.0.0"
const VERSION_CODE := 100
const COPYRIGHT_YEAR := "2026"
const SUPPORT_URL := "https://botgame.renace.tech"
const PRIVACY_URL := "https://botgame.renace.tech/privacy"
const PACKAGE_ID := "tech.renace.botgame"

const DISCLAIMER := (
	"Personajes y diseños originales. Inspiración estética de silueta cápsula; "
	+ "no afiliado a Among Us ni Innersloth. Todos los derechos reservados."
)


static func copyright_line() -> String:
	return "© %s %s. %s." % [COPYRIGHT_YEAR, PUBLISHER, DEVELOPER]


static func store_subtitle() -> String:
	return "1 Bestia vs Robots · sabotaje asimétrico · online y campaña"

extends "res://tests/test_case.gd"

## Identidad de producto: una sola fuente de verdad para versión y marca.
## Si esto falla, la landing, la tienda y version.json van a mentir.


func suite_name() -> String:
	return "identity"


func run() -> void:
	_version_has_a_single_source()
	_docs_quote_the_current_version()
	_brand_strings_are_publishable()
	_roster_and_theaters_are_named()


func _version_has_a_single_source() -> void:
	var project_version := str(ProjectSettings.get_setting("application/config/version", ""))
	eq(
		project_version, GameBrand.VERSION,
		"project.godot y GameBrand.VERSION no coinciden"
	)
	var parts := GameBrand.VERSION.split(".")
	eq(parts.size(), 3, "la versión debe ser semver mayor.menor.parche")
	var expected_code := int(parts[0]) * 100 + int(parts[1]) * 10 + int(parts[2])
	eq(
		GameBrand.VERSION_CODE, expected_code,
		"VERSION_CODE debe derivar de VERSION (mayor*100 + menor*10 + parche)"
	)
	eq(
		str(ProjectSettings.get_setting("application/config/name", "")), GameBrand.GAME_TITLE,
		"el nombre del proyecto no coincide con la marca"
	)


## El README se quedó anunciando 1.2.2 mientras el build iba por 1.4.0 y nadie lo
## notó. La documentación que lee un humano cuenta como superficie del producto.
func _docs_quote_the_current_version() -> void:
	for path in ["res://README.md", "res://docs/GDD.md", "res://docs/BIBLIA.md"]:
		var text := _read_text(path)
		neq(text, "", "falta %s" % path)
		if text.is_empty():
			continue
		ok(
			text.contains(GameBrand.VERSION),
			"%s no cita la versión actual (%s)" % [path.get_file(), GameBrand.VERSION]
		)


func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _brand_strings_are_publishable() -> void:
	neq(GameBrand.TAGLINE, "", "falta tagline para tiendas")
	neq(GameBrand.PUBLISHER, "", "falta publisher")
	ok(GameBrand.PACKAGE_ID.count(".") >= 2, "el package id debe ser un dominio invertido")
	ok(GameBrand.SUPPORT_URL.begins_with("https://"), "la URL de soporte debe ser HTTPS")
	ok(GameBrand.PRIVACY_URL.begins_with("https://"), "la URL de privacidad debe ser HTTPS")
	ok(GameBrand.copyright_line().contains(GameBrand.COPYRIGHT_YEAR), "el copyright no lleva año")
	ok(GameBrand.store_subtitle().contains(GameBrand.GAME_TITLE), "el subtítulo de tienda no cita el título")
	# El disclaimer es lo que nos separa de un clon: no puede desaparecer.
	ok(GameBrand.DISCLAIMER.length() > 60, "el disclaimer legal quedó demasiado corto")


func _roster_and_theaters_are_named() -> void:
	gt(float(CharacterCatalog.count()), 3.0, "el roster necesita al menos 4 personajes")
	for i in CharacterCatalog.count():
		var label := "personaje %d" % i
		var display := CharacterCatalog.display_name(i)
		neq(display, "?", "%s sin nombre legible" % label)
		neq(display, "", "%s con nombre vacío" % label)
		var entry := CharacterCatalog.get_entry(i)
		ok(not entry.is_empty(), "%s sin entrada en el catálogo" % label)
		ok(
			str(entry.get("role", "")) in ["explorer", "beast"],
			"%s con rol desconocido '%s'" % [label, str(entry.get("role", ""))]
		)
		ok(entry.has("tint"), "%s sin color de identidad" % label)

	# index_of_id() cae a 0 cuando no encuentra, así que preguntamos por la entrada.
	for bid in ["beast_classic", "beast_mecha", "beast_shadow"]:
		var entry := CharacterCatalog.find_by_id(bid)
		ok(not entry.is_empty(), "falta la variante de bestia '%s' en el catálogo" % bid)
		eq(str(entry.get("role", "")), "beast", "'%s' debe tener rol beast" % bid)

	gt(float(CharacterCatalog.explorer_indices().size()), 3.0, "faltan robots jugables")
	gt(float(CharacterCatalog.beast_indices().size()), 2.0, "faltan variantes de bestia")
	## Cara pública hangar: sin fantasy / Kenney en nombres de teatro.
	ok(CharacterCatalog.has_method("hangar_explorer_indices"), "API hangar explorers")
	ok(CharacterCatalog.has_method("hangar_beast_indices"), "API hangar beasts")
	eq(CharacterCatalog.hangar_beast_indices().size(), 3, "hangar: exactamente 3 bestias")
	for idx in CharacterCatalog.hangar_explorer_indices():
		var hid := str(CharacterCatalog.get_entry(int(idx)).get("id", ""))
		ok(not hid.begins_with("kay_"), "hangar no incluye KayKit (%s)" % hid)
	for mid in NetworkManager.MAP_IDS:
		var nm := str(NetworkManager.MAP_NAMES.get(mid, ""))
		ok(not nm.contains("Kenney"), "teatro %s no debe decir Kenney en UI" % mid)

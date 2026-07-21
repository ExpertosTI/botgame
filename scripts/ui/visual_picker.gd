class_name VisualPicker
extends RefCounted

## Tarjetas visuales clickeables para lobby (color / arsenal / mapa / bestia).


static func make_card(
	title: String,
	subtitle: String,
	accent: Color,
	selected: bool,
	min_size: Vector2 = Vector2(96, 88)
) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var edge := Color.WHITE if selected else accent.darkened(0.15)
	var bg := accent.darkened(0.55).lerp(Color(0.04, 0.06, 0.08), 0.35)
	if selected:
		bg = accent.darkened(0.35)
	card.add_theme_stylebox_override("panel", GameTheme.panel_style(bg, edge, 10, 3 if selected else 1))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(0, 28)
	swatch.color = accent
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(swatch)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", Color.WHITE if selected else GameTheme.C_TEXT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)

	if not subtitle.is_empty():
		var s := Label.new()
		s.text = subtitle
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.add_theme_font_size_override("font_size", 11)
		s.add_theme_color_override("font_color", GameTheme.C_MUTED)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(s)

	return card


static func make_skin_card(skin: int, selected: bool) -> PanelContainer:
	var colors := [
		Color(0.25, 0.55, 1.0),
		Color(1.0, 0.4, 0.7),
		Color(0.25, 0.85, 0.45),
		Color(1.0, 0.85, 0.2),
	]
	var c: Color = colors[clampi(skin, 0, 3)]
	var card := make_card(WeaponDefs.explorer_skin_name(skin), "ROBOT", c, selected, Vector2(78, 100))
	# Silueta cápsula simple
	var col := card.get_child(0) as VBoxContainer
	if col and col.get_child_count() > 0:
		var swatch := col.get_child(0) as ColorRect
		if swatch:
			swatch.custom_minimum_size = Vector2(0, 44)
	return card


static func make_loadout_card(loadout: int, selected: bool) -> PanelContainer:
	var accents := [
		Color(0.25, 0.85, 0.9),
		Color(1.0, 0.75, 0.2),
		Color(0.95, 0.35, 0.25),
		Color(0.45, 0.75, 1.0),
	]
	var hints := [
		"Bláster+",
		"Escopeta+",
		"Granadas+",
		"Hielo+",
	]
	return make_card(
		WeaponDefs.explorer_loadout_name(loadout),
		hints[clampi(loadout, 0, 3)],
		accents[clampi(loadout, 0, 3)],
		selected,
		Vector2(100, 92)
	)


static func make_map_card(map_id: String, selected: bool) -> PanelContainer:
	var accent := Color(0.2, 0.55, 0.85)
	var sub := "Arena abierta"
	match map_id:
		"containers":
			accent = Color(0.85, 0.45, 0.2)
			sub = "Pasillos"
		"ruins":
			accent = Color(0.7, 0.3, 0.55)
			sub = "Vertical"
		_:
			accent = Color(0.2, 0.7, 0.85)
			sub = "Neon"
	return make_card(NetworkManager.MAP_NAMES.get(map_id, map_id), sub, accent, selected, Vector2(110, 92))


static func make_beast_card(variant: int, selected: bool) -> PanelContainer:
	var accent := Color(0.75, 0.15, 0.18)
	var title := "Clásica"
	var sub := "Garras"
	match variant:
		GameManager.BeastVariant.MECHA:
			accent = Color(0.55, 0.55, 0.6)
			title = "Mecha"
			sub = "Slam"
		GameManager.BeastVariant.SHADOW:
			accent = Color(0.45, 0.2, 0.7)
			title = "Sombra"
			sub = "Cloak"
		_:
			accent = Color(0.85, 0.15, 0.2)
			title = "Clásica"
			sub = "Garras"
	return make_card(title, sub, accent, selected, Vector2(100, 92))

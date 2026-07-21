class_name VisualPicker
extends RefCounted

## Tarjetas visuales con arte / emoji para lobby.


static func make_card(
	title: String,
	subtitle: String,
	accent: Color,
	selected: bool,
	icon: Texture2D = null,
	emoji: String = "",
	min_size: Vector2 = Vector2(96, 118),
	icon_h: float = 72.0
) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var edge := Color.WHITE if selected else accent.darkened(0.1)
	var bg := Color(0.05, 0.07, 0.09, 0.95)
	if selected:
		bg = accent.darkened(0.55).lerp(Color(0.08, 0.1, 0.12), 0.4)
	card.add_theme_stylebox_override("panel", GameTheme.panel_style(bg, edge, 12, 3 if selected else 1))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame_bg := accent.darkened(0.65)
	frame.add_theme_stylebox_override(
		"panel",
		GameTheme.panel_style(frame_bg, accent.darkened(0.25), 8, 1)
	)
	col.add_child(frame)

	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(0, icon_h)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon_wrap)

	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size = Vector2(icon_h * 1.15, icon_h)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_wrap.add_child(tr)
	elif not emoji.is_empty():
		var em := Label.new()
		em.text = emoji
		em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		em.add_theme_font_size_override("font_size", 42)
		em.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_wrap.add_child(em)
	else:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(icon_h, icon_h * 0.55)
		swatch.color = accent
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_wrap.add_child(swatch)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title_row)

	if not emoji.is_empty() and icon != null:
		var em2 := Label.new()
		em2.text = emoji
		em2.add_theme_font_size_override("font_size", 14)
		em2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(em2)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color.WHITE if selected else GameTheme.C_TEXT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(t)

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
	var i := clampi(skin, 0, 3)
	var mobile := _is_narrow()
	return make_card(
		WeaponDefs.explorer_skin_name(skin),
		"ROBOT",
		colors[i],
		selected,
		UiIcons.skin_tex(i),
		UiIcons.ROBOT_EMOJI[i],
		Vector2(96 if mobile else 88, 136 if mobile else 128),
		92.0 if mobile else 78.0
	)


static func _is_narrow() -> bool:
	var tre := Engine.get_main_loop() as SceneTree
	if tre == null or tre.root == null:
		return false
	return tre.root.get_visible_rect().size.x < 780


static func make_loadout_card(loadout: int, selected: bool) -> PanelContainer:
	var accents := [
		Color(0.25, 0.85, 0.9),
		Color(1.0, 0.75, 0.2),
		Color(0.95, 0.35, 0.25),
		Color(0.45, 0.75, 1.0),
	]
	var hints := ["Bláster+", "Escopeta+", "Granadas+", "Hielo+"]
	var i := clampi(loadout, 0, 3)
	return make_card(
		WeaponDefs.explorer_loadout_name(loadout),
		hints[i],
		accents[i],
		selected,
		UiIcons.loadout_tex(i),
		UiIcons.LOADOUT_EMOJI[i],
		Vector2(104, 128),
		72.0
	)


static func make_map_card(map_id: String, selected: bool) -> PanelContainer:
	var accent := Color(0.2, 0.7, 0.85)
	var sub := "Neon"
	match map_id:
		"containers":
			accent = Color(0.85, 0.45, 0.2)
			sub = "Pasillos"
		"ruins":
			accent = Color(0.7, 0.3, 0.55)
			sub = "Vertical"
		_:
			accent = Color(0.2, 0.7, 0.85)
			sub = "Arena abierta"
	var emoji: String = str(UiIcons.MAP_EMOJI.get(map_id, "🗺️"))
	return make_card(
		NetworkManager.MAP_NAMES.get(map_id, map_id),
		sub,
		accent,
		selected,
		UiIcons.map_tex(map_id),
		emoji,
		Vector2(128, 132),
		70.0
	)


static func make_beast_card(variant: int, selected: bool) -> PanelContainer:
	var accent := Color(0.85, 0.15, 0.2)
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
	return make_card(
		title,
		sub,
		accent,
		selected,
		UiIcons.beast_tex(variant),
		UiIcons.beast_emoji(variant),
		Vector2(110, 128),
		78.0
	)

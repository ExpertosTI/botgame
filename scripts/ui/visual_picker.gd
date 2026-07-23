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
	icon_h: float = 72.0,
	locked: bool = false
) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	card.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_POINTING_HAND
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("locked", locked)
	var edge := Color.WHITE if selected else accent.darkened(0.1)
	var bg := Color(0.05, 0.07, 0.09, 0.95)
	if selected:
		bg = accent.darkened(0.55).lerp(Color(0.08, 0.1, 0.12), 0.4)
	if locked:
		bg = Color(0.06, 0.06, 0.07, 0.92)
		edge = Color(0.25, 0.25, 0.28)
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

	if not subtitle.is_empty() or locked:
		var s := Label.new()
		s.text = "BLOQUEADO" if locked else subtitle
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.add_theme_font_size_override("font_size", 11)
		s.add_theme_color_override("font_color", Color(0.75, 0.45, 0.35) if locked else GameTheme.C_MUTED)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(s)

	if locked:
		card.modulate = Color(0.55, 0.55, 0.58, 1.0)

	return card


static func make_skin_card(skin: int, selected: bool, locked: bool = false) -> PanelContainer:
	var entry: Dictionary = {}
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		entry = CharacterCatalog.get_entry(skin)
	var tint: Color = entry.get("tint", Color(0.25, 0.55, 1.0)) if not entry.is_empty() else Color(0.25, 0.55, 1.0)
	var title: String = str(entry.get("name", WeaponDefs.explorer_skin_name(skin % 4))) if not entry.is_empty() else WeaponDefs.explorer_skin_name(skin % 4)
	var mobile := _is_narrow()
	var role := str(entry.get("role", "explorer"))
	var sub := "BESTIA" if role == "beast" else "ROBOT"
	if not str(entry.get("mesh", "")).is_empty():
		sub = "3D · " + sub
	return make_card(
		title,
		sub,
		tint,
		selected,
		UiIcons.catalog_tex(skin),
		"",
		Vector2(96 if mobile else 88, 136 if mobile else 128),
		92.0 if mobile else 78.0,
		locked
	)


static func _is_narrow() -> bool:
	var tre := Engine.get_main_loop() as SceneTree
	if tre == null or tre.root == null:
		return false
	return tre.root.get_visible_rect().size.x < 780


static func make_loadout_card(loadout: int, selected: bool, locked: bool = false) -> PanelContainer:
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
		72.0,
		locked
	)


static func make_map_card(map_id: String, selected: bool, locked: bool = false) -> PanelContainer:
	var accent := Color(0.2, 0.7, 0.85)
	var sub := "Neon"
	match map_id:
		"containers":
			accent = Color(0.85, 0.45, 0.2)
			sub = "Pasillos"
		"ruins":
			accent = Color(0.7, 0.3, 0.55)
			sub = "Vertical"
		"reactor_pit":
			accent = Color(1.0, 0.35, 0.12)
			sub = "Zona caliente"
		"skybridge":
			accent = Color(0.4, 0.7, 1.0)
			sub = "Puentes"
		"castle":
			accent = Color(0.75, 0.65, 0.4)
			sub = "Murallas"
		"cave":
			accent = Color(0.55, 0.4, 0.3)
			sub = "Túneles"
		"forest":
			accent = Color(0.35, 0.7, 0.4)
			sub = "Árboles"
		_:
			accent = Color(0.2, 0.7, 0.85)
			sub = "Arena abierta"
	var emoji: String = ""
	var map_icon := UiIcons.map_tex(map_id)
	if map_icon == null:
		emoji = str(UiIcons.MAP_EMOJI.get(map_id, ""))
	return make_card(
		NetworkManager.MAP_NAMES.get(map_id, map_id),
		sub,
		accent,
		selected,
		map_icon,
		emoji,
		Vector2(128, 132),
		70.0,
		locked
	)


static func make_beast_card(variant: int, selected: bool, locked: bool = false) -> PanelContainer:
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
		78.0,
		locked
	)

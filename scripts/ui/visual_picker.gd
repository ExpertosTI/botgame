class_name VisualPicker
extends RefCounted

## Tarjetas del hangar: retratos reales (UiIcons), no iniciales HTML.
## Un solo preview 3D vive en el stage grande del menú.


static func make_card(
	title: String,
	subtitle: String,
	accent: Color,
	selected: bool,
	icon: Texture2D = null,
	_emoji: String = "",
	min_size: Vector2 = Vector2(112, 140),
	icon_h: float = 80.0,
	locked: bool = false,
	icon_control: Control = null
) -> Button:
	var card := Button.new()
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = min_size
	card.disabled = locked
	card.set_meta("locked", locked)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var edge := accent.lightened(0.35) if selected else accent.darkened(0.15)
	var bg := Color(0.06, 0.1, 0.12, 0.94)
	if selected:
		bg = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.96)
	if locked:
		bg = Color(0.06, 0.06, 0.07, 0.92)
		edge = Color(0.28, 0.28, 0.3)
	card.add_theme_stylebox_override("normal", GameTheme.panel_style(bg, edge, 18, 3 if selected else 1))
	card.add_theme_stylebox_override("hover", GameTheme.panel_style(bg.lightened(0.08), accent.lightened(0.2), 18, 2))
	card.add_theme_stylebox_override("pressed", GameTheme.panel_style(accent.darkened(0.45), Color.WHITE, 18, 2))
	card.add_theme_stylebox_override("disabled", GameTheme.panel_style(Color(0.05, 0.05, 0.06), Color(0.22, 0.22, 0.24), 18, 1))

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 4)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pad)

	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(0, icon_h)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon_wrap)

	if icon_control != null:
		icon_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if locked:
			icon_control.modulate = Color(0.45, 0.45, 0.5, 0.85)
		icon_wrap.add_child(icon_control)
	elif icon != null:
		var frame := PanelContainer.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.custom_minimum_size = Vector2(icon_h, icon_h)
		frame.add_theme_stylebox_override(
			"panel",
			GameTheme.panel_style(Color(0.02, 0.04, 0.05, 0.9), accent.darkened(0.2), 14, 1)
		)
		var tr := TextureRect.new()
		tr.texture = icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size = Vector2(icon_h - 6, icon_h - 6)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if locked:
			tr.modulate = Color(0.5, 0.5, 0.55, 0.8)
		frame.add_child(tr)
		icon_wrap.add_child(frame)
	else:
		icon_wrap.add_child(badge_mark(accent, icon_h * 0.9, title))

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color.WHITE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)

	var s := Label.new()
	s.text = "BLOQUEADO" if locked else subtitle
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 11)
	s.add_theme_color_override("font_color", Color(0.9, 0.45, 0.35) if locked else GameTheme.C_MUTED)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(s)
	return card


static func _narrow() -> bool:
	var tre := Engine.get_main_loop() as SceneTree
	return tre != null and tre.root != null and tre.root.get_visible_rect().size.x < 900


## Fallback solo si no hay retrato.
static func badge_mark(accent: Color, h: float, title: String) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(h, h)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override(
		"panel",
		GameTheme.panel_style(accent.darkened(0.35), accent.lightened(0.15), 12, 2)
	)
	var lb := Label.new()
	lb.text = title.substr(0, 1).to_upper() if not title.is_empty() else "?"
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", int(h * 0.42))
	lb.add_theme_color_override("font_color", Color.WHITE)
	if GameTheme.font_title():
		lb.add_theme_font_override("font", GameTheme.font_title())
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lb)
	return box


static func make_skin_card(skin: int, selected: bool, locked: bool = false) -> Button:
	var entry := CharacterCatalog.get_entry(skin) if Engine.get_main_loop() else {}
	var tint: Color = entry.get("tint", Color(0.25, 0.55, 1.0)) if not entry.is_empty() else Color(0.25, 0.55, 1.0)
	var title := str(entry.get("name", "?")) if not entry.is_empty() else "?"
	var sub := "LISTO" if selected else ("BESTIA" if str(entry.get("role", "")) == "beast" else "UNIDAD")
	var m := _narrow()
	var h := 92.0 if m else 78.0
	var portrait := UiIcons.catalog_tex(skin)
	return make_card(
		title, sub, tint, selected, portrait, "",
		Vector2(128 if m else 108, 168 if m else 148), h, locked, null
	)


static func make_loadout_card(loadout: int, selected: bool, locked: bool = false) -> Button:
	var accents := [Color(0.25, 0.85, 0.9), Color(1.0, 0.75, 0.2), Color(0.95, 0.35, 0.25), Color(0.45, 0.75, 1.0)]
	var hints := ["Bláster+", "Escopeta+", "Granadas+", "Hielo+"]
	var i := clampi(loadout, 0, 3)
	var name_s := WeaponDefs.explorer_loadout_name(loadout)
	var m := _narrow()
	var h := 72.0 if m else 64.0
	var portrait := UiIcons.loadout_tex(loadout)
	return make_card(
		name_s, hints[i], accents[i], selected, portrait, "",
		Vector2(118 if m else 104, 148 if m else 132), h, locked, null
	)


static func make_map_card(map_id: String, selected: bool, locked: bool = false) -> Button:
	var accent := Color(0.2, 0.7, 0.85)
	var sub := "Arena"
	match map_id:
		"containers":
			accent = Color(0.85, 0.45, 0.2); sub = "Pasillos"
		"ruins":
			accent = Color(0.7, 0.3, 0.55); sub = "Vertical"
		"reactor_pit":
			accent = Color(1.0, 0.35, 0.12); sub = "Caliente"
		"skybridge":
			accent = Color(0.4, 0.7, 1.0); sub = "Puentes"
		"castle":
			accent = Color(0.75, 0.65, 0.4); sub = "Murallas"
		"cave":
			accent = Color(0.55, 0.4, 0.3); sub = "Túneles"
		"forest":
			accent = Color(0.35, 0.7, 0.4); sub = "Bosque"
	var m := _narrow()
	var name_s := str(NetworkManager.MAP_NAMES.get(map_id, map_id))
	var h := 80.0 if m else 70.0
	var portrait := UiIcons.map_tex(map_id)
	return make_card(
		name_s, sub, accent, selected, portrait, "",
		Vector2(136 if m else 116, 156 if m else 138), h, locked, null
	)


static func make_beast_card(variant: int, selected: bool, locked: bool = false) -> Button:
	var accent := Color(0.85, 0.15, 0.2)
	var title := "Clásica"
	var sub := "Garras"
	match variant:
		GameManager.BeastVariant.MECHA:
			accent = Color(0.55, 0.55, 0.6); title = "Mecha"; sub = "Slam"
		GameManager.BeastVariant.SHADOW:
			accent = Color(0.45, 0.2, 0.7); title = "Sombra"; sub = "Camuflaje"
	var m := _narrow()
	var h := 92.0 if m else 78.0
	var portrait := UiIcons.beast_tex(variant)
	return make_card(
		title, sub, accent, selected, portrait, "",
		Vector2(128 if m else 108, 168 if m else 148), h, locked, null
	)

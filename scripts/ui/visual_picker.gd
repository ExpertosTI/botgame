class_name VisualPicker
extends RefCounted

## Tarjetas = Button (toques fiables). Skins = preview 3D, no JPG.


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

	var edge := Color.WHITE if selected else accent
	var bg := accent.darkened(0.5) if selected else Color(0.05, 0.08, 0.1, 0.95)
	if locked:
		bg = Color(0.07, 0.07, 0.08, 0.9)
		edge = Color(0.3, 0.3, 0.32)
	card.add_theme_stylebox_override("normal", GameTheme.panel_style(bg, edge, 14, 3 if selected else 2))
	card.add_theme_stylebox_override("hover", GameTheme.panel_style(bg.lightened(0.1), accent, 14, 3))
	card.add_theme_stylebox_override("pressed", GameTheme.panel_style(accent.darkened(0.4), Color.WHITE, 14, 3))
	card.add_theme_stylebox_override("disabled", GameTheme.panel_style(Color(0.06, 0.06, 0.07), Color(0.25, 0.25, 0.28), 14, 1))

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
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
		var tr := TextureRect.new()
		tr.texture = icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(icon_h, icon_h)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_wrap.add_child(tr)
	else:
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(icon_h * 0.85, icon_h * 0.55)
		sw.color = accent
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_wrap.add_child(sw)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", Color.WHITE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)

	var s := Label.new()
	s.text = "BLOQUEADO" if locked else subtitle
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 12)
	s.add_theme_color_override("font_color", Color(0.9, 0.45, 0.35) if locked else GameTheme.C_MUTED)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(s)
	return card


static func _narrow() -> bool:
	var tre := Engine.get_main_loop() as SceneTree
	return tre != null and tre.root != null and tre.root.get_visible_rect().size.x < 780


static func _skin_thumb(skin: int, selected: bool, h: float) -> Control:
	var thumb := CatalogThumb.new()
	thumb.setup(skin, h, selected)
	return thumb


static func _map_mark(accent: Color, h: float, label: String) -> Control:
	## Marca de mapa procedural (sin JPG).
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(h, h * 0.72)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override(
		"panel",
		GameTheme.panel_style(accent.darkened(0.55), accent, 10, 2)
	)
	var lb := Label.new()
	lb.text = label.substr(0, 1).to_upper()
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", int(h * 0.42))
	lb.add_theme_color_override("font_color", Color.WHITE)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lb)
	return box


static func make_skin_card(skin: int, selected: bool, locked: bool = false) -> Button:
	var entry := CharacterCatalog.get_entry(skin) if Engine.get_main_loop() else {}
	var tint: Color = entry.get("tint", Color(0.25, 0.55, 1.0)) if not entry.is_empty() else Color(0.25, 0.55, 1.0)
	var title := str(entry.get("name", "?")) if not entry.is_empty() else "?"
	var sub := "3D" if not str(entry.get("mesh", "")).is_empty() else "ROBOT"
	if str(entry.get("role", "")) == "beast":
		sub = "BESTIA"
	var m := _narrow()
	var h := 96.0 if m else 84.0
	var thumb := _skin_thumb(skin, selected and not locked, h)
	return make_card(
		title, sub, tint, selected, null, "",
		Vector2(124 if m else 110, 168 if m else 150), h, locked, thumb
	)


static func make_loadout_card(loadout: int, selected: bool, locked: bool = false) -> Button:
	var accents := [Color(0.25, 0.85, 0.9), Color(1.0, 0.75, 0.2), Color(0.95, 0.35, 0.25), Color(0.45, 0.75, 1.0)]
	var hints := ["Bláster+", "Escopeta+", "Granadas+", "Hielo+"]
	var i := clampi(loadout, 0, 3)
	return make_card(
		WeaponDefs.explorer_loadout_name(loadout), hints[i], accents[i], selected,
		UiIcons.loadout_tex(i), "", Vector2(112, 136), 72.0, locked
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
	var h := 78.0
	var mark := _map_mark(accent, h, name_s)
	return make_card(
		name_s, sub, accent, selected, null, "",
		Vector2(136 if m else 120, 152 if m else 136), h, locked, mark
	)


static func make_beast_card(variant: int, selected: bool, locked: bool = false) -> Button:
	var accent := Color(0.85, 0.15, 0.2)
	var title := "Clásica"
	var sub := "Garras"
	var cat_id := "beast_classic"
	match variant:
		GameManager.BeastVariant.MECHA:
			accent = Color(0.55, 0.55, 0.6); title = "Mecha"; sub = "Slam"; cat_id = "beast_mecha"
		GameManager.BeastVariant.SHADOW:
			accent = Color(0.45, 0.2, 0.7); title = "Sombra"; sub = "Cloak"; cat_id = "beast_shadow"
	var idx := CharacterCatalog.index_of_id(cat_id)
	var thumb := _skin_thumb(idx if idx >= 0 else 0, selected and not locked, 84.0)
	return make_card(title, sub, accent, selected, null, "", Vector2(118, 150), 84.0, locked, thumb)

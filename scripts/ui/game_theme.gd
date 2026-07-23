class_name GameTheme
extends RefCounted

## Tema visual industrial: cyan hangar + ámbar alerta + crimson bestia.
## Fuentes free: Orbitron (títulos) + Rajdhani (UI) — OFL.

const C_BG := Color(0.035, 0.045, 0.06, 1.0)
const C_PANEL := Color(0.06, 0.09, 0.12, 0.92)
const C_PANEL_EDGE := Color(0.18, 0.75, 0.7, 0.85)
const C_BTN := Color(0.08, 0.14, 0.18, 1.0)
const C_BTN_HOVER := Color(0.12, 0.28, 0.3, 1.0)
const C_BTN_PRESS := Color(0.05, 0.2, 0.22, 1.0)
const C_PRIMARY := Color(0.08, 0.55, 0.5, 1.0)
const C_PRIMARY_HOVER := Color(0.12, 0.7, 0.62, 1.0)
const C_DANGER := Color(0.55, 0.12, 0.16, 1.0)
const C_DANGER_HOVER := Color(0.75, 0.18, 0.22, 1.0)
const C_TEXT := Color(0.9, 0.95, 0.97, 1.0)
const C_MUTED := Color(0.55, 0.68, 0.72, 1.0)
const C_AMBER := Color(1.0, 0.72, 0.2, 1.0)
const C_CYAN := Color(0.2, 0.9, 0.82, 1.0)
const C_CRIMSON := Color(1.0, 0.32, 0.36, 1.0)

static var _theme: Theme
static var _font_title: FontFile
static var _font_ui: FontFile
static var _font_ui_bold: FontFile


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func apply(root: Control) -> void:
	root.theme = get_theme()


static func font_title() -> Font:
	_ensure_fonts()
	return _font_title


static func font_ui() -> Font:
	_ensure_fonts()
	return _font_ui


static func _ensure_fonts() -> void:
	if _font_title == null and ResourceLoader.exists("res://assets/fonts/Orbitron-Bold.ttf"):
		_font_title = load("res://assets/fonts/Orbitron-Bold.ttf") as FontFile
	if _font_ui == null and ResourceLoader.exists("res://assets/fonts/Rajdhani-Regular.ttf"):
		_font_ui = load("res://assets/fonts/Rajdhani-Regular.ttf") as FontFile
	if _font_ui_bold == null and ResourceLoader.exists("res://assets/fonts/Rajdhani-SemiBold.ttf"):
		_font_ui_bold = load("res://assets/fonts/Rajdhani-SemiBold.ttf") as FontFile


static func _build() -> Theme:
	_ensure_fonts()
	var t := Theme.new()
	if _font_ui:
		t.default_font = _font_ui
	t.default_font_size = 18

	t.set_stylebox("panel", "PanelContainer", _panel(C_PANEL, C_PANEL_EDGE, 14, 2))
	t.set_stylebox("panel", "Panel", _panel(C_PANEL, C_PANEL_EDGE, 12, 2))

	t.set_stylebox("normal", "Button", _btn(C_BTN, C_PANEL_EDGE, 10))
	t.set_stylebox("hover", "Button", _btn(C_BTN_HOVER, C_CYAN, 10))
	t.set_stylebox("pressed", "Button", _btn(C_BTN_PRESS, C_CYAN.darkened(0.2), 10))
	t.set_stylebox("disabled", "Button", _btn(Color(0.08, 0.08, 0.1, 0.7), Color(0.3, 0.3, 0.35, 0.5), 10))
	t.set_stylebox("focus", "Button", _btn(C_BTN_HOVER, C_AMBER, 10))
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", C_CYAN)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.5, 0.52))
	if _font_ui_bold:
		t.set_font("font", "Button", _font_ui_bold)
	t.set_font_size("font_size", "Button", 20)
	t.set_constant("h_separation", "Button", 8)

	t.set_stylebox("normal", "LineEdit", _panel(Color(0.03, 0.05, 0.07, 0.95), Color(0.25, 0.45, 0.48, 0.8), 8, 1))
	t.set_stylebox("focus", "LineEdit", _panel(Color(0.04, 0.07, 0.09, 0.98), C_CYAN, 8, 2))
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", C_MUTED)
	t.set_font_size("font_size", "LineEdit", 18)
	t.set_constant("minimum_character_width", "LineEdit", 1)

	t.set_stylebox("normal", "OptionButton", _btn(C_BTN, C_PANEL_EDGE, 8))
	t.set_stylebox("hover", "OptionButton", _btn(C_BTN_HOVER, C_CYAN, 8))
	t.set_stylebox("pressed", "OptionButton", _btn(C_BTN_PRESS, C_CYAN, 8))
	t.set_color("font_color", "OptionButton", C_TEXT)
	t.set_font_size("font_size", "OptionButton", 18)

	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckBox", C_MUTED)
	t.set_color("font_hover_color", "CheckBox", C_TEXT)
	t.set_color("font_pressed_color", "CheckBox", C_CYAN)

	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	if _font_ui:
		t.set_font("font", "Label", _font_ui)

	return t


static func _panel(bg: Color, border: Color, radius: float, border_w: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(int(border_w))
	s.set_corner_radius_all(int(radius))
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	return s


static func _btn(bg: Color, border: Color, radius: float) -> StyleBoxFlat:
	var s := _panel(bg, border, radius, 2)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.shadow_size = 4
	return s


static func style_touch(btn: Button, accent: Color = C_CYAN) -> void:
	## Controles táctiles: vidrio + borde (no cuadrados planos opacos).
	var bg := Color(0.04, 0.08, 0.1, 0.55)
	var hover := Color(accent.r, accent.g, accent.b, 0.35).lerp(bg, 0.35)
	var press := Color(accent.r, accent.g, accent.b, 0.55).lerp(Color(0.02, 0.04, 0.05, 0.75), 0.3)
	btn.add_theme_stylebox_override("normal", _btn(bg, accent.darkened(0.15), 16))
	btn.add_theme_stylebox_override("hover", _btn(hover, accent, 16))
	btn.add_theme_stylebox_override("pressed", _btn(press, Color.WHITE, 16))
	btn.add_theme_color_override("font_color", Color(0.92, 0.98, 0.98, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", accent.lightened(0.35))
	if font_ui():
		btn.add_theme_font_override("font", font_ui())


static func style_primary(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _btn(C_PRIMARY, C_CYAN, 10))
	btn.add_theme_stylebox_override("hover", _btn(C_PRIMARY_HOVER, Color.WHITE, 10))
	btn.add_theme_stylebox_override("pressed", _btn(C_PRIMARY.darkened(0.15), C_CYAN, 10))
	btn.add_theme_color_override("font_color", Color(0.05, 0.12, 0.12))
	btn.add_theme_color_override("font_hover_color", Color(0.02, 0.08, 0.08))


static func style_danger(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _btn(C_DANGER, C_CRIMSON, 10))
	btn.add_theme_stylebox_override("hover", _btn(C_DANGER_HOVER, Color.WHITE, 10))
	btn.add_theme_stylebox_override("pressed", _btn(C_DANGER.darkened(0.2), C_CRIMSON, 10))


static func style_title(label: Label, size: int = 42) -> void:
	if font_title():
		label.add_theme_font_override("font", font_title())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", C_TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0.1, 0.7, 0.65, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.22, 0.9))


static func style_muted(label: Label, size: int = 16) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", C_MUTED)


static func panel_style(bg: Color, border: Color, radius: float = 10, border_w: float = 2) -> StyleBoxFlat:
	return _panel(bg, border, radius, border_w)


static func make_player_card(name_text: String, role: String, ready: bool, skin: int = 0) -> PanelContainer:
	var card := PanelContainer.new()
	var is_beast := role == "beast"
	var edge := C_CRIMSON if is_beast else (C_CYAN if role == "explorer" else Color(0.4, 0.45, 0.5))
	if ready:
		edge = Color(0.25, 0.95, 0.55)
	var bg := Color(0.12, 0.05, 0.06, 0.92) if is_beast else Color(0.05, 0.1, 0.12, 0.92)
	if ready:
		bg = Color(0.04, 0.14, 0.1, 0.95)
	card.add_theme_stylebox_override("panel", _panel(bg, edge, 12, 3 if ready else 1))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var portrait_wrap := PanelContainer.new()
	portrait_wrap.custom_minimum_size = Vector2(56, 56)
	portrait_wrap.add_theme_stylebox_override(
		"panel",
		_panel(Color(0.02, 0.04, 0.06, 0.9), edge.darkened(0.2), 8, 1)
	)
	row.add_child(portrait_wrap)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(52, 52)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if is_beast:
		var bid := CharacterCatalog.index_of_id("beast_classic")
		if GameManager.beast_variant == GameManager.BeastVariant.MECHA:
			bid = CharacterCatalog.index_of_id("beast_mecha")
		elif GameManager.beast_variant == GameManager.BeastVariant.SHADOW:
			bid = CharacterCatalog.index_of_id("beast_shadow")
		portrait.texture = UiIcons.catalog_tex(bid)
	elif role == "explorer":
		portrait.texture = UiIcons.catalog_tex(skin)
	else:
		portrait.modulate = Color(0.5, 0.5, 0.55)
		portrait.texture = UiIcons.catalog_tex(0)
	portrait_wrap.add_child(portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	var name_l := Label.new()
	name_l.text = name_text
	if _font_ui_bold:
		name_l.add_theme_font_override("font", _font_ui_bold)
	name_l.add_theme_font_size_override("font_size", 17)
	col.add_child(name_l)

	var role_l := Label.new()
	var role_txt := "BESTIA" if is_beast else ("ROBOT" if role == "explorer" else "SIN ROL")
	role_l.text = role_txt + ("  ·  LISTO" if ready else "  ·  esperando…")
	role_l.add_theme_font_size_override("font_size", 13)
	role_l.add_theme_color_override("font_color", edge if ready else C_MUTED)
	col.add_child(role_l)

	if ready:
		var badge := Label.new()
		badge.text = "✓"
		badge.add_theme_font_size_override("font_size", 28)
		badge.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(badge)

	return card

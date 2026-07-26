class_name HowToPlay
extends CanvasLayer

## Explicación de las reglas antes de la primera partida.
##
## Hasta ahora lo único que recibía un jugador nuevo era un aviso de seis
## segundos ya dentro del teatro, con el 3D cargado y la Bestia buscándole. Nadie
## sabía qué era un núcleo ni que hay que MANTENER pulsado para sabotearlo.
##
## Se abre solo la primera vez (SettingsManager.tutorial_seen) y luego queda a
## mano en el botón del hangar. No bloquea nada: es un panel que se cierra.

signal closed

const SECTIONS := [
	{
		"title": "EL TRATO",
		"body": "Una Bestia contra la tripulación de robots. Partidas de dos a "
			+ "cuatro minutos. Sin cuenta y sin descargar nada.",
	},
	{
		"title": "SI ERES ROBOT",
		"body": "Sabotea los núcleos antes de que se acabe el reloj. Apunta y "
			+ "MANTÉN pulsado. Si te pegan, se corta. Blindado: dispara el "
			+ "escudo primero. Relé: solo en ventana amarilla. Sobrecarga: al "
			+ "caer detona cerca. Tienes dos vidas.",
	},
	{
		"title": "SI ERES LA BESTIA",
		"body": "Gana el reloj. Interrumpe canalizaciones con daño. El melee "
			+ "avisa con un anillo naranja. Agota las vidas de la tripulación "
			+ "y ganas antes.",
	},
	{
		"title": "COORDINACIÓN",
		"body": "V o botón PING marca el teatro: Ayuda, Bestia aquí o Saboteando. "
			+ "La flecha del HUD te lleva al núcleo más cercano.",
	},
	{
		"title": "ARENA",
		"body": "Orbes: escudo, turbo, reparación, sobrecarga. Zonas rojas "
			+ "queman; azules ralentizan; magenta pulsan. Mina (habilidad) "
			+ "arma tras un segundo. 1-4: dash, escudo, EMP, camouflage…",
	},
	{
		"title": "CONTROLES",
		"body": "",
	},
]


func _ready() -> void:
	layer = 64
	_build()


func _controls_text() -> String:
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		return (
			"Stick · DISPARO · mantén en núcleo · PING · ⏸ pausa."
		)
	return (
		"WASD · clic disparo · Q arma · 1-4 habilidades · G dash · V ping · "
		+ "mantén en núcleo · Esc pausa · F3 diagnóstico."
	)


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.88)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(min(560.0, _viewport_width() - 40.0), 0)
	card.add_theme_stylebox_override(
		"panel", GameTheme.panel_style(Color(0.03, 0.06, 0.08, 0.98), GameTheme.C_CYAN, 14, 2)
	)
	center.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var head := Label.new()
	head.text = "CÓMO SE JUEGA"
	GameTheme.style_title(head, 28)
	col.add_child(head)

	for section in SECTIONS:
		var t := Label.new()
		t.text = str(section["title"])
		t.add_theme_font_size_override("font_size", 15)
		t.add_theme_color_override("font_color", GameTheme.C_CYAN)
		col.add_child(t)

		var b := Label.new()
		b.text = _controls_text() if str(section["body"]).is_empty() else str(section["body"])
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", GameTheme.C_MUTED)
		col.add_child(b)

	var close := Button.new()
	close.text = "ENTENDIDO"
	close.custom_minimum_size = Vector2(0, 54)
	GameTheme.style_primary(close)
	close.pressed.connect(_on_close)
	col.add_child(close)


func _viewport_width() -> float:
	var vp := get_viewport()
	return vp.get_visible_rect().size.x if vp != null else 560.0


func _on_close() -> void:
	SettingsManager.mark_tutorial_seen()
	closed.emit()
	queue_free()


## Lo abre quien lo necesite; devuelve la instancia ya montada.
static func present(host: Node) -> HowToPlay:
	var panel := HowToPlay.new()
	host.add_child(panel)
	return panel

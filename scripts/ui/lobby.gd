extends Control

@onready var player_list: VBoxContainer = %PlayerList
@onready var ready_button: Button = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var role_beast_button: Button = %BeastRoleButton
@onready var role_robot_button: Button = %RobotRoleButton
@onready var skin_row: HBoxContainer = %SkinRow
@onready var loadout_row: HBoxContainer = %LoadoutRow
@onready var map_row: HBoxContainer = %MapRow
@onready var beast_row: HBoxContainer = %BeastRow
@onready var skin_title: Label = %SkinTitle
@onready var loadout_title: Label = %LoadoutTitle
@onready var variant_title: Label = %VariantTitle
@onready var loadout_hint: Label = %LoadoutHint
@onready var status_label: Label = %StatusLabel
@onready var easy_check: CheckBox = %EasyBeastCheck
@onready var campaign_check: CheckBox = %CampaignCheck
@onready var campaign_label: Label = %CampaignLabel
@onready var level_row: HBoxContainer = %LevelRow
@onready var level_title: Label = %LevelTitle
@onready var title: Label = %Title
@onready var wait_label: Label = %WaitLabel
@onready var atmosphere: ColorRect = %Atmosphere
@onready var map_hint: Label = %MapHint
@onready var hangar_slot: Control = %HangarSlot
@onready var main_scroll: ScrollContainer = %MainScroll
@onready var content: VBoxContainer = %Content
@onready var crew_panel: Control = %CrewPanel
@onready var setup_panel: Control = %SetupPanel

const GAME_SCENE := "res://scenes/main/game.tscn"
const HANGAR_SCRIPT := preload("res://scripts/ui/lobby_hangar.gd")
const LOADOUT_HINTS := [
	"Bláster · Granada · Rayo Hielo · Plasma",
	"Escopeta · Granada · Bláster · Plasma",
	"Granada · Plasma · Bláster · Escopeta",
	"Rayo Hielo · Bláster · Granada · Plasma",
]

var local_ready := false
var _pulse_t := 0.0
var _skin := -1
var _loadout := 0
var _map_idx := 0
var _beast_variant := GameManager.BeastVariant.MECHA
var _hangar: LobbyHangar
var _syncing_checks := false


func _ready() -> void:
	if _skin < 0:
		_skin = CharacterCatalog.default_explorer_skin()
	GameTheme.apply(self)
	_style_ui()
	_setup_atmosphere()
	if main_scroll:
		main_scroll.scroll_deadzone = 40

	ready_button.pressed.connect(_on_ready_pressed)
	start_button.pressed.connect(_on_start_pressed)
	role_beast_button.pressed.connect(_on_pick_beast)
	role_robot_button.pressed.connect(_on_pick_robot)
	easy_check.toggled.connect(_on_easy_toggled)
	campaign_check.toggled.connect(_on_campaign_toggled)

	NetworkManager.players_updated.connect(_refresh_player_list)
	NetworkManager.player_connected.connect(func(_a, _b): _refresh_player_list())
	NetworkManager.player_disconnected.connect(func(_a): _refresh_player_list())
	NetworkManager.lobby_settings_changed.connect(_on_settings_changed)
	NetworkManager.match_start_requested.connect(_on_match_start)
	ProgressionManager.progress_changed.connect(_on_progress_changed)

	_rebuild_all_pickers()
	_setup_hangar()
	_rebuild_levels()
	_refresh_player_list()
	_update_robot_sections_visibility()
	_update_hangar_preview()
	_update_campaign_ui()
	_apply_solo_lobby()
	call_deferred("_fit_content_width")
	call_deferred("_adapt_mobile_lobby")

	if NetworkManager.is_dedicated_server:
		status_label.text = "Servidor dedicado — esperando tripulación"
		ready_button.visible = false
		role_beast_button.visible = false
		role_robot_button.visible = false
		skin_row.visible = false
		loadout_row.visible = false
		setup_panel.visible = false


func _apply_solo_lobby() -> void:
	if not NetworkManager.is_solo_practice:
		return
	title.text = "PRÁCTICA · CHADRINE"
	wait_label.text = "Elige rol, arsenal y pulsa JUGAR NIVEL"
	ready_button.visible = false
	local_ready = true
	_syncing_checks = true
	campaign_check.button_pressed = true
	campaign_check.disabled = true
	_syncing_checks = false
	ProgressionManager.campaign_mode = true
	# No pisar el teatro ya elegido en el hangar
	if NetworkManager.selected_map not in NetworkManager.MAP_IDS:
		NetworkManager.selected_map = ProgressionManager.force_campaign_map()
	var map_idx := NetworkManager.MAP_IDS.find(NetworkManager.selected_map)
	if map_idx >= 0:
		_map_idx = map_idx
	_skin = CharacterCatalog.default_explorer_skin()
	if NetworkManager.players.has(1):
		NetworkManager.players[1]["skin"] = _skin
	start_button.text = "JUGAR NIVEL"
	start_button.disabled = false
	GameTheme.style_primary(start_button)
	_rebuild_maps()
	_update_map_hint()
	_update_campaign_ui()
	_rebuild_levels()
	# Rol por defecto robot
	if _local_role() == "":
		NetworkManager.submit_role("explorer")
	_update_robot_sections_visibility()
	_check_can_start()
	call_deferred("_scroll_to_setup")


func _scroll_to_setup() -> void:
	if main_scroll and setup_panel:
		main_scroll.ensure_control_visible(setup_panel)


func _style_ui() -> void:
	GameTheme.style_title(title, 34)
	GameTheme.style_muted(wait_label, 15)
	GameTheme.style_danger(role_beast_button)
	GameTheme.style_primary(role_robot_button)
	GameTheme.style_primary(start_button)
	role_beast_button.text = "SOY LA BESTIA"
	role_robot_button.text = "SOY ROBOT"
	ready_button.text = "MARCAR LISTO"
	start_button.text = "EMPEZAR PARTIDA"
	role_beast_button.icon = UiIcons.beast_tex(GameManager.BeastVariant.CLASSIC)
	role_robot_button.icon = UiIcons.skin_tex(0)
	role_beast_button.expand_icon = true
	role_robot_button.expand_icon = true
	role_beast_button.add_theme_constant_override("icon_max_width", 40)
	role_robot_button.add_theme_constant_override("icon_max_width", 40)
	role_beast_button.custom_minimum_size = Vector2(0, 56)
	role_robot_button.custom_minimum_size = Vector2(0, 56)
	start_button.custom_minimum_size = Vector2(0, 64)
	map_hint.add_theme_color_override("font_color", GameTheme.C_MUTED)
	loadout_hint.add_theme_color_override("font_color", GameTheme.C_MUTED)
	campaign_label.add_theme_color_override("font_color", GameTheme.C_CYAN)
	if crew_panel:
		(crew_panel as PanelContainer).add_theme_stylebox_override(
			"panel",
			GameTheme.panel_style(Color(0.04, 0.07, 0.09, 0.5), GameTheme.C_CYAN, 12, 2)
		)
	if setup_panel:
		(setup_panel as PanelContainer).add_theme_stylebox_override(
			"panel",
			GameTheme.panel_style(Color(0.05, 0.08, 0.1, 0.58), GameTheme.C_AMBER.darkened(0.3), 12, 2)
		)
	var tw := create_tween().set_loops()
	tw.tween_property(start_button, "modulate", Color(0.88, 1.0, 0.96), 0.95).set_trans(Tween.TRANS_SINE)
	tw.tween_property(start_button, "modulate", Color.WHITE, 0.95).set_trans(Tween.TRANS_SINE)


func _setup_atmosphere() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ui_mobile_bg.gdshader")
	atmosphere.material = mat


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_content_width()
		_adapt_mobile_lobby()


func _process(delta: float) -> void:
	_pulse_t += delta
	if NetworkManager.is_solo_practice:
		wait_label.modulate.a = 0.75 + 0.25 * sin(_pulse_t * 2.0)
		wait_label.text = "Práctica · elige rol abajo · JUGAR NIVEL siempre visible"
		return
	wait_label.modulate.a = 0.65 + 0.35 * sin(_pulse_t * 2.4)
	wait_label.text = "Esperando tripulación" + ".".repeat(int(_pulse_t * 2.0) % 4)


func _fit_content_width() -> void:
	if content == null or main_scroll == null:
		return
	var w := main_scroll.size.x
	if w < 8.0:
		w = size.x - 24.0
	content.custom_minimum_size = Vector2(maxi(int(w), 280), 0)


func _adapt_mobile_lobby() -> void:
	var narrow := size.x < 780
	if hangar_slot:
		hangar_slot.custom_minimum_size = Vector2(0, 120 if narrow else 160)
	if narrow:
		ready_button.custom_minimum_size = Vector2(0, 56)
		start_button.custom_minimum_size = Vector2(0, 64)
		start_button.add_theme_font_size_override("font_size", 22)
		role_beast_button.custom_minimum_size = Vector2(0, 72)
		role_robot_button.custom_minimum_size = Vector2(0, 72)
		skin_row.add_theme_constant_override("separation", 6)
		loadout_row.add_theme_constant_override("separation", 6)
		map_row.add_theme_constant_override("separation", 6)
		beast_row.add_theme_constant_override("separation", 6)
		GameTheme.style_title(title, 26)
		# En práctica, hangar más compacto para ver pickers antes
		if NetworkManager.is_solo_practice and hangar_slot:
			hangar_slot.custom_minimum_size = Vector2(0, 96)
	else:
		GameTheme.style_title(title, 34)
		start_button.remove_theme_font_size_override("font_size")


func _setup_hangar() -> void:
	if hangar_slot == null:
		return
	for c in hangar_slot.get_children():
		c.queue_free()
	_hangar = HANGAR_SCRIPT.new() as LobbyHangar
	hangar_slot.add_child(_hangar)
	hangar_slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func _update_hangar_preview() -> void:
	if _hangar == null:
		return
	var role := _local_role()
	if role == "":
		role = "explorer"
	_hangar.show_selection(role, _skin)


func _local_role() -> String:
	var info := NetworkManager.get_player(multiplayer.get_unique_id())
	return str(info.get("role", ""))


func _apply_ready_button_style() -> void:
	if local_ready:
		ready_button.text = "✅  ¡LISTO!"
		GameTheme.style_primary(ready_button)
	else:
		ready_button.text = "✅  MARCAR LISTO"
		ready_button.remove_theme_stylebox_override("normal")
		ready_button.remove_theme_stylebox_override("hover")
		ready_button.remove_theme_stylebox_override("pressed")


func _rebuild_all_pickers() -> void:
	_rebuild_skins()
	_rebuild_loadouts()
	_rebuild_maps()
	_rebuild_beasts()
	_syncing_checks = true
	easy_check.button_pressed = GameManager.easy_beast_mode
	campaign_check.button_pressed = ProgressionManager.campaign_mode
	_syncing_checks = false
	_update_map_hint()
	_update_loadout_hint()
	_update_campaign_ui()


func _clear_row(row: HBoxContainer) -> void:
	for c in row.get_children():
		c.queue_free()


func _wire_card(card: Button, cb: Callable) -> void:
	card.pressed.connect(func():
		if card.get_meta("locked", false):
			return
		AudioDirector.play_ui("click")
		cb.call()
	)


func _rebuild_skins() -> void:
	_clear_row(skin_row)
	var indices: Array = []
	for cat_i in CharacterCatalog.explorer_indices():
		var mesh := str(CharacterCatalog.get_entry(int(cat_i)).get("mesh", ""))
		if not mesh.is_empty() and ResourceLoader.exists(mesh):
			indices.append(int(cat_i))
	if indices.is_empty():
		indices = CharacterCatalog.explorer_indices()
	for cat_i in indices:
		var locked := not CharacterCatalog.is_unlocked(int(cat_i))
		var card := VisualPicker.make_skin_card(int(cat_i), int(cat_i) == _skin, locked)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wire_card(card, _on_skin_picked.bind(int(cat_i)))
		skin_row.add_child(card)


func _rebuild_loadouts() -> void:
	_clear_row(loadout_row)
	for i in 4:
		var locked := not ProgressionManager.is_loadout_unlocked(i)
		var card := VisualPicker.make_loadout_card(i, i == _loadout, locked)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wire_card(card, _on_loadout_picked.bind(i))
		loadout_row.add_child(card)


func _rebuild_maps() -> void:
	_clear_row(map_row)
	for i in NetworkManager.MAP_IDS.size():
		var mid: String = NetworkManager.MAP_IDS[i]
		var locked := not ProgressionManager.is_map_unlocked(mid)
		var card := VisualPicker.make_map_card(mid, i == _map_idx, locked)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wire_card(card, _on_map_picked.bind(i))
		map_row.add_child(card)


func _rebuild_beasts() -> void:
	_clear_row(beast_row)
	var variants := [
		GameManager.BeastVariant.MECHA,
		GameManager.BeastVariant.CLASSIC,
		GameManager.BeastVariant.SHADOW,
	]
	for v in variants:
		var locked := not ProgressionManager.is_beast_unlocked(v)
		var card := VisualPicker.make_beast_card(v, v == _beast_variant, locked)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wire_card(card, _on_beast_picked.bind(v))
		beast_row.add_child(card)


func _on_skin_picked(skin: int) -> void:
	if not CharacterCatalog.is_unlocked(skin):
		status_label.text = "Personaje bloqueado — gana más partidas"
		return
	_skin = skin
	_rebuild_skins()
	NetworkManager.submit_skin(skin)
	_update_hangar_preview()
	_update_hangar_preview()


func _on_loadout_picked(loadout: int) -> void:
	if not ProgressionManager.is_loadout_unlocked(loadout):
		status_label.text = "Arsenal bloqueado — gana partidas para desbloquear"
		return
	_loadout = loadout
	_rebuild_loadouts()
	_update_loadout_hint()
	NetworkManager.submit_loadout(loadout)


func _on_map_picked(index: int) -> void:
	var mid: String = NetworkManager.MAP_IDS[index]
	if not ProgressionManager.is_map_unlocked(mid):
		status_label.text = "Mapa bloqueado — gana con robots para desbloquear"
		return
	_map_idx = index
	_rebuild_maps()
	NetworkManager.submit_map(mid)
	_update_map_hint()
	if NetworkManager.is_solo_practice:
		status_label.text = "Teatro: %s" % NetworkManager.MAP_NAMES.get(mid, mid)


func _on_beast_picked(variant: int) -> void:
	if not ProgressionManager.is_beast_unlocked(variant):
		status_label.text = "Bestia bloqueada — gana 2 partidas como robots"
		return
	_beast_variant = variant
	_rebuild_beasts()
	NetworkManager.submit_beast_variant(variant)
	_update_hangar_preview()


func _update_map_hint() -> void:
	var mid: String = NetworkManager.selected_map
	match mid:
		"containers":
			map_hint.text = "Pasillos de contenedores — emboscadas cercanas."
		"ruins":
			map_hint.text = "Ruinas — plataforma alta y combate vertical."
		"reactor_pit":
			map_hint.text = "Pozo reactor — zona de daño central y pulsos."
		"skybridge":
			map_hint.text = "Puentes elevados — flancos peligrosos y núcleos altos."
		"castle":
			map_hint.text = "Castillo Kenney — puertas, torres y murallas."
		"cave":
			map_hint.text = "Cueva modular — corredores y salas oscuras."
		"forest":
			map_hint.text = "Mini bosque — cobertura entre árboles."
		_:
			map_hint.text = "Laboratorio neon — arena abierta y luces frías."
	if ProgressionManager.campaign_mode or NetworkManager.is_solo_practice:
		var lv := ProgressionManager.current_level()
		map_hint.text = "%s · %ds · %d núcleos" % [
			map_hint.text,
			int(lv.get("time", 240)),
			int(lv.get("cores", 5)),
		]


func _update_loadout_hint() -> void:
	if _loadout >= 0 and _loadout < LOADOUT_HINTS.size():
		loadout_hint.text = LOADOUT_HINTS[_loadout]


func _update_campaign_ui() -> void:
	campaign_label.text = "%s · %d/%d · victorias %d · mapas %d/3" % [
		ProgressionManager.level_name(),
		ProgressionManager.selected_level + 1,
		ProgressionManager.total_levels(),
		ProgressionManager.wins_total,
		ProgressionManager.unlocked_maps.size(),
	]
	if ProgressionManager.campaign_complete:
		campaign_label.text += " · ¡CAMPAÑA COMPLETA!"
	if NetworkManager.is_solo_practice:
		campaign_label.text += " · SOLITARIO · elige teatro libre"
		map_row.modulate = Color.WHITE
		if level_title:
			level_title.visible = true
		if level_row:
			level_row.visible = true
		return
	if ProgressionManager.campaign_mode:
		campaign_label.text += " · CAMPAÑA ON · mapa del nivel (online)"
		map_row.modulate = Color(0.75, 0.75, 0.8)
		if level_title:
			level_title.visible = true
		if level_row:
			level_row.visible = true
	else:
		map_row.modulate = Color.WHITE
		if level_title:
			level_title.visible = false
		if level_row:
			level_row.visible = false


func _rebuild_levels() -> void:
	if level_row == null:
		return
	for c in level_row.get_children():
		c.queue_free()
	for i in ProgressionManager.total_levels():
		var unlocked := ProgressionManager.is_level_unlocked(i)
		var btn := Button.new()
		btn.text = str(i + 1)
		btn.custom_minimum_size = Vector2(40, 40)
		btn.disabled = not unlocked
		btn.toggle_mode = true
		btn.button_pressed = i == ProgressionManager.selected_level
		if unlocked:
			btn.pressed.connect(_on_level_picked.bind(i))
		else:
			btn.tooltip_text = "Bloqueado"
		level_row.add_child(btn)
		if unlocked and i == ProgressionManager.selected_level:
			GameTheme.style_primary(btn)


func _on_level_picked(idx: int) -> void:
	if ProgressionManager.select_level(idx):
		NetworkManager.selected_map = ProgressionManager.force_campaign_map()
		var map_idx := NetworkManager.MAP_IDS.find(NetworkManager.selected_map)
		if map_idx >= 0:
			_map_idx = map_idx
		_rebuild_levels()
		_rebuild_maps()
		_update_map_hint()
		_update_campaign_ui()
		_check_can_start()


func _update_robot_sections_visibility() -> void:
	var role := _local_role()
	var is_robot := role == "explorer"
	var is_beast := role == "beast"
	skin_row.visible = is_robot
	skin_title.visible = is_robot
	loadout_row.visible = is_robot
	loadout_title.visible = is_robot
	loadout_hint.visible = is_robot
	beast_row.visible = is_beast or role == ""
	variant_title.visible = is_beast or role == ""
	easy_check.visible = is_beast or role == ""


func _on_easy_toggled(on: bool) -> void:
	if _syncing_checks:
		return
	NetworkManager.submit_easy_beast(on)


func _on_campaign_toggled(on: bool) -> void:
	if _syncing_checks:
		return
	if NetworkManager.is_solo_practice:
		return
	NetworkManager.submit_campaign_mode(on)


func _on_progress_changed() -> void:
	_rebuild_loadouts()
	_rebuild_maps()
	_rebuild_beasts()
	_rebuild_levels()
	_update_campaign_ui()


func _on_pick_beast() -> void:
	NetworkManager.submit_role("beast")
	_update_robot_sections_visibility()
	_update_hangar_preview()
	_check_can_start()


func _on_pick_robot() -> void:
	NetworkManager.submit_role("explorer")
	_update_robot_sections_visibility()
	_update_hangar_preview()
	_check_can_start()


func _on_ready_pressed() -> void:
	local_ready = not local_ready
	_apply_ready_button_style()
	NetworkManager.submit_ready(local_ready)
	_check_can_start()


func _on_start_pressed() -> void:
	if NetworkManager.is_solo_practice:
		if _local_role() == "":
			status_label.text = "Elige Bestia o Robot"
			return
		# Asegurar ready + bots
		NetworkManager.players[1]["ready"] = true
		NetworkManager.request_start_match()
		return
	if NetworkManager.get_player_count() < 2:
		status_label.text = "Se necesitan al menos 2 jugadores"
		return
	if not NetworkManager.all_players_ready():
		status_label.text = "Todos deben estar listos"
		return
	if not NetworkManager.has_exactly_one_beast():
		status_label.text = "Debe haber exactamente 1 Bestia"
		return
	NetworkManager.request_start_match.rpc_id(1)


func _on_match_start(_map_id: String) -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_changed() -> void:
	var map_idx := NetworkManager.MAP_IDS.find(NetworkManager.selected_map)
	if map_idx >= 0:
		_map_idx = map_idx
	_beast_variant = GameManager.beast_variant
	_syncing_checks = true
	easy_check.button_pressed = GameManager.easy_beast_mode
	campaign_check.button_pressed = ProgressionManager.campaign_mode
	_syncing_checks = false
	_rebuild_maps()
	_rebuild_beasts()
	_rebuild_loadouts()
	_update_map_hint()
	_update_campaign_ui()
	_refresh_player_list()
	_update_robot_sections_visibility()


func _refresh_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
	var my_id := multiplayer.get_unique_id()
	for peer_id in NetworkManager.players:
		if NetworkManager.is_bot_peer(int(peer_id)):
			continue  # bots solo en partida
		var info: Dictionary = NetworkManager.players[peer_id]
		var role := str(info.get("role", ""))
		var extra := ""
		if role == "explorer":
			extra = " · %s · %s" % [
				WeaponDefs.explorer_skin_name(int(info.get("skin", 0))),
				WeaponDefs.explorer_loadout_name(int(info.get("loadout", 0))),
			]
		elif role == "beast":
			extra = " · %s" % GameManager.get_beast_variant_name()
		var card := GameTheme.make_player_card(
			str(info.get("name", "?")) + extra,
			role,
			bool(info.get("ready", false)),
			int(info.get("skin", 0))
		)
		player_list.add_child(card)
		if int(peer_id) == my_id:
			local_ready = bool(info.get("ready", false))
			_skin = int(info.get("skin", _skin))
			_loadout = int(info.get("loadout", _loadout))
			if not NetworkManager.is_solo_practice:
				_apply_ready_button_style()
	_check_can_start()
	_update_robot_sections_visibility()
	_update_hangar_preview()


func _check_can_start() -> void:
	if NetworkManager.is_dedicated_server:
		return
	if NetworkManager.is_solo_practice:
		var role := _local_role()
		var ok := role == "beast" or role == "explorer"
		start_button.disabled = not ok
		status_label.text = "Práctica · %s · rol: %s · mapa: %s" % [
			ProgressionManager.level_name(),
			"Bestia" if role == "beast" else ("Robot" if role == "explorer" else "—"),
			NetworkManager.MAP_NAMES.get(NetworkManager.selected_map, "?"),
		]
		status_label.add_theme_color_override(
			"font_color", GameTheme.C_CYAN if ok else GameTheme.C_AMBER
		)
		if ok:
			status_label.text += "  ·  listo — pulsa JUGAR NIVEL"
		return
	var count := NetworkManager.get_player_count()
	var ok := count >= 2 and NetworkManager.all_players_ready() and NetworkManager.has_exactly_one_beast()
	start_button.disabled = not ok
	var ready_n := _count_ready()
	var mode := "campaña" if ProgressionManager.campaign_mode else "libre"
	status_label.text = "%d / %d en sala  ·  %d listos  ·  %s  ·  mapa: %s" % [
		count, NetworkManager.config.max_players if NetworkManager.config else 5,
		ready_n, mode, NetworkManager.MAP_NAMES.get(NetworkManager.selected_map, "?")
	]
	if ok:
		status_label.add_theme_color_override("font_color", GameTheme.C_CYAN)
		status_label.text += "  ·  ¡pueden despegar!"
	else:
		status_label.add_theme_color_override("font_color", GameTheme.C_AMBER)


func _count_ready() -> int:
	var n := 0
	for info in NetworkManager.players.values():
		if info.get("ready", false):
			n += 1
	return n

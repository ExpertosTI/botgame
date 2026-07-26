extends CanvasLayer

const PAUSE_SCRIPT := preload("res://scripts/ui/pause_menu.gd")

@onready var match_panel: Control = $MatchPanel
@onready var result_panel: Control = $ResultPanel
@onready var timer_label: Label = $MatchPanel/TopBar/TimerChip/TimerLabel
@onready var objectives_label: Label = $MatchPanel/TopBar/ObjChip/ObjectivesLabel
@onready var lives_container: VBoxContainer = $MatchPanel/LivesPanel/LivesMargin/LivesContainer
@onready var result_label: Label = $ResultPanel/Center/ResultCard/ResultCol/ResultLabel
@onready var unlock_label: Label = %UnlockLabel
@onready var level_label: Label = %LevelLabel
@onready var back_button: Button = $ResultPanel/Center/ResultCard/ResultCol/BackButton
@onready var rematch_button: Button = $ResultPanel/Center/ResultCard/ResultCol/RematchButton
@onready var combat_label: Label = $MatchPanel/CombatPanel/CombatMargin/CombatLabel
@onready var controls_hint: Label = $MatchPanel/ControlsHint
@onready var sabotage_panel: Control = %SabotagePanel
@onready var sabotage_bar: ProgressBar = %SabotageBar

var _sabotage_title: Label = null
var _timer_active := false
var _local_combat: CombatKit = null
var _local_explorer: ExplorerPlayer = null
var _pause: Node
var _pause_btn: Button
var _tip_label: Label
var _disconnect_shown := false
var _kill_feed: KillFeed
var _combo: ComboTracker
var _combo_label: Label
## Vitales del jugador local. El robot tenía 100 puntos de vida internos que no
## se enseñaban en ninguna parte: podías estar a un disparo de perder una vida
## sin manera de saberlo.
var _hp_bar: ProgressBar
var _hp_label: Label
## Confirmación de impacto. Quien disparaba no recibía ninguna señal de haber
## acertado: mismo sonido al disparar que al fallar, y el destello ocurría lejos.
var _hitmarker: Label
var _hitmarker_t := 0.0
var _interrupt_label: Label
var _interrupt_t := 0.0
var _obj_arrow: Label
var _obj_meta: Label
var _ping_btn: Button
var _tutorial: MatchTutorial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameTheme.apply(match_panel)
	GameTheme.apply(result_panel)
	match_panel.visible = false
	result_panel.visible = false
	if sabotage_panel:
		sabotage_panel.visible = false
		_sabotage_title = sabotage_panel.find_child("SabotageTitle", true, false) as Label
	back_button.pressed.connect(_on_back_pressed)
	rematch_button.pressed.connect(_on_rematch_pressed)
	GameTheme.style_primary(rematch_button)
	if timer_label and GameTheme.font_title():
		timer_label.add_theme_font_override("font", GameTheme.font_title())
		timer_label.add_theme_font_size_override("font_size", 28)
		timer_label.add_theme_color_override("font_color", GameTheme.C_CYAN)
	if controls_hint:
		GameTheme.style_muted(controls_hint, 13)
		if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
			controls_hint.text = "Stick · DISPARO · mantén en núcleo · PING · ⏸"
		else:
			controls_hint.text = "WASD · Click · Q arma · V ping · Esc pausa · Mantén en núcleo"
	if unlock_label:
		unlock_label.add_theme_color_override("font_color", GameTheme.C_AMBER)
	if level_label:
		GameTheme.style_muted(level_label, 14)

	_pause = PAUSE_SCRIPT.new()
	add_child(_pause)
	_pause.quit_requested.connect(_on_back_pressed)

	_make_pause_button()
	_make_tip()
	_kill_feed = KillFeed.new()
	match_panel.add_child(_kill_feed)
	_combo = ComboTracker.new()
	add_child(_combo)
	_combo.combo_changed.connect(_on_combo)
	_combo_label = Label.new()
	_combo_label.visible = false
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.set_anchors_preset(Control.PRESET_CENTER)
	_combo_label.offset_left = -120
	_combo_label.offset_right = 120
	_combo_label.offset_top = -40
	_combo_label.offset_bottom = 10
	_combo_label.add_theme_font_size_override("font_size", 28)
	_combo_label.add_theme_color_override("font_color", GameTheme.C_AMBER)
	match_panel.add_child(_combo_label)
	_build_vitals()
	_build_hitmarker()
	_build_objective_arrow()
	_build_ping_button()
	MatchStats.damage_recorded.connect(_on_damage_recorded)
	MatchStats.elimination_recorded.connect(_on_elim_recorded)
	NetworkManager.server_lost.connect(_on_server_lost)


func _build_vitals() -> void:
	var box := VBoxContainer.new()
	box.name = "Vitals"
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	## En touch/web el stick ocupa ~bottom-left; subir vitals para no tapar HP.
	var touch_ui := (
		DisplayServer.is_touchscreen_available()
		or OS.has_feature("mobile")
		or OS.has_feature("web")
	)
	if touch_ui:
		box.offset_left = 16
		box.offset_top = -268
		box.offset_right = 236
		box.offset_bottom = -210
	else:
		box.offset_left = 16
		box.offset_top = -96
		box.offset_right = 236
		box.offset_bottom = -46
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match_panel.add_child(box)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 13)
	_hp_label.add_theme_color_override("font_color", GameTheme.C_MUTED)
	box.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(200, 14)
	_hp_bar.max_value = 1.0
	_hp_bar.step = 0.001
	_hp_bar.show_percentage = false
	box.add_child(_hp_bar)


func _build_hitmarker() -> void:
	## Marca central de acierto. No es una mira: en web y móvil se dispara hacia
	## donde encara el cuerpo, no hacia el centro de la pantalla, así que pintar
	## una retícula fija sería mentirle al jugador.
	_hitmarker = Label.new()
	_hitmarker.text = "✕"
	_hitmarker.visible = false
	_hitmarker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	_hitmarker.offset_left = -30
	_hitmarker.offset_right = 30
	_hitmarker.offset_top = -18
	_hitmarker.offset_bottom = 18
	_hitmarker.add_theme_font_size_override("font_size", 26)
	_hitmarker.add_theme_color_override("font_color", GameTheme.C_AMBER)
	_hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match_panel.add_child(_hitmarker)

	_interrupt_label = Label.new()
	_interrupt_label.visible = false
	_interrupt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interrupt_label.set_anchors_preset(Control.PRESET_CENTER)
	_interrupt_label.offset_left = -180
	_interrupt_label.offset_right = 180
	_interrupt_label.offset_top = 40
	_interrupt_label.offset_bottom = 74
	_interrupt_label.add_theme_font_size_override("font_size", 18)
	# C_DANGER es un rojo oscuro pensado para fondos de botón; sobre el negro del
	# HUD no se lee.
	_interrupt_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	_interrupt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match_panel.add_child(_interrupt_label)


func _on_damage_recorded(from_peer: int, to_peer: int, amount: float) -> void:
	if _combo:
		_combo.register_hit(from_peer, amount)
	var me := multiplayer.get_unique_id()
	if from_peer == me and to_peer != me:
		_flash_hitmarker(amount)
	if to_peer == me:
		# La viñeta de daño llevaba escrita desde el principio y no la llamaba
		# nadie: el golpe recibido solo se notaba en la barra de vida.
		CombatVfx.damage_vignette(self)


func _flash_hitmarker(amount: float) -> void:
	if _hitmarker == null:
		return
	_hitmarker.text = "✕ %d" % int(roundf(amount))
	_hitmarker.visible = true
	_hitmarker.modulate.a = 1.0
	_hitmarker_t = 0.35
	AudioDirector.play_hit_confirm()


func _on_sabotage_interrupted() -> void:
	if _interrupt_label == null:
		return
	_interrupt_label.text = "SABOTAJE INTERRUMPIDO"
	_interrupt_label.visible = true
	_interrupt_label.modulate.a = 1.0
	_interrupt_t = 1.2


func _on_elim_recorded(killer: int, _victim: int) -> void:
	if _combo:
		_combo.register_ko(killer)


func _on_combo(count: int, label: String) -> void:
	if _combo_label == null:
		return
	if count < 3 or label.is_empty():
		_combo_label.visible = false
		return
	_combo_label.text = label
	_combo_label.visible = true
	_combo_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_combo_label, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.12)


func _make_pause_button() -> void:
	_pause_btn = Button.new()
	_pause_btn.text = "⏸"
	_pause_btn.custom_minimum_size = Vector2(52, 52)
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.offset_left = -68
	_pause_btn.offset_top = 10
	_pause_btn.offset_right = -12
	_pause_btn.offset_bottom = 62
	_pause_btn.pressed.connect(_toggle_pause)
	match_panel.add_child(_pause_btn)


func _make_tip() -> void:
	_tip_label = Label.new()
	_tip_label.visible = false
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tip_label.offset_left = -220
	_tip_label.offset_right = 220
	_tip_label.offset_top = 70
	_tip_label.offset_bottom = 130
	_tip_label.add_theme_font_size_override("font_size", 15)
	match_panel.add_child(_tip_label)


func _toggle_pause() -> void:
	if result_panel.visible:
		return
	if _pause and _pause.has_method("toggle_pause"):
		_pause.toggle_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if result_panel.visible:
			return
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_fade_transients(delta)
	if not _timer_active or get_tree().paused:
		return
	var time_left := GameManager.get_remaining_time()
	var mins := int(time_left) / 60
	var secs := int(time_left) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	_update_combat_hud()
	_update_sabotage_hud()
	_update_vitals()
	_update_objective_arrow()


func _fade_transients(delta: float) -> void:
	if _hitmarker != null and _hitmarker_t > 0.0:
		_hitmarker_t -= delta
		_hitmarker.modulate.a = clampf(_hitmarker_t / 0.35, 0.0, 1.0)
		if _hitmarker_t <= 0.0:
			_hitmarker.visible = false
	if _interrupt_label != null and _interrupt_t > 0.0:
		_interrupt_t -= delta
		_interrupt_label.modulate.a = clampf(_interrupt_t / 1.2, 0.0, 1.0)
		if _interrupt_t <= 0.0:
			_interrupt_label.visible = false


func _update_vitals() -> void:
	if _hp_bar == null or _hp_label == null:
		return
	if _local_explorer == null:
		_find_local_explorer()
	if _local_explorer != null and _local_explorer.alive:
		var ratio := clampf(_local_explorer.hp / 100.0, 0.0, 1.0)
		_hp_bar.value = ratio
		# modulate multiplica: aquí hacen falta colores claros, no los de botón.
		_hp_bar.modulate = Color(1.0, 0.4, 0.4) if ratio < 0.35 else GameTheme.C_CYAN
		var buffs := _buff_suffix(_local_explorer.combat)
		_hp_label.text = "BLINDAJE %d%%   ·   VIDAS %s%s" % [
			int(ratio * 100.0),
			"●".repeat(maxi(_local_explorer.lives, 0)),
			buffs,
		]
		_hp_bar.visible = true
		_hp_label.visible = true
		return

	var beast := _find_local_beast_owned()
	if beast != null:
		var ratio := clampf(beast.get_hp_ratio(), 0.0, 1.0)
		_hp_bar.value = ratio
		_hp_bar.modulate = Color(1.0, 0.4, 0.4) if ratio < 0.35 else GameTheme.C_AMBER
		_hp_label.text = "BESTIA %d%%%s" % [int(ratio * 100.0), _buff_suffix(beast.combat)]
		_hp_bar.visible = true
		_hp_label.visible = true
		return

	_hp_bar.visible = false
	_hp_label.visible = false


func _buff_suffix(kit: CombatKit) -> String:
	if kit == null:
		return ""
	var bits: PackedStringArray = []
	if kit.shielded:
		bits.append("ESC")
	if kit.speed_mult > 1.05:
		bits.append("TURBO")
	if kit.damage_mult > 1.05:
		bits.append("OVER")
	if kit.cloaked:
		bits.append("CAMU")
	if bits.is_empty():
		return ""
	return "   ·   " + " ".join(bits)


func _find_local_beast_owned() -> BeastPlayer:
	var my_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is BeastPlayer and (node as BeastPlayer).peer_id == my_id:
			return node as BeastPlayer
	return null


func _update_combat_hud() -> void:
	if combat_label == null:
		return
	if _local_combat == null:
		_find_local_combat()
	if _local_combat:
		var extra := ""
		var beast := _find_local_beast()
		if beast:
			extra = "\nHP Bestia: %d%%" % int(beast.get_hp_ratio() * 100.0)
		combat_label.text = _local_combat.get_hud_text() + extra


func _update_sabotage_hud() -> void:
	if sabotage_panel == null or sabotage_bar == null:
		return
	if _local_explorer == null:
		_find_local_explorer()
	if _local_explorer == null:
		sabotage_panel.visible = false
		return
	if _local_explorer.is_sabotaging:
		sabotage_panel.visible = true
		sabotage_bar.value = _local_explorer.get_sabotage_progress()
		if _sabotage_title:
			_sabotage_title.text = "SABOTEANDO…"
		return
	## Aviso de proximidad: el jugador ya está en rango aunque aún no canalice.
	if _local_explorer.can_channel_core():
		sabotage_panel.visible = true
		sabotage_bar.value = 0.0
		if _sabotage_title:
			_sabotage_title.text = "MANTÉN PARA SABOTEAR"
	elif _local_explorer.looking_at_core():
		sabotage_panel.visible = true
		sabotage_bar.value = 0.0
		var core := _local_explorer.looking_core()
		if _sabotage_title and core:
			_sabotage_title.text = core.status_line()
	else:
		sabotage_panel.visible = false


func _find_local_combat() -> void:
	var my_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is PlayerBase and (node as PlayerBase).peer_id == my_id:
			_local_combat = (node as PlayerBase).combat
			if node is ExplorerPlayer:
				_bind_explorer(node as ExplorerPlayer)
			return


func _find_local_explorer() -> void:
	var my_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is ExplorerPlayer and (node as ExplorerPlayer).peer_id == my_id:
			_bind_explorer(node as ExplorerPlayer)
			return


func _bind_explorer(explorer: ExplorerPlayer) -> void:
	_local_explorer = explorer
	if not explorer.sabotage_interrupted.is_connected(_on_sabotage_interrupted):
		explorer.sabotage_interrupted.connect(_on_sabotage_interrupted)


func _find_local_beast() -> BeastPlayer:
	for node in get_tree().get_nodes_in_group("player_characters"):
		if node is BeastPlayer:
			return node as BeastPlayer
	return null


func show_match_hud() -> void:
	match_panel.visible = true
	result_panel.visible = false
	_timer_active = true
	objectives_label.text = "NÚCLEOS  %d" % GameManager.objectives_remaining
	_build_lives_display()
	_show_level_tip()
	_maybe_start_match_tutorial()


func _maybe_start_match_tutorial() -> void:
	if SettingsManager.match_tutorial_done:
		return
	## Primera partida de cualquier modo (online incluido).
	var role := "explorer"
	var my_id := multiplayer.get_unique_id()
	var info: Dictionary = NetworkManager.players.get(my_id, {})
	if str(info.get("role", "")) == "beast":
		role = "beast"
	_tutorial = MatchTutorial.present(self, role)


func _show_level_tip() -> void:
	if _tip_label == null:
		return
	## Si corre el tutorial interactivo, no taparlo con un tip aleatorio.
	if not SettingsManager.match_tutorial_done:
		_tip_label.visible = false
		return
	var tip := ""
	var role := _local_role_id()
	if ProgressionManager.campaign_mode or NetworkManager.is_solo_practice:
		tip = ProgressionManager.level_briefing(role)
		if tip.is_empty():
			tip = ProgressionManager.level_tip()
		if not tip.is_empty():
			tip = "%s — %s" % [ProgressionManager.level_act(), tip]
	if tip.is_empty() and not SettingsManager.tutorial_seen:
		tip = "Robots: sabotea núcleos. Bestia: elimina robots. Esc/⏸ = pausa."
	if tip.is_empty():
		tip = TipBank.random_general()
	if tip.is_empty():
		_tip_label.visible = false
		return
	_tip_label.text = tip
	_tip_label.visible = true
	_tip_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(6.5)
	tw.tween_property(_tip_label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func(): _tip_label.visible = false)


func _local_role_id() -> String:
	var my_id := multiplayer.get_unique_id()
	var info: Dictionary = NetworkManager.players.get(my_id, {})
	return str(info.get("role", "explorer"))


func _build_objective_arrow() -> void:
	_obj_arrow = Label.new()
	_obj_arrow.name = "ObjArrow"
	_obj_arrow.text = "▲"
	_obj_arrow.visible = false
	_obj_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_arrow.set_anchors_preset(Control.PRESET_CENTER)
	_obj_arrow.offset_left = -40
	_obj_arrow.offset_right = 40
	_obj_arrow.offset_top = -120
	_obj_arrow.offset_bottom = -70
	_obj_arrow.add_theme_font_size_override("font_size", 42)
	_obj_arrow.add_theme_color_override("font_color", GameTheme.C_AMBER)
	_obj_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match_panel.add_child(_obj_arrow)

	_obj_meta = Label.new()
	_obj_meta.name = "ObjMeta"
	_obj_meta.visible = false
	_obj_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_meta.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_obj_meta.offset_left = -180
	_obj_meta.offset_right = 180
	_obj_meta.offset_top = -96
	_obj_meta.offset_bottom = -64
	_obj_meta.add_theme_font_size_override("font_size", 15)
	_obj_meta.add_theme_color_override("font_color", GameTheme.C_CYAN)
	_obj_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match_panel.add_child(_obj_meta)


func _build_ping_button() -> void:
	if not (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or OS.has_feature("web")):
		return
	_ping_btn = Button.new()
	_ping_btn.text = "PING"
	_ping_btn.custom_minimum_size = Vector2(88, 48)
	_ping_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ping_btn.offset_left = -210
	_ping_btn.offset_right = -114
	_ping_btn.offset_top = -140
	_ping_btn.offset_bottom = -84
	GameTheme.style_touch(_ping_btn, GameTheme.C_AMBER)
	_ping_btn.pressed.connect(func(): InputManager.request_ping())
	match_panel.add_child(_ping_btn)


func _update_objective_arrow() -> void:
	if _obj_arrow == null:
		return
	var local := _local_body()
	if local == null:
		_obj_arrow.visible = false
		if _obj_meta:
			_obj_meta.visible = false
		return
	var core := _nearest_active_core(local.global_position)
	if core == null:
		_obj_arrow.visible = false
		if _obj_meta:
			_obj_meta.visible = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_obj_arrow.visible = false
		return
	var world := core.global_position + Vector3(0, 1.2, 0)
	var vp := get_viewport().get_visible_rect().size
	## Side-cam / FOV amplio: unproject sale fuera del viewport y la flecha
	## desaparece o se clava en un borde. Siempre clamp a márgenes seguros.
	var mx := 36.0
	var my := 72.0
	if cam.is_position_behind(world):
		_obj_arrow.visible = true
		_obj_arrow.rotation = PI
		_obj_arrow.position = Vector2(
			clampf(vp.x * 0.5 - 20.0, mx, vp.x - mx),
			clampf(48.0, my, vp.y - my)
		)
	else:
		var screen: Vector2 = cam.unproject_position(world) + Vector2(-20, -48)
		_obj_arrow.visible = true
		_obj_arrow.rotation = 0.0
		_obj_arrow.global_position = Vector2(
			clampf(screen.x, mx, vp.x - mx),
			clampf(screen.y, my, vp.y - my)
		)
	var dist := int(roundf(local.global_position.distance_to(core.global_position)))
	_obj_arrow.text = "▲"
	if _obj_meta:
		_obj_meta.visible = true
		_obj_meta.text = "%s · %dm · %s" % [
			ObjectiveVariants.label(core.variant as ObjectiveVariants.Kind),
			dist,
			core.status_line(),
		]


func _local_body() -> Node3D:
	if _local_explorer != null and is_instance_valid(_local_explorer):
		return _local_explorer
	return _find_local_beast_owned()


func _nearest_active_core(from: Vector3) -> BeastObjective:
	var best: BeastObjective = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("beast_objectives"):
		if n is BeastObjective and (n as BeastObjective).is_active:
			var d := from.distance_to((n as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = n as BeastObjective
	return best


func update_objectives(remaining: int) -> void:
	objectives_label.text = "NÚCLEOS  %d" % remaining


func update_lives(peer_id: int, lives: int) -> void:
	var label := lives_container.get_node_or_null("Lives_%d" % peer_id) as Label
	if label:
		label.text = "%s  %s" % [
			NetworkManager.players.get(peer_id, {}).get("name", "Robot"),
			"●".repeat(maxi(lives, 0)) + "○".repeat(maxi(GameManager.EXPLORER_LIVES - lives, 0))
		]


func show_result(winner: String) -> void:
	_timer_active = false
	if _pause and _pause.has_method("close_pause"):
		_pause.close_pause()
	if sabotage_panel:
		sabotage_panel.visible = false
	result_panel.visible = true
	match winner:
		"explorers":
			result_label.text = "¡LOS ROBOTS GANAN!"
			result_label.add_theme_color_override("font_color", GameTheme.C_CYAN)
		"beast":
			result_label.text = "¡LA BESTIA GANA!"
			result_label.add_theme_color_override("font_color", GameTheme.C_CRIMSON)
	if GameTheme.font_title():
		result_label.add_theme_font_override("font", GameTheme.font_title())
		result_label.add_theme_font_size_override("font_size", 36)
	var role := _local_role_id()
	var won := (winner == "explorers" and role != "beast") or (winner == "beast" and role == "beast")
	var outro := ""
	if ProgressionManager.campaign_mode or NetworkManager.is_solo_practice:
		outro = ProgressionManager.level_outro(role, won)
	var mvp := MatchStats.mvp_name()
	var board := MatchStats.scoreboard_lines()
	var stats_block := ""
	if not outro.is_empty():
		stats_block = outro
	if not board.is_empty():
		var board_txt := "\n".join(board)
		if not mvp.is_empty():
			board_txt = "MVP · %s\n%s" % [mvp, board_txt]
		stats_block = (stats_block + "\n\n" if not stats_block.is_empty() else "") + board_txt
	if unlock_label:
		var msg := ProgressionManager.last_unlock_message
		if ProgressionManager.campaign_complete and msg.is_empty():
			msg = "¡Campaña completada!"
		if not stats_block.is_empty():
			msg = (msg + "\n\n" if not msg.is_empty() else "") + stats_block
		unlock_label.text = msg
		unlock_label.visible = not msg.is_empty()
		unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if level_label:
		var dur := int(MatchStats.duration_seconds())
		if NetworkManager.is_solo_practice or ProgressionManager.campaign_mode:
			level_label.text = "%s · %ds · v%s · best %d" % [
				ProgressionManager.level_name(),
				dur,
				GameBrand.VERSION,
				ProgressionManager.best_score,
			]
		else:
			level_label.text = "Partidas %d · victorias %d · %ds · v%s" % [
				ProgressionManager.matches_played,
				ProgressionManager.wins_total,
				dur,
				GameBrand.VERSION,
			]
	if NetworkManager.is_solo_practice:
		rematch_button.text = "Otro intento"
	else:
		rematch_button.text = "Jugar otra"


func _build_lives_display() -> void:
	for child in lives_container.get_children():
		child.queue_free()
	for peer_id in GameManager.explorer_lives:
		var label := Label.new()
		label.name = "Lives_%d" % peer_id
		var lives: int = GameManager.explorer_lives[peer_id]
		label.text = "%s  %s" % [
			NetworkManager.players.get(peer_id, {}).get("name", "Robot"),
			"●".repeat(lives) + "○".repeat(GameManager.EXPLORER_LIVES - lives)
		]
		label.add_theme_font_size_override("font_size", 16)
		lives_container.add_child(label)


func _on_back_pressed() -> void:
	if _pause and _pause.has_method("close_pause"):
		_pause.close_pause()
	get_tree().paused = false
	GameManager.abort_match()
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/main/menu.tscn")


func _on_server_lost() -> void:
	if _disconnect_shown or NetworkManager.is_solo_practice:
		return
	_disconnect_shown = true
	_timer_active = false
	GameManager.abort_match()
	if _pause and _pause.has_method("close_pause"):
		_pause.close_pause()
	result_panel.visible = true
	result_label.text = "Conexión perdida"
	result_label.add_theme_color_override("font_color", GameTheme.C_AMBER)
	if unlock_label:
		unlock_label.text = "El servidor se desconectó. Vuelve al menú e inténtalo de nuevo."
		unlock_label.visible = true
	rematch_button.visible = false

func _on_rematch_pressed() -> void:
	get_tree().paused = false
	NetworkManager.request_return_to_lobby()

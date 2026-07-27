class_name BeastObjective
extends StaticBody3D

signal sabotaged
signal shield_changed(current: float, maximum: float)
signal relay_changed(open: bool)

@export var health := 100.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var particles: GPUParticles3D = $DestroyParticles

var is_active := true
var sabotage_progress := 0.0
var variant: int = ObjectiveVariants.Kind.STANDARD
var sabotage_time_mult := 1.0
var shield_hp := 0.0
var shield_max := 0.0
var relay_open := true
var _relay_t := 0.0
var _ring: MeshInstance3D
var _status_lab: Label3D
var _pulse_tween: Tween


func _ready() -> void:
	add_to_group("beast_objectives")
	set_physics_process(false)
	## Web: GPUParticles3D × núcleos pega el heap.
	if WebSafe.is_web() and particles:
		particles.queue_free()
		particles = null
	_apply_visual()
	_boot_variant_state()


func apply_variant(v: int) -> void:
	variant = v
	sabotage_time_mult = ObjectiveVariants.sabotage_mult(v as ObjectiveVariants.Kind)
	_boot_variant_state()
	_apply_visual()


func _boot_variant_state() -> void:
	match variant:
		ObjectiveVariants.Kind.SHIELDED:
			shield_max = ObjectiveVariants.SHIELD_HP
			shield_hp = shield_max
			set_physics_process(false)
		ObjectiveVariants.Kind.TIMED_RELAY:
			shield_hp = 0.0
			shield_max = 0.0
			relay_open = true
			_relay_t = ObjectiveVariants.RELAY_OPEN_S
			set_physics_process(true)
		_:
			shield_hp = 0.0
			shield_max = 0.0
			relay_open = true
			set_physics_process(false)
	_refresh_status_label()


func _physics_process(delta: float) -> void:
	if not is_active or variant != ObjectiveVariants.Kind.TIMED_RELAY:
		return
	## Solo el servidor (o solo) avanza la ventana; el resto recibe el RPC.
	if multiplayer.has_multiplayer_peer() and not NetworkManager.is_match_authority():
		return
	_relay_t -= delta
	if _relay_t > 0.0:
		return
	relay_open = not relay_open
	_relay_t = (
		ObjectiveVariants.RELAY_OPEN_S if relay_open else ObjectiveVariants.RELAY_CLOSED_S
	)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_sync_relay.rpc(relay_open, _relay_t)
	else:
		_sync_relay(relay_open, _relay_t)


@rpc("authority", "call_local", "reliable")
func _sync_relay(open: bool, remaining: float) -> void:
	relay_open = open
	_relay_t = remaining
	relay_changed.emit(open)
	_refresh_status_label()
	_apply_relay_emission()


## ¿Se puede empezar (o seguir) canalizando este núcleo?
func can_accept_sabotage() -> bool:
	if not is_active:
		return false
	if variant == ObjectiveVariants.Kind.SHIELDED and shield_hp > 0.01:
		return false
	if variant == ObjectiveVariants.Kind.TIMED_RELAY and not relay_open:
		return false
	return true


func status_line() -> String:
	if not is_active:
		return ""
	match variant:
		ObjectiveVariants.Kind.SHIELDED:
			if shield_hp > 0.01:
				return "ESCUDO %d%%" % int(roundf(shield_hp / maxf(shield_max, 1.0) * 100.0))
			return "BLINDADO · listo"
		ObjectiveVariants.Kind.TIMED_RELAY:
			return "RELÉ · abierto" if relay_open else "RELÉ · cerrado"
		ObjectiveVariants.Kind.OVERCHARGED:
			return "SOBRECARGA"
		_:
			return "NÚCLEO"


## Disparo de explorador contra el escudo. Solo servidor aplica.
func apply_shield_damage(amount: float) -> void:
	if not is_active or amount <= 0.0:
		return
	if variant != ObjectiveVariants.Kind.SHIELDED or shield_hp <= 0.0:
		return
	if multiplayer.has_multiplayer_peer() and not NetworkManager.is_match_authority():
		return
	shield_hp = maxf(shield_hp - amount, 0.0)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not NetworkManager.is_solo_practice:
		_sync_shield.rpc(shield_hp)
	else:
		_sync_shield(shield_hp)
	if shield_hp <= 0.0:
		CombatVfx.burst(self, global_position + Vector3.UP, ObjectiveVariants.tint(variant as ObjectiveVariants.Kind), 1.4, 10)
		AudioDirector.play_core()


@rpc("authority", "call_local", "reliable")
func _sync_shield(hp: float) -> void:
	shield_hp = hp
	shield_changed.emit(shield_hp, shield_max)
	_refresh_status_label()
	_apply_visual()


func _apply_visual() -> void:
	if mesh == null:
		return
	var tint := ObjectiveVariants.tint(variant as ObjectiveVariants.Kind)
	if variant == ObjectiveVariants.Kind.TIMED_RELAY and not relay_open:
		tint = tint.darkened(0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.35
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = tint.lightened(0.15)
	mat.emission_energy_multiplier = 2.4
	if variant == ObjectiveVariants.Kind.SHIELDED and shield_hp > 0.01:
		mat.emission_energy_multiplier = 3.4
	mesh.material_override = mat

	var lite := OS.has_feature("web") or OS.get_name() == "Web"

	if _ring == null:
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.55
		torus.outer_radius = 0.72
		if lite:
			torus.rings = 8
			torus.ring_segments = 12
		_ring.mesh = torus
		_ring.position = Vector3(0, 0.05, 0)
		add_child(_ring)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = tint
	ring_mat.emission_enabled = true
	ring_mat.emission = tint
	ring_mat.emission_energy_multiplier = 2.5 if lite else 3.0
	_ring.material_override = ring_mat

	if not lite and not has_node("CoreLight"):
		var light := OmniLight3D.new()
		light.name = "CoreLight"
		light.light_color = tint
		light.light_energy = 2.2
		light.omni_range = 4.5
		light.position = Vector3(0, 1.2, 0)
		add_child(light)

	if variant != ObjectiveVariants.Kind.STANDARD and not has_meta("labeled"):
		set_meta("labeled", true)
		var lab := Label3D.new()
		lab.text = ObjectiveVariants.label(variant as ObjectiveVariants.Kind)
		lab.font_size = 48
		lab.modulate = tint
		lab.position = Vector3(0, 2.1, 0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lab)

	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(mat, "emission_energy_multiplier", 3.6 if lite else 4.2, 0.85)
	_pulse_tween.parallel().tween_property(_ring, "scale", Vector3(1.1, 1.0, 1.1), 0.85)
	_pulse_tween.tween_property(mat, "emission_energy_multiplier", 2.0, 0.85)
	_pulse_tween.parallel().tween_property(_ring, "scale", Vector3.ONE, 0.85)
	_refresh_status_label()


func _apply_relay_emission() -> void:
	if mesh == null:
		return
	_apply_visual()


func _refresh_status_label() -> void:
	var text := status_line()
	if text.is_empty():
		if _status_lab:
			_status_lab.visible = false
		return
	if _status_lab == null:
		_status_lab = Label3D.new()
		_status_lab.font_size = 36
		_status_lab.position = Vector3(0, 2.55, 0)
		_status_lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(_status_lab)
	_status_lab.text = text
	_status_lab.modulate = ObjectiveVariants.tint(variant as ObjectiveVariants.Kind)
	_status_lab.visible = true


@rpc("any_peer", "call_local", "reliable")
func sabotage() -> void:
	if not is_active:
		return
	## OfflineMultiplayerPeer en Web a veces no reporta is_server().
	if multiplayer.has_multiplayer_peer() and not NetworkManager.is_match_authority():
		return
	if not can_accept_sabotage():
		return
	_destroy()


func _destroy() -> void:
	is_active = false
	set_physics_process(false)
	sabotaged.emit()
	if variant == ObjectiveVariants.Kind.OVERCHARGED:
		_overcharge_blast()
	GameManager.register_objective_destroyed()
	_play_destroy_effect.rpc()


## Castigo arcade: quien se quede pegado al núcleo sobrecargado paga el pico.
func _overcharge_blast() -> void:
	var radius := ObjectiveVariants.OVERCHARGE_RADIUS
	var dmg := ObjectiveVariants.OVERCHARGE_DAMAGE
	var origin := global_position
	for node in get_tree().get_nodes_in_group("player_characters"):
		if not (node is Node3D):
			continue
		var body := node as Node3D
		if body.global_position.distance_to(origin) > radius:
			continue
		if node is ExplorerPlayer and (node as ExplorerPlayer).alive:
			var ex := node as ExplorerPlayer
			ex.apply_projectile_hit.rpc(ex.peer_id, dmg, 0.0, 0.0, 0)
		elif node is BeastPlayer:
			(node as BeastPlayer).apply_damage.rpc(dmg * 0.55, 0.0, 0.0, 0)


@rpc("any_peer", "call_local", "reliable")
func _play_destroy_effect() -> void:
	AudioDirector.play_core_down()
	var tint := ObjectiveVariants.tint(variant as ObjectiveVariants.Kind)
	CombatVfx.burst(self, global_position + Vector3.UP, tint, 2.2, 16)
	CombatVfx.ring(self, global_position, tint, 3.0)
	if variant == ObjectiveVariants.Kind.OVERCHARGED:
		CombatVfx.ring(self, global_position, tint, ObjectiveVariants.OVERCHARGE_RADIUS)
	if particles:
		particles.emitting = true
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.4)
	tween.tween_callback(queue_free)

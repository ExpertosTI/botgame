class_name HazardSystem
extends Node3D

## Peligros de mapa: pozos de daño, zonas de ralentización, puertas neón.

signal hazard_tick

var _hazards: Array[Dictionary] = []
var _tick := 0.0


func clear_hazards() -> void:
	_hazards.clear()
	for c in get_children():
		c.queue_free()


func _ready() -> void:
	add_to_group("hazard_systems")


func add_damage_zone(pos: Vector3, radius: float, dps: float, color: Color = Color(1.0, 0.25, 0.1)) -> void:
	_hazards.append({"type": "damage", "pos": pos, "radius": radius, "dps": dps})
	_spawn_marker(pos, radius, color, true)


func add_slow_zone(pos: Vector3, radius: float, slow: float = 0.4, color: Color = Color(0.3, 0.7, 1.0)) -> void:
	_hazards.append({"type": "slow", "pos": pos, "radius": radius, "slow": slow})
	_spawn_marker(pos, radius, color, false)


func add_pulse_zone(pos: Vector3, radius: float, damage: float, period: float = 3.0, color: Color = Color(0.9, 0.2, 0.85)) -> void:
	_hazards.append({"type": "pulse", "pos": pos, "radius": radius, "damage": damage, "period": period, "t": 0.0})
	_spawn_marker(pos, radius, color, true)


func _spawn_marker(pos: Vector3, radius: float, color: Color, hot: bool) -> void:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.08
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.28)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.8 if hot else 1.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	mesh.position = pos + Vector3.UP * 0.04
	add_child(mesh)
	if not OS.has_feature("web"):
		var tw := create_tween().set_loops()
		tw.tween_property(mat, "emission_energy_multiplier", 2.6 if hot else 1.8, 0.7)
		tw.tween_property(mat, "emission_energy_multiplier", 1.2 if hot else 0.9, 0.7)


func _physics_process(delta: float) -> void:
	if not GameManager.match_active:
		return
	if multiplayer.has_multiplayer_peer() and not NetworkManager.is_match_authority():
		return
	_tick += delta
	for h in _hazards:
		match str(h.get("type", "")):
			"damage":
				_apply_aoe_damage(h["pos"], float(h["radius"]), float(h["dps"]) * delta)
			"slow":
				_apply_aoe_slow(h["pos"], float(h["radius"]), float(h["slow"]))
			"pulse":
				h["t"] = float(h.get("t", 0.0)) + delta
				if float(h["t"]) >= float(h["period"]):
					h["t"] = 0.0
					_apply_aoe_damage(h["pos"], float(h["radius"]), float(h["damage"]))
					CombatVfx.ring(self, h["pos"], Color(0.9, 0.2, 0.85), float(h["radius"]))
	if _tick >= 0.5:
		_tick = 0.0
		hazard_tick.emit()


func danger_push(from: Vector3) -> Vector3:
	## Vector unitario para salir de zonas de daño/pulso (bots de práctica).
	var push := Vector3.ZERO
	for h in _hazards:
		var t := str(h.get("type", ""))
		if t != "damage" and t != "pulse":
			continue
		var hp: Vector3 = h["pos"]
		var r: float = float(h["radius"])
		var d := from.distance_to(hp)
		if d < r + 1.2:
			var away := from - hp
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3(1, 0, 0)
			push += away.normalized() * (1.0 - clampf(d / (r + 1.2), 0.0, 1.0))
	if push.length_squared() < 0.0001:
		return Vector3.ZERO
	return push.normalized()


func _apply_aoe_damage(pos: Vector3, radius: float, amount: float) -> void:
	if amount <= 0.05:
		return
	for n in get_tree().get_nodes_in_group("player_characters"):
		if not (n is PlayerBase):
			continue
		if n.global_position.distance_to(pos) > radius:
			continue
		if n is BeastPlayer:
			(n as BeastPlayer).apply_damage.rpc(amount, 0.0, 0.0, 0)
		elif n is ExplorerPlayer and (n as ExplorerPlayer).alive:
			(n as ExplorerPlayer).apply_projectile_hit.rpc((n as ExplorerPlayer).peer_id, amount, 0.0, 0.0)


func _apply_aoe_slow(pos: Vector3, radius: float, slow: float) -> void:
	for n in get_tree().get_nodes_in_group("player_characters"):
		if not (n is PlayerBase):
			continue
		if n.global_position.distance_to(pos) > radius:
			continue
		var p := n as PlayerBase
		## El movimiento lo manda el authority del jugador.
		if multiplayer.has_multiplayer_peer():
			p.apply_hazard_slow.rpc_id(p.get_multiplayer_authority(), slow, 0.35)
		elif p.combat:
			p.combat.apply_slow(slow, 0.35)

class_name PowerupSpawner
extends Node3D

## Pickups de partida: escudo, turbo, reparación, munición (CD reset).

enum Kind { SHIELD, SPEED, REPAIR, OVERCHARGE }

const KIND_COLORS := {
	Kind.SHIELD: Color(0.35, 0.75, 1.0),
	Kind.SPEED: Color(0.3, 1.0, 0.45),
	Kind.REPAIR: Color(0.95, 0.35, 0.85),
	Kind.OVERCHARGE: Color(1.0, 0.75, 0.2),
}

var _pickups: Array[Area3D] = []
var _respawn_queue: Array[Dictionary] = []


func clear_all() -> void:
	for p in _pickups:
		if is_instance_valid(p):
			p.queue_free()
	_pickups.clear()
	_respawn_queue.clear()


func spawn_at(pos: Vector3, kind: Kind) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.set_meta("kind", int(kind))
	area.add_to_group("powerups")
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.1
	col.shape = shape
	area.add_child(col)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	var c: Color = KIND_COLORS.get(kind, Color.WHITE)
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	area.add_child(mesh)
	area.position = pos + Vector3.UP * 0.9
	add_child(area)
	area.body_entered.connect(_on_body.bind(area))
	_pickups.append(area)
	var bob := create_tween().set_loops()
	bob.tween_property(area, "position:y", pos.y + 1.15, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(area, "position:y", pos.y + 0.75, 0.7).set_trans(Tween.TRANS_SINE)


func seed_for_map(map_id: String) -> void:
	clear_all()
	var spots: Array[Vector3] = []
	match map_id:
		"containers":
			spots = [Vector3(0, 0, 0), Vector3(-10, 0, 0), Vector3(10, 0, 0)]
		"ruins":
			spots = [Vector3(-8, 0, 0), Vector3(8, 0, 0), Vector3(0, 3.2, 0)]
		"reactor_pit":
			spots = [Vector3(0, 0, -8), Vector3(0, 0, 8), Vector3(-10, 0, 0), Vector3(10, 0, 0)]
		"skybridge":
			spots = [Vector3(0, 0, 0), Vector3(-6, 0, -6), Vector3(6, 0, 6)]
		_:
			spots = [Vector3(-6, 0, 0), Vector3(6, 0, 0), Vector3(0, 0, 6)]
	var kinds := [Kind.SHIELD, Kind.SPEED, Kind.REPAIR, Kind.OVERCHARGE]
	for i in spots.size():
		spawn_at(spots[i], kinds[i % kinds.size()] as Kind)


func _process(delta: float) -> void:
	if not GameManager.match_active:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var remain: Array[Dictionary] = []
	for item in _respawn_queue:
		item["t"] = float(item["t"]) - delta
		if float(item["t"]) <= 0.0:
			spawn_at(item["pos"], item["kind"] as Kind)
		else:
			remain.append(item)
	_respawn_queue = remain


func _on_body(body: Node3D, area: Area3D) -> void:
	if not GameManager.match_active:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not (body is PlayerBase):
		return
	if not is_instance_valid(area):
		return
	var kind: int = int(area.get_meta("kind", 0))
	_apply(body as PlayerBase, kind)
	var pos := area.position - Vector3.UP * 0.9
	CombatVfx.burst(self, area.global_position, KIND_COLORS.get(kind, Color.WHITE), 1.4, 12)
	AudioDirector.play_ability()
	_respawn_queue.append({"pos": pos, "kind": kind, "t": 18.0})
	_pickups.erase(area)
	area.queue_free()


func _apply(player: PlayerBase, kind: int) -> void:
	if player.combat == null:
		return
	match kind:
		Kind.SHIELD:
			player.combat.apply_buff("shield", 5.0)
		Kind.SPEED:
			player.combat.apply_buff("speed", 6.0)
		Kind.REPAIR:
			if player is BeastPlayer:
				var b := player as BeastPlayer
				b.hp = mini(b.hp + 35.0, BeastPlayer.MAX_HP * GameManager.level_beast_hp_mult)
			elif player is ExplorerPlayer:
				(player as ExplorerPlayer).hp = mini((player as ExplorerPlayer).hp + 40.0, 100.0)
		Kind.OVERCHARGE:
			player.combat.damage_mult = 1.45
			player.combat.apply_buff("overcharge", 7.0)
			for k in player.combat.weapon_cds.keys():
				player.combat.weapon_cds[k] = 0.0

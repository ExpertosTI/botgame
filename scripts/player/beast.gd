class_name BeastPlayer
extends PlayerBase

const MAX_HP := 120.0

@onready var attack_area: Area3D = $AttackArea

var hp := MAX_HP


func _ready() -> void:
	super._ready()
	move_speed = 7.0 if not GameManager.easy_beast_mode else 5.8
	sprint_multiplier = 1.35
	hp = MAX_HP * GameManager.level_beast_hp_mult
	_apply_beast_visuals()
	combat.setup(self, true, int(GameManager.beast_variant))


func _apply_beast_visuals() -> void:
	if crew == null:
		return
	crew.is_beast = true
	var colors := GameManager.get_beast_colors()
	var cat_idx := _resolve_beast_catalog_index()
	var entry := CharacterCatalog.get_entry(cat_idx)
	if not entry.is_empty():
		var tint: Color = entry.get("tint", colors.body)
		crew.apply_colors(tint, colors.visor, tint.lightened(0.15))
	else:
		crew.apply_colors(colors.body, colors.visor, colors.accent)
	var pname: String = str(NetworkManager.players.get(peer_id, {}).get("name", "Bestia"))
	crew.set_player_name(pname)
	if str(entry.get("mesh", "")).is_empty():
		return
	call_deferred("_attach_beast_mesh", cat_idx)


func _attach_beast_mesh(cat_idx: int) -> void:
	var mesh_parent: Node3D = get_node_or_null("Mesh") as Node3D
	if mesh_parent == null:
		return
	var existing := mesh_parent.get_node_or_null("CatalogMesh")
	if existing:
		mesh_parent.remove_child(existing)
		existing.free()
	var attached := CharacterCatalog.attach_mesh(mesh_parent, cat_idx, 1.1)
	if attached and crew:
		for c in crew.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false


func _resolve_beast_catalog_index() -> int:
	var skin := int(NetworkManager.players.get(peer_id, {}).get("skin", -1))
	if skin >= 0:
		var e := CharacterCatalog.get_entry(skin)
		if str(e.get("role", "")) == "beast":
			return skin
	match int(GameManager.beast_variant):
		GameManager.BeastVariant.MECHA:
			return CharacterCatalog.index_of_id("beast_mecha")
		GameManager.BeastVariant.SHADOW:
			var skel := CharacterCatalog.index_of_id("skel_warrior")
			if CharacterCatalog.is_unlocked(skel):
				return skel
			return CharacterCatalog.index_of_id("beast_shadow")
		_:
			return CharacterCatalog.index_of_id("beast_classic")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if has_meta("is_bot") and get_meta("is_bot"):
		return
	if not is_multiplayer_authority():
		return
	# Click = arma actual (garras / spit / slam / rugido)
	if InputManager.action_primary_just:
		combat.fire(get_aim_origin(), get_aim_dir())
	# Click derecho = granada/slam rápido (arma índice 2 si existe)
	if InputManager.action_secondary_just:
		if combat.weapons.size() > 2:
			var prev := combat.weapon_index
			combat.select_weapon(2)
			combat.fire(get_aim_origin(), get_aim_dir())
			combat.select_weapon(prev)


@rpc("any_peer", "call_local", "reliable")
func apply_damage(amount: float, slow: float = 0.0, slow_dur: float = 0.0, from_peer: int = 0) -> void:
	if combat and combat.shielded:
		amount *= 0.25
	if combat and combat.cloaked:
		combat.clear_buff("cloak")
	hp = maxf(hp - amount, 0.0)
	MatchStats.record_damage(from_peer, peer_id, amount)
	AudioDirector.play_hit()
	if is_multiplayer_authority() and camera:
		CombatVfx.shake_camera(camera, 0.12, 0.14)
	if crew:
		crew.play_hit()
	if slow > 0.0 and combat:
		combat.apply_slow(slow, slow_dur)
	if hp <= 0.0:
		_on_defeated()
		if from_peer > 0:
			MatchStats.record_elimination(from_peer, peer_id)


func _on_defeated() -> void:
	# Stun temporal + regen (no elimina a la bestia)
	hp = MAX_HP * 0.35
	if combat:
		combat.apply_slow(0.6, 3.0)
	visible = true
	if crew:
		crew.play_hit()


func get_hp_ratio() -> float:
	var max_hp := MAX_HP * maxf(GameManager.level_beast_hp_mult, 0.1)
	return hp / max_hp

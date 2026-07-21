class_name CombatKit
extends Node

## Armas + habilidades para cualquier jugador.

signal weapon_changed(weapon_name: String, index: int)
signal ability_used(ability_name: String)
signal cooldowns_updated

var weapons: Array = []
var abilities: Array = []
var weapon_index := 0
var weapon_cds: Dictionary = {}
var ability_cds: Dictionary = {}

var is_beast := false
var owner_player: PlayerBase = null

var speed_mult := 1.0
var damage_mult := 1.0
var shielded := false
var cloaked := false
var slowed := false
var _buff_timers: Dictionary = {}


func setup(player: PlayerBase, beast: bool, variant: int) -> void:
	owner_player = player
	is_beast = beast
	if beast:
		weapons = WeaponDefs.beast_loadout(variant)
		abilities = WeaponDefs.beast_abilities(variant)
	else:
		weapons = WeaponDefs.explorer_loadout(variant)
		abilities = WeaponDefs.explorer_abilities(variant)
	weapon_index = 0
	weapon_cds.clear()
	ability_cds.clear()
	weapon_changed.emit(current_weapon_name(), weapon_index)


func _process(delta: float) -> void:
	for k in weapon_cds.keys():
		weapon_cds[k] = maxf(weapon_cds[k] - delta, 0.0)
	for k in ability_cds.keys():
		ability_cds[k] = maxf(ability_cds[k] - delta, 0.0)
	for key in _buff_timers.keys():
		_buff_timers[key] -= delta
		if _buff_timers[key] <= 0.0:
			_clear_buff(key)
	cooldowns_updated.emit()


func current_weapon_id() -> int:
	if weapons.is_empty():
		return WeaponDefs.WeaponId.BLASTER
	return weapons[weapon_index]


func current_weapon_name() -> String:
	return WeaponDefs.weapon_data(current_weapon_id()).get("name", "?")


func cycle_weapon(dir: int = 1) -> void:
	if weapons.is_empty():
		return
	weapon_index = (weapon_index + dir) % weapons.size()
	if weapon_index < 0:
		weapon_index = weapons.size() - 1
	weapon_changed.emit(current_weapon_name(), weapon_index)


func select_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	weapon_index = index
	weapon_changed.emit(current_weapon_name(), weapon_index)


func can_fire() -> bool:
	return weapon_cds.get(weapon_index, 0.0) <= 0.0


func fire(aim_origin: Vector3, aim_dir: Vector3) -> bool:
	if not can_fire() or owner_player == null:
		return false
	var id: int = current_weapon_id()
	weapon_cds[weapon_index] = float(WeaponDefs.weapon_data(id).get("cooldown", 1.0))
	cooldowns_updated.emit()
	CombatFx.request_weapon_fire(id, aim_origin, aim_dir, owner_player.peer_id, is_beast)
	return true


func execute_server_fire(weapon_id: int, origin: Vector3, dir: Vector3, peer: int, beast: bool) -> void:
	_server_fire(weapon_id, origin, dir, peer, beast)


func _server_fire(weapon_id: int, origin: Vector3, dir: Vector3, peer: int, beast: bool) -> void:
	var data: Dictionary = WeaponDefs.weapon_data(weapon_id)
	var vs_explorers := beast
	match data.get("type", ""):
		"melee":
			CombatFx.replicate_melee(peer, weapon_id, beast)
		"projectile":
			CombatFx.replicate_shot(origin, dir, data, peer, vs_explorers)
		"shotgun":
			var pellets: int = int(data.get("pellets", 5))
			if OS.has_feature("web") or NetworkManager.get_player_count() >= 4:
				pellets = mini(pellets, 3)
			var spread: float = float(data.get("spread", 0.15))
			for i in pellets:
				var offset := Vector3(
					randf_range(-spread, spread),
					randf_range(-spread * 0.5, spread * 0.5),
					randf_range(-spread, spread)
				)
				CombatFx.replicate_shot(origin, (dir + offset).normalized(), data, peer, vs_explorers)
		"grenade":
			var gdata := data.duplicate()
			gdata["explode"] = true
			gdata["explode_radius"] = data.get("radius", 4.0)
			gdata["lifetime"] = data.get("fuse", 1.1)
			var arc_dir := (dir + Vector3.UP * 0.35).normalized()
			CombatFx.replicate_shot(origin, arc_dir, gdata, peer, vs_explorers)
		"explosion":
			if owner_player:
				CombatFx.replicate_explosion(
					owner_player.global_position,
					float(data.get("radius", 5.0)),
					float(data.get("damage", 30)) * damage_mult,
					peer, vs_explorers, not vs_explorers
				)
			CombatFx.replicate_melee(peer, weapon_id, beast)
		"roar":
			CombatFx.replicate_roar(peer, weapon_id)


func apply_melee_hits(weapon_id: int) -> void:
	var data: Dictionary = WeaponDefs.weapon_data(weapon_id)
	if owner_player and owner_player.crew:
		owner_player.crew.play_attack()
	if not multiplayer.is_server() or owner_player == null:
		return
	var dmg: float = float(data.get("damage", 1)) * damage_mult
	var attack_area := owner_player.get_node_or_null("AttackArea") as Area3D
	if attack_area == null:
		return
	for body in attack_area.get_overlapping_bodies():
		if is_beast and body is ExplorerPlayer:
			var e := body as ExplorerPlayer
			if e.is_alive():
				e.take_hit.rpc(e.peer_id)
		elif not is_beast and body is BeastPlayer:
			(body as BeastPlayer).apply_damage.rpc(dmg * 15.0, 0.0, 0.0, owner_player.peer_id)


func apply_roar_hits(weapon_id: int) -> void:
	var data: Dictionary = WeaponDefs.weapon_data(weapon_id)
	if owner_player and owner_player.crew:
		owner_player.crew.play_attack()
	if not multiplayer.is_server() or owner_player == null:
		return
	var radius: float = float(data.get("radius", 10.0))
	var slow: float = float(data.get("slow", 0.45))
	var dur: float = float(data.get("duration", 2.5))
	for node in owner_player.get_tree().get_nodes_in_group("player_characters"):
		if node is ExplorerPlayer and owner_player.global_position.distance_to(node.global_position) <= radius:
			(node as ExplorerPlayer).apply_projectile_hit.rpc((node as ExplorerPlayer).peer_id, 0.0, slow, dur)


func use_ability(index: int) -> bool:
	if index < 0 or index >= abilities.size():
		return false
	if ability_cds.get(index, 0.0) > 0.0:
		return false
	var id: int = abilities[index]
	var data: Dictionary = WeaponDefs.ability_data(id)
	ability_cds[index] = float(data.get("cooldown", 5.0))
	cooldowns_updated.emit()
	CombatFx.request_ability(id, owner_player.peer_id if owner_player else 0)
	ability_used.emit(data.get("name", "?"))
	return true


func execute_server_ability(ability_id: int) -> void:
	if owner_player:
		CombatFx.replicate_ability(owner_player.peer_id, ability_id)


func apply_ability_effects(ability_id: int) -> void:
	if owner_player == null:
		return
	var data: Dictionary = WeaponDefs.ability_data(ability_id)
	match ability_id:
		WeaponDefs.AbilityId.DASH:
			if owner_player.is_multiplayer_authority():
				var dir := -owner_player.global_transform.basis.z
				owner_player.velocity += dir * 16.0
				owner_player.velocity.y = maxf(owner_player.velocity.y, 2.5)
		WeaponDefs.AbilityId.SHIELD:
			_set_buff("shield", float(data.get("duration", 3.0)))
			shielded = true
		WeaponDefs.AbilityId.EMP:
			if multiplayer.is_server():
				var radius: float = float(data.get("radius", 7.0))
				for node in owner_player.get_tree().get_nodes_in_group("player_characters"):
					if node is BeastPlayer and owner_player.global_position.distance_to(node.global_position) <= radius:
						(node as BeastPlayer).apply_damage.rpc(5.0, 0.7, float(data.get("duration", 2.0)), owner_player.peer_id)
				CombatFx.replicate_explosion(owner_player.global_position, radius, 5.0, owner_player.peer_id, false, true)
		WeaponDefs.AbilityId.SPEED_BOOST:
			_set_buff("speed", float(data.get("duration", 3.5)))
			speed_mult = float(data.get("mult", 1.55))
		WeaponDefs.AbilityId.LEAP:
			if owner_player.is_multiplayer_authority():
				owner_player.velocity.y = float(data.get("force", 16.0))
				owner_player.velocity += -owner_player.global_transform.basis.z * 8.0
		WeaponDefs.AbilityId.RAGE:
			_set_buff("rage", float(data.get("duration", 4.0)))
			damage_mult = float(data.get("mult", 1.4))
			speed_mult = 1.25
		WeaponDefs.AbilityId.CLOAK:
			_set_buff("cloak", float(data.get("duration", 3.5)))
			cloaked = true
			if owner_player.crew:
				owner_player.crew.modulate_alpha(0.25)
		WeaponDefs.AbilityId.GROUND_SPIKES:
			if multiplayer.is_server():
				CombatFx.replicate_explosion(
					owner_player.global_position,
					float(data.get("radius", 4.0)),
					float(data.get("damage", 25)),
					owner_player.peer_id, true, false
				)


func _set_buff(key: String, duration: float) -> void:
	_buff_timers[key] = duration


func clear_buff(key: String) -> void:
	_clear_buff(key)


func _clear_buff(key: String) -> void:
	_buff_timers.erase(key)
	match key:
		"shield":
			shielded = false
		"speed", "slow":
			speed_mult = 1.0
			slowed = false
		"rage":
			damage_mult = 1.0
			speed_mult = 1.0
		"cloak":
			cloaked = false
			if owner_player and owner_player.crew:
				owner_player.crew.modulate_alpha(1.0)


func apply_slow(amount: float, duration: float) -> void:
	slowed = true
	speed_mult = minf(speed_mult, maxf(1.0 - amount, 0.35))
	_set_buff("slow", duration)


func get_hud_text() -> String:
	var wname := current_weapon_name()
	var wcd: float = weapon_cds.get(weapon_index, 0.0)
	var lines := "Arma: %s" % wname
	if wcd > 0.05:
		lines += " (%.1fs)" % wcd
	lines += "\n"
	for i in abilities.size():
		var aname: String = WeaponDefs.ability_data(abilities[i]).get("name", "?")
		var acd: float = ability_cds.get(i, 0.0)
		if acd > 0.05:
			lines += "[%d]%s %.0fs " % [i + 1, aname, acd]
		else:
			lines += "[%d]%s " % [i + 1, aname]
	return lines

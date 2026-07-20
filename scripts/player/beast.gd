class_name BeastPlayer
extends PlayerBase

const MAX_HP := 120.0

@onready var attack_area: Area3D = $AttackArea

var hp := MAX_HP


func _ready() -> void:
	super._ready()
	move_speed = 7.0 if not GameManager.easy_beast_mode else 5.8
	sprint_multiplier = 1.35
	_apply_beast_visuals()
	combat.setup(self, true, int(GameManager.beast_variant))


func _apply_beast_visuals() -> void:
	if crew == null:
		return
	crew.is_beast = true
	var colors := GameManager.get_beast_colors()
	crew.apply_colors(colors.body, colors.visor, colors.accent)
	var pname: String = str(NetworkManager.players.get(peer_id, {}).get("name", "Bestia"))
	crew.set_player_name(pname)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
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
func apply_damage(amount: float, slow: float = 0.0, slow_dur: float = 0.0, _from_peer: int = 0) -> void:
	if combat and combat.shielded:
		amount *= 0.25
	if combat and combat.cloaked:
		combat.clear_buff("cloak")
	hp = maxf(hp - amount, 0.0)
	if crew:
		crew.play_hit()
	if slow > 0.0 and combat:
		combat.apply_slow(slow, slow_dur)
	if hp <= 0.0:
		_on_defeated()


func _on_defeated() -> void:
	# Stun temporal + regen (no elimina a la bestia)
	hp = MAX_HP * 0.35
	if combat:
		combat.apply_slow(0.6, 3.0)
	visible = true
	if crew:
		crew.play_hit()


func get_hp_ratio() -> float:
	return hp / MAX_HP

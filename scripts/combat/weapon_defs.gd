class_name WeaponDefs
extends RefCounted

## Catálogo de armas y habilidades.

enum WeaponId {
	CLAW,
	FIRE_SPIT,
	SLAM_BOMB,
	ROAR_WAVE,
	BLASTER,
	SHOTGUN,
	GRENADE,
	PLASMA,
	ICE_RAY,
	RAILGUN,
	FLAMETHROWER,
	VOID_ORB,
}

enum AbilityId {
	DASH,
	SHIELD,
	EMP,
	SPEED_BOOST,
	LEAP,
	RAGE,
	CLOAK,
	GROUND_SPIKES,
	HEAL_PULSE,
	TRAP_MINE,
}


static func weapon_data(id: WeaponId) -> Dictionary:
	match id:
		WeaponId.CLAW:
			return {"name": "Garras", "cooldown": 0.9, "damage": 1, "type": "melee", "range": 2.8, "color": Color(1, 0.3, 0.2)}
		WeaponId.FIRE_SPIT:
			return {"name": "Escupitajo", "cooldown": 0.55, "damage": 18, "type": "projectile", "speed": 22.0, "lifetime": 1.4, "color": Color(1.0, 0.4, 0.05), "radius": 0.18}
		WeaponId.SLAM_BOMB:
			return {"name": "Bomba Slam", "cooldown": 2.8, "damage": 35, "type": "explosion", "radius": 5.0, "color": Color(1.0, 0.5, 0.1)}
		WeaponId.ROAR_WAVE:
			return {"name": "Rugido", "cooldown": 4.0, "damage": 0, "type": "roar", "radius": 10.0, "slow": 0.45, "duration": 2.5, "color": Color(0.8, 0.1, 0.9)}
		WeaponId.BLASTER:
			return {"name": "Bláster", "cooldown": 0.28, "damage": 12, "type": "projectile", "speed": 28.0, "lifetime": 1.2, "color": Color(0.3, 0.9, 1.0), "radius": 0.12}
		WeaponId.SHOTGUN:
			return {"name": "Escopeta", "cooldown": 0.85, "damage": 8, "type": "shotgun", "pellets": 5, "spread": 0.18, "speed": 24.0, "lifetime": 0.7, "color": Color(1.0, 0.85, 0.2), "radius": 0.1}
		WeaponId.GRENADE:
			return {"name": "Granada", "cooldown": 2.2, "damage": 40, "type": "grenade", "speed": 14.0, "fuse": 1.1, "radius": 4.5, "color": Color(0.2, 1.0, 0.35)}
		WeaponId.PLASMA:
			return {"name": "Plasma", "cooldown": 0.7, "damage": 22, "type": "projectile", "speed": 20.0, "lifetime": 1.5, "color": Color(0.7, 0.2, 1.0), "radius": 0.2, "explode": true, "explode_radius": 2.2}
		WeaponId.ICE_RAY:
			return {"name": "Rayo Hielo", "cooldown": 0.5, "damage": 8, "type": "projectile", "speed": 26.0, "lifetime": 1.0, "color": Color(0.5, 0.85, 1.0), "radius": 0.12, "slow": 0.5, "slow_duration": 1.8}
		WeaponId.RAILGUN:
			return {"name": "Railgun", "cooldown": 1.35, "damage": 38, "type": "projectile", "speed": 48.0, "lifetime": 0.9, "color": Color(0.55, 1.0, 0.85), "radius": 0.1}
		WeaponId.FLAMETHROWER:
			return {"name": "Lanzallamas", "cooldown": 0.12, "damage": 5, "type": "shotgun", "pellets": 3, "spread": 0.28, "speed": 14.0, "lifetime": 0.35, "color": Color(1.0, 0.45, 0.1), "radius": 0.14}
		WeaponId.VOID_ORB:
			return {"name": "Orbe Vacío", "cooldown": 1.8, "damage": 28, "type": "projectile", "speed": 12.0, "lifetime": 2.2, "color": Color(0.45, 0.15, 0.85), "radius": 0.28, "explode": true, "explode_radius": 3.4, "slow": 0.35, "slow_duration": 1.4}
	return {"name": "?", "cooldown": 1.0, "damage": 1, "type": "melee"}


static func beast_loadout(variant: int) -> Array:
	match variant:
		2: # SHADOW
			return [WeaponId.CLAW, WeaponId.VOID_ORB, WeaponId.ROAR_WAVE, WeaponId.SLAM_BOMB]
		1: # MECHA
			return [WeaponId.CLAW, WeaponId.FIRE_SPIT, WeaponId.SLAM_BOMB, WeaponId.ROAR_WAVE]
		_: # CLASSIC
			return [WeaponId.CLAW, WeaponId.FIRE_SPIT, WeaponId.FLAMETHROWER, WeaponId.SLAM_BOMB]


static func explorer_loadout(loadout_id: int) -> Array:
	## 0 Asalto · 1 Escopetero · 2 Demolición · 3 Soporte
	match loadout_id:
		1:
			return [WeaponId.SHOTGUN, WeaponId.GRENADE, WeaponId.FLAMETHROWER, WeaponId.PLASMA]
		2:
			return [WeaponId.GRENADE, WeaponId.PLASMA, WeaponId.RAILGUN, WeaponId.SHOTGUN]
		3:
			return [WeaponId.ICE_RAY, WeaponId.BLASTER, WeaponId.GRENADE, WeaponId.VOID_ORB]
		_:
			return [WeaponId.BLASTER, WeaponId.RAILGUN, WeaponId.ICE_RAY, WeaponId.PLASMA]


static func explorer_loadout_name(loadout_id: int) -> String:
	match loadout_id:
		1: return "Escopetero"
		2: return "Demolición"
		3: return "Soporte"
		_: return "Asalto"


static func explorer_skin_name(skin: int) -> String:
	var n: String = CharacterCatalog.display_name(skin)
	if n != "?" and not n.is_empty():
		return n
	match skin:
		1: return "Rosa"
		2: return "Verde"
		3: return "Amarillo"
		_: return "Azul"


static func beast_abilities(variant: int) -> Array:
	match variant:
		2:
			return [AbilityId.DASH, AbilityId.CLOAK, AbilityId.LEAP, AbilityId.TRAP_MINE]
		1:
			return [AbilityId.DASH, AbilityId.GROUND_SPIKES, AbilityId.LEAP, AbilityId.RAGE]
		_:
			return [AbilityId.DASH, AbilityId.LEAP, AbilityId.RAGE, AbilityId.HEAL_PULSE]


static func explorer_abilities(loadout_id: int) -> Array:
	match loadout_id:
		1:
			return [AbilityId.DASH, AbilityId.SHIELD, AbilityId.TRAP_MINE, AbilityId.SPEED_BOOST]
		2:
			return [AbilityId.DASH, AbilityId.EMP, AbilityId.TRAP_MINE, AbilityId.SHIELD]
		3:
			return [AbilityId.DASH, AbilityId.HEAL_PULSE, AbilityId.SHIELD, AbilityId.EMP]
		_:
			return [AbilityId.DASH, AbilityId.SHIELD, AbilityId.EMP, AbilityId.SPEED_BOOST]


static func ability_data(id: AbilityId) -> Dictionary:
	match id:
		AbilityId.DASH:
			return {"name": "Dash", "cooldown": 3.0, "duration": 0.25, "color": Color(0.4, 0.9, 1.0)}
		AbilityId.SHIELD:
			return {"name": "Escudo", "cooldown": 8.0, "duration": 3.0, "color": Color(0.4, 0.8, 1.0)}
		AbilityId.EMP:
			return {"name": "EMP", "cooldown": 10.0, "duration": 2.0, "radius": 7.0, "color": Color(0.7, 0.3, 1.0)}
		AbilityId.SPEED_BOOST:
			return {"name": "Turbo", "cooldown": 7.0, "duration": 3.5, "mult": 1.55, "color": Color(0.3, 1.0, 0.5)}
		AbilityId.LEAP:
			return {"name": "Salto", "cooldown": 5.0, "force": 16.0, "color": Color(1.0, 0.85, 0.3)}
		AbilityId.RAGE:
			return {"name": "Furia", "cooldown": 12.0, "duration": 4.0, "mult": 1.4, "color": Color(1.0, 0.2, 0.15)}
		AbilityId.CLOAK:
			return {"name": "Camuflaje", "cooldown": 11.0, "duration": 3.5, "color": Color(0.6, 0.4, 0.9)}
		AbilityId.GROUND_SPIKES:
			return {"name": "Púas", "cooldown": 9.0, "damage": 25, "radius": 4.0, "color": Color(0.9, 0.4, 0.1)}
		AbilityId.HEAL_PULSE:
			return {"name": "Pulso", "cooldown": 11.0, "duration": 0.2, "color": Color(0.3, 1.0, 0.55)}
		AbilityId.TRAP_MINE:
			return {"name": "Mina", "cooldown": 9.5, "damage": 28, "radius": 3.2, "color": Color(1.0, 0.55, 0.15)}
	return {"name": "?", "cooldown": 5.0}

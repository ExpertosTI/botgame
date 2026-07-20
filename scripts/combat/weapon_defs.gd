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
	return {"name": "?", "cooldown": 1.0, "damage": 1, "type": "melee"}


static func beast_loadout(variant: int) -> Array:
	match variant:
		2: # SHADOW
			return [WeaponId.CLAW, WeaponId.FIRE_SPIT, WeaponId.ROAR_WAVE, WeaponId.SLAM_BOMB]
		1: # MECHA
			return [WeaponId.CLAW, WeaponId.FIRE_SPIT, WeaponId.SLAM_BOMB, WeaponId.ROAR_WAVE]
		_: # CLASSIC
			return [WeaponId.CLAW, WeaponId.FIRE_SPIT, WeaponId.SLAM_BOMB, WeaponId.ROAR_WAVE]


static func explorer_loadout(variant: int) -> Array:
	match variant:
		0: # BLUE
			return [WeaponId.BLASTER, WeaponId.GRENADE, WeaponId.ICE_RAY, WeaponId.PLASMA]
		1: # PINK
			return [WeaponId.SHOTGUN, WeaponId.GRENADE, WeaponId.BLASTER, WeaponId.PLASMA]
		2: # GREEN
			return [WeaponId.PLASMA, WeaponId.GRENADE, WeaponId.BLASTER, WeaponId.ICE_RAY]
		_: # YELLOW
			return [WeaponId.BLASTER, WeaponId.SHOTGUN, WeaponId.GRENADE, WeaponId.ICE_RAY]


static func beast_abilities(variant: int) -> Array:
	match variant:
		2:
			return [AbilityId.DASH, AbilityId.CLOAK, AbilityId.LEAP, AbilityId.RAGE]
		1:
			return [AbilityId.DASH, AbilityId.GROUND_SPIKES, AbilityId.LEAP, AbilityId.RAGE]
		_:
			return [AbilityId.DASH, AbilityId.LEAP, AbilityId.RAGE, AbilityId.GROUND_SPIKES]


static func explorer_abilities(_variant: int) -> Array:
	return [AbilityId.DASH, AbilityId.SHIELD, AbilityId.EMP, AbilityId.SPEED_BOOST]


static func ability_data(id: AbilityId) -> Dictionary:
	match id:
		AbilityId.DASH:
			return {"name": "Dash", "cooldown": 3.0, "duration": 0.25}
		AbilityId.SHIELD:
			return {"name": "Escudo", "cooldown": 8.0, "duration": 3.0}
		AbilityId.EMP:
			return {"name": "EMP", "cooldown": 10.0, "duration": 2.0, "radius": 7.0}
		AbilityId.SPEED_BOOST:
			return {"name": "Turbo", "cooldown": 7.0, "duration": 3.5, "mult": 1.55}
		AbilityId.LEAP:
			return {"name": "Salto", "cooldown": 5.0, "force": 16.0}
		AbilityId.RAGE:
			return {"name": "Furia", "cooldown": 12.0, "duration": 4.0, "mult": 1.4}
		AbilityId.CLOAK:
			return {"name": "Camuflaje", "cooldown": 11.0, "duration": 3.5}
		AbilityId.GROUND_SPIKES:
			return {"name": "Púas", "cooldown": 9.0, "damage": 25, "radius": 4.0}
	return {"name": "?", "cooldown": 5.0}

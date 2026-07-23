extends Node

## Catálogo unificado de personajes (robots / bestias / extras).

signal catalog_ready

const FALLBACK_CREW := true

## Entries: id, name, role ("explorer"|"beast"|"any"), mesh path, tint, unlock_wins
var entries: Array[Dictionary] = []


func _ready() -> void:
	_build()
	catalog_ready.emit()


func _build() -> void:
	entries.clear()
	# Capsule originals (siempre disponibles, Web-friendly)
	_add("crew_blue", "Robot Azul", "explorer", "", Color(0.25, 0.55, 1.0), 0)
	_add("crew_pink", "Robot Rosa", "explorer", "", Color(1.0, 0.4, 0.7), 0)
	_add("crew_green", "Robot Verde", "explorer", "", Color(0.25, 0.85, 0.45), 0)
	_add("crew_yellow", "Robot Amarillo", "explorer", "", Color(1.0, 0.85, 0.2), 0)
	# Kenney blocky
	_add("blocky_a", "Blocky A", "explorer", "res://assets/characters/roster/blocky_a.glb", Color(0.9, 0.9, 0.95), 0)
	_add("blocky_b", "Blocky B", "explorer", "res://assets/characters/roster/blocky_b.glb", Color(0.95, 0.7, 0.3), 1)
	_add("blocky_c", "Blocky C", "explorer", "res://assets/characters/roster/blocky_c.glb", Color(0.4, 0.8, 0.95), 1)
	_add("blocky_d", "Blocky D", "explorer", "res://assets/characters/roster/blocky_d.glb", Color(0.7, 0.5, 0.95), 2)
	_add("blocky_e", "Blocky E", "explorer", "res://assets/characters/roster/blocky_e.glb", Color(0.95, 0.45, 0.55), 2)
	_add("blocky_f", "Blocky F", "explorer", "res://assets/characters/roster/blocky_f.glb", Color(0.45, 0.95, 0.55), 3)
	# KayKit adventurers
	_add("kay_knight", "Caballero", "explorer", "res://assets/characters/roster/kay_knight.glb", Color(0.7, 0.75, 0.85), 2)
	_add("kay_mage", "Mago", "explorer", "res://assets/characters/roster/kay_mage.glb", Color(0.55, 0.45, 0.95), 3)
	_add("kay_rogue", "Pícaro", "explorer", "res://assets/characters/roster/kay_rogue.glb", Color(0.35, 0.55, 0.4), 3)
	_add("kay_barbarian", "Bárbaro", "explorer", "res://assets/characters/roster/kay_barbarian.glb", Color(0.85, 0.45, 0.3), 4)
	_add("kay_ranger", "Explorador", "explorer", "res://assets/characters/roster/kay_ranger.glb", Color(0.4, 0.7, 0.45), 4)
	_add("forest_archer", "Arquero", "explorer", "res://assets/characters/roster/forest_archer.glb", Color(0.5, 0.75, 0.4), 3)
	# Beast / enemies
	_add("beast_classic", "Bestia Clásica", "beast", "", Color(0.75, 0.12, 0.15), 0)
	_add("beast_mecha", "Mecha Destructor", "beast", "", Color(0.28, 0.3, 0.35), 0)
	_add("beast_shadow", "Sombra Digital", "beast", "", Color(0.18, 0.1, 0.28), 2)
	_add("skel_warrior", "Esqueleto Guerrero", "beast", "res://assets/characters/roster/skel_warrior.glb", Color(0.9, 0.9, 0.85), 3)
	_add("skel_mage", "Esqueleto Mago", "beast", "res://assets/characters/roster/skel_mage.glb", Color(0.6, 0.85, 0.95), 4)


func _add(id: String, name: String, role: String, mesh: String, tint: Color, unlock_wins: int) -> void:
	entries.append({
		"id": id,
		"name": name,
		"role": role,
		"mesh": mesh,
		"tint": tint,
		"unlock_wins": unlock_wins,
	})


func count() -> int:
	return entries.size()


func get_entry(index: int) -> Dictionary:
	if index < 0 or index >= entries.size():
		return entries[0] if not entries.is_empty() else {}
	return entries[index]


func find_by_id(id: String) -> Dictionary:
	for e in entries:
		if str(e.get("id", "")) == id:
			return e
	return {}


func index_of_id(id: String) -> int:
	for i in entries.size():
		if str(entries[i].get("id", "")) == id:
			return i
	return 0


func explorer_indices() -> Array:
	var out: Array = []
	for i in entries.size():
		var r: String = str(entries[i].get("role", ""))
		if r == "explorer" or r == "any":
			out.append(i)
	return out


func beast_indices() -> Array:
	var out: Array = []
	for i in entries.size():
		var r: String = str(entries[i].get("role", ""))
		if r == "beast" or r == "any":
			out.append(i)
	return out


func is_unlocked(index: int) -> bool:
	var e := get_entry(index)
	if e.is_empty():
		return false
	return ProgressionManager.wins_total >= int(e.get("unlock_wins", 0))


func display_name(index: int) -> String:
	return str(get_entry(index).get("name", "?"))


## Instancia mesh GLB bajo parent; escala tipica para CharacterBody.
func attach_mesh(parent: Node3D, index: int, scale_mult: float = 1.0) -> Node3D:
	var e := get_entry(index)
	var path: String = str(e.get("mesh", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if packed == null:
		return null
	var node: Node3D
	if packed is PackedScene:
		node = (packed as PackedScene).instantiate() as Node3D
	else:
		return null
	if node == null:
		return null
	node.name = "CatalogMesh"
	node.scale = Vector3.ONE * scale_mult
	parent.add_child(node)
	_prepare_runtime_mesh(node)
	return node


func _prepare_runtime_mesh(root: Node) -> void:
	## Web: sin sombras / GI; idle anim si existe.
	var web := OS.has_feature("web") or OS.get_name() == "Web"
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		gi.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if web
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for ap_n in root.find_children("*", "AnimationPlayer", true, false):
		var ap := ap_n as AnimationPlayer
		if ap == null:
			continue
		var idle := ""
		for anim in ap.get_animation_list():
			var low := str(anim).to_lower()
			if "idle" in low or "stand" in low or "wait" in low:
				idle = str(anim)
				break
		if idle.is_empty() and not ap.get_animation_list().is_empty():
			idle = str(ap.get_animation_list()[0])
		if not idle.is_empty():
			ap.play(idle)

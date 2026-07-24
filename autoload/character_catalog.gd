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


func default_explorer_skin() -> int:
	## Primer robot 3D desbloqueado (Blocky A); evita cápsula verde legacy.
	var prefer := index_of_id("blocky_a")
	if prefer > 0 or str(get_entry(prefer).get("id", "")) == "blocky_a":
		var mesh := str(get_entry(prefer).get("mesh", ""))
		if not mesh.is_empty() and ResourceLoader.exists(mesh):
			return prefer
	for idx in explorer_indices():
		var i := int(idx)
		var mesh := str(get_entry(i).get("mesh", ""))
		if not mesh.is_empty() and ResourceLoader.exists(mesh) and is_unlocked(i):
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
	## Web: sin sombras / GI; cachea clips idle/walk/sprint.
	var web := OS.has_feature("web") or OS.get_name() == "Web"
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		gi.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if web
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		# Materiales un poco más “sólidos” bajo luz Compatibility/WebGL
		if gi.material_override is StandardMaterial3D:
			var m := gi.material_override as StandardMaterial3D
			m.roughness = clampf(m.roughness * 0.85, 0.25, 0.95)
	var ap := find_animation_player(root)
	if ap:
		var idle := _pick_anim(ap, ["idle", "stand", "wait", "static"])
		var walk := _pick_anim(ap, ["walk", "run", "move"])
		var sprint := _pick_anim(ap, ["sprint", "run-fast", "run"])
		root.set_meta("cat_ap", ap.get_path())
		root.set_meta("cat_idle", idle)
		root.set_meta("cat_walk", walk if not walk.is_empty() else idle)
		root.set_meta("cat_sprint", sprint if not sprint.is_empty() else (walk if not walk.is_empty() else idle))
		if not idle.is_empty():
			ap.play(idle)
	root.set_meta("cat_moving", false)


func find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	for ap_n in root.find_children("*", "AnimationPlayer", true, false):
		var ap := ap_n as AnimationPlayer
		if ap and not ap.get_animation_list().is_empty():
			return ap
	return null


func _pick_anim(ap: AnimationPlayer, keys: Array) -> String:
	var list := ap.get_animation_list()
	for key in keys:
		var k := str(key).to_lower()
		for anim in list:
			var low := str(anim).to_lower()
			if low == k or k in low:
				return str(anim)
	return ""


## Idle ↔ walk/sprint según movimiento (Blocky/Kenney). Kay sin clips: bob procedural.
func play_locomotion(root: Node, moving: bool, sprint: bool = false) -> void:
	if root == null or not is_instance_valid(root):
		return
	var was: bool = bool(root.get_meta("cat_moving", false))
	root.set_meta("cat_moving", moving)
	var ap: AnimationPlayer = null
	if root.has_meta("cat_ap"):
		ap = root.get_node_or_null(root.get_meta("cat_ap")) as AnimationPlayer
	if ap == null:
		ap = find_animation_player(root)
	if ap:
		var clip := ""
		if moving:
			clip = str(root.get_meta("cat_sprint" if sprint else "cat_walk", ""))
		else:
			clip = str(root.get_meta("cat_idle", ""))
		if clip.is_empty():
			return
		var cur := str(ap.current_animation)
		if cur != clip:
			ap.play(clip)
		return
	# Sin AnimationPlayer: balanceo suave al caminar
	if moving != was or moving:
		root.set_meta("cat_bob_t", float(root.get_meta("cat_bob_t", 0.0)))


## Hangar: arma (o garras) + pose de movimiento al seleccionar.
func attach_showcase_loadout(root: Node3D, role: String = "explorer") -> void:
	if root == null:
		return
	var old := root.get_node_or_null("ShowcaseWeapon")
	if old:
		old.queue_free()
	var gear := Node3D.new()
	gear.name = "ShowcaseWeapon"
	if role == "beast":
		_build_claw_mesh(gear)
		gear.position = Vector3(0.55, 0.95, 0.2)
		gear.rotation_degrees = Vector3(10, 0, -25)
	else:
		_build_blaster_mesh(gear)
		gear.position = Vector3(0.48, 0.92, 0.28)
		gear.rotation_degrees = Vector3(8, 15, -8)
	root.add_child(gear)


func play_showcase_motion(root: Node) -> void:
	## Prefiere walk; si hay holding-right + walk, usa walk (arma es mesh aparte).
	if root == null:
		return
	play_locomotion(root, true, false)
	var ap := find_animation_player(root)
	if ap == null:
		return
	# Algunas skins tienen “holding-right”: prioriza walk con arma visible
	var walk := _pick_anim(ap, ["walk", "run", "move"])
	if not walk.is_empty() and ap.current_animation != walk:
		ap.play(walk)


func _build_blaster_mesh(parent: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.2, 0.25)
	mat.metallic = 0.85
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.85, 0.75)
	mat.emission_energy_multiplier = 0.55
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.16, 0.58)
	body.mesh = box
	body.material_override = mat
	parent.add_child(body)
	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.045
	cyl.height = 0.28
	barrel.mesh = cyl
	barrel.rotation_degrees.x = 90
	barrel.position = Vector3(0, 0.02, -0.4)
	var bmat := mat.duplicate() as StandardMaterial3D
	bmat.albedo_color = Color(0.25, 0.9, 0.85)
	barrel.material_override = bmat
	parent.add_child(barrel)
	var sight := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(0.04, 0.08, 0.1)
	sight.mesh = sbox
	sight.position = Vector3(0, 0.12, -0.05)
	sight.material_override = bmat
	parent.add_child(sight)


func _build_claw_mesh(parent: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.2, 0.22)
	mat.metallic = 0.4
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.2)
	mat.emission_energy_multiplier = 0.4
	for i in 3:
		var claw := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.08, 0.42)
		claw.mesh = box
		claw.material_override = mat
		claw.position = Vector3((i - 1) * 0.09, 0, -0.12)
		claw.rotation_degrees = Vector3(-15 + i * 5, 0, (i - 1) * 12)
		parent.add_child(claw)


func tick_locomotion(root: Node, delta: float) -> void:
	if root == null or not is_instance_valid(root):
		return
	if find_animation_player(root) != null:
		return
	if not bool(root.get_meta("cat_moving", false)):
		root.rotation.x = move_toward(root.rotation.x, 0.0, delta * 4.0)
		root.position.y = move_toward(root.position.y, float(root.get_meta("cat_base_y", root.position.y)), delta * 4.0)
		return
	if not root.has_meta("cat_base_y"):
		root.set_meta("cat_base_y", root.position.y)
	var t := float(root.get_meta("cat_bob_t", 0.0)) + delta * 9.0
	root.set_meta("cat_bob_t", t)
	var base_y := float(root.get_meta("cat_base_y", 0.0))
	root.position.y = base_y + sin(t) * 0.04
	root.rotation.x = sin(t * 0.5) * 0.06


## Encuadre showcase (menú / lobby): altura objetivo + pies en el pedestal.
func fit_for_showcase(node: Node3D, target_height: float = 2.05) -> void:
	if node == null:
		return
	var aabb := _mesh_aabb(node)
	if aabb.size.length() < 0.01:
		return
	var h := maxf(aabb.size.y, 0.05)
	var s := target_height / h
	node.scale *= s
	aabb = _mesh_aabb(node)
	var c := aabb.get_center()
	node.position.x -= c.x
	node.position.z -= c.z
	node.position.y -= aabb.position.y
	node.set_meta("cat_base_y", node.position.y)


func _mesh_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if vi == null:
			continue
		var local := vi.get_aabb()
		var xf := vi.global_transform
		# Esquinas del AABB en espacio de root
		for i in 8:
			var corner := local.get_endpoint(i)
			var world := xf * corner
			var local_root := root.global_transform.affine_inverse() * world
			if first:
				out = AABB(local_root, Vector3.ZERO)
				first = false
			else:
				out = out.expand(local_root)
	return out

class_name CrewVisual
extends Node3D

## Construye un personaje cápsula estilo "crewmate" original.

@export var is_beast := false
@export var body_scale := 1.0

var body_mesh: MeshInstance3D
var visor_mesh: MeshInstance3D
var backpack_mesh: MeshInstance3D
var leg_l: MeshInstance3D
var leg_r: MeshInstance3D
var horn_l: MeshInstance3D
var horn_r: MeshInstance3D
var antenna: MeshInstance3D
var name_label: Label3D

var _idle_tween: Tween
var _walk_phase := 0.0
var _moving := false


func _ready() -> void:
	_build()
	_start_idle()


func _build() -> void:
	var s := body_scale * (1.45 if is_beast else 1.0)

	body_mesh = MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.38 * s
	body.height = 0.95 * s
	body_mesh.mesh = body
	body_mesh.position = Vector3(0, 0.72 * s, 0)
	add_child(body_mesh)

	visor_mesh = MeshInstance3D.new()
	var visor := SphereMesh.new()
	visor.radius = 0.28 * s
	visor.height = 0.42 * s
	visor_mesh.mesh = visor
	visor_mesh.scale = Vector3(1.1, 0.75, 0.55)
	visor_mesh.position = Vector3(0, 0.85 * s, 0.28 * s)
	add_child(visor_mesh)

	backpack_mesh = MeshInstance3D.new()
	var pack := BoxMesh.new()
	pack.size = Vector3(0.42 * s, 0.5 * s, 0.22 * s)
	backpack_mesh.mesh = pack
	backpack_mesh.position = Vector3(0, 0.7 * s, -0.32 * s)
	add_child(backpack_mesh)

	leg_l = _make_leg(Vector3(-0.14 * s, 0.18 * s, 0), s)
	leg_r = _make_leg(Vector3(0.14 * s, 0.18 * s, 0), s)
	add_child(leg_l)
	add_child(leg_r)

	if is_beast:
		horn_l = _make_horn(Vector3(-0.18 * s, 1.25 * s, 0), s, -0.3)
		horn_r = _make_horn(Vector3(0.18 * s, 1.25 * s, 0), s, 0.3)
		add_child(horn_l)
		add_child(horn_r)
	else:
		antenna = MeshInstance3D.new()
		var ant := CylinderMesh.new()
		ant.top_radius = 0.02 * s
		ant.bottom_radius = 0.03 * s
		ant.height = 0.22 * s
		antenna.mesh = ant
		antenna.position = Vector3(0.12 * s, 1.25 * s, 0)
		add_child(antenna)
		var tip := MeshInstance3D.new()
		var tip_mesh := SphereMesh.new()
		tip_mesh.radius = 0.05 * s
		tip.mesh = tip_mesh
		tip.position = Vector3(0.12 * s, 1.38 * s, 0)
		tip.name = "AntennaTip"
		add_child(tip)

	name_label = Label3D.new()
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 48
	name_label.outline_size = 8
	name_label.position = Vector3(0, 1.55 * s, 0)
	name_label.modulate = Color.WHITE
	add_child(name_label)


func _make_leg(pos: Vector3, s: float) -> MeshInstance3D:
	var leg := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.1 * s
	mesh.height = 0.28 * s
	leg.mesh = mesh
	leg.position = pos
	return leg


func _make_horn(pos: Vector3, s: float, tilt: float) -> MeshInstance3D:
	var horn := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.01 * s
	mesh.bottom_radius = 0.06 * s
	mesh.height = 0.28 * s
	horn.mesh = mesh
	horn.position = pos
	horn.rotation_degrees = Vector3(15, 0, tilt * 40.0)
	return horn


func apply_colors(body: Color, visor: Color, accent: Color = Color.WHITE) -> void:
	_set_mat(body_mesh, body, 0.15)
	_set_mat(visor_mesh, visor, 0.9, true)
	_set_mat(backpack_mesh, accent.darkened(0.15), 0.1)
	_set_mat(leg_l, body.darkened(0.1), 0.1)
	_set_mat(leg_r, body.darkened(0.1), 0.1)
	if horn_l:
		_set_mat(horn_l, accent, 0.2)
		_set_mat(horn_r, accent, 0.2)
	if antenna:
		_set_mat(antenna, accent, 0.3)
		var tip := get_node_or_null("AntennaTip") as MeshInstance3D
		if tip:
			_set_mat(tip, visor, 1.2, true)


func set_player_name(text: String) -> void:
	if name_label:
		name_label.text = text


func _set_mat(mi: MeshInstance3D, color: Color, emission: float = 0.0, shiny: bool = false) -> void:
	if mi == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.35 if shiny else 0.55
	mat.metallic = 0.35 if shiny else 0.05
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	mi.material_override = mat


func _start_idle() -> void:
	if _idle_tween:
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(body_mesh, "position:y", body_mesh.position.y + 0.04, 0.55).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(body_mesh, "position:y", body_mesh.position.y, 0.55).set_trans(Tween.TRANS_SINE)


func set_moving(moving: bool) -> void:
	_moving = moving


func _process(delta: float) -> void:
	if not _moving:
		leg_l.rotation.x = move_toward(leg_l.rotation.x, 0.0, delta * 8.0)
		leg_r.rotation.x = move_toward(leg_r.rotation.x, 0.0, delta * 8.0)
		return
	_walk_phase += delta * 12.0
	leg_l.rotation.x = sin(_walk_phase) * 0.45
	leg_r.rotation.x = sin(_walk_phase + PI) * 0.45


func play_attack() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.25, 0.85, 1.25), 0.08)
	tween.tween_property(self, "scale", Vector3.ONE, 0.18)


func play_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.85, 1.2, 0.85), 0.08)
	tween.tween_property(self, "scale", Vector3.ONE, 0.15)


func play_sabotage_pulse(active: bool) -> void:
	if active:
		var tween := create_tween().set_loops()
		tween.tween_property(self, "rotation_degrees:y", 8.0, 0.12)
		tween.tween_property(self, "rotation_degrees:y", -8.0, 0.12)
		set_meta("sabotage_tween", tween)
	else:
		if has_meta("sabotage_tween"):
			var t: Tween = get_meta("sabotage_tween")
			if t:
				t.kill()
		rotation_degrees.y = 0.0


func modulate_alpha(a: float) -> void:
	for child in get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				var mat := mi.material_override as StandardMaterial3D
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				var c := mat.albedo_color
				c.a = a
				mat.albedo_color = c


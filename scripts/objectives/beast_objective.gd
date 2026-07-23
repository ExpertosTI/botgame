class_name BeastObjective
extends StaticBody3D

signal sabotaged

@export var health := 100.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var particles: GPUParticles3D = $DestroyParticles

var is_active := true
var sabotage_progress := 0.0
var variant: int = ObjectiveVariants.Variant.STANDARD
var sabotage_time_mult := 1.0
var _ring: MeshInstance3D


func _ready() -> void:
	add_to_group("beast_objectives")
	_apply_visual()


func apply_variant(v: int) -> void:
	variant = v
	sabotage_time_mult = ObjectiveVariants.sabotage_mult(v as ObjectiveVariants.Variant)
	_apply_visual()


func _apply_visual() -> void:
	if mesh == null:
		return
	var tint := ObjectiveVariants.tint(variant as ObjectiveVariants.Variant)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.35
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = tint.lightened(0.15)
	mat.emission_energy_multiplier = 2.4
	mesh.material_override = mat

	var lite := OS.has_feature("web") or OS.get_name() == "Web"

	if _ring == null:
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.55
		torus.outer_radius = 0.72
		if lite:
			torus.rings = 8
			torus.ring_segments = 12
		_ring.mesh = torus
		_ring.position = Vector3(0, 0.05, 0)
		add_child(_ring)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = tint
	ring_mat.emission_enabled = true
	ring_mat.emission = tint
	ring_mat.emission_energy_multiplier = 2.5 if lite else 3.0
	_ring.material_override = ring_mat

	if not lite and not has_node("CoreLight"):
		var light := OmniLight3D.new()
		light.name = "CoreLight"
		light.light_color = tint
		light.light_energy = 2.2
		light.omni_range = 4.5
		light.position = Vector3(0, 1.2, 0)
		add_child(light)

	# Etiqueta flotante de variante
	if variant != ObjectiveVariants.Variant.STANDARD and not has_meta("labeled"):
		set_meta("labeled", true)
		var lab := Label3D.new()
		lab.text = ObjectiveVariants.label(variant as ObjectiveVariants.Variant)
		lab.font_size = 48
		lab.modulate = tint
		lab.position = Vector3(0, 2.1, 0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lab)

	var tween := create_tween().set_loops()
	tween.tween_property(mat, "emission_energy_multiplier", 3.6 if lite else 4.2, 0.85)
	tween.parallel().tween_property(_ring, "scale", Vector3(1.1, 1.0, 1.1), 0.85)
	tween.tween_property(mat, "emission_energy_multiplier", 2.0, 0.85)
	tween.parallel().tween_property(_ring, "scale", Vector3.ONE, 0.85)


@rpc("any_peer", "call_local", "reliable")
func sabotage() -> void:
	if not is_active:
		return
	if not multiplayer.is_server():
		return
	_destroy()


func _destroy() -> void:
	is_active = false
	sabotaged.emit()
	GameManager.register_objective_destroyed()
	_play_destroy_effect.rpc()


@rpc("any_peer", "call_local", "reliable")
func _play_destroy_effect() -> void:
	AudioDirector.play_core()
	var tint := ObjectiveVariants.tint(variant as ObjectiveVariants.Variant)
	CombatVfx.burst(self, global_position + Vector3.UP, tint, 2.2, 16)
	CombatVfx.ring(self, global_position, tint, 3.0)
	if particles:
		particles.emitting = true
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.4)
	tween.tween_callback(queue_free)

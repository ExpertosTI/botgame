class_name BeastObjective
extends StaticBody3D

signal sabotaged

@export var health := 100.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var particles: GPUParticles3D = $DestroyParticles

var is_active := true
var sabotage_progress := 0.0


func _ready() -> void:
	add_to_group("beast_objectives")
	_apply_visual()


func _apply_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.22, 0.28)
	mat.metallic = 0.35
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.15)
	mat.emission_energy_multiplier = 2.4
	mesh.material_override = mat

	# Anillo luminoso en el suelo
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.72
	ring.mesh = torus
	ring.position = Vector3(0, 0.05, 0)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.4, 0.15)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.45, 0.1)
	ring_mat.emission_energy_multiplier = 3.0
	ring.material_override = ring_mat
	add_child(ring)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.2)
	light.light_energy = 2.8
	light.omni_range = 5.0
	light.position = Vector3(0, 1.2, 0)
	add_child(light)

	var tween := create_tween().set_loops()
	tween.tween_property(mat, "emission_energy_multiplier", 4.2, 0.85)
	tween.parallel().tween_property(ring, "scale", Vector3(1.12, 1.0, 1.12), 0.85)
	tween.tween_property(mat, "emission_energy_multiplier", 2.0, 0.85)
	tween.parallel().tween_property(ring, "scale", Vector3.ONE, 0.85)


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
	if particles:
		particles.emitting = true
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.4)
	tween.tween_callback(queue_free)

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
	mat.albedo_color = Color(0.9, 0.2, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.1)
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat

	var tween := create_tween().set_loops()
	tween.tween_property(mat, "emission_energy_multiplier", 3.5, 1.0)
	tween.tween_property(mat, "emission_energy_multiplier", 2.0, 1.0)


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

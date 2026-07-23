class_name Projectile
extends Area3D

signal hit_body(body: Node3D)

var velocity := Vector3.ZERO
var damage := 10.0
var lifetime := 1.5
var owner_peer := 0
var hurts_explorers := false
var hurts_beast := true
var explode_on_hit := false
var explode_radius := 2.0
var slow_amount := 0.0
var slow_duration := 0.0
var _age := 0.0
var _mesh: MeshInstance3D


func setup(from: Vector3, dir: Vector3, data: Dictionary, peer: int, vs_explorers: bool = false) -> void:
	global_position = from
	velocity = dir.normalized() * float(data.get("speed", 20.0))
	damage = float(data.get("damage", 10))
	lifetime = float(data.get("lifetime", 1.2))
	owner_peer = peer
	hurts_explorers = vs_explorers
	hurts_beast = not vs_explorers
	explode_on_hit = bool(data.get("explode", false))
	explode_radius = float(data.get("explode_radius", 2.0))
	slow_amount = float(data.get("slow", 0.0))
	slow_duration = float(data.get("slow_duration", 0.0))
	_build_mesh(data.get("color", Color.WHITE), float(data.get("radius", 0.12)))
	body_entered.connect(_on_body_entered)
	# Capa: proyectiles detectan jugadores
	collision_layer = 8
	collision_mask = 2 | 1  # players + world
	monitoring = true


func _build_mesh(color: Color, radius: float) -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	_mesh.material_override = mat
	add_child(_mesh)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	add_child(col)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_expire()
		return
	global_position += velocity * delta
	if _mesh:
		_mesh.rotate_y(delta * 10.0)


func _on_body_entered(body: Node3D) -> void:
	if body is Projectile:
		return
	if body is CharacterBody3D:
		var player := body as CharacterBody3D
		if str(player.name).is_valid_int() and int(player.name) == owner_peer:
			return
		# Solo el servidor aplica daño; todos ven el impacto visual
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			_impact(body.global_position)
			return
		if hurts_beast and body is BeastPlayer:
			(body as BeastPlayer).apply_damage.rpc(damage, slow_amount, slow_duration, owner_peer)
			_impact(body.global_position)
			return
		if hurts_explorers and body is ExplorerPlayer:
			(body as ExplorerPlayer).apply_projectile_hit.rpc(
				(body as ExplorerPlayer).peer_id, damage, slow_amount, slow_duration, owner_peer
			)
			_impact(body.global_position)
			return
	_impact(global_position)


func _impact(pos: Vector3) -> void:
	if explode_on_hit and multiplayer.is_server():
		CombatFx.spawn_explosion(pos, explode_radius, damage * 0.6, owner_peer, hurts_explorers, hurts_beast)
	queue_free()


func _expire() -> void:
	if explode_on_hit and multiplayer.is_server():
		CombatFx.spawn_explosion(global_position, explode_radius, damage * 0.5, owner_peer, hurts_explorers, hurts_beast)
	queue_free()

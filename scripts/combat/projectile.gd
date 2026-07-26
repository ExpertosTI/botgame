class_name Projectile
extends Area3D

## Proyectil reciclable. Lo entrega y recoge FxPool: setup() puede llamarse
## muchas veces sobre el mismo nodo, así que la malla, la forma de colisión y la
## conexión de la señal se construyen una sola vez.

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
var _spent := false
var _mesh: MeshInstance3D
var _shape: SphereShape3D
var _collider: CollisionShape3D


func setup(from: Vector3, dir: Vector3, data: Dictionary, peer: int, vs_explorers: bool = false) -> void:
	_ensure_nodes()
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
	_age = 0.0
	_spent = false

	var radius: float = float(data.get("radius", 0.12))
	var color: Color = data.get("color", Color.WHITE)
	_mesh.mesh = FxAssets.sphere(radius)
	_mesh.material_override = FxAssets.emissive(color, 3.0)
	_mesh.rotation = Vector3.ZERO
	_shape.radius = radius

	collision_layer = 8
	collision_mask = 2 | 1  # players + world
	monitoring = true
	visible = true


func _ensure_nodes() -> void:
	if _mesh != null:
		return
	_mesh = MeshInstance3D.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_mesh)
	_shape = SphereShape3D.new()
	_collider = CollisionShape3D.new()
	_collider.shape = _shape
	add_child(_collider)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age >= lifetime:
		_expire()
		return
	global_position += velocity * delta
	if _mesh:
		_mesh.rotate_y(delta * 10.0)


func _on_body_entered(body: Node3D) -> void:
	if _spent or body is Projectile:
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
	if _spent:
		return
	_spent = true
	CombatVfx.flash(self, pos, _impact_color(), 0.2)
	if explode_on_hit and multiplayer.is_server():
		CombatFx.spawn_explosion(pos, explode_radius, damage * 0.6, owner_peer, hurts_explorers, hurts_beast)
	_recycle()


func _expire() -> void:
	if _spent:
		return
	_spent = true
	if explode_on_hit and multiplayer.is_server():
		CombatFx.spawn_explosion(global_position, explode_radius, damage * 0.5, owner_peer, hurts_explorers, hurts_beast)
	_recycle()


## FxPool nos pide el turno porque llegó al techo de proyectiles vivos.
func recycle_now() -> void:
	_spent = true
	_recycle()


func _recycle() -> void:
	velocity = Vector3.ZERO
	monitoring = false
	FxPool.release_projectile(self)


func _impact_color() -> Color:
	var mat := _mesh.material_override as StandardMaterial3D if _mesh else null
	return mat.albedo_color if mat != null else Color.WHITE

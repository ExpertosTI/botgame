class_name TrapMine
extends Area3D

## Mina colocable. Antes TRAP_MINE era una explosión instantánea delante del
## jugador: no había trampa que defender ni engaño posible. Ahora arma tras un
## retardo, vive unos segundos y detona al enemigo que entre.

const ARM_DELAY := 0.85
const LIFE := 18.0

var owner_peer := 0
var damage := 28.0
var radius := 3.2
var hurts_explorers := false
var hurts_beast := true
var _armed := false
var _spent := false
var _mesh: MeshInstance3D


func setup(
	pos: Vector3,
	peer: int,
	dmg: float,
	rad: float,
	vs_explorers: bool,
	vs_beast: bool
) -> void:
	owner_peer = peer
	damage = dmg
	radius = rad
	hurts_explorers = vs_explorers
	hurts_beast = vs_beast
	global_position = pos
	collision_layer = 0
	collision_mask = 2  # players
	monitoring = true
	_ensure_visual()
	body_entered.connect(_on_body)
	var arm := get_tree().create_timer(ARM_DELAY)
	arm.timeout.connect(_arm)
	var life := get_tree().create_timer(LIFE)
	life.timeout.connect(_expire)


func _ensure_visual() -> void:
	if _mesh != null:
		return
	_mesh = MeshInstance3D.new()
	_mesh.mesh = FxAssets.sphere(0.28)
	_mesh.material_override = FxAssets.emissive(Color(1.0, 0.35, 0.15), 2.4)
	_mesh.position = Vector3(0, 0.15, 0)
	add_child(_mesh)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(radius * 0.55, 1.2)
	shape.shape = sphere
	add_child(shape)


func _arm() -> void:
	if _spent:
		return
	_armed = true
	if _mesh:
		_mesh.material_override = FxAssets.emissive(Color(1.0, 0.15, 0.1), 4.0)


func _on_body(body: Node3D) -> void:
	if _spent or not _armed:
		return
	if body is CharacterBody3D and str(body.name).is_valid_int() and int(body.name) == owner_peer:
		return
	if hurts_beast and body is BeastPlayer:
		_detonate()
	elif hurts_explorers and body is ExplorerPlayer:
		_detonate()


func _detonate() -> void:
	if _spent:
		return
	_spent = true
	## Puede llegar desde body_entered: diferir monitoring / free.
	set_deferred("monitoring", false)
	if NetworkManager.is_match_authority():
		CombatFx.spawn_explosion(
			global_position, radius, damage, owner_peer, hurts_explorers, hurts_beast
		)
	call_deferred("queue_free")


func _expire() -> void:
	if _spent:
		return
	_spent = true
	queue_free()

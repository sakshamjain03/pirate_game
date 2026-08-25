class_name Cannonball extends RigidBody3D

@export var damage: float = 15.0
@export var lifetime: float = 5.0
@export var ammo: AmmoData

var source_ship: Node = null
var _splashed: bool = false

func _ready() -> void:
	# Enable contact reporting to detect hits
	contact_monitor = true
	max_contacts_reported = 1

	# Connect to collision signal
	body_entered.connect(_on_body_entered)

	# Despawn after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _process(_delta: float) -> void:
	# The ocean has no collider, so a miss would otherwise just sink through
	# and idle out its full lifetime underwater, invisible, with no impact
	# feedback at all.
	if not _splashed and global_position.y < 0.0:
		_splashed = true
		_spawn_splash()
		queue_free()

func _spawn_splash() -> void:
	var splash = CPUParticles3D.new()
	splash.emitting = false
	splash.one_shot = true
	splash.amount = 20
	splash.lifetime = 0.6
	splash.explosiveness = 0.9
	splash.spread = 40.0
	splash.direction = Vector3(0, 1, 0)
	splash.gravity = Vector3(0, -9.8, 0)
	splash.initial_velocity_min = 3.0
	splash.initial_velocity_max = 6.0

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mesh = SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	mesh.material = mat
	splash.mesh = mesh

	get_tree().current_scene.add_child(splash)
	splash.global_position = Vector3(global_position.x, 0.0, global_position.z)
	splash.emitting = true

	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): if is_instance_valid(splash): splash.queue_free())

func _on_body_entered(body: Node) -> void:
	# Ignore collision with the ship that fired this — but still despawn;
	# leaving the ball alive without freeing it meant it kept physically
	# colliding with (and shoving) the firer for its full lifetime.
	if body == source_ship:
		queue_free()
		return

	if not _is_friendly(body):
		var hit_dir = linear_velocity.normalized()
		var hit_ammo = ammo if ammo else load("res://resources/combat/ammo/RoundShot.tres")
		
		# Check if body has a ShipDamage component directly or through ShipCombat
		var dmg = body.get_node_or_null("ShipDamage")
		if dmg:
			dmg.apply_hit(damage, hit_ammo, hit_dir)
		elif body.has_method("take_damage"):
			body.take_damage(damage, hit_ammo, hit_dir)
		elif body.has_node("ShipCombat"):
			var combat = body.get_node("ShipCombat")
			if combat.has_method("take_damage"):
				combat.take_damage(damage, hit_ammo, hit_dir)

	# Spawn impact effect here later

	queue_free()


func _is_friendly(body: Node) -> bool:
	## Cannonballs share one collision mask across every enemy ship
	## (they're all on layer 2 regardless of faction), so without this an
	## enemy's broadside could damage another enemy on the SAME faction —
	## and Island.gd captures an island the instant its defender dies for
	## any cause, including friendly fire.
	if not source_ship or not is_instance_valid(source_ship):
		return false

	# One rule, one place. FiringSolver.are_hostile() is the same test the
	# auto-fire target picker uses, so the solver can never lock onto a ship this
	# cannonball would refuse to damage.
	return not FiringSolver.are_hostile(source_ship, body)

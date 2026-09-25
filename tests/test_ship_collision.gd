extends GutTest

# test_ship_collision.gd — M23 Requirement 1/2, driven through real physics
# with the real EnemyShip scene (EnemyAI stripped so nothing steers).

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")

var _scene: Node3D = null


func before_each():
	_scene = Node3D.new()
	_scene.name = "CollisionTestScene"
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func after_each():
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.queue_free()
	_scene = null


func _spawn(pos: Vector3, yaw: float, max_health: float = 800.0, friendly: bool = false) -> ShipController:
	var ship := ENEMY_SHIP.instantiate() as ShipController
	var ai := ship.get_node_or_null("EnemyAI")
	if ai:
		ship.remove_child(ai)
		ai.free()
	var stats: ShipStats = ship.ship_stats.duplicate()
	stats.max_health = max_health
	ship.ship_stats = stats
	for n in ["ShipDamage", "ShipMovement", "BuoyancySimulator", "ShipCombat", "FiringSolver"]:
		var c = ship.get_node_or_null(n)
		if c and "ship_stats" in c:
			c.ship_stats = stats
	if friendly:
		ship.remove_from_group("enemy_ship")
		ship.add_to_group("friendly_ship")
	var combat = ship.get_node_or_null("ShipCombat")
	if combat:
		combat.auto_fire_enabled = false
	_scene.add_child(ship)
	ship.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return ship


func test_every_ship_gets_a_collision_handler_and_a_pointed_hull():
	var ship := _spawn(Vector3.ZERO, 0.0)
	await wait_physics_frames(2)
	var handler := ship.get_node_or_null("ShipCollisionHandler")
	assert_not_null(handler, "ShipController must auto-add the handler")
	assert_true(ship.contact_monitor, "contacts must be reported")
	assert_not_null(ship.physics_material_override, "hull needs a low-friction material")
	assert_lt(ship.physics_material_override.friction, 0.5)
	var shape = ship.get_node("CollisionShape3D").shape
	assert_true(shape is ConvexPolygonShape3D, "box hull must be replaced by the pointed prism")


func test_enemy_hulls_collide_with_each_other():
	var ship := _spawn(Vector3.ZERO, 0.0)
	assert_true(ship.get_collision_mask_value(2), "enemy mask must include the enemy layer")


func test_overlapping_hulls_separate_instead_of_locking():
	# Two hulls spawned half-inside each other side by side — the classic
	# "stuck together" state. They must be pushed fully apart within ~2.5 s
	# (measured: clear by ~2 s; lateral anti-drift damping sets the pace).
	var a := _spawn(Vector3(-1.2, 0.0, 0.0), 0.0)
	var b := _spawn(Vector3(1.2, 0.0, 0.0), 0.0)
	await wait_physics_frames(150)
	var gap: float = Vector2(a.global_position.x - b.global_position.x,
		a.global_position.z - b.global_position.z).length()
	assert_gt(gap, 4.0, "hulls must end up at least a beam apart (gap %.2f)" % gap)


func test_bow_into_midship_ram_damages_the_victim_far_more():
	# A (player side) sails bow-first along +Z into B's side. B lies across
	# A's path (long axis along X), so the contact is A's bow on B's midship.
	var a := _spawn(Vector3(0.0, 0.0, -10.5), PI, 800.0, true)
	var b := _spawn(Vector3.ZERO, PI * 0.5)
	await wait_physics_frames(2)
	var fwd := -a.global_transform.basis.z
	a.linear_velocity = fwd * 14.0
	a.set_input(1.0, 0.0)
	var a_dmg: ShipDamage = a.get_node("ShipDamage")
	var b_dmg: ShipDamage = b.get_node("ShipDamage")
	var a_start := a_dmg.hull
	var b_start := b_dmg.hull
	await wait_physics_frames(90)
	var a_lost := a_start - a_dmg.hull
	var b_lost := b_start - b_dmg.hull
	assert_gt(b_lost, 5.0, "the rammed ship must take real damage (took %.1f)" % b_lost)
	assert_gt(b_lost, a_lost * 2.0, "victim %.1f vs rammer %.1f" % [b_lost, a_lost])


func test_friendly_contact_bumps_without_damage():
	var a := _spawn(Vector3(0.0, 0.0, -10.5), PI)
	var b := _spawn(Vector3.ZERO, PI * 0.5)
	await wait_physics_frames(2)
	a.linear_velocity = -a.global_transform.basis.z * 14.0
	a.set_input(1.0, 0.0)
	var b_dmg: ShipDamage = b.get_node("ShipDamage")
	var b_start := b_dmg.hull
	await wait_physics_frames(90)
	assert_almost_eq(b_dmg.hull, b_start, 0.001, "same-side hulls must not damage each other")


func test_contact_opens_the_yaw_grace_window():
	var a := _spawn(Vector3(-1.2, 0.0, 0.0), 0.0)
	var _b := _spawn(Vector3(1.2, 0.0, 0.0), 0.0)
	var saw_grace := false
	for i in 20:
		await wait_physics_frames(1)
		if a.get_node("ShipMovement").is_in_contact_grace():
			saw_grace = true
			break
	assert_true(saw_grace, "touching hulls must relax the yaw servo so they can rotate apart")

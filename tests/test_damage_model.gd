extends GutTest

# test_damage_model.gd
# Property-based tests for ShipDamage

class MockShipParent extends RigidBody3D:
	pass

func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene

func _make_ship(stats: ShipStats) -> Dictionary:
	var parent = MockShipParent.new()
	
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	parent.add_child(dmg)
	
	var combat = ShipCombat.new()
	combat.name = "ShipCombat"
	combat.ship_stats = stats
	parent.add_child(combat)
	
	var movement = ShipMovement.new()
	movement.name = "ShipMovement"
	movement.ship_stats = stats
	parent.add_child(movement)
	
	add_child_autoqfree(parent)
	return {"parent": parent, "damage": dmg, "combat": combat, "movement": movement}

func test_hull_zero_destroys():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	var built = _make_ship(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)
	
	watch_signals(dmg)
	
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")
	dmg.apply_hit(100.0, round_shot, Vector3.FORWARD)
	
	assert_eq(dmg.hull, 0.0, "Hull should be 0")
	assert_signal_emit_count(dmg, "destroyed", 1)

func test_sails_reduce_speed_but_never_below_min_fraction():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	stats.max_sails = 100.0
	stats.min_speed_fraction = 0.35
	var built = _make_ship(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)
	
	assert_eq(dmg.get_speed_multiplier(), 1.0, "Speed mult should be 1.0 when sails are full")
	
	dmg.sails = 50.0
	assert_almost_eq(dmg.get_speed_multiplier(), 0.675, 0.01, "Speed mult should scale linearly")
	
	dmg.sails = 0.0
	assert_eq(dmg.get_speed_multiplier(), 0.35, "Speed mult should clamp at min_speed_fraction")

func test_crew_zero_disables_firing():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	stats.max_crew = 100.0
	var built = _make_ship(stats)
	var combat = built["combat"]
	var dmg = built["damage"]
	await wait_process_frames(1)
	
	dmg.crew = 100.0
	# Firing should succeed (at least pass the crew check, returning false means it failed somewhere)
	# Wait, without markers, fire_broadside might return false? 
	# Let's add a marker so it returns true when it actually fires.
	var marker = Node3D.new()
	marker.name = "PortMarker1"
	built["parent"].add_child(marker)
	combat.port_markers.append(marker)
	
	assert_true(combat.fire_broadside("port"), "Should fire with full crew")
	
	dmg.crew = 0.0
	# Reset cooldown
	combat.can_fire_port = true
	
	assert_false(combat.fire_broadside("port"), "Should NOT fire with zero crew")

func test_stern_arc_crits_apply_only_inside_the_arc():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	stats.stern_arc_degrees = 60.0
	stats.stern_crit_multiplier = 2.0
	var built = _make_ship(stats)
	var dmg = built["damage"]
	var parent = built["parent"]
	await wait_process_frames(1)
	
	# Ship looks towards -Z by default, meaning aft is +Z
	# A hit exactly from behind (+Z direction) should crit
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")
	
	dmg.hull = 100.0
	dmg.apply_hit(10.0, round_shot, Vector3.FORWARD) # Vector3(0, 0, -1) which is hitting from front
	assert_eq(dmg.hull, 90.0, "Frontal hit should not crit (10 damage)")
	
	dmg.hull = 100.0
	dmg.apply_hit(10.0, round_shot, Vector3.BACK) # Vector3(0, 0, 1) which is hitting from aft
	assert_eq(dmg.hull, 80.0, "Aft hit exactly on axis should crit (20 damage)")
	
	dmg.hull = 100.0
	# Outside the 60 degree arc (>30 deg from aft)
	# Vector3(1, 0, 0) is 90 degrees from aft
	dmg.apply_hit(10.0, round_shot, Vector3.RIGHT)
	assert_eq(dmg.hull, 90.0, "Side hit should not crit (10 damage)")

func test_save_round_trip_with_missing_pools_defaults_to_full():
	var stats = ShipStats.new()
	stats.max_health = 200.0
	stats.max_sails = 150.0
	stats.max_crew = 50.0
	var built = _make_ship(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)
	
	# Only saving hull (legacy save format)
	var old_save = {"hull": 100.0}
	
	dmg.load_save_data(old_save)
	
	assert_eq(dmg.hull, 100.0, "Hull should load correctly")
	assert_eq(dmg.sails, 150.0, "Missing sails should default to max")
	assert_eq(dmg.crew, 50.0, "Missing crew should default to max")
	
	# Full round trip
	dmg.hull = 50.0
	dmg.sails = 75.0
	dmg.crew = 25.0
	
	var new_save = dmg.get_save_data()
	
	var dmg2 = load("res://scripts/world/ShipDamage.gd").new()
	dmg2.ship_stats = stats
	built["parent"].add_child(dmg2)
	await wait_process_frames(1)
	
	dmg2.load_save_data(new_save)
	
	assert_eq(dmg2.hull, 50.0)
	assert_eq(dmg2.sails, 75.0)
	assert_eq(dmg2.crew, 25.0)

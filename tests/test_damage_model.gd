extends GutTest

# test_damage_model.gd
# Property-based tests for ShipDamage

class MockShipParent extends RigidBody3D:
	# ShipDamage/ShipCombat probe the parent with `"active_captain" in parent`,
	# so the mock has to actually declare it for captain-modifier tests to
	# exercise the real code path. Null by default, which every consumer guards.
	var active_captain: CaptainData = null

var _created_test_scene: Node3D = null

func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene

func after_each():
	# This file's own current_scene, if it created one, must not outlive it —
	# a leaked one previously corrupted test_navigation_integration.gd's real
	# get_tree().change_scene_to_file() call (freed-lambda-capture crash).
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null

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


# --- Slice 0: the repair / restore write path ---
# M6 made ShipCombat.current_health a getter-only proxy onto ShipDamage.hull and
# left five callers assigning to it, so respawn, shipyard repair, save-load and
# ship purchase all silently wrote to nothing. These tests pin the write path.

func test_repair_restores_a_pool_and_clamps_at_maximum():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	stats.max_sails = 80.0
	var built = _make_ship(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)

	dmg.hull = 40.0
	assert_eq(dmg.repair("hull", 25.0), 25.0, "repair returns the amount actually restored")
	assert_eq(dmg.hull, 65.0, "Hull should rise by the repaired amount")

	# Over-repair is clamped, and reports only what it actually restored.
	assert_eq(dmg.repair("hull", 1000.0), 35.0, "Over-repair returns only the amount used")
	assert_eq(dmg.hull, 100.0, "Hull should clamp at its maximum")
	assert_eq(dmg.repair("hull", 50.0), 0.0, "Repairing a full pool restores nothing")

	dmg.sails = 10.0
	dmg.repair("sails", 20.0)
	assert_eq(dmg.sails, 30.0, "Sails repair independently of hull")


func test_repairing_a_wreck_makes_it_damageable_again():
	## The respawn bug in one assertion: without clearing _is_destroyed, apply_hit
	## early-returns forever and the respawned ship is invulnerable at zero hull.
	var stats = ShipStats.new()
	stats.max_health = 100.0
	var built = _make_ship(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)

	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")
	dmg.apply_hit(100.0, round_shot, Vector3.FORWARD)
	assert_true(dmg.is_destroyed(), "Ship should be destroyed at zero hull")

	dmg.repair("hull", 100.0)
	assert_false(dmg.is_destroyed(), "Repairing hull above zero clears the destroyed flag")

	dmg.apply_hit(30.0, round_shot, Vector3.FORWARD)
	assert_eq(dmg.hull, 70.0, "A repaired ship must take damage again")


func test_restore_all_resets_every_pool_and_the_destroyed_flag():
	var stats = ShipStats.new()
	stats.max_health = 200.0
	stats.max_sails = 150.0
	stats.max_crew = 50.0
	var built = _make_ship(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)

	dmg.hull = 0.0
	dmg.sails = 5.0
	dmg.crew = 1.0
	dmg.mark_destroyed()
	assert_true(dmg.is_destroyed(), "Precondition: ship is a wreck")

	dmg.restore_all()

	assert_eq(dmg.hull, 200.0, "Hull restored to maximum")
	assert_eq(dmg.sails, 150.0, "Sails restored to maximum")
	assert_eq(dmg.crew, 50.0, "Crew restored to maximum")
	assert_false(dmg.is_destroyed(), "Destroyed flag cleared")


func test_current_health_setter_forwards_into_ship_damage():
	## The five dead call sites all assign to ShipCombat.current_health.
	var stats = ShipStats.new()
	stats.max_health = 100.0
	var built = _make_ship(stats)
	var dmg = built["damage"]
	var combat = built["combat"]
	await wait_process_frames(1)

	dmg.hull = 20.0
	combat.current_health = 90.0
	assert_eq(dmg.hull, 90.0, "Assigning current_health must raise ShipDamage.hull")

	combat.current_health = 30.0
	assert_eq(dmg.hull, 30.0, "Assigning current_health must also lower hull")

	combat.current_health = 100000.0
	assert_eq(dmg.hull, 100.0, "The setter still clamps at the pool maximum")


func test_hull_maximum_respects_the_captain_health_modifier():
	## _ready() filled hull from get_effective_max_health() but apply_hit clamped
	## it to the raw ship_stats.max_health, so a captain's health bonus was shaved
	## off on the ship's first hit.
	var stats = ShipStats.new()
	stats.max_health = 100.0
	var built = _make_ship(stats)
	var dmg = built["damage"]
	var cap = CaptainData.new()
	cap.base_health_modifier = 2.0
	built["parent"].active_captain = cap
	await wait_process_frames(1)

	assert_eq(dmg.get_pool_maximum("hull"), 200.0, "Captain modifier raises the hull ceiling")

	dmg.hull = 200.0
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")
	dmg.apply_hit(10.0, round_shot, Vector3.FORWARD)
	assert_eq(dmg.hull, 190.0, "Bonus hull must not be clamped away by a hit")


func test_chain_shot_applies_a_timed_speed_penalty_that_expires():
	## AmmoData.speed_penalty / speed_penalty_duration were authored on
	## ChainShot.tres since M6 and read by nothing.
	var stats = ShipStats.new()
	stats.max_health = 1000.0
	stats.max_sails = 1000.0
	stats.min_speed_fraction = 0.1
	var built = _make_ship(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)

	var chain = preload("res://resources/combat/ammo/ChainShot.tres")
	assert_gt(chain.speed_penalty, 0.0, "Precondition: ChainShot authors a speed penalty")

	var before: float = dmg.get_speed_multiplier()
	dmg.apply_hit(1.0, chain, Vector3.RIGHT)
	assert_gt(before, dmg.get_speed_multiplier(), "Chain shot must slow the target")
	assert_eq(dmg.get_speed_penalty(), chain.speed_penalty, "Penalty matches the ammo")

	# Expire it on a fresh ship — apply_speed_penalty deliberately never shortens
	# an already-running debuff, so the 10 s one applied above would swallow a
	# short duration set on the same node.
	var fresh = _make_ship(stats)["damage"]
	await wait_process_frames(1)
	fresh.apply_speed_penalty(0.5, 0.05)
	assert_eq(fresh.get_speed_penalty(), 0.5, "Penalty is active immediately")
	await wait_seconds(0.25)
	assert_eq(fresh.get_speed_penalty(), 0.0, "Penalty must expire after its duration")


func test_speed_penalty_refresh_never_shortens_an_active_debuff():
	var stats = ShipStats.new()
	stats.max_sails = 100.0
	var built = _make_ship(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)

	dmg.apply_speed_penalty(0.5, 10.0)
	dmg.apply_speed_penalty(0.2, 0.01)
	assert_eq(dmg.get_speed_penalty(), 0.5,
		"A weaker penalty must not replace a stronger active one")
	await wait_seconds(0.1)
	assert_eq(dmg.get_speed_penalty(), 0.5,
		"...nor cut its remaining duration short")


func test_speed_penalty_never_drops_speed_below_min_fraction():
	var stats = ShipStats.new()
	stats.max_sails = 100.0
	stats.min_speed_fraction = 0.35
	var built = _make_ship(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)

	dmg.sails = 0.0
	dmg.apply_speed_penalty(1.0, 10.0)
	assert_eq(dmg.get_speed_multiplier(), 0.35,
		"A fully crippled ship must still be able to limp away")

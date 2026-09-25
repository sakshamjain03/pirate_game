extends GutTest

# test_ram_damage.gd — M23 Requirement 2. Pure-function coverage of
# ShipCollisionHandler's zone classification and ram/grounding damage, plus
# ShipDamage.apply_impact(). The physics-driven end-to-end ram lives in
# test_ship_collision.gd.

const Zone = RamConfigData.Zone

var cfg: RamConfigData


func before_each():
	cfg = load("res://resources/combat/RamConfig.tres")


func _stats() -> ShipStats:
	return ShipStats.new()


func test_ram_config_loads_with_a_full_3x3_matrix():
	assert_not_null(cfg, "RamConfig.tres must load")
	assert_eq(cfg.zone_matrix.size(), 9, "zone matrix must be 3x3")


func test_zone_classification_bow_midship_stern():
	var half := 4.5
	# Forward is -Z: the bow tip is at local z = -half.
	assert_eq(ShipCollisionHandler.classify_zone(-4.4, half, cfg), Zone.BOW)
	assert_eq(ShipCollisionHandler.classify_zone(-2.5, half, cfg), Zone.BOW, "front 25% is bow")
	assert_eq(ShipCollisionHandler.classify_zone(0.0, half, cfg), Zone.MIDSHIP)
	assert_eq(ShipCollisionHandler.classify_zone(2.0, half, cfg), Zone.MIDSHIP)
	assert_eq(ShipCollisionHandler.classify_zone(4.0, half, cfg), Zone.STERN, "rear 20% is stern")


func test_bow_into_midship_hurts_victim_far_more_than_rammer():
	var s := _stats()
	var victim := ShipCollisionHandler.compute_ram_damage(cfg, 12.0, 5000.0, 5000.0, Zone.MIDSHIP, Zone.BOW, s, s)
	var rammer := ShipCollisionHandler.compute_ram_damage(cfg, 12.0, 5000.0, 5000.0, Zone.BOW, Zone.MIDSHIP, s, s)
	assert_gt(victim, 0.0)
	assert_gt(victim, rammer * 3.0, "victim %.1f must dwarf rammer %.1f" % [victim, rammer])


func test_bow_into_midship_is_the_heaviest_blow_a_victim_can_take():
	var s := _stats()
	var bow_mid := ShipCollisionHandler.compute_ram_damage(cfg, 12.0, 5000.0, 5000.0, Zone.MIDSHIP, Zone.BOW, s, s)
	for mine in [Zone.BOW, Zone.MIDSHIP, Zone.STERN]:
		for theirs in [Zone.BOW, Zone.MIDSHIP, Zone.STERN]:
			var d := ShipCollisionHandler.compute_ram_damage(cfg, 12.0, 5000.0, 5000.0, mine, theirs, s, s)
			assert_true(d <= bow_mid + 0.001, "zone pair (%d,%d) must not exceed a midship ram" % [mine, theirs])


func test_bow_to_bow_is_symmetric_for_equal_ships():
	var s := _stats()
	var a := ShipCollisionHandler.compute_ram_damage(cfg, 10.0, 5000.0, 5000.0, Zone.BOW, Zone.BOW, s, s)
	var b := ShipCollisionHandler.compute_ram_damage(cfg, 10.0, 5000.0, 5000.0, Zone.BOW, Zone.BOW, s, s)
	assert_almost_eq(a, b, 0.001)


func test_below_threshold_speed_does_no_damage():
	var s := _stats()
	var d := ShipCollisionHandler.compute_ram_damage(cfg, cfg.min_closing_speed * 0.9, 5000.0, 5000.0, Zone.MIDSHIP, Zone.BOW, s, s)
	assert_eq(d, 0.0)
	assert_eq(ShipCollisionHandler.compute_grounding_damage(cfg, cfg.min_closing_speed * 0.9, Zone.BOW, s), 0.0)


func test_damage_grows_with_the_square_of_closing_speed():
	var s := _stats()
	s.bow_armor_multiplier = 1.0
	var slow := ShipCollisionHandler.compute_ram_damage(cfg, 5.0, 5000.0, 5000.0, Zone.MIDSHIP, Zone.BOW, s, s)
	var fast := ShipCollisionHandler.compute_ram_damage(cfg, 10.0, 5000.0, 5000.0, Zone.MIDSHIP, Zone.BOW, s, s)
	assert_almost_eq(fast / slow, 4.0, 0.01)


func test_heavier_ship_takes_less_than_lighter_one():
	var s := _stats()
	var heavy := ShipCollisionHandler.compute_ram_damage(cfg, 10.0, 20000.0, 5000.0, Zone.MIDSHIP, Zone.MIDSHIP, s, s)
	var light := ShipCollisionHandler.compute_ram_damage(cfg, 10.0, 5000.0, 20000.0, Zone.MIDSHIP, Zone.MIDSHIP, s, s)
	assert_lt(heavy, light, "the galleon must shrug off what staves in the sloop")


func test_ram_damage_mult_and_impact_resistance_scale_damage():
	var base := _stats()
	var rammer := _stats()
	rammer.ram_damage_mult = 2.0
	var tough := _stats()
	tough.impact_resistance = 2.0
	var plain := ShipCollisionHandler.compute_ram_damage(cfg, 10.0, 5000.0, 5000.0, Zone.MIDSHIP, Zone.BOW, base, base)
	var boosted := ShipCollisionHandler.compute_ram_damage(cfg, 10.0, 5000.0, 5000.0, Zone.MIDSHIP, Zone.BOW, base, rammer)
	var resisted := ShipCollisionHandler.compute_ram_damage(cfg, 10.0, 5000.0, 5000.0, Zone.MIDSHIP, Zone.BOW, tough, base)
	assert_almost_eq(boosted, plain * 2.0, 0.01, "a reinforced ram doubles what it deals")
	assert_almost_eq(resisted, plain * 0.5, 0.01, "impact resistance halves what is taken")


func test_ram_damage_mult_only_applies_to_a_bow_strike():
	var base := _stats()
	var rammer := _stats()
	rammer.ram_damage_mult = 2.0
	var side_a := ShipCollisionHandler.compute_ram_damage(cfg, 10.0, 5000.0, 5000.0, Zone.MIDSHIP, Zone.MIDSHIP, base, base)
	var side_b := ShipCollisionHandler.compute_ram_damage(cfg, 10.0, 5000.0, 5000.0, Zone.MIDSHIP, Zone.MIDSHIP, base, rammer)
	assert_almost_eq(side_a, side_b, 0.001, "a sideswipe isn't a ram")


func test_apply_impact_hits_hull_and_crew_and_can_destroy():
	var stats := _stats()
	stats.max_health = 100.0
	stats.max_crew = 20.0
	var dmg: ShipDamage = ShipDamage.new()
	dmg.ship_stats = stats
	add_child_autoqfree(dmg)
	watch_signals(dmg)
	dmg.apply_impact(30.0, 0.1)
	assert_almost_eq(dmg.hull, 70.0, 0.01)
	assert_almost_eq(dmg.crew, 17.0, 0.01)
	assert_signal_emitted(dmg, "pool_changed")
	dmg.apply_impact(500.0)
	assert_true(dmg.is_destroyed())
	assert_signal_emitted(dmg, "destroyed")


func test_apply_impact_stern_penalty_slows_the_ship():
	var stats := _stats()
	var dmg: ShipDamage = ShipDamage.new()
	dmg.ship_stats = stats
	add_child_autoqfree(dmg)
	var before := dmg.get_speed_multiplier()
	dmg.apply_impact(5.0, 0.0, cfg.stern_speed_penalty, cfg.stern_penalty_duration)
	assert_lt(dmg.get_speed_multiplier(), before, "a rudder hit must slow the hull")


func test_hull_prism_keeps_the_box_bounding_box():
	var e := Vector3(2.3, 1.0, 4.5)
	var shape := ShipCollisionHandler.build_hull_prism(e)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in shape.points:
		lo = Vector3(min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z))
		hi = Vector3(max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z))
	assert_eq(lo, -e, "AABB min must equal the old box — inertia depends on it")
	assert_eq(hi, e, "AABB max must equal the old box")

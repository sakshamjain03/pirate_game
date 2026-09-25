extends GutTest

# test_cannon_fire.gd — M23 Requirement 5: gun count, ripple fire, misfire,
# aim spread, glancing hits.

class MockShip extends RigidBody3D:
	var active_captain: CaptainData = null

var _scene: Node3D = null


func before_each():
	_scene = Node3D.new()
	_scene.name = "CannonTestScene"
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func after_each():
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.queue_free()
	_scene = null


func _make_ship(stats: ShipStats, port_markers: int, cfg: CannonConfigData = null) -> Dictionary:
	var ship := MockShip.new()
	for i in port_markers:
		var m := Marker3D.new()
		m.name = "PortMarker%d" % (i + 1)
		m.position = Vector3(-2.2, 1.7, -2.0 + 2.0 * i)
		ship.add_child(m)
	var dmg := ShipDamage.new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	ship.add_child(dmg)
	var combat := ShipCombat.new()
	combat.name = "ShipCombat"
	combat.ship_stats = stats
	combat.auto_fire_enabled = false
	if cfg:
		combat.cannon_config = cfg
	ship.add_child(combat)
	_scene.add_child(ship)
	return {"ship": ship, "combat": combat, "damage": dmg}


func _count_balls() -> int:
	var n := 0
	for c in _scene.get_children():
		if c is Cannonball and not c.is_queued_for_deletion():
			n += 1
	return n


func test_cannon_config_loads():
	var cfg: CannonConfigData = load("res://resources/combat/CannonConfig.tres")
	assert_not_null(cfg)
	assert_gt(cfg.ripple_interval, 0.0)


func test_zero_cannons_per_side_keeps_one_gun_per_marker():
	var stats := ShipStats.new()
	var built := _make_ship(stats, 3)
	assert_eq(built.combat.get_guns_per_side(), 3)
	assert_eq(built.combat.port_markers.size(), 3)


func test_cannons_per_side_generates_extra_guns():
	var stats := ShipStats.new()
	stats.cannons_per_side = 6
	var built := _make_ship(stats, 3)
	assert_eq(built.combat.port_markers.size(), 6, "6 guns requested on a 3-marker side")


func test_first_gun_fires_immediately_and_the_rest_ripple():
	var stats := ShipStats.new()
	stats.fire_rate = 0.2
	var cfg: CannonConfigData = load("res://resources/combat/CannonConfig.tres").duplicate()
	cfg.base_misfire_chance = 0.0
	cfg.crew_misfire_chance = 0.0
	cfg.ripple_interval = 0.1
	var built := _make_ship(stats, 3, cfg)
	assert_true(built.combat.fire_broadside("port"))
	assert_eq(_count_balls(), 1, "only gun 0 fires on the trigger frame")
	await wait_seconds(0.35)
	assert_eq(_count_balls(), 3, "the remaining guns ripple out afterwards")


func test_certain_misfire_still_gets_the_first_ball_off():
	var stats := ShipStats.new()
	var cfg: CannonConfigData = load("res://resources/combat/CannonConfig.tres").duplicate()
	cfg.base_misfire_chance = 0.95
	cfg.crew_misfire_chance = 0.0
	cfg.ripple_interval = 0.0
	var built := _make_ship(stats, 4, cfg)
	watch_signals(built.combat)
	# 0.95 per trailing gun: across 3 trailing guns at least one misfire is ~certain.
	assert_true(built.combat.fire_broadside("port"))
	assert_gte(_count_balls(), 1, "a volley always gets at least one ball away")
	assert_signal_emitted(built.combat, "misfired")


func test_misfire_chance_grows_as_crew_is_lost():
	var cfg: CannonConfigData = load("res://resources/combat/CannonConfig.tres")
	assert_gt(cfg.get_misfire_chance(0.2), cfg.get_misfire_chance(1.0))


func test_aim_spread_grows_off_the_beam_and_with_range():
	var cfg: CannonConfigData = load("res://resources/combat/CannonConfig.tres")
	assert_gt(cfg.get_spread_degrees(1.0, 0.0), cfg.get_spread_degrees(0.0, 0.0))
	assert_gt(cfg.get_spread_degrees(0.0, 1.0), cfg.get_spread_degrees(0.0, 0.0))


func test_glancing_hit_does_less_than_a_square_hit():
	var cfg: CannonConfigData = load("res://resources/combat/CannonConfig.tres")
	assert_lt(cfg.get_impact_angle_multiplier(0.1), cfg.get_impact_angle_multiplier(1.0))
	assert_almost_eq(cfg.get_impact_angle_multiplier(1.0), 1.0, 0.001)


func test_cannonball_angle_multiplier_uses_the_hull_zone():
	var target := load("res://scenes/world/EnemyShip.tscn").instantiate() as ShipController
	var ai := target.get_node_or_null("EnemyAI")
	if ai:
		target.remove_child(ai)
		ai.free()
	_scene.add_child(target)
	await wait_physics_frames(1)
	var ball := Cannonball.new()
	_scene.add_child(ball)
	# Midship, square on the beam: full damage.
	ball.global_position = target.global_position + Vector3(2.3, 1.0, 0.0)
	assert_almost_eq(ball.get_impact_angle_multiplier(target, Vector3(-1, 0, 0)), 1.0, 0.001)
	# Midship, skimming along the side: reduced.
	assert_lt(ball.get_impact_angle_multiplier(target, Vector3(0.1, 0, -1).normalized()), 0.6)
	# Stern rake (ball enters at the transom travelling along the keel): not reduced.
	ball.global_position = target.global_position + Vector3(0.0, 1.0, 4.4)
	assert_almost_eq(ball.get_impact_angle_multiplier(target, Vector3(0, 0, -1)), 1.0, 0.001)
	ball.queue_free()

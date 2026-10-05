extends GutTest
## M30 Wave 0 (0.13, B2): CombatModifiers.range_mult widened the FiringSolver's
## reach but never the ball's launch speed, so every range bonus (the existing
## CANNON_RANGE upgrade included) aimed at targets its shots fell short of. A
## level shot's flight time is set by height and gravity alone, so reach is
## proportional to launch speed: range_mult must scale that speed. Direction
## must stay the hull-basis broadside (CLAUDE.md fragile area).

class MockShip extends RigidBody3D:
	var active_captain: CaptainData = null

var _scene: Node3D


func before_each() -> void:
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func after_each() -> void:
	if get_tree().current_scene == _scene:
		get_tree().current_scene = null
	_scene.queue_free()


func _launch_speed(range_mult: float) -> Vector3:
	var stats := ShipStats.new()
	stats.cannon_speed = 100.0
	var ship := MockShip.new()
	ship.freeze = true
	var m := Marker3D.new()
	m.name = "StarboardMarker1"
	m.position = Vector3(2.2, 1.7, 0.0)
	ship.add_child(m)
	var mods := CombatModifiers.new()
	mods.name = "CombatModifiers"
	ship.add_child(mods)
	var combat := ShipCombat.new()
	combat.name = "ShipCombat"
	combat.ship_stats = stats
	combat.auto_fire_enabled = false
	# No aim error: this pins speed and direction, not the M23 spread.
	var cfg: CannonConfigData = load("res://resources/combat/CannonConfig.tres").duplicate()
	cfg.base_spread_degrees = 0.0
	cfg.off_beam_spread_degrees = 0.0
	cfg.range_spread_degrees = 0.0
	combat.cannon_config = cfg
	ship.add_child(combat)
	_scene.add_child(ship)
	mods._base["range"] = range_mult
	mods._recompute()
	combat._spawn_cannonball(m, "starboard")
	var ball: Cannonball = null
	for c in _scene.get_children():
		if c is Cannonball:
			ball = c  # the newest one: earlier calls in this test share _scene
	ship.queue_free()
	return ball.linear_velocity if ball else Vector3.ZERO


func test_range_bonus_scales_launch_speed() -> void:
	var base := _launch_speed(1.0)
	var boosted := _launch_speed(1.5)
	assert_gt(base.length(), 0.0, "no cannonball was spawned")
	assert_almost_eq(boosted.length() / base.length(), 1.5, 0.05,
		"a 1.5x range bonus must launch the ball 1.5x as fast, or it falls short")


func test_range_bonus_never_turns_the_shot() -> void:
	var boosted := _launch_speed(1.5)
	var flat := Vector3(boosted.x, 0.0, boosted.z).normalized()
	assert_gt(flat.dot(Vector3.RIGHT), 0.95,
		"starboard shot must still leave along the hull's +X beam")

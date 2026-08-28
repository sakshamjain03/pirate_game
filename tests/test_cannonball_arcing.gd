extends GutTest

## M11 Requirement 3 — Cannonball.tscn's gravity_scale was raised from 0.5 to
## 0.7 for a genuinely more pronounced ballistic arc; every ship's cannon_speed
## was compensated upward in the same change so authored cannon_range stayed
## truthful (see test_combat_integration.gd's reachability assertion) without
## shrinking tactical reach. This file verifies the actual runtime physics —
## not just the arithmetic — matches that derivation.

const CannonballScene := preload("res://scenes/combat/Cannonball.tscn")
const START_Y := 1.7
const OLD_GRAVITY_SCALE := 0.5
const G := 9.8

var _created_test_scene: Node3D = null

func before_each():
	# Cannonball._spawn_splash() reaches for get_tree().current_scene when it
	# hits the water — same guard test_empire_scaling.gd uses.
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene

func after_each():
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null

func _spawn_ball(speed: float) -> Node:
	var ball = CannonballScene.instantiate()
	add_child(ball)
	ball.global_position = Vector3(0, START_Y, 0)
	# Purely horizontal launch, matching ShipCombat._spawn_cannonball() exactly
	# (no upward component) — the arc comes entirely from gravity pulling a
	# level shot down, not a lobbed launch angle.
	ball.linear_velocity = Vector3(0, 0, -speed)
	return ball

func test_gravity_scale_is_the_newly_tuned_arc_value():
	var ball = _spawn_ball(150.0)
	assert_almost_eq(ball.gravity_scale, 0.7, 0.001,
		"M11 raised gravity_scale from the old near-straight-line 0.5 to 0.7 for a real arc")
	ball.queue_free()

func test_arc_drops_further_than_the_old_gravity_scale_would_have_at_the_same_elapsed_time():
	## Same time-since-launch, same start height: with the new gravity_scale
	## the ball should have fallen noticeably further than the old 0.5 value
	## would have produced — a direct, quantitative "more arc than before"
	## check, not just "some gravity exists."
	var ball = _spawn_ball(150.0)
	var dt = get_physics_process_delta_time()
	const SAMPLE_TIME := 0.3  # well inside both the old (~0.83s) and new (~0.70s) flight time
	var elapsed := 0.0
	while elapsed < SAMPLE_TIME:
		await get_tree().physics_frame
		elapsed += dt

	var actual_drop = START_Y - ball.global_position.y
	var old_gravity_drop = 0.5 * G * OLD_GRAVITY_SCALE * SAMPLE_TIME * SAMPLE_TIME

	assert_gt(actual_drop, old_gravity_drop,
		"At t=%.1fs the ball should have dropped further than the old gravity_scale=0.5 would have (%.3f) — got %.3f"
		% [SAMPLE_TIME, old_gravity_drop, actual_drop])
	ball.queue_free()

func test_flight_time_to_splash_matches_the_derivation_used_for_cannon_range():
	## Mirrors test_combat_integration.gd's FALL_TIME := 0.70 constant —
	## proves that number is actually true of the live scene, not just an
	## independently-maintained arithmetic assumption.
	const EXPECTED_FLIGHT_TIME := 0.70
	var ball = _spawn_ball(150.0)
	var dt = get_physics_process_delta_time()
	var elapsed := 0.0
	var splashed := false
	for i in range(180):  # generous ceiling — a regression back to a low/zero gravity_scale should fail loudly, not hang
		await get_tree().physics_frame
		elapsed += dt
		if not is_instance_valid(ball):
			splashed = true
			break

	assert_true(splashed, "Cannonball should splash (free itself once y < 0) well within 3s of simulated flight")
	if splashed:
		assert_almost_eq(elapsed, EXPECTED_FLIGHT_TIME, 0.15,
			"Flight time to splash should be close to the %.2fs derived for gravity_scale=0.7 from y=%.1f — got %.2fs"
			% [EXPECTED_FLIGHT_TIME, START_Y, elapsed])

extends GutTest

## M11 Requirement 2 — wind as a multiplicative term on ShipMovement's speed_mod,
## sourced from RegionData via a discoverable EnvironmentController (group
## "environment_controller"). Uses a fake controller so this doesn't need a
## full World scene.

const ShipStatsClass = preload("res://scripts/world/ShipStats.gd")
const ShipMovementClass = preload("res://scripts/world/ShipMovement.gd")
const RegionDataClass = preload("res://scripts/world/RegionData.gd")

class FakeEnvironmentController extends Node:
	var region: RegionData = null
	func get_current_region() -> RegionData:
		return region

var _fake_env: FakeEnvironmentController

func before_each():
	_fake_env = FakeEnvironmentController.new()
	_fake_env.add_to_group("environment_controller")
	add_child(_fake_env)

func after_each():
	if is_instance_valid(_fake_env):
		_fake_env.queue_free()

func _make_ship() -> Dictionary:
	var body = RigidBody3D.new()
	var movement = ShipMovementClass.new()
	var stats = ShipStatsClass.new()
	stats.max_speed = 20.0
	stats.acceleration = 200.0
	stats.deceleration = 200.0
	movement.ship_stats = stats
	body.add_child(movement)
	add_child(body)
	return {"body": body, "movement": movement}

func _measure_forward_speed(body: RigidBody3D, movement) -> float:
	var dt = get_physics_process_delta_time()
	for i in range(24):  # ~0.4s at 60fps — well past the servo's convergence time
		await get_tree().physics_frame
		movement.apply_movement(1.0, 0.0, dt)
	await get_tree().physics_frame
	var forward_dir = -body.global_transform.basis.z.normalized()
	return body.linear_velocity.dot(forward_dir)

func test_tailwind_sails_faster_than_calm():
	_fake_env.region = null
	var calm = await _make_ship_and_measure()

	var region = RegionDataClass.new()
	region.wind_strength = 1.0
	region.wind_direction_degrees = 0.0  # matches a fresh RigidBody3D's yaw 0 -> dead tailwind
	_fake_env.region = region
	var tailwind = await _make_ship_and_measure()

	assert_gt(tailwind, calm, "A dead tailwind should sail faster than calm water")

func test_headwind_sails_slower_than_calm():
	_fake_env.region = null
	var calm = await _make_ship_and_measure()

	var region = RegionDataClass.new()
	region.wind_strength = 1.0
	region.wind_direction_degrees = 180.0  # opposite of yaw 0 -> dead headwind
	_fake_env.region = region
	var headwind = await _make_ship_and_measure()

	assert_lt(headwind, calm, "A dead headwind should sail slower than calm water")

func test_zero_wind_strength_is_a_no_op():
	_fake_env.region = null
	var no_region = await _make_ship_and_measure()

	var region = RegionDataClass.new()
	region.wind_strength = 0.0
	region.wind_direction_degrees = 90.0
	_fake_env.region = region
	var zero_strength = await _make_ship_and_measure()

	assert_almost_eq(zero_strength, no_region, 0.3,
		"wind_strength = 0.0 should behave identically to no region data at all")

func _make_ship_and_measure() -> float:
	var ship = _make_ship()
	var speed = await _measure_forward_speed(ship.body, ship.movement)
	ship.body.queue_free()
	return speed

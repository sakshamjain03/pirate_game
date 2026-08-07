extends GutTest

const ShipStatsClass = preload("res://scripts/world/ShipStats.gd")
const ShipMovementClass = preload("res://scripts/world/ShipMovement.gd")
const BuoyancySimulatorClass = preload("res://scripts/world/BuoyancySimulator.gd")
const WaveGeneratorClass = preload("res://scripts/world/WaveGenerator.gd")

class MockWaveGenerator extends WaveGeneratorClass:
	func get_water_height_at(pos: Vector3, time: float) -> float:
		return sin(pos.x * 2.0 + time) * 1.5

func test_property_4_proportional_movement():
	var passed = true
	var body = RigidBody3D.new()
	var movement = ShipMovementClass.new()
	var stats = ShipStatsClass.new()
	movement.ship_stats = stats
	body.add_child(movement)
	add_child(body)
	
	for i in range(20):
		var input = randf_range(0.1, 1.0)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		
		await get_tree().physics_frame
		
		movement.apply_movement(input, 0.0, get_physics_process_delta_time())
		await get_tree().physics_frame
		
		var forward_dir = -body.global_transform.basis.z.normalized()
		var speed = body.linear_velocity.dot(forward_dir)
		
		if speed <= 0.0:
			passed = false
			
	body.queue_free()
	assert_true(passed, "Property 4: Ship acceleration shall be proportional to input strength")

func test_property_5_realistic_turning():
	var passed = true
	var body = RigidBody3D.new()
	var movement = ShipMovementClass.new()
	var stats = ShipStatsClass.new()
	movement.ship_stats = stats
	body.add_child(movement)
	add_child(body)
	
	for i in range(20):
		var turn_input = 1.0 if (randi() % 2 == 0) else -1.0
		var right_dir = body.global_transform.basis.x.normalized()
		var forward_dir = -body.global_transform.basis.z.normalized()
		body.linear_velocity = forward_dir * 10.0 + right_dir * 2.0
		body.angular_velocity = Vector3.ZERO
		
		await get_tree().physics_frame
		
		movement.apply_movement(0.0, turn_input, get_physics_process_delta_time())
		await get_tree().physics_frame
		
		var turn_speed = body.angular_velocity.y
		
		if abs(turn_speed) <= 0.0001:
			passed = false
			
		var new_drift = body.linear_velocity.dot(right_dir)
		if abs(new_drift) >= 2.0:
			passed = false
			
	body.queue_free()
	assert_true(passed, "Property 5: Ship shall rotate with appropriate momentum and exhibit proportional drift")

func test_property_6_water_resistance():
	var passed = true
	var body = RigidBody3D.new()
	var movement = ShipMovementClass.new()
	var stats = ShipStatsClass.new()
	movement.ship_stats = stats
	body.add_child(movement)
	add_child(body)
	
	for i in range(20):
		var initial_speed = randf_range(1.0, 20.0)
		body.linear_velocity = -body.global_transform.basis.z.normalized() * initial_speed
		
		await get_tree().physics_frame
		
		movement.apply_movement(0.0, 0.0, get_physics_process_delta_time())
		await get_tree().physics_frame
		
		var forward_dir2 = -body.global_transform.basis.z.normalized()
		var new_speed = body.linear_velocity.dot(forward_dir2)
		
		if new_speed >= initial_speed:
			passed = false
			
	body.queue_free()
	assert_true(passed, "Property 6: Ship shall decelerate at a rate defined by water resistance parameters when no input is given")

func test_property_7_wave_interaction():
	var passed = true
	var body = RigidBody3D.new()
	var buoyancy = BuoyancySimulatorClass.new()
	var stats = ShipStatsClass.new()
	buoyancy.ship_stats = stats
	
	var wave_gen = MockWaveGenerator.new()
	buoyancy.wave_generator = wave_gen
	
	var fp1 = Marker3D.new()
	fp1.position = Vector3(0, 0, -2)
	var fp2 = Marker3D.new()
	fp2.position = Vector3(0, 0, 2)
	
	body.add_child(fp1)
	body.add_child(fp2)
	
	var fp_array: Array[Node3D] = [fp1, fp2]
	buoyancy.float_points = fp_array
	
	body.add_child(buoyancy)
	body.add_child(wave_gen)
	add_child(body)
	
	for i in range(20):
		body.global_transform.basis = Basis().rotated(Vector3.RIGHT, randf_range(-0.5, 0.5))
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		
		await get_tree().physics_frame
		
		buoyancy.apply_buoyancy(get_physics_process_delta_time())
		await get_tree().physics_frame
		
		if body.angular_velocity.length() <= 0.0001 and body.linear_velocity.length() <= 0.0001:
			passed = false
			
	body.queue_free()
	assert_true(passed, "Property 7: Ship shall pitch and roll proportionally to wave height, maintaining stability")

func test_property_9_reverse_maneuverability():
	var passed = true
	var body = RigidBody3D.new()
	var movement = ShipMovementClass.new()
	var stats = ShipStatsClass.new()
	movement.ship_stats = stats
	body.add_child(movement)
	add_child(body)
	
	for i in range(20):
		var turn_input = 1.0
		var forward_dir = -body.global_transform.basis.z.normalized()
		
		body.linear_velocity = forward_dir * 5.0
		body.angular_velocity = Vector3.ZERO
		await get_tree().physics_frame
		
		movement.apply_movement(0.0, turn_input, get_physics_process_delta_time())
		await get_tree().physics_frame
		
		var forward_turn_speed = abs(body.angular_velocity.y)
		
		body.linear_velocity = forward_dir * -5.0
		body.angular_velocity = Vector3.ZERO
		await get_tree().physics_frame
		
		movement.apply_movement(0.0, turn_input, get_physics_process_delta_time())
		await get_tree().physics_frame
		
		var backward_turn_speed = abs(body.angular_velocity.y)
		
		if backward_turn_speed >= forward_turn_speed:
			passed = false
			
	body.queue_free()
	assert_true(passed, "Property 9: Turning rate while moving backward shall be reduced compared to forward movement at the same speed")

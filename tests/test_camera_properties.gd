extends GutTest

const CameraRigClass = preload("res://scripts/world/CameraRig.gd")
const CameraSettingsClass = preload("res://scripts/world/CameraSettings.gd")
const CameraRigScene = preload("res://scenes/world/CameraRig.tscn")

func test_property_1_camera_bounds():
	var passed = true
	var rig = CameraRigScene.instantiate() as CameraRigClass
	var settings = CameraSettingsClass.new()
	rig.settings = settings
	add_child(rig)
	
	for i in range(20):
		var large_pitch_add = randf_range(100.0, 500.0) * (1 if randi() % 2 == 0 else -1)
		rig.add_pitch(large_pitch_add)
		if rig.target_pitch < settings.min_pitch or rig.target_pitch > settings.max_pitch:
			passed = false
			
		var large_zoom_add = randf_range(100.0, 500.0) * (1 if randi() % 2 == 0 else -1)
		rig.add_zoom(large_zoom_add)
		if rig.target_zoom < settings.min_distance or rig.target_zoom > settings.max_distance:
			passed = false
			
	rig.queue_free()
	assert_true(passed, "Property 1: Camera shall maintain distance and not exceed vertical angle limits")

func test_property_2_obstacle_avoidance():
	var passed = true
	var rig = CameraRigScene.instantiate() as CameraRigClass
	var settings = CameraSettingsClass.new()
	rig.settings = settings
	
	var target = Node3D.new()
	rig.set_target(target)
	
	add_child(target)
	add_child(rig)
	
	var obstacle = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	col.shape = box
	obstacle.add_child(col)
	obstacle.collision_layer = 3 # matches SpringArm3D collision_mask = 3
	add_child(obstacle)
	
	for i in range(20):
		rig.global_position = Vector3.ZERO
		target.global_position = Vector3.ZERO
		
		await get_tree().physics_frame
		
		var dir = rig.spring_arm.global_transform.basis.z.normalized()
		var dist = randf_range(5.0, 20.0)
		obstacle.global_position = rig.spring_arm.global_position + dir * dist
		
		await get_tree().physics_frame
		await get_tree().physics_frame
		
		var hit_length = rig.spring_arm.get_hit_length()
		if hit_length >= 29.9:
			print("Prop 2 Fail: dist=", dist, " hit=", hit_length)
			passed = false
			
	obstacle.queue_free()
	target.queue_free()
	rig.queue_free()
	assert_true(passed, "Property 2: Camera shall adjust its position to avoid clipping through obstacle")

func test_property_3_smooth_damping():
	var passed = true
	var rig = CameraRigScene.instantiate() as CameraRigClass
	var settings = CameraSettingsClass.new()
	settings.damping = 0.5
	rig.settings = settings
	
	var target = Node3D.new()
	rig.set_target(target)
	
	add_child(target)
	add_child(rig)
	
	for i in range(20):
		rig.global_position = Vector3.ZERO
		target.global_position = Vector3(randf_range(10, 50), 0, randf_range(10, 50))
		
		var initial_dist = target.global_position.length()
		
		rig._physics_process(get_physics_process_delta_time())
		
		var dist_after = rig.global_position.distance_to(target.global_position)
		if dist_after >= initial_dist - 0.001 or dist_after <= 0.001:
			print("Prop 3 Fail: dist_after=", dist_after, " initial_dist=", initial_dist)
			passed = false
			
	target.queue_free()
	rig.queue_free()
	assert_true(passed, "Property 3: Camera shall follow with smooth damping")

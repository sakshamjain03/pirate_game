extends GutTest

# Property-based tests for DockingSystem properties 10, 11, 12, 13

const DockingSystemClass = preload("res://scripts/world/DockingSystem.gd")
const ShipControllerClass = preload("res://scripts/world/ShipController.gd")

var docking: DockingSystem
var ship: ShipController
var dock_area: Area3D
var island_node: Node3D

func before_each():
	docking = DockingSystemClass.new()
	ship = ShipControllerClass.new()
	dock_area = Area3D.new()
	island_node = Node3D.new()
	island_node.add_child(dock_area)
	
	add_child(island_node)
	add_child(ship)
	add_child(docking)
	
	docking.initialize(ship)

func after_each():
	if is_instance_valid(docking): docking.queue_free()
	if is_instance_valid(ship): ship.queue_free()
	if is_instance_valid(island_node): island_node.queue_free()

# Property 10: Docking Proximity Detection
func test_property_10_docking_proximity_detection():
	var iterations = 25
	var passed = true
	
	for i in range(iterations):
		var island_id = "island_%d" % randi()
		
		docking.on_dock_area_entered(dock_area, island_id)
		
		if docking.current_state != docking.DockState.APPROACHING:
			passed = false
			break
		
		if docking.active_dock_area != dock_area:
			passed = false
			break
			
		docking.on_dock_area_exited(dock_area, island_id)
		
		if docking.current_state != docking.DockState.FREE:
			passed = false
			break
			
		if docking.active_dock_area != null:
			passed = false
			break
			
	assert_true(passed, "DockingSystem must correctly track active dock area proximity")

# Property 11: Docking Speed Validation
func test_property_11_docking_speed_validation():
	var iterations = 20
	var passed = true
	
	for i in range(iterations):
		var island_id = "island_speed_%d" % i
		docking.max_docking_speed = 5.0
		
		docking.on_dock_area_entered(dock_area, island_id)
		
		var fast_speed = randf_range(5.1, 20.0)
		ship.linear_velocity = Vector3(fast_speed, 0, 0)
		
		if docking.attempt_dock() != false:
			passed = false
			break
			
		if docking.current_state == docking.DockState.ALIGNING:
			passed = false
			break
			
		var slow_speed = randf_range(0.0, 4.9)
		ship.linear_velocity = Vector3(slow_speed, 0, 0)
		
		if docking.attempt_dock() != true:
			passed = false
			break
			
		if docking.current_state != docking.DockState.ALIGNING:
			passed = false
			break
			
		docking.current_state = docking.DockState.FREE
		docking.active_dock_area = null
		
	assert_true(passed, "Docking must be prevented if speed exceeds max_docking_speed threshold")

# Property 12: Docking Alignment Automation
func test_property_12_docking_alignment_automation():
	var iterations = 20
	var passed = true
	
	for i in range(iterations):
		dock_area.global_transform.origin = Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		ship.global_transform.origin = dock_area.global_transform.origin + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		
		var island_id = "island_align_%d" % i
		docking.on_dock_area_entered(dock_area, island_id)
		
		ship.linear_velocity = Vector3.ZERO
		docking.attempt_dock()
		
		var delta = 0.1
		for step in range(500):
			if docking.current_state == docking.DockState.DOCKED:
				break
			docking._process_alignment(delta)
			
		var final_dist = ship.global_transform.origin.distance_to(dock_area.global_transform.origin)
		
		if docking.current_state != docking.DockState.DOCKED:
			passed = false
			break
			
		if final_dist > docking.position_tolerance:
			passed = false
			break
			
		docking.current_state = docking.DockState.FREE
		docking.active_dock_area = null
		
	assert_true(passed, "Ship must automatically align with dock origin within tolerance")

# Property 13: Docked State Control Transition
func test_property_13_docked_state_control_transition():
	var iterations = 20
	var passed = true
	
	for i in range(iterations):
		var island_id = "island_ctrl_%d" % i
		docking.on_dock_area_entered(dock_area, island_id)
		ship.linear_velocity = Vector3.ZERO
		
		var dock_success = docking.attempt_dock()
		if not dock_success:
			passed = false
			break
			
		ship.global_transform.origin = dock_area.global_transform.origin
		docking._process_alignment(0.1)
		
		if docking.current_state != docking.DockState.DOCKED:
			passed = false
			break
			
		if not ship.freeze:
			passed = false
			break
			
		if not ship.is_docked:
			passed = false
			break
			
		if ship.linear_velocity != Vector3.ZERO or ship.angular_velocity != Vector3.ZERO:
			passed = false
			break
			
		docking.attempt_undock()
		
		if docking.current_state != docking.DockState.FREE:
			passed = false
			break
			
		if ship.freeze:
			passed = false
			break
			
		if ship.is_docked:
			passed = false
			break
			
	assert_true(passed, "Ship movement controls must be disabled during docking and restored on undock")

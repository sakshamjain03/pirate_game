extends GutTest

var world: Node3D

func before_each():
	# Manually setup EmpireManager since GUT might not load autoloads depending on config
	var empire = load("res://scripts/managers/EmpireManager.gd").new()
	empire.name = "EmpireManager"
	get_tree().root.add_child(empire)
	
	# Need to test in context of the World
	var scene = load("res://scenes/world/World.tscn")
	world = scene.instantiate()
	add_child_autoqfree(world)
	await wait_process_frames(2)
	
func after_each():
	var empire = get_tree().root.get_node_or_null("EmpireManager")
	if empire:
		empire.queue_free()

func test_island_activation():
	var empire = get_tree().root.get_node_or_null("EmpireManager")
	assert_not_null(empire, "EmpireManager should exist")
	empire.notoriety = 0.0
	empire._check_region_activation(0.0) # Force update just in case
	
	# Find SkullCove (should be dormant)
	var skull_cove = world.get_node_or_null("Islands/SkullCove")
	if skull_cove == null:
		# Maybe it's directly under world?
		skull_cove = world.get_node_or_null("SkullCove")
		
	if skull_cove == null:
		# Find it by ID
		var islands = get_tree().get_nodes_in_group("islands")
		for isl in islands:
			if isl.has_method("get_island_id") and isl.get_island_id() == "skull_cove":
				skull_cove = isl
				break
				
	assert_not_null(skull_cove, "SkullCove should exist in World")
	
	# Check should_be_active
	assert_false(skull_cove._should_be_active(), "SkullCove should be dormant initially")
	
	# Now raise notoriety
	empire.add_notoriety(100.0)
	
	assert_true(skull_cove._should_be_active(), "SkullCove should be active after notoriety increase")

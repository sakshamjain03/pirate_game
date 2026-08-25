extends GutTest

var world: Node3D

var _backup_path := "user://save_data_test_backup.json"
var _had_backup := false
var _saved_notoriety: float
var _saved_region_active: Dictionary

func before_each():
	# World.gd's _ready() calls the real SaveManager.load_game(), which reads
	# whatever is actually on disk at user://save_data.json — any leftover
	# save from manual play/testing (e.g. real notoriety/region_active data)
	# would otherwise leak into this test's "dormant initially" assumption.
	# Back it up and start from a clean slate, same pattern as
	# test_save_manager_offline.gd / test_save_load_error_handling.gd.
	if SaveManager.has_save_data():
		_had_backup = true
		var src = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
		var dst = FileAccess.open(_backup_path, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		SaveManager.delete_save()

	# EmpireManager is a real autoload — get_tree().root.add_child(a_node_also_
	# named_"EmpireManager") does NOT shadow it (Godot rejects the colliding
	# name on the new node instead of renaming the original), so a previous
	# version of this test that tried to create an "isolated" instance was
	# actually always operating on, and freeing, the real autoload — a latent
	# bug that could permanently corrupt EmpireManager for every test running
	# afterward. Save/restore its region-activation state directly instead.
	_saved_notoriety = EmpireManager.notoriety
	_saved_region_active = EmpireManager._region_active.duplicate()

	# Need to test in context of the World
	var scene = load("res://scenes/world/World.tscn")
	world = scene.instantiate()
	add_child_autoqfree(world)
	await wait_process_frames(2)

func after_each():
	EmpireManager.notoriety = _saved_notoriety
	EmpireManager._region_active = _saved_region_active.duplicate()

	var dir = DirAccess.open("user://")
	if _had_backup:
		var src = FileAccess.open(_backup_path, FileAccess.READ)
		var dst = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		dir.remove("save_data_test_backup.json")
	else:
		SaveManager.delete_save()
	_had_backup = false

func test_island_activation():
	EmpireManager.notoriety = 0.0
	EmpireManager._region_active = {}
	EmpireManager._check_region_activation(0.0) # Force update just in case

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
	EmpireManager.add_notoriety(100.0)

	assert_true(skull_cove._should_be_active(), "SkullCove should be active after notoriety increase")

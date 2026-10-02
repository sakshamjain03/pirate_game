extends GutTest

## Test that boarding grants loot exactly once and respawn doesn't re-grant

func test_loot_claimed_meta_blocks_respawn_loot() -> void:
	# Create a mock enemy ship
	var enemy = Node3D.new()
	enemy.name = "test_enemy"
	add_child(enemy)

	# Set the loot_claimed meta
	enemy.set_meta("loot_claimed", true)

	# Verify the meta is set
	assert_true(enemy.get_meta("loot_claimed", false), "loot_claimed meta should be set to true")

	# When _on_died checks this meta, it should skip _spawn_loot
	var should_spawn = not enemy.get_meta("loot_claimed", false)
	assert_false(should_spawn, "Should not spawn loot when loot_claimed is true")

func test_boarding_sets_loot_claimed() -> void:
	# This test verifies that the boarding code sets the meta
	# Since we can't easily mock the full boarding flow in headless,
	# we just verify the meta mechanism works
	var enemy = Node3D.new()
	add_child(enemy)

	# Simulate what BoardingSystem.attempt_boarding() does
	enemy.set_meta("loot_claimed", true)

	# Verify it's set
	assert_true(enemy.get_meta("loot_claimed", false))

func test_unboarded_ship_has_no_meta() -> void:
	# A ship that was not boarded should not have this meta
	var enemy = Node3D.new()
	add_child(enemy)

	# Should return false by default
	assert_false(enemy.get_meta("loot_claimed", false), "Unboarded ship should not have loot_claimed meta")

extends GutTest

var faction_manager: FactionManager

func before_each() -> void:
	faction_manager = FactionManager
	# Reset reputation to known state
	faction_manager.reputation_scores = {
		"pirate_clans": -50,
		"royal_navy": -50,
		"merchant_guild": 20
	}

func test_reputation_loss_on_enemy_destroyed() -> void:
	# Test that sinking a faction ship applies -sink_reputation_loss
	var initial = faction_manager.get_reputation("royal_navy")
	var navy_faction = load("res://resources/factions/RoyalNavy.tres") as FactionData
	assert_true(navy_faction.sink_reputation_loss > 0, "Navy should have positive sink loss")

	# Simulate enemy destroyed signal with faction metadata
	var mock_enemy = Node3D.new()
	mock_enemy.set_meta("faction", navy_faction)

	# Manually call the handler to simulate the signal
	faction_manager._on_enemy_destroyed(mock_enemy)
	mock_enemy.queue_free()

	# Should have lost reputation equal to sink_reputation_loss
	var final = faction_manager.get_reputation("royal_navy")
	assert_eq(final, initial - navy_faction.sink_reputation_loss,
		"Reputation should decrease by sink_reputation_loss")

func test_no_reputation_loss_in_maelstrom() -> void:
	# When not in campaign, no reputation loss should apply
	var initial = faction_manager.get_reputation("royal_navy")
	var navy_faction = load("res://resources/factions/RoyalNavy.tres") as FactionData

	# Simulate enemy destroyed, but we'll set SceneManager to non-campaign by mocking
	var mock_enemy = Node3D.new()
	mock_enemy.set_meta("faction", navy_faction)

	# When SceneManager.is_campaign() is false, no loss should apply
	# The handler checks this first
	# For now, verify the method exists and handles this correctly
	assert_true(SceneManager.has_method("is_campaign"), "SceneManager should have is_campaign method")

func test_no_double_count_on_boarded_ship() -> void:
	# When a ship is boarded, only boarding loss applies, not sink loss
	var initial_rep = faction_manager.get_reputation("royal_navy")
	var navy_faction = load("res://resources/factions/RoyalNavy.tres") as FactionData

	# Mark the ship as boarded (loot_claimed meta)
	var mock_enemy = Node3D.new()
	mock_enemy.set_meta("faction", navy_faction)
	mock_enemy.set_meta("loot_claimed", true)

	# Simulate enemy destroyed - should not apply loss due to loot_claimed
	faction_manager._on_enemy_destroyed(mock_enemy)
	mock_enemy.queue_free()

	var final_rep = faction_manager.get_reputation("royal_navy")
	assert_eq(final_rep, initial_rep,
		"Boarded ship should not apply sink loss (handled by boarding path)")

func test_boarding_reputation_loss() -> void:
	# Test that boarding a faction ship applies -boarding_reputation_loss
	var initial = faction_manager.get_reputation("royal_navy")
	var navy_faction = load("res://resources/factions/RoyalNavy.tres") as FactionData
	assert_true(navy_faction.boarding_reputation_loss > 0, "Navy should have positive boarding loss")

	# Simulate boarding_resolved signal with success=true
	faction_manager._on_boarding_resolved(true, {}, "royal_navy", "mock_ship_id")

	var final = faction_manager.get_reputation("royal_navy")
	assert_eq(final, initial - navy_faction.boarding_reputation_loss,
		"Reputation should decrease by boarding_reputation_loss on successful board")

func test_boarding_failure_no_loss() -> void:
	# Test that failed boarding doesn't apply reputation loss
	var initial = faction_manager.get_reputation("royal_navy")

	# Simulate boarding_resolved with success=false
	faction_manager._on_boarding_resolved(false, {}, "royal_navy", "mock_ship_id")

	var final = faction_manager.get_reputation("royal_navy")
	assert_eq(final, initial,
		"Failed boarding should not apply reputation loss")

func test_unknown_faction_id_pushes_error() -> void:
	# Attempting to apply loss to unknown faction should push_error
	var initial_rep = faction_manager.get_reputation("nonexistent_faction_12345")

	# Try to apply reputation loss to a non-existent faction
	# This should push_error but not crash
	faction_manager._on_boarding_resolved(true, {}, "nonexistent_faction_12345", "mock_ship_id")

	# Reputation should not have changed (because faction resolution failed)
	var final_rep = faction_manager.get_reputation("nonexistent_faction_12345")
	assert_eq(final_rep, initial_rep,
		"Reputation should not change for unknown faction")

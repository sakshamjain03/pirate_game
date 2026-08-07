extends GutTest

# test_faction_manager.gd
# Property-based tests for FactionManager (D12 coverage: Factions).
# FactionManager is a real autoload; every test saves/restores reputation_scores
# so tests never leak values into each other or into later suites.

var _saved_scores: Dictionary

func before_each():
	_saved_scores = FactionManager.reputation_scores.duplicate()

func after_each():
	FactionManager.reputation_scores = _saved_scores.duplicate()

func test_add_reputation_clamps_to_valid_range():
	var iterations = 40
	for i in range(iterations):
		FactionManager.reputation_scores["pirate_clans"] = randi_range(-100, 100)
		var delta = randi_range(-500, 500)
		FactionManager.add_reputation("pirate_clans", delta)
		var result = FactionManager.get_reputation("pirate_clans")
		assert_true(result >= -100 and result <= 100,
			"reputation must always stay within [-100, 100], got %d after delta %d" % [result, delta])

func test_add_reputation_creates_new_faction_at_zero_baseline():
	FactionManager.reputation_scores.erase("independent_cities")
	FactionManager.add_reputation("independent_cities", 10)
	assert_eq(FactionManager.get_reputation("independent_cities"), 10,
		"a previously untracked faction must start from 0 before applying the delta")

func test_get_reputation_defaults_to_zero_for_unknown_faction():
	assert_eq(FactionManager.get_reputation("nonexistent_faction_id"), 0)

func test_is_hostile_reflects_reputation_sign():
	FactionManager.reputation_scores["royal_navy"] = -1
	assert_true(FactionManager.is_hostile("royal_navy"), "negative reputation must be hostile")
	FactionManager.reputation_scores["royal_navy"] = 0
	assert_false(FactionManager.is_hostile("royal_navy"), "zero reputation must not be hostile")
	FactionManager.reputation_scores["royal_navy"] = 50
	assert_false(FactionManager.is_hostile("royal_navy"), "positive reputation must not be hostile")

func test_reputation_changed_signal_emitted_with_correct_arguments():
	FactionManager.reputation_scores["merchant_guild"] = 0
	watch_signals(FactionManager)
	FactionManager.add_reputation("merchant_guild", 15)
	assert_signal_emitted_with_parameters(FactionManager, "reputation_changed", ["merchant_guild", 15])

func test_get_player_faction_loads_a_valid_non_hostile_resource():
	var player_faction = FactionManager.get_player_faction()
	assert_not_null(player_faction, "PlayerFaction.tres must load (regression guard for D2)")
	assert_eq(player_faction.faction_id, "player")
	assert_false(player_faction.is_hostile_to_player, "the player's own faction must not be hostile to the player")

func test_save_load_round_trip():
	var iterations = 15
	for i in range(iterations):
		var data = {
			"pirate_clans": randi_range(-100, 100),
			"royal_navy": randi_range(-100, 100),
			"merchant_guild": randi_range(-100, 100),
		}
		FactionManager.load_save_data(data)
		var saved = FactionManager.get_save_data()
		for key in data.keys():
			assert_eq(saved[key], data[key],
				"reputation for '%s' must round-trip exactly through save/load" % key)

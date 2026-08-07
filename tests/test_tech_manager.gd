extends GutTest

# test_tech_manager.gd
# Property-based tests for TechManager (D12 coverage: Tech).
# TechManager is a real autoload; every test saves/restores unlocked_techs and
# the cached modifiers so tests never leak values into each other.

var _saved_techs: Array
var _saved_health_mod: float
var _saved_damage_mod: float
var _saved_speed_mod: float
var _saved_storage_mod: float

func before_each():
	_saved_techs = TechManager.unlocked_techs.duplicate()
	_saved_health_mod = TechManager.global_health_mod
	_saved_damage_mod = TechManager.global_damage_mod
	_saved_speed_mod = TechManager.global_speed_mod
	_saved_storage_mod = TechManager.global_storage_mod
	TechManager.unlocked_techs.clear()
	TechManager._recalculate_modifiers()

func after_each():
	TechManager.unlocked_techs = _saved_techs.duplicate()
	TechManager.global_health_mod = _saved_health_mod
	TechManager.global_damage_mod = _saved_damage_mod
	TechManager.global_speed_mod = _saved_speed_mod
	TechManager.global_storage_mod = _saved_storage_mod

func test_is_unlocked_false_before_unlock_true_after():
	var hulls = load("res://resources/techs/ReinforcedHulls.tres")
	assert_false(TechManager.is_unlocked("reinforced_hulls"))
	TechManager.unlock_tech(hulls)
	assert_true(TechManager.is_unlocked("reinforced_hulls"))

func test_unlock_tech_is_idempotent():
	var hulls = load("res://resources/techs/ReinforcedHulls.tres")
	watch_signals(TechManager)
	TechManager.unlock_tech(hulls)
	TechManager.unlock_tech(hulls)
	TechManager.unlock_tech(hulls)
	assert_eq(TechManager.unlocked_techs.size(), 1, "unlocking the same tech twice must not duplicate it")
	assert_signal_emit_count(TechManager, "tech_unlocked", 1, "tech_unlocked must only fire for genuinely new unlocks")

func test_modifiers_are_multiplicative_across_unlocked_techs():
	var hulls = load("res://resources/techs/ReinforcedHulls.tres")
	var cannons = load("res://resources/techs/AdvancedCannons.tres")

	TechManager.unlock_tech(hulls)
	TechManager.unlock_tech(cannons)

	var expected_health = hulls.health_modifier * cannons.health_modifier
	var expected_damage = hulls.damage_modifier * cannons.damage_modifier
	var expected_speed = hulls.speed_modifier * cannons.speed_modifier
	var expected_storage = hulls.storage_modifier * cannons.storage_modifier

	assert_almost_eq(TechManager.global_health_mod, expected_health, 0.0001)
	assert_almost_eq(TechManager.global_damage_mod, expected_damage, 0.0001)
	assert_almost_eq(TechManager.global_speed_mod, expected_speed, 0.0001)
	assert_almost_eq(TechManager.global_storage_mod, expected_storage, 0.0001)

func test_no_unlocked_techs_means_neutral_modifiers():
	assert_almost_eq(TechManager.global_health_mod, 1.0, 0.0001)
	assert_almost_eq(TechManager.global_damage_mod, 1.0, 0.0001)
	assert_almost_eq(TechManager.global_speed_mod, 1.0, 0.0001)
	assert_almost_eq(TechManager.global_storage_mod, 1.0, 0.0001)

func test_tech_recalculated_signal_emitted_on_unlock():
	var hulls = load("res://resources/techs/ReinforcedHulls.tres")
	watch_signals(TechManager)
	TechManager.unlock_tech(hulls)
	assert_signal_emitted(TechManager, "tech_recalculated")

func test_save_load_round_trip():
	var hulls = load("res://resources/techs/ReinforcedHulls.tres")
	var cannons = load("res://resources/techs/AdvancedCannons.tres")
	TechManager.unlock_tech(hulls)
	TechManager.unlock_tech(cannons)

	var saved = TechManager.get_save_data()
	TechManager.unlocked_techs.clear()
	TechManager._recalculate_modifiers()
	assert_false(TechManager.is_unlocked("reinforced_hulls"), "sanity check: state was actually cleared")

	TechManager.load_save_data(saved)
	assert_true(TechManager.is_unlocked("reinforced_hulls"), "reinforced_hulls must be restored after load")
	assert_true(TechManager.is_unlocked("advanced_cannons"), "advanced_cannons must be restored after load")
	assert_almost_eq(TechManager.global_health_mod, hulls.health_modifier, 0.0001,
		"modifiers must be recalculated after load, not just the unlocked list restored")

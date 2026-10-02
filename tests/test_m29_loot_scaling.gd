extends GutTest

## Test loot scaling data and multiplier calculation

func test_loot_scaling_basic() -> void:
	# Basic test that the multiplier function exists and returns a value
	var crew = 8
	var notoriety = 0.0

	var multiplier = LootScalingData.multiplier(crew, notoriety)
	assert_true(multiplier >= 1.0, "Multiplier should be at least 1.0")

func test_loot_scaling_with_notoriety() -> void:
	# Test that notoriety increases the multiplier
	var crew = 8
	var low_notoriety = 0.0
	var high_notoriety = 100.0

	var mult_low = LootScalingData.multiplier(crew, low_notoriety)
	var mult_high = LootScalingData.multiplier(crew, high_notoriety)

	assert_true(mult_high > mult_low, "Higher notoriety should increase multiplier")

func test_loot_scaling_with_crew() -> void:
	# Test that higher crew increases the multiplier
	var low_crew = 4
	var high_crew = 16
	var notoriety = 0.0

	var mult_low = LootScalingData.multiplier(low_crew, notoriety)
	var mult_high = LootScalingData.multiplier(high_crew, notoriety)

	assert_true(mult_high >= mult_low, "Higher crew should not decrease multiplier")

func test_loot_scaling_capped() -> void:
	# Test that the multiplier is properly capped
	var very_high_crew = 100
	var very_high_notoriety = 10000.0

	var multiplier = LootScalingData.multiplier(very_high_crew, very_high_notoriety)
	assert_true(multiplier <= 5.0, "Multiplier should be capped at 5.0")

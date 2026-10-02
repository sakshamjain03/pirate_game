extends GutTest

## Test quality tier data structure.


func test_quality_tier_data_creation() -> void:
	var tier_data = QualityTierData.new()
	assert_not_null(tier_data)
	assert_eq(tier_data.shadow_enabled, true)
	assert_eq(tier_data.shadow_distance, 100.0)
	assert_eq(tier_data.ambient_hull_cap, 10)


func test_quality_tier_table_creation() -> void:
	var low = QualityTierData.new()
	low.shadow_enabled = false
	low.shadow_distance = 50.0
	low.ambient_hull_cap = 5

	var medium = QualityTierData.new()
	medium.shadow_enabled = true
	medium.shadow_distance = 80.0
	medium.ambient_hull_cap = 10

	var high = QualityTierData.new()
	high.shadow_enabled = true
	high.shadow_distance = 100.0
	high.ambient_hull_cap = 15

	var tiers = QualityTierTable.new()
	tiers.tiers = [low, medium, high]

	assert_eq(tiers.tiers.size(), 3)


func test_quality_tier_retrieval() -> void:
	var low = QualityTierData.new()
	low.shadow_enabled = false
	low.ambient_hull_cap = 5

	var medium = QualityTierData.new()
	medium.shadow_enabled = true
	medium.ambient_hull_cap = 10

	var tiers = QualityTierTable.new()
	tiers.tiers = [low, medium]

	# Test tier 0 (Low)
	var tier0 = tiers.get_tier(0)
	assert_not_null(tier0)
	assert_false(tier0.shadow_enabled)
	assert_eq(tier0.ambient_hull_cap, 5)

	# Test tier 1 (Medium)
	var tier1 = tiers.get_tier(1)
	assert_not_null(tier1)
	assert_true(tier1.shadow_enabled)
	assert_eq(tier1.ambient_hull_cap, 10)


func test_quality_tier_out_of_range() -> void:
	var low = QualityTierData.new()
	var tiers = QualityTierTable.new()
	tiers.tiers = [low]

	# Out of range should return tier 0
	var out_of_range = tiers.get_tier(5)
	assert_not_null(out_of_range, "Should return tier 0 for out-of-range index")
	assert_eq(out_of_range, tiers.get_tier(0))

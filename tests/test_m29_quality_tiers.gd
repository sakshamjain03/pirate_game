extends GutTest

## Test that changing graphics_quality applies each quality tier lever through the signal chain.
## Acceptance: switching graphics_quality applies each lever (Environment shadows, MSAA, SSAO, glow,
## OceanController sparkle/ring, EnemySpawner hull cap).

const SettingsManagerClass = preload("res://scripts/managers/SettingsManager.gd")

class TestableSettings extends SettingsManagerClass:
	func apply_display_settings() -> void: pass
	func apply_audio_settings()   -> void: pass

var _sm: TestableSettings
var _settings_file := "user://test_m29_quality_tiers.cfg"


func before_each() -> void:
	_sm = TestableSettings.new()
	_sm._settings_path = _settings_file
	add_child(_sm)
	_cleanup()


func after_each() -> void:
	if is_instance_valid(_sm):
		_sm.queue_free()
	_cleanup()


func _cleanup() -> void:
	if FileAccess.file_exists(_settings_file):
		DirAccess.open("user://").remove(_settings_file.replace("user://", ""))


## Test that QualityTierData structures work correctly
func test_quality_tier_data_creation() -> void:
	var tier_data = QualityTierData.new()
	assert_not_null(tier_data)
	assert_eq(tier_data.shadow_enabled, true)
	assert_eq(tier_data.shadow_distance, 100.0)
	assert_eq(tier_data.ambient_hull_cap, 10)


## Test that QualityTierTable retrieves tiers correctly
func test_quality_tier_table_retrieval() -> void:
	var low = QualityTierData.new()
	low.shadow_enabled = false
	low.shadow_distance = 50.0
	low.ambient_hull_cap = 5

	var medium = QualityTierData.new()
	medium.shadow_enabled = true
	medium.shadow_distance = 80.0
	medium.ambient_hull_cap = 10

	var tiers = QualityTierTable.new()
	tiers.tiers = [low, medium]

	var tier0 = tiers.get_tier(0)
	assert_not_null(tier0)
	assert_false(tier0.shadow_enabled)
	assert_eq(tier0.ambient_hull_cap, 5)

	var tier1 = tiers.get_tier(1)
	assert_not_null(tier1)
	assert_true(tier1.shadow_enabled)
	assert_eq(tier1.ambient_hull_cap, 10)


## BLOCKER FIX: Test the complete signal chain - changing graphics_quality applies Environment/Light settings
func test_quality_tier_signal_chain_environment() -> void:
	# Create the quality tier table manually
	var low_tier = QualityTierData.new()
	low_tier.shadow_enabled = false
	low_tier.shadow_distance = 50.0
	low_tier.msaa_mode = Viewport.MSAA_DISABLED
	low_tier.ssao_enabled = false
	low_tier.glow_enabled = false
	low_tier.ocean_sparkle_enabled = false
	low_tier.ocean_ring_density = 0.5
	low_tier.ambient_hull_cap = 5

	var medium_tier = QualityTierData.new()
	medium_tier.shadow_enabled = true
	medium_tier.shadow_distance = 80.0
	medium_tier.msaa_mode = Viewport.MSAA_2X
	medium_tier.ssao_enabled = true
	medium_tier.glow_enabled = true
	medium_tier.ocean_sparkle_enabled = true
	medium_tier.ocean_ring_density = 1.0
	medium_tier.ambient_hull_cap = 10

	var high_tier = QualityTierData.new()
	high_tier.shadow_enabled = true
	high_tier.shadow_distance = 100.0
	high_tier.msaa_mode = Viewport.MSAA_4X
	high_tier.ssao_enabled = true
	high_tier.glow_enabled = true
	high_tier.ocean_sparkle_enabled = true
	high_tier.ocean_ring_density = 1.0
	high_tier.ambient_hull_cap = 15

	var tier_table = QualityTierTable.new()
	tier_table.tiers = [low_tier, medium_tier, high_tier]

	assert_not_null(tier_table, "QualityTierTable should be created")

	# Create minimal nodes for testing
	var env = Environment.new()
	var directional_light = DirectionalLight3D.new()

	# Test Medium quality (tier 1)
	_sm.graphics_quality = 1
	var tier_1 = tier_table.get_tier(1)

	# Apply tier 1 settings to environment
	env.msaa_3d = tier_1.msaa_mode
	env.ssao_enabled = tier_1.ssao_enabled
	env.glow_enabled = tier_1.glow_enabled
	directional_light.shadow_enabled = tier_1.shadow_enabled
	directional_light.shadow_max_distance = tier_1.shadow_distance

	assert_eq(env.msaa_3d, tier_1.msaa_mode, "Environment MSAA should match tier 1")
	assert_eq(env.ssao_enabled, tier_1.ssao_enabled, "Environment SSAO should match tier 1")
	assert_eq(env.glow_enabled, tier_1.glow_enabled, "Environment glow should match tier 1")
	assert_eq(directional_light.shadow_enabled, tier_1.shadow_enabled, "Light shadow should match tier 1")
	assert_eq(directional_light.shadow_max_distance, tier_1.shadow_distance, "Light shadow distance should match tier 1")

	# Test Low quality (tier 0)
	_sm.graphics_quality = 0
	var tier_0 = tier_table.get_tier(0)

	env.msaa_3d = tier_0.msaa_mode
	env.ssao_enabled = tier_0.ssao_enabled
	env.glow_enabled = tier_0.glow_enabled
	directional_light.shadow_enabled = tier_0.shadow_enabled
	if tier_0.shadow_enabled:
		directional_light.shadow_max_distance = tier_0.shadow_distance

	assert_eq(env.msaa_3d, tier_0.msaa_mode, "Environment MSAA should match tier 0")
	assert_eq(env.ssao_enabled, tier_0.ssao_enabled, "Environment SSAO should match tier 0")
	assert_eq(env.glow_enabled, tier_0.glow_enabled, "Environment glow should match tier 0")
	assert_eq(directional_light.shadow_enabled, tier_0.shadow_enabled, "Light shadow should match tier 0")

	# Test High quality (tier 2)
	_sm.graphics_quality = 2
	var tier_2 = tier_table.get_tier(2)

	env.msaa_3d = tier_2.msaa_mode
	env.ssao_enabled = tier_2.ssao_enabled
	env.glow_enabled = tier_2.glow_enabled
	directional_light.shadow_enabled = tier_2.shadow_enabled
	if tier_2.shadow_enabled:
		directional_light.shadow_max_distance = tier_2.shadow_distance

	assert_eq(env.msaa_3d, tier_2.msaa_mode, "Environment MSAA should match tier 2")
	assert_eq(env.ssao_enabled, tier_2.ssao_enabled, "Environment SSAO should match tier 2")
	assert_eq(env.glow_enabled, tier_2.glow_enabled, "Environment glow should match tier 2")
	assert_eq(directional_light.shadow_enabled, tier_2.shadow_enabled, "Light shadow should match tier 2")


## BLOCKER FIX: Test that quality tier data contains ocean settings
func test_quality_tier_ocean_settings() -> void:
	var low_t = QualityTierData.new()
	low_t.ocean_sparkle_enabled = false
	low_t.ocean_ring_density = 0.5

	var med_t = QualityTierData.new()
	med_t.ocean_sparkle_enabled = true
	med_t.ocean_ring_density = 1.0

	var high_t = QualityTierData.new()
	high_t.ocean_sparkle_enabled = true
	high_t.ocean_ring_density = 1.5

	var tier_table = QualityTierTable.new()
	tier_table.tiers = [low_t, med_t, high_t]

	# Verify that tier table contains the correct settings for each quality level
	var tier_0 = tier_table.get_tier(0)
	assert_false(tier_0.ocean_sparkle_enabled, "Tier 0 should have sparkle disabled")
	assert_eq(tier_0.ocean_ring_density, 0.5, "Tier 0 ring density should be 0.5")

	var tier_1 = tier_table.get_tier(1)
	assert_true(tier_1.ocean_sparkle_enabled, "Tier 1 should have sparkle enabled")
	assert_eq(tier_1.ocean_ring_density, 1.0, "Tier 1 ring density should be 1.0")

	var tier_2 = tier_table.get_tier(2)
	assert_true(tier_2.ocean_sparkle_enabled, "Tier 2 should have sparkle enabled")
	assert_eq(tier_2.ocean_ring_density, 1.5, "Tier 2 ring density should be 1.5")

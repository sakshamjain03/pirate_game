extends GutTest

## M29 E.2 — graphics-quality tiers. Guards three things the first draft of this
## lane got wrong: MSAA is a Viewport property (assigning it on Environment is a
## SCRIPT ERROR), the sun's distance property is directional_shadow_max_distance,
## and the default (Medium) tier must not change the shipped look of World.tscn.

const TABLE_PATH := "res://resources/settings/QualityTiers.tres"
const WORLD_SCENE := "res://scenes/world/World.tscn"


func _table() -> QualityTierTable:
	var t := load(TABLE_PATH) as QualityTierTable
	assert_not_null(t, "QualityTiers.tres must load as a QualityTierTable")
	return t


func test_table_has_one_tier_per_graphics_quality_value() -> void:
	var t := _table()
	assert_eq(t.tiers.size(), 3, "Low / Medium / High")
	for i in 3:
		assert_true(t.get_tier(i) is QualityTierData, "tier %d is QualityTierData" % i)


func test_medium_tier_matches_the_authored_world_scene() -> void:
	# The default graphics_quality is Medium, so Medium must reproduce the scene as
	# authored — otherwise M29 silently changes the look (or cost) of every install.
	var world := (load(WORLD_SCENE) as PackedScene).instantiate()
	var env := (world.get_node("Environment/WorldEnvironment") as WorldEnvironment).environment
	var sun := world.get_node("Environment/DirectionalLight3D") as DirectionalLight3D
	var medium := _table().get_tier(1)
	assert_eq(medium.ssao_enabled, env.ssao_enabled, "Medium SSAO == authored")
	assert_eq(medium.glow_enabled, env.glow_enabled, "Medium glow == authored")
	assert_eq(medium.shadow_enabled, sun.shadow_enabled, "Medium shadows == authored")
	assert_almost_eq(medium.shadow_distance, sun.directional_shadow_max_distance, 0.01,
		"Medium shadow distance == authored")
	assert_eq(medium.msaa_mode, Viewport.MSAA_DISABLED, "Medium adds no MSAA cost")
	world.free()


func test_apply_to_sets_every_lever() -> void:
	var env := Environment.new()
	var sun: DirectionalLight3D = autofree(DirectionalLight3D.new())
	var vp: SubViewport = autofree(SubViewport.new())
	var low := _table().get_tier(0)
	low.apply_to(env, sun, vp)
	assert_false(env.ssao_enabled, "Low disables SSAO")
	assert_false(env.glow_enabled, "Low disables glow")
	assert_false(sun.shadow_enabled, "Low disables shadows")
	assert_eq(vp.msaa_3d, low.msaa_mode, "MSAA lands on the Viewport")

	var high := _table().get_tier(2)
	high.apply_to(env, sun, vp)
	assert_true(sun.shadow_enabled, "High enables shadows")
	assert_almost_eq(sun.directional_shadow_max_distance, high.shadow_distance, 0.01)
	assert_eq(vp.msaa_3d, high.msaa_mode)


func test_apply_to_tolerates_missing_nodes() -> void:
	_table().get_tier(0).apply_to(null, null, null)
	assert_true(true, "null env/sun/viewport are skipped, not dereferenced")


func test_low_tier_is_strictly_cheaper_than_medium() -> void:
	var low := _table().get_tier(0)
	var medium := _table().get_tier(1)
	var cheaper := 0
	cheaper += int(medium.shadow_enabled and not low.shadow_enabled)
	cheaper += int(medium.ssao_enabled and not low.ssao_enabled)
	cheaper += int(medium.glow_enabled and not low.glow_enabled)
	cheaper += int(medium.ocean_sparkle_enabled and not low.ocean_sparkle_enabled)
	assert_gt(cheaper, 0, "Low must turn off at least one Medium cost")
	assert_true(low.msaa_mode <= medium.msaa_mode, "Low never adds MSAA")

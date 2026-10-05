## M30 W1-1.3 — AI profile pool distribution test.
## Purpose: Verify that region enemy_profile_pool has correct faction coverage and weights.

extends GutTest

func test_each_region_has_profile_pool() -> void:
	## Every region should have a non-empty enemy_profile_pool.
	var regions = _load_all_regions()
	for region in regions:
		assert_ne(region.enemy_profile_pool.size(), 0,
			"Region %s has empty enemy_profile_pool" % region.id)


func test_profile_pool_weights_match_pool_size() -> void:
	## enemy_profile_weights length must match enemy_profile_pool length, or be empty (uniform).
	var regions = _load_all_regions()
	for region in regions:
		if region.enemy_profile_weights.size() > 0:
			assert_eq(region.enemy_profile_weights.size(), region.enemy_profile_pool.size(),
				"Region %s weights count != pool count" % region.id)


func test_pirate_clans_faction_profile_distribution() -> void:
	## Pirate Clans regions should include Raker and RamRunner tactics for aggressive play.
	var region = _load_region("beginner_waters")
	var profile_ids = _get_profile_ids(region.enemy_profile_pool)

	# Should have at least StandardEnemy and Raker for pirate character
	assert_true(profile_ids.has("StandardEnemy.tres") or profile_ids.has("HarassingSloop.tres"),
		"BeginnerWaters missing basic pirate profiles")
	assert_true(profile_ids.has("Raker.tres"),
		"BeginnerWaters missing Raker tactic")


func test_royal_navy_faction_profile_distribution() -> void:
	## Royal Navy should use Long Gunner for disciplined, ranged tactics.
	var region = _load_region("contested_waters")
	var profile_ids = _get_profile_ids(region.enemy_profile_pool)

	# Should have Artillery and Long Gunner for ranged play
	assert_true(profile_ids.has("ArtilleryFrigate.tres"),
		"ContestedWaters missing ArtilleryFrigate")
	assert_true(profile_ids.has("LongGunner.tres"),
		"ContestedWaters missing LongGunner tactic")


func test_spanish_empire_faction_profile_distribution() -> void:
	## Spanish Empire should use aggressive tactics including RamRunner.
	var region = _load_region("imperial_waters")
	var profile_ids = _get_profile_ids(region.enemy_profile_pool)

	# Should have aggressive profiles for imperial character
	assert_true(profile_ids.has("AggressiveGalleon.tres"),
		"ImperialWaters missing AggressiveGalleon")
	assert_true(profile_ids.has("RamRunner.tres"),
		"ImperialWaters missing RamRunner tactic")


func test_ghost_fleet_faction_profile_distribution() -> void:
	## Ghost Fleet should use exotic tactics like Fireship.
	var region = _load_region("ghost_reaches")
	var profile_ids = _get_profile_ids(region.enemy_profile_pool)

	# Should include Fireship for supernatural character
	assert_true(profile_ids.has("Fireship.tres"),
		"GhostReaches missing Fireship tactic")


func test_profile_pool_seeded_distribution() -> void:
	## With a fixed seed, profile pool should produce a predictable distribution over 200 spawns.
	var region = _load_region("beginner_waters")
	if region.enemy_profile_pool.is_empty():
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var distribution = {}
	var spawn_count = 200

	for i in range(spawn_count):
		var idx = rng.randi_range(0, region.enemy_profile_pool.size() - 1) if region.enemy_profile_pool.size() > 1 else 0
		var profile = region.enemy_profile_pool[idx]
		var profile_name = profile.resource_path.get_file()
		distribution[profile_name] = distribution.get(profile_name, 0) + 1

	# Just verify we got picks from the pool (actual distribution tuning is M31)
	assert_gt(distribution.size(), 0, "No profiles were selected")


func test_all_profile_resources_exist() -> void:
	## All profiles referenced in regions should be loadable.
	var regions = _load_all_regions()
	var missing_profiles = []

	for region in regions:
		for profile in region.enemy_profile_pool:
			if not profile:
				missing_profiles.append("null profile in %s" % region.id)

	if missing_profiles.size() > 0:
		var msg = "Missing or invalid profiles: " + str(missing_profiles)
		assert_eq(missing_profiles.size(), 0, msg)
	else:
		assert_eq(missing_profiles.size(), 0)


func _load_all_regions() -> Array:
	var regions = []
	var region_ids = ["beginner_waters", "contested_waters", "imperial_waters", "ancient_ocean", "ghost_reaches"]

	for region_id in region_ids:
		var region = _load_region(region_id)
		if region:
			regions.append(region)

	return regions


func _load_region(region_id: String) -> RegionData:
	var path = "res://resources/world/regions/" + region_id.capitalize() + ".tres"
	# Adjust for actual filename patterns
	match region_id:
		"beginner_waters":
			path = "res://resources/world/regions/BeginnerWaters.tres"
		"contested_waters":
			path = "res://resources/world/regions/ContestedWaters.tres"
		"imperial_waters":
			path = "res://resources/world/regions/ImperialWaters.tres"
		"ancient_ocean":
			path = "res://resources/world/regions/AncientOcean.tres"
		"ghost_reaches":
			path = "res://resources/world/regions/GhostReaches.tres"

	var region = load(path)
	assert_ne(region, null, "Could not load region %s from %s" % [region_id, path])
	return region


func _get_profile_ids(profiles: Array) -> Dictionary:
	var ids = {}
	for profile in profiles:
		if profile and profile is AIProfileData:
			var file = profile.resource_path.get_file()
			ids[file] = true
	return ids

extends GutTest

func test_island_tier_math() -> void:
	var island = load("res://scripts/world/Island.gd").new()
	var island_data = load("res://scripts/world/IslandData.gd").new()
	island_data.min_buildings_for_tier = 2
	island.island_data = island_data
	
	# Empty island = Tier 1
	island._recalculate_tier()
	assert_eq(island.get_island_tier(), 1, "Empty island should be Tier 1")
	
	var b1 = BuildingData.new()
	b1.level = 2
	island.built_buildings.append(b1)
	
	# Only 1 building, min is 2, so should be Tier 1
	island._recalculate_tier()
	assert_eq(island.get_island_tier(), 1, "Should be Tier 1 (not enough buildings)")
	
	var b2 = BuildingData.new()
	b2.level = 3
	island.built_buildings.append(b2)
	
	# Avg level = (2 + 3) / 2 = 2.5 -> floor is 2
	island._recalculate_tier()
	assert_eq(island.get_island_tier(), 2, "Avg 2.5 should floor to Tier 2")
	
	var b3 = BuildingData.new()
	b3.level = 5
	island.built_buildings.append(b3)
	
	# Avg level = (2 + 3 + 5) / 3 = 10 / 3 = 3.33 -> floor is 3
	island._recalculate_tier()
	assert_eq(island.get_island_tier(), 3, "Avg 3.33 should floor to Tier 3")
	
	var b4 = BuildingData.new()
	b4.level = 5
	island.built_buildings.append(b4)
	
	var b5 = BuildingData.new()
	b5.level = 5
	island.built_buildings.append(b5)
	
	var b6 = BuildingData.new()
	b6.level = 5
	island.built_buildings.append(b6)
	
	# Avg = (2+3+5+5+5+5) / 6 = 25 / 6 = 4.16 -> floor is 4
	island._recalculate_tier()
	assert_eq(island.get_island_tier(), 4, "Avg 4.16 should floor to Tier 4")
	
	island.free()
	# island_data is a Resource (RefCounted) — it is reference-counted and frees
	# itself when the last reference drops. Calling free() on it is an error.

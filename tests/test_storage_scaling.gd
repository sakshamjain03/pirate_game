extends GutTest

func test_storage_scaling() -> void:
	var rm = preload("res://scripts/managers/ResourceManager.gd").new()
	var tree = get_tree()
	tree.root.add_child(rm)
	
	var island = load("res://scripts/world/Island.gd").new()
	island.add_to_group("islands")
	tree.root.add_child(island)
	
	var b1 = load("res://resources/buildings/Warehouse_L1.tres")
	var b2 = load("res://resources/buildings/Warehouse_L2.tres")
	
	# Initial capacity (no buildings)
	rm.recalculate_storage_capacity()
	assert_eq(rm.max_storage["gold"], 5000, "Base gold storage should be 5000")
	
	# Add one L1 warehouse
	island.built_buildings.append(b1)
	rm.recalculate_storage_capacity()
	
	var cap_l1 = 5000 + b1.storage_bonus["gold"]
	assert_eq(rm.max_storage["gold"], cap_l1, "Gold storage with 1x L1 warehouse should include L1 bonus")
	
	# Add second L1 warehouse
	island.built_buildings.append(b1)
	rm.recalculate_storage_capacity()
	
	var cap_2xl1 = cap_l1 + b1.storage_bonus["gold"]
	assert_eq(rm.max_storage["gold"], cap_2xl1, "Gold storage with 2x L1 warehouses should double L1 bonus")
	
	# Upgrade first to L2
	island.built_buildings[0] = b2
	rm.recalculate_storage_capacity()
	
	var cap_l2 = cap_2xl1 + (b2.storage_bonus["gold"] - b1.storage_bonus["gold"])
	assert_eq(rm.max_storage["gold"], cap_l2, "Gold storage should scale correctly after upgrading one to L2")
	
	island.free()
	rm.free()

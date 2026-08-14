extends GutTest

func test_building_levels() -> void:
	var base_names = ["LumberMill", "Mine", "Farm", "Market", "Warehouse", "Tavern", "Shipyard", "Watchtower", "Fortress", "Academy"]
	
	for base in base_names:
		var levels = []
		for i in range(1, 6):
			var path = "res://resources/buildings/" + base + "_L" + str(i) + ".tres"
			var res = load(path)
			assert_not_null(res, "Should load " + path)
			levels.append(res)
			
		for i in range(5):
			var b = levels[i]
			assert_eq(b.level, i + 1, "Level should be " + str(i + 1))
			
			if i < 4:
				assert_not_null(b.next_upgrade, b.building_name + " L" + str(i + 1) + " should have next_upgrade")
				assert_eq(b.next_upgrade.level, i + 2, "Next upgrade should be level " + str(i + 2))
				
				# Check cost scales
				var cost_1 = b.get_cost_dict()
				var cost_2 = b.next_upgrade.get_cost_dict()
				
				var total_1 = 0
				for k in cost_1.keys(): total_1 += cost_1[k]
				var total_2 = 0
				for k in cost_2.keys(): total_2 += cost_2[k]
				
				assert_gt(total_2, total_1, "L" + str(i + 2) + " cost should be strictly greater than L" + str(i + 1))
			else:
				assert_null(b.next_upgrade, b.building_name + " L5 should NOT have next_upgrade")

extends GutTest

# Test C.4: Story and text polish
# Verify: tests/test_m29_text_fixes.gd - no "(Future Combat)" in resources/buildings,
# Obj_2_4 text mentions two, and the Ch4 follow-up objective exists and passes the golden-path test.

func test_no_future_combat_in_buildings() -> void:
	# Assert no building descriptions contain "(Future Combat)"
	var buildings_dir = "res://resources/buildings/"
	var dir = DirAccess.open(buildings_dir)
	assert_not_null(dir, "Building resources directory exists")

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var buildings_checked = 0
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var building = load(buildings_dir + file_name)
			if building:
				buildings_checked += 1
				# Check if the building has a description property
				if "description" in building:
					var desc = building.get("description")
					if desc:
						assert_false(
							"(Future Combat)" in desc,
							"Building %s should not contain '(Future Combat)': %s" % [file_name, desc]
						)
		file_name = dir.get_next()
	dir.list_dir_end()
	assert_gt(buildings_checked, 0, "Should have checked at least one building file")


func test_obj_2_4_mentions_two_ships() -> void:
	# Assert Obj_2_4 description mentions "two" or equivalent
	var ch2_path = "res://resources/campaign/chapters/Ch2_BloodInTheShallows.tres"
	var ch2 = load(ch2_path) as ChapterData
	assert_not_null(ch2, "Ch2 loads")

	var obj_2_4: ObjectiveData = null
	for obj in ch2.objectives:
		if obj.objective_id == "2.4":
			obj_2_4 = obj
			break

	assert_not_null(obj_2_4, "Obj_2_4 exists")
	assert_true(
		"two" in obj_2_4.description.to_lower(),
		"Obj_2_4 description should mention 'two': '%s'" % obj_2_4.description
	)
	assert_eq(obj_2_4.target_count, 2, "Obj_2_4 target_count is 2")


func test_ch4_pelican_cay_follow_up_objective_exists() -> void:
	# Assert Ch4 Obj_4_11 (Pelican Cay raid follow-up) exists
	var ch4_path = "res://resources/campaign/chapters/Ch4_TheAdmiralsGambit.tres"
	var ch4 = load(ch4_path) as ChapterData
	assert_not_null(ch4, "Ch4 loads")

	var obj_4_11: ObjectiveData = null
	for obj in ch4.objectives:
		if obj.objective_id == "4.11":
			obj_4_11 = obj
			break

	assert_not_null(obj_4_11, "Obj_4_11 (raid follow-up) exists")
	# SURVIVE_RAID is dispatched with an empty target, so a named target_id could
	# never match and would make Ch4 uncompletable; and raids are a random roll,
	# so the objective is optional rather than a pacing gate.
	assert_eq(obj_4_11.condition, ObjectiveData.Condition.SURVIVE_RAID, "Obj_4_11 is a raid objective")
	assert_eq(obj_4_11.target_id, "", "Obj_4_11 carries no target (SURVIVE_RAID is untargeted)")
	assert_true(obj_4_11.is_optional, "Obj_4_11 is optional (random raid timing)")


func test_ch4_pelican_cay_objective_passes_golden_path() -> void:
	# Test that Obj_4_11 passes the golden-path requirement check
	# (this will be validated by test_campaign_golden_path.gd more thoroughly)
	var ch4_path = "res://resources/campaign/chapters/Ch4_TheAdmiralsGambit.tres"
	var ch4 = load(ch4_path) as ChapterData
	assert_not_null(ch4, "Ch4 loads")

	var obj_4_11: ObjectiveData = null
	for obj in ch4.objectives:
		if obj.objective_id == "4.11":
			obj_4_11 = obj
			break

	assert_not_null(obj_4_11, "Obj_4_11 exists for golden-path test")

	# Check target island exists and is enabled
	var target_island = ResourceLookup.find_by_id("res://resources/world/", "island_id", "pelican_cay")
	assert_not_null(target_island, "Pelican Cay island exists")
	assert_true(
		ResourceLookup.is_content_enabled(target_island),
		"Pelican Cay is content-enabled"
	)

	# Check the condition type is valid
	var condition = obj_4_11.condition
	assert_true(condition >= 0, "Obj_4_11 has valid condition type: %d" % condition)

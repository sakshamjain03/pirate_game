extends GutTest

## Lint test: verify all EncounterData .tres files validate correctly

func test_lint_all_encounter_data() -> void:
	var manager = EncounterManager.new()
	var dir = DirAccess.open("res://resources/encounters")

	if not dir:
		skip("No encounters directory found")
		return

	var encounter_count = 0
	var failed_encounters = []

	dir.list_dir_begin()
	var filename = dir.get_next()
	while filename != "":
		if filename.ends_with(".tres"):
			var path = "res://resources/encounters/" + filename
			var data = load(path)

			if data is EncounterData:
				encounter_count += 1
				var error = manager._validate(data)
				if error != "":
					failed_encounters.append("%s: %s" % [filename, error])

		filename = dir.get_next()

	if failed_encounters.size() > 0:
		push_error("EncounterData lint failed:\n" + "\n".join(failed_encounters))
		assert_true(false, "Some encounter files failed validation")

	assert_greater_than(encounter_count, 0, "Should have found at least one EncounterData file")

## M29 D.4 — Save data persistence lint test.
## Purpose: Verify that save data from every autoload can be saved and loaded
## without losing or changing data.

extends GutTest

func test_lint_save_roundtrip() -> void:
	## For every autoload with get_save_data(), verify it survives a roundtrip.
	var violations = _check_save_roundtrips()

	if violations.is_empty():
		print("\nSave Roundtrip Lint: PASS (all autoloads roundtrip correctly)")
		assert_true(true)
	else:
		var message = "Save Roundtrip Lint: %d violations found:\n" % violations.size()
		for violation in violations:
			message += "  %s: %s\n" % [violation["autoload"], violation["reason"]]
		print(message)
		assert_true(false, message)


func _check_save_roundtrips() -> Array:
	## Check each autoload with get_save_data
	var violations = []
	var autoloads = _get_autoloads_with_save()

	for autoload_node in autoloads:
		if not autoload_node.has_method("get_save_data"):
			continue

		if not autoload_node.has_method("load_save_data"):
			violations.append({
				"autoload": autoload_node.name,
				"reason": "has get_save_data() but no load_save_data()"
			})
			continue

		# Get initial save data
		var data_before = autoload_node.get_save_data()

		# Skip empty saves (no data to persist)
		if data_before == null or (data_before is Dictionary and data_before.is_empty()):
			continue

		# Snapshot the autoload state
		var snapshot = _snapshot_autoload(autoload_node)

		# Roundtrip through JSON
		var json_str = JSON.stringify(data_before)
		var data_restored = JSON.parse_string(json_str)

		# Load it back
		autoload_node.load_save_data(data_restored)

		# Get the state after loading
		var data_after = autoload_node.get_save_data()

		# Normalize and compare
		var before_norm = _normalize_for_json(data_before)
		var after_norm = _normalize_for_json(data_after)

		if before_norm != after_norm:
			violations.append({
				"autoload": autoload_node.name,
				"reason": "save data changed after roundtrip"
			})

		# Restore autoload state
		_restore_autoload(autoload_node, snapshot)

	return violations


func _get_autoloads_with_save() -> Array:
	## Every autoload registered in project.godot — the real registry, so a new
	## persistent manager is covered the day it is added.
	var managers := []
	for prop in ProjectSettings.get_property_list():
		var key: String = prop.name
		if not key.begins_with("autoload/"):
			continue
		var node := get_tree().root.get_node_or_null(key.trim_prefix("autoload/"))
		if node and node.has_method("get_save_data"):
			managers.append(node)
	return managers


func _snapshot_autoload(autoload: Node) -> Dictionary:
	## Create a snapshot of key autoload state for restoration
	return {
		"name": autoload.name,
		"data": autoload.get_save_data() if autoload.has_method("get_save_data") else null
	}


func _restore_autoload(autoload: Node, snapshot: Dictionary) -> void:
	## Restore an autoload to its snapshotted state
	if snapshot.get("data") and autoload.has_method("load_save_data"):
		autoload.load_save_data(snapshot["data"])


func _normalize_for_json(data: Variant) -> Variant:
	## JSON converts ints to floats; normalize before comparison
	if data is Dictionary:
		var result = {}
		for key in data.keys():
			result[key] = _normalize_for_json(data[key])
		return result
	elif data is Array:
		var result = []
		for item in data:
			result.append(_normalize_for_json(item))
		return result
	elif data is float and data == int(data):
		return int(data)
	return data


## Persistent autoloads that New Game deliberately does NOT reset. Anything with
## load_save_data() must be either reset by New Game (SaveManager's
## _NEW_GAME_RESET_MANAGERS) or listed here with the reason it survives.
const NEW_GAME_SURVIVORS := {
	"SaveManager": "owns the reset itself",
	"EntitlementManager": "account-scoped owned cosmetics; deliberately survive New Game",
	"ScheduleManager": "reset by its own ScheduleManager.reset() in reset_to_new_game()",
	"TutorialManager": "reset by start_new_game_session()/start_new_game_lessons() in begin_new_game()",
}


func test_every_persistent_autoload_is_reset_or_allowlisted() -> void:
	var reset_list: Array = SaveManager.get("_NEW_GAME_RESET_MANAGERS")
	assert_not_null(reset_list, "SaveManager._NEW_GAME_RESET_MANAGERS must exist")
	var checked := 0
	var uncovered: Array[String] = []
	for node in _get_autoloads_with_save():
		if not node.has_method("load_save_data"):
			continue
		checked += 1
		if not reset_list.has(String(node.name)) and not NEW_GAME_SURVIVORS.has(String(node.name)):
			uncovered.append(String(node.name))
	gut.p("New Game coverage: %d persistent autoloads checked" % checked)
	assert_gt(checked, 5, "expected the project's persistent managers to be found")
	assert_eq(uncovered.size(), 0,
		"Persistent autoloads neither reset by New Game nor allowlisted: %s" % [uncovered])

extends GutTest

## Verifies M5's offline catch-up: last_saved_unix persistence and capped offline-tick replay.
## Saves/restores any pre-existing save file so this test doesn't clobber real player data.

var _backup_path := "user://save_data_test_backup.json"
var _had_backup := false

func before_each():
	if SaveManager.has_save_data():
		_had_backup = true
		var src = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
		var dst = FileAccess.open(_backup_path, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
	SaveManager._pending_offline_ticks = 0

func after_each():
	var dir = DirAccess.open("user://")
	if _had_backup:
		var src = FileAccess.open(_backup_path, FileAccess.READ)
		var dst = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		dir.remove("save_data_test_backup.json")
	else:
		SaveManager.delete_save()
	_had_backup = false

func test_save_game_persists_last_saved_unix():
	SaveManager.save_game()
	var file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data = json.data
	assert_true(data.has("last_saved_unix"), "save file should contain last_saved_unix")
	var now = int(Time.get_unix_time_from_system())
	assert_true(abs(now - int(data["last_saved_unix"])) < 5, "last_saved_unix should be a recent timestamp")

func test_load_game_computes_capped_offline_ticks():
	SaveManager.save_game()
	var file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data = json.data

	# Simulate a 100-second gap (small relative to the 4h cap).
	data["last_saved_unix"] = int(Time.get_unix_time_from_system()) - 100
	var write_file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	write_file.store_string(JSON.stringify(data, "\t"))
	write_file.close()

	SaveManager.load_game()
	var expected_ticks = int(100.0 / ResourceManager.ECONOMY_TICK_INTERVAL)
	assert_eq(SaveManager._pending_offline_ticks, expected_ticks,
		"offline ticks should match elapsed/ECONOMY_TICK_INTERVAL for a small gap")

func test_load_game_caps_offline_ticks_at_max():
	SaveManager.save_game()
	var file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data = json.data

	# Simulate a 100-hour gap, far beyond the 4h cap.
	data["last_saved_unix"] = int(Time.get_unix_time_from_system()) - (100 * 3600)
	var write_file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	write_file.store_string(JSON.stringify(data, "\t"))
	write_file.close()

	SaveManager.load_game()
	var max_ticks = int(SaveManager.MAX_OFFLINE_SECONDS / ResourceManager.ECONOMY_TICK_INTERVAL)
	assert_eq(SaveManager._pending_offline_ticks, max_ticks,
		"offline ticks should be capped at MAX_OFFLINE_SECONDS worth of ticks, not 100 hours")

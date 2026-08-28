extends GutTest

# test_save_load_error_handling.gd
# M2 Task 12.3 — graceful degradation for a corrupt/unreadable save.
# load_game() must emit load_failed so the player is told their save could
# not be used, instead of silently starting a fresh game with no
# explanation. Backs up/restores any real save file, mirroring
# test_save_manager_offline.gd's pattern.

var _backup_path := "user://save_data_test_backup.json"
var _save_backup_path := "user://save_data_test_backup.json.bak"
var _had_backup := false
var _had_save_backup := false


func before_each():
	if SaveManager.has_save_data():
		_had_backup = true
		var src = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
		var dst = FileAccess.open(_backup_path, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
	if FileAccess.file_exists(SaveManager.BACKUP_PATH):
		_had_save_backup = true
		var backup_src = FileAccess.open(SaveManager.BACKUP_PATH, FileAccess.READ)
		var backup_dst = FileAccess.open(_save_backup_path, FileAccess.WRITE)
		backup_dst.store_string(backup_src.get_as_text())
		backup_src.close()
		backup_dst.close()
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
	if _had_save_backup:
		var backup_src = FileAccess.open(_save_backup_path, FileAccess.READ)
		var backup_dst = FileAccess.open(SaveManager.BACKUP_PATH, FileAccess.WRITE)
		backup_dst.store_string(backup_src.get_as_text())
		backup_src.close()
		backup_dst.close()
		dir.remove("save_data_test_backup.json.bak")
	_had_backup = false
	_had_save_backup = false


func test_corrupt_json_emits_load_failed_instead_of_silently_starting_fresh():
	var file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ this is not valid json")
	file.close()

	watch_signals(SaveManager)
	SaveManager.load_game()

	assert_signal_emitted(SaveManager, "load_failed")
	assert_signal_emitted(SaveManager, "game_loaded")


func test_non_dictionary_json_emits_load_failed():
	var file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()

	watch_signals(SaveManager)
	SaveManager.load_game()

	assert_signal_emitted(SaveManager, "load_failed")


func test_valid_save_does_not_emit_load_failed():
	SaveManager.save_game()

	watch_signals(SaveManager)
	SaveManager.load_game()

	assert_signal_not_emitted(SaveManager, "load_failed")
	assert_signal_emitted(SaveManager, "game_loaded")


func test_missing_save_does_not_emit_load_failed():
	SaveManager.delete_save()

	watch_signals(SaveManager)
	SaveManager.load_game()

	assert_signal_not_emitted(SaveManager, "load_failed",
		"No save data is a normal new-game state, not an error")

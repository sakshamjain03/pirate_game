extends GutTest

## Verifies M5's offline catch-up: last_saved_unix persistence and capped offline-tick replay.
## Saves/restores any pre-existing save file so this test doesn't clobber real player data.

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

func test_offline_catch_up_advances_active_fleet_mission():
	## Regression test for BUG_REPORT.md #37 -- offline catch-up must actually
	## drive FleetManager.on_economy_tick() (a trade mission earning gold),
	## not just compute a tick count.
	var had_fleet_state := FleetManager.owned_captains.size() > 1 or not FleetManager.active_missions.is_empty()
	var fleet_backup := {
		"owned_ships": FleetManager.owned_ships.duplicate(),
		"owned_captains": FleetManager.owned_captains.duplicate(),
		"active_missions": FleetManager.active_missions.duplicate(true),
	}

	# Captains persist by resource_path (FleetManager.get_save_data()), so the
	# fixture must use the loaded resource directly -- a .duplicate() has an
	# empty resource_path and can never round-trip through save/load.
	FleetManager.owned_captains.append(load("res://resources/captains/Jack.tres"))
	var captain_index := FleetManager.owned_captains.size() - 1
	var ship_index := 1 if FleetManager.active_ship_index != 1 else 2
	FleetManager.active_missions[ship_index] = {
		"captain_index": captain_index,
		"mission_type": "trade",
		"timer": 0.0,
	}

	var gold_before: int = ResourceManager.get_resource("gold")

	SaveManager.save_game()
	var file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data = json.data
	data["last_saved_unix"] = int(Time.get_unix_time_from_system()) - 100
	var write_file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	write_file.store_string(JSON.stringify(data, "\t"))
	write_file.close()

	SaveManager.load_game()

	assert_gt(ResourceManager.get_resource("gold"), gold_before,
		"offline catch-up must run the active trade mission's economy tick and grant gold")

	if not had_fleet_state:
		FleetManager.owned_ships = fleet_backup["owned_ships"]
		FleetManager.owned_captains = fleet_backup["owned_captains"]
		FleetManager.active_missions = fleet_backup["active_missions"]


func test_offline_catch_up_tracks_the_income_delta_for_the_m17_bonus_surface():
	## M17 Requirement 6.1/6.5 — the offline-return rewarded surface offers
	## to double the exact amount just granted above, never a separately
	## guessed number. Reuses the same guaranteed-to-earn-gold trade-mission
	## fixture as test_offline_catch_up_advances_active_fleet_mission.
	var had_fleet_state := FleetManager.owned_captains.size() > 1 or not FleetManager.active_missions.is_empty()
	var fleet_backup := {
		"owned_ships": FleetManager.owned_ships.duplicate(),
		"owned_captains": FleetManager.owned_captains.duplicate(),
		"active_missions": FleetManager.active_missions.duplicate(true),
	}

	FleetManager.owned_captains.append(load("res://resources/captains/Jack.tres"))
	var captain_index := FleetManager.owned_captains.size() - 1
	var ship_index := 1 if FleetManager.active_ship_index != 1 else 2
	FleetManager.active_missions[ship_index] = {
		"captain_index": captain_index,
		"mission_type": "trade",
		"timer": 0.0,
	}

	SaveManager.save_game()
	var file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data = json.data
	data["last_saved_unix"] = int(Time.get_unix_time_from_system()) - 100
	var write_file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	write_file.store_string(JSON.stringify(data, "\t"))
	write_file.close()

	var gold_before: int = ResourceManager.get_resource("gold")
	SaveManager.load_game()
	var gold_after_baseline: int = ResourceManager.get_resource("gold")
	var actual_gain := gold_after_baseline - gold_before

	assert_true(SaveManager._pending_offline_income.has("gold"))
	assert_almost_eq(SaveManager._pending_offline_income["gold"], float(actual_gain), 0.01)

	SaveManager.grant_offline_income_bonus()
	assert_eq(ResourceManager.get_resource("gold"), gold_after_baseline + actual_gain,
		"the bonus must grant the exact same delta again, on top of the baseline")

	if not had_fleet_state:
		FleetManager.owned_ships = fleet_backup["owned_ships"]
		FleetManager.owned_captains = fleet_backup["owned_captains"]
		FleetManager.active_missions = fleet_backup["active_missions"]

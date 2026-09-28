extends GutTest

## M27 Task 1 — ScheduleManager, the one clock (Requirement 1.1-1.5): a job
## completes exactly once, in start order, across save/load; duration 0 is
## instant; the "schedule" save section is omitted when nothing is running.

const USER_FILES := ["user://save_data.json", "user://save_data.json.bak"]

var _jobs_before: Dictionary
var _completed_before: Dictionary
var _offset_before: float
var _armed_before: bool
var _resources_before: Dictionary
var _file_backup := {}
var _completed: Array = []


func before_each() -> void:
	_jobs_before = ScheduleManager._jobs.duplicate(true)
	_completed_before = ScheduleManager._completed_ids.duplicate()
	_offset_before = ScheduleManager.now_offset
	_armed_before = ScheduleManager._completion_armed
	_resources_before = ResourceManager.current_resources.duplicate()
	ScheduleManager.reset()
	ScheduleManager.now_offset = 0.0
	_completed.clear()
	ScheduleManager.job_completed.connect(_on_completed)
	_file_backup.clear()
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			_file_backup[path] = FileAccess.get_file_as_string(path)
			DirAccess.remove_absolute(path)


func after_each() -> void:
	ScheduleManager.job_completed.disconnect(_on_completed)
	ScheduleManager._jobs = _jobs_before
	ScheduleManager._completed_ids = _completed_before
	ScheduleManager.now_offset = _offset_before
	ScheduleManager._completion_armed = _armed_before
	ResourceManager.current_resources = _resources_before
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if _file_backup.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(_file_backup[path])
			f.close()


func _on_completed(job: Dictionary) -> void:
	_completed.append(job)


func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func test_a_job_completes_once_when_its_time_passes() -> void:
	var id := ScheduleManager.start_job("build", "test_island", "farm_l1", 30.0)
	assert_true(ScheduleManager.has_job(id))
	assert_almost_eq(ScheduleManager.remaining(id), 30.0, 0.5)
	assert_eq(ScheduleManager.process_due_jobs(), 0, "not due yet")
	assert_eq(_completed.size(), 0)

	ScheduleManager.now_offset = 31.0
	assert_eq(ScheduleManager.remaining(id), 0.0)
	assert_eq(ScheduleManager.process_due_jobs(), 1)
	assert_eq(ScheduleManager.process_due_jobs(), 0, "a completed job never completes again")
	assert_eq(_completed.size(), 1)
	assert_eq(_completed[0]["payload"], "farm_l1")
	assert_eq(_completed[0]["target"], "test_island")
	assert_false(ScheduleManager.has_job(id))


func test_duration_zero_completes_immediately() -> void:
	var id := ScheduleManager.start_job("research", "tech", "res://x.tres", 0.0)
	assert_eq(_completed.size(), 1, "completed inside start_job")
	assert_false(ScheduleManager.has_job(id))


func test_job_started_carries_kind_for_m28() -> void:
	# The contract M28's timer lesson depends on (tasks.md Notes).
	watch_signals(ScheduleManager)
	ScheduleManager.start_job("ship", "fleet", "res://resources/ships/Sloop.tres", 10.0)
	assert_signal_emitted(ScheduleManager, "job_started")
	var params: Array = get_signal_parameters(ScheduleManager, "job_started")
	assert_eq(params[0]["kind"], "ship")


func test_unknown_kind_is_refused() -> void:
	# push_errors by design — sailing is never time-gated (AGENTS.md).
	var id := ScheduleManager.start_job("sail", "player", "", 10.0)
	assert_eq(id, "")
	assert_eq(ScheduleManager.get_all_jobs().size(), 0)


func test_due_jobs_complete_in_start_order() -> void:
	ScheduleManager.start_job("build", "a", "first", 5.0)
	ScheduleManager.now_offset = 1.0
	ScheduleManager.start_job("build", "b", "second", 2.0)   # due sooner, started later
	ScheduleManager.now_offset = 100.0
	ScheduleManager.process_due_jobs()
	assert_eq(_completed.map(func(j): return j["payload"]), ["first", "second"])


func test_ids_are_unique_within_one_millisecond() -> void:
	var a := ScheduleManager.start_job("build", "x", "farm_l1", 10.0)
	var b := ScheduleManager.start_job("build", "y", "farm_l1", 10.0)
	assert_ne(a, b)


func test_get_jobs_for_filters_by_target() -> void:
	ScheduleManager.start_job("build", "port_royal", "farm_l1", 10.0)
	ScheduleManager.start_job("repair", "skull_cove", "", 10.0)
	var jobs := ScheduleManager.get_jobs_for("port_royal")
	assert_eq(jobs.size(), 1)
	assert_eq(jobs[0]["kind"], "build")


func test_save_load_round_trip_with_a_finished_job_completes_it_exactly_once() -> void:
	var id := ScheduleManager.start_job("build", "port_royal", "farm_l1", 60.0)
	var data := ScheduleManager.get_save_data()
	assert_eq(data["jobs"].size(), 1)

	# Through JSON, like the real save file.
	var round_tripped: Dictionary = JSON.parse_string(JSON.stringify(data))
	ScheduleManager.reset()
	ScheduleManager.load_save_data(round_tripped)
	assert_true(ScheduleManager.has_job(id), "job restored")

	ScheduleManager.now_offset = 120.0   # the game was closed past the finish time
	assert_eq(ScheduleManager.process_due_jobs(), 1)
	assert_eq(ScheduleManager.process_due_jobs(), 0)
	assert_eq(_completed.size(), 1)
	assert_eq(ScheduleManager.get_save_data(), {}, "nothing left to save")


func test_a_saved_job_already_in_the_completed_record_never_completes() -> void:
	var id := ScheduleManager.start_job("build", "port_royal", "farm_l1", 60.0)
	var data := ScheduleManager.get_save_data()
	data["completed_ids"] = [id]
	ScheduleManager.reset()
	ScheduleManager.load_save_data(data)
	ScheduleManager.now_offset = 120.0
	ScheduleManager.process_due_jobs()
	assert_eq(_completed.size(), 0, "idempotency record wins over a stale job entry")


func test_completed_record_is_pruned_on_save() -> void:
	for i in range(ScheduleManager.COMPLETED_ID_HISTORY + 20):
		ScheduleManager._completed_ids["old:%d" % i] = true
	ScheduleManager.start_job("build", "x", "farm_l1", 10.0)
	var ids: Array = ScheduleManager.get_save_data()["completed_ids"]
	assert_eq(ids.size(), ScheduleManager.COMPLETED_ID_HISTORY)
	assert_eq(ids[-1], "old:%d" % (ScheduleManager.COMPLETED_ID_HISTORY + 19), "keeps the newest")


func test_no_schedule_key_in_a_fresh_save() -> void:
	SaveManager.save_game()
	assert_false(_read_json(SaveManager.SAVE_PATH).has("schedule"), "omitted, never written empty")


func test_a_running_job_is_written_to_the_save() -> void:
	ScheduleManager.start_job("build", "port_royal", "farm_l1", 60.0)
	SaveManager.save_game()
	var saved := _read_json(SaveManager.SAVE_PATH)
	assert_true(saved.has("schedule"))
	assert_eq(saved["schedule"]["jobs"].size(), 1)


func test_load_game_clears_stale_jobs_when_the_save_has_none() -> void:
	# The omitted-section hazard: a save with no "schedule" must not leave an
	# earlier session's jobs alive in the autoload.
	SaveManager.save_game()
	ScheduleManager.start_job("build", "port_royal", "farm_l1", 60.0)
	SaveManager.load_game()
	assert_eq(ScheduleManager.get_all_jobs().size(), 0)


func test_finish_now_is_priced_from_remaining_and_completes() -> void:
	var id := ScheduleManager.start_job("build", "x", "farm_l1", 600.0)
	var cost := ScheduleManager.finish_cost_eights(id)
	assert_eq(cost, ceili(600.0 / ScheduleManager.pricing.seconds_per_eight))
	ResourceManager.current_resources[ResourceManager.PREMIUM_CURRENCY] = cost
	assert_true(ScheduleManager.finish_now(id))
	assert_eq(ResourceManager.get_resource(ResourceManager.PREMIUM_CURRENCY), 0)
	assert_eq(_completed.size(), 1)
	assert_false(ScheduleManager.finish_now(id), "already complete")

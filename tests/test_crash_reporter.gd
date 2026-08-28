extends GutTest

## M12 Task 2 — protects the crash marker contract without requiring a real crash.

func test_clean_shutdown_removes_the_session_marker():
	CrashReporter._write_session_marker()
	assert_true(FileAccess.file_exists(CrashReporter.SESSION_MARKER_PATH))
	CrashReporter.mark_clean_shutdown()
	assert_false(FileAccess.file_exists(CrashReporter.SESSION_MARKER_PATH))
	CrashReporter._write_session_marker()


func test_abnormal_exit_report_is_non_identifying_metadata():
	CrashReporter._create_abnormal_exit_report()
	var file := FileAccess.open(CrashReporter.LATEST_REPORT_PATH, FileAccess.READ)
	assert_not_null(file)
	var json := JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK)
	file.close()
	assert_eq(json.data.get("report_version"), 1)
	assert_true(json.data.has("reason"))
	assert_false(json.data.has("player_id"))

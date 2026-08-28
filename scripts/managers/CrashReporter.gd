extends Node

## Purpose: Detects an abnormal prior exit and preserves a minimal local crash-report bundle.
## Responsibilities: Maintains a clean-session marker, writes a bounded report on the next launch,
## and exposes report availability to UI without interrupting normal play.
## Dependencies: FileAccess and DirAccess only; deliberately no network dependency.
## Limitations: No remote support endpoint is configured, so reports remain local and opt-in-ready.
## TODOs: Add consented delivery only with a privacy notice and maintainer-owned endpoint.

signal crash_report_available(report_path: String)

const REPORT_DIR := "user://crash_reports"
const SESSION_MARKER_PATH := REPORT_DIR + "/session_active.marker"
const LATEST_REPORT_PATH := REPORT_DIR + "/latest_report.json"

var has_pending_report := false


func _ready() -> void:
	_ensure_directory()
	if FileAccess.file_exists(SESSION_MARKER_PATH):
		_create_abnormal_exit_report()
	_write_session_marker()


func _exit_tree() -> void:
	mark_clean_shutdown()


func mark_clean_shutdown() -> void:
	if FileAccess.file_exists(SESSION_MARKER_PATH):
		var dir := DirAccess.open(REPORT_DIR)
		if dir:
			dir.remove(SESSION_MARKER_PATH.get_file())


func get_report_path() -> String:
	return LATEST_REPORT_PATH if has_pending_report else ""


func dismiss_pending_report() -> void:
	## Dismissing the notice never deletes evidence; it only prevents a repeated
	## prompt during this run. A player may still retrieve the local file later.
	has_pending_report = false


func _create_abnormal_exit_report() -> void:
	var report := {
		"report_version": 1,
		"detected_unix": int(Time.get_unix_time_from_system()),
		"reason": "previous_session_did_not_mark_clean_shutdown",
		"engine": Engine.get_version_info().get("string", "unknown"),
	}
	var file := FileAccess.open(LATEST_REPORT_PATH, FileAccess.WRITE)
	if not file:
		push_error("CrashReporter: could not write local crash report.")
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	has_pending_report = true
	call_deferred("_emit_report_available")


func _emit_report_available() -> void:
	if has_pending_report:
		crash_report_available.emit(LATEST_REPORT_PATH)


func _write_session_marker() -> void:
	var file := FileAccess.open(SESSION_MARKER_PATH, FileAccess.WRITE)
	if file:
		file.store_string(str(Time.get_unix_time_from_system()))
		file.close()
	else:
		push_error("CrashReporter: could not create session marker.")


func _ensure_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))

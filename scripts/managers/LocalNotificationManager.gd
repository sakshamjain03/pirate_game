extends Node

## Purpose: Safely bridges gameplay completion notices to an optional Android local-notification plugin.
## Responsibilities: Owns permission state, formats notification text once, and never lets a missing
## plugin or denied permission affect gameplay.
## Dependencies: EmpireManager. Optional engine singleton: PirateLocalNotifications.
## Limitations: No Android plugin is bundled in M12; desktop and unconfigured exports are no-ops.
## TODOs: Enable the plugin in the Android export and validate permission states on hardware.

const PLUGIN_SINGLETON := "PirateLocalNotifications"
const SETTINGS_PATH := "user://notification_permission_state.json"

var _permission_requested := false


func _ready() -> void:
	_permission_requested = _read_permission_requested()
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	if EmpireManager and not EmpireManager.raid_resolved.is_connected(_on_raid_resolved):
		EmpireManager.raid_resolved.connect(_on_raid_resolved)


func _on_raid_resolved(report: Dictionary) -> void:
	## Raid resolution is the only real completion event in the current data
	## model. Construction is instant and fleet missions recur, so scheduling
	## either as a fake delayed completion would violate the no-waiting rule.
	schedule_completion("raid_resolved", tr("Empire report"), get_raid_notification_body(report))


func get_raid_notification_body(report: Dictionary) -> String:
	## Delegates to EmpireManager's shared composer rather than authoring its own
	## wording — this and RaidReportScreen's full report used to describe the same
	## outcome in two independently-drifting sentences (M12 Task 11).
	return EmpireManager.describe_raid_outcome(report)


func schedule_completion(event_id: String, title: String, body: String, delay_seconds: int = 0) -> bool:
	if not _ensure_permission_or_plugin():
		return false
	var plugin = Engine.get_singleton(PLUGIN_SINGLETON)
	if not plugin or not plugin.has_method("schedule"):
		return false
	plugin.schedule(event_id, title, body, max(0, delay_seconds))
	return true


func _ensure_permission_or_plugin() -> bool:
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		return false
	var plugin = Engine.get_singleton(PLUGIN_SINGLETON)
	if plugin.has_method("has_permission") and plugin.has_permission():
		return true
	if not _permission_requested and plugin.has_method("request_permission"):
		_permission_requested = true
		_write_permission_requested()
		plugin.request_permission()
	return plugin.has_method("has_permission") and plugin.has_permission()


func _read_permission_requested() -> bool:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return false
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	return error == OK and json.data is Dictionary and bool(json.data.get("requested", false))


func _write_permission_requested() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"requested": true}))
		file.close()

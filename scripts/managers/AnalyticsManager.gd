extends Node

## Purpose: Records privacy-preserving local funnel telemetry for playtest analysis.
## Responsibilities: Writes an append-only, rotated JSON-lines event log and connects it to
## existing campaign/empire signals. It does not identify players or transmit data.
## Dependencies: CampaignManager and EmpireManager autoload signals; optional EncounterManager
## through on_world_ready().
## Limitations: The current M12 fallback is local-only until an approved analytics plugin/backend
## forwards this public contract. Logs must be collected from a playtest build by the maintainer.
## TODOs: Add a consented Firebase adapter only after an Android plugin and privacy notice exist.

signal event_logged(event_name: String, params: Dictionary)

const TELEMETRY_DIR := "user://telemetry"
const LOG_PATH := TELEMETRY_DIR + "/funnel.jsonl"
const PREVIOUS_LOG_PATH := TELEMETRY_DIR + "/funnel.previous.jsonl"
const FIRST_EVENTS_PATH := TELEMETRY_DIR + "/first_events.json"
const MAX_LOG_BYTES := 256 * 1024

var _session_started_unix := 0
var _first_events: Dictionary = {}
var _active_encounter_is_boss := false


func _ready() -> void:

	_ensure_directory()
	_first_events = _read_json_dictionary(FIRST_EVENTS_PATH)
	_session_started_unix = int(Time.get_unix_time_from_system())
	call_deferred("_connect_signals")
	log_event("session_started")


func _exit_tree() -> void:
	if _session_started_unix > 0:
		log_event("session_ended", {"duration_seconds": max(0, int(Time.get_unix_time_from_system()) - _session_started_unix)})


func _connect_signals() -> void:
	if CampaignManager:
		_connect_once(CampaignManager.chapter_started, _on_chapter_started)
		_connect_once(CampaignManager.chapter_completed, _on_chapter_completed)
	if EmpireManager:
		_connect_once(EmpireManager.island_captured, _on_island_captured)
		_connect_once(EmpireManager.raid_resolved, _on_raid_resolved)


func on_world_ready(world: Node) -> void:
	## Scene-local systems do not exist when this autoload starts. World.gd calls this
	## after its Systems subtree is available, paralleling CampaignManager's pattern.
	if not world:
		return
	var systems := world.get_node_or_null("Systems")
	var encounters := systems.get_node_or_null("EncounterManager") if systems else null
	if encounters and encounters.has_signal("encounter_started"):
		_connect_once(encounters.encounter_started, _on_encounter_started)
	if encounters and encounters.has_signal("encounter_ended"):
		_connect_once(encounters.encounter_ended, _on_encounter_ended)


func log_event(event_name: String, params: Dictionary = {}) -> void:
	## All callers use this single narrow boundary so replacing the local fallback
	## with a consented backend later cannot spread SDK references through gameplay.
	if event_name.is_empty():
		push_error("AnalyticsManager: event_name must not be empty.")
		return
	var event := {
		"event": event_name,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"params": _sanitize_params(params),
	}
	_append_event(event)
	event_logged.emit(event_name, event["params"])


func log_first_event(event_name: String, params: Dictionary = {}) -> void:
	if _first_events.has(event_name):
		return
	_first_events[event_name] = true
	_write_json_dictionary(FIRST_EVENTS_PATH, _first_events)
	log_event(event_name, params)


func _on_chapter_started(chapter: ChapterData) -> void:
	if chapter:
		log_event("chapter_started", {"chapter_id": chapter.chapter_id, "chapter_number": chapter.chapter_number})


func _on_chapter_completed(chapter: ChapterData) -> void:
	if chapter:
		log_event("chapter_completed", {"chapter_id": chapter.chapter_id, "chapter_number": chapter.chapter_number})


func _on_island_captured(island_id: String) -> void:
	log_event("island_captured", {"island_id": island_id})
	log_first_event("first_colonize", {"island_id": island_id})


func _on_raid_resolved(report: Dictionary) -> void:
	var repelled := bool(report.get("repelled", false))
	log_event("raid_resolved", {"repelled": repelled, "faction_id": str(report.get("faction_id", "unknown"))})
	log_first_event("first_raid_survived" if repelled else "first_raid_lost")


func _on_encounter_started(data: EncounterData) -> void:
	_active_encounter_is_boss = data != null and data.kind == EncounterData.Kind.BOSS


func _on_encounter_ended(victory: bool, rewards: Dictionary) -> void:
	## Encounter rewards are intentionally summarized only by their keys; economy
	## values stay in authored data and individual playthrough balances stay private.
	log_event("encounter_ended", {"victory": victory, "reward_types": rewards.keys().size()})
	if victory and _active_encounter_is_boss:
		log_first_event("first_boss_defeat")
	_active_encounter_is_boss = false


func _sanitize_params(params: Dictionary) -> Dictionary:
	var clean := {}
	for key in params:
		var value = params[key]
		if value is String or value is int or value is float or value is bool:
			clean[str(key)] = value
		else:
			push_warning("AnalyticsManager: ignored non-primitive parameter '%s'." % str(key))
	return clean


func _append_event(event: Dictionary) -> void:
	_ensure_directory()
	if FileAccess.file_exists(LOG_PATH) and FileAccess.get_file_as_bytes(LOG_PATH).size() >= MAX_LOG_BYTES:
		var dir := DirAccess.open(TELEMETRY_DIR)
		if dir:
			dir.remove(PREVIOUS_LOG_PATH.get_file())
			dir.rename(LOG_PATH.get_file(), PREVIOUS_LOG_PATH.get_file())
	var appending := FileAccess.file_exists(LOG_PATH)
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if appending else FileAccess.WRITE)
	if not file:
		push_error("AnalyticsManager: could not open local funnel log.")
		return
	if appending:
		file.seek_end()
	file.store_string(JSON.stringify(event) + "\n")
	file.close()


func _ensure_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TELEMETRY_DIR))


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	return json.data.duplicate() if error == OK and json.data is Dictionary else {}


func _write_json_dictionary(path: String, data: Dictionary) -> void:
	_ensure_directory()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _connect_once(source_signal: Signal, callback: Callable) -> void:
	if not source_signal.is_connected(callback):
		source_signal.connect(callback)

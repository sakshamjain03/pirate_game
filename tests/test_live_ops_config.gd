extends GutTest

# test_live_ops_config.gd
# M14 Requirement 6 — LiveOpsConfig, the entire integration surface with
# M15's RemoteConfigManager. Mirrors test_remote_config_manager.gd's
# backup/restore-the-cache-directly seam (LiveOpsConfig itself makes no
# network calls of its own; RemoteConfigManager._cache is the only thing
# that varies between "a remote value is set" and "it isn't").

var _saved_cache: Dictionary
var _saved_events: Array


func before_each():
	_saved_cache = RemoteConfigManager._cache
	_saved_events = SeasonalEventManager._events.duplicate()
	RemoteConfigManager._cache = {}


func after_each():
	RemoteConfigManager._cache = _saved_cache
	SeasonalEventManager._events = _saved_events.duplicate()


func _event(id: String, start := "03-01", end := "05-31") -> SeasonalEventData:
	var e := SeasonalEventData.new()
	e.event_id = id
	e.fallback_window_start_month_day = start
	e.fallback_window_end_month_day = end
	return e


# === get_seasonal_window() ===

func test_falls_back_to_the_authored_local_window_when_no_remote_key_is_set():
	SeasonalEventManager._events = [_event("spring_crossing", "03-01", "05-31")]

	var window := LiveOpsConfig.get_seasonal_window("spring_crossing")

	assert_eq(window, {"start": "03-01", "end": "05-31"})


func test_a_real_remote_value_wins_over_the_authored_fallback():
	SeasonalEventManager._events = [_event("spring_crossing", "03-01", "05-31")]
	RemoteConfigManager._cache["seasonal_window_spring_crossing"] = {"start": "04-01", "end": "06-30"}

	var window := LiveOpsConfig.get_seasonal_window("spring_crossing")

	assert_eq(window, {"start": "04-01", "end": "06-30"})


func test_removing_the_remote_key_falls_back_to_the_local_window_again():
	## Requirement 6.3 — the degradation must be real, not just described.
	SeasonalEventManager._events = [_event("spring_crossing", "03-01", "05-31")]
	RemoteConfigManager._cache["seasonal_window_spring_crossing"] = {"start": "04-01", "end": "06-30"}
	assert_eq(LiveOpsConfig.get_seasonal_window("spring_crossing"), {"start": "04-01", "end": "06-30"})

	RemoteConfigManager._cache.erase("seasonal_window_spring_crossing")

	assert_eq(LiveOpsConfig.get_seasonal_window("spring_crossing"), {"start": "03-01", "end": "05-31"},
		"removing the remote key must fall back to the authored local window correctly")


func test_a_malformed_remote_value_falls_back_rather_than_crashing():
	SeasonalEventManager._events = [_event("spring_crossing", "03-01", "05-31")]
	RemoteConfigManager._cache["seasonal_window_spring_crossing"] = "not_a_dictionary"

	var window := LiveOpsConfig.get_seasonal_window("spring_crossing")

	assert_eq(window, {"start": "03-01", "end": "05-31"})


func test_an_unknown_event_id_with_no_remote_key_returns_an_empty_dictionary():
	SeasonalEventManager._events = []
	assert_eq(LiveOpsConfig.get_seasonal_window("nonexistent"), {})


# === is_content_enabled() ===

func test_is_content_enabled_defaults_true_when_no_kill_switch_key_is_set():
	assert_true(LiveOpsConfig.is_content_enabled("any_content_id"))


func test_a_real_kill_switch_can_disable_content():
	RemoteConfigManager._cache["kill_switch_ghost_fleet_flagship_boss"] = false
	assert_false(LiveOpsConfig.is_content_enabled("ghost_fleet_flagship_boss"))


func test_removing_the_kill_switch_key_re_enables_content():
	RemoteConfigManager._cache["kill_switch_ghost_fleet_flagship_boss"] = false
	assert_false(LiveOpsConfig.is_content_enabled("ghost_fleet_flagship_boss"))

	RemoteConfigManager._cache.erase("kill_switch_ghost_fleet_flagship_boss")

	assert_true(LiveOpsConfig.is_content_enabled("ghost_fleet_flagship_boss"))


# === SeasonalEventManager.is_active() actually routes through LiveOpsConfig ===

func test_seasonal_event_manager_is_active_respects_the_remote_window():
	var saved_override := SeasonalEventManager._date_override
	SeasonalEventManager._events = [_event("spring_crossing", "03-01", "05-31")]
	SeasonalEventManager._date_override = "2027-04-15"
	RemoteConfigManager._cache["seasonal_window_spring_crossing"] = {"start": "07-01", "end": "08-31"}

	assert_false(SeasonalEventManager.is_active("spring_crossing"),
		"the remote window (July-August) must override the authored fallback (March-May)")

	SeasonalEventManager._date_override = saved_override


func test_seasonal_event_manager_is_active_respects_the_kill_switch():
	var saved_override := SeasonalEventManager._date_override
	SeasonalEventManager._events = [_event("spring_crossing", "03-01", "05-31")]
	SeasonalEventManager._date_override = "2027-04-15"
	RemoteConfigManager._cache["kill_switch_spring_crossing"] = false

	assert_false(SeasonalEventManager.is_active("spring_crossing"),
		"a disabled kill-switch must suppress the event even inside its normal window")

	SeasonalEventManager._date_override = saved_override


# === EncounterManager honors the kill-switch too (Requirement 6.1) ===

func test_encounter_manager_excludes_a_killed_encounter_from_the_ambient_pool():
	var mgr := EncounterManager.new()
	add_child_autofree(mgr)
	mgr.ambient_enabled = true

	var e := EncounterData.new()
	e.encounter_id = "test_killed_encounter"
	e.enemy_scene = load("res://scenes/world/EnemyShip.tscn")
	mgr.encounter_pool = [e]
	RemoteConfigManager._cache["kill_switch_test_killed_encounter"] = false

	mgr._ambient_timer = mgr.ambient_interval
	mgr._start_random_ambient()

	assert_false(mgr.is_active(), "a killed encounter must never be picked as an ambient candidate")

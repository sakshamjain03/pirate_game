extends GutTest

# test_seasonal_event_content.gd
# M14 Wave 1/2 — the seasonal-event equivalent of test_campaign_content.gd's
# objective-integrity checks: every real resources/campaign/seasonal_events/
# *.tres loads, every objective_id is unique, and every target_id resolves
# against the real faction/island/resource registry rather than a typo'd
# guess (D3/D14's silent-failure trap).

const EVENTS_DIR := "res://resources/campaign/seasonal_events/"

var _island_ids: Array[String] = []
var _faction_ids: Array[String] = []
var _ship_ids: Array[String] = []


func before_each():
	_island_ids = _collect_ids("res://resources/world/", "island_id")
	_faction_ids = _collect_ids("res://resources/factions/", "faction_id")
	_ship_ids = _collect_ids("res://resources/ships/", "ship_id")
	_ship_ids.append_array(_collect_ids("res://resources/enemies/", "ship_id"))


func _collect_ids(dir_path: String, id_field: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(dir_path + file_name)
			if res and res.get(id_field) != null:
				var id: String = str(res.get(id_field))
				if not id.is_empty():
					out.append(id)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


func _load_all_events() -> Array[SeasonalEventData]:
	var out: Array[SeasonalEventData] = []
	var dir := DirAccess.open(EVENTS_DIR)
	assert_not_null(dir, "resources/campaign/seasonal_events/ must exist")
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var event := load(EVENTS_DIR + file_name) as SeasonalEventData
			if event:
				out.append(event)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


func test_at_least_one_real_seasonal_event_exists_and_loads():
	var events := _load_all_events()
	assert_gt(events.size(), 0, "The Spring Crossing (Ch8) must be authored as a real SeasonalEventData")


func test_every_event_id_is_unique():
	var events := _load_all_events()
	var seen: Array[String] = []
	for e in events:
		assert_false(seen.has(e.event_id), "Duplicate event_id: %s" % e.event_id)
		seen.append(e.event_id)


func test_every_event_has_a_valid_non_wrapping_or_wrapping_window():
	for e in _load_all_events():
		assert_eq(e.fallback_window_start_month_day.length(), 5,
			"%s: fallback_window_start_month_day must be 'MM-DD'" % e.event_id)
		assert_eq(e.fallback_window_end_month_day.length(), 5,
			"%s: fallback_window_end_month_day must be 'MM-DD'" % e.event_id)


func test_every_objective_id_is_globally_unique():
	var events := _load_all_events()
	var seen: Array[String] = []
	for e in events:
		for o in e.objectives:
			assert_false(seen.has(o.objective_id),
				"Duplicate objective_id '%s' (event %s)" % [o.objective_id, e.event_id])
			seen.append(o.objective_id)


func test_every_objective_target_id_resolves_against_the_real_registry():
	var events := _load_all_events()
	var checked := 0
	for e in events:
		for o in e.objectives:
			if o.target_id.is_empty():
				continue
			var registry: Array[String] = []
			var label := ""
			match o.condition:
				ObjectiveData.Condition.REACH_ISLAND_TIER, ObjectiveData.Condition.CAPTURE_ISLAND, \
						ObjectiveData.Condition.DISCOVER_ISLAND, ObjectiveData.Condition.DOCK_AT_ISLAND:
					registry = _island_ids
					label = "island"
				ObjectiveData.Condition.DESTROY_SHIPS:
					registry = _faction_ids
					label = "faction"
				ObjectiveData.Condition.BOARD_SHIPS:
					registry = _faction_ids + _ship_ids
					label = "faction or ship"
				ObjectiveData.Condition.DEFEAT_BOSS:
					registry = _ship_ids
					label = "ship"
				ObjectiveData.Condition.ACCUMULATE_RESOURCE:
					registry = ["gold", "wood", "iron", "rum", "research"]
					label = "resource key"
				_:
					continue
			checked += 1
			assert_true(registry.has(o.target_id),
				"%s.%s: target_id '%s' does not resolve as a real %s"
				% [e.event_id, o.objective_id, o.target_id, label])
	assert_gt(checked, 0, "Precondition: at least one target_id-bearing objective must exist")


func test_reward_references_resolve_or_are_empty():
	var captain_ids := _collect_ids("res://resources/captains/", "captain_id")
	var tech_ids := _collect_ids("res://resources/techs/", "tech_id")
	for e in _load_all_events():
		if not e.reward_captain_id.is_empty():
			assert_true(captain_ids.has(e.reward_captain_id),
				"%s.reward_captain_id '%s' does not name a real captain" % [e.event_id, e.reward_captain_id])
		if not e.reward_ship_id.is_empty():
			assert_true(_ship_ids.has(e.reward_ship_id),
				"%s.reward_ship_id '%s' does not name a real ship" % [e.event_id, e.reward_ship_id])
		if not e.reward_tech_id.is_empty():
			assert_true(tech_ids.has(e.reward_tech_id),
				"%s.reward_tech_id '%s' does not name a real tech" % [e.event_id, e.reward_tech_id])

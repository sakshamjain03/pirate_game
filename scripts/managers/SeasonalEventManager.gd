extends Node

## Purpose: M14 Requirement 3 — repeatable seasonal events (the Spring
## Crossing). Tracks "currently active" (date-window) and "completed this
## window" / "ever completed" per event id, instead of ChapterData's
## permanent one-way completion flag — see SeasonalEventData's own header for
## why this is a separate resource rather than a retrofit.
## Responsibilities: load resources/campaign/seasonal_events/*.tres, evaluate
## each event's active window, dispatch real gameplay signals against active
## events' objectives (reusing ObjectiveDispatch's arithmetic — the same
## engine CampaignManager's dispatch uses), grant rewards on completion, and
## round-trip completed-window history + in-progress objective state through
## SaveManager.
## Dependencies: EmpireManager, FleetManager, TechManager, ResourceManager
##   (autoloads); WorldManager, IslandMenu, EnemySpawner, EncounterManager,
##   BoardingSystem (scene-local, via on_world_ready(), mirroring
##   CampaignManager's own pattern). Design note: this manager listens to the
##   same gameplay signals CampaignManager does, independently, rather than
##   CampaignManager forwarding into it — CampaignManager's 10 signal handlers
##   are dense, already covered by 60+ passing tests, and 3 of them (boarding/
##   fleet/resources) have bespoke target-matching that doesn't reduce to a
##   single generic tuple without restructuring CampaignManager itself, out of
##   scope for this milestone. The genuinely shared logic (condition/target
##   matching, progress arithmetic) lives in ObjectiveDispatch and is reused
##   by both, so this is "one shared piece of matching logic" without editing
##   CampaignManager's proven handlers.
##
## M14 Requirement 6 — is_active()'s window lookup and kill-switch check both
## route through LiveOpsConfig rather than reading fallback_window_*_month_day
## or nothing at all: the fallback is LiveOpsConfig's local-path answer, not a
## second maintained path here.

signal objective_progressed(event_id: String, objective_id: String, current: int, target: int)
signal objective_completed(event_id: String, objective_id: String)
signal event_completed(event_id: String)

const EVENTS_DIR := "res://resources/campaign/seasonal_events/"

var _events: Array[SeasonalEventData] = []
var _completed_windows: Dictionary = {}              # event_id -> Array[String] window ids
var _event_objective_progress: Dictionary = {}       # event_id -> {objective_id: int}
var _event_completed_objective_ids: Dictionary = {}  # event_id -> Array[String]
var _progress_window_id: Dictionary = {}             # event_id -> window id the above progress belongs to

## Test seam mirroring RemoteConfigManager._request_override — empty means
## "use the real system clock." Format matches
## Time.get_date_string_from_system(): "YYYY-MM-DD".
var _date_override: String = ""


func _ready() -> void:
	_load_events()
	_connect_global_signals()


func _load_events() -> void:
	_events.clear()
	var dir := DirAccess.open(EVENTS_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var event := load(EVENTS_DIR + file_name) as SeasonalEventData
			if event:
				_events.append(event)
		file_name = dir.get_next()
	dir.list_dir_end()


func _connect_global_signals() -> void:
	if EmpireManager:
		EmpireManager.notoriety_changed.connect(_on_notoriety_changed)
		EmpireManager.island_captured.connect(_on_island_captured)
		EmpireManager.island_tier_changed.connect(_on_island_tier_changed)
		EmpireManager.raid_resolved.connect(_on_raid_resolved)
	if FleetManager:
		FleetManager.captain_recruited.connect(_on_captain_recruited)
		FleetManager.fleet_changed.connect(_on_fleet_changed)
	if TechManager:
		TechManager.tech_unlocked.connect(_on_tech_unlocked)
	if ResourceManager:
		ResourceManager.resources_changed.connect(_on_resources_changed)


## Scene-local wiring, called deferred from World.gd exactly like
## CampaignManager.on_world_ready() — these systems don't exist until a World
## scene does, so they can't be connected from this autoload's own _ready().
func on_world_ready(world_manager: Node) -> void:
	if world_manager and world_manager.has_signal("player_docked"):
		if not world_manager.player_docked.is_connected(_on_player_docked):
			world_manager.player_docked.connect(_on_player_docked)

	var island_menu := get_tree().get_first_node_in_group("island_menu")
	if island_menu and island_menu.has_signal("structure_changed"):
		if not island_menu.structure_changed.is_connected(_on_structure_changed):
			island_menu.structure_changed.connect(_on_structure_changed)

	var scene := get_tree().current_scene
	var systems := scene.get_node_or_null("Systems") if scene else null
	if not systems:
		return

	var spawner := systems.get_node_or_null("EnemySpawner")
	if spawner and spawner.has_signal("enemy_destroyed") \
			and not spawner.enemy_destroyed.is_connected(_on_ship_destroyed):
		spawner.enemy_destroyed.connect(_on_ship_destroyed)

	var encounter_mgr := systems.get_node_or_null("EncounterManager")
	if encounter_mgr and encounter_mgr.has_signal("ship_destroyed") \
			and not encounter_mgr.ship_destroyed.is_connected(_on_ship_destroyed):
		encounter_mgr.ship_destroyed.connect(_on_ship_destroyed)

	var boarding := systems.get_node_or_null("BoardingSystem")
	if boarding and boarding.has_signal("boarding_resolved") \
			and not boarding.boarding_resolved.is_connected(_on_boarding_resolved):
		boarding.boarding_resolved.connect(_on_boarding_resolved)


# === Public API (design.md) ===

func get_event_data(event_id: String) -> SeasonalEventData:
	for event in _events:
		if event.event_id == event_id:
			return event
	return null


func is_active(event_id: String) -> bool:
	if not get_event_data(event_id):
		return false
	if not LiveOpsConfig.is_content_enabled(event_id):
		return false
	var window: Dictionary = LiveOpsConfig.get_seasonal_window(event_id)
	if window.is_empty():
		return false
	return _month_day_in_window(_current_month_day(), window.get("start", ""), window.get("end", ""))


func is_completed_this_window(event_id: String) -> bool:
	var window_id := _window_identifier(event_id)
	if window_id.is_empty():
		return false
	return _completed_windows.get(event_id, []).has(window_id)


func has_ever_completed(event_id: String) -> bool:
	return _completed_windows.get(event_id, []).size() > 0


func mark_completed(event_id: String) -> void:
	var window_id := _window_identifier(event_id)
	if window_id.is_empty():
		return
	if not _completed_windows.has(event_id):
		_completed_windows[event_id] = []
	if not _completed_windows[event_id].has(window_id):
		_completed_windows[event_id].append(window_id)


# === Date handling (the fake-clock test seam Task 4 establishes — no such
# pattern existed anywhere in this project's tests before) ===

func _current_date_string() -> String:
	return _date_override if not _date_override.is_empty() else Time.get_date_string_from_system()


func _current_month_day() -> String:
	return _current_date_string().substr(5, 5)   # "YYYY-MM-DD" -> "MM-DD"


func _current_year() -> int:
	return int(_current_date_string().substr(0, 4))


## Window ids distinguish repeat completions across different years
## ("spring_crossing_2027" vs "spring_crossing_2028") — append-only history,
## per design.md, never overwritten.
func _window_identifier(event_id: String) -> String:
	if not is_active(event_id):
		return ""
	return "%s_%d" % [event_id, _current_year()]


## "MM-DD" comparison, with wraparound support for a window crossing a year
## boundary (e.g. a hypothetical winter event authored "12-01".."01-31") even
## though the Spring Crossing itself doesn't need it — a window schema that
## only worked for non-wrapping ranges would silently misbehave the first
## time a future event needs one, the same class of silent gap D3/D14 already
## burned this project on once.
func _month_day_in_window(current: String, start: String, end: String) -> bool:
	if start.is_empty() or end.is_empty():
		return false
	if start <= end:
		return current >= start and current <= end
	return current >= start or current <= end


# === Objective dispatch — mirrors CampaignManager's shape, per active event ===

func _for_each_active_event(body: Callable) -> void:
	for event in _events:
		if is_active(event.event_id):
			_ensure_current_window(event)
			body.call(event)


## A save/load or a real-time window rollover must not let progress recorded
## against a past, different window silently count toward a new one (e.g.
## half-finished in April, reopened the following April — a real scenario for
## a repeatable event, unlike a permanent chapter which never needs this).
func _ensure_current_window(event: SeasonalEventData) -> void:
	var event_id := event.event_id
	var current_window := _window_identifier(event_id)
	if _progress_window_id.get(event_id, "") == current_window:
		return
	_progress_window_id[event_id] = current_window
	_event_objective_progress[event_id] = {}
	_event_completed_objective_ids[event_id] = []


func _dispatch(condition: int, target_id: String, body: Callable) -> void:
	_for_each_active_event(func(event: SeasonalEventData):
		for objective in event.objectives:
			if not ObjectiveDispatch.matches(objective, condition, target_id):
				continue
			body.call(event, objective))


func _advance_objective(event: SeasonalEventData, objective: ObjectiveData, amount: int) -> void:
	var event_id := event.event_id
	var completed: Array = _event_completed_objective_ids[event_id]
	if completed.has(objective.objective_id):
		return
	var progress: Dictionary = _event_objective_progress[event_id]
	var current := ObjectiveDispatch.advance_count(progress, completed, objective, amount)
	objective_progressed.emit(event_id, objective.objective_id, current, objective.target_count)
	if completed.has(objective.objective_id):
		objective_completed.emit(event_id, objective.objective_id)
	_check_event_complete(event)


func _advance_level(event: SeasonalEventData, objective: ObjectiveData, value: float) -> void:
	var event_id := event.event_id
	var completed: Array = _event_completed_objective_ids[event_id]
	if completed.has(objective.objective_id):
		return
	var threshold: float = float(objective.target_count) \
		if objective.condition == ObjectiveData.Condition.REACH_ISLAND_TIER \
		else objective.target_value
	var progress: Dictionary = _event_objective_progress[event_id]
	var current := ObjectiveDispatch.advance_level(progress, completed, objective, value)
	objective_progressed.emit(event_id, objective.objective_id, current, int(threshold))
	if completed.has(objective.objective_id):
		objective_completed.emit(event_id, objective.objective_id)
	_check_event_complete(event)


func _check_event_complete(event: SeasonalEventData) -> void:
	if is_completed_this_window(event.event_id):
		return
	var completed: Array = _event_completed_objective_ids.get(event.event_id, [])
	for objective in event.objectives:
		if objective.is_optional:
			continue
		if not completed.has(objective.objective_id):
			return
	_complete_event(event)


func _complete_event(event: SeasonalEventData) -> void:
	mark_completed(event.event_id)
	_grant_rewards(event)
	_event_objective_progress[event.event_id] = {}
	_event_completed_objective_ids[event.event_id] = []
	event_completed.emit(event.event_id)


func _grant_rewards(event: SeasonalEventData) -> void:
	## Repeat completions grant the same reward as first completion —
	## design.md Requirement 3.4's explicit, deliberate resolution.
	if event.reward_gold > 0 and ResourceManager:
		ResourceManager.add_resource("gold", event.reward_gold)
	if not event.reward_captain_id.is_empty():
		var cap := ResourceLookup.find_by_id("res://resources/captains/", "captain_id", event.reward_captain_id)
		if cap and FleetManager.has_method("add_captain"):
			FleetManager.add_captain(cap)
	if not event.reward_ship_id.is_empty():
		var ship := ResourceLookup.find_by_id("res://resources/ships/", "ship_id", event.reward_ship_id)
		if ship and FleetManager.has_method("add_ship"):
			FleetManager.add_ship(ship)
	if not event.reward_tech_id.is_empty():
		var tech := ResourceLookup.find_by_id("res://resources/techs/", "tech_id", event.reward_tech_id)
		if tech and TechManager.has_method("unlock_tech"):
			TechManager.unlock_tech(tech)


# === Condition handlers — one per real signal, mirroring CampaignManager ===

func _on_player_docked(island_id: String) -> void:
	_dispatch(ObjectiveData.Condition.DOCK_AT_ISLAND, island_id,
		func(e, o): _advance_objective(e, o, 1))


func _on_structure_changed(building_id: String, is_upgrade: bool) -> void:
	var condition := ObjectiveData.Condition.UPGRADE_STRUCTURE_TO_LEVEL if is_upgrade \
		else ObjectiveData.Condition.BUILD_STRUCTURE
	_dispatch(condition, building_id, func(e, o): _advance_objective(e, o, 1))


func _on_ship_destroyed(ship: Node3D) -> void:
	if not is_instance_valid(ship):
		return
	var faction_id := ""
	if "faction" in ship and ship.get("faction"):
		faction_id = str(ship.get("faction").get("faction_id"))
	var ship_id := ""
	if "ship_stats" in ship and ship.ship_stats:
		ship_id = ship.ship_stats.ship_id

	_dispatch(ObjectiveData.Condition.DESTROY_SHIPS, faction_id, func(e, o): _advance_objective(e, o, 1))
	if not ship_id.is_empty():
		_dispatch(ObjectiveData.Condition.DEFEAT_BOSS, ship_id, func(e, o): _advance_objective(e, o, 1))


func _on_boarding_resolved(success: bool, _loot: Dictionary, target_faction_id: String = "",
		target_ship_id: String = "") -> void:
	if not success:
		return
	_for_each_active_event(func(event: SeasonalEventData):
		for objective in event.objectives:
			if not ObjectiveDispatch.matches_any(objective, ObjectiveData.Condition.BOARD_SHIPS,
					target_faction_id, target_ship_id):
				continue
			_advance_objective(event, objective, 1))


func _on_captain_recruited(_captain: CaptainData) -> void:
	_dispatch(ObjectiveData.Condition.RECRUIT_CAPTAIN, "", func(e, o): _advance_objective(e, o, 1))


func _on_fleet_changed() -> void:
	## OWN_SHIP_CLASS is recomputed from the best hull currently owned rather
	## than incremented — mirrors CampaignManager._on_fleet_changed() exactly.
	var max_class := 0
	for owned in FleetManager.owned_ships:
		if owned and owned.ship_stats and owned.ship_stats.ship_class > max_class:
			max_class = owned.ship_stats.ship_class

	_for_each_active_event(func(event: SeasonalEventData):
		var event_id := event.event_id
		for objective in event.objectives:
			if objective.condition != ObjectiveData.Condition.OWN_SHIP_CLASS:
				continue
			var completed: Array = _event_completed_objective_ids[event_id]
			if completed.has(objective.objective_id):
				continue
			var owns_one := 1 if max_class >= int(objective.target_value) else 0
			_event_objective_progress[event_id][objective.objective_id] = owns_one
			objective_progressed.emit(event_id, objective.objective_id, owns_one, 1)
			if owns_one >= 1:
				completed.append(objective.objective_id)
				objective_completed.emit(event_id, objective.objective_id)
		_check_event_complete(event))


func _on_tech_unlocked(tech: Resource) -> void:
	var tech_id: String = str(tech.get("tech_id")) if tech else ""
	_dispatch(ObjectiveData.Condition.UNLOCK_TECH, tech_id, func(e, o): _advance_objective(e, o, 1))


func _on_island_captured(island_id: String) -> void:
	_dispatch(ObjectiveData.Condition.CAPTURE_ISLAND, island_id, func(e, o): _advance_objective(e, o, 1))


func _on_island_tier_changed(island_id: String, new_tier: int) -> void:
	_dispatch(ObjectiveData.Condition.REACH_ISLAND_TIER, island_id,
		func(e, o): _advance_level(e, o, float(new_tier)))


func _on_notoriety_changed(new_value: float) -> void:
	_dispatch(ObjectiveData.Condition.REACH_NOTORIETY, "", func(e, o): _advance_level(e, o, new_value))


func _on_resources_changed(resources: Dictionary) -> void:
	_for_each_active_event(func(event: SeasonalEventData):
		for objective in event.objectives:
			if objective.condition != ObjectiveData.Condition.ACCUMULATE_RESOURCE:
				continue
			if objective.target_id.is_empty() or not resources.has(objective.target_id):
				continue
			_advance_level(event, objective, float(resources[objective.target_id])))


func _on_raid_resolved(_report: Dictionary) -> void:
	_dispatch(ObjectiveData.Condition.SURVIVE_RAID, "", func(e, o): _advance_objective(e, o, 1))


# === Save/load ===

func get_save_data() -> Dictionary:
	return {
		"completed_windows": _completed_windows.duplicate(true),
		"event_objective_progress": _event_objective_progress.duplicate(true),
		"event_completed_objective_ids": _event_completed_objective_ids.duplicate(true),
		"progress_window_id": _progress_window_id.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	_completed_windows = data["completed_windows"].duplicate(true) \
		if typeof(data.get("completed_windows")) == TYPE_DICTIONARY else {}
	_event_objective_progress = data["event_objective_progress"].duplicate(true) \
		if typeof(data.get("event_objective_progress")) == TYPE_DICTIONARY else {}
	_event_completed_objective_ids = data["event_completed_objective_ids"].duplicate(true) \
		if typeof(data.get("event_completed_objective_ids")) == TYPE_DICTIONARY else {}
	_progress_window_id = data["progress_window_id"].duplicate() \
		if typeof(data.get("progress_window_id")) == TYPE_DICTIONARY else {}

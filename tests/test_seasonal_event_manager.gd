extends GutTest

class MockShip extends Node3D:
	var faction: Resource = null
	var ship_stats: ShipStats = null

## M14 Wave 1 — SeasonalEventManager: window boundaries (using an injected fake
## date, not the real system clock — this project's first such test seam),
## repeat-completion tracking across windows, has_ever_completed(), objective
## dispatch reusing ObjectiveDispatch, and save/load round-trip. Mirrors
## test_campaign_manager.gd's convention: swap in in-memory SeasonalEventData
## rather than depending on real .tres content, save/restore autoload state
## around each test.

var _saved_events: Array
var _saved_completed_windows: Dictionary
var _saved_progress: Dictionary
var _saved_completed_objectives: Dictionary
var _saved_progress_window_id: Dictionary
var _saved_date_override: String
var _saved_resources: Dictionary
var _saved_ships: Array


func before_each():
	_saved_events = SeasonalEventManager._events.duplicate()
	_saved_completed_windows = SeasonalEventManager._completed_windows.duplicate(true)
	_saved_progress = SeasonalEventManager._event_objective_progress.duplicate(true)
	_saved_completed_objectives = SeasonalEventManager._event_completed_objective_ids.duplicate(true)
	_saved_progress_window_id = SeasonalEventManager._progress_window_id.duplicate()
	_saved_date_override = SeasonalEventManager._date_override
	_saved_resources = ResourceManager.current_resources.duplicate()
	_saved_ships = FleetManager.owned_ships.duplicate()

	SeasonalEventManager._completed_windows = {}
	SeasonalEventManager._event_objective_progress = {}
	SeasonalEventManager._event_completed_objective_ids = {}
	SeasonalEventManager._progress_window_id = {}


func after_each():
	SeasonalEventManager._events = _saved_events.duplicate()
	SeasonalEventManager._completed_windows = _saved_completed_windows.duplicate(true)
	SeasonalEventManager._event_objective_progress = _saved_progress.duplicate(true)
	SeasonalEventManager._event_completed_objective_ids = _saved_completed_objectives.duplicate(true)
	SeasonalEventManager._progress_window_id = _saved_progress_window_id.duplicate()
	SeasonalEventManager._date_override = _saved_date_override
	ResourceManager.current_resources = _saved_resources.duplicate()
	FleetManager.owned_ships = _saved_ships.duplicate()


func _objective(id: String, condition: int, target_id: String = "", count: int = 1,
		value: float = 0.0, optional: bool = false) -> ObjectiveData:
	var o := ObjectiveData.new()
	o.objective_id = id
	o.condition = condition
	o.target_id = target_id
	o.target_count = count
	o.target_value = value
	o.is_optional = optional
	return o


func _event(id: String, objectives: Array[ObjectiveData], start := "03-01", end := "05-31",
		gold := 0) -> SeasonalEventData:
	var e := SeasonalEventData.new()
	e.event_id = id
	e.display_name = id
	e.objectives = objectives
	e.fallback_window_start_month_day = start
	e.fallback_window_end_month_day = end
	e.reward_gold = gold
	return e


# === Window boundaries ===

func test_is_active_true_inside_the_window():
	var e := _event("spring", [])
	SeasonalEventManager._events = [e]
	SeasonalEventManager._date_override = "2027-04-15"

	assert_true(SeasonalEventManager.is_active("spring"))


func test_is_active_false_outside_the_window():
	var e := _event("spring", [])
	SeasonalEventManager._events = [e]
	SeasonalEventManager._date_override = "2027-07-01"

	assert_false(SeasonalEventManager.is_active("spring"))


func test_is_active_true_on_the_exact_boundary_dates():
	var e := _event("spring", [], "03-01", "05-31")
	SeasonalEventManager._events = [e]

	SeasonalEventManager._date_override = "2027-03-01"
	assert_true(SeasonalEventManager.is_active("spring"), "start boundary is inclusive")

	SeasonalEventManager._date_override = "2027-05-31"
	assert_true(SeasonalEventManager.is_active("spring"), "end boundary is inclusive")

	SeasonalEventManager._date_override = "2027-02-28"
	assert_false(SeasonalEventManager.is_active("spring"), "the day before start is not active")

	SeasonalEventManager._date_override = "2027-06-01"
	assert_false(SeasonalEventManager.is_active("spring"), "the day after end is not active")


func test_a_wrapping_window_crossing_the_year_boundary_is_supported():
	var e := _event("winter", [], "12-01", "01-31")
	SeasonalEventManager._events = [e]

	SeasonalEventManager._date_override = "2027-12-15"
	assert_true(SeasonalEventManager.is_active("winter"))

	SeasonalEventManager._date_override = "2028-01-15"
	assert_true(SeasonalEventManager.is_active("winter"))

	SeasonalEventManager._date_override = "2028-06-01"
	assert_false(SeasonalEventManager.is_active("winter"))


func test_unknown_event_id_is_never_active():
	SeasonalEventManager._events = []
	assert_false(SeasonalEventManager.is_active("nonexistent"))


# === Completion tracking (per-window, not permanent) ===

func test_has_ever_completed_is_false_before_any_completion():
	assert_false(SeasonalEventManager.has_ever_completed("spring"))


func test_mark_completed_sets_has_ever_completed_and_is_completed_this_window():
	var e := _event("spring", [])
	SeasonalEventManager._events = [e]
	SeasonalEventManager._date_override = "2027-04-01"

	SeasonalEventManager.mark_completed("spring")

	assert_true(SeasonalEventManager.has_ever_completed("spring"))
	assert_true(SeasonalEventManager.is_completed_this_window("spring"))


func test_repeat_completion_across_two_different_windows():
	var e := _event("spring", [])
	SeasonalEventManager._events = [e]

	SeasonalEventManager._date_override = "2027-04-01"
	SeasonalEventManager.mark_completed("spring")
	assert_true(SeasonalEventManager.is_completed_this_window("spring"), "completed in 2027's window")

	SeasonalEventManager._date_override = "2028-04-01"
	assert_false(SeasonalEventManager.is_completed_this_window("spring"),
		"a new year's window has not been completed yet, even though the event was completed before")
	assert_true(SeasonalEventManager.has_ever_completed("spring"),
		"has_ever_completed is a one-way flag across all windows — Ch9's gate reads only this")

	SeasonalEventManager.mark_completed("spring")
	assert_true(SeasonalEventManager.is_completed_this_window("spring"), "now completed in 2028's window too")


# === Objective dispatch (reuses ObjectiveDispatch, same engine CampaignManager uses) ===

func test_destroying_ships_advances_a_destroy_ships_objective_and_completes_the_event():
	var obj := _objective("spring_kills", ObjectiveData.Condition.DESTROY_SHIPS, "spanish_empire", 2)
	var e := _event("spring", [obj], "03-01", "05-31", 500)
	SeasonalEventManager._events = [e]
	SeasonalEventManager._date_override = "2027-04-01"
	watch_signals(SeasonalEventManager)

	var ship := MockShip.new()
	var faction := FactionData.new()
	faction.faction_id = "spanish_empire"
	ship.faction = faction
	add_child_autofree(ship)

	SeasonalEventManager._on_ship_destroyed(ship)
	assert_signal_emitted(SeasonalEventManager, "objective_progressed")
	assert_false(SeasonalEventManager.is_completed_this_window("spring"), "only 1 of 2 kills so far")

	var starting_gold: int = ResourceManager.current_resources.get("gold", 0)
	SeasonalEventManager._on_ship_destroyed(ship)

	assert_true(SeasonalEventManager.is_completed_this_window("spring"))
	assert_signal_emitted(SeasonalEventManager, "event_completed")
	assert_eq(ResourceManager.current_resources.get("gold", 0), starting_gold + 500,
		"reward_gold is granted on completion")


func test_an_objective_for_the_wrong_faction_does_not_progress():
	var obj := _objective("spring_kills", ObjectiveData.Condition.DESTROY_SHIPS, "spanish_empire", 1)
	var e := _event("spring", [obj])
	SeasonalEventManager._events = [e]
	SeasonalEventManager._date_override = "2027-04-01"

	var ship := MockShip.new()
	var faction := FactionData.new()
	faction.faction_id = "pirate_clans"
	ship.faction = faction
	add_child_autofree(ship)

	SeasonalEventManager._on_ship_destroyed(ship)
	assert_false(SeasonalEventManager.is_completed_this_window("spring"))


func test_dispatch_is_a_no_op_outside_the_active_window():
	var obj := _objective("spring_kills", ObjectiveData.Condition.DESTROY_SHIPS, "spanish_empire", 1)
	var e := _event("spring", [obj], "03-01", "05-31")
	SeasonalEventManager._events = [e]
	SeasonalEventManager._date_override = "2027-08-01"   # outside the window

	var ship := MockShip.new()
	var faction := FactionData.new()
	faction.faction_id = "spanish_empire"
	ship.faction = faction
	add_child_autofree(ship)

	SeasonalEventManager._on_ship_destroyed(ship)
	assert_false(SeasonalEventManager.is_completed_this_window("spring"))


func test_completed_objectives_reset_for_a_new_window_rather_than_carrying_over():
	var obj := _objective("spring_kills", ObjectiveData.Condition.DESTROY_SHIPS, "spanish_empire", 2)
	var e := _event("spring", [obj])
	SeasonalEventManager._events = [e]

	SeasonalEventManager._date_override = "2027-04-01"
	var ship := MockShip.new()
	var faction := FactionData.new()
	faction.faction_id = "spanish_empire"
	ship.faction = faction
	add_child_autofree(ship)
	SeasonalEventManager._on_ship_destroyed(ship)   # 1 of 2 — a real but incomplete progress

	# A whole year passes with no further progress; the same event is active again.
	SeasonalEventManager._date_override = "2028-04-01"
	SeasonalEventManager._on_ship_destroyed(ship)   # if last year's progress leaked in, this would be "2 of 2"

	assert_false(SeasonalEventManager.is_completed_this_window("spring"),
		"last year's half-finished progress must not silently count toward this year's window")


# === Save/load ===

func test_save_load_round_trips_completed_windows_and_in_progress_state():
	var obj := _objective("spring_kills", ObjectiveData.Condition.DESTROY_SHIPS, "spanish_empire", 5)
	var e := _event("spring", [obj])
	SeasonalEventManager._events = [e]
	SeasonalEventManager._date_override = "2027-04-01"

	var ship := MockShip.new()
	var faction := FactionData.new()
	faction.faction_id = "spanish_empire"
	ship.faction = faction
	add_child_autofree(ship)
	SeasonalEventManager._on_ship_destroyed(ship)
	SeasonalEventManager.mark_completed("spring")

	var saved := SeasonalEventManager.get_save_data()

	SeasonalEventManager._completed_windows = {}
	SeasonalEventManager._event_objective_progress = {}
	SeasonalEventManager._event_completed_objective_ids = {}
	SeasonalEventManager._progress_window_id = {}

	SeasonalEventManager.load_save_data(saved)

	assert_true(SeasonalEventManager.has_ever_completed("spring"))
	assert_eq(int(SeasonalEventManager._event_objective_progress["spring"]["spring_kills"]), 1)


func test_get_save_data_returns_a_duplicate_not_the_live_dictionary():
	var e := _event("spring", [])
	SeasonalEventManager._events = [e]
	SeasonalEventManager._date_override = "2027-04-01"
	SeasonalEventManager.mark_completed("spring")

	var saved := SeasonalEventManager.get_save_data()
	saved["completed_windows"]["spring"].append("mutated")

	assert_ne(SeasonalEventManager._completed_windows["spring"].size(),
		saved["completed_windows"]["spring"].size(),
		"mutating the returned snapshot must not mutate live state (FleetManager D12 convention)")

extends GutTest
## M30 Wave 0 (0.2): captain level/XP reset to level 1 on every restart — the
## save held only each captain's resource_path while add_xp() mutated the
## CaptainData itself. Also guards the two ways that fix can go wrong: a
## duplicate()d captain stops matching `cap in owned_captains` (the Tavern
## offers an owned captain for hire again), and an unresolvable path must
## survive the next save rather than silently vanish.

const JACK := "res://resources/captains/Jack.tres"

var _saved_fleet: Dictionary
var _jack: CaptainData
var _jack_level: int
var _jack_xp: int


func before_each() -> void:
	_saved_fleet = FleetManager.get_save_data().duplicate(true)
	_jack = load(JACK)
	_jack_level = _jack.level
	_jack_xp = _jack.current_xp


func after_each() -> void:
	FleetManager.load_save_data(_saved_fleet)
	_jack.level = _jack_level
	_jack.current_xp = _jack_xp


func test_level_and_xp_round_trip() -> void:
	FleetManager.load_save_data({"owned_captains": [JACK]})
	_jack.level = 4
	_jack.current_xp = 37
	var saved: Dictionary = FleetManager.get_save_data().duplicate(true)
	# Simulate a restart: the shared resource is back at its authored values.
	_jack.level = 1
	_jack.current_xp = 0
	FleetManager.load_save_data(saved)
	var cap: CaptainData = FleetManager.owned_captains[0]
	assert_eq(cap.level, 4, "captain level lost across save/load")
	assert_eq(cap.current_xp, 37, "captain XP lost across save/load")


func test_loaded_captain_is_still_recognised_as_owned() -> void:
	FleetManager.load_save_data({"owned_captains": [{"path": JACK, "level": 2, "current_xp": 5}]})
	assert_true(load(JACK) in FleetManager.owned_captains,
		"a loaded captain must be the shared resource, or the Tavern re-offers it")


func test_pre_m30_bare_path_loads_at_level_one() -> void:
	_jack.level = 1
	_jack.current_xp = 0
	FleetManager.load_save_data({"owned_captains": [JACK]})
	assert_eq(FleetManager.owned_captains.size(), 1)
	assert_eq(FleetManager.owned_captains[0].level, 1)


func test_unresolvable_captain_is_carried_forward() -> void:
	var ghost := {"path": "res://resources/captains/NoSuchCaptain.tres", "level": 3, "current_xp": 9}
	# push_errors by design (CLAUDE.md: resolvers never skip silently); GUT 9.4
	# has no error tracker, so this pins what the error accompanies.
	FleetManager.load_save_data({"owned_captains": [JACK, ghost]})
	assert_eq(FleetManager.owned_captains.size(), 1)
	var resaved: Array = FleetManager.get_save_data()["owned_captains"]
	var paths: Array = resaved.map(func(e): return e["path"])
	assert_has(paths, ghost["path"], "an unresolvable captain must not be deleted by the next save")

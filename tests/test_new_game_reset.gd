extends GutTest

## New Game after playing in the same session (World -> Main Menu -> New Game)
## used to delete the save file and reset four resources, nothing more. Every
## other manager is an autoload and load_game() skips a section a save doesn't
## have, so the "new" game kept the old chapter progress, fleet, techs, heat and
## running timers. It also dropped the "eights" key, so add_resource() rejected
## chapter-reward Eights as an unknown resource.
## SaveManager.reset_to_new_game() returns each one to its boot snapshot.

const MANAGERS := ["ResourceManager", "FleetManager", "TechManager", "FactionManager",
	"EmpireManager", "CampaignManager", "SeasonalEventManager"]

var _saved: Dictionary = {}
var _saved_jobs: Dictionary = {}
var _saved_completed: Dictionary = {}


func before_each() -> void:
	for m in MANAGERS:
		_saved[m] = get_tree().root.get_node(m).get_save_data().duplicate(true)
	_saved_jobs = ScheduleManager._jobs.duplicate(true)
	_saved_completed = ScheduleManager._completed_ids.duplicate()


func after_each() -> void:
	for m in MANAGERS:
		get_tree().root.get_node(m).load_save_data(_saved[m].duplicate(true))
	ScheduleManager._jobs = _saved_jobs
	ScheduleManager._completed_ids = _saved_completed


func _dirty_every_manager() -> void:
	ResourceManager.current_resources["gold"] = 4321
	ResourceManager.current_resources.erase("eights")
	var owned := OwnedShipData.new()
	owned.ship_stats = load("res://resources/ships/Sloop.tres")
	FleetManager.owned_ships.append(owned)
	FleetManager.owned_ships.append(owned)
	EmpireManager.load_save_data({"notoriety": 250.0})
	CampaignManager.completed_chapter_ids.append("ch1_the_drowned_port")
	CampaignManager._completed_objective_ids.append("1.1")
	ScheduleManager.start_job("build", "port_royal", "farm_l1", 600.0)


func test_the_boot_snapshot_was_captured_for_every_manager() -> void:
	for m in MANAGERS:
		assert_true(SaveManager._fresh_state.has(m), "no boot snapshot for %s" % m)


func test_new_game_returns_every_campaign_manager_to_its_boot_state() -> void:
	_dirty_every_manager()
	SaveManager.reset_to_new_game()
	for m in MANAGERS:
		assert_eq(get_tree().root.get_node(m).get_save_data(), SaveManager._fresh_state[m],
			"%s must match its boot state after New Game" % m)
	assert_eq(ScheduleManager.get_save_data(), {}, "no timer survives into a new game")


func test_new_game_keeps_eights_a_known_resource() -> void:
	_dirty_every_manager()
	SaveManager.reset_to_new_game()
	assert_true(ResourceManager.current_resources.has(ResourceManager.PREMIUM_CURRENCY),
		"the eights key must exist, or chapter-reward Eights are rejected")
	var before := ResourceManager.get_resource(ResourceManager.PREMIUM_CURRENCY)
	ResourceManager.add_resource(ResourceManager.PREMIUM_CURRENCY, 10)
	assert_eq(ResourceManager.get_resource(ResourceManager.PREMIUM_CURRENCY), before + 10)


func test_new_game_starts_with_the_starting_resources() -> void:
	_dirty_every_manager()
	SaveManager.reset_to_new_game()
	assert_eq(ResourceManager.get_resource("gold"), 200)
	assert_eq(ResourceManager.get_resource("wood"), 50)
	assert_eq(ResourceManager.get_resource("iron"), 20)
	assert_eq(ResourceManager.get_resource("rum"), 10)

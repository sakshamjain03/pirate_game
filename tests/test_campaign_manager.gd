extends GutTest

class MockShip extends Node3D:
	var faction: Resource = null
	var ship_stats: ShipStats = null

# test_campaign_manager.gd
# M7 Wave 2 — the campaign spine. CampaignManager is a real autoload; these
# tests drive it directly rather than loading real chapter .tres content
# (Phase 3 authors that), swapping in in-memory ChapterData so gating and
# objective dispatch can be pinned without touching the real campaign files.

var _saved_chapters: Array
var _saved_index: int
var _saved_completed: Array
var _saved_progress: Dictionary
var _saved_completed_objectives: Array
var _saved_notoriety: float
var _saved_region_active: Dictionary
var _saved_home_island_id: String
var _saved_resources: Dictionary
var _saved_ships: Array


func before_each():
	_saved_chapters = CampaignManager.chapters.duplicate()
	_saved_index = CampaignManager.current_chapter_index
	_saved_completed = CampaignManager.completed_chapter_ids.duplicate()
	_saved_progress = CampaignManager._objective_progress.duplicate()
	_saved_completed_objectives = CampaignManager._completed_objective_ids.duplicate()
	_saved_notoriety = EmpireManager.notoriety
	_saved_region_active = EmpireManager._region_active.duplicate()
	_saved_home_island_id = EmpireManager.home_island_id
	_saved_resources = ResourceManager.current_resources.duplicate()
	_saved_ships = FleetManager.owned_ships.duplicate()

	CampaignManager.current_chapter_index = -1
	CampaignManager.completed_chapter_ids.clear()
	CampaignManager._objective_progress.clear()
	CampaignManager._completed_objective_ids.clear()


func after_each():
	CampaignManager.chapters = _saved_chapters.duplicate()
	CampaignManager.current_chapter_index = _saved_index
	CampaignManager.completed_chapter_ids = _saved_completed.duplicate()
	CampaignManager._objective_progress = _saved_progress.duplicate()
	CampaignManager._completed_objective_ids = _saved_completed_objectives.duplicate()
	EmpireManager.notoriety = _saved_notoriety
	EmpireManager._region_active = _saved_region_active.duplicate()
	EmpireManager.home_island_id = _saved_home_island_id
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


func _chapter(id: String, number: int, objectives: Array[ObjectiveData],
		required_previous: String = "", required_region: String = "") -> ChapterData:
	var c := ChapterData.new()
	c.chapter_id = id
	c.chapter_number = number
	c.title = id
	c.objectives = objectives
	c.required_previous_chapter = required_previous
	c.required_region_id = required_region
	return c


# === Chapter loading / gating ===

func test_chapter_with_no_gate_starts_immediately():
	var ch1 := _chapter("ch1", 1, [])
	CampaignManager.chapters = [ch1]
	watch_signals(CampaignManager)

	CampaignManager._catch_up()

	assert_eq(CampaignManager.current_chapter_index, 0)
	assert_signal_emitted(CampaignManager, "chapter_started")


func test_a_region_gated_chapter_does_not_start_until_the_region_activates():
	EmpireManager._region_active["contested_waters"] = false
	var ch1 := _chapter("ch1", 1, [], "", "contested_waters")
	CampaignManager.chapters = [ch1]

	CampaignManager._catch_up()
	assert_eq(CampaignManager.current_chapter_index, -1, "The gate must hold the chapter back")

	EmpireManager._region_active["contested_waters"] = true
	CampaignManager._on_region_activated("contested_waters")
	assert_eq(CampaignManager.current_chapter_index, 0, "...and release it once the region activates")


func test_a_previous_chapter_gate_holds_until_that_chapter_completes():
	var obj := _objective("1.1", ObjectiveData.Condition.RECRUIT_CAPTAIN)
	var ch1 := _chapter("ch1", 1, [obj])
	var ch2 := _chapter("ch2", 2, [], "ch1")
	CampaignManager.chapters = [ch1, ch2]
	CampaignManager._catch_up()
	assert_eq(CampaignManager.current_chapter_index, 0, "Precondition: chapter 1 is active")

	CampaignManager._on_captain_recruited(null)

	assert_eq(CampaignManager.current_chapter_index, 1, "Completing ch1 must release ch2's gate")
	assert_true(CampaignManager.is_chapter_completed("ch1"))


func test_the_overshoot_case_cascades_through_already_satisfied_gates():
	## Requirement 6.8: a save can load with `completed_chapter_ids` already
	## holding real completions and a region independently active, while
	## `current_chapter_index` itself hasn't caught up yet (e.g. the region
	## activated after the last save). The campaign must catch up rather than
	## stay stuck on a stale index — never by *assuming* a chapter is done.
	EmpireManager._region_active["contested_waters"] = true
	CampaignManager.completed_chapter_ids = ["ch1", "ch2"]
	var ch1 := _chapter("ch1", 1, [])
	var ch2 := _chapter("ch2", 2, [], "ch1")
	var ch3 := _chapter("ch3", 3, [], "", "contested_waters")
	CampaignManager.chapters = [ch1, ch2, ch3]

	CampaignManager._catch_up()

	assert_eq(CampaignManager.current_chapter_index, 2, "Must land on the furthest genuinely satisfied chapter")


func test_catch_up_never_assumes_an_incomplete_chapter_is_done():
	var obj := _objective("1.1", ObjectiveData.Condition.RECRUIT_CAPTAIN)
	var ch1 := _chapter("ch1", 1, [obj])
	var ch2 := _chapter("ch2", 2, [], "ch1")
	CampaignManager.chapters = [ch1, ch2]

	CampaignManager._catch_up()

	assert_eq(CampaignManager.current_chapter_index, 0,
		"ch1's real objective is untouched — catch-up must not skip to ch2")
	assert_false(CampaignManager.is_chapter_completed("ch1"))


# === Objective dispatch ===

func test_a_counting_objective_completes_at_its_target_count():
	var obj := _objective("1.1", ObjectiveData.Condition.DESTROY_SHIPS, "pirate_clans", 3)
	CampaignManager.chapters = [_chapter("ch1", 1, [obj])]
	CampaignManager._catch_up()
	watch_signals(CampaignManager)

	var faction := load("res://resources/factions/PirateClans.tres")

	for i in range(3):
		var ship := MockShip.new()
		ship.faction = faction
		add_child_autoqfree(ship)
		CampaignManager._on_ship_destroyed(ship)

	assert_signal_emitted(CampaignManager, "objective_completed")
	assert_true(CampaignManager._completed_objective_ids.has("1.1"))


func test_defeat_boss_matches_a_dedicated_ship_id_not_a_faction():
	## E1: boss identity comes from a dedicated (non-shared) ShipStats.ship_id,
	## never the shared ManOWar.tres template also sold to the player — sinking
	## a player-owned Man O'War must never satisfy "defeat the boss".
	var obj := _objective("4.6", ObjectiveData.Condition.DEFEAT_BOSS, "intransigent")
	CampaignManager.chapters = [_chapter("ch1", 1, [obj])]
	CampaignManager._catch_up()
	watch_signals(CampaignManager)

	var generic_man_o_war := MockShip.new()
	generic_man_o_war.faction = load("res://resources/factions/RoyalNavy.tres")
	generic_man_o_war.ship_stats = load("res://resources/ships/ManOWar.tres")
	add_child_autoqfree(generic_man_o_war)
	CampaignManager._on_ship_destroyed(generic_man_o_war)
	assert_false(CampaignManager._completed_objective_ids.has("4.6"),
		"A shared-template hull must never satisfy a named-boss objective")

	var boss := MockShip.new()
	var boss_stats := ShipStats.new()
	boss_stats.ship_id = "intransigent"
	boss.ship_stats = boss_stats
	add_child_autoqfree(boss)
	CampaignManager._on_ship_destroyed(boss)
	assert_true(CampaignManager._completed_objective_ids.has("4.6"))


func test_an_objective_for_the_wrong_faction_does_not_progress():
	var obj := _objective("1.1", ObjectiveData.Condition.DESTROY_SHIPS, "royal_navy", 1)
	CampaignManager.chapters = [_chapter("ch1", 1, [obj])]
	CampaignManager._catch_up()

	var ship := MockShip.new()
	ship.faction = load("res://resources/factions/PirateClans.tres")
	add_child_autoqfree(ship)
	CampaignManager._on_ship_destroyed(ship)

	assert_false(CampaignManager._completed_objective_ids.has("1.1"))


func test_reach_island_tier_is_a_level_check_not_a_counter():
	var obj := _objective("1.1", ObjectiveData.Condition.REACH_ISLAND_TIER, "port_royal", 2)
	CampaignManager.chapters = [_chapter("ch1", 1, [obj])]
	CampaignManager._catch_up()
	watch_signals(CampaignManager)

	CampaignManager._on_island_tier_changed("port_royal", 1)
	assert_false(CampaignManager._completed_objective_ids.has("1.1"), "Tier 1 must not satisfy a target of 2")

	CampaignManager._on_island_tier_changed("port_royal", 2)
	assert_true(CampaignManager._completed_objective_ids.has("1.1"))


func test_accumulate_resource_reads_the_absolute_amount():
	var obj := _objective("1.1", ObjectiveData.Condition.ACCUMULATE_RESOURCE, "gold", 1, 500.0)
	CampaignManager.chapters = [_chapter("ch1", 1, [obj])]
	CampaignManager._catch_up()

	CampaignManager._on_resources_changed({"gold": 200})
	assert_false(CampaignManager._completed_objective_ids.has("1.1"))

	CampaignManager._on_resources_changed({"gold": 500})
	assert_true(CampaignManager._completed_objective_ids.has("1.1"))


func test_own_ship_class_checks_the_best_owned_hull():
	var obj := _objective("1.1", ObjectiveData.Condition.OWN_SHIP_CLASS, "", 1, 2.0)
	CampaignManager.chapters = [_chapter("ch1", 1, [obj])]
	CampaignManager._catch_up()

	FleetManager.owned_ships.clear()
	var sloop_owned := OwnedShipData.new()
	sloop_owned.ship_stats = load("res://resources/ships/Sloop.tres")
	FleetManager.owned_ships.append(sloop_owned)
	CampaignManager._on_fleet_changed()
	assert_false(CampaignManager._completed_objective_ids.has("1.1"), "A class-1 Sloop must not satisfy class 2")

	var schooner_owned := OwnedShipData.new()
	schooner_owned.ship_stats = load("res://resources/ships/Schooner.tres")
	FleetManager.owned_ships.append(schooner_owned)
	CampaignManager._on_fleet_changed()
	assert_true(CampaignManager._completed_objective_ids.has("1.1"))


func test_survive_raid_completes_on_either_outcome():
	var obj := _objective("1.1", ObjectiveData.Condition.SURVIVE_RAID)
	CampaignManager.chapters = [_chapter("ch1", 1, [obj])]
	CampaignManager._catch_up()

	CampaignManager._on_raid_resolved({"outcome": "looted"})

	assert_true(CampaignManager._completed_objective_ids.has("1.1"),
		"Being robbed is a lesson, not a fail state (docs/13 Ch3 3.4)")


func test_optional_objectives_do_not_block_chapter_completion():
	var required := _objective("1.1", ObjectiveData.Condition.RECRUIT_CAPTAIN)
	var optional := _objective("1.2", ObjectiveData.Condition.BOARD_SHIPS, "", 1, 0.0, true)
	CampaignManager.chapters = [_chapter("ch1", 1, [required, optional])]
	CampaignManager._catch_up()
	watch_signals(CampaignManager)

	CampaignManager._on_captain_recruited(null)

	assert_signal_emitted(CampaignManager, "chapter_completed")
	assert_true(CampaignManager.is_chapter_completed("ch1"))


# === Boarding target matching ===

func test_boarding_matches_against_either_faction_or_ship_id():
	var obj := _objective("1.1", ObjectiveData.Condition.BOARD_SHIPS, "intransigent")
	CampaignManager.chapters = [_chapter("ch1", 1, [obj])]
	CampaignManager._catch_up()

	CampaignManager._on_boarding_resolved(true, {}, "royal_navy", "man_o_war")
	assert_false(CampaignManager._completed_objective_ids.has("1.1"),
		"A generic Navy hull must not satisfy a named-boss objective")

	CampaignManager._on_boarding_resolved(true, {}, "royal_navy", "intransigent")
	assert_true(CampaignManager._completed_objective_ids.has("1.1"))


func test_a_failed_boarding_attempt_never_progresses():
	var obj := _objective("1.1", ObjectiveData.Condition.BOARD_SHIPS)
	CampaignManager.chapters = [_chapter("ch1", 1, [obj])]
	CampaignManager._catch_up()

	CampaignManager._on_boarding_resolved(false, {}, "pirate_clans", "")

	assert_false(CampaignManager._completed_objective_ids.has("1.1"))


# === Rewards ===

func test_completing_a_chapter_grants_gold_and_advances():
	var obj := _objective("1.1", ObjectiveData.Condition.RECRUIT_CAPTAIN)
	var ch1 := _chapter("ch1", 1, [obj])
	ch1.reward_gold = 500
	var ch2 := _chapter("ch2", 2, [], "ch1")
	CampaignManager.chapters = [ch1, ch2]
	CampaignManager._catch_up()
	var gold_before: int = int(ResourceManager.current_resources.get("gold", 0))

	CampaignManager._on_captain_recruited(null)

	assert_eq(int(ResourceManager.current_resources.get("gold", 0)), gold_before + 500)
	assert_eq(CampaignManager.current_chapter_index, 1)


# === Discovery write path (E2) ===

func test_docking_marks_the_island_discovered():
	var scene := Node3D.new()
	add_child_autoqfree(scene)
	var island = load("res://scripts/world/Island.gd").new()
	island.island_data = IslandData.new()
	island.island_data.island_id = "tortuga"
	scene.add_child(island)
	await wait_process_frames(1)

	assert_false(island.island_data.discovered, "Precondition: not yet discovered")
	CampaignManager._on_player_docked("tortuga")
	assert_true(island.island_data.discovered, "Docking must write IslandData.discovered")


# === Save / load ===

func test_save_load_round_trips_chapter_and_objective_progress():
	var obj := _objective("1.1", ObjectiveData.Condition.RECRUIT_CAPTAIN)
	var ch1 := _chapter("ch1", 1, [obj])
	var ch2 := _chapter("ch2", 2, [], "ch1")
	CampaignManager.chapters = [ch1, ch2]
	CampaignManager._catch_up()
	CampaignManager._on_captain_recruited(null)
	assert_eq(CampaignManager.current_chapter_index, 1, "Precondition: advanced to ch2")

	var saved := CampaignManager.get_save_data()
	CampaignManager.current_chapter_index = -1
	CampaignManager.completed_chapter_ids.clear()
	CampaignManager._completed_objective_ids.clear()

	CampaignManager.load_save_data(saved)

	assert_eq(CampaignManager.current_chapter_index, 1)
	assert_true(CampaignManager.completed_chapter_ids.has("ch1"))
	assert_true(CampaignManager._completed_objective_ids.has("1.1"))


func test_get_save_data_returns_a_duplicate_not_the_live_array():
	## The FleetManager D12 lesson: mutating the returned dict must never leak
	## back into live state.
	CampaignManager.chapters = [_chapter("ch1", 1, [])]
	CampaignManager._catch_up()
	var saved := CampaignManager.get_save_data()
	saved["completed_chapter_ids"].append("ch99")
	assert_false(CampaignManager.completed_chapter_ids.has("ch99"),
		"Mutating the saved dict's array must not affect live state")

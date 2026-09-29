extends GutTest

## M27 Tasks 3-4 — timed building, upgrades, research, ships and repair
## (Requirements 2.1-2.4, 2.7). Real content resources are used (their resource
## paths are what jobs persist), with a duration set for the test and restored
## after — every shipped .tres starts at 0 = instant.

const IslandScript = preload("res://scripts/world/Island.gd")
const IslandMenuScene = preload("res://scenes/ui/IslandMenu.tscn")
const PLAYER_SHIP := preload("res://scenes/world/PlayerShip.tscn")

const FARM_L1 := "res://resources/buildings/Farm_L1.tres"
const FARM_L2 := "res://resources/buildings/Farm_L2.tres"
const MILL_L1 := "res://resources/buildings/LumberMill_L1.tres"
const TECH := "res://resources/techs/ReinforcedHulls.tres"
const OTHER_TECH := "res://resources/techs/SwifterSails.tres"
const SHIP := "res://resources/ships/Brigantine.tres"
const ISLAND_ID := "m27_test_island"

var _island: Node3D
var _jobs_before: Dictionary
var _completed_before: Dictionary
var _offset_before: float
var _resources_before: Dictionary
var _techs_before: Array[Resource]
var _ships_before: Array[OwnedShipData]
## resource -> {property: original value}, restored in after_each.
var _authored: Dictionary = {}


func before_each() -> void:
	_jobs_before = ScheduleManager._jobs.duplicate(true)
	_completed_before = ScheduleManager._completed_ids.duplicate()
	_offset_before = ScheduleManager.now_offset
	ScheduleManager.reset()
	ScheduleManager.now_offset = 0.0
	_resources_before = ResourceManager.current_resources.duplicate()
	# Assigned directly (past storage caps): enough for any cost used below.
	for type in ["gold", "wood", "iron", "rum"]:
		ResourceManager.current_resources[type] = 5000
	_techs_before = TechManager.unlocked_techs.duplicate()
	TechManager.unlocked_techs.clear()
	_ships_before = FleetManager.owned_ships.duplicate()
	_island = _make_island(ISLAND_ID)


func after_each() -> void:
	for res in _authored:
		for prop in _authored[res]:
			res.set(prop, _authored[res][prop])
	_authored.clear()
	ScheduleManager._jobs = _jobs_before
	ScheduleManager._completed_ids = _completed_before
	ScheduleManager.now_offset = _offset_before
	ResourceManager.current_resources = _resources_before
	TechManager.unlocked_techs = _techs_before
	TechManager._recalculate_modifiers()
	FleetManager.owned_ships = _ships_before
	get_tree().paused = false


func _make_island(id: String) -> Node3D:
	var island: Node3D = IslandScript.new()
	var data := IslandData.new()
	data.island_id = id
	data.island_type = IslandData.IslandType.CAPITAL
	island.island_data = data
	# A slot so the completed building gets a visual, like an authored island.
	var buildings := Node3D.new()
	buildings.name = "Buildings"
	var slots := Node3D.new()
	slots.name = "BuildingSlots"
	slots.add_child(Marker3D.new())
	slots.add_child(Marker3D.new())
	buildings.add_child(slots)
	island.add_child(buildings)
	add_child_autofree(island)
	return island


## Sets `prop` on a (cached, shared) content resource for this test only.
func _author(path: String, prop: String, value) -> Resource:
	var res := load(path)
	if not _authored.has(res):
		_authored[res] = {}
	if not _authored[res].has(prop):
		_authored[res][prop] = res.get(prop)
	res.set(prop, value)
	return res


func _finish_everything() -> void:
	ScheduleManager.now_offset += 100000.0
	ScheduleManager.process_due_jobs()


# ------------------------------------------------------------------ building (Task 3)

func test_a_timed_building_is_absent_until_its_job_completes() -> void:
	var farm: BuildingData = _author(FARM_L1, "build_seconds", 30.0)
	var gold_before := ResourceManager.get_resource("gold")
	assert_true(_island.build_structure(farm))
	assert_lt(ResourceManager.get_resource("gold"), gold_before, "cost is spent immediately")
	assert_false(_island.has_building("farm_l1"), "not built yet")
	assert_true(_island.is_building("farm_l1"))
	assert_true(_island.is_constructing())

	_finish_everything()
	assert_true(_island.has_building("farm_l1"))
	assert_false(_island.is_constructing())
	assert_true(_island._spawned_models.has("farm_l1"), "the building's visual appears on completion")


func test_construction_time_shortens_with_island_tier() -> void:
	var farm: BuildingData = _author(FARM_L1, "build_seconds", 100.0)
	var tier_1: float = _island.get_construction_seconds(farm)
	_island._current_tier = 3
	assert_lt(_island.get_construction_seconds(farm), tier_1)


func test_structure_changed_fires_on_completion_not_on_payment() -> void:
	# CampaignManager's BUILD_STRUCTURE objectives listen to IslandMenu.structure_changed.
	var menu: IslandMenu = IslandMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_frames(1)   # _connect_islands is deferred
	watch_signals(menu)
	var farm: BuildingData = _author(FARM_L1, "build_seconds", 30.0)
	_island.build_structure(farm)
	assert_signal_not_emitted(menu, "structure_changed", "paying must not complete an objective")

	_finish_everything()
	assert_signal_emit_count(menu, "structure_changed", 1)
	assert_eq(get_signal_parameters(menu, "structure_changed"), ["farm_l1", false])


func test_an_instant_building_still_completes_immediately_and_once() -> void:
	var menu: IslandMenu = IslandMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_frames(1)
	watch_signals(menu)
	var farm: BuildingData = _author(FARM_L1, "build_seconds", 0.0)   # 0 = instant
	assert_true(_island.build_structure(farm))
	assert_true(_island.has_building("farm_l1"))
	assert_signal_emit_count(menu, "structure_changed", 1)
	assert_eq(ScheduleManager.get_all_jobs().size(), 0, "no job for an instant build")


func test_a_second_construction_on_the_same_island_is_refused() -> void:
	var farm: BuildingData = _author(FARM_L1, "build_seconds", 30.0)
	var mill: BuildingData = load(MILL_L1)
	assert_true(_island.build_structure(farm))
	var gold := ResourceManager.get_resource("gold")
	assert_false(_island.build_structure(mill), "one build/upgrade per island at a time")
	assert_eq(ResourceManager.get_resource("gold"), gold, "a refused build spends nothing")

	var other := _make_island("m27_other_island")
	assert_true(other.build_structure(mill), "another island's builders are free")


func test_a_timed_upgrade_keeps_the_old_level_until_it_completes() -> void:
	var farm_l1: BuildingData = _author(FARM_L1, "build_seconds", 0.0)
	assert_true(_island.build_structure(farm_l1))
	var farm_l2: BuildingData = _author(FARM_L2, "build_seconds", 90.0)
	assert_true(_island.upgrade_structure("farm_l1", farm_l2))
	assert_true(_island.has_building("farm_l1"), "the Level 1 farm keeps working meanwhile")
	assert_false(_island.has_building("farm_l2"))
	assert_true(_island.is_building("farm_l2"))

	_finish_everything()
	assert_false(_island.has_building("farm_l1"))
	assert_true(_island.has_building("farm_l2"))
	assert_eq(_island.get_building_level("farm"), 2)


func test_a_job_for_another_island_never_builds_here() -> void:
	var other := _make_island("m27_other_island")
	var farm: BuildingData = _author(FARM_L1, "build_seconds", 30.0)
	other.build_structure(farm)
	_finish_everything()
	assert_true(other.has_building("farm_l1"))
	assert_false(_island.has_building("farm_l1"))


func test_restoring_buildings_from_a_save_is_not_a_completion() -> void:
	watch_signals(_island)
	_island.restore_buildings(["farm_l1"])
	assert_signal_not_emitted(_island, "structure_completed")


func test_get_building_level_is_zero_when_absent() -> void:
	assert_eq(_island.get_building_level("academy"), 0)


# ------------------------------------------------------------------ research, ships, repair (Task 4)

func test_research_unlocks_only_when_its_job_completes() -> void:
	var tech: TechData = _author(TECH, "research_seconds", 60.0)
	assert_true(TechManager.start_research(tech, tech.get_cost_dict()))
	assert_false(TechManager.is_unlocked(tech.tech_id))
	assert_true(TechManager.is_researching())
	_finish_everything()
	assert_true(TechManager.is_unlocked(tech.tech_id))
	assert_false(TechManager.is_researching())


func test_a_second_research_job_is_refused() -> void:
	var tech: TechData = _author(TECH, "research_seconds", 60.0)
	var other: TechData = _author(OTHER_TECH, "research_seconds", 60.0)
	assert_true(TechManager.start_research(tech, tech.get_cost_dict()))
	var gold := ResourceManager.get_resource("gold")
	assert_false(TechManager.start_research(other, other.get_cost_dict()))
	assert_eq(ResourceManager.get_resource("gold"), gold, "a refused research spends nothing")


func test_research_speed_comes_from_the_best_academy() -> void:
	var tech: TechData = _author(TECH, "research_seconds", 100.0)
	var without := TechManager.get_research_seconds(tech)
	_island.restore_buildings(["academy_l2"])
	assert_eq(TechManager.get_academy_level(), 2)
	assert_lt(TechManager.get_research_seconds(tech), without)


func test_a_new_ship_joins_the_fleet_only_on_completion() -> void:
	var ship: ShipStats = _author(SHIP, "build_seconds", 45.0)
	FleetManager.owned_ships = FleetManager.owned_ships.filter(func(o): return o.ship_stats != ship)
	var cost := {"gold": 1}
	assert_true(FleetManager.start_ship_construction(ship, cost, 1))
	assert_false(FleetManager.owns_ship_stats(ship))
	assert_true(FleetManager.is_ship_under_construction(ship))
	assert_false(FleetManager.start_ship_construction(ship, cost, 1), "the same hull can't be paid for twice")
	_finish_everything()
	assert_true(FleetManager.owns_ship_stats(ship))


func test_shipyard_level_shortens_ship_construction() -> void:
	var ship: ShipStats = _author(SHIP, "build_seconds", 100.0)
	assert_lt(FleetManager.get_ship_build_seconds(ship, 3), FleetManager.get_ship_build_seconds(ship, 1))


func test_shipyard_repair_applies_on_completion() -> void:
	var menu: IslandMenu = IslandMenuScene.instantiate()
	add_child_autofree(menu)
	var player := PLAYER_SHIP.instantiate()
	add_child_autofree(player)
	await wait_frames(1)
	var damage = player.get_node("ShipDamage")
	damage.hull = damage.get_pool_maximum("hull") * 0.5
	damage.sails = damage.get_pool_maximum("sails") * 0.5
	menu.current_island = _island
	var hull_before: float = damage.hull

	menu._on_repair_ship_pressed(damage)
	assert_eq(ScheduleManager.get_jobs_of_kind("repair").size(), 1)
	assert_gt(ScheduleManager.remaining(ScheduleManager.get_jobs_of_kind("repair")[0]["id"]), 0.0,
		"repair time scales with the damage")
	assert_eq(damage.hull, hull_before, "nothing repaired yet")

	_finish_everything()
	assert_almost_eq(damage.hull, damage.get_pool_maximum("hull"), 0.01)
	assert_almost_eq(damage.sails, damage.get_pool_maximum("sails"), 0.01)

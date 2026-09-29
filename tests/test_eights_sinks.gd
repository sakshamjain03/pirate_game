extends GutTest

## M27 Task 6 — the two Eights sinks (Requirements 4.1-4.4, 5.1-5.5). AGENTS.md:
## skip cost is priced off remaining time, never total; money only finishes what
## play can finish; covering never applies to an Eights cost, and never buys
## resources a storage cap would throw away.

const IslandScript = preload("res://scripts/world/Island.gd")
const FARM_L1 := "res://resources/buildings/Farm_L1.tres"
const EIGHTS := "eights"
const EightsConfirmDialogScript := preload("res://scripts/ui/EightsConfirmDialog.gd")

var _jobs_before: Dictionary
var _completed_before: Dictionary
var _offset_before: float
var _resources_before: Dictionary
var _storage_before: Dictionary
var _completed: Array = []


func before_each() -> void:
	_jobs_before = ScheduleManager._jobs.duplicate(true)
	_completed_before = ScheduleManager._completed_ids.duplicate()
	_offset_before = ScheduleManager.now_offset
	ScheduleManager.reset()
	ScheduleManager.now_offset = 0.0
	_resources_before = ResourceManager.current_resources.duplicate()
	_storage_before = ResourceManager.max_storage.duplicate()
	ResourceManager.current_resources = {"gold": 0, "wood": 0, "iron": 0, "rum": 0, "research": 0, EIGHTS: 0}
	_completed.clear()
	ScheduleManager.job_completed.connect(_on_completed)


func after_each() -> void:
	ScheduleManager.job_completed.disconnect(_on_completed)
	ScheduleManager._jobs = _jobs_before
	ScheduleManager._completed_ids = _completed_before
	ScheduleManager.now_offset = _offset_before
	ResourceManager.current_resources = _resources_before
	ResourceManager.max_storage = _storage_before


func _on_completed(job: Dictionary) -> void:
	_completed.append(job)


func _rate(res: String) -> int:
	return int(ScheduleManager.pricing.shortfall_rates[res])


# ------------------------------------------------------------------ Finish now

func test_finish_cost_comes_from_remaining_time_not_total() -> void:
	# Requirement 4.4 — equal remaining, different totals, same price.
	var long_job := ScheduleManager.start_job("build", "a", "long", 1200.0)
	ScheduleManager.now_offset = 600.0
	var short_job := ScheduleManager.start_job("build", "b", "short", 600.0)
	assert_almost_eq(ScheduleManager.remaining(long_job), ScheduleManager.remaining(short_job), 0.5)
	assert_eq(ScheduleManager.finish_cost_eights(long_job), ScheduleManager.finish_cost_eights(short_job))


func test_finish_cost_falls_as_the_job_runs() -> void:
	var id := ScheduleManager.start_job("build", "a", "x", 600.0)
	var at_start := ScheduleManager.finish_cost_eights(id)
	ScheduleManager.now_offset = 450.0
	assert_lt(ScheduleManager.finish_cost_eights(id), at_start)


func test_finish_cost_is_at_least_one() -> void:
	var id := ScheduleManager.start_job("build", "a", "x", 600.0)
	ScheduleManager.now_offset = 599.0
	assert_eq(ScheduleManager.finish_cost_eights(id), 1)


func test_finish_now_spends_and_completes() -> void:
	var id := ScheduleManager.start_job("research", "tech", "x", 300.0)
	var cost := ScheduleManager.finish_cost_eights(id)
	ResourceManager.current_resources[EIGHTS] = cost + 2
	assert_true(ScheduleManager.finish_now(id))
	assert_eq(ResourceManager.get_resource(EIGHTS), 2)
	assert_eq(_completed.size(), 1)


func test_finish_now_refusal_spends_nothing() -> void:
	var id := ScheduleManager.start_job("research", "tech", "x", 300.0)
	ResourceManager.current_resources[EIGHTS] = ScheduleManager.finish_cost_eights(id) - 1
	var before := ResourceManager.get_resource(EIGHTS)
	assert_false(ScheduleManager.finish_now(id), "unaffordable")
	assert_eq(ResourceManager.get_resource(EIGHTS), before)
	assert_true(ScheduleManager.has_job(id), "the job keeps running")
	assert_eq(_completed.size(), 0)


func test_finish_now_on_a_finished_job_is_refused() -> void:
	var id := ScheduleManager.start_job("research", "tech", "x", 30.0)
	ScheduleManager.now_offset = 60.0
	ScheduleManager.process_due_jobs()
	ResourceManager.current_resources[EIGHTS] = 10
	assert_false(ScheduleManager.finish_now(id))
	assert_eq(ResourceManager.get_resource(EIGHTS), 10)


func test_a_due_job_finishes_for_free() -> void:
	# Remaining time already 0 (e.g. the menu was open when it ran out): never
	# charge for time that has already passed.
	var id := ScheduleManager.start_job("build", "a", "x", 30.0)
	ScheduleManager.now_offset = 60.0
	assert_eq(ScheduleManager.finish_cost_eights(id), 0)
	assert_true(ScheduleManager.finish_now(id))
	assert_eq(ResourceManager.get_resource(EIGHTS), 0)


# ------------------------------------------------------------------ Cover shortfall

func test_shortfall_reports_only_what_is_missing() -> void:
	ResourceManager.current_resources["gold"] = 30
	ResourceManager.current_resources["wood"] = 50
	var gap := ResourceManager.shortfall({"gold": 100, "wood": 20})
	assert_eq(gap, {"gold": 70})
	assert_eq(ResourceManager.shortfall({"gold": 10}), {}, "affordable = no shortfall")


func test_shortfall_price_rounds_up_per_resource_with_a_minimum_of_one() -> void:
	ResourceManager.current_resources["gold"] = _rate("gold") * 2 - 1   # one gold short
	assert_eq(ResourceManager.shortfall_cost_eights({"gold": _rate("gold") * 2}), 1)
	ResourceManager.current_resources["gold"] = 0
	ResourceManager.current_resources["wood"] = 0
	var cost := {"gold": _rate("gold") + 1, "wood": _rate("wood")}
	assert_eq(ResourceManager.shortfall_cost_eights(cost), 2 + 1, "ceil per resource, summed")
	assert_eq(ResourceManager.shortfall_cost_eights({}), 0)


func test_cover_is_atomic_and_exact() -> void:
	ResourceManager.current_resources["gold"] = 100
	ResourceManager.current_resources["wood"] = 5
	var cost := {"gold": 300, "wood": 5}
	var price := ResourceManager.shortfall_cost_eights(cost)
	ResourceManager.current_resources[EIGHTS] = price + 3
	assert_true(ResourceManager.cover_shortfall_and_spend(cost))
	assert_eq(ResourceManager.get_resource("gold"), 0, "exactly the shortfall was added, then the full cost spent")
	assert_eq(ResourceManager.get_resource("wood"), 0)
	assert_eq(ResourceManager.get_resource(EIGHTS), 3)


func test_cover_without_enough_eights_changes_nothing() -> void:
	ResourceManager.current_resources["gold"] = 100
	var cost := {"gold": 300}
	ResourceManager.current_resources[EIGHTS] = ResourceManager.shortfall_cost_eights(cost) - 1
	var before := ResourceManager.current_resources.duplicate()
	assert_false(ResourceManager.cover_shortfall_and_spend(cost))
	assert_eq(ResourceManager.current_resources, before)


func test_cover_is_refused_when_the_top_up_would_clamp_at_storage() -> void:
	ResourceManager.max_storage["wood"] = 200
	ResourceManager.current_resources[EIGHTS] = 100000
	var before := ResourceManager.current_resources.duplicate()
	assert_false(ResourceManager.can_cover_shortfall({"wood": 500}))
	assert_false(ResourceManager.cover_shortfall_and_spend({"wood": 500}),
		"Eights must never buy resources the cap would throw away")
	assert_eq(ResourceManager.current_resources, before)


func test_cover_is_refused_for_an_eights_cost() -> void:
	ResourceManager.current_resources[EIGHTS] = 100000
	var before := ResourceManager.current_resources.duplicate()
	assert_false(ResourceManager.cover_shortfall_and_spend({"gold": 100, EIGHTS: 5}))
	assert_eq(ResourceManager.current_resources, before)
	assert_false(ResourceManager.shortfall({EIGHTS: 5}).has(EIGHTS), "Eights is never a shortfall resource")


func test_cover_is_refused_when_nothing_is_missing() -> void:
	ResourceManager.current_resources["gold"] = 500
	ResourceManager.current_resources[EIGHTS] = 10
	assert_false(ResourceManager.can_cover_shortfall({"gold": 100}))


func test_pay_spends_normally_when_affordable_even_with_cover_allowed() -> void:
	ResourceManager.current_resources["gold"] = 500
	ResourceManager.current_resources[EIGHTS] = 10
	assert_true(ResourceManager.pay({"gold": 100}, true))
	assert_eq(ResourceManager.get_resource("gold"), 400)
	assert_eq(ResourceManager.get_resource(EIGHTS), 10, "no Eights when nothing is missing")


func test_pay_without_cover_never_touches_eights() -> void:
	ResourceManager.current_resources[EIGHTS] = 100
	assert_false(ResourceManager.pay({"gold": 100}))
	assert_eq(ResourceManager.get_resource(EIGHTS), 100)


func test_a_building_purchase_can_be_covered_end_to_end() -> void:
	var island: Node3D = IslandScript.new()
	var data := IslandData.new()
	data.island_id = "m27_sink_island"
	data.island_type = IslandData.IslandType.CAPITAL
	island.island_data = data
	add_child_autofree(island)
	var farm: BuildingData = load(FARM_L1)
	var cost := farm.get_cost_dict()
	ResourceManager.current_resources[EIGHTS] = ResourceManager.shortfall_cost_eights(cost)
	assert_false(island.build_structure(farm), "unaffordable without cover")
	assert_true(island.build_structure(farm, true), "covered with Eights")
	ScheduleManager.now_offset += 100000.0
	ScheduleManager.process_due_jobs()
	assert_true(island.has_building("farm_l1"))
	assert_eq(ResourceManager.get_resource(EIGHTS), 0)


func test_the_confirm_dialog_spends_only_on_the_spend_button() -> void:
	var result := [null]
	var dialog := EightsConfirmDialogScript.new("Finish the Farm now", 3)
	var run := func(): result[0] = await dialog.confirm(self)
	run.call()
	dialog._on_choice(EightsConfirmDialogScript.SPEND_INDEX)
	await wait_frames(1)
	assert_eq(result[0], true)

	var cancelled := [null]
	var dialog2 := EightsConfirmDialogScript.new("Finish the Farm now", 3)
	var run2 := func(): cancelled[0] = await dialog2.confirm(self)
	run2.call()
	dialog2._on_choice(EightsConfirmDialogScript.CANCEL_INDEX)
	await wait_frames(1)
	assert_eq(cancelled[0], false)


# ------------------------------------------------------------------ IslandMenu rows

const IslandMenuScene = preload("res://scenes/ui/IslandMenu.tscn")


func _open_menu_on_new_island() -> Array:
	var island: Node3D = IslandScript.new()
	var data := IslandData.new()
	data.island_id = "m27_menu_island"
	data.island_type = IslandData.IslandType.CAPITAL
	island.island_data = data
	add_child_autofree(island)
	var menu: IslandMenu = IslandMenuScene.instantiate()
	add_child_autofree(menu)
	return [menu, island]


func _all_buttons(menu: Node) -> Array:
	return menu.buildings_container.get_parent().get_parent().find_children("*", "Button", true, false)


func test_a_running_job_row_shows_progress_and_a_finish_now_control() -> void:
	var pair := _open_menu_on_new_island()
	var menu: IslandMenu = pair[0]
	var island = pair[1]
	ScheduleManager.start_job("build", "m27_menu_island", "farm_l1", 120.0)
	assert_true(island.is_building("farm_l1"))
	menu.open(island)
	await wait_frames(3)
	var finish := _all_buttons(menu).filter(func(b): return b.text.begins_with("Finish now"))
	assert_eq(finish.size(), 1, "one Finish now control for the one running job")
	assert_gt(menu.buildings_container.get_parent().get_parent().find_children("*", "ProgressBar", true, false).size(), 0)
	assert_false(finish[0].theme_type_variation == &"PrimaryButton", "an Eights spend is never the hero CTA")
	menu.close()


## Found in the M27 Checkpoint B phone sweep: pressing Build refreshes the page
## several times in one frame (the spend, job_started, the handler itself), each
## queuing a deferred restyle. The second restyle found the first's cards already
## tiled and hid the detail panel, so the new job row and its Finish now vanished.
func test_several_refreshes_in_one_frame_keep_the_detail_docked() -> void:
	var pair := _open_menu_on_new_island()
	var menu: IslandMenu = pair[0]
	menu.open(pair[1])
	await wait_frames(3)
	menu._refresh_buildings()
	ScheduleManager.start_job("build", "m27_menu_island", "farm_l1", 120.0)
	menu._refresh_buildings()
	await wait_frames(3)
	var board: Dictionary = menu._boards[menu.buildings_container]
	assert_true(board.detail.visible, "the selected entry stays docked")
	assert_eq(board.body.get_child_count(), 1)
	menu.close()


func test_cover_is_offered_only_when_it_can_succeed() -> void:
	var pair := _open_menu_on_new_island()
	var menu: IslandMenu = pair[0]
	var island = pair[1]
	menu.open(island)
	await wait_frames(3)
	var covers := _all_buttons(menu).filter(func(b): return b.text.begins_with("Cover for"))
	assert_eq(covers.size(), 0, "no Eights, no paid button on every row")
	menu.close()

	ResourceManager.current_resources[EIGHTS] = 100000
	menu.open(island)
	await wait_frames(3)
	covers = _all_buttons(menu).filter(func(b): return b.text.begins_with("Cover for"))
	assert_gt(covers.size(), 0, "an unaffordable purchase offers Cover")
	menu.close()


# ------------------------------------------- Cover on every paid purchase
# The paid currency must be able to supplement any resource on any purchase the
# player chose — not only builds, hulls, captains and research. These three
# FleetManager upgrades (and IslandMenu's crew recruit and colonize, which go
# through the same ResourceManager.pay()) used to spend without a cover path.

func _with_owned_sloop(level: int, component_level: int) -> int:
	var owned := OwnedShipData.new()
	owned.ship_stats = load("res://resources/ships/Sloop.tres")
	owned.level = level
	owned.set_all_components(component_level)
	FleetManager.owned_ships.append(owned)
	return FleetManager.owned_ships.size() - 1


func _cover_exactly(cost: Dictionary) -> void:
	ResourceManager.current_resources[EIGHTS] = ResourceManager.shortfall_cost_eights(cost)


func test_a_ship_level_up_can_be_covered() -> void:
	var saved := FleetManager.owned_ships.duplicate()
	var idx := _with_owned_sloop(1, 1)
	var owned: OwnedShipData = FleetManager.owned_ships[idx]
	var cost := owned.get_level_up_cost()
	_cover_exactly(cost)
	assert_false(FleetManager.level_up_ship(idx), "unaffordable without cover")
	assert_true(FleetManager.level_up_ship(idx, true), "covered with Eights")
	assert_eq(owned.level, 2)
	assert_eq(ResourceManager.get_resource(EIGHTS), 0)
	FleetManager.owned_ships = saved


func test_a_component_upgrade_can_be_covered() -> void:
	var saved := FleetManager.owned_ships.duplicate()
	var idx := _with_owned_sloop(2, 1)
	var owned: OwnedShipData = FleetManager.owned_ships[idx]
	var comp_id: String = OwnedShipData.get_component_catalog().get_ids()[0]
	var cost := owned.get_component_upgrade_cost(comp_id)
	_cover_exactly(cost)
	assert_false(FleetManager.upgrade_component(idx, comp_id), "unaffordable without cover")
	assert_true(FleetManager.upgrade_component(idx, comp_id, true), "covered with Eights")
	assert_eq(owned.get_component_level(comp_id), 2)
	assert_eq(ResourceManager.get_resource(EIGHTS), 0)
	FleetManager.owned_ships = saved


func test_a_module_install_can_be_covered() -> void:
	var saved := FleetManager.owned_ships.duplicate()
	var idx := _with_owned_sloop(1, 1)
	var module := ShipModuleData.new()
	module.module_id = "m27_cover_test_module"
	module.cost_gold = 120
	module.cost_wood = 30
	var cost := {"gold": 120, "wood": 30, "iron": 0}
	_cover_exactly(cost)
	assert_false(FleetManager.equip_module(idx, module), "unaffordable without cover")
	assert_true(FleetManager.equip_module(idx, module, true), "covered with Eights")
	assert_eq(FleetManager.owned_ships[idx].get_module_in_slot(module.slot), module)
	assert_eq(ResourceManager.get_resource(EIGHTS), 0)
	FleetManager.owned_ships = saved

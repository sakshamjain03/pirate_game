extends GutTest

# test_ship_progression.gd
# Slice 8 (docs/navalCombat.md §13: ship level + modules) — gated on Wave A's
# M7 economy correction (ship_class/costs). `FleetManager.owned_ships` used to
# be a bare Array[ShipStats] pointing at shared resource templates; two owned
# Sloops would have had to share one mutable level/module record. These tests
# pin the OwnedShipData wrapper: level/modules apply to a duplicated ShipStats,
# never the shared template, and round-trip through save/load.

class MockPlayer extends Node3D:
	var ship_stats: ShipStats = null

var _saved_ships: Array
var _saved_active_index: int
var _saved_resources: Dictionary
var _created_test_scene: Node3D = null

func before_each():
	_saved_ships = FleetManager.owned_ships.duplicate()
	_saved_active_index = FleetManager.active_ship_index
	_saved_resources = ResourceManager.current_resources.duplicate()
	ResourceManager.current_resources["gold"] = 100000
	ResourceManager.current_resources["wood"] = 100000
	ResourceManager.current_resources["iron"] = 100000

func after_each():
	FleetManager.owned_ships = _saved_ships.duplicate()
	FleetManager.active_ship_index = _saved_active_index
	ResourceManager.current_resources = _saved_resources.duplicate()
	# This file's own current_scene, if it created one (see
	# test_equip_module_updates_the_active_ships_live_stats), must not outlive
	# it — a leaked one previously corrupted test_navigation_integration.gd's
	# real get_tree().change_scene_to_file() call (freed-lambda-capture crash).
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null

func _fresh_owned(ship_path: String = "res://resources/ships/Sloop.tres") -> OwnedShipData:
	var o := OwnedShipData.new()
	o.ship_stats = load(ship_path)
	return o


func test_leveling_up_never_mutates_the_shared_ship_stats_template():
	var owned := _fresh_owned()
	var template := owned.ship_stats
	var health_before: float = template.max_health

	owned.level = 3
	var effective := owned.get_effective_stats()

	assert_eq(template.max_health, health_before, "The shared .tres template must be untouched")
	assert_gt(effective.max_health, health_before,
		"...while the effective stats used in combat are genuinely stronger")


func test_equipping_a_module_never_mutates_the_shared_ship_stats_template():
	var owned := _fresh_owned()
	var template := owned.ship_stats
	var damage_before: float = template.cannon_damage
	var heavy: ShipModuleData = load("res://resources/modules/HeavyCannons.tres")

	owned.equip_module(heavy)
	var effective := owned.get_effective_stats()

	assert_eq(template.cannon_damage, damage_before, "The shared .tres template must be untouched")
	assert_almost_eq(effective.cannon_damage, damage_before * heavy.cannon_damage_mult, 0.01,
		"...while the effective stats reflect the module")


func test_equipping_a_second_module_in_the_same_slot_replaces_the_first():
	var owned := _fresh_owned()
	var planking: ShipModuleData = load("res://resources/modules/ReinforcedPlanking.tres")
	var iron_hull: ShipModuleData = load("res://resources/modules/IronHull.tres")  # same slot: HULL

	owned.equip_module(planking)
	assert_eq(owned.installed_modules.size(), 1)
	owned.equip_module(iron_hull)

	assert_eq(owned.installed_modules.size(), 1,
		"One module per slot — equipping a second HULL module must replace, not stack")
	assert_eq(owned.get_module_in_slot(ShipModuleData.Slot.HULL), iron_hull)


func test_modules_in_different_slots_stack():
	var owned := _fresh_owned()
	owned.equip_module(load("res://resources/modules/ReinforcedPlanking.tres"))  # HULL
	owned.equip_module(load("res://resources/modules/HeavyCannons.tres"))        # CANNON

	assert_eq(owned.installed_modules.size(), 2, "Different slots must not collide")


func test_fleet_manager_owns_ship_stats_survives_the_wrapper():
	FleetManager.owned_ships.clear()
	var sloop = load("res://resources/ships/Sloop.tres")
	var dinghy = load("res://resources/ships/Dinghy.tres")
	FleetManager.add_ship(sloop)

	assert_true(FleetManager.owns_ship_stats(sloop),
		"A bought hull must read as owned when comparing against the catalog template")
	assert_false(FleetManager.owns_ship_stats(dinghy), "...and an unbought one must not")


func test_level_up_spends_resources_and_refuses_past_max_level():
	FleetManager.owned_ships.clear()
	FleetManager.owned_ships.append(_fresh_owned())
	FleetManager.active_ship_index = 0
	var gold_before: int = int(ResourceManager.current_resources.get("gold", 0))

	assert_true(FleetManager.level_up_ship(0), "An affordable level-up must succeed")
	assert_lt(int(ResourceManager.current_resources.get("gold", 0)), gold_before,
		"...and actually spend the cost")
	assert_eq(FleetManager.owned_ships[0].level, 2)

	FleetManager.owned_ships[0].level = OwnedShipData.MAX_LEVEL
	assert_false(FleetManager.level_up_ship(0), "A maxed hull must refuse further level-ups")


func test_level_up_refuses_when_unaffordable():
	FleetManager.owned_ships.clear()
	FleetManager.owned_ships.append(_fresh_owned())
	ResourceManager.current_resources["gold"] = 0
	ResourceManager.current_resources["wood"] = 0

	assert_false(FleetManager.level_up_ship(0), "A level-up the player can't afford must be refused")
	assert_eq(FleetManager.owned_ships[0].level, 1, "...and nothing should change")


func test_equip_module_updates_the_active_ships_live_stats():
	## Leveling/equipping the ship currently being sailed must be felt
	## immediately (FleetManager._refresh_ship_on_deck), not just on next switch.
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene

	var player = MockPlayer.new()
	player.add_to_group("player_ship")
	add_child_autoqfree(player)

	FleetManager.owned_ships.clear()
	var owned := _fresh_owned()
	FleetManager.owned_ships.append(owned)
	FleetManager.active_ship_index = 0

	var heavy: ShipModuleData = load("res://resources/modules/HeavyCannons.tres")
	assert_true(FleetManager.equip_module(0, heavy))

	assert_eq(player.ship_stats.cannon_damage, owned.get_effective_stats().cannon_damage,
		"The ship on deck must pick up the new effective stats immediately")


func test_owned_ship_save_load_round_trips_level_and_modules():
	var owned := _fresh_owned()
	owned.level = 3
	owned.equip_module(load("res://resources/modules/ReinforcedPlanking.tres"))
	owned.equip_module(load("res://resources/modules/HeavyCannons.tres"))

	var saved := owned.get_save_data()
	var restored := OwnedShipData.from_save_data(saved)

	assert_eq(restored.level, 3)
	assert_eq(restored.ship_stats.resource_path, owned.ship_stats.resource_path)
	assert_eq(restored.installed_modules.size(), 2)
	assert_not_null(restored.get_module_in_slot(ShipModuleData.Slot.HULL))
	assert_not_null(restored.get_module_in_slot(ShipModuleData.Slot.CANNON))


func test_fleet_manager_save_load_round_trips_ship_progression():
	FleetManager.owned_ships.clear()
	FleetManager.owned_captains.clear()
	FleetManager.active_missions.clear()

	var owned := _fresh_owned("res://resources/ships/Galleon.tres")
	owned.level = 2
	owned.equip_module(load("res://resources/modules/FullCanvas.tres"))
	FleetManager.owned_ships.append(owned)
	FleetManager.active_ship_index = 0

	var saved := FleetManager.get_save_data()
	FleetManager.owned_ships.clear()
	FleetManager.load_save_data(saved)

	assert_eq(FleetManager.owned_ships.size(), 1)
	assert_eq(FleetManager.owned_ships[0].level, 2)
	assert_eq(FleetManager.owned_ships[0].installed_modules.size(), 1)
	assert_eq(FleetManager.owned_ships[0].ship_stats.resource_path,
		"res://resources/ships/Galleon.tres")


func test_legacy_flat_path_save_format_still_loads():
	## Pre-M8 saves stored owned_ships as a flat Array of resource path Strings.
	FleetManager.owned_ships.clear()
	FleetManager.owned_captains.clear()
	FleetManager.active_missions.clear()

	FleetManager.load_save_data({
		"owned_ships": ["res://resources/ships/Sloop.tres"],
		"owned_captains": [],
		"active_ship_index": 0,
		"active_captain_index": 0,
	})

	assert_eq(FleetManager.owned_ships.size(), 1)
	assert_eq(FleetManager.owned_ships[0].level, 1, "A legacy entry has no level data — defaults to 1")
	assert_eq(FleetManager.owned_ships[0].installed_modules.size(), 0)
	assert_eq(FleetManager.owned_ships[0].ship_stats.resource_path, "res://resources/ships/Sloop.tres")

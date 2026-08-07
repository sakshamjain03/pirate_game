extends GutTest

# test_fleet_manager.gd
# Property-based tests for FleetManager (D12 coverage: Fleet).
# FleetManager, ResourceManager, and FactionManager are real autoloads whose
# mutable state this file touches (missions tick gold/reputation), so every
# test saves/restores all three.

var _saved_ships: Array
var _saved_captains: Array
var _saved_active_ship_index: int
var _saved_active_captain_index: int
var _saved_missions: Dictionary
var _saved_resources: Dictionary
var _saved_reputation: Dictionary

func before_each():
	_saved_ships = FleetManager.owned_ships.duplicate()
	_saved_captains = FleetManager.owned_captains.duplicate()
	_saved_active_ship_index = FleetManager.active_ship_index
	_saved_active_captain_index = FleetManager.active_captain_index
	_saved_missions = FleetManager.active_missions.duplicate(true)
	_saved_resources = ResourceManager.current_resources.duplicate()
	_saved_reputation = FactionManager.reputation_scores.duplicate()

func after_each():
	FleetManager.owned_ships = _saved_ships.duplicate()
	FleetManager.owned_captains = _saved_captains.duplicate()
	FleetManager.active_ship_index = _saved_active_ship_index
	FleetManager.active_captain_index = _saved_active_captain_index
	FleetManager.active_missions = _saved_missions.duplicate(true)
	ResourceManager.current_resources = _saved_resources.duplicate()
	FactionManager.reputation_scores = _saved_reputation.duplicate()

func _setup_two_ship_fleet() -> Dictionary:
	FleetManager.owned_ships.clear()
	FleetManager.owned_captains.clear()
	FleetManager.active_missions.clear()
	FleetManager.active_ship_index = 0
	FleetManager.active_captain_index = 0

	var ship_a = ShipStats.new()
	var ship_b = ShipStats.new()
	FleetManager.owned_ships.append(ship_a)
	FleetManager.owned_ships.append(ship_b)

	var captain = CaptainData.new()
	captain.level = 3
	captain.current_xp = 0
	FleetManager.owned_captains.append(captain)

	return {"ship_a": ship_a, "ship_b": ship_b, "captain": captain}

func test_add_ship_is_idempotent_for_the_same_resource():
	var ship = ShipStats.new()
	var before_count = FleetManager.owned_ships.size()
	watch_signals(FleetManager)

	FleetManager.add_ship(ship)
	FleetManager.add_ship(ship)

	assert_eq(FleetManager.owned_ships.size(), before_count + 1,
		"adding the same ship twice must not duplicate it")
	assert_signal_emit_count(FleetManager, "fleet_changed", 1,
		"fleet_changed must only fire for the genuinely new addition")

func test_add_captain_is_idempotent_for_the_same_resource():
	var captain = CaptainData.new()
	var before_count = FleetManager.owned_captains.size()
	watch_signals(FleetManager)

	FleetManager.add_captain(captain)
	FleetManager.add_captain(captain)

	assert_eq(FleetManager.owned_captains.size(), before_count + 1,
		"adding the same captain twice must not duplicate it")
	assert_signal_emit_count(FleetManager, "fleet_changed", 1)

func test_assign_mission_blocks_the_active_ship():
	var setup = _setup_two_ship_fleet()
	FleetManager.assign_mission(FleetManager.active_ship_index, 0, "trade")
	assert_false(FleetManager.is_on_mission(FleetManager.active_ship_index),
		"the player's active ship must never be assignable to a background mission")

func test_assign_and_unassign_mission_on_a_non_active_ship():
	var setup = _setup_two_ship_fleet()
	watch_signals(FleetManager)

	FleetManager.assign_mission(1, 0, "trade")
	assert_true(FleetManager.is_on_mission(1))
	assert_signal_emitted(FleetManager, "fleet_changed")

	FleetManager.unassign_mission(1)
	assert_false(FleetManager.is_on_mission(1))

func test_economy_tick_trade_mission_grants_gold_and_captain_xp():
	var setup = _setup_two_ship_fleet()
	var captain = setup["captain"]
	FleetManager.assign_mission(1, 0, "trade")

	ResourceManager.current_resources["gold"] = 0
	FleetManager._on_economy_tick()

	assert_eq(ResourceManager.get_resource("gold"), 10 * captain.level,
		"a trade mission must earn 10 * captain.level gold per tick")
	assert_eq(captain.current_xp, 10, "a trade mission must grant the assigned captain 10 xp per tick")

func test_economy_tick_patrol_mission_grants_merchant_reputation():
	var setup = _setup_two_ship_fleet()
	FleetManager.assign_mission(1, 0, "patrol")

	var rep_before = FactionManager.get_reputation("merchant_guild")
	FleetManager._on_economy_tick()

	assert_eq(FactionManager.get_reputation("merchant_guild"), rep_before + 1,
		"a patrol mission must earn 1 merchant_guild reputation per tick")

func test_save_load_round_trip():
	FleetManager.owned_ships.clear()
	FleetManager.owned_captains.clear()
	FleetManager.active_missions.clear()

	var dinghy = load("res://resources/ships/Dinghy.tres")
	var sloop = load("res://resources/ships/Sloop.tres")
	var jack = load("res://resources/captains/Jack.tres")
	FleetManager.owned_ships.append(dinghy)
	FleetManager.owned_ships.append(sloop)
	FleetManager.owned_captains.append(jack)
	FleetManager.active_ship_index = 1
	FleetManager.active_captain_index = 0
	FleetManager.assign_mission(0, 0, "patrol")

	var saved = FleetManager.get_save_data()

	FleetManager.owned_ships.clear()
	FleetManager.owned_captains.clear()
	FleetManager.active_missions.clear()
	FleetManager.active_ship_index = 0
	FleetManager.active_captain_index = 0

	FleetManager.load_save_data(saved)

	assert_eq(FleetManager.owned_ships.size(), 2)
	assert_eq(FleetManager.owned_captains.size(), 1)
	assert_eq(FleetManager.active_ship_index, 1)
	assert_eq(FleetManager.active_captain_index, 0)
	assert_true(FleetManager.is_on_mission(0), "mission assignments must survive save/load")
	assert_eq(FleetManager.active_missions[0]["mission_type"], "patrol")

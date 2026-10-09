extends GutTest
## M30 Wave 2 (2.7): hull identity. Missions, Defend Home and the saved active hull are keyed by
## OwnedShipData.uid, never by position in FleetManager.owned_ships (which shifts the moment a
## prize joins or a hull is dismantled). A schema-1 save (position keys, no uids) migrates to the
## uid form with missions, Defend Home and captain pairing intact. test_fleet_manager.gd's
## "purchases are idempotent" test is untouched: prizes (2.8) will be the duplicates.

const SLOOP := "res://resources/ships/Sloop.tres"
const DINGHY := "res://resources/ships/Dinghy.tres"
const SCHOONER := "res://resources/ships/Schooner.tres"
const JACK := "res://resources/captains/Jack.tres"

var _saved_ships: Array[OwnedShipData]
var _saved_captains: Array[CaptainData]
var _saved_missions: Dictionary
var _saved_defend: Array
var _saved_active_index: int
var _saved_captain_index: int
var _saved_unresolved: Array
var _saved_gold: int
var _saved_xp: int
var _saved_level: int


func before_each() -> void:
	_saved_ships = FleetManager.owned_ships.duplicate()
	_saved_captains = FleetManager.owned_captains.duplicate()
	_saved_missions = FleetManager.active_missions.duplicate(true)
	_saved_defend = FleetManager.defend_home_ship_uids.duplicate()
	_saved_active_index = FleetManager.active_ship_index
	_saved_captain_index = FleetManager.active_captain_index
	_saved_unresolved = FleetManager._unresolved_captains.duplicate()
	_saved_gold = ResourceManager.get_resource("gold")
	var jack: CaptainData = load(JACK)
	_saved_xp = jack.current_xp
	_saved_level = jack.level
	FleetManager.owned_ships.clear()
	FleetManager.owned_captains.clear()
	FleetManager.active_missions.clear()
	FleetManager.defend_home_ship_uids.clear()
	FleetManager.active_ship_index = 0
	FleetManager.active_captain_index = 0


func after_each() -> void:
	FleetManager.owned_ships = _saved_ships.duplicate()
	FleetManager.owned_captains = _saved_captains.duplicate()
	FleetManager.active_missions = _saved_missions.duplicate(true)
	FleetManager.defend_home_ship_uids = _saved_defend.duplicate()
	FleetManager.active_ship_index = _saved_active_index
	FleetManager.active_captain_index = _saved_captain_index
	FleetManager._unresolved_captains = _saved_unresolved.duplicate()
	var jack: CaptainData = load(JACK)
	jack.current_xp = _saved_xp
	jack.level = _saved_level
	ResourceManager.current_resources["gold"] = _saved_gold


func _owned(path: String) -> OwnedShipData:
	var o := OwnedShipData.new()
	o.ship_stats = load(path)
	return o


func _fleet_of(paths: Array) -> void:
	for p in paths:
		FleetManager.owned_ships.append(_owned(p))


# === Identity ===

func test_a_purchased_hull_gets_a_unique_uid() -> void:
	FleetManager.add_ship(load(SLOOP))
	FleetManager.add_ship(load(DINGHY))
	var a := FleetManager.owned_ships[0].uid
	var b := FleetManager.owned_ships[1].uid
	assert_ne(a, "")
	assert_ne(b, "")
	assert_ne(a, b)


func test_a_hull_appended_without_a_uid_is_given_one_lazily_and_keeps_it() -> void:
	_fleet_of([SLOOP, DINGHY])
	assert_eq(FleetManager.owned_ships[0].uid, "", "precondition: appended directly")
	var uid := FleetManager.uid_of(0)
	assert_ne(uid, "")
	assert_eq(FleetManager.uid_of(0), uid, "stable once assigned")
	assert_ne(FleetManager.uid_of(1), uid)
	assert_eq(FleetManager.uid_of(7), "", "no such hull")
	assert_eq(FleetManager.uid_of(-1), "")


func test_index_of_uid_and_lookup_follow_the_hull() -> void:
	_fleet_of([SLOOP, DINGHY])
	var uid := FleetManager.uid_of(1)
	assert_eq(FleetManager.index_of_uid(uid), 1)
	assert_same(FleetManager.get_ship_by_uid(uid), FleetManager.owned_ships[1])
	FleetManager.owned_ships.push_front(_owned(SCHOONER))
	assert_eq(FleetManager.index_of_uid(uid), 2, "it moved; its identity did not")
	assert_eq(FleetManager.index_of_uid("nope"), -1)
	assert_eq(FleetManager.index_of_uid(""), -1)


# === Missions and Defend Home follow the hull, not the slot ===

func test_a_mission_stays_with_its_hull_when_the_fleet_is_reordered() -> void:
	_fleet_of([SLOOP, DINGHY])
	FleetManager.owned_captains.append(load(JACK))
	FleetManager.assign_mission(1, 0, "patrol")
	assert_true(FleetManager.is_on_mission(1))
	var dinghy := FleetManager.owned_ships[1]

	FleetManager.owned_ships.push_front(_owned(SCHOONER))  # a prize joins at the front
	assert_false(FleetManager.is_on_mission(1), "slot 1 is now the Sloop, which has no mission")
	assert_false(FleetManager.is_on_mission(0))
	assert_true(FleetManager.is_on_mission(2), "the Dinghy, now at 2, still has its mission")
	assert_same(FleetManager.owned_ships[2], dinghy)
	assert_eq(FleetManager.get_mission_display_text(2), "Patrol")
	assert_eq(FleetManager.get_mission_display_text(1), "")


func test_defend_home_follows_the_hull() -> void:
	_fleet_of([SLOOP, DINGHY])
	FleetManager.set_defend_home(1, true)
	assert_true(FleetManager.is_defending_home(1))
	FleetManager.owned_ships.push_front(_owned(SCHOONER))
	assert_false(FleetManager.is_defending_home(1))
	assert_true(FleetManager.is_defending_home(2))
	assert_eq(FleetManager.get_ships_defending_home(), 1, "the Dinghy is not the active hull and not on a mission")
	FleetManager.set_defend_home(2, false)
	assert_false(FleetManager.is_defending_home(2))


func test_the_active_hull_cannot_run_a_mission() -> void:
	_fleet_of([SLOOP, DINGHY])
	FleetManager.owned_captains.append(load(JACK))
	FleetManager.assign_mission(0, 0, "trade")  # 0 is active
	assert_true(FleetManager.active_missions.is_empty())


func test_unassign_removes_the_mission_by_hull() -> void:
	_fleet_of([SLOOP, DINGHY])
	FleetManager.owned_captains.append(load(JACK))
	FleetManager.assign_mission(1, 0, "trade")
	FleetManager.unassign_mission(1)
	assert_false(FleetManager.is_on_mission(1))
	assert_true(FleetManager.active_missions.is_empty())


func test_a_trade_route_keeps_its_route_data_under_the_uid() -> void:
	_fleet_of([SLOOP, DINGHY])
	FleetManager.owned_captains.append(load(JACK))
	FleetManager.assign_trade_route(1, 0, "Spice Run", 3)
	var m := FleetManager.get_mission(1)
	assert_eq(m["mission_type"], "trade_route")
	assert_eq(m["region_tier"], 3)
	assert_eq(FleetManager.get_mission_display_text(1), "Spice Run")


# === Captain pairing ===

func test_a_mission_pairs_its_captain_by_id_and_pays_them() -> void:
	_fleet_of([SLOOP, DINGHY])
	var jack: CaptainData = load(JACK)
	FleetManager.owned_captains.append(load("res://resources/captains/%s" % _other_captain_file()))
	FleetManager.owned_captains.append(jack)
	FleetManager.assign_mission(1, 1, "trade")
	assert_eq(FleetManager.get_mission(1)["captain_id"], FleetManager.captain_key(jack))

	# The roster reorders; the pairing must still find Jack.
	FleetManager.owned_captains.reverse()
	var xp_before := jack.current_xp
	var gold_before: int = ResourceManager.get_resource("gold")
	FleetManager.on_economy_tick()
	assert_gt(jack.current_xp, xp_before, "Jack, not whoever is now at the old index, earned the XP")
	assert_gt(ResourceManager.get_resource("gold"), gold_before)


func _other_captain_file() -> String:
	var dir := DirAccess.open("res://resources/captains")
	for f in dir.get_files():
		if f.ends_with(".tres") and f != "Jack.tres":
			return f
	return "Jack.tres"


func test_an_id_less_captain_falls_back_to_its_index() -> void:
	_fleet_of([SLOOP, DINGHY])
	var anon := CaptainData.new()
	anon.level = 2
	FleetManager.owned_captains.append(anon)
	FleetManager.assign_mission(1, 0, "trade")
	var gold_before: int = ResourceManager.get_resource("gold")
	FleetManager.on_economy_tick()
	assert_eq(ResourceManager.get_resource("gold"), gold_before + 10 * 2, "paid by index when there is no id")


# === Saving ===

func test_the_save_carries_uids_and_no_position_keys() -> void:
	_fleet_of([SLOOP, DINGHY])
	FleetManager.owned_captains.append(load(JACK))
	FleetManager.assign_mission(1, 0, "patrol")
	FleetManager.set_defend_home(1, true)
	FleetManager.active_ship_index = 0
	var saved := FleetManager.get_save_data()
	for ship in saved["owned_ships"]:
		assert_ne(str(ship["uid"]), "")
	var uid1: String = saved["owned_ships"][1]["uid"]
	assert_true(saved["active_missions"].has(uid1))
	assert_eq(saved["defend_home_ship_uids"], [uid1])
	assert_false(saved.has("defend_home_ship_indices"))
	assert_eq(saved["active_ship_uid"], saved["owned_ships"][0]["uid"])


func test_a_uid_round_trips_through_save_and_load() -> void:
	_fleet_of([SLOOP, DINGHY])
	FleetManager.owned_captains.append(load(JACK))
	FleetManager.assign_mission(1, 0, "patrol")
	FleetManager.set_defend_home(1, true)
	var before_uids := [FleetManager.uid_of(0), FleetManager.uid_of(1)]
	var saved := JSON.parse_string(JSON.stringify(FleetManager.get_save_data()))  # as the disk sees it
	FleetManager.owned_ships.clear()
	FleetManager.active_missions.clear()
	FleetManager.defend_home_ship_uids.clear()
	FleetManager.load_save_data(saved)
	assert_eq([FleetManager.owned_ships[0].uid, FleetManager.owned_ships[1].uid], before_uids)
	assert_true(FleetManager.is_on_mission(1))
	assert_true(FleetManager.is_defending_home(1))


func test_the_active_hull_is_restored_by_uid_even_if_the_saved_order_differs() -> void:
	_fleet_of([SLOOP, DINGHY])
	FleetManager.active_ship_index = 1
	var saved := FleetManager.get_save_data()
	saved["owned_ships"].reverse()  # a cloud merge or hand edit reordered the hulls
	saved["active_ship_index"] = 0  # the stale index now points at the wrong hull
	FleetManager.load_save_data(saved)
	assert_eq(FleetManager.owned_ships[FleetManager.active_ship_index].ship_stats.resource_path, DINGHY,
		"the uid, not the saved position, picks the active hull")


# === Migrating a schema-1 save ===

## What FleetManager.get_save_data() wrote before this task (JSON-style: string keys).
func _old_fleet() -> Dictionary:
	return {
		"owned_ships": [
			{"ship_path": SLOOP, "level": 3, "modules": [], "components": {}},
			{"ship_path": DINGHY, "level": 1, "modules": [], "components": {}},
			{"ship_path": SCHOONER, "level": 2, "modules": [], "components": {}},
		],
		"owned_captains": [{"path": JACK, "level": 4, "current_xp": 12}],
		"active_ship_index": 0,
		"active_captain_index": 0,
		"active_missions": {"2": {"captain_index": 0, "mission_type": "trade", "timer": 0.0}},
		"defend_home_ship_indices": [1],
	}


func test_an_old_save_loads_with_uids_and_keeps_its_missions_and_captain_pairing() -> void:
	FleetManager.load_save_data(_old_fleet())
	assert_eq(FleetManager.owned_ships.size(), 3)
	for i in 3:
		assert_ne(FleetManager.owned_ships[i].uid, "", "every hull has a uid")
	assert_eq(FleetManager.owned_ships[0].level, 3, "progress is untouched")
	assert_true(FleetManager.is_on_mission(2), "the Schooner's mission followed it")
	assert_false(FleetManager.is_on_mission(1))
	assert_eq(FleetManager.get_mission(2)["mission_type"], "trade")
	var jack: CaptainData = load(JACK)
	assert_eq(FleetManager.get_mission(2)["captain_id"], FleetManager.captain_key(jack), "paired by id now")
	assert_true(FleetManager.is_defending_home(1), "Defend Home on the Dinghy is kept")
	assert_false(FleetManager.is_defending_home(0))
	assert_eq(FleetManager.active_ship_index, 0)
	# ...and the migrated mission still works.
	var gold_before: int = ResourceManager.get_resource("gold")
	FleetManager.on_economy_tick()
	assert_gt(ResourceManager.get_resource("gold"), gold_before)


func test_migration_is_deterministic_idempotent_and_does_not_touch_its_input() -> void:
	var old := _old_fleet()
	var snapshot := old.duplicate(true)
	var a := FleetManager.migrate_fleet_save(old)
	assert_eq(old, snapshot, "the input is not mutated")
	assert_eq(a["owned_ships"][0]["uid"], "legacy-0")
	assert_eq(a["owned_ships"][2]["uid"], "legacy-2")
	assert_true(a["active_missions"].has("legacy-2"))
	assert_eq(a["defend_home_ship_uids"], ["legacy-1"])
	assert_false(a.has("defend_home_ship_indices"))
	assert_eq(a["active_ship_uid"], "legacy-0")
	var b := FleetManager.migrate_fleet_save(a)
	assert_eq(b, a, "migrating an already-migrated fleet changes nothing")
	assert_eq(FleetManager.migrate_fleet_save(snapshot), a, "same input, same output on every device")


func test_a_mission_on_a_hull_that_no_longer_exists_is_dropped_by_the_migration() -> void:
	var old := _old_fleet()
	old["active_missions"]["9"] = {"captain_index": 0, "mission_type": "patrol", "timer": 0.0}
	var migrated := FleetManager.migrate_fleet_save(old)
	assert_eq(migrated["active_missions"].keys(), ["legacy-2"])


func test_flat_pre_m8_ship_paths_get_uids_and_keep_their_missions() -> void:
	var old := {
		"owned_ships": [SLOOP, DINGHY],
		"owned_captains": [JACK],
		"active_ship_index": 0,
		"active_missions": {"1": {"captain_index": 0, "mission_type": "trade", "timer": 0.0}},
	}
	FleetManager.load_save_data(old)
	assert_eq(FleetManager.owned_ships.size(), 2)
	assert_eq(FleetManager.owned_ships[1].uid, "legacy-1")
	assert_true(FleetManager.is_on_mission(1))


func test_schema_version_is_bumped_and_savemanager_runs_the_fleet_migration() -> void:
	assert_eq(SaveManager.SAVE_SCHEMA_VERSION, 2)
	var data := {"save_schema_version": 1, "fleet": _old_fleet(), "economy": {"gold": 5}}
	var migrated := SaveManager._migrate(data, 1)
	assert_eq(migrated["save_schema_version"], 2)
	assert_eq(migrated["fleet"]["owned_ships"][0]["uid"], "legacy-0")
	assert_true(migrated["fleet"]["active_missions"].has("legacy-2"))
	assert_eq(migrated["economy"], {"gold": 5}, "nothing else is touched")
	assert_eq(data["fleet"]["owned_ships"][0].has("uid"), false, "the source dictionary is not mutated")


func test_a_version_zero_save_still_migrates_all_the_way_through() -> void:
	var migrated := SaveManager._migrate({"fleet": _old_fleet(), "islands": {}}, 0)
	assert_eq(migrated["save_schema_version"], 2)
	assert_eq(migrated["fleet"]["owned_ships"][1]["uid"], "legacy-1")


func test_a_save_without_a_fleet_section_migrates_cleanly() -> void:
	var migrated := SaveManager._migrate({"save_schema_version": 1, "economy": {}}, 1)
	assert_eq(migrated["save_schema_version"], 2)
	assert_false(migrated.has("fleet"))

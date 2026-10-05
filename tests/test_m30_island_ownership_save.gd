extends GutTest
## M30 Wave 0 (0.1): island ownership was never saved. SaveManager wrote only
## `buildings`/`discovered` per island, so a captured or colonised island
## reverted to its authored owner on restart — it stopped producing, and the
## dock asked the player to colonise it again. These pin the entry shape, the
## pre-M30 migration, the unknown-faction resolver contract, and New Game.
##
## Islands here are bare stand-ins (Island.gd's _ready() needs a live World);
## restore_island_ownership()/island_save_entry() are the exact functions
## save_game()/load_game() call per island.

const SKULL_COVE := "res://resources/world/SkullCove.tres"


class FakeIsland extends Node:
	var island_data: IslandData
	var buildings: Array = []

	func get_island_id() -> String:
		return island_data.island_id

	func get_built_building_ids() -> Array:
		return buildings


var _data: IslandData
var _authored_type: int
var _authored_owner: Resource


func before_each() -> void:
	_data = load(SKULL_COVE)
	_authored_type = _data.island_type
	_authored_owner = _data.owner_faction


func after_each() -> void:
	_data.island_type = _authored_type
	_data.owner_faction = _authored_owner


func _island(data: IslandData, buildings: Array = []) -> FakeIsland:
	var island := FakeIsland.new()
	island.island_data = data
	island.buildings = buildings
	autofree(island)
	return island


func _fresh_neutral() -> IslandData:
	var d := IslandData.new()
	d.island_id = "test_isle"
	d.island_type = IslandData.IslandType.NEUTRAL
	return d


func test_captured_island_round_trips() -> void:
	var island := _island(_data, ["farm_l1"])
	_data.island_type = IslandData.IslandType.FRIENDLY
	_data.owner_faction = FactionManager.get_player_faction()
	var entry := SaveManager.island_save_entry(island)
	assert_eq(entry.get("island_type"), int(IslandData.IslandType.FRIENDLY))
	assert_eq(entry.get("owner_faction_id"), "player")

	# Restart: the cached resource is back to its authored (ENEMY, pirate_clans) state.
	_data.island_type = _authored_type
	_data.owner_faction = _authored_owner
	SaveManager.restore_island_ownership(island, JSON.parse_string(JSON.stringify(entry)), "")
	assert_eq(_data.island_type, IslandData.IslandType.FRIENDLY, "capture lost on reload")
	assert_true(_data.is_owned_by_player(), "a captured island must produce after reload")
	assert_eq(_data.owner_faction, FactionManager.get_player_faction(),
		"owner must be the shared FactionData, not a copy")


func test_unowned_island_saves_no_owner_and_restores_none() -> void:
	var d := _fresh_neutral()
	var entry := SaveManager.island_save_entry(_island(d))
	assert_false(entry.has("owner_faction_id"), "no owner means no key, not an empty one")
	d.owner_faction = FactionManager.get_player_faction()
	SaveManager.restore_island_ownership(_island(d), entry, "")
	assert_null(d.owner_faction)


func test_pre_m30_entry_with_buildings_migrates_to_friendly() -> void:
	var d := _fresh_neutral()
	SaveManager.restore_island_ownership(_island(d), {"buildings": ["farm_l1"], "discovered": true}, "")
	assert_eq(d.island_type, IslandData.IslandType.FRIENDLY)
	assert_eq(d.owner_faction, FactionManager.get_player_faction())


func test_pre_m10_flat_array_entry_migrates_too() -> void:
	var d := _fresh_neutral()
	SaveManager.restore_island_ownership(_island(d), ["farm_l1"], "")
	assert_eq(d.island_type, IslandData.IslandType.FRIENDLY)


func test_pre_m30_home_island_migrates_without_buildings() -> void:
	var d := _fresh_neutral()
	SaveManager.restore_island_ownership(_island(d), {"buildings": []}, "test_isle")
	assert_eq(d.island_type, IslandData.IslandType.FRIENDLY)


func test_pre_m30_empty_entry_keeps_authored_owner() -> void:
	SaveManager.restore_island_ownership(_island(_data), {"buildings": [], "discovered": true}, "")
	assert_eq(_data.island_type, _authored_type)
	assert_eq(_data.owner_faction, _authored_owner)


func test_migration_never_downgrades_a_capital() -> void:
	var d := _fresh_neutral()
	d.island_type = IslandData.IslandType.CAPITAL
	SaveManager.restore_island_ownership(_island(d), {"buildings": ["farm_l1"]}, "")
	assert_eq(d.island_type, IslandData.IslandType.CAPITAL)


func test_unknown_faction_keeps_authored_owner() -> void:
	# push_errors by design (resolvers never skip silently); GUT 9.4 has no
	# error tracker, so this pins the state the error accompanies.
	SaveManager.restore_island_ownership(_island(_data),
		{"island_type": int(IslandData.IslandType.ENEMY), "owner_faction_id": "no_such_faction"}, "")
	assert_eq(_data.owner_faction, _authored_owner)


func test_new_game_restores_authored_ownership() -> void:
	_data.island_type = IslandData.IslandType.FRIENDLY
	_data.owner_faction = FactionManager.get_player_faction()
	SaveManager._restore_authored_island_ownership()
	assert_eq(_data.island_type, IslandData.IslandType.ENEMY)
	assert_not_null(_data.owner_faction)
	assert_eq(_data.owner_faction.faction_id, "pirate_clans")
	assert_eq(_data.owner_faction, _authored_owner, "must be the shared FactionData")


func test_list_resource_paths_sees_exported_remaps() -> void:
	var paths := ResourceLookup.list_resource_paths("res://resources/world/")
	assert_has(paths, SKULL_COVE)
	for p in paths:
		assert_true(p.ends_with(".tres"), "%s is not a .tres path" % p)

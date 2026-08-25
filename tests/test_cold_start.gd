extends GutTest

# test_cold_start.gd
# D58: a genuinely new game started owning no island and no production, gated
# behind a 1000-gold colonize cost against a 200-gold starting purse.
# World._seed_port_royal_as_home() closes this on a real new game only —
# guarded on "no save file exists", never "home_island_id happens to be empty",
# so an existing save with a different home island is never overwritten.

class MockIsland extends Node:
	var island_data: IslandData
	var _id: String
	func _init(id: String) -> void:
		_id = id
		island_data = IslandData.new()
		island_data.island_id = id
	func get_island_id() -> String:
		return _id

var _world
var _saved_home_island_id: String

var _backup_path := "user://save_data_test_backup.json"
var _had_backup := false

func before_each():
	# World.gd's _ready() unconditionally defers a real SaveManager.load_game()
	# call (line 32-34) regardless of has_save_data() at line 28 — so whatever
	# is actually on disk gets applied to the real EmpireManager/SaveManager
	# autoloads. Region activation is sticky (EmpireManager._check_region_activation
	# only ever sets true, never false), so a stale save with real notoriety
	# would otherwise permanently poison EmpireManager for every test that runs
	# after this one in the same suite. Back up/restore around this test, same
	# pattern as test_save_manager_offline.gd / test_region_gates.gd.
	if SaveManager.has_save_data():
		_had_backup = true
		var src = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
		var dst = FileAccess.open(_backup_path, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		SaveManager.delete_save()

	_world = load("res://scripts/world/World.gd").new()
	add_child_autoqfree(_world)
	_saved_home_island_id = EmpireManager.home_island_id
	EmpireManager.home_island_id = ""

func after_each():
	EmpireManager.home_island_id = _saved_home_island_id

	var dir = DirAccess.open("user://")
	if _had_backup:
		var src = FileAccess.open(_backup_path, FileAccess.READ)
		var dst = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		dir.remove("save_data_test_backup.json")
	else:
		SaveManager.delete_save()
	_had_backup = false


func test_seeding_grants_port_royal_as_capital_and_sets_home():
	var port_royal := MockIsland.new("port_royal")
	var tortuga := MockIsland.new("tortuga")

	_world._seed_port_royal_as_home([port_royal, tortuga])

	assert_eq(port_royal.island_data.island_type, IslandData.IslandType.CAPITAL,
		"Port Royal must become the capital on a new game")
	assert_not_null(port_royal.island_data.owner_faction,
		"Port Royal must be owned by the player faction")
	assert_eq(port_royal.island_data.owner_faction.faction_id, "player")
	assert_eq(EmpireManager.home_island_id, "port_royal")
	assert_eq(tortuga.island_data.island_type, IslandData.IslandType.NEUTRAL,
		"Only Port Royal is touched, not every island in the list")


func test_seeding_is_a_no_op_without_a_port_royal_island_in_the_list():
	var tortuga := MockIsland.new("tortuga")
	_world._seed_port_royal_as_home([tortuga])
	assert_eq(EmpireManager.home_island_id, "",
		"With no port_royal island present, nothing should be set")

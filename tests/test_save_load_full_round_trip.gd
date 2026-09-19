extends GutTest

## BUG_REPORT.md #36 -- individual managers each have their own save/load
## round-trip test, but nothing exercises a real SaveManager.save_game() /
## load_game() pass across all of them together. This drives distinct state
## into Economy, Fleet, Tech, Faction, and Empire, does one real save/load
## round trip, and checks every system landed correctly in the same pass --
## the way a real player's save actually works, not one system at a time.

var _backup_path := "user://save_data_test_backup.json"
var _save_backup_path := "user://save_data_test_backup.json.bak"
var _had_backup := false
var _had_save_backup := false

var _saved_resources: Dictionary
var _saved_ships: Array
var _saved_captains: Array
var _saved_active_ship_index: int
var _saved_active_captain_index: int
var _saved_unlocked_techs: Array
var _saved_reputation: Dictionary
var _saved_notoriety: float
var _saved_home_island_id: String


func before_each():
	if SaveManager.has_save_data():
		_had_backup = true
		var src = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
		var dst = FileAccess.open(_backup_path, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
	if FileAccess.file_exists(SaveManager.BACKUP_PATH):
		_had_save_backup = true
		var backup_src = FileAccess.open(SaveManager.BACKUP_PATH, FileAccess.READ)
		var backup_dst = FileAccess.open(_save_backup_path, FileAccess.WRITE)
		backup_dst.store_string(backup_src.get_as_text())
		backup_src.close()
		backup_dst.close()

	_saved_resources = ResourceManager.current_resources.duplicate()
	_saved_ships = FleetManager.owned_ships.duplicate()
	_saved_captains = FleetManager.owned_captains.duplicate()
	_saved_active_ship_index = FleetManager.active_ship_index
	_saved_active_captain_index = FleetManager.active_captain_index
	_saved_unlocked_techs = TechManager.unlocked_techs.duplicate()
	_saved_reputation = FactionManager.reputation_scores.duplicate()
	_saved_notoriety = EmpireManager.notoriety
	_saved_home_island_id = EmpireManager.home_island_id


func after_each():
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
	if _had_save_backup:
		var backup_src = FileAccess.open(_save_backup_path, FileAccess.READ)
		var backup_dst = FileAccess.open(SaveManager.BACKUP_PATH, FileAccess.WRITE)
		backup_dst.store_string(backup_src.get_as_text())
		backup_src.close()
		backup_dst.close()
		dir.remove("save_data_test_backup.json.bak")
	_had_backup = false
	_had_save_backup = false

	ResourceManager.current_resources = _saved_resources.duplicate()
	FleetManager.owned_ships = _saved_ships.duplicate()
	FleetManager.owned_captains = _saved_captains.duplicate()
	FleetManager.active_ship_index = _saved_active_ship_index
	FleetManager.active_captain_index = _saved_active_captain_index
	TechManager.unlocked_techs = _saved_unlocked_techs.duplicate()
	FactionManager.reputation_scores = _saved_reputation.duplicate()
	EmpireManager.notoriety = _saved_notoriety
	EmpireManager.home_island_id = _saved_home_island_id


func test_save_and_load_round_trips_every_system_together():
	# Economy
	ResourceManager.current_resources["gold"] = 4321
	ResourceManager.current_resources["wood"] = 77

	# Fleet
	FleetManager.owned_ships.clear()
	FleetManager.owned_captains.clear()
	var sloop_owned := OwnedShipData.new()
	sloop_owned.ship_stats = load("res://resources/ships/Sloop.tres")
	sloop_owned.level = 3
	FleetManager.owned_ships.append(sloop_owned)
	# Captains are persisted by resource_path (FleetManager.get_save_data()), so
	# the fixture must use the loaded resource directly -- a .duplicate() has
	# an empty resource_path and can never round-trip.
	var captain: CaptainData = load("res://resources/captains/Jack.tres")
	FleetManager.owned_captains.append(captain)
	FleetManager.active_ship_index = 0
	FleetManager.active_captain_index = 0

	# Tech
	var tech: Resource = load("res://resources/techs/AdvancedCannons.tres")
	TechManager.unlocked_techs = [tech]

	# Faction
	FactionManager.reputation_scores["royal_navy"] = -42

	# Empire
	EmpireManager.notoriety = 88.0
	EmpireManager.home_island_id = "port_royal"

	SaveManager.save_game()

	# Clear every system before loading, so a passing test can only mean the
	# load path actually restored it -- not that state was simply untouched.
	ResourceManager.current_resources = {"gold": 0, "wood": 0, "iron": 0, "rum": 0, "research": 0}
	FleetManager.owned_ships.clear()
	FleetManager.owned_captains.clear()
	FleetManager.active_ship_index = -1
	FleetManager.active_captain_index = -1
	TechManager.unlocked_techs.clear()
	FactionManager.reputation_scores.clear()
	EmpireManager.notoriety = 0.0
	EmpireManager.home_island_id = ""

	SaveManager.load_game()

	assert_eq(ResourceManager.get_resource("gold"), 4321, "Economy state must round-trip")
	assert_eq(ResourceManager.get_resource("wood"), 77, "Economy state must round-trip")

	assert_eq(FleetManager.owned_ships.size(), 1, "Fleet ships must round-trip")
	assert_eq(FleetManager.owned_ships[0].level, 3, "Ship level must round-trip")
	assert_eq(FleetManager.owned_captains.size(), 1, "Fleet captains must round-trip")

	assert_eq(TechManager.unlocked_techs.size(), 1, "Unlocked techs must round-trip")

	assert_eq(FactionManager.get_reputation("royal_navy"), -42, "Faction reputation must round-trip")

	assert_eq(EmpireManager.notoriety, 88.0, "Empire notoriety must round-trip")
	assert_eq(EmpireManager.home_island_id, "port_royal", "Empire home_island_id must round-trip")

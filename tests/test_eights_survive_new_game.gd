extends GutTest

## Owner decision 2026-09-30: Pieces of Eight a player holds — bought or earned —
## must never expire or be deleted. Starting over ends the empire, not the wallet.
## Covers every way the balance could have been lost:
##   - New Game with the campaign not yet loaded this session (fresh launch -> menu)
##   - New Game after playing (memory is the live wallet)
##   - Eights waiting in the pending file (Maelstrom / menu purchase before a save)
##   - choosing "Keep Cloud" over a local save that holds more Eights
## and the farm that carrying Eights over would otherwise open: chapter Eights pay
## once per install, not once per New Game.

const EIGHTS := "eights"
const LEDGER_TEST_PATH := "user://eights_ledger_test.json"
const USER_FILES := ["user://save_data.json", "user://save_data.json.bak",
	"user://maelstrom_pending.json", LEDGER_TEST_PATH]
const MANAGERS := ["ResourceManager", "FleetManager", "TechManager", "FactionManager",
	"EmpireManager", "CampaignManager", "SeasonalEventManager"]

var _file_backup := {}
var _managers_before := {}
var _wallet_loaded_before: bool
var _pending_claimed_before: bool
var _ledger_path_before: String
var _ledger_before: Dictionary
var _tutorial_before: Dictionary


func before_each() -> void:
	_file_backup.clear()
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			_file_backup[path] = FileAccess.get_file_as_string(path)
			DirAccess.remove_absolute(path)
	for m in MANAGERS:
		_managers_before[m] = get_tree().root.get_node(m).get_save_data().duplicate(true)
	_wallet_loaded_before = SaveManager._wallet_loaded_this_session
	_pending_claimed_before = SaveManager._maelstrom_pending_claimed
	_ledger_path_before = CampaignManager.eights_ledger_path
	_ledger_before = CampaignManager._chapter_eights_paid.duplicate()
	CampaignManager.eights_ledger_path = LEDGER_TEST_PATH
	CampaignManager._chapter_eights_paid.clear()
	_tutorial_before = TutorialManager.get_save_data().duplicate(true)


func after_each() -> void:
	for m in MANAGERS:
		get_tree().root.get_node(m).load_save_data(_managers_before[m].duplicate(true))
	SaveManager._wallet_loaded_this_session = _wallet_loaded_before
	SaveManager._maelstrom_pending_claimed = _pending_claimed_before
	CampaignManager.eights_ledger_path = _ledger_path_before
	CampaignManager._chapter_eights_paid = _ledger_before
	TutorialManager.load_save_data(_tutorial_before)
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if _file_backup.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(_file_backup[path])
			f.close()


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _save_with_eights(eights: int) -> void:
	_write_json(SaveManager.SAVE_PATH, {
		"save_schema_version": SaveManager.SAVE_SCHEMA_VERSION,
		"economy": {"gold": 900, "wood": 50, "iron": 20, "rum": 10, "research": 0, EIGHTS: eights},
		"last_saved_unix": 1000,
	})


## What the first World entry after New Game sees: no save, so load_game()
## takes its no-save path and claims the pending file.
func _enter_world_after_new_game() -> int:
	SaveManager.load_game()
	return ResourceManager.get_resource(EIGHTS)


# --------------------------------------------------------------- New Game

func test_new_game_from_a_fresh_launch_keeps_the_saved_eights() -> void:
	# Fresh launch -> main menu: the campaign has not been loaded, memory is 0.
	_save_with_eights(480)
	SaveManager._wallet_loaded_this_session = false
	ResourceManager.current_resources[EIGHTS] = 0
	assert_eq(SaveManager.eights_balance(), 480)
	assert_true(SaveManager.begin_new_game(true))
	assert_false(SaveManager.has_save_data(), "the empire is deleted")
	assert_eq(_enter_world_after_new_game(), 480, "the wallet is not")


func test_new_game_after_playing_keeps_the_live_balance() -> void:
	# Memory holds Eights earned since the last autosave.
	_save_with_eights(100)
	SaveManager._wallet_loaded_this_session = true
	ResourceManager.current_resources[EIGHTS] = 135
	assert_true(SaveManager.begin_new_game(true))
	assert_eq(_enter_world_after_new_game(), 135)


func test_new_game_folds_in_pending_eights_exactly_once() -> void:
	_save_with_eights(200)
	_write_json(SaveManager.MAELSTROM_PENDING_PATH, {"eights": 25})
	SaveManager._wallet_loaded_this_session = false
	ResourceManager.current_resources[EIGHTS] = 0
	assert_true(SaveManager.begin_new_game(true))
	assert_eq(_enter_world_after_new_game(), 225, "save + pending, not doubled")


func test_new_game_still_resets_the_empire() -> void:
	_save_with_eights(50)
	SaveManager._wallet_loaded_this_session = true
	ResourceManager.current_resources["gold"] = 4321
	ResourceManager.current_resources[EIGHTS] = 50
	assert_true(SaveManager.begin_new_game(true))
	_enter_world_after_new_game()
	assert_eq(ResourceManager.get_resource("gold"), 200, "gold is empire, not wallet")
	assert_eq(ResourceManager.get_resource(EIGHTS), 50)


func test_the_no_save_load_path_never_adds_pending_on_top_of_memory() -> void:
	# A menu purchase with no save credits memory AND the pending file; entering
	# World must count it once.
	_write_json(SaveManager.MAELSTROM_PENDING_PATH, {"eights": 80})
	ResourceManager.current_resources[EIGHTS] = 80
	SaveManager.load_game()
	assert_eq(ResourceManager.get_resource(EIGHTS), 80)


# ------------------------------------------------------------------- cloud

func test_keeping_the_cloud_empire_never_costs_local_eights() -> void:
	_save_with_eights(700)          # bought on this device since the last sync
	SaveManager._wallet_loaded_this_session = false
	SaveManager._apply_cloud_save({"save_data": {
		"save_schema_version": SaveManager.SAVE_SCHEMA_VERSION,
		"economy": {"gold": 3000, EIGHTS: 150},
		"last_saved_unix": 2000,
	}})
	var economy: Dictionary = _read_json(SaveManager.SAVE_PATH).get("economy", {})
	assert_eq(int(economy.get("gold", 0)), 3000, "the cloud empire is kept")
	assert_eq(int(economy.get(EIGHTS, 0)), 700, "the local wallet is not lost")


func test_keeping_the_cloud_takes_its_eights_when_they_are_higher() -> void:
	_save_with_eights(40)
	_write_json(SaveManager.MAELSTROM_PENDING_PATH, {"eights": 10})
	SaveManager._wallet_loaded_this_session = false
	SaveManager._apply_cloud_save({"save_data": {"economy": {EIGHTS: 900}, "last_saved_unix": 2000}})
	assert_eq(int(_read_json(SaveManager.SAVE_PATH)["economy"][EIGHTS]), 900)
	assert_false(_read_json(SaveManager.MAELSTROM_PENDING_PATH).has("eights"),
		"pending is folded in, so load_game() can't add it again")


# ------------------------------------------------------------- the farm

func _chapter_with_eights(id: String, eights: int) -> ChapterData:
	var chapter := ChapterData.new()
	chapter.chapter_id = id
	chapter.reward_eights = eights
	return chapter


func test_chapter_eights_pay_once_per_install_not_once_per_new_game() -> void:
	ResourceManager.current_resources[EIGHTS] = 0
	var ch1 := _chapter_with_eights("m_test_ch1", 10)
	CampaignManager._grant_rewards(ch1)
	assert_eq(ResourceManager.get_resource(EIGHTS), 10)
	# A New Game replays Chapter 1: the empire rewards come back, the Eights don't.
	CampaignManager._grant_rewards(ch1)
	assert_eq(ResourceManager.get_resource(EIGHTS), 10)
	assert_true(CampaignManager.has_paid_chapter_eights("m_test_ch1"))


func test_the_chapter_ledger_persists_to_disk() -> void:
	CampaignManager._grant_rewards(_chapter_with_eights("m_test_ch2", 15))
	CampaignManager._chapter_eights_paid.clear()
	CampaignManager._load_eights_ledger()
	assert_true(CampaignManager.has_paid_chapter_eights("m_test_ch2"))


# ------------------------------------------------------------- main menu

func test_with_a_save_the_main_menu_offers_only_continue() -> void:
	_save_with_eights(0)
	var menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	assert_true(menu.continue_button.visible)
	assert_false(menu.new_game_button.visible,
		"one empire you keep building: starting over lives in Settings")


func test_without_a_save_the_main_menu_offers_new_game() -> void:
	var menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	assert_true(menu.new_game_button.visible)
	assert_false(menu.continue_button.visible)

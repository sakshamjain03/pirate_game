extends GutTest

# test_chapter1_playthrough.gd
# M7 Task 21's mechanical half: drives the REAL Chapter 1 resource end to end
# through CampaignManager, firing the actual signals a real playthrough would
# (dock, build x4, destroy 3 pirates, recruit a captain), confirming every
# objective tracks and the chapter completes with its authored reward. The
# manual half (does it *feel* right in ~25-40 min without a wiki) needs a
# human at the controls, per this project's standing precedent for
# interactive-only verification.

var _saved_index: int
var _saved_completed: Array
var _saved_progress: Dictionary
var _saved_completed_objectives: Array
var _saved_resources: Dictionary

class MockShip extends Node3D:
	var faction: Resource = null

func before_each():
	_saved_index = CampaignManager.current_chapter_index
	_saved_completed = CampaignManager.completed_chapter_ids.duplicate()
	_saved_progress = CampaignManager._objective_progress.duplicate()
	_saved_completed_objectives = CampaignManager._completed_objective_ids.duplicate()
	_saved_resources = ResourceManager.current_resources.duplicate()

	# Start clean, as a genuinely new game would.
	CampaignManager.current_chapter_index = -1
	CampaignManager.completed_chapter_ids.clear()
	CampaignManager._objective_progress.clear()
	CampaignManager._completed_objective_ids.clear()
	CampaignManager._catch_up()

func after_each():
	CampaignManager.current_chapter_index = _saved_index
	CampaignManager.completed_chapter_ids = _saved_completed.duplicate()
	CampaignManager._objective_progress = _saved_progress.duplicate()
	CampaignManager._completed_objective_ids = _saved_completed_objectives.duplicate()
	ResourceManager.current_resources = _saved_resources.duplicate()


func test_chapter_1_starts_immediately_on_a_new_game():
	var chapter := CampaignManager._current_chapter()
	assert_not_null(chapter, "Chapter 1 has no gate — it must be current from the first frame")
	assert_eq(chapter.chapter_id, "ch1_the_drowned_port")
	assert_eq(chapter.objectives.size(), 8)


func test_playing_chapter_1_for_real_completes_it_with_its_authored_reward():
	watch_signals(CampaignManager)
	var gold_before: int = int(ResourceManager.current_resources.get("gold", 0))

	# 1.1 dock at Port Royal
	CampaignManager._on_player_docked("port_royal")
	# 1.2-1.4, 1.6 build the four required structures
	CampaignManager._on_structure_changed("farm_l1", false)
	CampaignManager._on_structure_changed("lumber_mill_l1", false)
	CampaignManager._on_structure_changed("warehouse_l1", false)
	CampaignManager._on_structure_changed("tavern_l1", false)
	# 1.5 sink 3 Pirate Clan hulls
	var pirate_faction := load("res://resources/factions/PirateClans.tres")
	for i in range(3):
		var ship := MockShip.new()
		ship.faction = pirate_faction
		add_child_autoqfree(ship)
		CampaignManager._on_ship_destroyed(ship)
	# 1.7 recruit a captain
	CampaignManager._on_captain_recruited(null)

	assert_true(CampaignManager.is_chapter_completed("ch1_the_drowned_port"),
		"All non-optional objectives are done — the chapter must complete")
	assert_signal_emitted(CampaignManager, "chapter_completed")
	assert_gt(int(ResourceManager.current_resources.get("gold", 0)), gold_before,
		"Chapter 1's authored reward_gold must actually reach the player")


func test_the_optional_tier_objective_does_not_block_completion():
	CampaignManager._on_player_docked("port_royal")
	CampaignManager._on_structure_changed("farm_l1", false)
	CampaignManager._on_structure_changed("lumber_mill_l1", false)
	CampaignManager._on_structure_changed("warehouse_l1", false)
	CampaignManager._on_structure_changed("tavern_l1", false)
	var pirate_faction := load("res://resources/factions/PirateClans.tres")
	for i in range(3):
		var ship := MockShip.new()
		ship.faction = pirate_faction
		add_child_autoqfree(ship)
		CampaignManager._on_ship_destroyed(ship)
	CampaignManager._on_captain_recruited(null)

	assert_true(CampaignManager.is_chapter_completed("ch1_the_drowned_port"),
		"1.8 (optional: reach tier 2) was never touched, and must not block completion")


func test_completing_chapter_1_hands_off_to_chapter_2():
	CampaignManager._on_player_docked("port_royal")
	CampaignManager._on_structure_changed("farm_l1", false)
	CampaignManager._on_structure_changed("lumber_mill_l1", false)
	CampaignManager._on_structure_changed("warehouse_l1", false)
	CampaignManager._on_structure_changed("tavern_l1", false)
	var pirate_faction := load("res://resources/factions/PirateClans.tres")
	for i in range(3):
		var ship := MockShip.new()
		ship.faction = pirate_faction
		add_child_autoqfree(ship)
		CampaignManager._on_ship_destroyed(ship)
	CampaignManager._on_captain_recruited(null)

	var chapter := CampaignManager._current_chapter()
	assert_not_null(chapter, "Chapter 2 has no gate beyond ch1's completion — it must become current")
	assert_eq(chapter.chapter_id, "ch2_blood_in_the_shallows")

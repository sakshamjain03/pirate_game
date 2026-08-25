extends GutTest

# test_tutorial_manager.gd
# TutorialManager is now a thin wrapper (M7 Task 10): it no longer drives an
# 8-step dialogue sequence — Chapter 1's own opening/closing beats
# (docs/13_CAMPAIGN_LEVELS_1-5.md §3) took over that narrative role. What
# remains is UI-tab unlock tracking, driven by CampaignManager's objective/
# chapter signals, plus the one-time completion flag.
#
# Uses a fresh instance of the script (like test_empire_manager.gd) rather
# than the global autoload singleton, so these tests can't interfere with any
# real gameplay session's tutorial state.
#
# IMPORTANT: TutorialManager.COMPLETION_PATH is a hardcoded user:// path
# shared by every instance (fresh test instances included), not just the real
# autoload singleton. Tests here call skip_tutorial()/reset_and_replay(),
# which write to that real file — so before_all/after_all back up and restore
# whatever was on disk, otherwise running this suite permanently marks the
# real game's tutorial as completed on the test machine.

const _COMPLETION_PATH := "user://tutorial_state.json"

var tm: Node
var _real_completion_existed: bool = false
var _real_completion_backup: String = ""

func before_all():
	_real_completion_existed = FileAccess.file_exists(_COMPLETION_PATH)
	if _real_completion_existed:
		var file := FileAccess.open(_COMPLETION_PATH, FileAccess.READ)
		if file:
			_real_completion_backup = file.get_as_text()
			file.close()

func after_all():
	if _real_completion_existed:
		var file := FileAccess.open(_COMPLETION_PATH, FileAccess.WRITE)
		if file:
			file.store_string(_real_completion_backup)
			file.close()
	elif FileAccess.file_exists(_COMPLETION_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("tutorial_state.json")

func before_each():
	tm = load("res://scripts/managers/TutorialManager.gd").new()
	add_child_autoqfree(tm)
	await wait_process_frames(1)
	# Force deterministic starting state regardless of any real
	# user://tutorial_state.json left over on the test machine.
	tm.tutorial_completed = false
	tm.tutorial_active = false
	tm._unlocked_ui.clear()

func test_start_new_game_session_arms_tutorial_when_not_completed():
	tm.start_new_game_session()
	assert_true(tm.tutorial_active, "a never-completed tutorial must arm on New Game")
	assert_eq(tm._unlocked_ui.size(), 0)

func test_start_new_game_session_skips_when_already_completed():
	tm.tutorial_completed = true
	tm.start_new_game_session()
	assert_false(tm.tutorial_active, "a completed tutorial must not replay on New Game")

func test_is_ui_unlocked_true_when_tutorial_not_active():
	tm.tutorial_active = false
	assert_true(tm.is_ui_unlocked("tab_fleet"),
		"once the tutorial isn't active (finished, skipped, or never started), all UI reads as unlocked")

func test_is_ui_unlocked_false_for_a_locked_id_while_active():
	tm.tutorial_active = true
	assert_false(tm.is_ui_unlocked("tab_fleet"), "a freshly-armed tutorial must start with no unlocked tabs")

func test_completing_the_recruit_objective_unlocks_the_fleet_tab():
	tm.start_new_game_session()
	assert_false(tm.is_ui_unlocked("tab_fleet"), "Precondition: locked")

	tm._on_objective_completed("1.7")  # docs/13 §3: "Sign your first captain"

	assert_true(tm.is_ui_unlocked("tab_fleet"))
	assert_false(tm.is_ui_unlocked("tab_research"), "an unrelated objective must not unlock other tabs")

func test_completing_the_combat_objective_unlocks_the_research_tab():
	tm.start_new_game_session()
	tm._on_objective_completed("1.5")  # docs/13 §3: "Sink whatever comes sniffing"
	assert_true(tm.is_ui_unlocked("tab_research"))

func test_an_unmapped_objective_id_unlocks_nothing():
	tm.start_new_game_session()
	tm._on_objective_completed("2.3")  # a Chapter 2 objective, not in the unlock map
	assert_eq(tm._unlocked_ui.size(), 0)

func test_completing_chapter_1_unlocks_trade_and_finishes_onboarding():
	tm.start_new_game_session()
	watch_signals(tm)

	var ch1 := ChapterData.new()
	ch1.chapter_id = "ch1_the_drowned_port"
	tm._on_chapter_completed(ch1)

	assert_true(tm.is_ui_unlocked("tab_trade"),
		"the old 'capture' step's unlock has no successor objective — it moves to chapter completion")
	assert_true(tm.tutorial_completed)
	assert_false(tm.tutorial_active)
	assert_signal_emitted(tm, "tutorial_finished")

func test_completing_a_later_chapter_does_not_replay_the_finished_signal():
	tm.start_new_game_session()
	var ch1 := ChapterData.new()
	ch1.chapter_id = "ch1_the_drowned_port"
	tm._on_chapter_completed(ch1)
	watch_signals(tm)

	var ch2 := ChapterData.new()
	ch2.chapter_id = "ch2_blood_in_the_shallows"
	tm._on_chapter_completed(ch2)

	assert_signal_not_emitted(tm, "tutorial_finished",
		"onboarding is already finished — a later chapter must not re-fire it")

func test_skip_tutorial_completes_immediately_and_unlocks_all_ui():
	tm.start_new_game_session()
	tm.skip_tutorial()

	assert_true(tm.tutorial_completed)
	assert_false(tm.tutorial_active)
	assert_true(tm.is_ui_unlocked("tab_fleet"))
	assert_true(tm.is_ui_unlocked("tab_research"))
	assert_true(tm.is_ui_unlocked("tab_trade"))

func test_save_load_round_trip():
	tm.start_new_game_session()
	tm._on_objective_completed("1.7")

	var saved = tm.get_save_data()

	var tm2 = load("res://scripts/managers/TutorialManager.gd").new()
	add_child_autoqfree(tm2)
	tm2.load_save_data(saved)

	assert_true(tm2.tutorial_active)
	assert_true(tm2.is_ui_unlocked("tab_fleet"), "unlocked UI ids must survive save/load")
	assert_false(tm2.is_ui_unlocked("tab_research"), "ids not yet unlocked must not leak in")

func test_reset_and_replay_rearms_a_completed_tutorial():
	tm.tutorial_completed = true
	tm.reset_and_replay()

	assert_false(tm.tutorial_completed)
	assert_true(tm.tutorial_active)
	assert_eq(tm._unlocked_ui.size(), 0)

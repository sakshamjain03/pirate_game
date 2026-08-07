extends GutTest

# test_tutorial_manager.gd
# Property-based tests for TutorialManager (light onboarding tutorial FSM).
# Uses a fresh instance of the script (like test_empire_manager.gd) rather
# than the global autoload singleton, so these tests can't interfere with
# any real gameplay session's tutorial state.
#
# IMPORTANT: TutorialManager.COMPLETION_PATH is a hardcoded user:// path
# shared by every instance (fresh test instances included), not just the
# real autoload singleton. Tests here call skip_tutorial()/reset_and_replay(),
# which write to that real file — so before_all/after_all back up and
# restore whatever was on disk, otherwise running this suite permanently
# marks the real game's tutorial as completed on the test machine.

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
	tm.current_step_index = -1
	tm._ready_to_advance = false

func test_start_new_game_session_arms_tutorial_when_not_completed():
	tm.start_new_game_session()
	assert_true(tm.tutorial_active, "a never-completed tutorial must arm on New Game")
	assert_eq(tm.current_step_index, 0)

func test_start_new_game_session_skips_when_already_completed():
	tm.tutorial_completed = true
	tm.start_new_game_session()
	assert_false(tm.tutorial_active, "a completed tutorial must not replay on New Game")
	assert_eq(tm.current_step_index, -1)

func test_advance_step_blocks_until_wait_for_condition_is_met():
	tm.start_new_game_session()          # step 0: welcome (no wait_for)
	tm.advance_step()
	assert_eq(tm.current_step_index, 1, "narration-only step must advance on Next")

	tm.advance_step()                    # step 1: sail, wait_for="speed", min_value=5.0
	assert_eq(tm.current_step_index, 1, "gated step must not advance before its condition fires")

	tm._on_ship_speed_changed(2.0)
	assert_false(tm._ready_to_advance, "speed below min_value must not satisfy the condition")
	tm.advance_step()
	assert_eq(tm.current_step_index, 1, "must not advance below the min_value threshold")

	tm._on_ship_speed_changed(6.0)
	assert_true(tm._ready_to_advance, "speed at/above min_value must satisfy the condition")
	tm.advance_step()
	assert_eq(tm.current_step_index, 2, "must advance once the condition is met")

func test_condition_dispatch_ignores_signals_for_other_steps():
	tm.start_new_game_session()
	tm.advance_step()                    # -> step 1 (sail)
	tm._on_player_docked("port_royal")   # wrong condition for the current step
	assert_false(tm._ready_to_advance, "a signal for a different condition must not satisfy the current step")

func test_skip_tutorial_completes_immediately_and_unlocks_all_ui():
	tm.start_new_game_session()
	tm.skip_tutorial()

	assert_true(tm.tutorial_completed)
	assert_false(tm.tutorial_active)
	assert_eq(tm.current_step_index, -1)
	assert_true(tm.is_ui_unlocked("tab_fleet"))
	assert_true(tm.is_ui_unlocked("tab_research"))
	assert_true(tm.is_ui_unlocked("tab_trade"))

func test_is_ui_unlocked_true_when_tutorial_not_active():
	tm.tutorial_active = false
	assert_true(tm.is_ui_unlocked("tab_fleet"),
		"once the tutorial isn't active (finished, skipped, or never started), all UI reads as unlocked")

func test_is_ui_unlocked_false_for_a_locked_id_while_active():
	tm.tutorial_active = true
	assert_false(tm.is_ui_unlocked("tab_fleet"), "a freshly-armed tutorial must start with no unlocked tabs")

func test_save_load_round_trip():
	# Drive state through the public API (never poke _unlocked_ui directly)
	# so this also exercises the unlock-on-advance behavior end to end.
	tm.start_new_game_session()          # step 0: welcome
	tm.advance_step()                    # -> step 1: sail
	tm._on_ship_speed_changed(6.0)
	tm.advance_step()                    # -> step 2: dock
	tm._on_player_docked("port_royal")
	tm.advance_step()                    # -> step 3: build
	tm._on_structure_changed("lumber_mill", false)
	tm.advance_step()                    # -> step 4: recruit
	tm._on_captain_recruited(null)
	tm.advance_step()                    # -> step 5: combat (applies "recruit" step's tab_fleet unlock)

	assert_eq(tm.current_step_index, 5)
	assert_true(tm.is_ui_unlocked("tab_fleet"), "leaving the recruit step must unlock the fleet tab")

	var saved = tm.get_save_data()

	var tm2 = load("res://scripts/managers/TutorialManager.gd").new()
	add_child_autoqfree(tm2)
	tm2.load_save_data(saved)

	assert_eq(tm2.current_step_index, 5)
	assert_true(tm2.tutorial_active)
	assert_true(tm2.is_ui_unlocked("tab_fleet"), "unlocked UI ids must survive save/load")
	assert_false(tm2.is_ui_unlocked("tab_research"), "ids not yet unlocked must not leak in")

func test_reset_and_replay_rearms_a_completed_tutorial():
	tm.tutorial_completed = true
	tm.reset_and_replay()

	assert_false(tm.tutorial_completed)
	assert_true(tm.tutorial_active)
	assert_eq(tm.current_step_index, 0)

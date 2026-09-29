extends GutTest

# test_lessons.gd
# M28 Tasks 2-4 — lessons as chapter content. TutorialManager holds only the
# on/off flag and the seen set (Task 2); CampaignManager fires a chapter's
# lessons from signals it already listens to (Task 3); LessonCoachCard shows
# them without ever pausing the tree or overlapping TutorialDialogue (Task 4).
# Also pins the M28 fix for Chapter 1's opening beats, which fired at autoload
# boot into a menu with no dialogue to render them.

class FakeDialogue extends Control:
	var blocking := false
	func _ready() -> void:
		add_to_group("tutorial_dialogue")
	func is_blocking() -> bool:
		return blocking

const _CARD_SCENE := preload("res://scenes/ui/LessonCoachCard.tscn")
const _DIALOGUE_SCENE := preload("res://scenes/ui/TutorialDialogue.tscn")

var _saved_chapters: Array
var _saved_index: int
var _saved_completed: Array
var _saved_progress: Dictionary
var _saved_completed_objectives: Array
var _saved_lessons_enabled: bool
var _saved_seen: Array
var _saved_shown: Array
var _saved_legacy: bool
var _saved_heat_level: int
var _saved_pool_last: Dictionary
var _saved_resources: Dictionary


func before_each():
	_saved_chapters = CampaignManager.chapters.duplicate()
	_saved_index = CampaignManager.current_chapter_index
	_saved_completed = CampaignManager.completed_chapter_ids.duplicate()
	_saved_progress = CampaignManager._objective_progress.duplicate()
	_saved_completed_objectives = CampaignManager._completed_objective_ids.duplicate()
	_saved_heat_level = CampaignManager._last_heat_level
	_saved_pool_last = CampaignManager._player_pool_last.duplicate()
	_saved_lessons_enabled = TutorialManager.lessons_enabled
	_saved_seen = TutorialManager._seen_lessons.duplicate()
	_saved_shown = TutorialManager._shown_opening_ids.duplicate()
	_saved_legacy = TutorialManager._openings_legacy
	_saved_resources = ResourceManager.current_resources.duplicate()

	CampaignManager.current_chapter_index = -1
	CampaignManager.completed_chapter_ids.clear()
	CampaignManager._objective_progress.clear()
	CampaignManager._completed_objective_ids.clear()
	TutorialManager.lessons_enabled = true
	TutorialManager._seen_lessons.clear()
	TutorialManager._shown_opening_ids.clear()
	TutorialManager._openings_legacy = false


func after_each():
	CampaignManager.chapters = _saved_chapters.duplicate()
	CampaignManager.current_chapter_index = _saved_index
	CampaignManager.completed_chapter_ids = _saved_completed.duplicate()
	CampaignManager._objective_progress = _saved_progress.duplicate()
	CampaignManager._completed_objective_ids = _saved_completed_objectives.duplicate()
	CampaignManager._last_heat_level = _saved_heat_level
	CampaignManager._player_pool_last = _saved_pool_last.duplicate()
	TutorialManager.lessons_enabled = _saved_lessons_enabled
	TutorialManager._seen_lessons = _saved_seen.duplicate()
	TutorialManager._shown_opening_ids = _saved_shown.duplicate()
	TutorialManager._openings_legacy = _saved_legacy
	TutorialManager._replay_pending = false
	ResourceManager.current_resources = _saved_resources.duplicate()


# --- helpers ---

func _lesson(id: String, trigger: int, arg: String = "", seconds: float = 8.0) -> LessonData:
	var l := LessonData.new()
	l.lesson_id = id
	l.title = id
	l.body = "body of " + id
	l.trigger = trigger
	l.trigger_arg = arg
	l.display_seconds = seconds
	return l


func _objective(id: String, condition: int, target_id: String = "", optional := false) -> ObjectiveData:
	var o := ObjectiveData.new()
	o.objective_id = id
	o.condition = condition
	o.target_id = target_id
	o.is_optional = optional
	return o


func _chapter(id: String, number: int, objectives: Array[ObjectiveData], lessons: Array[LessonData],
		required_previous := "") -> ChapterData:
	var c := ChapterData.new()
	c.chapter_id = id
	c.chapter_number = number
	c.title = id
	c.objectives = objectives
	c.lessons = lessons
	c.required_previous_chapter = required_previous
	return c


## Stands in for a LessonCoachCard: CampaignManager only fires while one exists.
func _add_card_marker() -> Node:
	var marker := Node.new()
	marker.add_to_group("lesson_coach_card")
	add_child_autoqfree(marker)
	return marker


func _fresh_tutorial_manager() -> Node:
	var tm: Node = load("res://scripts/managers/TutorialManager.gd").new()
	add_child_autoqfree(tm)
	return tm


# === Task 2 — TutorialManager lesson state ===

func test_seen_set_and_flag_round_trip_through_save_data():
	var tm := _fresh_tutorial_manager()
	tm.lessons_enabled = false
	tm.mark_seen("lesson_a")
	tm.mark_seen("lesson_b")
	tm.mark_opening_shown("ch1_the_drowned_port")

	var tm2 := _fresh_tutorial_manager()
	tm2.load_save_data(tm.get_save_data())

	assert_false(tm2.lessons_enabled)
	assert_true(tm2.has_seen("lesson_a"))
	assert_true(tm2.has_seen("lesson_b"))
	assert_false(tm2.has_seen("lesson_c"))
	assert_true(tm2.has_shown_opening("ch1_the_drowned_port"))


func test_a_pre_m28_save_loads_with_lessons_on_and_nothing_seen():
	var tm := _fresh_tutorial_manager()
	tm.lessons_enabled = false
	tm.mark_seen("stale")
	tm.load_save_data({"tutorial_active": false, "unlocked_ui": []})
	assert_true(tm.lessons_enabled, "a save without lessons_enabled must default to on")
	assert_false(tm.has_seen("stale"))


func test_mark_seen_is_idempotent():
	var tm := _fresh_tutorial_manager()
	tm.mark_seen("x")
	tm.mark_seen("x")
	assert_eq(tm._seen_lessons.size(), 1)


func test_replay_lessons_clears_seen_and_enables():
	var tm := _fresh_tutorial_manager()
	tm.lessons_enabled = false
	tm.mark_seen("x")
	tm.replay_lessons()
	assert_true(tm.lessons_enabled)
	assert_false(tm.has_seen("x"))


func test_replay_survives_the_load_a_continue_runs_straight_afterwards():
	## Settings -> Replay lessons -> Continue: load_save_data() runs next and
	## must not restore the pre-replay state.
	var tm := _fresh_tutorial_manager()
	tm.replay_lessons()
	tm.load_save_data({"lessons_enabled": false, "seen_lessons": ["x"]})
	assert_true(tm.lessons_enabled)
	assert_false(tm.has_seen("x"))
	# ...and only for that one load.
	tm.load_save_data({"lessons_enabled": false, "seen_lessons": ["x"]})
	assert_false(tm.lessons_enabled)
	assert_true(tm.has_seen("x"))


func test_start_new_game_lessons_resets_seen_and_openings():
	var tm := _fresh_tutorial_manager()
	tm.mark_seen("x")
	tm.mark_opening_shown("ch1")
	tm.start_new_game_lessons(false)
	assert_false(tm.lessons_enabled)
	assert_false(tm.has_seen("x"))
	assert_false(tm.has_shown_opening("ch1"), "a new game shows Chapter 1's opening again")


func test_pre_m28_save_counts_already_started_chapters_as_shown():
	## A legacy save has no opening record; its completed and current chapters
	## were long since started, so Continue must not replay their openings.
	## Resolved lazily — SaveManager loads "tutorial" before "campaign".
	var tm := _fresh_tutorial_manager()
	tm.load_save_data({"tutorial_active": false})
	var ch1 := _chapter("ch1", 1, [], [])
	var ch2 := _chapter("ch2", 2, [], [])
	CampaignManager.chapters = [ch1, ch2]
	CampaignManager.completed_chapter_ids = ["ch1"]
	CampaignManager.current_chapter_index = 1
	assert_true(tm.has_shown_opening("ch1"))
	assert_true(tm.has_shown_opening("ch2"))
	assert_true(tm.get_save_data()["shown_openings"].has("ch2"),
		"the legacy inference must be written back, not lost on the next save")


# === Task 3 — CampaignManager firing ===

func test_a_chapter_start_lesson_fires_once_and_is_marked_seen():
	var lesson := _lesson("start", LessonData.Trigger.CHAPTER_STARTED)
	CampaignManager.chapters = [_chapter("ch1", 1, [], [lesson])]
	_add_card_marker()
	watch_signals(CampaignManager)

	CampaignManager._catch_up()
	CampaignManager._refire_world_ready_lessons()

	assert_signal_emit_count(CampaignManager, "lesson_requested", 1)
	assert_true(TutorialManager.has_seen("start"))


func test_no_card_means_no_fire_and_nothing_marked_seen():
	## Chapter 1 starts at autoload boot on the menu, where no card exists — the
	## lesson must wait for the World instead of being "seen" by nobody.
	var lesson := _lesson("start", LessonData.Trigger.CHAPTER_STARTED)
	CampaignManager.chapters = [_chapter("ch1", 1, [], [lesson])]
	watch_signals(CampaignManager)

	CampaignManager._catch_up()
	assert_signal_emit_count(CampaignManager, "lesson_requested", 0)
	assert_false(TutorialManager.has_seen("start"))

	_add_card_marker()
	CampaignManager._refire_world_ready_lessons()
	assert_signal_emit_count(CampaignManager, "lesson_requested", 1,
		"world-ready must fire the lesson the boot-time chapter start couldn't")


func test_disabled_lessons_never_fire():
	var lesson := _lesson("start", LessonData.Trigger.CHAPTER_STARTED)
	CampaignManager.chapters = [_chapter("ch1", 1, [], [lesson])]
	_add_card_marker()
	TutorialManager.lessons_enabled = false
	watch_signals(CampaignManager)
	CampaignManager._catch_up()
	assert_signal_emit_count(CampaignManager, "lesson_requested", 0)


func test_a_lesson_never_fires_outside_its_own_chapter():
	var ch1 := _chapter("ch1", 1, [_objective("1.1", ObjectiveData.Condition.DOCK_AT_ISLAND, "far_isle")], [])
	var ch2 := _chapter("ch2", 2, [], [_lesson("ch2_dock", LessonData.Trigger.FIRST_DOCK)], "ch1")
	CampaignManager.chapters = [ch1, ch2]
	_add_card_marker()
	CampaignManager._catch_up()
	watch_signals(CampaignManager)

	CampaignManager._on_player_docked("some_port")

	assert_signal_emit_count(CampaignManager, "lesson_requested", 0)
	assert_false(TutorialManager.has_seen("ch2_dock"))


func test_objective_current_fires_when_its_objective_becomes_the_first_incomplete_one():
	var objectives: Array[ObjectiveData] = [
		_objective("x.1", ObjectiveData.Condition.DOCK_AT_ISLAND, "isle_a"),
		_objective("x.2", ObjectiveData.Condition.DOCK_AT_ISLAND, "isle_b"),
	]
	var lesson := _lesson("second", LessonData.Trigger.OBJECTIVE_CURRENT, "x.2")
	CampaignManager.chapters = [_chapter("ch1", 1, objectives, [lesson])]
	_add_card_marker()
	watch_signals(CampaignManager)

	CampaignManager._catch_up()
	assert_signal_emit_count(CampaignManager, "lesson_requested", 0, "x.1 is current, not x.2")

	CampaignManager._on_player_docked("isle_a")
	assert_signal_emit_count(CampaignManager, "lesson_requested", 1)
	assert_eq(CampaignManager.get_current_objective().objective_id, "x.2")


func test_get_current_objective_skips_optional_and_completed():
	var objectives: Array[ObjectiveData] = [
		_objective("x.1", ObjectiveData.Condition.DOCK_AT_ISLAND, "a"),
		_objective("x.2", ObjectiveData.Condition.DOCK_AT_ISLAND, "b", true),
		_objective("x.3", ObjectiveData.Condition.DOCK_AT_ISLAND, "c"),
	]
	CampaignManager.chapters = [_chapter("ch1", 1, objectives, [])]
	CampaignManager._catch_up()
	CampaignManager._completed_objective_ids.append("x.1")
	assert_eq(CampaignManager.get_current_objective().objective_id, "x.3")


func test_chapter_completed_lesson_fires_for_the_chapter_just_completed():
	var lesson := _lesson("done", LessonData.Trigger.CHAPTER_COMPLETED)
	var objectives: Array[ObjectiveData] = [_objective("x.1", ObjectiveData.Condition.DOCK_AT_ISLAND, "isle_a")]
	CampaignManager.chapters = [_chapter("ch1", 1, objectives, [lesson])]
	_add_card_marker()
	CampaignManager._catch_up()
	watch_signals(CampaignManager)

	CampaignManager._on_player_docked("isle_a")

	assert_signal_emitted(CampaignManager, "chapter_completed")
	assert_signal_emit_count(CampaignManager, "lesson_requested", 1)


func test_trigger_arg_filters_job_kind():
	var lesson := _lesson("timers", LessonData.Trigger.FIRST_JOB_STARTED, "research")
	CampaignManager.chapters = [_chapter("ch1", 1, [], [lesson])]
	_add_card_marker()
	CampaignManager._catch_up()
	watch_signals(CampaignManager)

	CampaignManager._on_job_started({"kind": "build"})
	assert_signal_emit_count(CampaignManager, "lesson_requested", 0)
	CampaignManager._on_job_started({"kind": "research"})
	assert_signal_emit_count(CampaignManager, "lesson_requested", 1)


func test_empty_trigger_arg_matches_any_job():
	var lesson := _lesson("timers", LessonData.Trigger.FIRST_JOB_STARTED)
	CampaignManager.chapters = [_chapter("ch1", 1, [], [lesson])]
	_add_card_marker()
	CampaignManager._catch_up()
	watch_signals(CampaignManager)
	CampaignManager._on_job_started({"kind": "ship"})
	assert_signal_emit_count(CampaignManager, "lesson_requested", 1)


func test_heat_lesson_fires_only_on_a_rise():
	var lesson := _lesson("heat", LessonData.Trigger.HEAT_TIER_UP)
	# Pending objective: a downward crossing runs LOWER_HEAT's dispatch, which
	# would complete an objective-less chapter mid-test.
	var objectives: Array[ObjectiveData] = [_objective("x.1", ObjectiveData.Condition.DOCK_AT_ISLAND, "far")]
	CampaignManager.chapters = [_chapter("ch1", 1, objectives, [lesson])]
	_add_card_marker()
	CampaignManager._catch_up()
	watch_signals(CampaignManager)

	CampaignManager._last_heat_level = 1
	var down := HeatTierData.new()
	down.tier = 0
	CampaignManager._on_heat_tier_changed(down)
	assert_signal_emit_count(CampaignManager, "lesson_requested", 0)
	var up := HeatTierData.new()
	up.tier = 1
	CampaignManager._on_heat_tier_changed(up)
	assert_signal_emit_count(CampaignManager, "lesson_requested", 1)


func test_damage_lesson_fires_only_on_a_decrease():
	var lesson := _lesson("hurt", LessonData.Trigger.FIRST_DAMAGE_TAKEN)
	CampaignManager.chapters = [_chapter("ch1", 1, [], [lesson])]
	_add_card_marker()
	CampaignManager._catch_up()
	watch_signals(CampaignManager)

	CampaignManager._player_pool_last = {"hull": 100.0}
	CampaignManager._on_player_pool_changed("hull", 120.0, 150.0)
	assert_signal_emit_count(CampaignManager, "lesson_requested", 0)
	CampaignManager._on_player_pool_changed("hull", 90.0, 150.0)
	assert_signal_emit_count(CampaignManager, "lesson_requested", 1)


func test_eights_lesson_fires_once_eights_are_held():
	var lesson := _lesson("eights", LessonData.Trigger.FIRST_EIGHTS)
	# A pending objective: a chapter with none completes on the first
	# resources_changed (_check_chapter_complete), ending it mid-test.
	var objectives: Array[ObjectiveData] = [_objective("x.1", ObjectiveData.Condition.DOCK_AT_ISLAND, "far")]
	CampaignManager.chapters = [_chapter("ch1", 1, objectives, [lesson])]
	_add_card_marker()
	CampaignManager._catch_up()
	watch_signals(CampaignManager)

	CampaignManager._on_resources_changed({ResourceManager.PREMIUM_CURRENCY: 0, "gold": 10})
	assert_signal_emit_count(CampaignManager, "lesson_requested", 0)
	CampaignManager._on_resources_changed({ResourceManager.PREMIUM_CURRENCY: 10})
	assert_signal_emit_count(CampaignManager, "lesson_requested", 1)


func test_unknown_lesson_id_resolves_to_null_rather_than_a_silent_skip():
	CampaignManager.chapters = [_chapter("ch1", 1, [], [_lesson("real", LessonData.Trigger.FIRST_DOCK)])]
	assert_true(CampaignManager.has_lesson("real"))
	assert_false(CampaignManager.has_lesson("no_such_lesson"))
	# get_lesson() push_errors here (M28 Requirement 1.5); GUT 9.4 has no error
	# tracker, so this pins the null contract the error accompanies.
	assert_null(CampaignManager.get_lesson("no_such_lesson"))
	assert_eq(CampaignManager.get_lesson("real").lesson_id, "real")


func test_schedule_manager_job_started_is_connected():
	assert_true(ScheduleManager.job_started.is_connected(CampaignManager._on_job_started))


func test_a_missing_or_signal_less_schedule_manager_is_not_an_error():
	## M28 Requirement 4.2 — the timer trigger is optional. A node without
	## job_started (or none at all) is a quiet no-op.
	var plain := Node.new()
	add_child_autoqfree(plain)
	CampaignManager._connect_schedule_manager(plain)
	CampaignManager._connect_schedule_manager(null)
	pass_test("no crash, no error path taken")


# === Task 4 — LessonCoachCard ===

func _card() -> LessonCoachCard:
	var card: LessonCoachCard = _CARD_SCENE.instantiate()
	add_child_autoqfree(card)
	return card


func test_showing_a_lesson_never_pauses_the_tree():
	var card := _card()
	await wait_process_frames(1)
	card.enqueue(_lesson("a", LessonData.Trigger.FIRST_DOCK))
	assert_true(card.visible)
	assert_false(get_tree().paused)
	assert_ne(card.process_mode, Node.PROCESS_MODE_ALWAYS,
		"the card must pause with the game, never run through a pause menu")


func test_two_lessons_queue_and_show_one_at_a_time():
	var card := _card()
	await wait_process_frames(1)
	var a := _lesson("a", LessonData.Trigger.FIRST_DOCK)
	var b := _lesson("b", LessonData.Trigger.FIRST_DOCK)
	card.enqueue(a)
	card.enqueue(b)
	assert_eq(card.get_current_lesson(), a)
	assert_eq(card.get_queue_size(), 1)
	card.dismiss()
	assert_eq(card.get_current_lesson(), b)
	assert_eq(card.get_queue_size(), 0)


func test_a_blocking_dialogue_defers_the_card():
	var dialogue := FakeDialogue.new()
	dialogue.blocking = true
	add_child_autoqfree(dialogue)
	var card := _card()
	await wait_process_frames(1)

	card.enqueue(_lesson("a", LessonData.Trigger.FIRST_DOCK))
	assert_false(card.visible, "never overlaps a dialogue that has focus")
	assert_null(card.get_current_lesson())

	dialogue.blocking = false
	await wait_process_frames(2)
	assert_true(card.visible)


func test_a_dialogue_opening_mid_lesson_takes_the_screen_and_the_lesson_returns():
	var dialogue := FakeDialogue.new()
	add_child_autoqfree(dialogue)
	var card := _card()
	await wait_process_frames(1)
	var a := _lesson("a", LessonData.Trigger.FIRST_DOCK)
	card.enqueue(a)
	assert_true(card.visible)

	dialogue.blocking = true
	await wait_process_frames(2)
	assert_false(card.visible)

	dialogue.blocking = false
	await wait_process_frames(2)
	assert_true(card.visible)
	assert_eq(card.get_current_lesson(), a)


func test_the_card_dismisses_itself_after_display_seconds():
	var card := _card()
	await wait_process_frames(1)
	card.enqueue(_lesson("a", LessonData.Trigger.FIRST_DOCK, "", 1.0))
	card._process(0.4)
	assert_true(card.visible)
	card._process(0.7)
	assert_false(card.visible)
	assert_null(card.get_current_lesson())


func test_the_card_shows_what_campaign_manager_requests():
	var card := _card()
	await wait_process_frames(1)
	var a := _lesson("a", LessonData.Trigger.FIRST_DOCK)
	CampaignManager.lesson_requested.emit(a)
	assert_eq(card.get_current_lesson(), a)
	assert_eq(card.title_label.text, "a")


func test_the_card_registers_the_group_campaign_manager_checks():
	var card := _card()
	await wait_process_frames(1)
	assert_true(card.is_in_group(LessonCoachCard.GROUP))
	assert_true(CampaignManager._lesson_card_present())


func test_highlight_breathes_on_the_group_node_and_is_restored_on_dismiss():
	var target := Control.new()
	target.add_to_group("m28_test_highlight")
	add_child_autoqfree(target)
	var card := _card()
	await wait_process_frames(1)
	var a := _lesson("a", LessonData.Trigger.FIRST_DOCK)
	a.highlight_group = &"m28_test_highlight"
	card.enqueue(a)
	assert_eq(card._highlight_node, target)
	await wait_process_frames(3)
	card.dismiss()
	assert_eq(target.self_modulate, Color.WHITE)


# === Chapter openings lost at boot (M28 fix) ===

func test_a_chapter_started_before_any_dialogue_existed_shows_its_opening_once():
	var beat := DialogueBeatData.new()
	beat.speaker_name = "Higgins"
	beat.text = "That's it, then."
	var ch1 := _chapter("ch1", 1, [_objective("1.1", ObjectiveData.Condition.DOCK_AT_ISLAND, "far")], [])
	ch1.opening_beats = [beat]
	CampaignManager.chapters = [ch1]
	# Autoload boot: the chapter starts with no dialogue in the tree.
	CampaignManager._catch_up()

	var dialogue: TutorialDialogue = _DIALOGUE_SCENE.instantiate()
	add_child_autoqfree(dialogue)
	await wait_process_frames(1)
	assert_false(dialogue.visible,
		"reproduces the defect: chapter_started fired before this dialogue existed")

	dialogue.show_missed_opening()
	assert_true(dialogue.visible, "the missed opening is shown once the World is up")
	assert_true(TutorialManager.has_shown_opening("ch1"))

	dialogue.hide()
	dialogue.show_missed_opening()
	assert_false(dialogue.visible, "Continue must never replay an opening already shown")


# === Task 8 — skip / replay ===

class MockShip extends Node3D:
	var faction: Resource = null
	var ship_stats: ShipStats = null

const _COMPLETION_PATH := "user://tutorial_state.json"


func test_new_game_offers_teach_first_to_a_new_player():
	var labels := MainMenu.new_game_lesson_choices(false)
	assert_eq(labels[0], "Teach me the ropes")
	assert_true(MainMenu.wants_lessons_for(0, false))
	assert_false(MainMenu.wants_lessons_for(1, false))


func test_new_game_defaults_a_returning_player_to_skip():
	## Requirement 3.1 — ChoiceDialog focuses its first button.
	var labels := MainMenu.new_game_lesson_choices(true)
	assert_eq(labels[0], "I know these waters")
	assert_false(MainMenu.wants_lessons_for(0, true))
	assert_true(MainMenu.wants_lessons_for(1, true))


func test_i_know_these_waters_keeps_chapter_1_but_fires_no_lessons():
	## Requirement 3.2 — a scripted Chapter 1 after "I know these waters": every
	## tab open, no lesson fires, every objective still completes and the
	## chapter's rewards are still granted.
	var had_file := FileAccess.file_exists(_COMPLETION_PATH)
	var backup := FileAccess.get_file_as_string(_COMPLETION_PATH) if had_file else ""
	var saved_active: bool = TutorialManager.tutorial_active
	var saved_completed: bool = TutorialManager.tutorial_completed
	var saved_unlocked: Array = TutorialManager._unlocked_ui.duplicate()

	TutorialManager.tutorial_completed = false
	TutorialManager.start_new_game_session()
	TutorialManager.start_new_game_lessons(false)
	TutorialManager.skip_tutorial()

	var ch1 := load("res://resources/campaign/chapters/Ch1_TheDrownedPort.tres") as ChapterData
	CampaignManager.chapters = [ch1]
	_add_card_marker()
	ResourceManager.current_resources[ResourceManager.PREMIUM_CURRENCY] = 0
	watch_signals(CampaignManager)
	CampaignManager._catch_up()

	for tab in ["tab_fleet", "tab_research", "tab_trade"]:
		assert_true(TutorialManager.is_ui_unlocked(tab), "%s must be open from the start" % tab)

	CampaignManager._on_player_docked("port_royal")                  # 1.1
	CampaignManager._on_island_captured("port_royal")                # 1.2
	for building in ["farm_l1", "lumber_mill_l1", "warehouse_l1", "tavern_l1"]:
		CampaignManager._on_structure_changed(building, false)       # 1.3 1.4 1.5 1.7
	var clans := FactionData.new()
	clans.faction_id = "pirate_clans"
	for i in 3:                                                      # 1.6
		var ship := MockShip.new()
		ship.faction = clans
		autoqfree(ship)
		CampaignManager._on_ship_destroyed(ship)
	CampaignManager._player_ammo_id = "round"
	CampaignManager._on_player_ammo_changed(load("res://resources/combat/ammo/ChainShot.tres"))  # 1.10
	CampaignManager._on_captain_recruited(CaptainData.new())         # 1.8

	assert_signal_emitted(CampaignManager, "chapter_completed", "Chapter 1 still completes")
	assert_signal_emit_count(CampaignManager, "lesson_requested", 0, "no lesson fires when skipped")
	assert_gt(int(ResourceManager.current_resources.get(ResourceManager.PREMIUM_CURRENCY, 0)), 0,
		"Chapter 1's rewards are still granted")

	TutorialManager.tutorial_active = saved_active
	TutorialManager.tutorial_completed = saved_completed
	TutorialManager._unlocked_ui.assign(saved_unlocked)
	if had_file:
		var f := FileAccess.open(_COMPLETION_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	elif FileAccess.file_exists(_COMPLETION_PATH):
		DirAccess.open("user://").remove("tutorial_state.json")


func test_replay_after_skipping_turns_lessons_back_on():
	TutorialManager.start_new_game_lessons(false)
	TutorialManager.mark_seen("ch1_sailing")
	TutorialManager.replay_lessons()
	assert_true(TutorialManager.lessons_enabled)
	assert_false(TutorialManager.has_seen("ch1_sailing"))

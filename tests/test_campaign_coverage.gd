extends GutTest

# test_campaign_coverage.gd
# M28 Requirement 2.1 — every player-facing system has at least one lesson and
# at least one objective in shipping chapters 1-5. This table is what stops a
# future system from shipping untaught: add a system, add its row.
#
# Timers are live (M27's ScheduleManager has shipped), not pending. The
# Maelstrom is lesson-only by design: the mode teaches itself.

const COVERAGE := {
	"sailing":                  {"lessons": ["ch1_sailing"], "objectives": ["1.1"]},
	"docking":                  {"lessons": ["ch1_docking", "ch1_island_menu"], "objectives": ["1.1"]},
	"building":                 {"lessons": ["ch1_building"], "objectives": ["1.3", "1.4"]},
	"economy_storage":          {"lessons": ["ch1_storage"], "objectives": ["1.5"]},
	"manual_fire":              {"lessons": ["ch1_manual_fire"], "objectives": ["1.6"]},
	"ammo_and_damage_triangle": {"lessons": ["ch1_ammo"], "objectives": ["1.10", "2.9"]},
	"boarding":                 {"lessons": ["ch2_boarding"], "objectives": ["2.4"]},
	"capture":                  {"lessons": ["ch2_capture"], "objectives": ["2.7"]},
	"captains":                 {"lessons": ["ch1_captains"], "objectives": ["1.8"]},
	"fleet_captain_assignment": {"lessons": ["ch3_fleet"], "objectives": ["3.9"]},
	"ship_classes":             {"lessons": ["ch2_ship_classes"], "objectives": ["2.3"]},
	"repair":                   {"lessons": ["ch2_repair"], "objectives": ["2.10"]},
	"heat":                     {"lessons": ["ch3_heat", "ch3_lie_low"], "objectives": ["3.8"]},
	"factions_reputation":      {"lessons": ["ch4_factions"], "objectives": ["4.10"]},
	"world_map":                {"lessons": ["ch4_world_map"], "objectives": ["4.9"]},
	"research":                 {"lessons": ["ch4_research"], "objectives": ["4.4"]},
	"raids_defence":            {"lessons": ["ch3_defence"], "objectives": ["3.2", "3.4"]},
	# The Eights clear (EmpireManager.spend_to_reduce_heat) is one of the two
	# ways to finish 3.8 — the other is free decay, so Eights are never required.
	"pieces_of_eight":          {"lessons": ["ch3_eights", "ch3_lie_low"], "objectives": ["3.8"]},
	# Every build is a ScheduleManager job since M27, so 2.2's shipyard is timed.
	"timers":                   {"lessons": ["ch2_timers"], "objectives": ["2.2"]},
	"maelstrom":                {"lessons": ["ch5_maelstrom"], "objectives": []},
}
const LESSON_ONLY := ["maelstrom"]
const LESSONS_DIR := "res://resources/campaign/lessons/"

## The objectives M28 added, and the chapter each must live in.
const NEW_OBJECTIVES := {
	"1.10": "ch1_the_drowned_port", "2.9": "ch2_blood_in_the_shallows",
	"2.10": "ch2_blood_in_the_shallows", "3.8": "ch3_the_kings_answer",
	"3.9": "ch3_the_kings_answer", "4.9": "ch4_the_admirals_gambit",
	"4.10": "ch4_the_admirals_gambit",
}

var _chapters: Array[ChapterData] = []


func before_all():
	for chapter in CampaignManager.chapters:
		if chapter.chapter_number >= 1 and chapter.chapter_number <= 5:
			_chapters.append(chapter)


func _lesson_chapter(lesson_id: String) -> ChapterData:
	for chapter in _chapters:
		for lesson in chapter.lessons:
			if lesson and lesson.lesson_id == lesson_id:
				return chapter
	return null


func _objective(objective_id: String) -> ObjectiveData:
	for chapter in _chapters:
		for o in chapter.objectives:
			if o.objective_id == objective_id:
				return o
	return null


func _chapter_of_objective(objective_id: String) -> ChapterData:
	for chapter in _chapters:
		for o in chapter.objectives:
			if o.objective_id == objective_id:
				return chapter
	return null


func test_chapters_1_to_5_are_all_shipping():
	assert_eq(_chapters.size(), 5)


func test_every_system_has_a_lesson_in_chapters_1_to_5():
	for system in COVERAGE:
		var lessons: Array = COVERAGE[system]["lessons"]
		assert_gt(lessons.size(), 0, "%s has no lesson" % system)
		for lesson_id in lessons:
			assert_not_null(_lesson_chapter(lesson_id),
				"%s: lesson '%s' is not attached to any of chapters 1-5" % [system, lesson_id])


func test_every_system_has_an_objective_in_chapters_1_to_5():
	for system in COVERAGE:
		var objectives: Array = COVERAGE[system]["objectives"]
		if system in LESSON_ONLY:
			assert_eq(objectives.size(), 0, "%s is lesson-only by design" % system)
			continue
		assert_gt(objectives.size(), 0, "%s has no objective" % system)
		for objective_id in objectives:
			assert_not_null(_objective(objective_id),
				"%s: objective '%s' is not in chapters 1-5" % [system, objective_id])


func test_timers_are_live_not_pending():
	## M28 Requirement 4 — ScheduleManager (M27) has shipped, so the timer
	## lesson has a real trigger source and builds really are timed.
	var schedule := get_tree().root.get_node_or_null("ScheduleManager")
	assert_not_null(schedule)
	assert_true(schedule.has_signal("job_started"))
	assert_true(schedule.KINDS.has("build"), "2.2's shipyard build must be a timed job")
	var timers := _lesson_chapter("ch2_timers")
	for lesson in timers.lessons:
		if lesson.lesson_id == "ch2_timers":
			assert_eq(lesson.trigger, LessonData.Trigger.FIRST_JOB_STARTED)


func test_lesson_ids_are_unique_and_every_lesson_file_is_used():
	var ids := {}
	for chapter in _chapters:
		for lesson in chapter.lessons:
			assert_not_null(lesson, "%s has a null lesson" % chapter.chapter_id)
			assert_false(lesson.lesson_id.is_empty())
			assert_false(ids.has(lesson.lesson_id), "duplicate lesson id %s" % lesson.lesson_id)
			ids[lesson.lesson_id] = true
	var dir := DirAccess.open(LESSONS_DIR)
	assert_not_null(dir)
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var lesson := load(LESSONS_DIR + file_name) as LessonData
		assert_not_null(lesson, "%s is not a LessonData" % file_name)
		assert_true(ids.has(lesson.lesson_id), "%s is authored but no chapter uses it" % file_name)


func test_objective_current_lessons_name_an_objective_in_their_own_chapter():
	for chapter in _chapters:
		var own := {}
		for o in chapter.objectives:
			own[o.objective_id] = o
		for lesson in chapter.lessons:
			if lesson.trigger != LessonData.Trigger.OBJECTIVE_CURRENT:
				continue
			assert_true(own.has(lesson.trigger_arg),
				"%s points at objective '%s', not in %s" % [lesson.lesson_id, lesson.trigger_arg, chapter.chapter_id])
			if own.has(lesson.trigger_arg):
				assert_false(own[lesson.trigger_arg].is_optional,
					"%s: an optional objective never becomes the current one" % lesson.lesson_id)


func test_new_objectives_live_in_their_chapter_and_are_mandatory():
	for objective_id in NEW_OBJECTIVES:
		var chapter := _chapter_of_objective(objective_id)
		assert_not_null(chapter, "new objective %s is missing" % objective_id)
		if chapter:
			assert_eq(chapter.chapter_id, NEW_OBJECTIVES[objective_id])
			assert_false(_objective(objective_id).is_optional,
				"%s teaches a system — it must be required, not skippable" % objective_id)


func test_new_objective_targets_resolve_to_real_content():
	# SWAP_AMMO: a real, player-cyclable ammo id.
	var cyclable := []
	for path in ShipCombat.AMMO_CYCLE:
		cyclable.append((load(path) as AmmoData).ammo_id)
	assert_true(cyclable.has(_objective("1.10").target_id), "1.10 must target ammo the player can cycle to")
	# SET_COURSE: a shipping island (test_content_gate_integrity checks the
	# gate; this checks it is the cay 4.1 then asks the player to find).
	assert_eq(_objective("4.9").target_id, _objective("4.1").target_id)
	# CHANGE_REPUTATION: a faction FactionManager tracks, reachable by one tribute
	# from the starting standing.
	var rep_target := _objective("4.10")
	assert_true(FactionManager.reputation_scores.has(rep_target.target_id))
	assert_true(rep_target.target_value <= 20 + FactionManager.TRIBUTE_REPUTATION_GAIN,
		"4.10's threshold must be within one tribute of the Guild's starting standing")


func test_lower_heat_is_reachable_when_chapter_3_starts():
	## 3.8 needs a downward heat-tier crossing. Chapter 3 is gated on Contested
	## Waters, whose activation threshold must sit at or above tier 1's floor,
	## so the chapter always opens with at least one tier to fall through.
	var ch3 := _chapter_of_objective("3.8")
	var region_path := "res://resources/world/regions/ContestedWaters.tres"
	var region := load(region_path)
	assert_eq(ch3.required_region_id, region.get("id"))
	var tier1 := load("res://resources/balance/heat_tiers/T1_Noticed.tres") as HeatTierData
	assert_true(float(region.get("activation_notoriety_threshold")) >= tier1.min_notoriety)

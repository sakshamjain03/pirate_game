extends GutTest

# test_campaign_content.gd
# M7 Task 20 — the objective-integrity test. Loads every real chapter/objective
# resource and asserts every target_id that names an island/building/faction/
# tech/captain resolves against the real registry, not a filename someone
# guessed the spelling of. The automated version of the authoring warning
# repeated throughout docs/12_CHARACTER_BIBLE.md and
# docs/13_CAMPAIGN_LEVELS_1-5.md (D3/D14: a wrong id fails silently — an
# objective that can never complete looks identical to one that just hasn't
# been done yet).

const CHAPTERS_DIR := "res://resources/campaign/chapters/"

var _island_ids: Array[String] = []
var _faction_ids: Array[String] = []
var _building_ids: Array[String] = []
var _tech_ids: Array[String] = []
var _captain_ids: Array[String] = []
var _ship_ids: Array[String] = []


func before_each():
	_island_ids = _collect_ids("res://resources/world/", "island_id")
	_faction_ids = _collect_ids("res://resources/factions/", "faction_id")
	_building_ids = _collect_ids("res://resources/buildings/", "building_id")
	_tech_ids = _collect_ids("res://resources/techs/", "tech_id")
	_captain_ids = _collect_ids("res://resources/captains/", "captain_id")
	_ship_ids = _collect_ids("res://resources/ships/", "ship_id")
	_ship_ids.append_array(_collect_ids("res://resources/enemies/", "ship_id"))


func _collect_ids(dir_path: String, id_field: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(dir_path + file_name)
			if res and res.get(id_field) != null:
				var id: String = str(res.get(id_field))
				if not id.is_empty():
					out.append(id)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


func _load_all_chapters() -> Array[ChapterData]:
	var out: Array[ChapterData] = []
	var dir := DirAccess.open(CHAPTERS_DIR)
	assert_not_null(dir, "resources/campaign/chapters/ must exist")
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var chapter := load(CHAPTERS_DIR + file_name) as ChapterData
			if chapter:
				out.append(chapter)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


func test_the_real_chapters_1_through_5_all_load():
	var chapters := _load_all_chapters()
	var numbers: Array[int] = []
	for c in chapters:
		numbers.append(c.chapter_number)
	numbers.sort()
	assert_eq(numbers, [1, 2, 3, 4, 5], "Chapters 1-5 must all be present and uniquely numbered")


func test_every_chapter_id_is_unique():
	var chapters := _load_all_chapters()
	var seen: Array[String] = []
	for c in chapters:
		assert_false(seen.has(c.chapter_id), "Duplicate chapter_id: %s" % c.chapter_id)
		seen.append(c.chapter_id)


func test_every_gate_reference_resolves_to_a_real_chapter_or_region():
	var chapters := _load_all_chapters()
	var chapter_ids: Array[String] = []
	for c in chapters:
		chapter_ids.append(c.chapter_id)
	var real_regions := ["beginner_waters", "contested_waters", "imperial_waters"]

	for c in chapters:
		if not c.required_previous_chapter.is_empty():
			assert_true(chapter_ids.has(c.required_previous_chapter),
				"%s.required_previous_chapter '%s' does not name a real chapter"
				% [c.chapter_id, c.required_previous_chapter])
		if not c.required_region_id.is_empty():
			assert_true(real_regions.has(c.required_region_id),
				"%s.required_region_id '%s' does not name a real region"
				% [c.chapter_id, c.required_region_id])


func test_every_objective_id_is_globally_unique():
	var chapters := _load_all_chapters()
	var seen: Array[String] = []
	for c in chapters:
		for o in c.objectives:
			assert_false(seen.has(o.objective_id),
				"Duplicate objective_id '%s' (chapter %s)" % [o.objective_id, c.chapter_id])
			seen.append(o.objective_id)


func test_every_objective_target_id_resolves_against_the_real_registry():
	var chapters := _load_all_chapters()
	var checked := 0
	for c in chapters:
		for o in c.objectives:
			if o.target_id.is_empty():
				continue
			var registry: Array[String] = []
			var label := ""
			match o.condition:
				ObjectiveData.Condition.BUILD_STRUCTURE, ObjectiveData.Condition.UPGRADE_STRUCTURE_TO_LEVEL:
					registry = _building_ids
					label = "building"
				ObjectiveData.Condition.REACH_ISLAND_TIER, ObjectiveData.Condition.CAPTURE_ISLAND, \
						ObjectiveData.Condition.DISCOVER_ISLAND, ObjectiveData.Condition.DOCK_AT_ISLAND:
					registry = _island_ids
					label = "island"
				ObjectiveData.Condition.DESTROY_SHIPS:
					registry = _faction_ids
					label = "faction"
				ObjectiveData.Condition.BOARD_SHIPS:
					# CampaignManager._on_boarding_resolved() matches against
					# either a faction (2.4/3.7) or a dedicated boss ship_id
					# (4.8/5.7) — the target can legitimately be either.
					registry = _faction_ids + _ship_ids
					label = "faction or ship"
				ObjectiveData.Condition.DEFEAT_BOSS:
					registry = _ship_ids
					label = "ship"
				ObjectiveData.Condition.UNLOCK_TECH:
					registry = _tech_ids
					label = "tech"
				ObjectiveData.Condition.ACCUMULATE_RESOURCE:
					registry = ["gold", "wood", "iron", "rum", "research"]
					label = "resource key"
				_:
					continue
			checked += 1
			assert_true(registry.has(o.target_id),
				"%s.%s: target_id '%s' does not resolve as a real %s"
				% [c.chapter_id, o.objective_id, o.target_id, label])
	assert_gt(checked, 0, "Precondition: at least one target_id-bearing objective must exist")


func test_every_chapter_reward_reference_resolves():
	var chapters := _load_all_chapters()
	for c in chapters:
		if not c.reward_captain_id.is_empty():
			assert_true(_captain_ids.has(c.reward_captain_id),
				"%s.reward_captain_id '%s' does not name a real captain" % [c.chapter_id, c.reward_captain_id])
		if not c.reward_ship_id.is_empty():
			assert_true(_ship_ids.has(c.reward_ship_id),
				"%s.reward_ship_id '%s' does not name a real ship" % [c.chapter_id, c.reward_ship_id])
		if not c.reward_tech_id.is_empty():
			assert_true(_tech_ids.has(c.reward_tech_id),
				"%s.reward_tech_id '%s' does not name a real tech" % [c.chapter_id, c.reward_tech_id])


func test_every_captains_unlock_chapter_id_resolves_or_is_empty():
	var chapters := _load_all_chapters()
	var chapter_ids: Array[String] = []
	for c in chapters:
		chapter_ids.append(c.chapter_id)

	var dir := DirAccess.open("res://resources/captains/")
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var checked := 0
	while file_name != "":
		if file_name.ends_with(".tres"):
			var cap: CaptainData = load("res://resources/captains/%s" % file_name)
			if cap and not cap.unlock_chapter_id.is_empty():
				checked += 1
				assert_true(chapter_ids.has(cap.unlock_chapter_id),
					"%s.unlock_chapter_id '%s' does not name a real chapter"
					% [file_name, cap.unlock_chapter_id])
		file_name = dir.get_next()
	dir.list_dir_end()
	assert_gt(checked, 0, "Precondition: at least one captain must have a chapter-gated unlock")


func test_every_captains_home_island_and_faction_resolve_or_are_empty():
	var dir := DirAccess.open("res://resources/captains/")
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var cap: CaptainData = load("res://resources/captains/%s" % file_name)
			if cap:
				if not cap.home_island_id.is_empty():
					assert_true(_island_ids.has(cap.home_island_id),
						"%s.home_island_id '%s' does not name a real island" % [file_name, cap.home_island_id])
				if not cap.allegiance_faction_id.is_empty():
					assert_true(_faction_ids.has(cap.allegiance_faction_id),
						"%s.allegiance_faction_id '%s' does not name a real faction"
						% [file_name, cap.allegiance_faction_id])
		file_name = dir.get_next()
	dir.list_dir_end()


func test_destroy_count_objectives_never_ask_for_more_than_exist_in_the_composition():
	## Not a hard requirement of the schema (DESTROY_SHIPS counts kills across
	## the whole chapter's ambient/encounter spawns, not one fixed composition),
	## but a sanity ceiling so a target_count typo doesn't create an
	## uncompletable objective.
	var chapters := _load_all_chapters()
	for c in chapters:
		for o in c.objectives:
			if o.condition in [ObjectiveData.Condition.DESTROY_SHIPS, ObjectiveData.Condition.BOARD_SHIPS]:
				assert_lt(o.target_count, 20,
					"%s.%s: target_count %d is implausibly high" % [c.chapter_id, o.objective_id, o.target_count])

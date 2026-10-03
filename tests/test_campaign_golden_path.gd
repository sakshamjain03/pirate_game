extends GutTest

# Test C.3: golden-path test - every Ch1-5 objective is provably completable

const CHAPTERS_DIR := "res://resources/campaign/chapters/"

var _island_ids: Array[String] = []
var _faction_ids: Array[String] = []
var _building_ids: Array[String] = []
var _captain_ids: Array[String] = []
var _ship_ids: Array[String] = []


func before_each():
	_island_ids = _collect_ids("res://resources/world/", "island_id")
	_faction_ids = _collect_ids("res://resources/factions/", "faction_id")
	_building_ids = _collect_ids("res://resources/buildings/", "building_id")
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


func test_every_chapter_objective_is_completable():
	# Get all enabled chapters, up to Ch5
	var enabled_chapters = []
	for chapter in CampaignManager.chapters:
		if ResourceLookup.is_content_enabled(chapter) and chapter.chapter_number <= 5:
			enabled_chapters.append(chapter)
	
	assert_gt(enabled_chapters.size(), 0, "At least one enabled chapter exists")
	
	# Test each chapter's objectives
	for chapter in enabled_chapters:
		for objective in chapter.objectives:
			# Every objective must have a target_count >= 1
			assert_true(objective.target_count >= 1, 
				"Chapter %d Objective %s has target_count >= 1" % [chapter.chapter_number, objective.objective_id])
			
			# For faction-based or boss-based objectives, the target_id should resolve
			if objective.condition in [
				ObjectiveData.Condition.DESTROY_SHIPS,
				ObjectiveData.Condition.BOARD_SHIPS,
				ObjectiveData.Condition.CHANGE_REPUTATION
			]:
				if not objective.target_id.is_empty():
					# Can be either a faction or a specific boss ship
					var is_valid = _faction_ids.has(objective.target_id) or _ship_ids.has(objective.target_id)
					assert_true(is_valid,
						"Chapter %d Objective %s target '%s' exists (faction or ship)" % [chapter.chapter_number, objective.objective_id, objective.target_id])
			
			# For structure objectives, the target_id should resolve
			if objective.condition in [
				ObjectiveData.Condition.BUILD_STRUCTURE,
				ObjectiveData.Condition.UPGRADE_STRUCTURE_TO_LEVEL
			]:
				if not objective.target_id.is_empty():
					assert_true(_building_ids.has(objective.target_id),
						"Chapter %d Objective %s building '%s' exists" % [chapter.chapter_number, objective.objective_id, objective.target_id])
			
			# For island objectives, the target_id should resolve
			if objective.condition in [
				ObjectiveData.Condition.DOCK_AT_ISLAND,
				ObjectiveData.Condition.REACH_ISLAND_TIER,
				ObjectiveData.Condition.DISCOVER_ISLAND
			]:
				if not objective.target_id.is_empty():
					assert_true(_island_ids.has(objective.target_id),
						"Chapter %d Objective %s island '%s' exists" % [chapter.chapter_number, objective.objective_id, objective.target_id])
			
			# For captain objectives, the target_id should resolve
			if objective.condition == ObjectiveData.Condition.RECRUIT_CAPTAIN:
				if not objective.target_id.is_empty():
					assert_true(_captain_ids.has(objective.target_id),
						"Chapter %d Objective %s captain '%s' exists" % [chapter.chapter_number, objective.objective_id, objective.target_id])
			
			# For ship class objectives, the target_id should resolve
			if objective.condition == ObjectiveData.Condition.OWN_SHIP_CLASS:
				if not objective.target_id.is_empty():
					assert_true(_ship_ids.has(objective.target_id),
						"Chapter %d Objective %s ship '%s' exists" % [chapter.chapter_number, objective.objective_id, objective.target_id])


## Requirement C2's two other clauses: an island target must be IN the shipping
## (content_enabled) scope, not merely exist on disk — a cut island is exactly how
## Ch4/Ch5 shipped uncompletable before — and every condition a chapter uses must
## be handled by CampaignManager, or it can never progress.
func test_targets_are_in_scope_and_every_condition_is_handled():
	var enabled_islands: Array[String] = []
	var dir := DirAccess.open("res://resources/world/")
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			var res := load("res://resources/world/" + f)
			if res is IslandData and ResourceLookup.is_content_enabled(res):
				enabled_islands.append(res.island_id)
		f = dir.get_next()
	assert_gt(enabled_islands.size(), 0, "found the enabled islands")

	var source := FileAccess.get_file_as_string("res://scripts/managers/CampaignManager.gd")
	var names: Array = ObjectiveData.Condition.keys()
	var island_conditions := [
		ObjectiveData.Condition.DOCK_AT_ISLAND, ObjectiveData.Condition.REACH_ISLAND_TIER,
		ObjectiveData.Condition.DISCOVER_ISLAND, ObjectiveData.Condition.CAPTURE_ISLAND,
		ObjectiveData.Condition.SET_COURSE,
	]
	var checked := 0
	for chapter in CampaignManager.chapters:
		if not ResourceLookup.is_content_enabled(chapter) or chapter.chapter_number > 5:
			continue
		for o in chapter.objectives:
			checked += 1
			var cname: String = names[o.condition]
			assert_true(source.contains("Condition." + cname),
				"Ch%d %s: condition %s has a CampaignManager handler" % [chapter.chapter_number, o.objective_id, cname])
			if island_conditions.has(o.condition) and not o.target_id.is_empty():
				assert_true(enabled_islands.has(o.target_id),
					"Ch%d %s: island '%s' is content-enabled" % [chapter.chapter_number, o.objective_id, o.target_id])
	gut.p("golden path: %d objectives checked against %d enabled islands" % [checked, enabled_islands.size()])
	assert_gt(checked, 20, "Ch1-5 objectives were actually iterated")


## A condition CampaignManager only ever dispatches with an EMPTY target id can
## never match an objective that names one (ObjectiveDispatch.matches rejects
## target != ""). M29's first Ch4 raid objective did exactly that
## (SURVIVE_RAID + target_id "pelican_cay") and would have shipped Ch4
## uncompletable. Derived from the source so new handlers are covered.
func test_untargeted_conditions_carry_no_target_id():
	var source := FileAccess.get_file_as_string("res://scripts/managers/CampaignManager.gd")
	var re := RegEx.new()
	re.compile('_for_each_matching[(]ObjectiveData[.]Condition[.]([A-Z_]+), *([^,]+),')
	var empty_only := {}
	var targeted := {}
	for m in re.search_all(source):
		var cname := m.get_string(1)
		if m.get_string(2).strip_edges() == '""':
			empty_only[cname] = true
		else:
			targeted[cname] = true
	for cname in targeted:
		empty_only.erase(cname)
	assert_true(empty_only.has("SURVIVE_RAID"), "the scan finds SURVIVE_RAID's untargeted dispatch")
	var names: Array = ObjectiveData.Condition.keys()
	for chapter in CampaignManager.chapters:
		if not ResourceLookup.is_content_enabled(chapter) or chapter.chapter_number > 5:
			continue
		for o in chapter.objectives:
			var cname: String = names[o.condition]
			if empty_only.has(cname):
				assert_eq(o.target_id, "",
					"Ch%d %s: %s is dispatched without a target, so target_id must be empty" % [chapter.chapter_number, o.objective_id, cname])

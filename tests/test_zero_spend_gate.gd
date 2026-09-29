extends GutTest

## M27 Task 8 — the zero-spend release gate (Requirements 7.1-7.2, AGENTS.md:
## "Chapters 1-5 must be completable with earnable content only"). Reads the
## shipping chapter .tres files themselves, so a new objective is covered the day
## it's authored:
##   * nothing a Ch1-5 objective requires costs Eights;
##   * no job Ch1-2 needs (their required buildings, every Level 2 upgrade — the
##     way to island tier 2 — and a hull of each required class) takes longer than
##     EconomyPricing.zero_spend_early_cap_seconds at WORST-case speed (island
##     tier 1, a Level 1 Shipyard, no Academy). Stricter than "at the level those
##     chapters reach", and simpler to trust.

const IslandScript = preload("res://scripts/world/Island.gd")
const CHAPTER_DIR := "res://resources/campaign/chapters"
const EIGHTS := "eights"
const C := ObjectiveData.Condition

var _chapters: Array[ChapterData] = []
var _pricing
var _island_resolver: Node


func before_all() -> void:
	_pricing = ScheduleManager.pricing
	_island_resolver = IslandScript.new()
	for file in DirAccess.get_files_at(CHAPTER_DIR):
		if file.ends_with(".tres"):
			var chapter := load(CHAPTER_DIR.path_join(file)) as ChapterData
			if chapter and chapter.chapter_number <= 5:
				_chapters.append(chapter)


func after_all() -> void:
	_island_resolver.free()


func _required(max_chapter: int, conditions: Array) -> Array[ObjectiveData]:
	var result: Array[ObjectiveData] = []
	for chapter in _chapters:
		if chapter.chapter_number > max_chapter:
			continue
		for o in chapter.objectives:
			if not o.is_optional and o.condition in conditions:
				result.append(o)
	return result


func _tech(tech_id: String) -> TechData:
	for file in DirAccess.get_files_at("res://resources/techs"):
		var t := load("res://resources/techs".path_join(file)) as TechData
		if t and t.tech_id == tech_id:
			return t
	return null


func _ships_of_class(ship_class: int) -> Array[ShipStats]:
	var result: Array[ShipStats] = []
	for file in DirAccess.get_files_at("res://resources/ships"):
		var s := load("res://resources/ships".path_join(file)) as ShipStats
		if s and s.ship_class == ship_class:
			result.append(s)
	return result


## The Shipyard's own price dict, as IslandMenu builds it.
func _ship_cost(s: ShipStats) -> Dictionary:
	var cost := {"gold": s.cost_gold, "wood": s.cost_wood, "iron": s.cost_iron}
	if s.cost_rum > 0:
		cost["rum"] = s.cost_rum
	return cost


func _all_level_2_buildings() -> Array[BuildingData]:
	var result: Array[BuildingData] = []
	for file in DirAccess.get_files_at("res://resources/buildings"):
		if file.ends_with("_L2.tres"):
			result.append(load("res://resources/buildings".path_join(file)))
	return result


func test_the_five_shipping_chapters_are_found() -> void:
	assert_eq(_chapters.size(), 5)
	assert_gt(_required(5, [C.BUILD_STRUCTURE]).size(), 0, "fixture: Ch1-5 do require buildings")


func test_no_required_building_tech_or_ship_costs_eights() -> void:
	for o in _required(5, [C.BUILD_STRUCTURE, C.UPGRADE_STRUCTURE_TO_LEVEL]):
		var b: BuildingData = _island_resolver._resolve_building(o.target_id)
		assert_not_null(b, "objective %s's building %s resolves" % [o.objective_id, o.target_id])
		if b:
			assert_false(b.get_cost_dict().has(EIGHTS), "%s costs no Eights" % b.building_id)
	for o in _required(5, [C.UNLOCK_TECH]):
		var t := _tech(o.target_id)
		assert_not_null(t, "objective %s's tech %s resolves" % [o.objective_id, o.target_id])
		if t:
			assert_false(t.get_cost_dict().has(EIGHTS), "%s costs no Eights" % t.tech_id)
	for o in _required(5, [C.OWN_SHIP_CLASS]):
		var hulls := _ships_of_class(int(o.target_value))
		assert_gt(hulls.size(), 0, "a class %d hull exists for %s" % [int(o.target_value), o.objective_id])
		for s in hulls:
			assert_false(_ship_cost(s).has(EIGHTS), "%s costs no Eights" % s.ship_id)


func test_ch1_2_required_buildings_are_under_the_early_cap() -> void:
	var cap: float = _pricing.zero_spend_early_cap_seconds
	for o in _required(2, [C.BUILD_STRUCTURE]):
		var b: BuildingData = _island_resolver._resolve_building(o.target_id)
		var d: float = _pricing.effective_duration("build", b.build_seconds, 1)
		assert_lte(d, cap, "%s takes %.0fs at island tier 1 (cap %.0fs)" % [b.building_id, d, cap])


func test_every_level_2_upgrade_is_under_the_early_cap() -> void:
	# Island tier 2 (Ch1's tier objective, and every tier-2 gate) is reached by
	# upgrading buildings to Level 2 — each of those jobs counts as Ch1-2 play.
	var cap: float = _pricing.zero_spend_early_cap_seconds
	var l2 := _all_level_2_buildings()
	assert_gt(l2.size(), 0)
	for b in l2:
		var d: float = _pricing.effective_duration("upgrade", b.build_seconds, 1)
		assert_lte(d, cap, "%s takes %.0fs at island tier 1 (cap %.0fs)" % [b.building_id, d, cap])


func test_a_hull_of_every_ch1_2_required_class_is_under_the_early_cap() -> void:
	var cap: float = _pricing.zero_spend_early_cap_seconds
	for o in _required(2, [C.OWN_SHIP_CLASS]):
		var fastest := INF
		for s in _ships_of_class(int(o.target_value)):
			fastest = minf(fastest, _pricing.effective_duration("ship", s.build_seconds, 1))
		assert_lte(fastest, cap, "a class %d hull builds within %.0fs at a Level 1 Shipyard" % [int(o.target_value), cap])


func test_ch1_2_required_research_is_under_the_early_cap() -> void:
	var cap: float = _pricing.zero_spend_early_cap_seconds
	var required := _required(2, [C.UNLOCK_TECH])
	if required.is_empty():
		pass_test("Ch1-2 require no research today; guards any that is added later")
	for o in required:
		var t := _tech(o.target_id)
		assert_lte(_pricing.effective_duration("research", t.research_seconds, 0), cap, "%s without an Academy" % t.tech_id)


func test_no_job_kind_can_be_shortened_only_by_paying() -> void:
	# The constitution's "every timer must also be reducible by playing", for the
	# authored content: every timed thing has a speed source above level 1.
	for kind in ScheduleManager.KINDS:
		var table: Array = _pricing.speed_multipliers_for(kind)
		assert_lt(float(table[-1]), float(table[0]), "'%s' gets faster with play" % kind)

extends GutTest

## M11 Requirement 1.2 — TechData.required_island_tier / required_prerequisite_tech_id
## gating, checked through TechManager.can_research() (used by IslandMenu's
## Research tab so the gate logic isn't duplicated in UI code).

var tech_manager: Node

func before_each():
	tech_manager = load("res://scripts/managers/TechManager.gd").new()

func after_each():
	if is_instance_valid(tech_manager):
		tech_manager.free()

func _make_tech(tech_id: String, tier: int, prereq: String) -> TechData:
	var t = TechData.new()
	t.tech_id = tech_id
	t.tech_name = tech_id
	t.required_island_tier = tier
	t.required_prerequisite_tech_id = prereq
	return t

func test_tier_locked_tech_cannot_be_researched():
	var tech = _make_tech("test_tier3", 3, "")
	assert_false(tech_manager.can_research(tech, 2), "Tier 3 tech should be locked at island tier 2")
	assert_true(tech_manager.can_research(tech, 3), "Tier 3 tech should be available at island tier 3")

func test_prerequisite_locked_tech_cannot_be_researched():
	var base = _make_tech("test_base", 1, "")
	var advanced = _make_tech("test_advanced", 1, "test_base")

	assert_false(tech_manager.can_research(advanced, 5), "Tech with an unmet prerequisite should be locked regardless of tier")

	tech_manager.unlock_tech(base)
	assert_true(tech_manager.can_research(advanced, 5), "Tech should unlock once its prerequisite is researched")

func test_both_gates_must_be_satisfied():
	var base = _make_tech("test_base2", 1, "")
	var advanced = _make_tech("test_advanced2", 4, "test_base2")

	assert_false(tech_manager.can_research(advanced, 4), "Prerequisite still unmet even though tier is satisfied")

	tech_manager.unlock_tech(base)
	assert_false(tech_manager.can_research(advanced, 2), "Prerequisite met but tier still unmet")
	assert_true(tech_manager.can_research(advanced, 4), "Available once both tier and prerequisite are satisfied")

func test_three_deep_prerequisite_chain():
	var a = _make_tech("chain_a", 1, "")
	var b = _make_tech("chain_b", 2, "chain_a")
	var c = _make_tech("chain_c", 3, "chain_b")

	assert_true(tech_manager.can_research(a, 3), "Root of the chain has no prerequisite")
	assert_false(tech_manager.can_research(b, 3), "Middle of the chain locked until root is researched")
	assert_false(tech_manager.can_research(c, 3), "End of the chain locked until both prior links are researched")

	tech_manager.unlock_tech(a)
	assert_true(tech_manager.can_research(b, 3), "Middle unlocks once root is researched")
	assert_false(tech_manager.can_research(c, 3), "End still locked — middle not yet researched")

	tech_manager.unlock_tech(b)
	assert_true(tech_manager.can_research(c, 3), "End unlocks once the full chain is researched")

func test_already_unlocked_tech_cannot_be_researched_again():
	var tech = _make_tech("test_once", 1, "")
	tech_manager.unlock_tech(tech)
	assert_false(tech_manager.can_research(tech, 5), "An already-unlocked tech should not be re-researchable")

func test_all_authored_tech_resources_load_and_have_valid_ranges():
	var dir = DirAccess.open("res://resources/techs/")
	assert_not_null(dir, "resources/techs/ should exist")
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var count = 0
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var tech: TechData = load("res://resources/techs/" + file_name)
			assert_not_null(tech, "%s should load as a TechData resource" % file_name)
			if tech:
				count += 1
				assert_true(tech.required_island_tier >= 1 and tech.required_island_tier <= 5,
					"%s: required_island_tier should be in 1-5" % file_name)
				assert_true(tech.health_modifier >= 1.0 and tech.damage_modifier >= 1.0
					and tech.speed_modifier >= 1.0 and tech.storage_modifier >= 1.0,
					"%s: modifiers should never be a nerf (< 1.0)" % file_name)
		file_name = dir.get_next()

	assert_true(count >= 12, "M11 targets 12-15 total techs (2 existing + 10-13 new); found %d" % count)

func test_every_prerequisite_id_resolves_to_a_real_authored_tech():
	var dir = DirAccess.open("res://resources/techs/")
	assert_not_null(dir)
	if not dir:
		return

	var ids := {}
	var prereqs := {}
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var tech: TechData = load("res://resources/techs/" + file_name)
			if tech:
				ids[tech.tech_id] = true
				if not tech.required_prerequisite_tech_id.is_empty():
					prereqs[tech.tech_id] = tech.required_prerequisite_tech_id
		file_name = dir.get_next()

	for tech_id in prereqs:
		var prereq_id = prereqs[tech_id]
		assert_true(ids.has(prereq_id), "%s's prerequisite '%s' must match a real authored tech_id" % [tech_id, prereq_id])

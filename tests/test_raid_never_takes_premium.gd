extends GutTest

## AI raids only ever take gold, wood, iron and rum. Research and Eights must
## survive a lost raid untouched (docs/00_VISION.md §19.2).

var empire_manager: Node
var _saved_resources: Dictionary

func before_each():
	empire_manager = load("res://scripts/managers/EmpireManager.gd").new()
	add_child_autoqfree(empire_manager)
	_saved_resources = ResourceManager.current_resources.duplicate()
	await wait_process_frames(1)

func after_each():
	ResourceManager.current_resources = _saved_resources.duplicate()

func test_lost_raid_never_takes_research_or_eights():
	empire_manager.home_island_id = "test_island"
	empire_manager.notoriety = 500.0
	ResourceManager.current_resources = {
		"gold": 1000, "wood": 100, "iron": 40, "rum": 20,
		"research": 800, "eights": 500
	}
	var region = load("res://scripts/world/RegionData.gd").new()
	region.tier = 3

	var report = empire_manager._resolve_raid(load("res://resources/factions/RoyalNavy.tres"), region)

	assert_false(report.repelled, "precondition: the raid must succeed")
	assert_false(report.stolen.has("research"), "research must never be stolen")
	assert_false(report.stolen.has("eights"), "eights must never be stolen")
	assert_eq(ResourceManager.get_resource("research"), 800)
	assert_eq(ResourceManager.get_resource("eights"), 500)
	assert_true(ResourceManager.get_resource("gold") < 1000, "gold is still lootable")

func test_lootable_list_is_exactly_the_four_basics():
	assert_eq(",".join(empire_manager.RAID_LOOTABLE), "gold,wood,iron,rum")

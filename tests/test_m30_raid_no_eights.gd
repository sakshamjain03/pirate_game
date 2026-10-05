extends GutTest

var empire_manager: Node
var _saved_resources: Dictionary

func before_each():
	empire_manager = load("res://scripts/managers/EmpireManager.gd").new()
	add_child_autoqfree(empire_manager)
	_saved_resources = ResourceManager.current_resources.duplicate()
	await wait_process_frames(1)

func after_each():
	ResourceManager.current_resources = _saved_resources.duplicate()

## W0-3.2: Raids never steal the premium currency (Eights).
## With a lost raid and eights=500, eights must remain 500 while other resources drop.
func test_raid_never_steals_eights():
	empire_manager.home_island_id = "test_island"
	empire_manager.notoriety = 500.0  # High attack score

	# Set up resources including eights
	ResourceManager.current_resources = {
		"gold": 1000,
		"wood": 100,
		"iron": 40,
		"rum": 20,
		"research": 0,
		"eights": 500
	}

	var attacking_faction = load("res://resources/factions/RoyalNavy.tres")
	var region = load("res://scripts/world/RegionData.gd").new()
	region.tier = 3  # High tier -> high attack score

	var initial_eights = ResourceManager.get_resource("eights")
	var initial_gold = ResourceManager.get_resource("gold")

	var report = empire_manager._resolve_raid(attacking_faction, region)

	assert_false(report.repelled, "Raid should not be repelled")
	assert_true(report.stolen.size() > 0, "Should steal something")

	# CRITICAL: Eights must not be in the stolen dictionary
	assert_false(report.stolen.has("eights"), "Eights must NEVER be stolen")

	# CRITICAL: Eights balance must be unchanged
	assert_eq(ResourceManager.get_resource("eights"), initial_eights,
		"Eights balance must remain 500, not be affected by raid")

	# Other resources must actually be stolen
	assert_eq(ResourceManager.get_resource("gold"), initial_gold - report.stolen.get("gold", 0),
		"Gold must be stolen as normal")
	assert_true(ResourceManager.get_resource("gold") < initial_gold,
		"Gold must actually decrease from the raid")

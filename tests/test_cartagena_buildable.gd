extends GutTest

# test_cartagena_buildable.gd
# M7 Task 19: docs/13_CAMPAIGN_LEVELS_1-5.md §7 flags Cartagena as Chapter 5's
# "second buildable island" as an explicit risk — the design already supports
# it (Island.gd is per-instance) but no UI flow had ever proven it. This
# exercises the real capture -> build -> upgrade -> tier path against
# Cartagena's actual authored IslandData, the same way it already works for
# Port Royal.

var _island: Node
var _saved_resources: Dictionary
var _saved_region_active: Dictionary
var _created_test_scene: Node3D = null

func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene

	_saved_resources = ResourceManager.current_resources.duplicate()
	ResourceManager.current_resources["gold"] = 100000
	ResourceManager.current_resources["wood"] = 100000
	ResourceManager.current_resources["iron"] = 100000

	# Cartagena is gated behind imperial_waters exactly like every other
	# island — capture_island() no-ops on _should_be_active() otherwise, the
	# same rule that keeps a player from taking it before Chapter 5's gate.
	_saved_region_active = EmpireManager._region_active.duplicate()
	EmpireManager._region_active["imperial_waters"] = true

	_island = load("res://scripts/world/Island.gd").new()
	_island.island_data = load("res://resources/world/CartagenaOutpost.tres").duplicate()
	add_child_autoqfree(_island)
	await wait_process_frames(1)

func after_each():
	ResourceManager.current_resources = _saved_resources.duplicate()
	EmpireManager._region_active = _saved_region_active.duplicate()
	# This file's own current_scene, if it created one, must not outlive it —
	# a leaked one previously corrupted test_navigation_integration.gd's real
	# get_tree().change_scene_to_file() call (freed-lambda-capture crash).
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func test_cartagena_starts_owned_by_spain_and_not_buildable():
	assert_eq(_island.island_data.island_type, IslandData.IslandType.ENEMY,
		"Precondition: Cartagena is Spanish-held before capture")


func test_capturing_cartagena_makes_it_friendly_exactly_like_any_other_island():
	_island.capture_island(load("res://resources/factions/PlayerFaction.tres"))

	assert_eq(_island.island_data.island_type, IslandData.IslandType.FRIENDLY,
		"Island.capture_island() is generic — it must not special-case Port Royal")
	assert_eq(_island.island_data.owner_faction.faction_id, "player")


func test_building_on_a_captured_cartagena_works_identically_to_port_royal():
	_island.capture_island(load("res://resources/factions/PlayerFaction.tres"))

	var farm: BuildingData = load("res://resources/buildings/Farm_L1.tres")
	assert_true(_island.build_structure(farm), "Building must succeed on a captured non-home island")
	assert_true(_island.has_building(farm.building_id))


func test_upgrading_a_building_on_cartagena_works():
	_island.capture_island(load("res://resources/factions/PlayerFaction.tres"))
	var farm_l1: BuildingData = load("res://resources/buildings/Farm_L1.tres")
	_island.build_structure(farm_l1)

	var farm_l2: BuildingData = load("res://resources/buildings/Farm_L2.tres")
	assert_true(_island.upgrade_structure(farm_l1.building_id, farm_l2),
		"Upgrading must work on a captured non-home island exactly like Port Royal")
	assert_true(_island.has_building(farm_l2.building_id))


func test_island_tier_advances_on_cartagena():
	_island.capture_island(load("res://resources/factions/PlayerFaction.tres"))
	var tier_before: int = _island.get_island_tier()

	# Tier is the average building level, so a handful of level-1 structures
	# alone never moves it — at least one real upgrade must land, exactly the
	# same formula Port Royal uses.
	var farm_l1: BuildingData = load("res://resources/buildings/Farm_L1.tres")
	var mill_l1: BuildingData = load("res://resources/buildings/LumberMill_L1.tres")
	_island.build_structure(farm_l1)
	_island.build_structure(mill_l1)
	_island.upgrade_structure(farm_l1.building_id, load("res://resources/buildings/Farm_L2.tres"))
	_island.upgrade_structure(mill_l1.building_id, load("res://resources/buildings/LumberMill_L2.tres"))

	assert_gt(_island.get_island_tier(), tier_before,
		"Tier must recalculate from Cartagena's own buildings, not assume it's always tier 1")

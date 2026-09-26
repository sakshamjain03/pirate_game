extends GutTest

# test_building_type_lookup.gd
# BuildingData.building_id is level-suffixed ("shipyard_l1".."shipyard_l5",
# docs/05_CURRENT_SYSTEMS.md). IslandMenu (Shipyard/Tavern tab gating),
# Island.has_shipyard() (DockingSystem's shipyard offer) and EmpireManager
# (raid defence from fortress/watchtower) all asked has_building("shipyard")
# etc. — an EXACT match that no real resource could ever satisfy, so none of
# those features could trigger in real play. The existing tests missed it by
# hand-building BuildingData with a bare "fortress" id; this uses the real
# .tres files on purpose.

const IslandScript := preload("res://scripts/world/Island.gd")

var _island: Node3D

func before_each():
	_island = IslandScript.new()

func after_each():
	_island.free()


func _built(paths: Array) -> void:
	for p in paths:
		var b: BuildingData = load(p)
		assert_not_null(b, "fixture must load: %s" % p)
		_island.built_buildings.append(b)


func test_any_level_of_a_type_counts():
	_built(["res://resources/buildings/Shipyard_L1.tres", "res://resources/buildings/Tavern_L3.tres",
		"res://resources/buildings/Fortress_L2.tres"])
	assert_true(_island.has_building_type("shipyard"))
	assert_true(_island.has_building_type("tavern"))
	assert_true(_island.has_building_type("fortress"))
	assert_true(_island.has_shipyard(), "DockingSystem's shipyard offer reads this")
	assert_false(_island.has_building_type("watchtower"))


func test_type_match_does_not_bleed_across_similar_prefixes():
	# "farm" must not match an unrelated id that merely starts with it.
	var b := BuildingData.new()
	b.building_id = "farmstead_l1"
	_island.built_buildings.append(b)
	assert_false(_island.has_building_type("farm"))


func test_exact_has_building_keeps_its_exact_semantics():
	# build_structure()'s "already built" check relies on this staying exact.
	_built(["res://resources/buildings/Shipyard_L1.tres"])
	assert_true(_island.has_building("shipyard_l1"))
	assert_false(_island.has_building("shipyard_l2"))
	assert_false(_island.has_building("shipyard"))

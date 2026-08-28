extends GutTest

# test_ammo_properties.gd
# Property-based tests for AmmoData and ShipDamage

class MockShipParent extends Node3D:
	pass

var _created_test_scene: Node3D = null

func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene

func after_each():
	# This file was the one place in the suite that created a fake
	# current_scene and never cleaned it up — every other file with the same
	# "if not get_tree().current_scene" guard silently adopted this leftover
	# node instead of making their own, and it eventually corrupted a real
	# get_tree().change_scene_to_file() call in test_navigation_integration.gd
	# (a freed-lambda-capture crash, only reproducible via the full suite).
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null

func _make_damage_node(stats: ShipStats) -> Dictionary:
	var parent = MockShipParent.new()
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	parent.add_child(dmg)
	add_child_autoqfree(parent)
	return {"parent": parent, "damage": dmg}

func test_round_shot_damages_hull_only():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	stats.max_sails = 100.0
	stats.max_crew = 100.0
	
	var built = _make_damage_node(stats)
	var dmg = built["damage"]
	await wait_process_frames(1) # let _ready finish
	
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")
	assert_not_null(round_shot, "RoundShot resource must exist")
	
	dmg.apply_hit(50.0, round_shot, Vector3.FORWARD)
	
	assert_eq(dmg.hull, 50.0, "Round shot should damage hull (1.0 mult)")
	assert_eq(dmg.sails, 100.0, "Round shot should not damage sails")
	assert_eq(dmg.crew, 100.0, "Round shot should not damage crew")

func test_chain_shot_damages_sails_and_hull():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	stats.max_sails = 100.0
	stats.max_crew = 100.0
	
	var built = _make_damage_node(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)
	
	var chain_shot = preload("res://resources/combat/ammo/ChainShot.tres")
	assert_not_null(chain_shot, "ChainShot resource must exist")
	
	dmg.apply_hit(50.0, chain_shot, Vector3.FORWARD)
	
	assert_eq(dmg.hull, 85.0, "Chain shot should damage hull at 0.3 mult (100 - 50*0.3)")
	assert_eq(dmg.sails, 50.0, "Chain shot should damage sails at 1.0 mult (100 - 50*1.0)")
	assert_eq(dmg.crew, 100.0, "Chain shot should not damage crew")

func test_grape_shot_damages_crew_and_hull():
	var stats = ShipStats.new()
	stats.max_health = 100.0
	stats.max_sails = 100.0
	stats.max_crew = 100.0
	
	var built = _make_damage_node(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)
	
	var grape_shot = preload("res://resources/combat/ammo/GrapeShot.tres")
	assert_not_null(grape_shot, "GrapeShot resource must exist")
	
	dmg.apply_hit(50.0, grape_shot, Vector3.FORWARD)
	
	assert_eq(dmg.hull, 90.0, "Grape shot should damage hull at 0.2 mult (100 - 50*0.2)")
	assert_eq(dmg.sails, 100.0, "Grape shot should not damage sails")
	assert_eq(dmg.crew, 50.0, "Grape shot should damage crew at 1.0 mult (100 - 50*1.0)")

func test_multipliers_never_produce_negative_pools():
	var stats = ShipStats.new()
	stats.max_health = 10.0
	stats.max_sails = 10.0
	stats.max_crew = 10.0
	
	var built = _make_damage_node(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)
	
	# Create an overpowered ammo
	var doom_shot = AmmoData.new()
	doom_shot.hull_damage_mult = 5.0
	doom_shot.sail_damage_mult = 5.0
	doom_shot.crew_damage_mult = 5.0
	
	dmg.apply_hit(100.0, doom_shot, Vector3.FORWARD)
	
	assert_eq(dmg.hull, 0.0, "Hull should clamp at 0")
	assert_eq(dmg.sails, 0.0, "Sails should clamp at 0")
	assert_eq(dmg.crew, 0.0, "Crew should clamp at 0")

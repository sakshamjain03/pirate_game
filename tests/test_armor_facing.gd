extends GutTest

## M11 Requirement 4 — hull-facing armor (bow_armor_multiplier/
## broadside_armor_multiplier/bow_arc_degrees), extending the existing
## stern-crit system in ShipDamage.apply_hit() without replacing it.

class MockShipParent extends RigidBody3D:
	var active_captain: CaptainData = null

var _created_test_scene: Node3D = null

func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene

func after_each():
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null

func _make_ship(stats: ShipStats) -> Dictionary:
	var parent = MockShipParent.new()
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	parent.add_child(dmg)
	add_child(parent)
	return {"parent": parent, "damage": dmg}

func _stats() -> ShipStats:
	var s = ShipStats.new()
	s.max_health = 100.0
	s.stern_arc_degrees = 60.0
	s.stern_crit_multiplier = 2.0
	s.bow_arc_degrees = 60.0
	s.bow_armor_multiplier = 0.5
	s.broadside_armor_multiplier = 1.0
	return s

func test_bow_hit_takes_reduced_damage():
	var built = _make_ship(_stats())
	var dmg = built["damage"]
	await wait_process_frames(1)
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")

	dmg.hull = 100.0
	dmg.apply_hit(10.0, round_shot, Vector3.FORWARD)  # (0,0,-1) — dead ahead, matches the ship's own forward
	assert_eq(dmg.hull, 95.0, "A bow hit should take bow_armor_multiplier (0.5x) damage, not full damage")

func test_broadside_hit_takes_baseline_damage():
	var built = _make_ship(_stats())
	var dmg = built["damage"]
	await wait_process_frames(1)
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")

	dmg.hull = 100.0
	dmg.apply_hit(10.0, round_shot, Vector3.RIGHT)  # 90 degrees from both bow and stern
	assert_eq(dmg.hull, 90.0, "A broadside hit should take the 1.0x baseline, unaffected by bow/stern armor")

func test_stern_hit_still_crits_exactly_as_before():
	var built = _make_ship(_stats())
	var dmg = built["damage"]
	await wait_process_frames(1)
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")

	dmg.hull = 100.0
	dmg.apply_hit(10.0, round_shot, Vector3.BACK)  # (0,0,1) — dead astern
	assert_eq(dmg.hull, 80.0, "Stern-crit behavior (2.0x) must be unchanged by adding bow/broadside armor")

func test_facing_multiplier_composes_multiplicatively_with_ammo_type():
	var built = _make_ship(_stats())
	var dmg = built["damage"]
	await wait_process_frames(1)
	# Chain shot deals reduced hull damage and full sail damage — a second,
	# independent multiplier that should stack with facing, not override it.
	var chain_shot = preload("res://resources/combat/ammo/ChainShot.tres")

	dmg.hull = 100.0
	dmg.sails = 100.0
	dmg.apply_hit(10.0, chain_shot, Vector3.FORWARD)
	var expected_hull = 100.0 - (10.0 * 0.5 * chain_shot.hull_damage_mult)
	var expected_sails = 100.0 - (10.0 * 0.5 * chain_shot.sail_damage_mult)
	assert_almost_eq(dmg.hull, expected_hull, 0.01, "Bow armor and ammo hull_damage_mult should both apply")
	assert_almost_eq(dmg.sails, expected_sails, 0.01, "Bow armor and ammo sail_damage_mult should both apply")

func test_bow_arc_degrees_zero_disables_bow_check_entirely():
	var stats = _stats()
	stats.bow_arc_degrees = 0.0
	var built = _make_ship(stats)
	var dmg = built["damage"]
	await wait_process_frames(1)
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")

	dmg.hull = 100.0
	dmg.apply_hit(10.0, round_shot, Vector3.FORWARD)
	assert_eq(dmg.hull, 90.0, "bow_arc_degrees = 0 should fall through to the broadside baseline, not bow armor")

func test_default_ship_stats_facing_values_are_sane():
	var stats = ShipStats.new()
	assert_true(stats.bow_armor_multiplier < 1.0, "Default bow armor should reduce damage (thick forward timbers)")
	assert_almost_eq(stats.broadside_armor_multiplier, 1.0, 0.01, "Default broadside should be the unmodified baseline")
	assert_gt(stats.stern_crit_multiplier, 1.0, "Stern remains the existing weak-point crit, unaffected by this change")

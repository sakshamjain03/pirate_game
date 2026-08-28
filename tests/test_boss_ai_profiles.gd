extends GutTest

## M11 Requirement 5 — the 2 new bosses (The Iron Vulture, Fortune's Toll),
## following test_combat_integration.gd's precedent of instantiating the real
## scenes rather than mocking them (the D15/D57 failure mode: logic that
## passes in isolation but is dead in the real tree because a scene was never
## wired).

const IRON_VULTURE_BOSS := "res://scenes/world/IronVultureBoss.tscn"
const FORTUNES_TOLL_BOSS := "res://scenes/world/FortunesTollBoss.tscn"

var _root: Node3D
var _created_test_scene: Node3D = null

func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_root = Node3D.new()
	_root.name = "BossRoot"
	add_child_autoqfree(_root)

func after_each():
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null

func _spawn(path: String) -> Node3D:
	var ship = load(path).instantiate() as Node3D
	_root.add_child(ship)
	ship.global_position = Vector3.ZERO
	if ship is RigidBody3D:
		ship.freeze = true
	return ship

func test_both_new_bosses_carry_the_full_combat_component_set():
	for path in [IRON_VULTURE_BOSS, FORTUNES_TOLL_BOSS]:
		var ship = _spawn(path)
		await wait_process_frames(1)

		assert_not_null(ship.get_node_or_null("ShipDamage"), "%s must carry ShipDamage" % path)
		assert_not_null(ship.get_node_or_null("ShipCombat"), "%s must carry ShipCombat" % path)
		assert_not_null(ship.get_node_or_null("ShipMovement"), "%s must carry ShipMovement" % path)
		assert_not_null(ship.get_node_or_null("BuoyancySimulator"), "%s must carry BuoyancySimulator" % path)
		var solver = ship.get_node_or_null("FiringSolver")
		assert_not_null(solver, "%s must carry FiringSolver" % path)
		assert_not_null(solver.ship_stats, "%s FiringSolver must receive ship_stats" % path)
		assert_gt(solver.get_range(), 0.0, "%s must have a usable firing range" % path)

		var ai = ship.get_node_or_null("EnemyAI")
		assert_not_null(ai, "%s must carry EnemyAI" % path)
		assert_not_null(ai.ai_profile, "%s EnemyAI must receive an ai_profile" % path)
		ship.free()

func test_iron_vulture_has_a_distinct_artillery_identity():
	var ship = _spawn(IRON_VULTURE_BOSS)
	await wait_process_frames(1)
	var stats: ShipStats = ship.ship_stats
	var profile: AIProfileData = ship.get_node("EnemyAI").ai_profile

	assert_eq(profile.ammo_preference, "ChainShot",
		"The Iron Vulture's signature is crippling sails, not raw damage")
	assert_gt(stats.cannon_range, 100.0,
		"An artillery specialist should genuinely outrange a standard hull, not just have artillery flavor text")
	assert_almost_eq(stats.max_health, 220.0, 0.01, "Sanity: authored HP matches design intent")
	ship.free()

func test_fortunes_toll_has_a_distinct_balanced_bow_chaser_identity():
	var ship = _spawn(FORTUNES_TOLL_BOSS)
	await wait_process_frames(1)
	var stats: ShipStats = ship.ship_stats
	var profile: AIProfileData = ship.get_node("EnemyAI").ai_profile

	assert_true(stats.has_bow_chaser,
		"Fortune's Toll's positioning threat comes from a bow chaser, distinct from Intransigent's tanking and Cárdenas' multi-stage escalation")
	assert_eq(profile.role, AIProfileData.Role.BOSS, "Bosses are tagged BOSS, per the Intransigent/Cárdenas precedent")
	assert_gt(stats.max_health, 220.0, "Should sit between Intransigent (600) and the Iron Vulture (220) per the reward-tier design")
	assert_lt(stats.max_health, 600.0, "Should sit between Intransigent (600) and the Iron Vulture (220) per the reward-tier design")
	ship.free()

func test_both_bosses_have_authored_ambient_events():
	## M11 Requirement 5 — placement follows _spawn_ghost_ship_boss()'s actual
	## working mechanism (EventManager event_id match -> dedicated spawn
	## function), not the EncounterData/EncounterManager path, which is only
	## consumed by the chapter-gated bosses (Intransigent/Cárdenas).
	for data in [
		["res://resources/world/events/IronVultureBoss.tres", "iron_vulture_boss"],
		["res://resources/world/events/FortunesTollBoss.tres", "fortunes_toll_boss"],
	]:
		var event: EventData = load(data[0])
		assert_not_null(event, "%s should load as EventData" % data[0])
		assert_eq(event.event_id, data[1], "%s event_id must match the EventManager match-case that spawns it" % data[0])
		assert_gt(event.min_region_tier, 1, "A boss-tier event should not be reachable from Beginner Waters")

func test_event_manager_has_a_spawn_function_for_each_new_boss_event_id():
	var mgr = load("res://scripts/managers/EventManager.gd").new()
	assert_true(mgr.has_method("_spawn_iron_vulture_boss"), "EventManager must know how to spawn the Iron Vulture")
	assert_true(mgr.has_method("_spawn_fortunes_toll_boss"), "EventManager must know how to spawn Fortune's Toll")
	mgr.free()

extends GutTest

var spawner: Node
var empire_manager: Node

func before_all():
	# If EmpireManager is not in the tree (autoload), we instantiate one
	# so we can manipulate notoriety safely.
	if not get_tree().root.has_node("EmpireManager"):
		empire_manager = load("res://scripts/managers/EmpireManager.gd").new()
		empire_manager.name = "EmpireManager"
		get_tree().root.add_child(empire_manager)
	else:
		empire_manager = get_tree().root.get_node("EmpireManager")

func after_all():
	if empire_manager and not empire_manager.is_inside_tree():
		pass # Was autoloaded

func before_each():
	spawner = load("res://scripts/combat/EnemySpawner.gd").new()
	
	# To prevent crashes if get_tree().current_scene is null
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		
	add_child_autoqfree(spawner)
	await wait_process_frames(1)

func test_compute_spawn_multiplier():
	if empire_manager:
		empire_manager.notoriety = 100.0
		
	var mult_t1 = spawner.compute_spawn_multiplier(1)
	var mult_t2 = spawner.compute_spawn_multiplier(2)
	var mult_t3 = spawner.compute_spawn_multiplier(3)
	
	assert_true(mult_t1 <= mult_t2, "Multiplier should be non-decreasing with tier")
	assert_true(mult_t2 <= mult_t3, "Multiplier should be non-decreasing with tier")
	
	var mult_t2_again = spawner.compute_spawn_multiplier(2)
	assert_eq(mult_t2, mult_t2_again, "Identical inputs should yield identical multipliers")

func test_non_empire_spawns_unaffected():
	var non_empire = load("res://resources/factions/PirateClans.tres")
	
	if empire_manager:
		empire_manager.notoriety = 500.0
		
	spawner.spawn_hunter(non_empire)
	
	await wait_process_frames(1)
	
	var enemies = get_tree().current_scene.get_node_or_null("Enemies")
	assert_not_null(enemies, "Enemies container should exist")
	
	if enemies and enemies.get_child_count() > 0:
		var enemy = enemies.get_child(enemies.get_child_count() - 1)
		var stats = enemy.get("ship_stats")
		assert_not_null(stats, "Spawned enemy should have ship_stats")
		
		if stats:
			var baseline = load("res://resources/enemies/EnemyShipStats.tres")
			assert_eq(stats.max_health, baseline.max_health, "Non-empire health should be unscaled")
			assert_eq(stats.cannon_damage, baseline.cannon_damage, "Non-empire damage should be unscaled")
			assert_eq(stats, baseline, "Non-empire ship_stats should be the shared resource, not a duplicate")
	else:
		fail_test("Enemy was not spawned")

func test_empire_spawns_scaled():
	# Make sure SpanishEmpire is loaded properly and has is_empire = true
	var empire_faction = load("res://resources/factions/SpanishEmpire.tres")
	if not empire_faction:
		empire_faction = FactionData.new()
		empire_faction.is_empire = true
		
	if empire_manager:
		empire_manager.notoriety = 500.0
		
	# Spawn near player/center, since no islands exist, tier will be 1
	spawner.spawn_hunter(empire_faction)
	
	await wait_process_frames(1)
	
	var enemies = get_tree().current_scene.get_node_or_null("Enemies")
	assert_not_null(enemies, "Enemies container should exist")
	
	if enemies and enemies.get_child_count() > 0:
		var enemy = enemies.get_child(enemies.get_child_count() - 1)
		var stats = enemy.get("ship_stats")
		assert_not_null(stats, "Spawned enemy should have ship_stats")
		
		if stats:
			var baseline = load("res://resources/enemies/EnemyShipStats.tres")
			assert_ne(stats, baseline, "Empire ship_stats should be duplicated")
			
			var mult = spawner.compute_spawn_multiplier(1)
			assert_eq(stats.max_health, baseline.max_health * mult, "Empire health should be scaled")
			assert_eq(stats.cannon_damage, baseline.cannon_damage * mult, "Empire damage should be scaled")
	else:
		fail_test("Enemy was not spawned")

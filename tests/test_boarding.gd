extends GutTest

# test_boarding.gd
# Property-based tests for BoardingSystem and BoardingData

class MockShipParent extends RigidBody3D:
	pass

class MockLootDrop extends Node3D:
	func generate_loot() -> Dictionary:
		return {"gold": 100, "rum": 20}

var boarding_system: BoardingSystem
var player_ship: Node
var enemy_ship: Node
var _created_test_scene: Node3D = null

func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene

	boarding_system = load("res://scripts/combat/BoardingSystem.gd").new()
	var bd = BoardingData.new()
	bd.hull_threshold = 0.3
	bd.range = 12.0
	bd.loot_multiplier = 2.0
	bd.win_crew_loss_fraction = 0.1
	bd.lose_crew_loss_fraction = 0.5
	bd.attacker_advantage = 1.2
	boarding_system.boarding_data = bd
	get_tree().current_scene.add_child(boarding_system)

func _make_ship(is_player: bool, stats: ShipStats) -> Node:
	var parent = MockShipParent.new()
	parent.add_to_group("player_ship" if is_player else "enemy_ship")
	
	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	parent.add_child(dmg)
	
	if not is_player:
		var loot = MockLootDrop.new()
		loot.name = "LootDrop"
		parent.add_child(loot)
		
	get_tree().current_scene.add_child(parent)
	return parent
	
func after_each():
	if is_instance_valid(boarding_system):
		boarding_system.queue_free()
	for p in get_tree().get_nodes_in_group("player_ship"):
		if is_instance_valid(p): p.queue_free()
	for e in get_tree().get_nodes_in_group("enemy_ship"):
		if is_instance_valid(e): e.queue_free()
	# This file's own current_scene, if it created one, must not outlive it —
	# a leaked one previously corrupted test_navigation_integration.gd's real
	# get_tree().change_scene_to_file() call (freed-lambda-capture crash).
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null

func test_resolution_is_deterministic_success():
	var p_stats = ShipStats.new()
	p_stats.max_crew = 100.0
	player_ship = _make_ship(true, p_stats)
	var p_dmg = player_ship.get_node("ShipDamage")
	p_dmg.crew = 100.0 # Attacker strength: 100 * 1.0 * 1.2 = 120
	
	var e_stats = ShipStats.new()
	e_stats.max_crew = 100.0
	enemy_ship = _make_ship(false, e_stats)
	var e_dmg = enemy_ship.get_node("ShipDamage")
	e_dmg.crew = 100.0 # Defender strength: 100
	
	await wait_process_frames(1)
	
	boarding_system._eligible_enemy = enemy_ship
	watch_signals(boarding_system)
	
	var success = boarding_system.attempt_boarding()
	assert_true(success, "Attempt should execute")
	
	# Loot is random from StandardEnemyLoot.tres, but we can verify it's a Dictionary.
	# get_signal_parameters() already returns the emission's parameter array, so it
	# is indexed once (signal_args[0]), not twice — the previous signal_args[0][0]
	# indexed into the bool and errored.
	var signal_args = get_signal_parameters(boarding_system, "boarding_resolved")
	assert_not_null(signal_args, "boarding_resolved should be emitted")
	if signal_args and signal_args.size() >= 2:
		var em_success = signal_args[0]
		var em_loot = signal_args[1]
		assert_true(em_success, "Success should be true")
		assert_true(em_loot is Dictionary, "Loot should be a dictionary")
		assert_true(em_loot.size() > 0, "Loot should not be empty")
	
	assert_eq(p_dmg.crew, 90.0, "Attacker should lose 10% crew on win")
	assert_eq(e_dmg.hull, 0.0, "Enemy hull should be 0 on loss")

func test_resolution_is_deterministic_failure():
	var p_stats = ShipStats.new()
	p_stats.max_crew = 100.0
	player_ship = _make_ship(true, p_stats)
	var p_dmg = player_ship.get_node("ShipDamage")
	p_dmg.crew = 50.0 # Attacker strength: 50 * 1.0 * 1.2 = 60
	
	var e_stats = ShipStats.new()
	e_stats.max_crew = 100.0
	enemy_ship = _make_ship(false, e_stats)
	var e_dmg = enemy_ship.get_node("ShipDamage")
	e_dmg.crew = 100.0 # Defender strength: 100
	e_dmg.hull = 100.0 # Give them some hull to start
	
	await wait_process_frames(1)
	
	boarding_system._eligible_enemy = enemy_ship
	watch_signals(boarding_system)
	
	var success = boarding_system.attempt_boarding()
	assert_true(success, "Attempt should execute")
	
	# assert_signal_emitted_with_parameters()'s 4th argument is an emission INDEX,
	# not a message — passing a String there made GUT compare "String == int" and
	# then deep-diff against a null parameter list.
	assert_signal_emitted_with_parameters(boarding_system, "boarding_resolved", [false, {}, "", ""])
	
	assert_eq(p_dmg.crew, 0.0, "Attacker should lose 50% max_crew (50-50) on loss")
	assert_eq(e_dmg.hull, 100.0, "Enemy hull should remain intact on attacker loss")

func test_boarding_a_wreck_twice_grants_loot_only_once():
	## Regression guard: attempt_boarding() used to zero `hull` and emit
	## `destroyed` directly, leaving ShipDamage._is_destroyed false and
	## _eligible_enemy still set. A second call therefore re-rolled the loot
	## table and re-granted the whole payout against the same wreck.
	var p_stats = ShipStats.new()
	p_stats.max_crew = 100.0
	player_ship = _make_ship(true, p_stats)
	var p_dmg = player_ship.get_node("ShipDamage")
	p_dmg.crew = 100.0

	var e_stats = ShipStats.new()
	e_stats.max_crew = 100.0
	enemy_ship = _make_ship(false, e_stats)
	var e_dmg = enemy_ship.get_node("ShipDamage")
	e_dmg.crew = 10.0

	await wait_process_frames(1)

	boarding_system._eligible_enemy = enemy_ship
	assert_true(boarding_system.attempt_boarding(), "First boarding should resolve")
	assert_true(e_dmg.is_destroyed(), "Winning a boarding must mark the hull destroyed")
	assert_eq(boarding_system._eligible_enemy, null, "Eligibility must clear after resolving")

	# Re-arm eligibility exactly as the proximity scan would have, and confirm
	# the destroyed-hull guard refuses the second attempt.
	boarding_system._eligible_enemy = enemy_ship
	assert_false(boarding_system.attempt_boarding(), "Boarding an already-destroyed hull must be refused")

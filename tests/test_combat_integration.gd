extends GutTest

# test_combat_integration.gd
# Guards against the D15/D57 failure mode this project keeps hitting: logic that
# passes in isolation but is dead in the real tree because a scene was never
# wired. These tests instantiate the ACTUAL ship scenes rather than mocks.

const PLAYER_SHIP := "res://scenes/world/PlayerShip.tscn"
const ENEMY_SHIP := "res://scenes/world/EnemyShip.tscn"
const BOSS_SHIP := "res://scenes/world/BossShip.tscn"

var _root: Node3D

func before_each():
	# ShipCombat spawns cannonballs, muzzle flashes and floating damage into
	# get_tree().current_scene, so one has to exist or every volley errors.
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
	_root = Node3D.new()
	_root.name = "IntegrationRoot"
	add_child_autoqfree(_root)

func _spawn(path: String, pos: Vector3) -> Node3D:
	var ship = load(path).instantiate() as Node3D
	_root.add_child(ship)
	ship.global_position = pos
	# There is no Ocean (and so no WaveGenerator) in this bare test root, so
	# BuoyancySimulator has no water surface to work against and would shove the
	# hulls around before the first scan. Freezing pins the transforms, which is
	# what these tests are actually about — targeting and firing, not physics.
	# ShipCombat._physics_process still runs, so auto-fire is unaffected.
	if ship is RigidBody3D:
		ship.freeze = true
	return ship


func test_every_ship_scene_has_the_combat_components_wired():
	for path in [PLAYER_SHIP, ENEMY_SHIP, BOSS_SHIP]:
		var ship = _spawn(path, Vector3.ZERO)
		await wait_process_frames(1)

		assert_not_null(ship.get_node_or_null("ShipDamage"),
			"%s must carry ShipDamage" % path)
		assert_not_null(ship.get_node_or_null("ShipCombat"),
			"%s must carry ShipCombat" % path)
		assert_not_null(ship.get_node_or_null("FiringSolver"),
			"%s must carry FiringSolver — without it the ship can never auto-fire" % path)

		var solver = ship.get_node_or_null("FiringSolver")
		assert_not_null(solver.ship_stats,
			"%s FiringSolver must receive ship_stats, or its range gate is zero" % path)
		assert_gt(solver.get_range(), 0.0, "%s must have a usable firing range" % path)
		ship.free()


func test_authored_cannon_range_is_actually_reachable_by_a_cannonball():
	## cannon_range used to be authored at 150-400 while a ball launched from
	## y≈1.7 with gravity_scale 0.5 splashes after ~0.83 s. Auto-fire gates on
	## this number, so a fantasy range means firing at hulls it can never hit.
	const FALL_TIME := 0.83
	const TOLERANCE := 1.35  # ship's own forward speed extends reach somewhat
	var paths := [
		"res://resources/ships/Dinghy.tres", "res://resources/ships/Schooner.tres",
		"res://resources/ships/Sloop.tres", "res://resources/ships/Corvette.tres",
		"res://resources/ships/Brigantine.tres", "res://resources/ships/Frigate.tres",
		"res://resources/ships/Galleon.tres", "res://resources/ships/ManOWar.tres",
		"res://resources/enemies/EnemyShipStats.tres",
		"res://resources/enemies/IntransigentStats.tres",
		"res://resources/enemies/CardenasEscortStats.tres",
	]
	for p in paths:
		var stats: ShipStats = load(p)
		var reachable: float = stats.cannon_speed * FALL_TIME * TOLERANCE
		assert_lt(stats.cannon_range, reachable,
			"%s: cannon_range %.0f exceeds what cannon_speed %.0f can reach (%.0f)"
			% [p.get_file(), stats.cannon_range, stats.cannon_speed, reachable])
		if stats.has_bow_chaser or stats.has_stern_chaser:
			assert_lt(stats.chaser_range, reachable,
				"%s: chaser_range %.0f exceeds what cannon_speed %.0f can reach (%.0f) — a chaser fires the same cannonball physics as the broadside"
				% [p.get_file(), stats.chaser_range, stats.cannon_speed, reachable])


func test_a_real_player_ship_auto_fires_on_a_real_enemy_in_its_arc():
	## The end-to-end proof of docs/navalCombat.md §4: no input, correct
	## positioning, cannonballs in the water.
	var player = _spawn(PLAYER_SHIP, Vector3.ZERO)
	# Default orientation faces -Z, so +X is the starboard beam. 45 units is
	# inside the Sloop's authored 85-unit range.
	_spawn(ENEMY_SHIP, Vector3(45, 0, 0))

	# Watch from the very first frame: the solver scans on its first physics tick
	# by design, so the opening volley lands almost immediately and the 0.5 s
	# reload then outlasts any short window opened after the fact.
	var combat = player.get_node("ShipCombat")
	watch_signals(combat)
	await wait_physics_frames(4)

	var solver = player.get_node("FiringSolver")
	assert_true(solver.is_aligned(FiringSolver.SIDE_STARBOARD),
		"A real enemy off the real player ship's starboard beam must lock")
	assert_signal_emitted(combat, "fired",
		"The player ship must fire with no input at all once the arc lines up")
	assert_eq(get_signal_parameters(combat, "fired", 0)[0], FiringSolver.SIDE_STARBOARD,
		"...from the side that actually bears")


func test_a_real_player_ship_does_not_auto_fire_at_a_bow_on_enemy():
	var player = _spawn(PLAYER_SHIP, Vector3.ZERO)
	_spawn(ENEMY_SHIP, Vector3(0, 0, -45))

	var combat = player.get_node("ShipCombat")
	watch_signals(combat)
	await wait_physics_frames(4)

	var solver = player.get_node("FiringSolver")
	assert_false(solver.has_any_target(),
		"Bow-on, no broadside bears — the player has to turn to bring guns round")
	assert_signal_not_emitted(combat, "fired", "...so nothing should fire")


func test_respawn_restores_a_real_player_ship_to_a_fightable_state():
	## Slice 0's fix, verified on the real scene rather than a mock: the old
	## respawn left an unkillable hull-0 ship.
	var player = _spawn(PLAYER_SHIP, Vector3.ZERO)
	await wait_process_frames(1)

	var dmg = player.get_node("ShipDamage")
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")
	dmg.apply_hit(100000.0, round_shot, Vector3.FORWARD)
	assert_true(dmg.is_destroyed(), "Precondition: the ship sank")

	player.respawn(Vector3(10, 0, 10))
	await wait_process_frames(1)

	assert_false(dmg.is_destroyed(), "Respawn must clear the destroyed flag")
	assert_gt(dmg.hull, 0.0, "Respawn must restore hull")
	assert_eq(dmg.hull, dmg.get_pool_maximum("hull"), "...to full")
	assert_eq(dmg.sails, dmg.get_pool_maximum("sails"), "...and sails")
	assert_eq(dmg.crew, dmg.get_pool_maximum("crew"), "...and crew")

	var hull_before: float = dmg.hull
	dmg.apply_hit(25.0, round_shot, Vector3.FORWARD)
	assert_lt(dmg.hull, hull_before, "A respawned ship must be damageable again")


func test_the_player_ship_scene_carries_the_whole_combat_loop():
	## Every piece of the V1 loop has to be present on the actual scene, not just
	## importable. This is the wiring check that D15/D57 would have caught.
	var player = _spawn(PLAYER_SHIP, Vector3.ZERO)
	await wait_process_frames(1)

	for node_name in ["ShipDamage", "ShipCombat", "FiringSolver", "CombatModifiers",
			"CaptainAbility"]:
		assert_not_null(player.get_node_or_null(node_name),
			"PlayerShip.tscn must carry %s" % node_name)

	# The starter captain must actually have a usable verb in the real scene.
	var ability_node = player.get_node("CaptainAbility")
	assert_true(ability_node.has_ability(),
		"The default captain on PlayerShip.tscn must have an authored active ability")
	assert_true(ability_node.is_ready(), "...ready to use from the first frame")
	assert_true(ability_node.activate(), "...and it must actually fire on the real scene")


func test_the_world_scene_wires_the_encounter_and_upgrade_systems():
	## Loads World.tscn's own node structure without running it, so a missing
	## EncounterManager or an empty pool is caught here rather than in playtest.
	var world: PackedScene = load("res://scenes/world/World.tscn")
	assert_not_null(world, "World.tscn must load")
	var state := world.get_state()

	var found_encounter_manager := false
	for i in range(state.get_node_count()):
		if state.get_node_name(i) != "EncounterManager":
			continue
		found_encounter_manager = true
		var pool: Array = []
		var upgrades: Array = []
		for p in range(state.get_node_property_count(i)):
			match state.get_node_property_name(i, p):
				"encounter_pool": pool = state.get_node_property_value(i, p)
				"upgrade_pool": upgrades = state.get_node_property_value(i, p)
		assert_gt(pool.size(), 0,
			"EncounterManager must have an authored encounter pool or no fight ever starts")
		assert_gt(upgrades.size(), 5,
			"EncounterManager must have an authored upgrade pool or offers are empty")

	assert_true(found_encounter_manager,
		"World.tscn must contain Systems/EncounterManager")

	# And the superseded system must be gone, not merely unused.
	var world_text := FileAccess.get_file_as_string("res://scenes/world/World.tscn")
	assert_false(world_text.contains("WorldEventManager.gd"),
		"World.tscn must no longer reference the deleted WorldEventManager script")

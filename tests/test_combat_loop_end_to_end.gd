extends GutTest

# test_combat_loop_end_to_end.gd
# The V1 combat loop, driven through the REAL scenes, in order:
#
#   World -> Enter Battle -> Control Ship -> Fight Enemy -> Cannon System
#   -> Captain Ability -> Temporary Upgrade Choice -> Win/Lose -> Rewards -> World
#
# Every other combat test covers one component. This one covers the seam between
# them, which is where this project's recurring defect class actually lives (D15,
# D57, and the five dead `current_health` writers found in this milestone's audit).

const PLAYER_SHIP := "res://scenes/world/PlayerShip.tscn"
const ENEMY_SHIP := "res://scenes/world/EnemyShip.tscn"

var _root: Node
var _systems: Node
var _mgr: EncounterManager
var _player: Node3D


func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene

	_root = Node3D.new()
	_root.name = "LoopRoot"
	add_child_autoqfree(_root)

	_systems = Node.new()
	_systems.name = "Systems"
	_root.add_child(_systems)

	var spawner = load("res://scripts/combat/EnemySpawner.gd").new()
	spawner.name = "EnemySpawner"
	# Ambient population off: this test is about a bounded encounter, and stray
	# roamers would make the objective count non-deterministic.
	spawner.initial_enemies = 0
	spawner.max_enemies = 0
	_systems.add_child(spawner)

	_mgr = EncounterManager.new()
	_mgr.name = "EncounterManager"
	_mgr.ambient_enabled = false
	_mgr.upgrade_pool = _pool()
	_mgr.choices_per_offer = 3
	_systems.add_child(_mgr)

	# The real player ship, with its real captain and its real components.
	_player = load(PLAYER_SHIP).instantiate() as Node3D
	_root.add_child(_player)
	_player.global_position = Vector3.ZERO
	# No Ocean here, so freeze rather than let buoyancy fling the hull around.
	if _player is RigidBody3D:
		_player.freeze = true

	await wait_process_frames(1)


func after_each():
	# Encounters pause ambient spawning and the upgrade screen pauses the tree;
	# never leave either latched for the next test script.
	get_tree().paused = false


func _pool() -> Array[BattleUpgradeData]:
	var out: Array[BattleUpgradeData] = []
	for f in ["HeavyVolley", "RapidReload", "EmergencyRepairs", "FullSail", "LongNines"]:
		out.append(load("res://resources/combat/upgrades/%s.tres" % f))
	return out


func _encounter() -> EncounterData:
	var d: EncounterData = load("res://resources/combat/encounters/Skirmish.tres").duplicate()
	d.enemy_count = 2
	d.upgrade_offers = 1
	d.upgrade_interval = 0.05
	d.spawn_distance_min = 40.0
	d.spawn_distance_max = 45.0
	d.time_limit = 0.0
	return d


func _freeze_enemies() -> void:
	for e in _mgr._enemies:
		if is_instance_valid(e) and e is RigidBody3D:
			e.freeze = true


func test_the_whole_v1_combat_loop_runs_through_the_real_scenes():
	var combat = _player.get_node("ShipCombat")
	var solver = _player.get_node("FiringSolver")
	var mods: CombatModifiers = _player.get_node("CombatModifiers")
	var ability: CaptainAbility = _player.get_node("CaptainAbility")
	var dmg = _player.get_node("ShipDamage")

	# --- Control Ship: the real ship is steerable and undamaged ---
	assert_false(_player.is_docked, "The player starts free to sail")
	assert_eq(dmg.hull, dmg.get_pool_maximum("hull"), "...at full hull")

	# --- Enter Battle ---
	watch_signals(_mgr)
	assert_true(_mgr.start_encounter(_encounter()), "An encounter must start")
	_freeze_enemies()
	assert_eq(_mgr._enemies.size(), 2, "...with its authored composition present")
	assert_signal_emitted(_mgr, "encounter_started", "...and announced")

	# --- Captain Ability: a real captain with a real authored verb ---
	assert_true(ability.has_ability(),
		"The real starter captain must have an authored active ability")
	var speed_before: float = mods.speed_mult
	var damage_before: float = mods.damage_mult
	assert_true(ability.activate(), "The ability must fire")
	assert_true(mods.speed_mult != speed_before or mods.damage_mult != damage_before
			or mods.fire_rate_mult != 1.0 or mods.range_mult != 1.0,
		"...and change something measurable about the ship")
	assert_false(ability.is_ready(), "...then go on cooldown")

	# --- Cannon System: the special volley, and auto-fire on alignment ---
	assert_true(combat.is_special_broadside_ready(), "The full broadside starts ready")
	assert_true(combat.fire_special_broadside(), "...and fires on demand")
	assert_false(combat.is_special_broadside_ready(), "...then cools down")

	# Place a hostile squarely off the starboard beam and let auto-fire take it.
	var target = load(ENEMY_SHIP).instantiate() as Node3D
	_root.add_child(target)
	target.global_position = Vector3(40, 0, 0)
	if target is RigidBody3D:
		target.freeze = true
	watch_signals(combat)
	# Long enough for two things the special volley above just consumed: the
	# solver's 0.1 s retarget interval, and the per-side reload (fire_rate 2.0 =>
	# 0.5 s). A shorter window would be asserting against the reload gate working,
	# not against auto-fire failing.
	await wait_seconds(0.8)
	assert_true(solver.is_aligned(FiringSolver.SIDE_STARBOARD),
		"A hostile off the beam must lock the starboard battery")
	assert_signal_emitted(combat, "fired",
		"...and the guns must fire themselves, with no input")
	target.queue_free()

	# --- Temporary Upgrade Choice (the 0.8 s wait above already covered the
	# 0.05 s authored cadence) ---
	assert_signal_emitted(_mgr, "upgrade_offer_requested", "An offer must arrive on cadence")
	var offer = get_signal_parameters(_mgr, "upgrade_offer_requested", 0)
	var choices: Array = offer[0]
	assert_eq(choices.size(), 3, "...with three cards")
	assert_true(_mgr.apply_upgrade_choice(choices[0]), "...one of which can be taken")
	assert_eq(mods.get_applied_upgrades().size(), 1, "...and is recorded on the build")

	# --- Win ---
	var gold_before: int = int(ResourceManager.current_resources.get("gold", 0))
	for e in _mgr._enemies.duplicate():
		if is_instance_valid(e):
			e.get_node("ShipDamage").mark_destroyed()
			_mgr._on_encounter_enemy_destroyed(e)
	await wait_process_frames(2)

	assert_false(_mgr.is_active(), "Sinking the composition must end the battle")
	assert_signal_emitted(_mgr, "encounter_ended", "...and report an outcome")
	var ended = get_signal_parameters(_mgr, "encounter_ended", 0)
	assert_true(ended[0], "...a victory")

	# --- Rewards ---
	assert_false(ended[1].is_empty(), "Victory must pay something")
	assert_gt(int(ResourceManager.current_resources.get("gold", 0)), gold_before,
		"...and it must actually reach the player's purse")

	# --- Return to World: the build is gone, the ship sails on ---
	assert_eq(mods.damage_mult, 1.0, "Battle upgrades must not survive the battle")
	assert_eq(mods.get_applied_upgrades().size(), 0, "...nor be remembered")
	assert_false(_player.is_docked, "The player is back in the open world")


func test_losing_the_battle_returns_to_the_world_without_confiscating_progress():
	## docs/navalCombat.md §17: "try a better strategy", never "you lost 3 hours".
	var mods: CombatModifiers = _player.get_node("CombatModifiers")
	var dmg = _player.get_node("ShipDamage")

	watch_signals(_mgr)
	_mgr.start_encounter(_encounter())
	_freeze_enemies()
	_mgr.apply_upgrade_choice(load("res://resources/combat/upgrades/HeavyVolley.tres"))
	assert_gt(mods.damage_mult, 1.0, "Precondition: a build is live")

	var gold_before: int = int(ResourceManager.current_resources.get("gold", 0))
	dmg.apply_hit(100000.0, load("res://resources/combat/ammo/RoundShot.tres"), Vector3.FORWARD)
	await wait_process_frames(2)

	assert_false(_mgr.is_active(), "A sunk player ends the battle")
	var ended = get_signal_parameters(_mgr, "encounter_ended", 0)
	assert_false(ended[0], "...as a defeat")
	assert_eq(int(ResourceManager.current_resources.get("gold", 0)), gold_before,
		"Defeat must not confiscate resources")
	assert_eq(mods.damage_mult, 1.0, "...and the temporary build is cleared either way")

	# And the ship can be put back in the water and fight again — the loop this
	# milestone's audit found was entirely dead.
	_player.respawn(Vector3(5, 0, 5))
	await wait_process_frames(1)
	assert_false(dmg.is_destroyed(), "Respawn must make the ship whole")
	assert_eq(dmg.hull, dmg.get_pool_maximum("hull"), "...at full hull")
	assert_true(_player.get_node("CaptainAbility").has_ability(),
		"...with the captain's verb still available for the next fight")

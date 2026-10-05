extends GutTest
## M30 Wave 0 (0.16): encounter boundaries.
## B6 — a second start_encounter() returned false silently, and starting one
##      left nearby ambient ships alive inside the "bounded" fight, polluting
##      its authored composition. Now a second start is refused loudly
##      (encounter_failed "busy"), and unprovoked ambient hulls near the centre
##      are parked for the battle and restored after.
## B7 — CombatModifiers.reset() at encounter end wiped every layer. Now it
##      clears only the ENCOUNTER layer (battle upgrades).
## Setup mirrors test_encounters.gd (MockPlayer/MockSpawner).

class MockPlayer extends RigidBody3D:
	var active_captain: CaptainData = null
	var faction: Resource = null
	var is_docked: bool = false

class MockSpawner extends Node:
	var spawning_enabled: bool = true
	var enemy_scene: PackedScene = null
	var _enemies_container: Node = null

var _root: Node
var _mgr: EncounterManager
var _player: MockPlayer
var _created_test_scene: Node3D = null


func before_each() -> void:
	if not get_tree().current_scene:
		var scene := Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_root = Node.new()
	_root.name = "Systems"
	add_child_autoqfree(_root)
	var spawner := MockSpawner.new()
	spawner.name = "EnemySpawner"
	spawner._enemies_container = _root
	_root.add_child(spawner)
	_mgr = EncounterManager.new()
	_mgr.name = "EncounterManager"
	_mgr.ambient_enabled = false
	_root.add_child(_mgr)
	_player = MockPlayer.new()
	_player.add_to_group("player_ship")
	_player.freeze = true
	var dmg: ShipDamage = ShipDamage.new()
	dmg.name = "ShipDamage"
	var stats := ShipStats.new()
	stats.max_health = 100.0
	stats.max_sails = 100.0
	stats.max_crew = 20.0
	dmg.ship_stats = stats
	_player.add_child(dmg)
	var mods := CombatModifiers.new()
	mods.name = "CombatModifiers"
	_player.add_child(mods)
	add_child_autoqfree(_player)
	_player.global_position = Vector3.ZERO


func after_each() -> void:
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func _encounter(id: String = "test_fight") -> EncounterData:
	var d := EncounterData.new()
	d.encounter_id = id
	d.display_name = "Test Fight"
	d.objective = EncounterData.Objective.DESTROY_ALL
	d.enemy_count = 1
	d.enemy_scene = load("res://scenes/world/EnemyShip.tscn")
	d.spawn_distance_min = 40.0
	d.spawn_distance_max = 50.0
	d.upgrade_offers = 0
	d.ambient_clear_radius = 160.0
	return d


func _ambient(at: Vector3) -> Node3D:
	var n := RigidBody3D.new()
	n.freeze = true
	n.add_to_group("enemy_ship")
	n.add_to_group("ambient_enemy")
	add_child_autoqfree(n)
	n.global_position = at
	return n


func test_second_encounter_is_refused_with_busy() -> void:
	assert_true(_mgr.start_encounter(_encounter("first")))
	watch_signals(_mgr)
	assert_false(_mgr.start_encounter(_encounter("second")))
	assert_signal_emitted_with_parameters(_mgr, "encounter_failed", ["second", EncounterManager.REASON_BUSY])
	assert_eq(_mgr.active_encounter.encounter_id, "first", "the running fight is untouched")


func test_nearby_ambient_is_parked_and_restored() -> void:
	var near := _ambient(Vector3(60, 0, 0))
	var far := _ambient(Vector3(400, 0, 0))
	assert_true(_mgr.start_encounter(_encounter()))
	assert_false(near.is_in_group("enemy_ship"), "a parked hull must not be targetable")
	assert_false(near.is_in_group("ambient_enemy"))
	assert_false(near.visible)
	assert_eq(near.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_true(far.is_in_group("enemy_ship"), "ships outside the radius are left alone")

	_mgr.abandon()
	assert_true(near.is_in_group("enemy_ship"), "restored to targeting after the battle")
	assert_true(near.is_in_group("ambient_enemy"))
	assert_true(near.visible)
	assert_ne(near.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(near.global_position, Vector3(60, 0, 0), "restored where it was")


func test_provoked_ambient_stays_in_the_fight() -> void:
	var angry := _ambient(Vector3(50, 0, 0))
	# Only EnemyAI.is_provoked() is consulted; a stub avoids needing a full ship.
	var stub := _ProvokedAI.new()
	stub.name = "EnemyAI"
	angry.add_child(stub)
	assert_true(_mgr.start_encounter(_encounter()))
	assert_true(angry.is_in_group("enemy_ship"), "a hull already fighting the player is not parked")
	assert_true(angry.visible)


func test_reset_keeps_persistent_and_timed_layers() -> void:
	var mods := CombatModifiers.new()
	add_child_autofree(mods)
	var up := BattleUpgradeData.new()
	up.upgrade_id = "dmg"
	up.effect = BattleUpgradeData.Effect.DAMAGE
	up.magnitude = 1.5
	up.max_stacks = 1
	mods.apply_upgrade(up)
	mods.set_persistent_layer(&"gunners_station", {"fire_rate": 1.08})
	mods.add_timed_effect({"speed": 1.2}, 30.0)
	mods.reset()
	assert_eq(mods.damage_mult, 1.0, "the ENCOUNTER layer (battle upgrades) is cleared")
	assert_almost_eq(mods.fire_rate_mult, 1.08, 0.0001, "a PERSISTENT layer survives reset()")
	assert_almost_eq(mods.speed_mult, 1.2, 0.0001, "a TIMED layer runs out its own clock")
	mods.clear_persistent_layer(&"gunners_station")
	assert_eq(mods.fire_rate_mult, 1.0)


class _ProvokedAI extends Node:
	func is_provoked() -> bool:
		return true

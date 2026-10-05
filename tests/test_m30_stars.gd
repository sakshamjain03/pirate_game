extends GutTest
## M30 Wave 1 (1.13): Sortie Stars. An encounter awards 0–3 cosmetic stars for
## meeting authored conditions. Star conditions evaluate on encounter resolve,
## and are saved in CampaignManager (they never gate progression).

const ENEMY_SCENE := "res://scenes/world/EnemyShip.tscn"

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
	spawner.enemy_scene = load(ENEMY_SCENE)
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
	add_child_autoqfree(_player)
	_player.global_position = Vector3.ZERO


func after_each() -> void:
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func _encounter(id: String = "star_fight") -> EncounterData:
	var d := EncounterData.new()
	d.encounter_id = id
	d.display_name = "Star Fight"
	d.objective = EncounterData.Objective.DESTROY_ALL
	d.enemy_scene = load(ENEMY_SCENE)
	d.enemy_count = 1
	d.spawn_distance_min = 40.0
	d.spawn_distance_max = 50.0
	d.upgrade_offers = 0
	d.ambient_clear_radius = 0.0
	return d


func _star_condition(kind: int, target: float = 0.0) -> StarConditionData:
	var s := StarConditionData.new()
	s.condition = kind
	s.target_value = target
	return s


func test_each_condition_kind_evaluates() -> void:
	var d := _encounter()
	d.star_conditions = [
		_star_condition(StarConditionData.Condition.QUICK_VICTORY, 30.0),  # defeat in 30s
		_star_condition(StarConditionData.Condition.PERFECT_DEFENSE, 0.0),  # take 0 damage
		_star_condition(StarConditionData.Condition.ZERO_LOSSES, 0.0),  # no crew lost
	]
	assert_true(_mgr.start_encounter(d))
	# Instant win (no time elapsed, no damage, no losses)
	await get_tree().process_frame
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	var stars: Array = _mgr._last_encounter_stars
	assert_eq(stars.size(), 3, "all 3 conditions passed")


func test_quick_victory_star_evaluates_by_time() -> void:
	var d := _encounter()
	d.star_conditions = [_star_condition(StarConditionData.Condition.QUICK_VICTORY, 30.0)]
	assert_true(_mgr.start_encounter(d))
	# Simulate 25 seconds elapsed
	_mgr._battle_elapsed = 25.0
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 1, "condition passed (25 < 30)")

	var d2 := _encounter("slow_fight")
	d2.star_conditions = [_star_condition(StarConditionData.Condition.QUICK_VICTORY, 20.0)]
	assert_true(_mgr.start_encounter(d2))
	_mgr._battle_elapsed = 35.0
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "condition failed (35 >= 20)")


func test_perfect_defense_star_evaluates_by_damage() -> void:
	var d := _encounter()
	d.star_conditions = [_star_condition(StarConditionData.Condition.PERFECT_DEFENSE, 0.0)]
	assert_true(_mgr.start_encounter(d))
	# Player takes no damage
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 1, "condition passed")

	var d2 := _encounter("damage_fight")
	d2.star_conditions = [_star_condition(StarConditionData.Condition.PERFECT_DEFENSE, 0.0)]
	assert_true(_mgr.start_encounter(d2))
	# Simulate damage taken: health drops from 100 to 90
	_mgr._player_damage_taken = 10.0
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "condition failed (took damage)")


func test_zero_losses_star_evaluates_by_crew() -> void:
	var d := _encounter()
	d.star_conditions = [_star_condition(StarConditionData.Condition.ZERO_LOSSES, 0.0)]
	assert_true(_mgr.start_encounter(d))
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 1, "condition passed (no crew loss)")

	var d2 := _encounter("losses_fight")
	d2.star_conditions = [_star_condition(StarConditionData.Condition.ZERO_LOSSES, 0.0)]
	assert_true(_mgr.start_encounter(d2))
	# Simulate crew loss: crew drops from 20 to 15
	_mgr._player_crew_lost = 5.0
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "condition failed (crew loss)")


func test_stars_only_awarded_on_victory() -> void:
	var d := _encounter("no_victory")
	d.star_conditions = [_star_condition(StarConditionData.Condition.QUICK_VICTORY, 30.0)]
	assert_true(_mgr.start_encounter(d))
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.DEFEAT))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "no stars on defeat")

	var d2 := _encounter("escaped")
	d2.star_conditions = [_star_condition(StarConditionData.Condition.PERFECT_DEFENSE, 0.0)]
	assert_true(_mgr.start_encounter(d2))
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.ESCAPED))
	assert_eq(_mgr._last_encounter_stars.size(), 0, "no stars on escape")


func test_multiple_conditions_each_evaluated() -> void:
	var d := _encounter()
	d.star_conditions = [
		_star_condition(StarConditionData.Condition.QUICK_VICTORY, 30.0),  # will pass
		_star_condition(StarConditionData.Condition.PERFECT_DEFENSE, 0.0),  # will fail
		_star_condition(StarConditionData.Condition.ZERO_LOSSES, 0.0),  # will pass
	]
	assert_true(_mgr.start_encounter(d))
	_mgr._battle_elapsed = 20.0
	_mgr._player_damage_taken = 5.0  # fail PERFECT_DEFENSE
	_mgr._player_crew_lost = 0.0
	assert_true(_mgr.end_encounter(EncounterManager.Outcome.VICTORY))
	assert_eq(_mgr._last_encounter_stars.size(), 2, "2 of 3 conditions passed")

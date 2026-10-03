extends GutTest

## M29 B.2 — sinking or boarding a faction's ship costs reputation with it.
## The enemy stand-in exposes `faction` as a PROPERTY, exactly like
## ShipController's @export — the first draft of this lane read node metadata,
## which no real ship sets, so sinking never cost anything in play.


class FakeEnemy extends Node3D:
	var faction: Resource


class FakeSpawner extends Node:
	var hunters: Array = []
	func spawn_hunter(faction: Resource) -> void:
		hunters.append(faction)


var _saved_factions: Dictionary
var _saved_mode
var _saved_spawner


func before_each() -> void:
	_saved_factions = FactionManager.get_save_data().duplicate(true)
	_saved_mode = SceneManager.game_mode
	_saved_spawner = FactionManager._spawner
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	FactionManager._event_hunter_cooldown.clear()
	FactionManager.reputation_scores["royal_navy"] = 0
	FactionManager.reputation_scores["spanish_empire"] = 0


func after_each() -> void:
	FactionManager.load_save_data(_saved_factions)
	SceneManager.game_mode = _saved_mode
	FactionManager._spawner = _saved_spawner
	FactionManager._event_hunter_cooldown.clear()


func _enemy(faction_path: String, boarded := false) -> FakeEnemy:
	var e: FakeEnemy = autofree(FakeEnemy.new())
	e.faction = load(faction_path)
	if boarded:
		e.set_meta("loot_claimed", true)
	return e


func test_sinking_costs_reputation_with_the_victims_faction() -> void:
	var spain := load("res://resources/factions/SpanishEmpire.tres") as FactionData
	assert_gt(spain.sink_reputation_loss, 0, "Spain authors a sink loss")
	FactionManager._on_enemy_destroyed(_enemy("res://resources/factions/SpanishEmpire.tres"))
	assert_eq(FactionManager.get_reputation("spanish_empire"), -spain.sink_reputation_loss)
	assert_eq(FactionManager.get_reputation("royal_navy"), 0, "other factions untouched")


func test_sinking_via_the_real_signal_path() -> void:
	# The spawner signal is what play actually uses; FactionManager connects to
	# any EnemySpawner that enters the tree.
	var spawner: EnemySpawner = EnemySpawner.new()
	spawner.spawning_enabled = false
	add_child_autofree(spawner)
	assert_true(spawner.enemy_destroyed.is_connected(FactionManager._on_enemy_destroyed),
		"FactionManager auto-connects to a new EnemySpawner")
	var navy := load("res://resources/factions/RoyalNavy.tres") as FactionData
	spawner.enemy_destroyed.emit(_enemy("res://resources/factions/RoyalNavy.tres"))
	assert_eq(FactionManager.get_reputation("royal_navy"), -navy.sink_reputation_loss)


func test_boarded_ship_takes_only_the_boarding_loss() -> void:
	var navy := load("res://resources/factions/RoyalNavy.tres") as FactionData
	# The boarding resolves first, then the ship is destroyed with loot_claimed set.
	FactionManager._on_boarding_resolved(true, {}, "royal_navy", "hms_test")
	FactionManager._on_enemy_destroyed(_enemy("res://resources/factions/RoyalNavy.tres", true))
	assert_eq(FactionManager.get_reputation("royal_navy"), -navy.boarding_reputation_loss,
		"boarding loss once, no sink loss on top")


func test_failed_boarding_costs_nothing() -> void:
	FactionManager._on_boarding_resolved(false, {}, "royal_navy", "hms_test")
	assert_eq(FactionManager.get_reputation("royal_navy"), 0)


func test_no_consequence_outside_the_campaign() -> void:
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	FactionManager._on_enemy_destroyed(_enemy("res://resources/factions/SpanishEmpire.tres"))
	FactionManager._on_boarding_resolved(true, {}, "royal_navy", "hms_test")
	assert_eq(FactionManager.get_reputation("spanish_empire"), 0)
	assert_eq(FactionManager.get_reputation("royal_navy"), 0)


func test_unknown_faction_id_changes_nothing() -> void:
	# _resolve_faction push_errors "unknown faction_id" (visible in the log); the
	# handler must then stop rather than invent a reputation entry.
	var before := FactionManager.get_save_data().duplicate(true)
	FactionManager._on_boarding_resolved(true, {}, "no_such_faction", "x")
	assert_false(FactionManager.reputation_scores.has("no_such_faction"))
	assert_eq(FactionManager.get_save_data(), before)


func test_successful_boarding_of_an_empire_ship_sends_a_hunter() -> void:
	var spawner: FakeSpawner = autofree(FakeSpawner.new())
	FactionManager._spawner = spawner
	FactionManager._on_boarding_resolved(true, {}, "royal_navy", "hms_test")
	assert_eq(spawner.hunters.size(), 1, "one hunter for the boarded faction")
	assert_eq((spawner.hunters[0] as FactionData).faction_id, "royal_navy")

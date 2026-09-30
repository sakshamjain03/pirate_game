extends GutTest

## Guards M26's EnemySpawner.spawn_profile_override (Requirements 3.2, 3.3, 3.5):
## when set it replaces the heat-tier lookup; unset, nothing about M25 changes.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")

var _scene: Node3D = null
var _spawner: EnemySpawner = null
var _profile := {"cap": 7, "interval": 2.5, "strength": 2.0, "pool": []}


func before_each() -> void:
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_spawner = EnemySpawner.new()
	_spawner.initial_enemies = 0
	_scene.add_child(_spawner)
	_spawner._initialize()


func after_each() -> void:
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.free()
	_scene = null
	_spawner = null


func _get_profile() -> Dictionary:
	return _profile


func test_override_replaces_cap_and_interval() -> void:
	_spawner.spawn_profile_override = _get_profile
	assert_eq(_spawner.get_active_max_enemies(), 7)
	assert_almost_eq(_spawner.get_active_spawn_interval(), 2.5, 0.001)


func test_override_is_read_live_each_call() -> void:
	# MaelstromRun changes band mid-run; the spawner must see it without re-binding.
	_spawner.spawn_profile_override = _get_profile
	_profile = {"cap": 9, "interval": 1.5, "strength": 1.0, "pool": []}
	assert_eq(_spawner.get_active_max_enemies(), 9)
	_profile = {"cap": 7, "interval": 2.5, "strength": 2.0, "pool": []}


func test_unset_override_uses_heat_tier_or_export() -> void:
	var tier = EmpireManager.get_heat_tier() if EmpireManager.has_method("get_heat_tier") else null
	var expected_cap: int = tier.max_ambient_enemies if tier else _spawner.max_enemies
	assert_false(_spawner.spawn_profile_override.is_valid())
	assert_eq(_spawner.get_active_max_enemies(), expected_cap)


func test_profile_spawn_scales_a_duplicate_never_the_shared_stats() -> void:
	# Read the scene's shared stats, then free the probe hull: left orphaned, this
	# RigidBody3D outlived the physics server and crashed the process at engine
	# teardown (the 0xC0000005 every full suite run exited with since M26).
	var probe := ENEMY_SHIP.instantiate() as ShipController
	var shared: ShipStats = probe.ship_stats
	probe.free()
	var shared_health := shared.max_health
	var shared_damage := shared.cannon_damage
	_spawner.spawn_profile_override = _get_profile
	_spawner._spawn_enemy()
	assert_eq(_spawner.get_active_enemy_count(), 1, "one hull spawned")
	var enemy: ShipController = _spawner._active_enemies[0]
	assert_ne(enemy.ship_stats, shared, "spawned hull must own a duplicated ShipStats")
	assert_almost_eq(enemy.ship_stats.max_health, shared_health * 2.0, 0.01, "strength applied")
	assert_almost_eq(enemy.ship_stats.cannon_damage, shared_damage * 2.0, 0.01)
	assert_eq(shared.max_health, shared_health, "Req 3.5: shared resource untouched")


func test_profile_spawn_always_engages() -> void:
	_spawner.spawn_profile_override = _get_profile
	_spawner._spawn_enemy()
	var enemy: Node3D = _spawner._active_enemies[0]
	assert_false(enemy.is_in_group("ambient_enemy"), "heat passivity must not apply")
	var ai = enemy.get_node_or_null("EnemyAI")
	assert_not_null(ai)
	assert_true(ai.is_provoked(), "Req 3.3: engages unprovoked")


func test_profile_pool_picks_from_pool() -> void:
	var boss: PackedScene = load("res://scenes/world/BossShip.tscn")
	_profile = {"cap": 3, "interval": 1.0, "strength": 1.0, "pool": [boss]}
	_spawner.spawn_profile_override = _get_profile
	_spawner._spawn_enemy()
	var enemy: Node3D = _spawner._active_enemies[0]
	assert_eq(enemy.scene_file_path, boss.resource_path)
	_profile = {"cap": 7, "interval": 2.5, "strength": 2.0, "pool": []}


func test_regunned_boss_generated_markers_join_the_tree() -> void:
	# ShipCombat._build_side() used to add generated gun markers directly inside
	# the ship's _ready(), which Godot refuses ("Parent node is busy setting up
	# children") — the Man O'War boss then fired from markers outside the tree.
	var boss: PackedScene = load("res://scenes/world/BossShip.tscn")
	var enemy := _spawner.spawn_scene(boss, 1.0)
	await get_tree().process_frame
	var combat = enemy.get_node("ShipCombat")
	assert_gt(combat._generated_markers.size(), 0, "fixture: BossShip really is re-gunned")
	for m in combat._generated_markers:
		assert_true(m.is_inside_tree(), "generated marker '%s' is in the tree" % m.name)
		assert_eq(m.get_parent(), enemy)


func test_spawn_scene_spawns_and_tracks_boss() -> void:
	var boss: PackedScene = load("res://scenes/world/BossShip.tscn")
	watch_signals(_spawner)
	var enemy := _spawner.spawn_scene(boss, 1.5)
	assert_not_null(enemy)
	assert_signal_emitted(_spawner, "enemy_spawned")
	assert_true(_spawner._active_enemies.has(enemy), "boss is tracked so its kill counts")

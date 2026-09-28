extends GutTest

## Guards M26's MaelstromRun (Requirements 3.3, 3.4, 4.1-4.3, 5.2, 5.4): kills
## scatter pickups, pickups route to run-only effects, level-ups queue one offer
## at a time, bands drive the spawner and spawn their boss once.

const PLAYER_SHIP := preload("res://scenes/world/PlayerShip.tscn")
const USER_FILES := ["user://save_data.json", "user://save_data.json.bak", "user://maelstrom_pending.json"]

var _scene: Node3D = null
var _run: MaelstromRun = null
var _spawner: EnemySpawner = null
var _player: RigidBody3D = null
var _file_backup := {}
var _resources_before: Dictionary


func before_each() -> void:
	# _end_run() persists through SaveManager; never leave a test's write behind.
	_file_backup.clear()
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			_file_backup[path] = FileAccess.get_file_as_string(path)
			DirAccess.remove_absolute(path)
	_resources_before = ResourceManager.current_resources.duplicate()

	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene
	_player = PLAYER_SHIP.instantiate()
	_scene.add_child(_player)
	_run = MaelstromRun.new()
	_spawner = EnemySpawner.new()
	_spawner.name = "EnemySpawner"
	_spawner.initial_enemies = 0
	_run.add_child(_spawner)
	_scene.add_child(_run)
	_spawner._initialize()   # normally deferred


func after_each() -> void:
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	ResourceManager.current_resources = _resources_before
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.free()
	_scene = null
	for path in USER_FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if _file_backup.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(_file_backup[path])
			f.close()


func _pickups() -> Array:
	var out := []
	for c in _scene.get_children():
		if c is LootDrop:
			out.append(c)
	return out


func _modifiers() -> CombatModifiers:
	return _player.get_node("CombatModifiers")


func test_ready_sets_mode_and_binds_spawner() -> void:
	assert_eq(SceneManager.game_mode, SceneManager.GameMode.MAELSTROM)
	assert_true(_spawner.spawn_profile_override.is_valid(), "spawner is driven by the curve")
	assert_eq(_run.state, MaelstromRun.State.RUNNING)


func test_profile_follows_the_band_for_elapsed_time() -> void:
	var curve := _run.curve
	_run.elapsed = 0.0
	assert_eq(_spawner.get_active_max_enemies(), curve.bands[0].max_enemies)
	_run.elapsed = 99999.0
	assert_eq(_spawner.get_active_max_enemies(), curve.bands.back().max_enemies)
	assert_almost_eq(_spawner.get_active_spawn_interval(), curve.bands.back().spawn_interval, 0.001)


func test_kill_scatters_rolled_pickups() -> void:
	var curve := _run.curve
	_run._on_kill(Vector3(30, 0, 30))
	var drops := _pickups()
	assert_between(drops.size(), curve.drops_per_kill.x, curve.drops_per_kill.y, "Req 4.1")
	for d in drops:
		assert_true(d.loot_data.has("kind"), "every pickup carries a kind")
		assert_almost_eq(d.lifetime, curve.pickup_lifetime, 0.001, "Req 4.3: authored lifetime")
		assert_gt(d.magnet_range, d.pickup_range, "magnet reaches past the pickup radius")
	assert_eq(_run.kills, 1)


func test_pickup_radius_upgrade_widens_new_drops() -> void:
	var u := BattleUpgradeData.new()
	u.upgrade_id = "t_radius"
	u.effect = BattleUpgradeData.Effect.PICKUP_RADIUS
	u.magnitude = 2.0
	_modifiers().apply_upgrade(u)
	var drop := _run._spawn_pickup({"kind": "plunder", "amount": 1.0}, Vector3(40, 0, 0))
	assert_almost_eq(drop.pickup_range, _run.curve.base_pickup_radius * 2.0, 0.001, "Req 4.4")


func test_two_thresholds_queue_two_offers_shown_one_at_a_time() -> void:
	var curve := _run.curve
	watch_signals(_run)
	_run.add_plunder(curve.xp_for_level(1) + curve.xp_for_level(2))
	assert_eq(_run.level, 3)
	assert_eq(_run.pending_offers(), 2, "Req 5.4: both level-ups queued")

	_run._maybe_offer()
	_run._maybe_offer()
	assert_signal_emit_count(_run, "upgrade_offer_requested", 1, "only one offer open at a time")
	assert_eq(_run.state, MaelstromRun.State.OFFERING)

	var params: Array = get_signal_parameters(_run, "upgrade_offer_requested", 0)
	var choices: Array = params[0]
	assert_eq(choices.size(), curve.choices_per_offer, "Req 5.2: three choices")
	_run.apply_upgrade_choice(choices[0])
	assert_eq(_run.pending_offers(), 1)
	assert_eq(_run.state, MaelstromRun.State.RUNNING)

	_run._maybe_offer()
	assert_signal_emit_count(_run, "upgrade_offer_requested", 2, "the queued offer follows")


func test_offered_choices_all_pass_can_apply() -> void:
	# Max out everything but two upgrades; only those two may be offered.
	var mods := _modifiers()
	var pool := _run.curve.upgrade_pool
	for i in range(2, pool.size()):
		for s in range(pool[i].max_stacks):
			mods.apply_upgrade(pool[i])
	var choices := _run.pick_choices()
	assert_eq(choices.size(), 2)
	for c in choices:
		assert_true(mods.can_apply(c), "'%s' is still applicable" % c.upgrade_id)
		assert_true(c == pool[0] or c == pool[1])


func test_fully_maxed_pool_never_hangs_the_run() -> void:
	var mods := _modifiers()
	for u in _run.curve.upgrade_pool:
		for s in range(u.max_stacks):
			mods.apply_upgrade(u)
	_run.add_plunder(_run.curve.xp_for_level(1))
	_run._maybe_offer()
	assert_eq(_run.state, MaelstromRun.State.RUNNING)
	assert_eq(_run.pending_offers(), 0)


func test_repair_pickup_calls_repair_pool() -> void:
	var dmg: ShipDamage = _player.get_node("ShipDamage")
	var maximum := dmg.get_pool_maximum("hull")
	dmg.hull = maximum * 0.5
	_run._on_pickup({"kind": "repair", "amount": 0.2})
	assert_almost_eq(dmg.hull, maximum * 0.7, 0.01, "Req 4.2: repair_pool('hull', 0.2)")


func test_powerup_pickup_adds_timed_effect() -> void:
	_run._on_pickup({"kind": "powerup", "effect": {"speed": 1.5}, "duration": 5.0})
	assert_true(_modifiers().has_timed_effect())
	assert_almost_eq(_modifiers().speed_mult, 1.5, 0.001)


func test_keg_damages_enemies_in_radius_only() -> void:
	_spawner.spawn_profile_override = func(): return {"cap": 5, "interval": 1.0, "strength": 1.0, "pool": []}
	_spawner._spawn_enemy()
	_spawner._spawn_enemy()
	var near: Node3D = _spawner._active_enemies[0]
	var far: Node3D = _spawner._active_enemies[1]
	near.global_position = Vector3(500, 0.3, 0)
	far.global_position = Vector3(500 + _run.curve.keg_radius * 3.0, 0.3, 0)
	var near_hull: float = near.get_node("ShipDamage").hull
	var far_hull: float = far.get_node("ShipDamage").hull
	_run._on_pickup({"kind": "keg"}, Vector3(500, 0, 0))
	assert_lt(near.get_node("ShipDamage").hull, near_hull, "Req 4.2: keg damages hulls in radius")
	assert_eq(far.get_node("ShipDamage").hull, far_hull, "outside the radius is untouched")


func test_pickups_never_touch_campaign_resources() -> void:
	_run._on_pickup({"kind": "plunder", "amount": 3.0})
	_run._on_pickup({"kind": "repair", "amount": 0.1})
	_run._on_pickup({"kind": "powerup", "effect": {"damage": 1.2}, "duration": 2.0})
	assert_eq(ResourceManager.current_resources, _resources_before, "Req 2.2")


func test_band_boss_spawns_once_on_entering_its_band() -> void:
	var boss_band := -1
	for i in range(_run.curve.bands.size()):
		if _run.curve.bands[i].boss_scene:
			boss_band = i
			break
	assert_gt(boss_band, -1, "curve authors a boss band")
	_run.elapsed = _run.curve.bands[boss_band].start_seconds
	_run._process(0.0)
	var count_after_entry := _spawner.get_active_enemy_count()
	assert_eq(count_after_entry, 1, "Req 3.4: boss spawned at band start")
	_run._process(0.1)
	assert_eq(_spawner.get_active_enemy_count(), count_after_entry, "and only once")


func test_player_death_ends_run_and_stops_spawning() -> void:
	watch_signals(_run)
	_run.elapsed = 400.0
	_player.ship_destroyed.emit()
	assert_eq(_run.state, MaelstromRun.State.ENDED)
	assert_false(_spawner.spawning_enabled, "Req 6.1: spawning stops")
	assert_signal_emitted(_run, "run_ended")
	var summary: Dictionary = get_signal_parameters(_run, "run_ended")[0]
	assert_eq(summary["eights"], _run.curve.eights_for(400.0), "Req 6.2")
	for key in ["seconds", "kills", "level", "best_seconds", "best_level"]:
		assert_true(summary.has(key), "summary has '%s'" % key)


func test_death_mid_offer_closes_the_choice_panel() -> void:
	watch_signals(_run)
	_run.add_plunder(_run.curve.xp_for_level(1))
	_run._maybe_offer()
	_run._end_run()
	assert_signal_emitted(_run, "encounter_ended", "UpgradeChoiceScreen closes on this")

extends GutTest

# test_ai_difficulty.gd — M23 Requirement 6.

const PATH := "user://test_ai_difficulty_settings.cfg"

var _scene: Node3D = null


func before_each():
	# fire_broadside() spawns cannonballs/muzzle flashes into current_scene.
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func after_each():
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.queue_free()
	_scene = null
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _manager() -> Node:
	var m = load("res://scripts/managers/SettingsManager.gd").new()
	m._settings_path = PATH
	add_child_autoqfree(m)
	return m


func test_every_level_resource_loads():
	var m = _manager()
	for i in m.AI_DIFFICULTY_PATHS.size():
		m.ai_difficulty = i
		assert_true(m.get_ai_difficulty_profile() is AIDifficultyData, "level %d must load" % i)


func test_default_is_normal_and_normal_is_gentler_than_hard():
	var m = _manager()
	assert_eq(m.ai_difficulty, 1)
	var normal: AIDifficultyData = m.get_ai_difficulty_profile()
	m.ai_difficulty = 2
	var hard: AIDifficultyData = m.get_ai_difficulty_profile()
	assert_lt(normal.damage_mult, hard.damage_mult)
	assert_gt(normal.reload_time_mult, hard.reload_time_mult)
	assert_gt(normal.spread_mult, hard.spread_mult)


func test_difficulty_round_trips_through_settings_file():
	var m = _manager()
	m.ai_difficulty = 3
	m.save_settings()
	var m2 = _manager()
	m2.load_settings()
	assert_eq(m2.ai_difficulty, 3)


func test_out_of_range_value_is_clamped():
	var m = _manager()
	m.ai_difficulty = 99
	assert_eq(m.ai_difficulty, m.AI_DIFFICULTY_PATHS.size() - 1)


func test_applies_only_to_hostile_ships():
	var enemy := Node3D.new()
	enemy.add_to_group("enemy_ship")
	var player := Node3D.new()
	player.add_to_group("player_ship")
	var escort := Node3D.new()
	escort.add_to_group("friendly_ship")
	add_child_autoqfree(enemy)
	add_child_autoqfree(player)
	add_child_autoqfree(escort)
	assert_true(AIDifficultyData.applies_to(enemy))
	assert_false(AIDifficultyData.applies_to(player))
	assert_false(AIDifficultyData.applies_to(escort))
	assert_null(AIDifficultyData.for_ship(player))


func test_enemy_reload_scales_with_live_setting_change():
	var original: int = SettingsManager.ai_difficulty
	var ship := RigidBody3D.new()
	ship.add_to_group("enemy_ship")
	var m := Marker3D.new()
	m.name = "PortMarker1"
	ship.add_child(m)
	var stats := ShipStats.new()
	stats.fire_rate = 1.0
	var combat := ShipCombat.new()
	combat.ship_stats = stats
	combat.auto_fire_enabled = false
	ship.add_child(combat)
	add_child_autoqfree(ship)

	SettingsManager.ai_difficulty = 2  # Hard: reload_time_mult 1.0 -> 1.0 s
	assert_true(combat.fire_broadside("port"))
	await wait_seconds(1.1)
	assert_true(combat.can_fire_port, "Hard reload is the authored 1 s")

	SettingsManager.ai_difficulty = 0  # Relaxed: 1.4 s
	assert_true(combat.fire_broadside("port"))
	await wait_seconds(1.1)
	assert_false(combat.can_fire_port, "Relaxed must reload slower, applied without a reload")
	SettingsManager.ai_difficulty = original

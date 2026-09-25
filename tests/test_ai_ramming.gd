extends GutTest

# test_ai_ramming.gd — M23 Requirement 4.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")

var _scene: Node3D = null


func before_each():
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func after_each():
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.queue_free()
	_scene = null


func _spawn_target(pos: Vector3, yaw: float) -> ShipController:
	var t := ENEMY_SHIP.instantiate() as ShipController
	var ai := t.get_node("EnemyAI")
	t.remove_child(ai)
	ai.free()
	t.remove_from_group("enemy_ship")
	t.add_to_group("friendly_ship")
	t.get_node("ShipCombat").auto_fire_enabled = false
	_scene.add_child(t)
	t.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return t


func _spawn_rammer(tendency: float) -> Array:
	var ship := ENEMY_SHIP.instantiate() as ShipController
	ship.get_node("ShipCombat").auto_fire_enabled = false
	var ai: EnemyAI = ship.get_node("EnemyAI")
	var prof: AIProfileData = load("res://resources/combat/ai_profiles/StandardEnemy.tres").duplicate()
	prof.ram_tendency = tendency
	ai.ai_profile = prof
	_scene.add_child(ship)
	return [ship, ai]


func test_profiles_author_ram_tendency():
	var galleon: AIProfileData = load("res://resources/combat/ai_profiles/AggressiveGalleon.tres")
	var vulture: AIProfileData = load("res://resources/combat/ai_profiles/IronVultureProfile.tres")
	var standard: AIProfileData = load("res://resources/combat/ai_profiles/StandardEnemy.tres")
	assert_gt(galleon.ram_tendency, 0.0)
	assert_gt(vulture.ram_tendency, 0.0)
	assert_eq(standard.ram_tendency, 0.0, "ordinary enemies don't ram on purpose")


func test_profile_tendency_reaches_the_ai():
	var built := _spawn_rammer(0.6)
	await wait_physics_frames(1)
	assert_almost_eq(built[1].ram_tendency, 0.6, 0.001)


func test_exposed_broadside_in_range_meets_ram_conditions():
	var built := _spawn_rammer(1.0)
	var ai: EnemyAI = built[1]
	# Target 30 m ahead, lying broadside-on (long axis across our line of approach).
	var target := _spawn_target(Vector3(0, 0, -30), PI * 0.5)
	await wait_physics_frames(2)
	ai.player_ship = target
	assert_true(ai.ram_conditions_met(), "a broadside-on target inside range is a ram opportunity")


func test_bow_on_target_does_not_meet_ram_conditions():
	var built := _spawn_rammer(1.0)
	var ai: EnemyAI = built[1]
	var target := _spawn_target(Vector3(0, 0, -30), 0.0)  # pointing at us: no side to hit
	await wait_physics_frames(2)
	ai.player_ship = target
	assert_false(ai.ram_conditions_met())


func test_out_of_range_target_does_not_meet_ram_conditions():
	var built := _spawn_rammer(1.0)
	var ai: EnemyAI = built[1]
	var target := _spawn_target(Vector3(0, 0, -(ai.ram_max_distance + 20.0)), PI * 0.5)
	await wait_physics_frames(2)
	ai.player_ship = target
	assert_false(ai.ram_conditions_met())


func test_ram_run_times_out():
	var built := _spawn_rammer(1.0)
	var ai: EnemyAI = built[1]
	var target := _spawn_target(Vector3(0, 0, -30), PI * 0.5)
	await wait_physics_frames(2)
	ai.player_ship = target
	ai.ram_run_timeout = 0.2
	ai._start_ram_run()
	assert_true(ai.is_ramming())
	for i in 30:
		ai._process_ram(1.0 / 60.0)
	assert_false(ai.is_ramming(), "a run that hasn't connected must be abandoned")


func test_zero_tendency_never_starts_a_run():
	var built := _spawn_rammer(0.0)
	var ai: EnemyAI = built[1]
	var target := _spawn_target(Vector3(0, 0, -30), PI * 0.5)
	await wait_physics_frames(2)
	ai.player_ship = target
	for i in 10:
		ai._ram_eval_timer = 0.0
		assert_false(ai._should_start_ram(0.016))

extends GutTest
## M30 W1 task 1.10 — Powder Kegs. Verify bullets:
##   - Drop is only available with an enemy in the stern cone (through
##     WorldManager's "keg" provider and the real ContextVerbArbiter).
##   - Detonation damage is applied (to real hulls in the radius, not outside it).
##   - Stock decrements on a drop and refills at port.
## Plus: a keg detonates on proximity (W1-2.2 "contact or proximity"), drops
## astern of the hull whatever its heading, and the Raker's existing obstacle
## probe sees kegs while other profiles' don't.

const PLAYER_SHIP := "res://scenes/world/PlayerShip.tscn"
const ENEMY_SHIP := "res://scenes/world/EnemyShip.tscn"
const KEG_SCENE := "res://scenes/combat/PowderKeg.tscn"

var _cfg: KegConfigData
var _root: Node3D
var _created_test_scene: Node3D = null
var _wm: Node
var _player: Node3D


func before_each() -> void:
	# ShipCombat spawns floating damage into current_scene; one must exist.
	if not get_tree().current_scene:
		var scene := Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_cfg = load("res://resources/combat/KegConfig.tres")
	_root = Node3D.new()
	_root.name = "KegRoot"
	add_child_autoqfree(_root)
	_player = _spawn(PLAYER_SHIP, Vector3.ZERO)
	_wm = load("res://scripts/managers/WorldManager.gd").new()
	add_child_autoqfree(_wm)
	_wm.player_ship = _player
	# The real Brace provider (task 1.6) stays registered: it outranks Keg, so
	# these tests also prove it is not offered without a wind-up on the player.


func after_each() -> void:
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func _spawn(path: String, pos: Vector3) -> Node3D:
	var ship := load(path).instantiate() as Node3D
	_root.add_child(ship)
	ship.global_position = pos
	if ship is RigidBody3D:
		ship.freeze = true   # no ocean here; pin the transforms
	var combat = ship.get_node_or_null("ShipCombat")
	if combat:
		combat.auto_fire_enabled = false
	var ai = ship.get_node_or_null("EnemyAI")
	if ai:
		ai.set_physics_process(false)
		ai.set_process(false)
	return ship


func _hull(ship: Node3D) -> float:
	return ship.get_node("ShipDamage").hull


func _astern(dist: float) -> Vector3:
	return _player.global_position + _player.global_transform.basis.z * dist


func test_keg_config_holds_the_drop_and_fuse_numbers() -> void:
	assert_gt(_cfg.stock_per_sortie, 0)
	assert_gt(_cfg.stern_cone_degrees, 0.0)
	assert_gt(_cfg.stern_cone_range, 0.0)
	assert_gt(_cfg.drop_offset, 0.0)
	assert_gt(_cfg.fuse_seconds, 0.0)
	assert_gt(_cfg.proximity_radius, 0.0)
	var keg: Node = load(KEG_SCENE).instantiate()
	assert_false("fuse_burn_time" in keg,
		"the fuse lives in KegConfigData, not as a script default")
	keg.free()


func test_keg_offered_only_with_an_enemy_in_the_stern_cone() -> void:
	var enemy := _spawn(ENEMY_SHIP, Vector3(40, 0, 0))   # abeam
	assert_ne(_wm.get_context_verb(), &"keg", "an enemy abeam is not in the stern cone")
	enemy.global_position = _astern(25.0)
	assert_eq(_wm.get_context_verb(), &"keg", "an enemy astern offers Keg")
	enemy.global_position = _astern(_cfg.stern_cone_range + 10.0)
	assert_ne(_wm.get_context_verb(), &"keg", "beyond stern_cone_range it is not offered")


## Starts a live broadside wind-up on `enemy` aimed at the player, with its
## per-frame solver/combat processing paused so nothing rescans it away.
func _wind_up_on_player(enemy: Node3D, remaining: float) -> void:
	var combat: ShipCombat = enemy.get_node("ShipCombat")
	var solver: FiringSolver = enemy.get_node("FiringSolver")
	combat.set_physics_process(false)
	solver.set_physics_process(false)
	solver._targets[FiringSolver.SIDE_PORT] = _player
	combat._windup_t[FiringSolver.SIDE_PORT] = remaining
	# Brace's gate reads WorldManager's IncomingWindupTracker, which is signal
	# driven (merged from the 1.6 lane): watch the hull and announce the wind-up.
	_wm.tick_windup_tracker(0.0)   # sets the tracker's target to the player
	_wm.get_windup_tracker().watch(enemy)
	combat.broadside_windup.emit(FiringSolver.SIDE_PORT, remaining, _player)


func test_keg_is_offered_with_the_real_brace_provider_registered() -> void:
	# W1-2.2: an enemy astern and no wind-up -> the context button says Keg.
	_spawn(ENEMY_SHIP, _astern(25.0))
	assert_eq(_wm.get_context_verb(), &"keg",
		"Brace must not shadow Keg when nothing is winding up on the player")


func test_brace_needs_a_wind_up_on_the_player_and_then_outranks_keg() -> void:
	var enemy := _spawn(ENEMY_SHIP, _astern(25.0))
	_wind_up_on_player(enemy, 1.0)
	assert_eq(_wm.get_context_verb(), &"brace", "a wind-up covering the player offers Brace")
	var solver: FiringSolver = enemy.get_node("FiringSolver")
	solver._targets[FiringSolver.SIDE_PORT] = null
	enemy.get_node("ShipCombat").broadside_windup_cancelled.emit(FiringSolver.SIDE_PORT)
	assert_eq(_wm.get_context_verb(), &"keg", "a wind-up aimed elsewhere does not")


func test_brace_pressed_late_in_the_wind_up_is_perfect() -> void:
	var brace: BraceData = load("res://resources/balance/Brace.tres")
	var enemy := _spawn(ENEMY_SHIP, _astern(25.0))
	_wind_up_on_player(enemy, brace.perfect_window * 0.5)
	var combat: ShipCombat = _player.get_node("ShipCombat")
	watch_signals(combat)
	assert_eq(_wm._context_arbiter.perform(), &"brace")
	assert_signal_emitted_with_parameters(combat, "brace_started", [true])


func test_brace_pressed_early_in_the_wind_up_is_plain() -> void:
	var brace: BraceData = load("res://resources/balance/Brace.tres")
	var enemy := _spawn(ENEMY_SHIP, _astern(25.0))
	_wind_up_on_player(enemy, brace.perfect_window + 1.0)
	var combat: ShipCombat = _player.get_node("ShipCombat")
	watch_signals(combat)
	assert_eq(_wm._context_arbiter.perform(), &"brace")
	assert_signal_emitted_with_parameters(combat, "brace_started", [false])


func test_keg_floats_on_the_swell() -> void:
	var waves := StubWaves.new()
	add_child_autoqfree(waves)
	var keg := _make_keg(Vector3(0, 0, 100))
	keg.wave_generator = waves
	keg.tick(0.1)
	assert_almost_eq(keg.global_position.y, StubWaves.HEIGHT, 0.001, "rides the wave crest")
	waves.height_now = -0.8
	keg.tick(0.1)
	assert_almost_eq(keg.global_position.y, -0.8, 0.001, "and drops into the trough")


func test_keg_finds_the_ocean_by_group() -> void:
	var waves := StubWaves.new()
	add_child_autoqfree(waves)   # WaveGenerator._ready joins "wave_generator"
	var keg := _make_keg(Vector3(0, 0, 100))
	assert_eq(keg.wave_generator, waves)


class StubWaves extends WaveGenerator:
	const HEIGHT := 1.7
	var height_now: float = HEIGHT
	func get_water_height_at(_pos: Vector3, _time: float) -> float:
		return height_now


func test_stern_cone_follows_the_hull_heading() -> void:
	_player.rotation.y = PI * 0.5   # aft (+Z local) now points along world +X
	var enemy := _spawn(ENEMY_SHIP, _astern(25.0))
	assert_eq(_wm.get_context_verb(), &"keg", "the cone is the hull's aft axis, not world +Z")
	enemy.global_position = _player.global_position + Vector3(0, 0, 25)
	assert_ne(_wm.get_context_verb(), &"keg", "world +Z is now abeam")


func test_no_keg_with_zero_stock_and_a_sunk_enemy_does_not_count() -> void:
	var enemy := _spawn(ENEMY_SHIP, _astern(25.0))
	_wm._keg_stock = 0
	assert_ne(_wm.get_context_verb(), &"keg", "0 stock -> no Keg")
	_wm._keg_stock = 2
	enemy.get_node("ShipDamage")._is_destroyed = true
	assert_ne(_wm.get_context_verb(), &"keg", "a sinking hull astern does not offer Keg")


func test_drop_decrements_stock_and_places_the_keg_astern_in_the_world() -> void:
	_player.rotation.y = 0.7
	_spawn(ENEMY_SHIP, _astern(40.0))
	var before: int = _wm.get_keg_stock()
	assert_eq(before, _cfg.stock_per_sortie, "a sortie starts with the authored stock")
	assert_eq(_wm._context_arbiter.perform(), &"keg", "the context press performs Keg")
	assert_eq(_wm.get_keg_stock(), before - 1, "a drop spends one keg")
	var kegs := get_tree().get_nodes_in_group("powder_kegs")
	assert_eq(kegs.size(), 1)
	var keg: PowderKeg = kegs[0]
	assert_eq(keg.get_parent(), _player.get_parent(), "parented to the world, not the scene root")
	var want := _astern(_cfg.drop_offset)
	assert_almost_eq(keg.global_position.x, want.x, 0.01, "dropped along the hull's aft axis")
	assert_almost_eq(keg.global_position.z, want.z, 0.01)
	assert_almost_eq(keg.global_position.y, 0.0, 0.01, "on the water")
	assert_eq(keg.dropped_by, _player)


func test_stock_refills_at_port() -> void:
	_spawn(ENEMY_SHIP, _astern(40.0))
	_wm._context_arbiter.perform()
	_wm._context_arbiter.perform()
	assert_eq(_wm.get_keg_stock(), _cfg.stock_per_sortie - 2)
	_wm._on_dock_completed("")
	assert_eq(_wm.get_keg_stock(), _cfg.stock_per_sortie, "docking refills the sortie stock")


func _make_keg(pos: Vector3) -> PowderKeg:
	var keg: PowderKeg = load(KEG_SCENE).instantiate()
	keg.dropped_by = _player
	_root.add_child(keg)
	keg.global_position = pos
	keg.set_physics_process(false)   # driven by tick() below
	return keg


func test_detonation_damages_hulls_in_the_radius_only() -> void:
	var keg := _make_keg(Vector3(0, 0, 100))
	var near := _spawn(ENEMY_SHIP, Vector3(_cfg.detonation_radius * 0.5, 0, 100))
	var far := _spawn(ENEMY_SHIP, Vector3(_cfg.detonation_radius + 15.0, 0, 100))
	var near_hp := _hull(near)
	var far_hp := _hull(far)
	var player_hp := _hull(_player)
	watch_signals(keg)
	keg.detonate()
	assert_signal_emitted(keg, "detonated")
	assert_lt(_hull(near), near_hp, "a hull inside the radius takes damage")
	assert_eq(_hull(far), far_hp, "a hull outside the radius is untouched")
	assert_eq(_hull(_player), player_hp, "the player's own keg never hurts the player")
	assert_true(keg.is_queued_for_deletion(), "the keg is spent")


func test_proximity_sets_the_keg_off_before_the_fuse() -> void:
	var keg := _make_keg(Vector3(0, 0, 100))
	var enemy := _spawn(ENEMY_SHIP, Vector3(_cfg.proximity_radius + 20.0, 0, 100))
	var hp := _hull(enemy)
	watch_signals(keg)
	keg.tick(0.1)
	assert_signal_not_emitted(keg, "detonated", "nobody close yet")
	enemy.global_position = Vector3(_cfg.proximity_radius * 0.5, 0, 100)
	keg.tick(0.1)
	assert_signal_emitted(keg, "detonated", "a hostile hull inside proximity_radius detonates it")
	assert_lt(keg.get_fuse_remaining(), _cfg.fuse_seconds)
	assert_gt(keg.get_fuse_remaining(), 0.0, "well before the fuse ran out")
	assert_lt(_hull(enemy), hp)


func test_fuse_burns_out_with_nobody_near() -> void:
	var keg := _make_keg(Vector3(0, 0, 300))
	watch_signals(keg)
	keg.tick(_cfg.fuse_seconds - 0.5)
	assert_signal_not_emitted(keg, "detonated")
	keg.tick(1.0)
	assert_signal_emitted(keg, "detonated", "the fuse detonates it on its own")


func test_a_boss_hull_is_hit_by_a_keg() -> void:
	var keg := _make_keg(Vector3(0, 0, 100))
	var boss := _spawn("res://scenes/world/BossShip.tscn", Vector3(5, 0, 100))
	var hp := _hull(boss)
	keg.detonate()
	assert_lt(_hull(boss), hp, "boss_ship hulls are not immune to kegs")


func test_raker_probe_sees_kegs_and_a_standard_profile_does_not() -> void:
	var raker := _spawn(ENEMY_SHIP, Vector3(0, 0, -200))
	var standard := _spawn(ENEMY_SHIP, Vector3(60, 0, -200))
	var raker_ai: EnemyAI = raker.get_node("EnemyAI")
	var std_ai: EnemyAI = standard.get_node("EnemyAI")
	raker_ai.apply_profile(load("res://resources/combat/ai_profiles/Raker.tres"))
	std_ai.apply_profile(load("res://resources/combat/ai_profiles/StandardEnemy.tres"))
	assert_true(raker_ai.avoid_collision_mask & 16 != 0, "terrain stays in the mask")
	_make_keg(Vector3(0, 0, -215))
	_make_keg(Vector3(60, 0, -215))
	await wait_physics_frames(2)
	var fwd := -raker.global_transform.basis.z
	var space := raker.get_world_3d().direct_space_state
	assert_gt(raker_ai._probe(space, raker.global_position, fwd), 0.0,
		"the Raker's existing probe hits the keg ahead, so it paths around it")
	assert_lt(std_ai._probe(space, standard.global_position, fwd), 0.0,
		"profiles without the keg layer ignore kegs")

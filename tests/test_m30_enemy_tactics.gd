extends GutTest

# test_m30_enemy_tactics.gd — M30 W1 task 1.1 (Requirement W1-1.1).
#
# Deterministic: both hulls are frozen and `_process_attack()` is driven by hand
# with a fixed dt, so the assertions are on the `ideal_position` the tactic
# computes (the only thing a tactic is allowed to change), not on a physics run.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
const DT := 1.0 / 60.0

## SHA-256 of each avoidance function's source (CR stripped, trailing blank
## lines trimmed), taken from main before M30 W1. Any edit to these three
## functions fails this test: the tactics must only ever change ideal_position.
const AVOIDANCE_HASHES := {
	"_get_avoidance_turn": "8fb7f2bb153fb7488a5429f817fbaad851853fe6334dca8abb9d0522b78f06a3",
	"_probe": "a76fb4948e7eea86da607b6460d66b42d99bf19d6f45c7832568baa6738f3a88",
	"_push_to_open_water": "8e03434b0445a4b08ed287b0560648616be4503cdfdf668a7be56f886cef08c4",
}

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
	t.freeze = true
	_scene.add_child(t)
	t.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return t


func _spawn_ai(prof: AIProfileData, pos: Vector3, yaw: float = 0.0) -> EnemyAI:
	var ship := ENEMY_SHIP.instantiate() as ShipController
	ship.get_node("ShipCombat").auto_fire_enabled = false
	ship.freeze = true
	var ai: EnemyAI = ship.get_node("EnemyAI")
	ai.ai_profile = prof
	_scene.add_child(ship)
	ship.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	ai.set_physics_process(false)
	return ai


func _profile(tactic: int, bearing: float, dist: float) -> AIProfileData:
	var p: AIProfileData = load("res://resources/combat/ai_profiles/StandardEnemy.tres").duplicate()
	p.tactic = tactic
	p.preferred_bearing_deg = bearing
	p.preferred_combat_distance = dist
	p.flee_health_threshold = 0.0
	p.ram_tendency = 0.0
	return p


func _engage(ai: EnemyAI, target: ShipController) -> void:
	ai.player_ship = target
	ai.current_state = EnemyAI.AIState.ATTACK


func _bearing_deg(target: Node3D, point: Vector3) -> float:
	## Signed bearing of `point` off the target's bow, + = starboard.
	var fwd: Vector3 = -target.global_transform.basis.z
	var right: Vector3 = target.global_transform.basis.x
	var rel: Vector3 = point - target.global_position
	rel.y = 0.0
	return rad_to_deg(atan2(rel.dot(right), rel.dot(fwd)))


func _tick(ai: EnemyAI, seconds: float) -> void:
	for _i in range(int(round(seconds / DT))):
		ai._process_attack(DT)


# --- STERN_RAKER -------------------------------------------------------------

func test_raker_settles_in_the_stern_quarter_within_20s():
	var target := _spawn_target(Vector3.ZERO, 0.0)
	# Abeam on the target's starboard side (bearing +90).
	var ai := _spawn_ai(_profile(AIProfileData.Tactic.STERN_RAKER, 165.0, 30.0), Vector3(30, 0, 0))
	await wait_physics_frames(2)
	_engage(ai, target)

	_tick(ai, 0.1)
	var early := absf(_bearing_deg(target, ai.last_ideal_position))
	assert_lt(early, 120.0, "the bearing is low-pass filtered, not snapped to the stern")
	assert_gt(early, 85.0, "the filter starts from where the raker actually is (abeam)")

	_tick(ai, 19.9)
	var b := absf(_bearing_deg(target, ai.last_ideal_position))
	assert_almost_eq(b, 180.0, 25.0, "Raker's ideal position sits in the stern quarter (±25°) within 20 s")
	assert_almost_eq(ai.last_ideal_position.distance_to(target.global_position), 30.0, 0.5,
		"held at the profile's preferred_combat_distance")


func test_raker_bearing_is_relative_to_the_target_heading():
	var target := _spawn_target(Vector3.ZERO, 0.0)
	var ai := _spawn_ai(_profile(AIProfileData.Tactic.STERN_RAKER, 165.0, 30.0), Vector3(30, 0, 0))
	await wait_physics_frames(2)
	_engage(ai, target)
	_tick(ai, 10.0)
	# The target comes about 90°: the ideal point swings with its stern at once,
	# because the bearing is measured off the TARGET's heading, not the line
	# between the two hulls.
	target.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	_tick(ai, DT)
	var b := absf(_bearing_deg(target, ai.last_ideal_position))
	assert_almost_eq(b, 180.0, 25.0, "still astern of the turned target")


# --- LONG_GUNNER -------------------------------------------------------------

func test_long_gunner_pushes_outward_inside_kite_distance():
	var target := _spawn_target(Vector3.ZERO, 0.0)
	var prof := _profile(AIProfileData.Tactic.LONG_GUNNER, 90.0, 50.0)
	prof.kite_min_distance = 40.0
	var ai := _spawn_ai(prof, Vector3(10, 0, 5))
	await wait_physics_frames(2)
	_engage(ai, target)
	_tick(ai, DT)

	var me: Vector3 = ai.ship_controller.global_position
	var ideal: Vector3 = ai.last_ideal_position
	var ideal_flat := Vector2(ideal.x, ideal.z).length()
	assert_gte(ideal_flat, prof.kite_min_distance, "ideal position is at least kite_min_distance out")
	var outward := Vector3(me.x, 0, me.z).normalized()
	var to_ideal := Vector3(ideal.x - me.x, 0, ideal.z - me.z)
	assert_gt(to_ideal.dot(outward), 0.0, "a Long Gunner inside its kite distance opens the range")


func test_long_gunner_outside_kite_distance_holds_its_bearing():
	var target := _spawn_target(Vector3.ZERO, 0.0)
	var prof := _profile(AIProfileData.Tactic.LONG_GUNNER, 90.0, 50.0)
	prof.kite_min_distance = 40.0
	var ai := _spawn_ai(prof, Vector3(48, 0, 0))
	await wait_physics_frames(2)
	_engage(ai, target)
	_tick(ai, 5.0)
	assert_almost_eq(ai.last_ideal_position.distance_to(target.global_position), 50.0, 0.5)
	assert_almost_eq(absf(_bearing_deg(target, ai.last_ideal_position)), 90.0, 5.0)


# --- RAM_RUNNER --------------------------------------------------------------

func test_ram_runner_telegraphs_before_the_ram():
	var prof := _profile(AIProfileData.Tactic.RAM_RUNNER, 90.0, 25.0)
	prof.ram_tendency = 1.0
	prof.ram_telegraph_seconds = 1.0
	var ai := _spawn_ai(prof, Vector3.ZERO)
	# 30 m ahead, broadside-on: a ram opportunity.
	var target := _spawn_target(Vector3(0, 0, -30), PI * 0.5)
	await wait_physics_frames(2)
	_engage(ai, target)
	# Deterministic roll: the active AIDifficultyData scales ram_tendency (Normal
	# x0.7), so lift it far enough that the clamp makes the roll certain.
	ai.ram_tendency = 100.0
	ai._ram_eval_timer = 0.0
	watch_signals(ai)

	_tick(ai, DT)
	assert_signal_emitted(ai, "ram_telegraphed", "the ram is announced first")
	assert_false(ai.is_ramming(), "...and not started on the same tick")
	_tick(ai, 0.5)
	assert_false(ai.is_ramming(), "still inside the telegraph window")
	_tick(ai, 0.6)
	assert_true(ai.is_ramming(), "the run starts once the telegraph elapses")


func test_telegraph_cancelled_when_attack_ends():
	var prof := _profile(AIProfileData.Tactic.RAM_RUNNER, 90.0, 25.0)
	prof.ram_tendency = 1.0
	prof.ram_telegraph_seconds = 1.0
	var ai := _spawn_ai(prof, Vector3.ZERO)
	var target := _spawn_target(Vector3(0, 0, -30), PI * 0.5)
	await wait_physics_frames(2)
	_engage(ai, target)
	# Deterministic roll: the active AIDifficultyData scales ram_tendency (Normal
	# x0.7), so lift it far enough that the clamp makes the roll certain.
	ai.ram_tendency = 100.0
	ai._ram_eval_timer = 0.0
	_tick(ai, DT)
	assert_true(ai.is_ram_telegraphing())
	ai._change_state(EnemyAI.AIState.FLEE)
	assert_false(ai.is_ram_telegraphing(), "leaving ATTACK drops a pending ram")


# --- STANDARD stays the old rule; ammo rules ---------------------------------

func test_standard_tactic_keeps_the_legacy_perpendicular_position():
	var target := _spawn_target(Vector3.ZERO, 0.7)
	var ai := _spawn_ai(_profile(AIProfileData.Tactic.STANDARD, 165.0, 25.0), Vector3(20, 0, 10))
	await wait_physics_frames(2)
	_engage(ai, target)
	_tick(ai, DT)
	var to_t: Vector3 = target.global_position - ai.ship_controller.global_position
	var flat := Vector3(to_t.x, 0, to_t.z).normalized()
	var perp := Vector3(-flat.z, 0.0, flat.x)
	var off: Vector3 = (perp if ai.broadside_side == "starboard" else -perp) * 25.0
	assert_almost_eq(ai.last_ideal_position.distance_to(target.global_position + off), 0.0, 0.01,
		"STANDARD ignores preferred_bearing_deg")


func test_ammo_rules_pick_by_range():
	var target := _spawn_target(Vector3.ZERO, 0.0)
	var prof := _profile(AIProfileData.Tactic.LONG_GUNNER, 90.0, 40.0)
	prof.ammo_preference = "RoundShot"
	prof.ammo_rules = {"GrapeShot": 15.0, "ChainShot": 30.0}
	var ai := _spawn_ai(prof, Vector3(10, 0, 0))
	await wait_physics_frames(2)
	_engage(ai, target)
	_tick(ai, DT)
	assert_eq(ai.ship_combat.current_ammo.resource_path.get_file(), "GrapeShot.tres")
	ai.ship_controller.global_position = Vector3(25, 0, 0)
	_tick(ai, DT)
	assert_eq(ai.ship_combat.current_ammo.resource_path.get_file(), "ChainShot.tres")
	ai.ship_controller.global_position = Vector3(45, 0, 0)
	_tick(ai, DT)
	assert_eq(ai.ship_combat.current_ammo.resource_path.get_file(), "RoundShot.tres",
		"outside every band -> ammo_preference")


# --- avoidance untouched -----------------------------------------------------

static func _function_source(src: String, fname: String) -> String:
	var lines := src.replace("\r", "").split("\n")
	var out: PackedStringArray = []
	var inside := false
	for line in lines:
		if not inside:
			if line.begins_with("func %s(" % fname):
				inside = true
				out.append(line)
			continue
		if line != "" and not line.begins_with("\t") and not line.begins_with(" "):
			break
		out.append(line)
	while out.size() > 0 and out[out.size() - 1].strip_edges() == "":
		out.remove_at(out.size() - 1)
	return "\n".join(out)


func test_avoidance_functions_are_byte_identical():
	var src := FileAccess.get_file_as_string("res://scripts/combat/EnemyAI.gd")
	for fname in AVOIDANCE_HASHES:
		var body := _function_source(src, fname)
		assert_ne(body, "", "%s still exists" % fname)
		assert_eq(body.sha256_text(), AVOIDANCE_HASHES[fname], "%s is unchanged" % fname)

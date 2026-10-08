extends GutTest

# test_m30_fireship.gd — M30 W1 task 1.2 (Requirement W1-1.1, design §5).
#
# Behaviour, not data: every test drives the real EnemyAI FIRESHIP path
# (`_process_attack` -> contact check -> `_detonate_fireship` -> AreaDamage) on
# the real EnemyShip scene. Verify: "Contact -> area damage to every hull within
# radius, and the fireship frees itself."

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")
const FIRESHIP := preload("res://resources/combat/ai_profiles/Fireship.tres")
const DT := 1.0 / 60.0

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


## A hull with no AI (nothing steers it), in `group`, optionally frozen.
func _hull(pos: Vector3, group: String, frozen: bool = true, yaw: float = 0.0) -> ShipController:
	var ship := ENEMY_SHIP.instantiate() as ShipController
	var ai := ship.get_node("EnemyAI")
	ship.remove_child(ai)
	ai.free()
	if group != "enemy_ship":
		ship.remove_from_group("enemy_ship")
		ship.add_to_group(group)
	ship.get_node("ShipCombat").auto_fire_enabled = false
	ship.freeze = frozen
	_scene.add_child(ship)
	ship.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return ship


func _fireship(pos: Vector3, yaw: float = 0.0, frozen: bool = true) -> EnemyAI:
	var ship := ENEMY_SHIP.instantiate() as ShipController
	ship.get_node("ShipCombat").auto_fire_enabled = false
	ship.freeze = frozen
	var ai: EnemyAI = ship.get_node("EnemyAI")
	ai.ai_profile = FIRESHIP
	_scene.add_child(ship)
	ship.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	# Frozen = driven by hand with _process_attack(); a live physics loop would
	# detect, chase and detonate on its own before the test engages it.
	ai.set_physics_process(not frozen)
	return ai


func _engage(ai: EnemyAI, target: ShipController) -> void:
	ai.player_ship = target
	ai.provoke()
	ai.current_state = EnemyAI.AIState.ATTACK


func _hull_hp(ship: Node) -> float:
	return (ship.get_node("ShipDamage") as ShipDamage).hull


# --- authored profile --------------------------------------------------------

func test_fireship_profile_is_a_fireship_and_never_a_support_hull():
	assert_eq(FIRESHIP.tactic, AIProfileData.Tactic.FIRESHIP)
	# A SUPPORT role pre-empts the state machine to go repair wounded allies.
	assert_ne(FIRESHIP.role, AIProfileData.Role.SUPPORT, "a fireship must never divert to repair allies")
	assert_lt(FIRESHIP.fireship_contact_distance, FIRESHIP.fireship_radius,
		"its own target is always inside the blast")


# --- contact -> area damage -> frees itself ----------------------------------

func test_contact_damages_every_hull_in_radius_and_frees_the_fireship():
	var ai := _fireship(Vector3.ZERO)
	var target := _hull(Vector3(6, 0, 0), "player_ship")                  # contact
	var near_enemy := _hull(Vector3(0, 0, 14), "enemy_ship")              # in radius (18)
	var near_ally := _hull(Vector3(-12, 0, -8), "friendly_ship")          # in radius
	var far_hull := _hull(Vector3(0, 0, 45), "enemy_ship")                # outside radius
	await wait_physics_frames(2)
	_engage(ai, target)
	var ship := ai.ship_controller
	var start := {target: _hull_hp(target), near_enemy: _hull_hp(near_enemy),
		near_ally: _hull_hp(near_ally), far_hull: _hull_hp(far_hull)}

	ai._process_attack(DT)

	assert_lt(_hull_hp(target), start[target], "the target in contact takes the blast")
	assert_lt(_hull_hp(near_enemy), start[near_enemy], "an enemy hull in radius takes it too")
	assert_lt(_hull_hp(near_ally), start[near_ally], "a friendly hull in radius takes it too")
	assert_almost_eq(start[target] - _hull_hp(target), FIRESHIP.fireship_damage, 0.01,
		"the authored fireship_damage is what lands")
	assert_eq(_hull_hp(far_hull), start[far_hull], "a hull outside fireship_radius is untouched")
	await wait_physics_frames(1)
	assert_false(is_instance_valid(ship), "the fireship frees itself on contact")


func test_no_detonation_outside_contact_distance():
	var ai := _fireship(Vector3.ZERO)
	var target := _hull(Vector3(FIRESHIP.fireship_contact_distance + 6.0, 0, 0), "player_ship")
	await wait_physics_frames(2)
	_engage(ai, target)
	var hp := _hull_hp(target)
	ai._process_attack(DT)
	await wait_physics_frames(1)
	assert_true(is_instance_valid(ai.ship_controller), "still afloat short of contact")
	assert_eq(_hull_hp(target), hp)


func test_contact_with_the_targets_escort_also_detonates():
	var ai := _fireship(Vector3.ZERO)
	var target := _hull(Vector3(0, 0, -40), "player_ship")
	var escort := _hull(Vector3(7, 0, 0), "friendly_ship")
	await wait_physics_frames(2)
	_engage(ai, target)
	var ship := ai.ship_controller
	var hp := _hull_hp(escort)
	ai._process_attack(DT)
	assert_lt(_hull_hp(escort), hp, "brushing an escort sets the fireship off")
	await wait_physics_frames(1)
	assert_false(is_instance_valid(ship))


func test_the_fireship_does_not_damage_itself_into_a_kill():
	# It is consumed, not sunk: hitting its own ShipCombat would run the died /
	# kill-credit path for a hull the player never shot.
	var ai := _fireship(Vector3.ZERO)
	var target := _hull(Vector3(6, 0, 0), "player_ship")
	await wait_physics_frames(2)
	_engage(ai, target)
	watch_signals(ai.ship_combat)
	var hp := _hull_hp(ai.ship_controller)
	ai._process_attack(DT)
	assert_eq(_hull_hp(ai.ship_controller), hp, "no self-damage")
	assert_signal_not_emitted(ai.ship_combat, "died")


# --- ideal_position = target; closes to contact ------------------------------

func test_fireship_ideal_position_is_the_target():
	var ai := _fireship(Vector3.ZERO)
	var target := _hull(Vector3(0, 0, -30), "player_ship", true, 1.1)
	await wait_physics_frames(2)
	_engage(ai, target)
	ai._process_attack(DT)
	assert_almost_eq(ai.last_ideal_position.distance_to(target.global_position), 0.0, 0.01,
		"design §5: FIRESHIP ideal_position = target")


func test_fireship_sails_from_30m_onto_its_target_and_detonates():
	# Real physics: the fireship starts 30 m off, bow-on; the target is frozen
	# broadside across its path. Hull avoidance must not steer it off.
	var ai := _fireship(Vector3.ZERO, 0.0, false)
	var target := _hull(Vector3(0, 0, -30), "player_ship", true, PI * 0.5)
	await wait_physics_frames(2)
	_engage(ai, target)
	var ship := ai.ship_controller
	var hp := _hull_hp(target)
	var closest := INF
	for _i in range(60 * 20):
		await wait_physics_frames(1)
		if not is_instance_valid(ship):
			break
		ai.current_state = EnemyAI.AIState.ATTACK
		closest = minf(closest, Vector2(ship.global_position.x - target.global_position.x,
			ship.global_position.z - target.global_position.z).length())
	assert_false(is_instance_valid(ship),
		"the fireship reached contact and blew within 20 s (closest %.1f m)" % closest)
	assert_lt(_hull_hp(target), hp, "and the target took the blast")


func test_hull_avoidance_ignores_the_fireships_own_target():
	# Bow-on, 14 m off (inside ship_avoid_distance): an ordinary hull swerves
	# away from the target; an engaged fireship must not, or it can never reach
	# contact unless the player sails into it.
	var ai := _fireship(Vector3.ZERO)
	# Hull box sits 1.25 m above the origin; drop the target so the feelers (cast
	# at the fireship's origin height) cross it, as they do for floating hulls.
	var target := _hull(Vector3(0, -1.25, -14), "player_ship", true, PI * 0.5)
	await wait_physics_frames(3)
	ai.player_ship = target
	ai.current_state = EnemyAI.AIState.PATROL
	assert_ne(ai._get_ship_avoidance_turn(), 0.0,
		"control: not engaged, the hull ahead is avoided like any other")
	_engage(ai, target)
	assert_eq(ai._get_ship_avoidance_turn(), 0.0, "engaged: its target is not an obstacle")

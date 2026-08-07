class_name EnemyAI extends Node

## Purpose: Controls enemy ship behavior through a state machine.
## Responsibilities: Patrol waypoints, detect player, chase, position for broadside, fire, flee when low.
## Dependencies: ShipController (parent), ShipCombat (sibling)
##
## States:
##   IDLE     — stationary, waiting for player to enter detection range
##   PATROL   — sailing between waypoints
##   CHASE    — pursuing the player ship
##   ATTACK   — maneuvering for broadside shots and firing
##   FLEE     — retreating when health is critically low
##
## Limitations:
##   - No formation or squad tactics (future milestone)
##   - No faction awareness (future milestone)
##
## TODO:
##   - M4: Add faction-based aggression levels
##   - M5: Add loot table integration
##   - M6: Add captain trait modifiers to AI behavior

signal state_changed(new_state: String)

enum AIState {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	FLEE,
}

## --- Exported Configuration (data-driven, no hardcoded values) ---

@export_group("Detection")
@export var detection_range: float = 80.0
@export var attack_range: float = 40.0
@export var lose_interest_range: float = 120.0

@export_group("Patrol")
@export var patrol_radius: float = 30.0
@export var waypoint_reached_dist: float = 8.0
@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 5.0

@export_group("Combat")
@export var broadside_angle_tolerance: float = 30.0  # degrees
@export var flee_health_threshold: float = 0.25  # flee below 25% HP
@export var preferred_combat_distance: float = 25.0

@export_group("Behavior")
@export var aggression: float = 0.7  # 0=passive, 1=always aggressive

var current_state: AIState = AIState.IDLE
var ship_controller: ShipController
var ship_combat: ShipCombat
var player_ship: ShipController

# Patrol
var patrol_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var home_position: Vector3 = Vector3.ZERO
var idle_timer: float = 0.0

# Attack
var broadside_side: String = "port"  # which side to present to player
var _attack_repositioning: bool = false


func _ready() -> void:
	ship_controller = get_parent() as ShipController
	if not ship_controller:
		push_error("EnemyAI: Must be a child of a ShipController!")
		return

	ship_combat = ship_controller.get_node_or_null("ShipCombat") as ShipCombat

	# Remember spawn position as home for patrol routes
	home_position = ship_controller.global_position

	# Generate initial patrol waypoints around home
	_generate_patrol_waypoints()

	# Find player after scene is ready
	call_deferred("_find_player")

	_change_state(AIState.PATROL)


func _find_player() -> void:
	## Locate the player ship in the scene tree
	var found = get_tree().get_first_node_in_group("player_ship")
	if found and found is ShipController:
		player_ship = found


func _physics_process(delta: float) -> void:
	if not ship_controller or ship_controller.is_docked:
		return

	if not player_ship:
		_find_player()
		if not player_ship:
			# No player found, just patrol
			_process_patrol(delta)
			return

	match current_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.PATROL:
			_process_patrol(delta)
		AIState.CHASE:
			_process_chase(delta)
		AIState.ATTACK:
			_process_attack(delta)
		AIState.FLEE:
			_process_flee(delta)


# === STATE PROCESSORS ===

func _process_idle(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0.0:
		_change_state(AIState.PATROL)
		return

	ship_controller.set_input(0.0, 0.0)

	# Still check for player while idle
	if _can_detect_player():
		_change_state(AIState.CHASE)


func _process_patrol(delta: float) -> void:
	# Check for player detection
	if _can_detect_player():
		_change_state(AIState.CHASE)
		return

	if patrol_waypoints.is_empty():
		_generate_patrol_waypoints()
		return

	var target = patrol_waypoints[current_waypoint_index]
	var dist = _flat_distance_to(target)

	if dist < waypoint_reached_dist:
		# Reached waypoint, move to next or idle briefly
		current_waypoint_index = (current_waypoint_index + 1) % patrol_waypoints.size()
		idle_timer = randf_range(idle_time_min, idle_time_max)
		_change_state(AIState.IDLE)
		return

	# Steer towards waypoint
	_steer_towards(target, 0.6)  # patrol at partial throttle


func _process_chase(delta: float) -> void:
	if not is_instance_valid(player_ship):
		_change_state(AIState.PATROL)
		return
		
	if not _is_hostile_to_player():
		_change_state(AIState.PATROL)
		return

	var dist = _flat_distance_to(player_ship.global_position)

	# Lost interest — too far
	if dist > lose_interest_range:
		_change_state(AIState.PATROL)
		return

	# Close enough to attack
	if dist < attack_range:
		_change_state(AIState.ATTACK)
		return

	# Chase at full speed
	_steer_towards(player_ship.global_position, 1.0)


func _process_attack(delta: float) -> void:
	if not is_instance_valid(player_ship):
		_change_state(AIState.PATROL)
		return
		
	if not _is_hostile_to_player():
		_change_state(AIState.PATROL)
		return

	# Check flee condition
	if _should_flee():
		_change_state(AIState.FLEE)
		return

	var to_player = player_ship.global_position - ship_controller.global_position
	var dist = Vector2(to_player.x, to_player.z).length()

	# If player escaped attack range, chase again
	if dist > attack_range * 1.5:
		_change_state(AIState.CHASE)
		return

	# Decide which side to present — pick the one closer to facing the player
	var ship_right = ship_controller.global_transform.basis.x.normalized()
	var to_player_flat = Vector3(to_player.x, 0, to_player.z).normalized()
	var right_dot = ship_right.dot(to_player_flat)

	# If player is more to our right, present starboard; otherwise port
	broadside_side = "starboard" if right_dot > 0 else "port"

	# We want to sail so the player is perpendicular to us (broadside).
	# Perpendicular to the player-relative axis, in the horizontal plane —
	# NOT the enemy's own basis.x. Using the enemy's own heading here
	# created a feedback loop: the heading rotates as the ship steers
	# toward the ideal position, which immediately shifts that position,
	# which changes the heading again — a wobble/circling-of-death instead
	# of a stable approach to broadside range.
	var perp = Vector3(-to_player_flat.z, 0.0, to_player_flat.x)
	var perpendicular_offset: Vector3 = (perp if broadside_side == "starboard" else -perp) * preferred_combat_distance

	var ideal_position = player_ship.global_position + perpendicular_offset

	# Steer towards the ideal broadside position
	_steer_towards(ideal_position, 0.5)

	# Check if we have a good broadside angle to fire
	var angle_to_player = _get_broadside_angle(to_player_flat)
	if angle_to_player < broadside_angle_tolerance and dist < attack_range:
		ship_controller.fire_cannons(broadside_side)


func _process_flee(delta: float) -> void:
	if not is_instance_valid(player_ship):
		_change_state(AIState.PATROL)
		return

	# Flee away from the player
	var away_dir = ship_controller.global_position - player_ship.global_position
	var flee_target = ship_controller.global_position + away_dir.normalized() * 50.0

	_steer_towards(flee_target, 1.0)

	# If we got far enough, go back to patrol
	var dist = _flat_distance_to(player_ship.global_position)
	if dist > lose_interest_range:
		_change_state(AIState.PATROL)


# === STEERING ===

func _steer_towards(target: Vector3, throttle: float) -> void:
	## Steer the ship towards a world-space target position.
	## throttle: 0.0 to 1.0 for forward speed.
	var to_target = target - ship_controller.global_position
	var to_target_flat = Vector3(to_target.x, 0, to_target.z)

	if to_target_flat.length_squared() < 1.0:
		ship_controller.set_input(0.0, 0.0)
		return

	var forward = -ship_controller.global_transform.basis.z.normalized()
	var forward_flat = Vector3(forward.x, 0, forward.z).normalized()
	var target_dir = to_target_flat.normalized()

	# Signed angle between forward and target direction (using cross product Y)
	var cross_y = forward_flat.cross(target_dir).y
	var dot = forward_flat.dot(target_dir)

	# Turn input: negative cross_y means target is to our right
	var turn: float = 0.0
	if abs(cross_y) > 0.05:
		turn = -sign(cross_y) * clamp(abs(cross_y) * 3.0, 0.3, 1.0)

	# Reduce throttle when needing to turn sharply
	var actual_throttle = throttle
	if dot < 0.3:
		actual_throttle *= 0.4  # slow down for sharp turns
	elif dot < 0.7:
		actual_throttle *= 0.7

	ship_controller.set_input(actual_throttle, turn)


# === UTILITY ===

func _is_hostile_to_player() -> bool:
	if "faction" in ship_controller and ship_controller.faction:
		var faction_id = ship_controller.faction.faction_id
		if FactionManager and not FactionManager.is_hostile(faction_id):
			return false
	return true

func _can_detect_player() -> bool:
	if not is_instance_valid(player_ship):
		return false
		
	if not _is_hostile_to_player():
		return false
		
	var dist = _flat_distance_to(player_ship.global_position)
	return dist < detection_range


func _should_flee() -> bool:
	if not ship_combat or not ship_combat.ship_stats:
		return false
	var health_pct = ship_combat.current_health / ship_combat.ship_stats.max_health
	return health_pct < flee_health_threshold


func _flat_distance_to(target: Vector3) -> float:
	## Distance ignoring Y axis (height)
	var diff = target - ship_controller.global_position
	return Vector2(diff.x, diff.z).length()


func _get_broadside_angle(to_target_dir: Vector3) -> float:
	## Returns angle (degrees) between the ship's side and the target direction.
	## 0 = perfect broadside, 90 = target is directly ahead/behind
	var ship_right = ship_controller.global_transform.basis.x.normalized()
	var right_flat = Vector3(ship_right.x, 0, ship_right.z).normalized()
	var dot = abs(right_flat.dot(to_target_dir))
	# dot of 1.0 = perfect broadside (target perpendicular), 0.0 = target ahead/behind
	return rad_to_deg(acos(clamp(dot, 0.0, 1.0)))


func _generate_patrol_waypoints() -> void:
	## Create a set of waypoints in a rough circle around the home position
	patrol_waypoints.clear()
	var num_points = randi_range(3, 5)
	var angle_step = TAU / num_points
	var start_angle = randf() * TAU

	for i in range(num_points):
		var angle = start_angle + angle_step * i
		var offset = Vector3(
			cos(angle) * patrol_radius * randf_range(0.6, 1.0),
			0,
			sin(angle) * patrol_radius * randf_range(0.6, 1.0)
		)
		patrol_waypoints.append(home_position + offset)

	current_waypoint_index = 0


func _change_state(new_state: AIState) -> void:
	if new_state == current_state:
		return

	current_state = new_state
	var state_name = AIState.keys()[new_state]
	state_changed.emit(state_name)

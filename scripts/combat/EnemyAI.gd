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
@export var lose_interest_range: float = 120.0
## `attack_range` used to be a second, independent firing range (40) that
## disagreed with the authored `ShipStats.cannon_range`. Firing range now comes
## from the hull's own stats via `FiringSolver`, so a bigger gun genuinely
## reaches further. This multiplier only decides how close the AI *chooses* to
## close before switching from CHASE to ATTACK.
@export_range(0.1, 2.0) var attack_range_fraction: float = 0.9

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
@export var ai_profile: Resource # AIProfileData

@export_group("Obstacle Avoidance")
## Enemy ships previously had no obstacle awareness at all, so any steering
## target on the far side of an island drove them straight onto the shore,
## where the hull rode up the terrain and capsized (tracked as D39/V8). These
## feelers steer around islands before contact instead.
@export var avoid_enabled: bool = true
## How far ahead the ship looks for obstructions. Wants to exceed the turning
## circle — a ship that only sees an island one hull-length out cannot turn
## away in time at full throttle.
@export var avoid_probe_distance: float = 45.0
## Angle of the left/right feelers off the bow, in degrees.
@export var avoid_feeler_angle: float = 30.0
## Physics layers the feelers test. Layer 5 (bit 16) is terrain — islands carry
## it in addition to layer 1, so masking terrain alone detects islands without
## every enemy also swerving around every other ship.
@export_flags_3d_physics var avoid_collision_mask: int = 16
## Steering authority applied when a feeler is blocked, 0..1.
@export var avoid_turn_strength: float = 1.0

var current_state: AIState = AIState.IDLE
var ship_controller: ShipController
var ship_combat: ShipCombat
var firing_solver: FiringSolver
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
	if ai_profile:
		aggression = ai_profile.get("aggression")
		preferred_combat_distance = ai_profile.get("preferred_combat_distance")
		flee_health_threshold = ai_profile.get("flee_health_threshold")
		broadside_angle_tolerance = ai_profile.get("broadside_angle_tolerance")
		
	ship_controller = get_parent() as ShipController
	if not ship_controller:
		push_error("EnemyAI: Must be a child of a ShipController!")
		return

	ship_combat = ship_controller.get_node_or_null("ShipCombat") as ShipCombat
	firing_solver = ship_controller.get_node_or_null("FiringSolver") as FiringSolver

	# Feed the profile's gun-crew discipline into the shared solver instead of
	# keeping a second copy of the arc check here.
	if firing_solver and broadside_angle_tolerance > 0.0:
		firing_solver.arc_override_degrees = broadside_angle_tolerance

	if ai_profile and ship_combat:
		var ammo_path = "res://resources/combat/ammo/" + ai_profile.get("ammo_preference") + ".tres"
		var ammo_res = load(ammo_path)
		if ammo_res:
			ship_combat.current_ammo = ammo_res

	# Remember spawn position as home for patrol routes
	home_position = ship_controller.global_position

	# Generate initial patrol waypoints around home
	_generate_patrol_waypoints()

	# Find player after scene is ready
	call_deferred("_find_player")

	_change_state(AIState.PATROL)


func _find_player() -> void:
	## Despite the name/type, this holds "my current hostile target" — the
	## player for an ordinary enemy, or the nearest hostile hull for a
	## `friendly_ship`-grouped AI support ship (Slice 7). Re-run whenever the
	## current target is freed (the `not player_ship` guard in
	## `_physics_process`, which Godot nulls automatically for a freed typed
	## reference), so a destroyed target is re-acquired without any extra
	## polling logic.
	if ship_controller and ship_controller.is_in_group("friendly_ship"):
		player_ship = _find_nearest_hostile_enemy()
		return
	var found = get_tree().get_first_node_in_group("player_ship")
	if found and found is ShipController:
		player_ship = found


func _find_nearest_hostile_enemy() -> ShipController:
	if not ship_controller:
		return null
	var best: ShipController = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("enemy_ship"):
		if not is_instance_valid(node) or node == ship_controller or not (node is ShipController):
			continue
		var dmg = node.get_node_or_null("ShipDamage")
		if dmg and dmg.has_method("is_destroyed") and dmg.is_destroyed():
			continue
		var d: float = ship_controller.global_position.distance_to(node.global_position)
		# Bounded like every other detection path here (_can_detect_player()) —
		# an ally has no reason to omnisciently lock onto a hostile clear across
		# the map the instant it spawns.
		if d > detection_range:
			continue
		if d < best_dist:
			best_dist = d
			best = node
	return best


func _physics_process(delta: float) -> void:
	if not ship_controller or ship_controller.is_docked:
		return

	# A Support-role ship's whole job is keeping a wounded ally afloat — that
	# takes priority over the normal detect/chase/attack state machine, but only
	# while someone actually needs it, so a lone Support hull still fights like
	# any other profile's numbers say it should.
	if ai_profile and int(ai_profile.get("role")) == AIProfileData.Role.SUPPORT:
		var ally := _find_wounded_ally()
		if ally:
			_process_support(delta, ally)
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
	if dist < _get_attack_range():
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

	# If player escaped weapons range, chase again
	if dist > _get_attack_range() * 1.5:
		_change_state(AIState.CHASE)
		return

	# Decide which side to present — pick the one closer to facing the player
	var to_player_flat = Vector3(to_player.x, 0, to_player.z).normalized()
	if firing_solver:
		broadside_side = firing_solver.side_for_direction(to_player_flat)
	else:
		var ship_right = ship_controller.global_transform.basis.x.normalized()
		broadside_side = "starboard" if ship_right.dot(to_player_flat) > 0 else "port"

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

	# Firing itself is no longer the AI's job. ShipCombat's auto-fire loop reads
	# the same FiringSolver and pulls the trigger the instant the arc lines up,
	# for enemies exactly as for the player — so an enemy that manoeuvres well
	# shoots well, and there is only one firing rule in the game. The AI's job
	# in ATTACK is purely to *get into* that arc, which _steer_towards() above
	# does. Kept as a fallback only for a ship with no solver attached.
	if not firing_solver:
		var right_flat := ship_controller.global_transform.basis.x.normalized()
		var angle: float = rad_to_deg(acos(clamp(abs(right_flat.dot(to_player_flat)), 0.0, 1.0)))
		if angle < broadside_angle_tolerance and dist < _get_attack_range():
			ship_controller.fire_cannons(broadside_side)


func _process_support(delta: float, ally: Node3D) -> void:
	## Close on a wounded ally and repair their hull once in range, rather than
	## engaging the player. Reuses `ShipDamage.repair()` (Slice 0) — no second
	## healing system.
	var heal_range: float = ai_profile.get("support_heal_range") if ai_profile else 15.0
	var dist := _flat_distance_to(ally.global_position)
	if dist > heal_range:
		_steer_towards(ally.global_position, 0.8)
		return

	ship_controller.set_input(0.0, 0.0)
	var dmg = ally.get_node_or_null("ShipDamage")
	if dmg and dmg.has_method("repair"):
		var rate: float = ai_profile.get("support_heal_rate") if ai_profile else 15.0
		dmg.repair("hull", rate * delta)


func _find_wounded_ally() -> Node3D:
	if not ship_controller:
		return null
	var threshold: float = ai_profile.get("support_heal_threshold") if ai_profile else 0.6

	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("enemy_ship"):
		if node == ship_controller or not is_instance_valid(node):
			continue
		var dmg = node.get_node_or_null("ShipDamage")
		if not dmg or (dmg.has_method("is_destroyed") and dmg.is_destroyed()):
			continue
		var max_hp: float = dmg.get_effective_max_health() if dmg.has_method("get_effective_max_health") else 1.0
		if max_hp <= 0.0:
			continue
		var pct: float = dmg.hull / max_hp
		if pct <= 0.0 or pct >= threshold:
			continue
		var d := _flat_distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best


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

	# Obstacle avoidance overrides the navigation turn. It is applied last and
	# unconditionally: running aground is always worse than missing a waypoint
	# or losing a firing angle, and a beached ship is unrecoverable because
	# nothing pushes a hull back off terrain once it has ridden up onto it.
	var avoid_turn := _get_avoidance_turn()
	if avoid_turn != 0.0:
		turn = avoid_turn
		actual_throttle = min(actual_throttle, 0.5)

	ship_controller.set_input(actual_throttle, turn)


func _get_avoidance_turn() -> float:
	## Three-feeler whisker probe from the bow. Returns a turn input steering
	## away from whichever side is blocked, or 0.0 when the way ahead is clear.
	##
	## The centre feeler alone is not enough — a ship approaching an island
	## head-on has an equally blocked left and right, and with no tie-break it
	## would sail straight in. When both sides are blocked the ship commits to
	## the side whose feeler hit *further* away, which is the shorter way out.
	if not avoid_enabled or not ship_controller:
		return 0.0

	var space := ship_controller.get_world_3d().direct_space_state
	if not space:
		return 0.0

	var origin := ship_controller.global_position
	var forward := -ship_controller.global_transform.basis.z.normalized()
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	if forward.length_squared() < 0.01:
		return 0.0

	var rad := deg_to_rad(avoid_feeler_angle)
	var left_dir := forward.rotated(Vector3.UP, rad)
	var right_dir := forward.rotated(Vector3.UP, -rad)

	var centre_hit := _probe(space, origin, forward)
	var left_hit := _probe(space, origin, left_dir)
	var right_hit := _probe(space, origin, right_dir)

	if centre_hit < 0.0 and left_hit < 0.0 and right_hit < 0.0:
		return 0.0

	# Normalize misses to "infinitely far" so the comparisons below read
	# naturally, then steer toward the side with more room.
	var left_room := left_hit if left_hit >= 0.0 else INF
	var right_room := right_hit if right_hit >= 0.0 else INF

	var turn_dir := 1.0 if left_room > right_room else -1.0

	# Urgency scales with how close the nearest obstruction is, so a distant
	# island produces a gentle course correction rather than a hard swerve.
	# Explicitly typed: min()/clamp() return Variant, and this project promotes
	# the "inferred from Variant" warning to an error.
	var nearest: float = min(left_room, right_room)
	if centre_hit >= 0.0:
		nearest = min(nearest, centre_hit)
	if nearest == INF:
		return 0.0

	var urgency: float = clamp(1.0 - (nearest / avoid_probe_distance), 0.25, 1.0)
	return turn_dir * urgency * avoid_turn_strength


func _probe(space: PhysicsDirectSpaceState3D, origin: Vector3, dir: Vector3) -> float:
	## Casts one feeler. Returns the distance to the obstruction, or -1.0 if
	## the ray is clear. Excludes the ship's own body so a hull that overlaps
	## its own probe origin does not report itself as an obstacle.
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * avoid_probe_distance)
	query.collision_mask = avoid_collision_mask
	if ship_controller is CollisionObject3D:
		query.exclude = [ship_controller.get_rid()]

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return -1.0
	return origin.distance_to(hit.position)


# === UTILITY ===

func _is_hostile_to_player() -> bool:
	if ship_controller and ship_controller.is_in_group("friendly_ship"):
		# _find_player() only ever assigns a hostile hull from "enemy_ship" for
		# a friendly-grouped AI, so a valid target is hostile by construction.
		return is_instance_valid(player_ship)
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


func _get_attack_range() -> float:
	## How close the AI closes before committing to ATTACK, derived from the hull's
	## real weapons range rather than a second hardcoded number.
	## `_get_broadside_angle()` used to live here too; it is now
	## `FiringSolver.get_broadside_angle()`, shared with the player's auto-fire.
	var weapons_range: float = 40.0
	if firing_solver:
		weapons_range = firing_solver.get_range()
	elif ship_combat and ship_combat.ship_stats:
		weapons_range = ship_combat.ship_stats.cannon_range
	return weapons_range * attack_range_fraction


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
		var point: Vector3 = home_position + offset
		# A waypoint generated on top of an island is unreachable: the ship
		# sails at it, avoidance turns it away, it never arrives, and it grinds
		# along the shore indefinitely. Push any such point back out to open
		# water along the home->point direction before accepting it.
		point = _push_to_open_water(point)
		patrol_waypoints.append(point)

	current_waypoint_index = 0


func _push_to_open_water(point: Vector3) -> Vector3:
	## If `point` lies inside island terrain, walk it back toward home until it
	## clears. Returns the original point when it is already in open water.
	if not ship_controller:
		return point
	var space := ship_controller.get_world_3d().direct_space_state
	if not space:
		return point

	var probe := PhysicsPointQueryParameters3D.new()
	probe.collision_mask = avoid_collision_mask
	probe.collide_with_areas = false

	var candidate := point
	for _attempt in range(6):
		probe.position = candidate
		if space.intersect_point(probe, 1).is_empty():
			return candidate
		# Step back toward home, which is by definition water the ship spawned on.
		candidate = candidate.lerp(home_position, 0.35)

	return home_position


func _change_state(new_state: AIState) -> void:
	if new_state == current_state:
		return

	current_state = new_state
	var state_name = AIState.keys()[new_state]
	state_changed.emit(state_name)

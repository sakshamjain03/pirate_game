class_name ShipMovement extends Node

# Converts the authored ShipStats.turn_rate value (already hand-tuned per
# ship, ranging ~0.5-2.5) into an absolute max yaw speed. Turning used to be
# a raw torque = turn_rate * mass, which is not a rate at all — it was never
# divided by the hull's moment of inertia, so actual turn speed silently
# rescaled with every hull-size change and came out to ~7 deg/s regardless
# of the authored value. Driving angular_velocity toward an explicit
# deg/s target instead decouples turning from mass entirely.
const TURN_RATE_TO_DEG_PER_SEC := 25.0
# How quickly angular velocity approaches its target; time constant is
# roughly 1/this, in seconds. Higher = snappier turning.
const TURN_RESPONSE_RATE := 6.0
# Rudder authority at zero forward speed, as a fraction of full authority.
# A real rudder needs flow across it to bite, but a hard 0 would let the
# ship get stuck unable to turn its way out of a dead stop.
const MIN_RUDDER_AUTHORITY := 0.35
# The authored per-ship drift_compensation_multiplier (4-10) was tuned
# against a torque-based turn model and, combined with linear_damp, killed
# lateral velocity within ~0.3s — the ship never carried any momentum
# through a turn. Scaling it down here (rather than editing 8 resources)
# keeps each ship's relative feel while giving all of them a longer,
# more boat-like drift decay.
const DRIFT_COMPENSATION_SCALE := 0.25

@export var ship_stats: ShipStats
var body: RigidBody3D

func _ready() -> void:
	body = get_parent() as RigidBody3D
	if not body:
		push_error("ShipMovement must be a child of a RigidBody3D")

func apply_movement(forward_input: float, turn_input: float, delta: float) -> void:
	if not body or not ship_stats:
		return

	var speed_mod = 1.0
	var turn_mod = 1.0
	if body and "active_captain" in body and body.active_captain:
		speed_mod = body.active_captain.speed_modifier
		turn_mod = body.active_captain.turn_rate_modifier

	var dmg = body.get_node_or_null("ShipDamage")
	if dmg and dmg.has_method("get_speed_multiplier"):
		speed_mod *= dmg.get_speed_multiplier()

	# Temporary battle upgrades and captain abilities. Applied to the speed target
	# only — the buoyancy/stability block is deliberately untouched (V1/D33/D34).
	var mods = body.get_node_or_null("CombatModifiers")
	if mods:
		speed_mod *= mods.speed_mult

	# Forward/Backward movement (Propulsion)
	var forward_dir = -body.global_transform.basis.z.normalized()
	var current_speed = body.linear_velocity.dot(forward_dir)

	if forward_input != 0:
		var target_speed = ship_stats.max_speed * speed_mod * forward_input
		var speed_diff = target_speed - current_speed

		# Use acceleration for speeding up, deceleration for slowing down/
		# reversing. `forward_input * current_speed > 0` used to gate this,
		# but that's false at exactly current_speed == 0, so every launch
		# from a dead stop used the (lower) deceleration value instead.
		var speeding_up = current_speed == 0.0 or \
			(forward_input * current_speed > 0 and abs(current_speed) < abs(target_speed))
		var accel = ship_stats.acceleration if speeding_up else ship_stats.deceleration

		# Calculate force to reach target speed, capped by max acceleration.
		# This clamp is what actually limits top speed now — the RigidBody's
		# own linear_damp is no longer applied (see ShipController), which
		# previously fought this servo and capped terminal speed at
		# acceleration/linear_damp (~4 m/s) instead of the authored max_speed.
		var max_velocity_change = accel * delta
		var actual_velocity_change = sign(speed_diff) * min(abs(speed_diff), max_velocity_change)
		var force = forward_dir * (actual_velocity_change / delta * body.mass)

		body.apply_central_force(force)
	else:
		# Water resistance
		var drag = -forward_dir * (current_speed * ship_stats.deceleration * body.mass)
		body.apply_central_force(drag)

	# Turning (Steering) — servo the yaw rate toward an explicit deg/s
	# target instead of applying raw torque (see TURN_RATE_TO_DEG_PER_SEC).
	var target_yaw_speed_dps = 0.0
	if turn_input != 0:
		var speed_frac = clamp(abs(current_speed) / max(ship_stats.max_speed, 0.01), 0.0, 1.0)
		var rudder_authority = lerp(MIN_RUDDER_AUTHORITY, 1.0, speed_frac)
		var rate = ship_stats.turn_rate * TURN_RATE_TO_DEG_PER_SEC * turn_mod * rudder_authority
		# Reduce turn rate if moving backwards (Property 9)
		if current_speed < -0.1:
			rate *= ship_stats.reverse_turn_modifier
		target_yaw_speed_dps = -turn_input * rate

	var target_yaw_speed = deg_to_rad(target_yaw_speed_dps)
	var yaw_t = 1.0 - exp(-TURN_RESPONSE_RATE * delta)
	# Servo ONLY the yaw component, preserving roll/pitch. Assigning
	# `angular_velocity.y` directly used to overwrite the world-Y component
	# outright every frame — which is precisely the component the buoyancy
	# restoring torque needs to accumulate in order to right a heeled hull.
	# Ships that steer continuously (i.e. every AI-driven enemy) therefore had
	# their self-righting cancelled on every physics tick and stayed capsized,
	# while the player ship — which is only steered on input — recovered.
	# Rebuilding the vector from its parts keeps steering authority without
	# touching the axes that stability owns.
	var ang_vel := body.angular_velocity
	var yaw_now := ang_vel.dot(Vector3.UP)
	var roll_pitch := ang_vel - Vector3.UP * yaw_now
	body.angular_velocity = roll_pitch + Vector3.UP * lerp(yaw_now, target_yaw_speed, yaw_t)

	# Drift compensation
	var right_dir = body.global_transform.basis.x.normalized()
	var drift_velocity = body.linear_velocity.dot(right_dir)
	var anti_drift_force = -right_dir * (drift_velocity * (1.0 - ship_stats.drift_factor) * body.mass * ship_stats.drift_compensation_multiplier * DRIFT_COMPENSATION_SCALE)
	body.apply_central_force(anti_drift_force)

class_name ShipCollisionHandler extends Node

## Purpose: everything that happens when a hull touches something — M23
##   (`.kiro/specs/milestone-m23-naval-dynamics/design.md` §3–§4).
## Responsibilities:
##   - Swaps the ship's sharp-cornered BoxShape3D for a pointed convex hull with
##     the same bounding box, and gives the body a low-friction PhysicsMaterial,
##     so contacts glance off instead of snagging corner-on-corner.
##   - Reads the body's contacts every physics tick, keeps ShipMovement's yaw
##     servo in its contact-grace window while touching, and frees a hull that
##     has been pinned against something under throttle (anti-stuck watchdog).
##   - Resolves rams: zone (bow / midship / stern) of each hull at the contact,
##     closing speed, mass, and the RamConfig zone matrix → hull damage via
##     ShipDamage.apply_impact(), plus an arcade knockback shove.
## Dependencies: RigidBody3D parent (ShipController), ShipMovement, ShipDamage,
##   RamConfigData, FiringSolver.are_hostile(). Auto-added by ShipController._ready().

signal rammed(other: Node, my_zone: int, their_zone: int, damage_taken: float)
signal grounded(damage_taken: float)

const RAM_CONFIG_PATH := "res://resources/combat/RamConfig.tres"
const HULL_MATERIAL_PATH := "res://resources/physics/ShipHullPhysics.tres"
const MAX_CONTACTS := 6
## Used for a hull whose CollisionShape3D isn't a box we converted (tests,
## hand-built bodies) — the shared ship footprint is 9 long.
const DEFAULT_HALF_LENGTH := 4.5

@export var config: RamConfigData

var body: RigidBody3D
var half_length: float = DEFAULT_HALF_LENGTH
## Local Z of the hull shape's centre (0 on every current ship scene).
var hull_center_z: float = 0.0

# Velocity snapshots, see get_pre_step_velocity().
var _vel_latest: Vector3 = Vector3.ZERO
var _vel_previous: Vector3 = Vector3.ZERO
var _vel_stamp: int = -1

var _pair_cooldowns: Dictionary = {}  # other instance id -> seconds remaining
var _stuck_time: float = 0.0
var _unstick_cooldown: float = 0.0
var _in_contact: bool = false

var _floating_damage_scene: PackedScene = preload("res://scenes/ui/FloatingDamage.tscn")


func _ready() -> void:
	body = get_parent() as RigidBody3D
	if not body:
		push_error("ShipCollisionHandler must be a child of a RigidBody3D")
		return
	if not config:
		config = load(RAM_CONFIG_PATH)
	body.contact_monitor = true
	body.max_contacts_reported = max(body.max_contacts_reported, MAX_CONTACTS)
	if not body.physics_material_override:
		body.physics_material_override = load(HULL_MATERIAL_PATH)
	_convert_hull_shapes()
	_vel_latest = body.linear_velocity
	_vel_previous = body.linear_velocity


# === HULL SHAPE ===

func _convert_hull_shapes() -> void:
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var half_extents: Vector3 = (child.shape as BoxShape3D).size * 0.5
			child.shape = build_hull_prism(half_extents)
			half_length = half_extents.z
			hull_center_z = child.position.z


static func build_hull_prism(e: Vector3) -> ConvexPolygonShape3D:
	## A flat-topped, vertical-walled hull outline with a pointed bow (−Z) and a
	## chamfered transom. Same AABB as the box it replaces: GodotPhysics derives
	## a convex shape's inertia from its AABB, so the body's inertia — and with
	## it all of BuoyancySimulator's hand-tuned stability — is unchanged. Vertical
	## walls mean contact normals are horizontal: two hulls can shove each other
	## sideways but never lever one another up out of the water.
	var pts := PackedVector3Array()
	for y: float in [-e.y, e.y]:
		pts.append(Vector3(0.0, y, -e.z))
		pts.append(Vector3(e.x, y, -0.45 * e.z))
		pts.append(Vector3(-e.x, y, -0.45 * e.z))
		pts.append(Vector3(e.x, y, 0.7 * e.z))
		pts.append(Vector3(-e.x, y, 0.7 * e.z))
		pts.append(Vector3(0.7 * e.x, y, e.z))
		pts.append(Vector3(-0.7 * e.x, y, e.z))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	return shape


# === ZONES & DAMAGE (pure, static — unit tested) ===

static func classify_zone(local_z: float, hull_half_length: float, cfg: RamConfigData) -> int:
	## 0 = bow tip, 1 = transom along the hull's length (forward is −Z).
	var t: float = (local_z + hull_half_length) / max(2.0 * hull_half_length, 0.01)
	if t < cfg.bow_fraction:
		return RamConfigData.Zone.BOW
	if t > 1.0 - cfg.stern_fraction:
		return RamConfigData.Zone.STERN
	return RamConfigData.Zone.MIDSHIP


static func compute_ram_damage(cfg: RamConfigData, closing_speed: float, my_mass: float,
		other_mass: float, my_zone: int, their_zone: int,
		my_stats: ShipStats, other_stats: ShipStats) -> float:
	## Hull damage *I* take. Kinetic-energy shaped (closing²); `share` splits it
	## by mass — the heavier hull takes less, exactly as the same impulse spread
	## over more timber would — and the zone matrix makes a bow driven into a
	## midship the heaviest blow for the victim and a light one for the rammer.
	if closing_speed < cfg.min_closing_speed or my_mass <= 0.0 or other_mass <= 0.0:
		return 0.0
	var mu: float = (my_mass * other_mass) / (my_mass + other_mass)
	var share: float = 2.0 * mu / my_mass
	var scale: float = pow(2.0 * mu / cfg.reference_mass, cfg.mass_scale_exponent)
	var dmg: float = cfg.damage_per_speed_sq * closing_speed * closing_speed * share * scale
	dmg *= cfg.get_zone_multiplier(my_zone, their_zone)
	if their_zone == RamConfigData.Zone.BOW and other_stats:
		dmg *= other_stats.ram_damage_mult
	if my_zone == RamConfigData.Zone.BOW and my_stats:
		dmg *= my_stats.bow_armor_multiplier
	if my_stats:
		dmg /= max(my_stats.impact_resistance, 0.1)
	return dmg


static func compute_grounding_damage(cfg: RamConfigData, closing_speed: float, my_zone: int,
		my_stats: ShipStats) -> float:
	if closing_speed < cfg.min_closing_speed:
		return 0.0
	var dmg: float = cfg.damage_per_speed_sq * closing_speed * closing_speed * cfg.grounding_damage_mult
	if my_zone == RamConfigData.Zone.BOW and my_stats:
		dmg *= my_stats.bow_armor_multiplier
	if my_stats:
		dmg /= max(my_stats.impact_resistance, 0.1)
	return dmg


func get_zone_at(world_point: Vector3) -> int:
	var local: Vector3 = body.global_transform.affine_inverse() * world_point
	return classify_zone(local.z - hull_center_z, half_length, config)


# === VELOCITY SNAPSHOTS ===

func get_pre_step_velocity() -> Vector3:
	## Contacts are reported *after* the solver has resolved them, so a hull's
	## current velocity is already post-bounce — useless for "how hard did we
	## hit". Each tick this handler snapshots linear_velocity after reading
	## contacts, i.e. before the next physics step. This returns the snapshot
	## taken before the step that produced the current contacts, regardless of
	## whether this handler or the other ship's ran first this frame.
	if _vel_stamp == Engine.get_physics_frames():
		return _vel_previous
	return _vel_latest


func _snapshot_velocity() -> void:
	_vel_previous = _vel_latest
	_vel_latest = body.linear_velocity
	_vel_stamp = Engine.get_physics_frames()


# === PER-TICK ===

func _physics_process(delta: float) -> void:
	if not body or not config:
		return

	for id in _pair_cooldowns.keys():
		_pair_cooldowns[id] -= delta
		if _pair_cooldowns[id] <= 0.0:
			_pair_cooldowns.erase(id)
	if _unstick_cooldown > 0.0:
		_unstick_cooldown -= delta

	var any_contact := false
	var normal_sum := Vector3.ZERO
	var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state and not ("is_docked" in body and body.is_docked):
		var seen := {}
		for i in state.get_contact_count():
			var other: Object = state.get_contact_collider_object(i)
			if not _is_relevant_collider(other):
				continue
			var n := _normal_into_me(state.get_contact_local_normal(i), other as Node3D)
			if n == Vector3.ZERO:
				continue
			any_contact = true
			normal_sum += n
			var id: int = other.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_evaluate_contact(other as Node3D, state.get_contact_local_position(i), n)

	_in_contact = any_contact
	if any_contact:
		_notify_grace(body, config.contact_yaw_grace)
	_update_watchdog(delta, any_contact, normal_sum)
	_snapshot_velocity()


func is_in_contact() -> bool:
	return _in_contact


func _is_relevant_collider(other: Object) -> bool:
	## Hulls and terrain only. Cannonballs are RigidBodies on a layer ships do
	## collide with (that's how they're detected), and must never count as a ram.
	if not other or not is_instance_valid(other):
		return false
	return other is ShipController or other is StaticBody3D


func _normal_into_me(raw: Vector3, other: Node3D) -> Vector3:
	## Flattened, and oriented so it points from the other body into this one —
	## the reported sign convention isn't something to depend on.
	var n := Vector3(raw.x, 0.0, raw.z)
	if n.length_squared() < 0.0001:
		return Vector3.ZERO
	n = n.normalized()
	var away := body.global_position - other.global_position
	away.y = 0.0
	if n.dot(away) < 0.0:
		n = -n
	return n


func _evaluate_contact(other: Node3D, point: Vector3, n_into_me: Vector3) -> void:
	var id := other.get_instance_id()
	if _pair_cooldowns.has(id):
		return

	var my_v := get_pre_step_velocity()

	if other is ShipController:
		var other_handler := other.get_node_or_null("ShipCollisionHandler") as ShipCollisionHandler
		# One resolver per pair: the lower instance id handles both hulls, so a
		# ram is never damaged twice from the two handlers seeing one contact.
		if other_handler and id < body.get_instance_id():
			return
		var other_v: Vector3 = other_handler.get_pre_step_velocity() if other_handler else (other as RigidBody3D).linear_velocity
		var closing: float = (my_v - other_v).dot(-n_into_me)
		if closing < config.min_closing_speed:
			return
		_pair_cooldowns[id] = config.pair_cooldown
		if other_handler:
			other_handler._pair_cooldowns[body.get_instance_id()] = config.pair_cooldown
		_resolve_ram(other as ShipController, other_handler, point, n_into_me, closing)
	else:
		var closing_t: float = my_v.dot(-n_into_me)
		if closing_t < config.min_closing_speed:
			return
		_pair_cooldowns[id] = config.pair_cooldown
		var zone := get_zone_at(point)
		var dmg := compute_grounding_damage(config, closing_t, zone, _stats_of(body))
		_notify_grace(body, config.ram_yaw_grace)
		if dmg > 0.0:
			_apply_impact(body, dmg, zone)
			grounded.emit(dmg)
			_spawn_splinters(point)
			if body.is_in_group("player_ship"):
				_announce("Ran aground! -%d hull" % int(round(dmg)))


func _resolve_ram(other: ShipController, other_handler: ShipCollisionHandler, point: Vector3,
		n_into_me: Vector3, closing: float) -> void:
	var my_zone := get_zone_at(point)
	var their_zone: int
	if other_handler:
		their_zone = other_handler.get_zone_at(point)
	else:
		var local: Vector3 = other.global_transform.affine_inverse() * point
		their_zone = classify_zone(local.z, DEFAULT_HALF_LENGTH, config)

	var hostile := FiringSolver.are_hostile(body, other)
	var my_stats := _stats_of(body)
	var other_stats := _stats_of(other)
	var dmg_me := 0.0
	var dmg_other := 0.0
	if hostile:
		dmg_me = compute_ram_damage(config, closing, body.mass, other.mass, my_zone, their_zone, my_stats, other_stats)
		dmg_other = compute_ram_damage(config, closing, other.mass, body.mass, their_zone, my_zone, other_stats, my_stats)
		if dmg_me > 0.0:
			_apply_impact(body, dmg_me, my_zone)
		if dmg_other > 0.0:
			_apply_impact(other, dmg_other, their_zone)

	# Arcade shove on whoever got struck (both, if bow met bow), applied at the
	# contact point at centre-of-mass height so it yaws the hull but never rolls it.
	var mu: float = (body.mass * other.mass) / max(body.mass + other.mass, 0.01)
	var j: float = closing * config.knockback_fraction * mu
	if my_zone != RamConfigData.Zone.BOW or their_zone == RamConfigData.Zone.BOW:
		_shove(body, n_into_me * j, point)
	if their_zone != RamConfigData.Zone.BOW or my_zone == RamConfigData.Zone.BOW:
		_shove(other, -n_into_me * j, point)
	_notify_grace(body, config.ram_yaw_grace)
	_notify_grace(other, config.ram_yaw_grace)

	rammed.emit(other, my_zone, their_zone, dmg_me)
	if other_handler:
		other_handler.rammed.emit(body, their_zone, my_zone, dmg_other)

	if hostile:
		_spawn_splinters(point)
		if AudioManager:
			AudioManager.play_sound("ram_impact")
		if body.is_in_group("player_ship"):
			_announce_ram(my_zone, their_zone, dmg_me, dmg_other)
		elif other.is_in_group("player_ship"):
			_announce_ram(their_zone, my_zone, dmg_other, dmg_me)


# === EFFECTS ===

func _shove(ship: RigidBody3D, impulse: Vector3, point: Vector3) -> void:
	if not is_instance_valid(ship) or ship.freeze:
		return
	var r := Vector3(point.x - ship.global_position.x, 0.0, point.z - ship.global_position.z)
	r += ship.global_transform.basis * ship.center_of_mass
	ship.apply_impulse(Vector3(impulse.x, 0.0, impulse.z), r)


func _apply_impact(ship: Node, amount: float, zone: int) -> void:
	var dmg = ship.get_node_or_null("ShipDamage")
	if not dmg or not dmg.has_method("apply_impact"):
		return
	var stern := zone == RamConfigData.Zone.STERN
	dmg.apply_impact(amount, config.crew_damage_fraction,
		config.stern_speed_penalty if stern else 0.0,
		config.stern_penalty_duration if stern else 0.0)
	if _floating_damage_scene and ship is Node3D and ship.is_inside_tree():
		var text = _floating_damage_scene.instantiate()
		text.damage_amount = amount
		var root := get_tree().current_scene
		if root:
			root.add_child(text)
		else:
			ship.add_child(text)
		text.global_position = (ship as Node3D).global_position + Vector3(0, 3.5, 0)


func _notify_grace(ship: Node, seconds: float) -> void:
	var mv = ship.get_node_or_null("ShipMovement")
	if mv and mv.has_method("notify_contact"):
		mv.notify_contact(seconds)


func _stats_of(ship: Node) -> ShipStats:
	return ship.ship_stats if ship and "ship_stats" in ship else null


func _spawn_splinters(point: Vector3) -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 24
	p.lifetime = 0.9
	p.explosiveness = 0.95
	p.spread = 70.0
	p.direction = Vector3(0, 1, 0)
	p.gravity = Vector3(0, -9.8, 0)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.16)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.06, 0.35)
	mesh.material = mat
	p.mesh = mesh
	scene_root.add_child(p)
	p.global_position = Vector3(point.x, max(point.y, 0.5), point.z)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func(): if is_instance_valid(p): p.queue_free())


func _announce_ram(player_zone: int, enemy_zone: int, dmg_taken: float, dmg_dealt: float) -> void:
	if player_zone == RamConfigData.Zone.BOW and enemy_zone != RamConfigData.Zone.BOW:
		_announce("Rammed their %s! -%d to them, -%d to us" % [RamConfigData.zone_name(enemy_zone).to_lower(), int(round(dmg_dealt)), int(round(dmg_taken))])
	elif enemy_zone == RamConfigData.Zone.BOW and player_zone != RamConfigData.Zone.BOW:
		_announce("We've been rammed amidships! -%d hull" % int(round(dmg_taken)))
	else:
		_announce("Collision! -%d hull" % int(round(dmg_taken)))


func _announce(text: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("announce_event"):
		hud.announce_event(text)


# === ANTI-STUCK ===

func _update_watchdog(delta: float, any_contact: bool, normal_sum: Vector3) -> void:
	var throttle: float = body.current_forward_input if "current_forward_input" in body else 0.0
	var forward := -body.global_transform.basis.z
	forward.y = 0.0
	var fwd_speed: float = body.linear_velocity.dot(forward.normalized()) if forward.length_squared() > 0.0001 else 0.0
	var pinned := any_contact and throttle > config.unstick_min_throttle and fwd_speed < config.unstick_max_speed
	_stuck_time = _stuck_time + delta if pinned else 0.0
	if _stuck_time < config.unstick_after or _unstick_cooldown > 0.0:
		return
	var away := Vector3(normal_sum.x, 0.0, normal_sum.z)
	if away.length_squared() < 0.0001:
		return
	away = away.normalized()
	body.apply_central_impulse(away * body.mass * config.unstick_speed)
	# Turn toward open water: the side of the bow the push points at. Yaw
	# component only, the same split ShipMovement's own servo uses.
	var turn_sign: float = sign(forward.cross(away).y)
	if turn_sign == 0.0:
		turn_sign = 1.0
	body.angular_velocity += Vector3.UP * turn_sign * config.unstick_yaw_rate
	_notify_grace(body, 1.0)
	_stuck_time = 0.0
	_unstick_cooldown = config.unstick_cooldown

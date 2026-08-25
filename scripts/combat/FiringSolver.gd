class_name FiringSolver extends Node

## Purpose: the single source of truth for "is there a valid target in this side's
##   firing arc, and how far off alignment am I?"
## Responsibilities: target selection, arc geometry, side selection, hostility.
## Dependencies: ShipStats (arc + range), FactionManager (via the shared hostility rule).
##
## Why this exists as its own component: the arc-alignment check that
## `docs/navalCombat.md` §4 makes the centre of the combat identity was already
## implemented — inside `EnemyAI._get_broadside_angle()`, usable only by enemies.
## Rather than write a second copy for the player's auto-fire, the geometry moved
## here and `EnemyAI` now consumes it, so player and AI can never disagree about
## what "aligned" means (AGENTS.md: never duplicate systems).

const SIDE_PORT := "port"
const SIDE_STARBOARD := "starboard"
## Chaser mounts (`docs/navalCombat.md` §3). Only ever locked when the ship's
## `ShipStats` authors `has_bow_chaser`/`has_stern_chaser` — most hulls don't.
const SIDE_BOW := "bow"
const SIDE_STERN := "stern"

@export var ship_stats: ShipStats
## Overrides ShipStats.firing_arc_degrees when > 0. `AIProfileData` sets this from
## its `broadside_angle_tolerance` so a disciplined gun crew can be a per-profile
## trait without the arc *geometry* living in two places.
@export var arc_override_degrees: float = 0.0
## How often the candidate list is re-scanned, in seconds. Targets are re-picked
## on this cadence rather than every physics tick, matching the caching pattern
## `BuoyancySimulator` already uses for wave lookups.
@export var retarget_interval: float = 0.1
## Which groups hold shootable hulls. Every other system in the project finds
## ships by group (`EnemySpawner`, `EncounterManager`, `EnemyAI._find_player`),
## so this stays consistent with them. Exported rather than hardcoded so a future
## friendly consort can be given a different candidate scope without a second
## targeting implementation.
@export var target_groups: Array[String] = ["player_ship", "enemy_ship", "boss_ship", "friendly_ship"]

var _ship: Node3D
var _targets: Dictionary = {SIDE_PORT: null, SIDE_STARBOARD: null, SIDE_BOW: null, SIDE_STERN: null}
## Pre-loaded so the very first physics frame scans instead of the ship spending
## its first `retarget_interval` blind — which for a ship that spawns already
## broadside-on would swallow the opening volley.
var _scan_accumulator: float = INF


static func are_hostile(shooter: Node, target: Node) -> bool:
	## The authoritative "may A shoot B" rule, shared with `Cannonball._is_friendly()`
	## so the solver never picks a target whose cannonball would pass straight
	## through it. Enemy ships all share collision layer 2 regardless of faction,
	## so faction identity — not the layer — is what separates friend from foe.
	if not shooter or not target or not is_instance_valid(target):
		return false
	if shooter == target:
		return false

	# `friendly_ship` (escorts, future AI consorts) is on the player's side of this
	# check without literally joining `player_ship`, which several other systems
	# assume has exactly one member.
	var shooter_is_player: bool = shooter.is_in_group("player_ship") or shooter.is_in_group("friendly_ship")
	var target_is_player: bool = target.is_in_group("player_ship") or target.is_in_group("friendly_ship")
	# The player carries no FactionData, and every enemy that engages the player
	# is hostile to them by construction.
	if shooter_is_player != target_is_player:
		return true

	var shooter_faction = shooter.get("faction") if "faction" in shooter else null
	var target_faction = target.get("faction") if "faction" in target else null
	if shooter_faction == null or target_faction == null:
		# Unknown allegiance: treat as hostile only across the player boundary,
		# which the check above already handled. Same faction by default.
		return false

	return shooter_faction.get("faction_id") != target_faction.get("faction_id")


func _ready() -> void:
	_ship = get_parent() as Node3D
	if not _ship:
		push_error("FiringSolver must be a child of a Node3D ship")


func _physics_process(delta: float) -> void:
	_scan_accumulator += delta
	if _scan_accumulator >= retarget_interval:
		_scan_accumulator = 0.0
		_rescan()


func _get_modifiers() -> CombatModifiers:
	if not _ship:
		return null
	return _ship.get_node_or_null("CombatModifiers") as CombatModifiers


func get_arc_degrees() -> float:
	var base: float = 35.0
	if arc_override_degrees > 0.0:
		base = arc_override_degrees
	elif ship_stats:
		base = ship_stats.firing_arc_degrees
	var mods := _get_modifiers()
	if mods:
		base += mods.arc_bonus_degrees
	# A cone wider than 90 degrees off the beam would cover the bow and stern too,
	# which would defeat the whole positioning mechanic.
	return clamp(base, 1.0, 89.0)


func get_range() -> float:
	if not ship_stats:
		return 0.0
	var mods := _get_modifiers()
	return ship_stats.cannon_range * (mods.range_mult if mods else 1.0)


func get_chaser_range() -> float:
	if not ship_stats:
		return 0.0
	var mods := _get_modifiers()
	return ship_stats.chaser_range * (mods.range_mult if mods else 1.0)


func get_chaser_arc_degrees() -> float:
	if not ship_stats:
		return 0.0
	return clamp(ship_stats.chaser_arc_degrees, 1.0, 45.0)


func get_broadside_angle(to_target_dir: Vector3) -> float:
	## Angle in degrees between the ship's beam and the target direction.
	## 0 = a perfect broadside, 90 = the target is dead ahead or dead astern.
	if not _ship:
		return 180.0
	var right := _ship.global_transform.basis.x.normalized()
	var right_flat := Vector3(right.x, 0.0, right.z).normalized()
	var dir_flat := Vector3(to_target_dir.x, 0.0, to_target_dir.z).normalized()
	if dir_flat.length_squared() < 0.01:
		return 180.0
	var d: float = abs(right_flat.dot(dir_flat))
	return rad_to_deg(acos(clamp(d, 0.0, 1.0)))


func side_for_direction(to_target_dir: Vector3) -> String:
	## Which broadside faces the given direction. The hull's +X is starboard,
	## matching the launch direction `ShipCombat._spawn_cannonball()` derives
	## from the hull basis.
	if not _ship:
		return SIDE_STARBOARD
	var right := _ship.global_transform.basis.x.normalized()
	var dir_flat := Vector3(to_target_dir.x, 0.0, to_target_dir.z).normalized()
	return SIDE_STARBOARD if right.dot(dir_flat) > 0.0 else SIDE_PORT


func get_target(side: String) -> Node3D:
	var t = _targets.get(side)
	return t if t and is_instance_valid(t) else null


func is_aligned(side: String) -> bool:
	return get_target(side) != null


func has_any_target() -> bool:
	return is_aligned(SIDE_PORT) or is_aligned(SIDE_STARBOARD) \
		or is_aligned(SIDE_BOW) or is_aligned(SIDE_STERN)


func force_rescan() -> void:
	## Lets a caller get a fresh solution without waiting out retarget_interval —
	## used by the player-triggered special volley so it never fires blind.
	_rescan()


func _rescan() -> void:
	_targets[SIDE_PORT] = null
	_targets[SIDE_STARBOARD] = null
	_targets[SIDE_BOW] = null
	_targets[SIDE_STERN] = null

	if not _ship or not is_instance_valid(_ship) or not ship_stats:
		return

	var broadside_range := get_range()
	var broadside_arc := get_arc_degrees()
	var has_bow: bool = ship_stats.has_bow_chaser
	var has_stern: bool = ship_stats.has_stern_chaser
	var chaser_range := get_chaser_range() if (has_bow or has_stern) else 0.0
	var chaser_arc := get_chaser_arc_degrees()

	if broadside_range <= 0.0 and chaser_range <= 0.0:
		return

	# Nearest valid target per side wins: closest is the one most likely to
	# actually be hit, given projectiles are unguided.
	var best := {SIDE_PORT: INF, SIDE_STARBOARD: INF, SIDE_BOW: INF, SIDE_STERN: INF}
	var fwd := -_ship.global_transform.basis.z.normalized()
	var fwd_flat := Vector3(fwd.x, 0.0, fwd.z).normalized()

	for candidate in _gather_candidates():
		if not is_instance_valid(candidate) or candidate == _ship:
			continue
		if not are_hostile(_ship, candidate):
			continue
		# A sinking hull is not a target — firing at a wreck wastes the volley
		# and would keep auto-fire locked on during the 2 s sink animation.
		var dmg = candidate.get_node_or_null("ShipDamage")
		if dmg and dmg.has_method("is_destroyed") and dmg.is_destroyed():
			continue

		var to_target: Vector3 = candidate.global_position - _ship.global_position
		var flat := Vector3(to_target.x, 0.0, to_target.z)
		var dist_sq := flat.length_squared()
		if dist_sq < 0.01:
			continue
		var dir := flat.normalized()

		if broadside_range > 0.0 and dist_sq <= broadside_range * broadside_range:
			if get_broadside_angle(dir) <= broadside_arc:
				var side := side_for_direction(dir)
				if dist_sq < best[side]:
					best[side] = dist_sq
					_targets[side] = candidate

		if chaser_range > 0.0 and dist_sq <= chaser_range * chaser_range:
			var fwd_dot: float = fwd_flat.dot(dir)
			if has_bow and fwd_dot > 0.0:
				var bow_angle: float = rad_to_deg(acos(clamp(fwd_dot, 0.0, 1.0)))
				if bow_angle <= chaser_arc and dist_sq < best[SIDE_BOW]:
					best[SIDE_BOW] = dist_sq
					_targets[SIDE_BOW] = candidate
			elif has_stern and fwd_dot < 0.0:
				var stern_angle: float = rad_to_deg(acos(clamp(-fwd_dot, 0.0, 1.0)))
				if stern_angle <= chaser_arc and dist_sq < best[SIDE_STERN]:
					best[SIDE_STERN] = dist_sq
					_targets[SIDE_STERN] = candidate


func _gather_candidates() -> Array:
	if not is_inside_tree():
		return []
	var out: Array = []
	var tree := get_tree()
	if not tree:
		return out
	for group in target_groups:
		for node in tree.get_nodes_in_group(group):
			if node is Node3D and not out.has(node):
				out.append(node)
	return out

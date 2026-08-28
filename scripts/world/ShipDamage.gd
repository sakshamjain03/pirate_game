class_name ShipDamage extends Node

signal pool_changed(pool: String, current: float, maximum: float)
signal destroyed()

@export var ship_stats: ShipStats

var hull: float = 0.0
var sails: float = 0.0
var crew: float = 0.0

var _is_destroyed: bool = false

# Timed mobility debuff, driven by AmmoData.speed_penalty / speed_penalty_duration
# (chain shot). Authored on ChainShot.tres since M6 but read by nothing until now:
# sail damage was the only thing that touched speed, so chain shot's "crippling"
# effect was entirely the sail pool. Folded into get_speed_multiplier() rather
# than applied in ShipMovement, because ShipMovement already queries this node
# for its speed multiplier and needs no change.
var _speed_penalty: float = 0.0
var _speed_penalty_remaining: float = 0.0

func get_effective_max_health() -> float:
	if not ship_stats:
		return 100.0
	var max_hp = ship_stats.max_health
	var parent = get_parent()
	if parent and "active_captain" in parent and parent.active_captain:
		max_hp *= parent.active_captain.health_modifier
		
	if parent and parent.is_in_group("player_ship") and TechManager:
		max_hp *= TechManager.global_health_mod
	return max_hp

func _ready() -> void:
	if ship_stats:
		if hull <= 0.0:
			hull = get_effective_max_health()
		if sails <= 0.0:
			sails = ship_stats.max_sails
		if crew <= 0.0:
			crew = ship_stats.max_crew

func _process(delta: float) -> void:
	if _speed_penalty_remaining > 0.0:
		_speed_penalty_remaining -= delta
		if _speed_penalty_remaining <= 0.0:
			_speed_penalty_remaining = 0.0
			_speed_penalty = 0.0

func get_pool_maximum(pool: String) -> float:
	## Single source of truth for each pool's ceiling. Hull uses the captain/tech
	## modified maximum, not the raw ShipStats value — clamping hull to
	## ship_stats.max_health while _ready() filled it from
	## get_effective_max_health() meant a captain's health bonus was silently
	## shaved off on the ship's first hit, and the HUD was told the wrong maximum.
	if not ship_stats:
		return 0.0
	match pool:
		"hull": return get_effective_max_health()
		"sails": return ship_stats.max_sails
		"crew": return ship_stats.max_crew
	return 0.0

func apply_hit(amount: float, ammo: AmmoData, hit_direction: Vector3) -> void:
	if _is_destroyed or not ship_stats or not ammo:
		return
		
	var total_amount = amount

	# M11 Requirement 4 — per-facing armor, extending the existing stern-crit
	# model. Priority: stern (unchanged, existing behavior) > bow > broadside
	# baseline default — a hit lands in exactly one facing.
	var facing_mult = ship_stats.broadside_armor_multiplier
	var parent = get_parent()
	if parent and parent is Node3D:
		var hit_dir_flat = Vector3(hit_direction.x, 0.0, hit_direction.z).normalized()
		if hit_dir_flat.length_squared() > 0.01:
			var stern_hit = false
			if ship_stats.stern_arc_degrees > 0.0:
				var aft = parent.global_transform.basis.z.normalized()
				var aft_flat = Vector3(aft.x, 0.0, aft.z).normalized()
				var dot = hit_dir_flat.dot(aft_flat)
				var angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))

				# If the hit came from within the stern arc
				if angle <= ship_stats.stern_arc_degrees * 0.5:
					facing_mult = ship_stats.stern_crit_multiplier
					stern_hit = true

			if not stern_hit and ship_stats.bow_arc_degrees > 0.0:
				var fwd = -parent.global_transform.basis.z.normalized()
				var fwd_flat = Vector3(fwd.x, 0.0, fwd.z).normalized()
				var bow_dot = hit_dir_flat.dot(fwd_flat)
				var bow_angle = rad_to_deg(acos(clamp(bow_dot, -1.0, 1.0)))

				if bow_angle <= ship_stats.bow_arc_degrees * 0.5:
					facing_mult = ship_stats.bow_armor_multiplier

	total_amount *= facing_mult

	var hull_dmg = total_amount * ammo.hull_damage_mult
	var sail_dmg = total_amount * ammo.sail_damage_mult
	var crew_dmg = total_amount * ammo.crew_damage_mult
	
	if hull_dmg > 0.0:
		hull = clamp(hull - hull_dmg, 0.0, get_pool_maximum("hull"))
		pool_changed.emit("hull", hull, get_pool_maximum("hull"))

	if sail_dmg > 0.0:
		sails = clamp(sails - sail_dmg, 0.0, ship_stats.max_sails)
		pool_changed.emit("sails", sails, ship_stats.max_sails)

	if crew_dmg > 0.0:
		crew = clamp(crew - crew_dmg, 0.0, ship_stats.max_crew)
		pool_changed.emit("crew", crew, ship_stats.max_crew)

	if ammo.speed_penalty > 0.0 and ammo.speed_penalty_duration > 0.0:
		apply_speed_penalty(ammo.speed_penalty, ammo.speed_penalty_duration)

	if hull <= 0.0 and not _is_destroyed:
		_is_destroyed = true
		destroyed.emit()

func is_destroyed() -> bool:
	return _is_destroyed


func mark_destroyed() -> void:
	## Destroys the ship through a path other than cannon damage — currently
	## boarding. Callers previously zeroed `hull` and emitted `destroyed`
	## themselves, which left `_is_destroyed` false and allowed the same wreck
	## to be destroyed (and looted) more than once. Idempotent by design.
	if _is_destroyed:
		return
	hull = 0.0
	_is_destroyed = true
	pool_changed.emit("hull", hull, get_effective_max_health())
	destroyed.emit()


func repair(pool: String, amount: float) -> float:
	## Restores a single pool, clamped to its maximum. Returns the amount actually
	## restored so callers can report or bill for it. This is the write path M6
	## never built: ShipCombat.current_health became a getter-only proxy onto
	## `hull`, so every existing repair/respawn/load call site was silently
	## writing to nothing (shipyard repair, respawn, save-load, ship purchase).
	if not ship_stats or amount <= 0.0:
		return 0.0
	var maximum := get_pool_maximum(pool)
	var before := 0.0
	match pool:
		"hull": before = hull
		"sails": before = sails
		"crew": before = crew
		_:
			push_error("ShipDamage.repair: unknown pool '%s'" % pool)
			return 0.0

	var after: float = clamp(before + amount, 0.0, maximum)
	if is_equal_approx(after, before):
		return 0.0

	match pool:
		"hull": hull = after
		"sails": sails = after
		"crew": crew = after

	# Repairing a wreck's hull back above zero makes it a live ship again —
	# otherwise apply_hit() keeps early-returning on _is_destroyed and the
	# ship is permanently invulnerable.
	if pool == "hull" and after > 0.0:
		_is_destroyed = false

	pool_changed.emit(pool, after, maximum)
	return after - before


func restore_all() -> void:
	## Full restore of all three pools, clearing the destroyed flag. Used by
	## respawn and by buying/switching a ship.
	if not ship_stats:
		return
	hull = get_pool_maximum("hull")
	sails = get_pool_maximum("sails")
	crew = get_pool_maximum("crew")
	_is_destroyed = false
	_speed_penalty = 0.0
	_speed_penalty_remaining = 0.0
	pool_changed.emit("hull", hull, get_pool_maximum("hull"))
	pool_changed.emit("sails", sails, get_pool_maximum("sails"))
	pool_changed.emit("crew", crew, get_pool_maximum("crew"))


func apply_speed_penalty(fraction: float, duration: float) -> void:
	## Timed mobility debuff (chain shot). A stronger penalty replaces a weaker
	## one; an equal-or-weaker one only refreshes the remaining duration, so
	## sustained chain fire keeps a target crippled without stacking to zero speed.
	var f: float = clamp(fraction, 0.0, 1.0)
	if f >= _speed_penalty:
		_speed_penalty = f
		_speed_penalty_remaining = max(_speed_penalty_remaining, duration)
	else:
		_speed_penalty_remaining = max(_speed_penalty_remaining, duration)


func get_speed_penalty() -> float:
	return _speed_penalty if _speed_penalty_remaining > 0.0 else 0.0


func get_speed_multiplier() -> float:
	if not ship_stats or ship_stats.max_sails <= 0.0:
		return 1.0
	var sail_ratio = clamp(sails / ship_stats.max_sails, 0.0, 1.0)
	var sail_mult: float = lerp(ship_stats.min_speed_fraction, 1.0, sail_ratio)
	# The timed debuff multiplies on top of sail damage but is still floored at
	# min_speed_fraction, so a crippled ship can always limp away rather than
	# being frozen in place — the same guarantee sail damage already made.
	var penalised: float = sail_mult * (1.0 - get_speed_penalty())
	return max(penalised, ship_stats.min_speed_fraction)

func get_save_data() -> Dictionary:
	return {
		"hull": hull,
		"sails": sails,
		"crew": crew
	}

func load_save_data(data: Dictionary) -> void:
	if not ship_stats:
		return
		
	if data.has("hull"):
		hull = clamp(data["hull"], 0.0, get_pool_maximum("hull"))
	else:
		hull = get_pool_maximum("hull")

	if data.has("sails"):
		sails = clamp(data["sails"], 0.0, ship_stats.max_sails)
	else:
		sails = ship_stats.max_sails
		
	if data.has("crew"):
		crew = clamp(data["crew"], 0.0, ship_stats.max_crew)
	else:
		crew = ship_stats.max_crew

	_is_destroyed = hull <= 0.0
	_speed_penalty = 0.0
	_speed_penalty_remaining = 0.0

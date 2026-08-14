class_name ShipDamage extends Node

signal pool_changed(pool: String, current: float, maximum: float)
signal destroyed()

@export var ship_stats: ShipStats

var hull: float = 0.0
var sails: float = 0.0
var crew: float = 0.0

var _is_destroyed: bool = false

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

func apply_hit(amount: float, ammo: AmmoData, hit_direction: Vector3) -> void:
	if _is_destroyed or not ship_stats or not ammo:
		return
		
	var total_amount = amount
	
	if ship_stats.stern_arc_degrees > 0.0:
		var parent = get_parent()
		if parent and parent is Node3D:
			var aft = parent.global_transform.basis.z.normalized()
			var hit_dir_flat = Vector3(hit_direction.x, 0.0, hit_direction.z).normalized()
			var aft_flat = Vector3(aft.x, 0.0, aft.z).normalized()
			
			if hit_dir_flat.length_squared() > 0.01:
				var dot = hit_dir_flat.dot(aft_flat)
				var angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))
				
				# If the hit came from within the stern arc
				if angle <= ship_stats.stern_arc_degrees * 0.5:
					total_amount *= ship_stats.stern_crit_multiplier
				
	var hull_dmg = total_amount * ammo.hull_damage_mult
	var sail_dmg = total_amount * ammo.sail_damage_mult
	var crew_dmg = total_amount * ammo.crew_damage_mult
	
	if hull_dmg > 0.0:
		hull = clamp(hull - hull_dmg, 0.0, ship_stats.max_health)
		pool_changed.emit("hull", hull, ship_stats.max_health)
	
	if sail_dmg > 0.0:
		sails = clamp(sails - sail_dmg, 0.0, ship_stats.max_sails)
		pool_changed.emit("sails", sails, ship_stats.max_sails)
		
	if crew_dmg > 0.0:
		crew = clamp(crew - crew_dmg, 0.0, ship_stats.max_crew)
		pool_changed.emit("crew", crew, ship_stats.max_crew)
		
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


func get_speed_multiplier() -> float:
	if not ship_stats or ship_stats.max_sails <= 0.0:
		return 1.0
	var sail_ratio = clamp(sails / ship_stats.max_sails, 0.0, 1.0)
	return lerp(ship_stats.min_speed_fraction, 1.0, sail_ratio)

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
		hull = clamp(data["hull"], 0.0, ship_stats.max_health)
	else:
		hull = ship_stats.max_health
		
	if data.has("sails"):
		sails = clamp(data["sails"], 0.0, ship_stats.max_sails)
	else:
		sails = ship_stats.max_sails
		
	if data.has("crew"):
		crew = clamp(data["crew"], 0.0, ship_stats.max_crew)
	else:
		crew = ship_stats.max_crew
		
	_is_destroyed = hull <= 0.0

class_name ShipComponentData extends Resource

## Purpose: one upgradable part of an owned hull — M23 Requirement 3 (hull,
## bow, stern, sails, cannons). Distinct from a ShipModuleData: a module is
## *what kind* of part is fitted (swappable, one per slot); a component level
## is *how strong* that part of this particular ship is.
## Responsibilities: pure data + `apply_to()` / `get_upgrade_cost()`. Applied
## only by `OwnedShipData.get_effective_stats()`, always to a duplicate.
## Gating (component level <= ship level) lives in OwnedShipData, not here.

@export var component_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Per-level bonus")
## Every *_bonus is multiplicative per level above 1:
## stat *= 1 + bonus * (level - 1). A level-1 component changes nothing.
@export_range(0.0, 0.5) var max_health_bonus: float = 0.0
@export_range(0.0, 0.5) var impact_resistance_bonus: float = 0.0
@export_range(0.0, 0.5) var ram_damage_bonus: float = 0.0
@export_range(0.0, 0.5) var turn_rate_bonus: float = 0.0
@export_range(0.0, 0.5) var max_speed_bonus: float = 0.0
@export_range(0.0, 0.5) var max_sails_bonus: float = 0.0
@export_range(0.0, 0.5) var acceleration_bonus: float = 0.0
@export_range(0.0, 0.5) var cannon_damage_bonus: float = 0.0
@export_range(0.0, 0.5) var fire_rate_bonus: float = 0.0
## Reduces bow_armor_multiplier (damage taken on the bow) per level:
## armor *= 1 - bonus * (level - 1), floored at ShipStats' own export minimum.
@export_range(0.0, 0.1) var bow_armor_bonus: float = 0.0
## Moves stern_crit_multiplier toward 1.0 (no crit) per level.
@export_range(0.0, 0.1) var stern_crit_reduction: float = 0.0
## Component levels at which this part adds one gun per broadside side.
@export var guns_at_levels: Array[int] = []
## Gun count used as the base when the hull's ShipStats leaves
## cannons_per_side at 0 ("one per scene marker") and this component adds guns.
@export_range(1, 16) var base_guns_per_side: int = 3

@export_group("Cost")
## Cost to reach level L on a hull of ship_class C:
## base * C * cost_growth^(L - 2).
@export_range(0, 20000) var cost_gold_base: int = 150
@export_range(0, 5000) var cost_wood_base: int = 40
@export_range(0, 2000) var cost_iron_base: int = 0
@export_range(1.0, 3.0) var cost_growth: float = 1.5


func apply_to(s: ShipStats, level: int) -> void:
	var steps := float(max(level - 1, 0))
	if steps <= 0.0:
		return
	s.max_health *= 1.0 + max_health_bonus * steps
	s.impact_resistance *= 1.0 + impact_resistance_bonus * steps
	s.ram_damage_mult *= 1.0 + ram_damage_bonus * steps
	s.turn_rate *= 1.0 + turn_rate_bonus * steps
	s.max_speed *= 1.0 + max_speed_bonus * steps
	s.max_sails *= 1.0 + max_sails_bonus * steps
	s.acceleration *= 1.0 + acceleration_bonus * steps
	s.cannon_damage *= 1.0 + cannon_damage_bonus * steps
	s.fire_rate *= 1.0 + fire_rate_bonus * steps
	if bow_armor_bonus > 0.0:
		s.bow_armor_multiplier = max(s.bow_armor_multiplier * (1.0 - bow_armor_bonus * steps), 0.4)
	if stern_crit_reduction > 0.0:
		var keep: float = max(1.0 - stern_crit_reduction * steps, 0.0)
		s.stern_crit_multiplier = 1.0 + (s.stern_crit_multiplier - 1.0) * keep
	var extra := get_extra_guns(level)
	if extra > 0:
		var base := s.cannons_per_side if s.cannons_per_side > 0 else base_guns_per_side
		s.cannons_per_side = min(base + extra, 16)


func get_extra_guns(level: int) -> int:
	var n := 0
	for l in guns_at_levels:
		if level >= l:
			n += 1
	return n


func get_upgrade_cost(to_level: int, ship_class: int) -> Dictionary:
	var mult: float = float(max(ship_class, 1)) * pow(cost_growth, float(max(to_level - 2, 0)))
	var cost := {}
	if cost_gold_base > 0:
		cost["gold"] = int(round(cost_gold_base * mult))
	if cost_wood_base > 0:
		cost["wood"] = int(round(cost_wood_base * mult))
	if cost_iron_base > 0:
		cost["iron"] = int(round(cost_iron_base * mult))
	return cost


func describe_level(level: int) -> String:
	## Short HUD/menu summary of what this part gives at `level`.
	var parts: PackedStringArray = []
	var steps := float(max(level - 1, 0))
	for pair in [["Hull", max_health_bonus], ["Impact", impact_resistance_bonus],
			["Ram", ram_damage_bonus], ["Turn", turn_rate_bonus], ["Speed", max_speed_bonus],
			["Accel", acceleration_bonus], ["Damage", cannon_damage_bonus], ["Reload", fire_rate_bonus]]:
		if pair[1] > 0.0 and steps > 0.0:
			parts.append("%s +%d%%" % [pair[0], int(round(pair[1] * steps * 100.0))])
	var guns := get_extra_guns(level)
	if guns > 0:
		parts.append("+%d gun%s/side" % [guns, "" if guns == 1 else "s"])
	return ", ".join(parts) if not parts.is_empty() else "Base"

class_name OwnedShipData extends Resource

## Purpose: per-instance progression for one owned hull — `docs/navalCombat.md`
## §13's ship level + modules. `ShipStats` resources are shared by every hull
## of a class (`FleetManager` used to hold `owned_ships` as a bare
## `Array[ShipStats]`, so two owned Sloops would have had to share one mutable
## record), so ownership wraps the shared template plus the state that is
## genuinely per-ship: level and installed modules.
## Responsibilities: pure data + `get_effective_stats()`, the only place level/
## module bonuses are ever applied — always to a duplicate, never to
## `ship_stats` itself.

const MAX_LEVEL := 5
## Multiplicative per level above 1, applied to a duplicated ShipStats exactly
## like a module would be — a level-5 hull reads as "the same kind of bonus
## stacked five times," not a second, differently-shaped system.
const LEVEL_STAT_BONUS_PER_LEVEL := 0.05

@export var ship_stats: ShipStats
@export var level: int = 1
@export var installed_modules: Array[ShipModuleData] = []


func get_module_in_slot(slot: ShipModuleData.Slot) -> ShipModuleData:
	for m in installed_modules:
		if m and m.slot == slot:
			return m
	return null


func equip_module(module: ShipModuleData) -> void:
	## One module per slot: equipping a new one replaces whatever already
	## occupied that slot rather than stacking.
	if not module:
		return
	var existing := get_module_in_slot(module.slot)
	if existing:
		installed_modules.erase(existing)
	installed_modules.append(module)


func unequip_slot(slot: ShipModuleData.Slot) -> void:
	var existing := get_module_in_slot(slot)
	if existing:
		installed_modules.erase(existing)


func get_level_up_cost() -> Dictionary:
	## Scales with the hull's own ship_class, so a Man O'War's levels cost more
	## than a Dinghy's — the same tier Wave A's purchase ladder already prices by.
	var tier: int = ship_stats.ship_class if ship_stats else 1
	var base: int = 200 * tier
	return {"gold": base * level, "wood": int(base * level / 4.0)}


func get_effective_stats() -> ShipStats:
	## Duplicate-never-mutate: `ship_stats` is the shared template for every
	## hull of this class. Level and module bonuses are applied to a private
	## copy, the same pattern `EncounterManager._apply_strength()` and
	## `CombatModifiers` already use for runtime stat changes.
	if not ship_stats:
		return null
	var s: ShipStats = ship_stats.duplicate()

	var level_mult: float = 1.0 + LEVEL_STAT_BONUS_PER_LEVEL * float(level - 1)
	s.max_health *= level_mult
	s.cannon_damage *= level_mult
	s.max_speed *= level_mult

	for m in installed_modules:
		if not m:
			continue
		s.max_health *= m.max_health_mult
		s.cannon_damage *= m.cannon_damage_mult
		s.fire_rate *= m.fire_rate_mult
		s.max_speed *= m.max_speed_mult
		s.max_sails *= m.max_sails_mult
		s.max_crew *= m.max_crew_mult
		s.cannon_range *= m.cannon_range_mult

	return s


func get_save_data() -> Dictionary:
	var module_paths: Array = []
	for m in installed_modules:
		if m:
			module_paths.append(m.resource_path)
	return {
		"ship_path": ship_stats.resource_path if ship_stats else "",
		"level": level,
		"modules": module_paths,
	}


static func from_save_data(data: Dictionary) -> OwnedShipData:
	var o := OwnedShipData.new()
	var path: String = data.get("ship_path", "")
	if ResourceLoader.exists(path):
		o.ship_stats = load(path)
	o.level = int(data.get("level", 1))
	var mods: Array[ShipModuleData] = []
	for p in data.get("modules", []):
		if ResourceLoader.exists(p):
			mods.append(load(p))
	o.installed_modules = mods
	return o

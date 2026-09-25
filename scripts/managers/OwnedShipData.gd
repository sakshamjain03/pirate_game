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

## M23 — raised from 5 so the Town-Hall-style gating below has room to breathe.
const MAX_LEVEL := 10
## Multiplicative per level above 1, applied to a duplicated ShipStats exactly
## like a module would be. M23 lowered this from 0.05: since M23 the ship
## level is primarily the *cap* on component levels (the Clash-of-Clans Town
## Hall), and the real per-part power comes from the components themselves —
## 5%/level on top of component bonuses would have made a level-10 hull ~80%
## faster than its template.
const LEVEL_STAT_BONUS_PER_LEVEL := 0.02
const PROGRESSION_CONFIG_PATH := "res://resources/ship_components/ShipProgressionConfig.tres"

static var _catalog: ShipProgressionConfig = null

@export var ship_stats: ShipStats
@export var level: int = 1
@export var installed_modules: Array[ShipModuleData] = []
## M23 — component id -> level (1..level). A missing id reads as level 1.
@export var component_levels: Dictionary = {}


# === COMPONENTS (M23 Requirement 3) ===

static func get_component_catalog() -> ShipProgressionConfig:
	if not _catalog:
		_catalog = load(PROGRESSION_CONFIG_PATH)
		if not _catalog:
			push_error("OwnedShipData: component catalog '%s' failed to load" % PROGRESSION_CONFIG_PATH)
	return _catalog


func get_component_level(component_id: String) -> int:
	return max(int(component_levels.get(component_id, 1)), 1)


func can_upgrade_component(component_id: String) -> bool:
	## Clash-of-Clans rule: no part may out-level the ship itself.
	var cat := get_component_catalog()
	if not cat or not cat.get_component(component_id):
		return false
	return get_component_level(component_id) < level


func can_level_up_ship() -> bool:
	## The ship levels up only once every part has caught up to it.
	return level < MAX_LEVEL and get_components_below_level().is_empty()


func get_components_below_level() -> Array[String]:
	var out: Array[String] = []
	var cat := get_component_catalog()
	if not cat:
		return out
	for id in cat.get_ids():
		if get_component_level(id) < level:
			out.append(id)
	return out


func get_component_upgrade_cost(component_id: String) -> Dictionary:
	var cat := get_component_catalog()
	var comp: ShipComponentData = cat.get_component(component_id) if cat else null
	if not comp:
		return {}
	var tier: int = ship_stats.ship_class if ship_stats else 1
	return comp.get_upgrade_cost(get_component_level(component_id) + 1, tier)


func set_all_components(to_level: int) -> void:
	var cat := get_component_catalog()
	if not cat:
		return
	for id in cat.get_ids():
		component_levels[id] = clampi(to_level, 1, MAX_LEVEL)


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

	var cat := get_component_catalog()
	if cat:
		for comp in cat.components:
			if comp:
				comp.apply_to(s, get_component_level(comp.component_id))

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
		"components": component_levels.duplicate(),
	}


static func from_save_data(data: Dictionary) -> OwnedShipData:
	var o := OwnedShipData.new()
	var path: String = data.get("ship_path", "")
	if ResourceLoader.exists(path):
		o.ship_stats = load(path)
	elif path != "":
		push_error("OwnedShipData: saved ship '%s' could not be resolved" % path)
	o.level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	var mods: Array[ShipModuleData] = []
	for p in data.get("modules", []):
		if ResourceLoader.exists(p):
			mods.append(load(p))
		else:
			# Was a silent skip — a module the player paid for vanishing on load
			# must be loud (CLAUDE.md: resolvers push_error, never skip silently).
			push_error("OwnedShipData: saved module '%s' could not be resolved" % p)
	o.installed_modules = mods

	# M23 — component levels. A pre-M23 save has none: every part starts at the
	# saved ship level, so a player's existing progress is never regressed and
	# the ship isn't immediately stuck behind five catch-up upgrades.
	var cat := get_component_catalog()
	var saved = data.get("components", null)
	if saved is Dictionary:
		for id in saved.keys():
			if cat and cat.get_component(str(id)):
				o.component_levels[str(id)] = clampi(int(saved[id]), 1, o.level)
			else:
				push_error("OwnedShipData: saved component '%s' is not in the catalog" % id)
	else:
		o.set_all_components(o.level)
	return o

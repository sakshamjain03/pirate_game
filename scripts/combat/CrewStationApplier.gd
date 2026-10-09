class_name CrewStationApplier extends Node

## Purpose: the Ship's Company at its sea stations (M30 2.10). Each fit squad moves a combat stat
##   by its role (gunners: reload, riggers: speed, marines: damage taken, surgeons: hull repair),
##   scaled by its rank and trait, summed across the company and held under a stacking cap.
## Responsibilities:
##   - keeps ONE persistent CombatModifiers layer ("crew_stations") up to date, rebuilt whenever the
##     company changes (`FleetManager.squads_changed`) or a boarding starts or ends;
##   - suspends the boarding roles' stations while a boarding is open (they are over the side);
##   - when a boarding resolves, hands the result to `FleetManager.apply_boarding_result` (xp,
##     wounds, an elite squad, captain xp).
## Dependencies: CombatModifiers (the persistent layer), FleetManager.squads, CrewRankTable,
##   BoardingSystem (found through its group).
## Composition: added to the player ship by `ShipController._ready()`, like MoraleComponent on enemies.

const LAYER := &"crew_stations"

var _modifiers: CombatModifiers = null
var _system: BoardingSystem = null
var _suspended: bool = false
var _in_campaign: bool = true


func _ready() -> void:
	_modifiers = get_parent().get_node_or_null("CombatModifiers") as CombatModifiers
	FleetManager.squads_changed.connect(refresh)
	_system = get_tree().get_first_node_in_group("boarding_system") as BoardingSystem
	if _system and not _system.boarding_outcome.is_connected(_on_boarding_outcome):
		_system.boarding_outcome.connect(_on_boarding_outcome)
	refresh()


func _exit_tree() -> void:
	if FleetManager and FleetManager.squads_changed.is_connected(refresh):
		FleetManager.squads_changed.disconnect(refresh)
	if _modifiers and is_instance_valid(_modifiers):
		_modifiers.clear_persistent_layer(LAYER)


func _process(_delta: float) -> void:
	# The mode can flip after the ship exists (a Maelstrom run starts after its player spawns).
	var campaign: bool = SceneManager == null or SceneManager.is_campaign()
	if campaign != _in_campaign:
		_in_campaign = campaign
		refresh()
	if _system == null or not is_instance_valid(_system):
		return
	var boarding := _system.is_boarding_active()
	if boarding != _suspended:
		_suspended = boarding
		refresh()


## Rebuilds the layer from the company as it stands. A Maelstrom run is its own closed mode (its
## own upgrades and pickups; nothing from the campaign carries in), so the company stands down there.
func refresh() -> void:
	if _modifiers == null or not is_instance_valid(_modifiers):
		return
	if SceneManager and not SceneManager.is_campaign():
		_modifiers.clear_persistent_layer(LAYER)
		return
	_modifiers.set_persistent_layer(LAYER,
			compute_effects(FleetManager.squads, CrewRankTable.get_default(), _suspended))


func _on_boarding_outcome(_outcome_id: String, details: Dictionary) -> void:
	FleetManager.apply_boarding_result(details)


## The CombatModifiers layer for `squads`: each fit squad (boarding-role squads excluded while
## `boarding`) adds its role effect x its station multiplier; each effect is then held to the
## table's stack cap. Keys are CombatModifiers layer keys: fire_rate / speed / damage_taken are
## multipliers (1.0 + total), regen is added as-is.
static func compute_effects(squads: Array, table: CrewRankTable, boarding: bool) -> Dictionary:
	var totals := {}
	for s in squads:
		var squad: OwnedSquadData = s
		if squad == null or not squad.is_fit(table):
			continue
		if boarding and squad.role in table.boarding_roles:
			continue
		var per_unit: Dictionary = table.role_effects.get(str(squad.role), {})
		for key in per_unit.keys():
			totals[key] = float(totals.get(key, 0.0)) + float(per_unit[key]) * squad.station_mult(table)
	var layer := {}
	for key in totals.keys():
		var total: float = totals[key]
		if table.stack_caps.has(key):
			var cap: float = float(table.stack_caps[key])
			total = minf(total, cap) if cap >= 0.0 else maxf(total, cap)
		layer[key] = total if key == "regen" else 1.0 + total
	return layer

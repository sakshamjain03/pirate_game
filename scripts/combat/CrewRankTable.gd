@tool
class_name CrewRankTable extends Resource

## Purpose: the Ship's Company rulebook (M30 2.10): ranks and what they earn, what each role does
##   at its sea station, the stacking cap on those bonuses, and the Tavern prices.
## Responsibilities: pure data and pure lookups (`rank_for`, `station_mult`, `trait_by_id`,
##   `traits_for_role`). The squads themselves are `OwnedSquadData`, held by `FleetManager`; the
##   bonuses are applied by `CrewStationApplier`. Every number is a placeholder (M31 tunes them).

const DEFAULT_PATH := "res://resources/crew/CrewRanks.tres"

## Rank ladder, lowest first. The arrays are parallel.
@export var rank_ids: Array[StringName] = [&"green", &"trained", &"veteran", &"elite"]
@export var rank_names: PackedStringArray = PackedStringArray(["Green", "Trained", "Veteran", "Elite"])
## XP needed for each rank (index 0 is 0).
@export var xp_thresholds: PackedInt32Array = PackedInt32Array([0, 30, 100, 250])  # placeholder: tune in M31
## Sea-station multiplier at each rank.
@export var station_mults: PackedFloat32Array = PackedFloat32Array([0.5, 1.0, 1.5, 2.0])  # placeholder: tune in M31
## Ranks at or above this index can only be reached with BOARDING xp: elite crews are made in
## the fight on an enemy deck, never bought at the Tavern or earned by sailing.
@export var boarding_only_from_rank: int = 3  # placeholder: tune in M31
## Wounds a squad can take before it is out of action (no station bonus, no boarding).
@export var wound_cap: int = 3  # placeholder: tune in M31
## Wounds that heal each time the player docks.
@export var dock_heal: int = 1  # placeholder: tune in M31

## Squad roles the company can field.
@export var roles: Array[StringName] = [&"gunners", &"riggers", &"marines", &"surgeons"]
## The roles whose squads go over the side to board; their sea station is left empty for the
## duration of a boarding (and they are the ones wounded by it).
@export var boarding_roles: Array[StringName] = [&"marines"]
## Per role: the CombatModifiers key it moves and by how much per 1.0 of station multiplier.
## "fire_rate"/"speed" are multipliers (+x), "damage_taken" a multiplier (a negative x cuts damage),
## "regen" is hull fraction per second. See CrewStationApplier.compute_effects.
@export var role_effects: Dictionary = {
	"gunners": {"fire_rate": 0.05},
	"riggers": {"speed": 0.04},
	"marines": {"damage_taken": -0.03},
	"surgeons": {"regen": 0.0015},
}  # placeholder: tune in M31
## The most any one effect can add up to across every squad, so a company of ten does not break
## the game. Same keys as the effects; the sign matches (damage_taken is negative).
@export var stack_caps: Dictionary = {
	"fire_rate": 0.20, "speed": 0.15, "damage_taken": -0.15, "regen": 0.006,
}  # placeholder: tune in M31

## The Tavern: gold per squad (Green only), and how many squads a company holds.
@export var hire_cost_gold: int = 150  # placeholder: tune in M31
@export var max_squads: int = 8  # placeholder: tune in M31
@export var squad_headcount: int = 8  # placeholder: tune in M31
## A fresh company (and an old save) is derived from the ship's crew as one squad per role here.
@export var template_roles: Array[StringName] = [&"gunners", &"riggers", &"marines", &"surgeons"]

## Names a new squad is given, in turn (then numbered).
@export var squad_names: PackedStringArray = PackedStringArray([
	"Marlow's Mates", "The Bilge Rats", "Gallows Gang", "Saltwater Sons", "Cutlass Cousins",
	"Powder Monkeys", "The Orlop Crew", "Reef Runners"])

## The traits a squad may be dealt.
@export var traits: Array[CrewTraitData] = []
## Boarding hit points a FIT boarding-role squad brings, by rank index.
@export var boarding_hp_per_rank: PackedInt32Array = PackedInt32Array([1, 2, 3, 4])  # placeholder: tune in M31
## xp a boarding earns the boarding squads: a win, a loss.
@export var boarding_xp_win: int = 40  # placeholder: tune in M31
@export var boarding_xp_loss: int = 10  # placeholder: tune in M31
## Wounds the boarding squads take when the whole party falls (scaled by casualties, rounded up).
@export var boarding_wounds_max: int = 3  # placeholder: tune in M31

static var _default: CrewRankTable


static func get_default() -> CrewRankTable:
	if _default == null:
		_default = load(DEFAULT_PATH) as CrewRankTable
		if _default == null:
			push_error("CrewRankTable: could not load %s; using built-in defaults." % DEFAULT_PATH)
			_default = CrewRankTable.new()
	return _default


## The rank index earned by `xp`, of which `boarding_xp` was won boarding. A rank at or above
## `boarding_only_from_rank` needs its xp threshold met by BOARDING xp alone.
func rank_for(xp: int, boarding_xp: int) -> int:
	var rank := 0
	for i in range(1, xp_thresholds.size()):
		var have := boarding_xp if i >= boarding_only_from_rank else xp
		if have >= xp_thresholds[i]:
			rank = i
		else:
			break
	return rank


func rank_count() -> int:
	return rank_ids.size()


func station_mult(rank: int) -> float:
	return station_mults[clampi(rank, 0, station_mults.size() - 1)]


func rank_name(rank: int) -> String:
	return rank_names[clampi(rank, 0, rank_names.size() - 1)]


func trait_by_id(id: StringName) -> CrewTraitData:
	for t in traits:
		if t != null and t.trait_id == id:
			return t
	return null


## The traits a squad of `role` can be dealt.
func traits_for_role(role: StringName) -> Array[CrewTraitData]:
	var out: Array[CrewTraitData] = []
	for t in traits:
		if t != null and (t.roles.is_empty() or role in t.roles):
			out.append(t)
	return out

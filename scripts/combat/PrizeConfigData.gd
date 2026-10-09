@tool
class_name PrizeConfigData extends Resource

## Purpose: what taking a ship as a prize costs and pays (M30 2.8).
## Responsibilities: pure data for the Prize Ledger (Keep / Ransom / Break), the transit home and
##   a prize's condition. Every number is a placeholder (M31 tunes them).

const DEFAULT_PATH := "res://resources/balance/PrizeConfig.tres"

## A kept prize is a damaged ship: this is its condition (0..1) when it reaches the fleet.
@export_range(0.0, 1.0) var keep_condition: float = 0.6  # placeholder: tune in M31
## At condition 0 a prize's effective hull is this fraction of its template's; it scales
## linearly to 1.0 at condition 1.
@export_range(0.0, 1.0) var condition_health_floor: float = 0.5  # placeholder: tune in M31
## Fraction of the player's max crew a prize crew takes off to sail the prize home.
@export_range(0.0, 1.0) var prize_crew_fraction: float = 0.1  # placeholder: tune in M31
## Chance a prize in transit is retaken on the way (checked at the next dock, seeded), plus this
## much more per 100 notoriety: a famous pirate's prizes are hunted.
@export_range(0.0, 1.0) var recapture_chance: float = 0.2  # placeholder: tune in M31
@export_range(0.0, 1.0) var recapture_per_100_notoriety: float = 0.1  # placeholder: tune in M31
## Ransom for the captured officers, per ship class of the hull: gold to the player and
## reputation with the officers' own faction.
@export var ransom_gold_per_class: int = 120  # placeholder: tune in M31
@export var ransom_reputation: int = 3  # placeholder: tune in M31
## Breaking the prize up for salvage pays this per ship class.
@export var break_wood_per_class: int = 40  # placeholder: tune in M31
@export var break_iron_per_class: int = 15  # placeholder: tune in M31

static var _default: PrizeConfigData


static func get_default() -> PrizeConfigData:
	if _default == null:
		_default = load(DEFAULT_PATH) as PrizeConfigData
		if _default == null:
			push_error("PrizeConfigData: could not load %s; using built-in defaults." % DEFAULT_PATH)
			_default = PrizeConfigData.new()
	return _default

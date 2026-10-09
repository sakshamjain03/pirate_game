@tool
class_name CrewTraitData extends Resource

## Purpose: one trait a squad of the Ship's Company can carry (M30 2.10) - a small, named edge.
## Responsibilities: pure data read by `CrewStationApplier` (sea stations) and `FleetManager`
##   (boarding hit points, wounds). Every number is a placeholder (M31 tunes them).

@export var trait_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
## Roles this trait suits; empty = any. A squad is only dealt a trait that suits its role.
@export var roles: Array[StringName] = []
## Added to the squad's sea-station multiplier (rank multiplier + this).
@export var station_mult_bonus: float = 0.0  # placeholder: tune in M31
## Extra boarding hit points the squad brings to a Three Bells battle.
@export var boarding_hp_bonus: int = 0  # placeholder: tune in M31
## Extra wounds the squad can take before it is out of action.
@export var wound_cap_bonus: int = 0  # placeholder: tune in M31

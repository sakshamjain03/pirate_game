@tool
class_name BoardingObjectiveData extends Resource

## Purpose: a zone the boarding party can seize to end the battle with a specific outcome
##   (M30 2.2): the Quarterdeck takes the Colours, the Hold takes the cargo, the Forecastle
##   takes the powder magazine.
## Responsibilities: pure data. A zone is seized when the party stands in it and no
##   defender is left in it.

@export var id: StringName = &""
@export var display_name: String = ""
## Which zone this objective sits in.
@export var zone: BoardingZone.Id = BoardingZone.Id.QUARTERDECK
## The outcome id `BoardingSystem.resolve_tactical()` is told ("colours", "hold", "magazine").
@export var outcome_id: StringName = &"colours"
## Multiplies the boarding loot roll for this outcome.
@export var loot_mult: float = 1.0  # placeholder: tune in M31
## False for the outcomes that leave a wreck instead of a taken ship (the magazine).
@export var captures_ship: bool = true
## M30 2.10 - the Brig: seizing it frees prisoners who join as an ELITE squad (the only way one
## is ever made). The Cabin: the officers' papers pay the captain this much xp.
@export var grants_elite_squad: bool = false
@export var captain_xp: int = 0  # placeholder: tune in M31

@tool
class_name BoardingData extends Resource

@export var hull_threshold: float = 0.3
@export var range: float = 12.0
@export var loot_multiplier: float = 2.0
@export var win_crew_loss_fraction: float = 0.1
@export var lose_crew_loss_fraction: float = 0.5
@export var attacker_advantage: float = 1.2

# M30 W2 (2.1) — # placeholder: tune in M31
## begin_boarding() auto-resolves (no battle) once the player's boarding strength
## is at least this many times the defenders' crew: a hopeless fight is not played.
@export var overwhelm_ratio: float = 3.0
## Losing a tactical boarding costs this fraction of max crew when the player cuts loose.
@export var cut_loose_crew_loss_fraction: float = 0.2

# --- Three Bells rules (M30 2.2) --- # placeholder: tune in M31
## Command points the player gets each bell.
@export var bell_cp: int = 3
## Bells in a battle = bells_base + round(enemy hull fraction * bells_per_hull), at most bells_max.
@export var bells_base: int = 2
@export var bells_per_hull: float = 5.0
@export var bells_max: int = 4
## The bell rings by itself this many seconds after the last (the overlay enforces it).
@export var bell_seconds: float = 6.0
## Enemy morale at or below this strikes the colours.
@export var strike_morale: int = 30
## Extra morale lost when the officer falls (the leader sinking).
@export var officer_down_morale: int = 12
## CP an Advance into the next zone costs.
@export var advance_cp: int = 1
## Damage a Guarding defender soaks from each player hit (a hit always does at least 1).
@export var guard_reduction: int = 2
## Defenders one zone can hold; a Shove into a full zone fails.
@export var zone_slots: int = 4

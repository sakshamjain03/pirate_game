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
## What the Hold pays after the enemy jettisoned its cargo (bell 2).
@export var jettison_hold_mult: float = 0.5

# --- Deck building and content (M30 2.3) ---
## The player's side of the battle: boarders = round(crew * boarder_fraction), clamped.
@export var boarder_fraction: float = 0.25  # placeholder: tune in M31
@export var boarder_min: int = 6  # placeholder: tune in M31
@export var boarder_max: int = 24  # placeholder: tune in M31
## Hostile hulls this close to the target keep firing from outside the grapple, at most
## `max_outside_threats` of them.
@export var outside_range: float = 40.0  # placeholder: tune in M31
@export var max_outside_threats: int = 2  # placeholder: tune in M31
## How many of the target's most recent player hits feed the deck (the hit_tags log).
@export var hit_log_size: int = 12  # placeholder: tune in M31
## Faction x class profiles, and the fallback when none matches.
@export var deck_profiles: Array[BoardingDeckProfile] = []
@export var default_profile: BoardingDeckProfile
## The verbs the overlay offers (Cutlass, Pistol, Shove, Parry, Brace, Point-Blank).
@export var actions: Array[BoardingActionData] = []

## Share of the player's max crew lost if the whole boarding party falls (scaled by casualties).
@export var casualty_crew_fraction: float = 0.4  # placeholder: tune in M31

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

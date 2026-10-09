@tool
class_name MoraleData extends Resource

## Purpose: how an enemy crew's nerve drains and breaks (M30 2.6).
## Responsibilities: pure data read by `MoraleComponent`. Every number is a placeholder
##   (M31 tunes them) — they describe a feel, not a balance sheet.

const DEFAULT_PATH := "res://resources/combat/Morale.tres"

## Morale an enemy hull starts with.
@export var start: float = 100.0  # placeholder: tune in M31
## Morale lost for the WHOLE crew going down (scaled by the fraction actually lost, so a grape
## volley that kills a third of the crew costs a third of this).
@export var crew_loss_drain: float = 70.0  # placeholder: tune in M31
## Morale lost per bow or stern rake the player lands.
@export var rake_drain: float = 6.0  # placeholder: tune in M31
## Morale lost when the squad leader sinks.
@export var leader_sunk_drain: float = 30.0  # placeholder: tune in M31
## At or below this the crew starts to waver (a telegraph the player can read).
@export var wavering_threshold: float = 45.0  # placeholder: tune in M31
## At or below this when the wavering ends, the crew strikes its colours rather than runs.
@export var strike_threshold: float = 20.0  # placeholder: tune in M31
## How long a crew wavers before it flees or strikes.
@export var waver_seconds: float = 3.0  # placeholder: tune in M31
## A wavering crew flees only if the rigging still has this fraction left; a ship with its
## sails shot away cannot run, so it strikes instead (chain shot buys a prize).
@export_range(0.0, 1.0) var flee_min_sails: float = 0.5  # placeholder: tune in M31

static var _default: MoraleData


static func get_default() -> MoraleData:
	if _default == null:
		_default = load(DEFAULT_PATH) as MoraleData
		if _default == null:
			push_error("MoraleData: could not load %s; using built-in defaults." % DEFAULT_PATH)
			_default = MoraleData.new()
	return _default

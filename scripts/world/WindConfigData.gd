class_name WindConfigData extends Resource

## Purpose: points-of-sail speed balance (M30 0.19). Read by
## ShipMovement's wind term, which used to hardcode 0.85 and 1.15.
## Wave 6 (6.4) grows this into full points of sail; Wave 0 only moves the two
## numbers into data with defaults that reproduce the old behaviour exactly.

const DEFAULT_PATH := "res://resources/balance/WindConfig.tres"

## Speed multiplier sailing dead into the wind (at full region wind_strength).
@export_range(0.1, 1.0) var headwind_speed_mult: float = 0.85  # placeholder: tune in M31
## Speed multiplier running dead downwind (at full region wind_strength).
@export_range(1.0, 2.0) var tailwind_speed_mult: float = 1.15  # placeholder: tune in M31

static var _default: WindConfigData


## The shared config, loaded once. A missing file push_errors and falls back
## to the built-in defaults so ships still sail.
static func get_default() -> WindConfigData:
	if _default == null:
		_default = load(DEFAULT_PATH) as WindConfigData
		if _default == null:
			push_error("WindConfigData: could not load %s; using built-in defaults." % DEFAULT_PATH)
			_default = WindConfigData.new()
	return _default

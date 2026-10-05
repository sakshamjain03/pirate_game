class_name NotorietyGainsData extends Resource

## Purpose: how much notoriety (heat) each campaign act earns (M30 0.19).
## Island.capture_island() and ShipController._on_died() hardcoded 15 / 5 / 1.
## Encounters already author their own EncounterData.notoriety_reward; Wave 3's
## IslandDefenseData may override capture per island.

const DEFAULT_PATH := "res://resources/balance/NotorietyGains.tres"

@export var island_capture: float = 15.0  # placeholder: tune in M31
## Sinking a hull of an empire faction (Royal Navy, Spain).
@export var sink_empire_ship: float = 5.0  # placeholder: tune in M31
## Sinking any other faction's hull.
@export var sink_other_ship: float = 1.0  # placeholder: tune in M31

static var _default: NotorietyGainsData


static func get_default() -> NotorietyGainsData:
	if _default == null:
		_default = load(DEFAULT_PATH) as NotorietyGainsData
		if _default == null:
			push_error("NotorietyGainsData: could not load %s; using built-in defaults." % DEFAULT_PATH)
			_default = NotorietyGainsData.new()
	return _default

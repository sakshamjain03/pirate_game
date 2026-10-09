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

## M30 W2 (2.6) — the Dread/Renown axis (EmpireManager.shift_axis; positive = Dread). Sinking a
## ship that had already struck its colours is Dread; taking one as a prize is Renown. These are
## amounts of the axis, not of notoriety.
@export var dread_sink_struck: float = 4.0  # placeholder: tune in M31
@export var renown_take_prize: float = 3.0  # placeholder: tune in M31
## Breaking a taken ship up for salvage rather than keeping or ransoming it is Dread.
@export var dread_break_prize: float = 2.0  # placeholder: tune in M31
## Winning a boarding under a No Quarter order is Dread.
@export var dread_no_quarter: float = 3.0  # placeholder: tune in M31

static var _default: NotorietyGainsData


static func get_default() -> NotorietyGainsData:
	if _default == null:
		_default = load(DEFAULT_PATH) as NotorietyGainsData
		if _default == null:
			push_error("NotorietyGainsData: could not load %s; using built-in defaults." % DEFAULT_PATH)
			_default = NotorietyGainsData.new()
	return _default

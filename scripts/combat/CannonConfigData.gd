class_name CannonConfigData extends Resource

## Purpose: how a broadside actually behaves once the trigger is pulled —
## M23 Requirement 5. Read by `ShipCombat` (ripple, misfire, aim spread) and
## `Cannonball` (glancing hits). Reload and per-ball damage stay on ShipStats.

@export_group("Ripple")
## Seconds between successive guns of one broadside. Gun 0 always fires
## immediately; a real broadside rolls down the side rather than going off
## as one instantaneous shotgun blast.
@export_range(0.0, 1.0) var ripple_interval: float = 0.12

@export_group("Misfire")
## Chance each gun after the first fails to fire (damp powder, bad fuse).
## The first gun never misfires, so every volley gets at least one ball off.
@export_range(0.0, 0.5) var base_misfire_chance: float = 0.06
## Extra misfire chance at zero crew, scaled linearly by missing crew.
@export_range(0.0, 0.8) var crew_misfire_chance: float = 0.25

@export_group("Aim spread")
## Standard deviation (degrees) of horizontal aim error for a target dead on
## the beam at point-blank range.
@export_range(0.0, 10.0) var base_spread_degrees: float = 0.8
## Added at the edge of the firing arc — a gun layed at an awkward angle is
## far less accurate than one pointed straight out of its port.
@export_range(0.0, 20.0) var off_beam_spread_degrees: float = 3.5
## Added at maximum range.
@export_range(0.0, 20.0) var range_spread_degrees: float = 2.0
## Vertical error as a fraction of the horizontal error.
@export_range(0.0, 1.0) var vertical_spread_ratio: float = 0.35

@export_group("Impact angle")
## Damage multiplier for a ball that glances along the side (incidence 0);
## a ball striking the side square-on (incidence 1) deals full damage.
## Bow/stern (raking) hits are never reduced.
@export_range(0.0, 1.0) var glancing_damage_min: float = 0.45


func get_misfire_chance(crew_fraction: float) -> float:
	return clamp(base_misfire_chance + crew_misfire_chance * (1.0 - clamp(crew_fraction, 0.0, 1.0)), 0.0, 0.95)


func get_spread_degrees(off_beam_fraction: float, range_fraction: float) -> float:
	return base_spread_degrees \
		+ off_beam_spread_degrees * clamp(off_beam_fraction, 0.0, 1.0) \
		+ range_spread_degrees * clamp(range_fraction, 0.0, 1.0)


func get_impact_angle_multiplier(incidence: float) -> float:
	return lerp(glancing_damage_min, 1.0, clamp(incidence, 0.0, 1.0))

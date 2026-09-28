class_name EconomyPricingData extends Resource

## Purpose: every tunable number of the M27 timer + Eights economy, in one authored
##   file (resources/balance/EconomyPricing.tres). No price or speed lives in a script.
## Responsibilities: pure data plus three lookups — effective_duration(),
##   finish_cost(), speed_multipliers_for().
##
## AGENTS.md: "Every timer must also be reducible by playing, and skip cost is priced
## off remaining time, never total time." The speed arrays are the first half of that
## rule (tests/test_economy_pricing.gd pins them strictly decreasing); finish_cost()
## taking only a remaining time is the second.

## One Piece of Eight finishes this many seconds of a running job.
@export var seconds_per_eight: float = 60.0
## Units of a resource one Eight covers when topping up a shortfall. Eights itself
## is deliberately absent: it is never a shortfall resource.
@export var shortfall_rates: Dictionary = {"gold": 50, "wood": 10, "iron": 5, "rum": 5, "research": 5}

@export_group("Speed sources")
## Build/upgrade multiplier by island tier; index 0 = tier 1.
@export var build_speed_by_island_tier: Array[float] = [1.0, 0.85, 0.7, 0.55, 0.4]
## Research multiplier by the highest Academy level owned; index 0 = no Academy.
@export var research_speed_by_academy_level: Array[float] = [1.0, 0.8, 0.65, 0.5, 0.4, 0.3]
## Ship construction and repair multiplier by that island's Shipyard level;
## index 0 = no Shipyard.
@export var ship_speed_by_shipyard_level: Array[float] = [1.0, 0.8, 0.65, 0.5, 0.4, 0.3]

@export_group("Repair")
## Seconds of repair job per missing hull or sail point, before the Shipyard speed.
@export var repair_seconds_per_point: float = 0.5

@export_group("Zero-spend gate")
## No job a Ch1-2 objective requires may take longer than this at the speed-source
## level those chapters reach (tests/test_zero_spend_gate.gd).
@export var zero_spend_early_cap_seconds: float = 120.0


## The multiplier table for a job kind, or [] (with an error) for an unknown kind.
func speed_multipliers_for(kind: String) -> Array[float]:
	match kind:
		"build", "upgrade":
			return build_speed_by_island_tier
		"research":
			return research_speed_by_academy_level
		"ship", "repair":
			return ship_speed_by_shipyard_level
	push_error("EconomyPricingData: no speed source for job kind '%s'." % kind)
	return []


## `level` is the kind's speed-source level: island tier (1-5) for build/upgrade,
## Academy level (0-5) for research, Shipyard level (0-5) for ship/repair. Levels
## past either end of a table clamp to it. A base of 0 stays 0 (instant).
func effective_duration(kind: String, base: float, level: int) -> float:
	if base <= 0.0:
		return 0.0
	var table := speed_multipliers_for(kind)
	if table.is_empty():
		return base
	var index := level - 1 if kind in ["build", "upgrade"] else level
	return base * table[clampi(index, 0, table.size() - 1)]


## Eights to finish a job with `remaining` seconds left: at least one while any time
## remains, 0 once it is due.
func finish_cost(remaining: float) -> int:
	if remaining <= 0.0:
		return 0
	return maxi(1, ceili(remaining / seconds_per_eight))

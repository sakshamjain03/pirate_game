@tool
class_name HeatConfigData extends Resource

## Purpose: the authored heat-tier catalog and the single resolver from a
## notoriety value to a tier (M25). This is also the game's ambient-encounter
## difficulty curve — it absorbs the `DifficultyCurve.tres` deferred from M24
## rather than existing alongside a second escalation file.
## Responsibilities: pure data plus lookup. `EmpireManager` owns the current
## tier and the signal; this resource only answers questions.
## Dependencies: HeatTierData.

## Authored lowest-first. `tier_for()` tolerates any order, but authoring them
## sorted keeps the .tres readable as a curve.
@export var tiers: Array[HeatTierData] = []

@export_group("Cooling off")
## Seconds with no notoriety gain before free decay starts. The pre-M25 value
## was 600s, which was far too inert to read as "cooling off" — the player had
## to stop playing for ten minutes to see any change at all.
@export_range(0.0, 900.0) var decay_grace_seconds: float = 120.0
## Multiplier on decay while docked at a player-owned island ("lying low").
@export_range(1.0, 10.0) var lying_low_multiplier: float = 2.0


## The single resolver. Returns the highest tier whose `min_notoriety` the value
## meets. Everything that needs to know the current heat asks through here, so
## the thresholds live in exactly one place.
func tier_for(notoriety: float) -> HeatTierData:
	var best: HeatTierData = null
	for t in tiers:
		if t == null:
			continue
		if notoriety >= t.min_notoriety:
			if best == null or t.min_notoriety > best.min_notoriety:
				best = t
	if best == null:
		# Authoring error, not a runtime condition: a catalog with no tier at or
		# below the current notoriety cannot describe the world. Never fall back
		# silently — a missing tier would quietly reinstate the old flat cap.
		push_error("HeatConfigData: no tier matches notoriety %.1f. The catalog must author a tier with min_notoriety <= 0." % notoriety)
	return best


## The tier one step below `tier`, or null if it is already the lowest. Used by
## the paid clear, which drops exactly one tier.
func tier_below(tier: HeatTierData) -> HeatTierData:
	if tier == null:
		return null
	var best: HeatTierData = null
	for t in tiers:
		if t == null or t.min_notoriety >= tier.min_notoriety:
			continue
		if best == null or t.min_notoriety > best.min_notoriety:
			best = t
	return best


func highest_tier() -> HeatTierData:
	var best: HeatTierData = null
	for t in tiers:
		if t and (best == null or t.min_notoriety > best.min_notoriety):
			best = t
	return best

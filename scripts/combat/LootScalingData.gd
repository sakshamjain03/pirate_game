@tool
class_name LootScalingData extends Resource

## Purpose: data-driven loot scaling factors, shared between boarding and sinking.
## Both a resource for balance tuning and a static helper for the multiplier formula.

@export var notoriety_divisor: float = 100.0
@export var class_multiplier_max: float = 3.0
@export var max_multiplier: float = 5.0
@export var crew_per_class_step: float = 8.0

static var _cached: LootScalingData = null

## Compute loot multiplier from max crew and notoriety, clamped and data-driven.
static func multiplier(max_crew: int, notoriety: float) -> float:
	var data := _load_once()
	if not data:
		return 1.0

	# Class multiplier: higher crew count = higher loot multiplier
	var class_mult = clamp(float(max_crew) / data.crew_per_class_step, 1.0, data.class_multiplier_max)

	# Notoriety multiplier: higher notoriety = higher loot multiplier
	var not_mult = 1.0 + (notoriety / data.notoriety_divisor)

	# Combined multiplier, clamped to max_multiplier
	var combined = class_mult * not_mult
	return clampf(combined, 1.0, data.max_multiplier)

static func _load_once() -> LootScalingData:
	if _cached:
		return _cached

	_cached = load("res://resources/combat/LootScaling.tres")
	if not _cached:
		push_error("LootScalingData: Failed to load res://resources/combat/LootScaling.tres")
		return null

	return _cached

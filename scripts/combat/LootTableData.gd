extends Resource
class_name LootTableData

## Purpose: Defines randomized loot generation ranges (M9).
## Responsibilities: Provides a roll() method to generate a concrete loot dictionary.

@export var min_gold: int = 10
@export var max_gold: int = 50

@export var min_wood: int = 0
@export var max_wood: int = 15

@export var min_iron: int = 0
@export var max_iron: int = 5

@export var min_rum: int = 0
@export var max_rum: int = 2

## `rng` is optional: boarding battles pass their seeded generator so a replay
## of the same battle pays the same loot; every other caller keeps the global RNG.
func roll(rng: RandomNumberGenerator = null) -> Dictionary:
	var loot = {}
	var g = _range(rng, min_gold, max_gold)
	if g > 0: loot["gold"] = g

	var w = _range(rng, min_wood, max_wood)
	if w > 0: loot["wood"] = w

	var i = _range(rng, min_iron, max_iron)
	if i > 0: loot["iron"] = i

	var r = _range(rng, min_rum, max_rum)
	if r > 0: loot["rum"] = r

	return loot


static func _range(rng: RandomNumberGenerator, lo: int, hi: int) -> int:
	return rng.randi_range(lo, hi) if rng != null else randi_range(lo, hi)

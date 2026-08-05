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

func roll() -> Dictionary:
	var loot = {}
	var g = randi_range(min_gold, max_gold)
	if g > 0: loot["gold"] = g
	
	var w = randi_range(min_wood, max_wood)
	if w > 0: loot["wood"] = w
	
	var i = randi_range(min_iron, max_iron)
	if i > 0: loot["iron"] = i
	
	var r = randi_range(min_rum, max_rum)
	if r > 0: loot["rum"] = r
	
	return loot

extends Resource
class_name TechData

## Purpose: Defines a permanent technology upgrade.
## Responsibilities: Holds cost, name, and stat modifiers.

@export var tech_id: String
@export var tech_name: String
@export var description: String
@export var cost_gold: int = 100
@export var cost_wood: int = 0
@export var cost_iron: int = 0

## M11 — gates this tech behind the player's home island reaching this tier,
## mirroring BuildingData.required_island_tier's exact pattern. 1 = ungated.
@export var required_island_tier: int = 1

## M11 — this tech's tech_id must already be unlocked (TechManager.is_unlocked())
## before this one can be researched. Empty string = no prerequisite.
@export var required_prerequisite_tech_id: String = ""

@export_group("Modifiers")
@export var health_modifier: float = 1.0
@export var damage_modifier: float = 1.0
@export var speed_modifier: float = 1.0
@export var storage_modifier: float = 1.0

func get_cost_dict() -> Dictionary:
	var dict = {}
	if cost_gold > 0: dict["gold"] = cost_gold
	if cost_wood > 0: dict["wood"] = cost_wood
	if cost_iron > 0: dict["iron"] = cost_iron
	return dict

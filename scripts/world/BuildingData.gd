@tool
class_name BuildingData extends Resource

## Purpose: Defines properties for an island building.
## Responsibilities: Stores cost, production rates, and visual representation.

@export var building_id: String = "lumber_mill"
@export var building_name: String = "Lumber Mill"
@export var description: String = "Produces wood over time."
@export var next_upgrade: Resource # BuildingData

@export_group("Progression")
@export var level: int = 1
@export var required_island_tier: int = 1
@export var storage_bonus: Dictionary = {}
@export_group("Cost")
@export var cost_gold: int = 50
@export var cost_wood: int = 0
@export var cost_iron: int = 0

@export_group("Production")
@export var produces_resource: String = "wood"
@export var production_amount: int = 5
@export var production_interval: float = 10.0 # seconds per tick

@export_group("Visual")
@export var icon_path: String = ""
@export var model_path: String = "res://assets/models/structure.glb"

func get_cost_dict() -> Dictionary:
	var cost = {}
	if cost_gold > 0: cost["gold"] = cost_gold
	if cost_wood > 0: cost["wood"] = cost_wood
	if cost_iron > 0: cost["iron"] = cost_iron
	return cost

extends Resource
class_name FactionData

## Purpose: Defines a Faction in the game world (M7).
## Responsibilities: Holds faction name, base hostility, and a primary color for ships.

@export var faction_id: String
@export var faction_name: String
@export var is_hostile_to_player: bool = true
@export var sail_color: Color = Color.WHITE
@export var hull_color: Color = Color.WHITE

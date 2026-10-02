extends Resource
class_name FactionData

## Purpose: Defines a Faction in the game world (M7).
## Responsibilities: Holds faction name, base hostility, and a primary color for ships.

@export var faction_id: String
@export var faction_name: String
@export var is_hostile_to_player: bool = true
@export var is_empire: bool = false
@export var sail_color: Color = Color.WHITE
@export var hull_color: Color = Color.WHITE

@export_group("Consequences")
@export var sink_reputation_loss: int = 0
@export var boarding_reputation_loss: int = 0
@export var hunter_cooldown_seconds: float = 120.0
@export var tribute_cost_gold: int = 500
@export var tribute_cooldown_seconds: float = 300.0
@export var raid_frequency_mult: float = 1.0

@export_group("Art seams (owner-supplied, M31)")
@export var flag_texture_path: String = ""
@export var sail_texture_path: String = ""

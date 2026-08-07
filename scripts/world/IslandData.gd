@tool
class_name IslandData extends Resource

@export var island_id: String = "island_001"
@export var island_name: String = "Unknown Island"
@export var discovered: bool = false

enum IslandType { NEUTRAL, FRIENDLY, ENEMY, CAPITAL, LEGENDARY }
@export var island_type: IslandType = IslandType.NEUTRAL
@export var owner_faction: Resource # FactionData


@export_group("Docking")
@export var has_dock: bool = true
@export var docking_speed_limit: float = 5.0

@export_group("Visual")
@export var model_path: String = ""

## All six islands share one Island.tscn layout — this lets a specific
## island (e.g. a volcano or a frozen reef, by name) re-tint its shared
## terrain materials at runtime instead of reading as a copy-pasted
## tropical island regardless of its name and lore.
enum TerrainTheme { TROPICAL, VOLCANIC, FROZEN }
@export var terrain_theme: TerrainTheme = TerrainTheme.TROPICAL

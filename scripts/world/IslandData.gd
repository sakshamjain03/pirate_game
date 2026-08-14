@tool
class_name IslandData extends Resource

@export var island_id: String = "island_001"
@export var island_name: String = "Unknown Island"
@export var discovered: bool = false

enum IslandType { NEUTRAL, FRIENDLY, ENEMY, CAPITAL, LEGENDARY }
@export var island_type: IslandType = IslandType.NEUTRAL
@export var owner_faction: Resource # FactionData

@export_group("World")
## Authored XZ position, kept in sync with this island's transform in World.tscn.
## The scene file is still what places the island; this mirrors it so that code and
## UI can reason about distance and region membership without walking the scene
## tree (a prerequisite for the world-map UI). See docs/11_WORLD_MAP.md.
@export var world_position: Vector2 = Vector2.ZERO
## Which RegionData this island belongs to. RegionData.island_ids already holds the
## same relationship, but only one-way — this is the reverse lookup.
@export var region_id: String = ""

@export_group("Progression")
@export var min_buildings_for_tier: int = 2

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

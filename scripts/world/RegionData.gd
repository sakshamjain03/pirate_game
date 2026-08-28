extends Resource
class_name RegionData

## Purpose: Defines one of the 3 empire-escalation regions (M4).
## Responsibilities: Groups a set of islands under a tier, dominant faction, and the notoriety
##   threshold at which EmpireManager activates it (dormant regions have no defenders and can't
##   be colonized — see Island.gd's _should_be_active()).
## Dependencies: None — pure data, loaded by EmpireManager from resources/world/regions/.

@export var id: String
@export var display_name: String
@export var tier: int
@export var dominant_faction: String
@export var activation_notoriety_threshold: float
@export var island_ids: Array[String]

## M10 — the outer edge of this region's ring band in world units (see
## docs/11_WORLD_MAP.md's Expanded layout), used by WorldMapScreen to draw
## concentric region rings. World geography, not gameplay balance, but kept
## here rather than hardcoded in UI script per AGENTS.md's data-over-code
## rule — this is the same object that already owns "what varies per region."
@export var display_ring_radius: float = 0.0

## M10 Requirement 5 — per-region weather modifiers applied to OceanSettings.
## Multiplied against the base OceanSettings values when this region becomes
## the player's current region. Beginner Waters (calm) ≈ 1.0, Contested Waters
## (choppy) ≈ 1.3, Imperial Waters (heavy seas) ≈ 1.6.
@export var wave_intensity_multiplier: float = 1.0
@export var fog_density_multiplier: float = 1.0

## M10 Requirement 5 — per-region ship type pool. When spawning ambient
## enemies in this region, EnemySpawner picks a random ShipStats from this
## array instead of always using the default enemy ship. Allows Beginner Waters
## to spawn Sloops/Dinghies, Contested Waters to spawn mid-tier hulls, Imperial
## Waters to spawn Frigates/Galleons. If empty, falls back to default behavior.
@export var enemy_ship_pool: Array[ShipStats] = []

## M11 Requirement 2 — prevailing wind for this region, read by ShipMovement
## as one more multiplicative term on speed_mod. 0 strength is a no-op
## regardless of direction. Beginner Waters ≈ 0.2 (light breeze), Contested
## ≈ 0.5, Imperial ≈ 0.8 (heavy gale) — same calm-to-harsh escalation M10
## already established for wave_intensity_multiplier/fog_density_multiplier.
@export_range(0.0, 1.0) var wind_strength: float = 0.0
@export_range(0.0, 360.0) var wind_direction_degrees: float = 0.0

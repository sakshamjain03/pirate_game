class_name QualityTierData extends Resource

## Per-quality-tier rendering settings that respond to SettingsManager.graphics_quality.
##
## Each tier contains settings for shadows, MSAA, SSAO, glow, ocean effects, and
## ambient hull spawning caps. Settings are applied via Environment/DirectionalLight3D
## properties and through OceanController/EnemySpawner.

@export_group("Shadows", "shadow_")
@export var shadow_enabled: bool = true
@export var shadow_distance: float = 100.0

@export_group("Anti-aliasing", "msaa_")
@export var msaa_mode: Viewport.MSAA = Viewport.MSAA_2X

@export_group("Ambient occlusion", "ssao_")
@export var ssao_enabled: bool = true

@export_group("Glow", "glow_")
@export var glow_enabled: bool = true

@export_group("Ocean effects", "ocean_")
@export var ocean_sparkle_enabled: bool = true
@export var ocean_ring_density: float = 1.0  # Multiplier for wake ring density

@export_group("Combat", "combat_")
@export var ambient_hull_cap: int = 10  # Max ambient spawned ships at once

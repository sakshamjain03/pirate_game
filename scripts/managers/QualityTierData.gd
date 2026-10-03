class_name QualityTierData extends Resource

## M29 E.2 — one graphics-quality tier. QualityTierTable holds one per
## SettingsManager.graphics_quality value (0 Low, 1 Medium, 2 High); World and
## OceanController apply the active tier whenever settings change.
##
## Medium is authored to match World.tscn's look as it shipped before M29, so the
## default tier changes nothing on screen; Low is where the savings are.

@export_group("Shadows", "shadow_")
@export var shadow_enabled: bool = true
## DirectionalLight3D.directional_shadow_max_distance (Godot default 100).
@export var shadow_distance: float = 100.0

@export_group("Anti-aliasing", "msaa_")
## Applied to the Viewport — MSAA is a Viewport property in Godot 4, not an
## Environment one.
@export var msaa_mode: Viewport.MSAA = Viewport.MSAA_DISABLED

@export_group("Ambient occlusion", "ssao_")
@export var ssao_enabled: bool = true

@export_group("Glow", "glow_")
@export var glow_enabled: bool = true

@export_group("Ocean effects", "ocean_")
@export var ocean_sparkle_enabled: bool = true


## Applies this tier. Any argument may be null (headless tests, scenes without a
## sun); each is skipped independently.
func apply_to(env: Environment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	if env:
		env.ssao_enabled = ssao_enabled
		env.glow_enabled = glow_enabled
	if sun:
		sun.shadow_enabled = shadow_enabled
		sun.directional_shadow_max_distance = shadow_distance
	if viewport:
		viewport.msaa_3d = msaa_mode

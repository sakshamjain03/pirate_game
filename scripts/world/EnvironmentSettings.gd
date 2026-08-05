class_name EnvironmentSettings extends Resource

@export_group("Sun")
@export var sun_color_morning: Color = Color("#ffb38a")
@export var sun_color_noon: Color = Color("#fffdfa")
@export var sun_color_evening: Color = Color("#ff7a59")
@export var sun_color_night: Color = Color("#34487a")

## Sky background colors per time-of-day keyframe. Without these the sky stays
## a static bright-day gradient even at midnight, since the ProceduralSkyMaterial
## isn't otherwise tied to time of day at all — only the sun's own light dims.
@export_group("Sky Top")
@export var sky_top_morning: Color = Color(0.10, 0.28, 0.5)
@export var sky_top_noon: Color = Color(0.04, 0.32, 0.68)
@export var sky_top_evening: Color = Color(0.08, 0.14, 0.34)
@export var sky_top_night: Color = Color(0.01, 0.02, 0.07)

@export_group("Sky Horizon")
@export var sky_horizon_morning: Color = Color(0.85, 0.62, 0.5)
@export var sky_horizon_noon: Color = Color(0.95, 0.72, 0.42)
@export var sky_horizon_evening: Color = Color(0.55, 0.28, 0.3)
@export var sky_horizon_night: Color = Color(0.03, 0.04, 0.1)

@export_group("Ambient")
@export var ambient_energy_morning: float = 0.3
@export var ambient_energy_noon: float = 0.3
@export var ambient_energy_evening: float = 0.22
@export var ambient_energy_night: float = 0.08

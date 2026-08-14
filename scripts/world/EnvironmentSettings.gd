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

## Only morning and evening are warm. Noon was previously authored as
## (0.95, 0.72, 0.42) — a sunset orange — which, combined with
## EnvironmentController rewriting the sky every frame, made the horizon read
## as a permanent sunset at every time of day. Noon is now a pale daylight haze
## that sits under sky_top_noon, and morning is pulled back from peach to a
## soft warm blue so dawn reads as dawn rather than as a second sunset.
@export_group("Sky Horizon")
@export var sky_horizon_morning: Color = Color(0.68, 0.66, 0.62)
@export var sky_horizon_noon: Color = Color(0.62, 0.76, 0.88)
@export var sky_horizon_evening: Color = Color(0.72, 0.36, 0.26)
@export var sky_horizon_night: Color = Color(0.03, 0.04, 0.1)

@export_group("Ambient")
@export var ambient_energy_morning: float = 0.3
@export var ambient_energy_noon: float = 0.3
@export var ambient_energy_evening: float = 0.22
@export var ambient_energy_night: float = 0.08

@export_group("Sun Energy")
## Directional light energy across the day. These were hardcoded in
## EnvironmentController as (0.3, 0.9, 1.3, 0.9).
##
## Noon was 1.3, which OVERBRIGHTENED the scene into channel clipping: the
## Kenney colormap's warm wood tones peak around RGB(241,151,108), and
## 0.945 * sun_red * 1.3 = 1.23, clipped to 1.0. Every warm surface lost its
## red-channel detail and collapsed toward the same washed-out salmon, while
## cooler surfaces (sails, water) kept theirs — which is exactly why hulls,
## palm trunks, rocks, docks and sand all read as one flat orange while the
## sails still looked correct. 1.0 keeps the brightest atlas pixel just under
## clipping while staying bright.
@export var sun_energy_morning: float = 0.75
@export var sun_energy_noon: float = 1.0
@export var sun_energy_evening: float = 0.75
@export var sun_energy_night: float = 0.25

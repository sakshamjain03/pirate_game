class_name ThreatDecalsData extends Resource

## Purpose: tuning for the enemy broadside wind-up read (M30 W1-1.2, task 1.5):
## the wedge decal on the water and the screen-rim arrow. Read by ThreatDecals.
## Authored in resources/ui/ThreatDecals.tres.

## At most this many threats are drawn at once — more than two wedges stop being
## a read and become noise on a phone screen.
@export_range(1, 6) var max_visible: int = 2  # placeholder: tune in M31
## How often (seconds) the HUD looks for newly spawned hostile hulls to watch.
@export var scan_interval: float = 0.25  # placeholder: tune in M31
## Wedge length/arc used when the attacker has no FiringSolver to ask.
@export var fallback_range: float = 60.0  # placeholder: tune in M31
@export var fallback_arc_degrees: float = 35.0  # placeholder: tune in M31
## World height the wedge is drawn at (just above calm sea level).
@export var wedge_height: float = 0.4  # placeholder: tune in M31
## Wedge alpha ramps from min (wind-up just started) to max (about to fire).
@export_range(0.0, 1.0) var wedge_alpha_min: float = 0.22  # placeholder: tune in M31
@export_range(0.0, 1.0) var wedge_alpha_max: float = 0.6  # placeholder: tune in M31
## Seconds before the volley over which the alpha ramp runs (a longer fuse
## sits at wedge_alpha_min until it is inside this horizon).
@export var alpha_ramp_seconds: float = 3.0  # placeholder: tune in M31
## Rim arrow inset from the screen edge, and its size, in canvas pixels.
@export var rim_margin_px: float = 56.0  # placeholder: tune in M31
@export var rim_arrow_size_px: float = 30.0  # placeholder: tune in M31
## Tint per AmmoData.ammo_id, so the player can read *what* is coming (round =
## hull, chain = rigging, grape = crew) and answer with the right ammo or brace.
@export var ammo_colors: Dictionary = {}
@export var default_color: Color = Color(1.0, 0.3, 0.2, 1.0)


func color_for_ammo(ammo_id: String) -> Color:
	if ammo_colors.has(ammo_id):
		return ammo_colors[ammo_id]
	return default_color

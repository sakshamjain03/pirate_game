class_name CombatFeedbackData extends Resource

## Purpose: tuning for the M30 W1-2.3 feedback pack (task 1.11) and the
## tap-to-mark pick (task 1.8). Read by CombatFeedback, RibbonStack,
## FloatingDamage, CameraRig.punch() callers and WorldManager.
## Authored in resources/ui/CombatFeedback.tres.

@export_group("Ribbons")
## At most this many ribbons on screen; a new one retires the oldest.
@export_range(1, 6) var max_ribbons: int = 3  # placeholder: tune in M31
## Seconds a ribbon stays up. A repeat of the same ribbon restarts it and
## bumps its "xN" count instead of taking a second slot.
@export var ribbon_lifetime: float = 2.2  # placeholder: tune in M31

@export_group("Camera punch")
## Peak camera h/v_offset (world units) for each event. Never time_scale.
@export var punch_hit_taken: float = 0.35  # placeholder: tune in M31
@export var punch_rake: float = 0.2  # placeholder: tune in M31
@export var punch_kill: float = 0.3  # placeholder: tune in M31
## Seconds for a punch to decay back to a zero offset.
@export var punch_duration: float = 0.25  # placeholder: tune in M31
## Ceiling on a single punch, so stacked hits never throw the frame.
@export var punch_max: float = 0.6  # placeholder: tune in M31

@export_group("Damage numbers")
## The ONE ammo palette (ThreatDecals.tres): an incoming wedge and the number
## that hit lands as share a colour, so the player learns one language.
@export var ammo_palette: ThreatDecalsData
## A stern or bow hit (a rake) overrides the ammo colour. Kept well clear of
## every ammo palette colour (round red, chain blue, grape yellow) and from the
## red threat wedge: green reads as "your opening", never as incoming fire.
@export var rake_color: Color = Color(0.35, 1.0, 0.45, 1.0)  # placeholder: tune in M31

@export_group("Rake cone")
## The cone drawn off the current target's stern: sail into it to rake.
@export var rake_cone_length: float = 30.0  # placeholder: tune in M31
@export var rake_cone_height: float = 0.35  # placeholder: tune in M31
@export var rake_cone_color: Color = Color(0.35, 1.0, 0.45, 0.3)  # placeholder: tune in M31
## Half-angle used when the target has no ShipStats (else stern_arc_degrees / 2).
@export var rake_cone_fallback_half_angle: float = 30.0  # placeholder: tune in M31

@export_group("Tap to mark")
## A tap marks the hostile hull whose on-screen position is nearest the touch,
## if it is within this many canvas pixels (fat-finger tolerance).
@export var mark_pick_radius_px: float = 90.0  # placeholder: tune in M31
## A touch that moves further than this before release is a camera drag, not a tap.
@export var tap_slop_px: float = 24.0  # placeholder: tune in M31

@export_group("Scan")
## How often (seconds) the feedback node looks for the player hull to wire.
@export var scan_interval: float = 0.25  # placeholder: tune in M31


## Colour for a damage number: rake colour for stern/bow facings, else the
## ammo's palette colour; `fallback` (the HUD's hp-low red) for anything the
## palette doesn't know (impacts, untyped damage).
func damage_color(ammo_id: String, facing: StringName, fallback: Color) -> Color:
	if facing == &"stern" or facing == &"bow":
		return rake_color
	if ammo_palette and ammo_palette.ammo_colors.has(ammo_id):
		return ammo_palette.ammo_colors[ammo_id]
	return fallback

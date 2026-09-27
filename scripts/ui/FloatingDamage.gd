extends Label3D

## Purpose: Floating text used for damage numbers.
## Responsibilities: Displays a number, floats up, fades out, and destroys itself.
## Dependencies: None

@export var damage_amount: float = 0
@export var float_duration: float = 1.0
@export var float_distance: float = 3.0

## Label3D font px (rendered at `fixed_size`, so screen-constant). At
## _FIXED_PIXEL_SIZE the number is ~60 canvas px tall on the 780px-high
## base viewport — the HUD's own number size, readable at any range.
const _FONT_SIZE := 72
const _OUTLINE_SIZE := 18
const _FIXED_PIXEL_SIZE := 0.0016

func _ready() -> void:
	# Format text
	text = "-" + str(int(damage_amount))
	
	# M22 6.9: v0.3 numbers — Baloo 2 ExtraBold in hp-low red with a thick
	# ink outline (was the engine default font with a thin black edge).
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var pal := UITokens.palette()
	var num_font := PirateThemeBuilder.number_font()
	if num_font:
		font = num_font
	# Constant on-screen size: at world scale a hit on a ship 40m out was a
	# few pixels tall (M22 6.9 capture). no_depth_test keeps it over waves.
	fixed_size = true
	pixel_size = _FIXED_PIXEL_SIZE
	no_depth_test = true
	modulate = pal.hp_low
	outline_modulate = pal.ink
	outline_size = _OUTLINE_SIZE
	font_size = PirateThemeBuilder.scaled_font_size(_FONT_SIZE)
	
	# Start tween animation
	var tween = create_tween().set_parallel(true)
	
	# Float up — RELATIVE to wherever the label is when the tween starts
	# (its first process step), not an absolute target computed here: both
	# spawners (ShipCombat, ShipCollisionHandler) add_child() first and set
	# global_position after, so a target taken in _ready() was origin + 3m and
	# every damage number slid toward the world origin (M22 6.9 capture).
	tween.tween_property(self, "position", Vector3(0, float_distance, 0), float_duration) 		.as_relative().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Fade out alpha
	tween.tween_property(self, "modulate:a", 0.0, float_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# Delete after duration
	tween.chain().tween_callback(queue_free)

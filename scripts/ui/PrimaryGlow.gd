class_name PrimaryGlow extends TextureRect

## Purpose: the looping glow behind a screen's single Primary CTA button
## (design.md §7, requirements.md Requirement 5.3). A plain child of the
## Button it glows for — `show_behind_parent = true` draws it beneath the
## parent with no sibling reshuffle needed (AGENTS.md composition, same
## precedent as ButtonJuice being a child Node rather than a Button
## subclass). Added/removed only via PirateThemeBuilder.mark_primary(),
## never placed directly in a .tscn.

const GLOW_TEXTURE := "res://assets/ui/kit/glow_sprite.svg"

var _loop_tween: Tween


func _ready() -> void:
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex = ResourceLoader.load(GLOW_TEXTURE)
	if tex is Texture2D:
		texture = tex
	else:
		push_warning("PrimaryGlow: could not load " + GLOW_TEXTURE)

	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left   = -UITokens.GLOW_INSET
	offset_top    = -UITokens.GLOW_INSET
	offset_right  = UITokens.GLOW_INSET
	offset_bottom = UITokens.GLOW_INSET

	modulate.a = UITokens.GLOW_OPACITY_MIN
	scale = Vector2.ONE * UITokens.GLOW_SCALE_MIN
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)

	_start_loop()


func _start_loop() -> void:
	var half := UITokens.GLOW_PERIOD_SEC / 2.0
	_loop_tween = create_tween().set_loops()
	_loop_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop_tween.tween_property(self, "modulate:a", UITokens.GLOW_OPACITY_MAX, half)
	_loop_tween.parallel().tween_property(self, "scale", Vector2.ONE * UITokens.GLOW_SCALE_MAX, half)
	_loop_tween.tween_property(self, "modulate:a", UITokens.GLOW_OPACITY_MIN, half)
	_loop_tween.parallel().tween_property(self, "scale", Vector2.ONE * UITokens.GLOW_SCALE_MIN, half)

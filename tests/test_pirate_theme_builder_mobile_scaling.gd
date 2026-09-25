extends GutTest

# test_pirate_theme_builder_mobile_scaling.gd
# M13 Task 16.5 follow-up #2 (2026-09-20) — PirateThemeBuilder gained a
# dynamic mobile-only sizing API (MOBILE_CONTROL_SCALE, is_mobile(),
# scaled()/scaled_size()/scaled_font_size(), apply_mobile_control_scaling())
# used across every dialog/popup screen. GUT runs headless on a desktop
# Godot binary, so OS.has_feature("pc") is true here and is_mobile() always
# takes the PC branch — there is no way to exercise the mobile branch itself
# in this environment (see CLAUDE.md's note on manual/visual behavior; the
# mobile branch is verified via real-device screenshots instead). What CAN
# be verified headlessly, and matters just as much, is the invariant the
# whole design depends on: PC sizing must be completely unaffected — a
# no-op passthrough — by every one of these helpers.

func test_is_mobile_is_false_on_the_pc_test_platform():
	assert_false(PirateThemeBuilder.is_mobile(),
		"GUT runs on a desktop Godot binary — OS.has_feature('pc') must be true here")


func test_scaled_size_is_identity_on_pc():
	var pc_size := Vector2(220, 50)
	assert_eq(PirateThemeBuilder.scaled_size(pc_size), pc_size,
		"PC sizing must never be touched by the mobile scaling helper")


func test_scaled_value_is_identity_on_pc():
	var pc_value := -170.0
	assert_eq(PirateThemeBuilder.scaled(pc_value), pc_value,
		"PC offsets/geometry must never be touched by the mobile scaling helper")


func test_scaled_font_size_is_identity_on_pc():
	assert_eq(PirateThemeBuilder.scaled_font_size(24), 24,
		"PC font sizes must never be touched by the mobile scaling helper")


# M22 (2026-09-25) — the project base resolution changed from 1920x1080 to
# 1688x780 (design.md §3), chosen so canvas px already equals real phone dp
# with no multiplier; MOBILE_CONTROL_SCALE dropped from 1.5 to 1.0 as a
# direct, intentional consequence (design.md §3's table). The "must actually
# enlarge" invariant this test used to guard now lives in
# MOBILE_MIN_TOUCH_TARGET (a flat 96x96 canvas-px floor, = 48dp x2) instead
# of a scale multiplier — see test_touch_target_audit.gd.
func test_mobile_control_scale_is_never_below_pc_size():
	assert_true(PirateThemeBuilder.MOBILE_CONTROL_SCALE >= 1.0,
		"Mobile control geometry must never shrink below PC size")


func test_mobile_min_touch_target_meets_the_48dp_floor():
	# 96 canvas px = 48dp x2 at M22's base (design.md §3) — the actual
	# invariant "mobile touch targets must actually be big enough" now
	# guards, replacing the old scale-multiplier-based check above.
	assert_eq(PirateThemeBuilder.MOBILE_MIN_TOUCH_TARGET, Vector2(96, 96))


func test_apply_mobile_control_scaling_is_a_noop_on_pc():
	var root := Control.new()
	add_child_autofree(root)
	var child := Button.new()
	child.custom_minimum_size = Vector2(80, 40)
	child.add_theme_font_size_override("font_size", 18)
	root.add_child(child)

	PirateThemeBuilder.apply_mobile_control_scaling(root)

	assert_eq(child.custom_minimum_size, Vector2(80, 40),
		"The recursive scaling sweep must not touch custom_minimum_size on PC")
	assert_eq(child.get_theme_font_size("font_size"), 18,
		"The recursive scaling sweep must not touch a font_size override on PC")


# 2026-09-20 phone/tablet split — a tablet has more physical inches per
# logical pixel than a phone at typical viewing distance, so it should get
# bigger text without proportionally bigger touch targets. control_scale()/
# font_scale()/_min_touch_target() are the one place that picks phone vs.
# tablet; every existing scaled_size()/scaled_font_size()/apply_button_juice()
# call site becomes tablet-aware automatically through them.
#
# M22 (2026-09-25) — with MOBILE_CONTROL_SCALE now 1.0 (see above), "a
# tablet's touch targets should not grow as much as a phone's" is satisfied
# by TABLET_CONTROL_SCALE also being 1.0 (equal, not smaller — neither scales
# control geometry up any more; MOBILE_MIN_TOUCH_TARGET/TABLET_MIN_TOUCH_TARGET,
# both 96x96, are what guarantee the floor now, per design.md §3's "a finger
# isn't bigger on a tablet"). Font is still the one axis a tablet grows.
func test_tablet_control_scale_equals_phone_but_font_scale_is_larger():
	PirateThemeBuilder.force_mobile_scaling_for_test = true
	MobileLayoutManager.force_tablet_for_test = true

	assert_eq(PirateThemeBuilder.control_scale(), PirateThemeBuilder.MOBILE_CONTROL_SCALE,
		"A tablet's control geometry no longer scales differently from a phone's")
	assert_gt(PirateThemeBuilder.font_scale(), PirateThemeBuilder.MOBILE_FONT_SCALE,
		"A tablet's text should grow more than a phone's, even though its buttons don't grow further")

	MobileLayoutManager.force_tablet_for_test = false
	PirateThemeBuilder.force_mobile_scaling_for_test = false


func test_phone_scaling_is_unchanged_when_tablet_is_not_forced():
	PirateThemeBuilder.force_mobile_scaling_for_test = true
	MobileLayoutManager.force_tablet_for_test = false

	assert_eq(PirateThemeBuilder.control_scale(), PirateThemeBuilder.MOBILE_CONTROL_SCALE,
		"Without tablet detection, control_scale() must stay the existing phone constant")
	assert_eq(PirateThemeBuilder.font_scale(), PirateThemeBuilder.MOBILE_FONT_SCALE,
		"Without tablet detection, font_scale() must stay the existing phone constant")

	PirateThemeBuilder.force_mobile_scaling_for_test = false

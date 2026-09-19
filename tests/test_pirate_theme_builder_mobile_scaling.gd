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


func test_mobile_control_scale_actually_grows_things():
	assert_gt(PirateThemeBuilder.MOBILE_CONTROL_SCALE, 1.0,
		"The one dial every screen's mobile sizing depends on must actually enlarge, not shrink or no-op")


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

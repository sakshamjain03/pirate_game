extends GutTest

# test_mobile_dialog_sizing.gd
# 2026-09-20 device-test feedback — CaptainsLog/WorldMapScreen/WhatsNewScreen/
# CodexScreen's modal panels, scaled by a flat PirateThemeBuilder.
# control_scale() multiplier of a small PC-authored box, still read as a
# narrow column surrounded by wasted space on a real 2340x1080 landscape
# phone screenshot. MobileLayoutManager.mobile_dialog_size() is the shared
# fix all four screens' panel sizing now routes through.

var _viewport: SubViewport

func before_each():
	PirateThemeBuilder.force_mobile_scaling_for_test = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(2340, 1080)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

func after_each():
	PirateThemeBuilder.force_mobile_scaling_for_test = false
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null


func test_dialog_size_is_much_larger_than_the_flat_scaled_size_on_a_wide_phone():
	var pc_size := Vector2(480, 560)
	var result: Vector2 = MobileLayoutManager.mobile_dialog_size(pc_size, _viewport)
	var flat_scaled := pc_size * PirateThemeBuilder.control_scale()
	assert_true(result.x > flat_scaled.x * 1.5,
		"A 2340px-wide landscape phone should get a dialog much wider than a flat 1.5x of a small PC box (got %s vs flat %s)" %
			[result, flat_scaled])


func test_dialog_size_never_exceeds_the_safe_area():
	var pc_size := Vector2(480, 560)
	var result: Vector2 = MobileLayoutManager.mobile_dialog_size(pc_size, _viewport)
	var safe := MobileLayoutManager.safe_area(_viewport)
	assert_true(result.x <= safe.size.x, "Dialog width must not exceed the safe area")
	assert_true(result.y <= safe.size.y, "Dialog height must not exceed the safe area")


func test_dialog_size_never_shrinks_below_the_existing_flat_scaled_size():
	var pc_size := Vector2(480, 560)
	var result: Vector2 = MobileLayoutManager.mobile_dialog_size(pc_size, _viewport)
	var flat_scaled := pc_size * PirateThemeBuilder.control_scale()
	assert_true(result.x >= flat_scaled.x - 0.5)
	assert_true(result.y >= flat_scaled.y - 0.5)


func test_a_landscape_authored_panel_is_not_squashed_taller_than_wide():
	# CodexScreen authors 780x600 (wider than tall) — the fix must not flip
	# that relationship on a landscape phone screen.
	var pc_size := Vector2(780, 600)
	var result: Vector2 = MobileLayoutManager.mobile_dialog_size(pc_size, _viewport)
	assert_true(result.x >= result.y,
		"A landscape-authored panel should stay at least as wide as it is tall")


func test_on_a_narrow_safe_area_the_result_still_fits_on_screen():
	# When even the flat-scaled floor would exceed a narrow safe area (e.g.
	# portrait or a small notch cutout), staying on-screen must win over
	# preserving that floor — verifies the final safe-area clamp applies
	# even when it means shrinking below the flat-scaled size.
	_viewport.size = Vector2i(500, 1000)
	var pc_size := Vector2(480, 560)
	var result: Vector2 = MobileLayoutManager.mobile_dialog_size(pc_size, _viewport)
	var safe := MobileLayoutManager.safe_area(_viewport)
	assert_true(result.x <= safe.size.x, "Must not exceed the safe area even on a narrow viewport")
	assert_true(result.y <= safe.size.y, "Must not exceed the safe area even on a narrow viewport")

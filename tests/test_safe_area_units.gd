extends GutTest

# test_safe_area_units.gd
# M22 Phase 1.5 — MobileLayoutManager.safe_area() previously intersected
# DisplayServer.get_display_safe_area() (PHYSICAL screen px) directly with
# viewport.get_visible_rect() (CANVAS px), which only agreed by coincidence
# under the old 1080-tall project base on a common 1080-tall phone. At M22's
# 1688x780 base they diverge (~1.385x on a 2340x1080 phone), so safe_area()
# now maps the physical rect through the viewport's own stretch transform
# first. A SubViewport (this project's usual test double) has an identity
# transform and can't model two independent sizes at once, so this test uses
# an embedded Window instead, with real content_scale_* settings — the only
# way to reproduce the actual physical-vs-canvas split under GUT.
#
# Numbers below were verified empirically against the real Godot 4.3 engine
# (not derived from documentation), with content_scale_size=1688x780,
# content_scale_aspect=EXPAND, window size=2340x1080: visible_rect comes back
# 1690x780 (not exactly 1688 — EXPAND matches the *actual* window aspect,
# treating the configured base as a minimum) and final_transform is a
# uniform 1.384615x scale (=2340/1690).

var _win: Window


func before_each():
	PirateThemeBuilder.force_mobile_scaling_for_test = true
	_win = Window.new()
	_win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_win.content_scale_size = Vector2i(1688, 780)
	_win.size = Vector2i(2340, 1080)
	_win.visible = false
	add_child(_win)


func after_each():
	PirateThemeBuilder.force_mobile_scaling_for_test = false
	MobileLayoutManager.force_native_safe_area_for_test = Rect2i()
	if is_instance_valid(_win):
		_win.queue_free()
	_win = null


func test_canvas_visible_rect_differs_from_physical_window_size():
	# Sanity check on the fixture itself: proves canvas px and physical px
	# really do diverge at this base, which is the whole premise of the bug.
	var visible := _win.get_visible_rect()
	assert_almost_eq(visible.size.x, 1690.0, 2.0)
	assert_eq(visible.size.y, 780)
	assert_ne(visible.size, Vector2(_win.size))


func test_safe_area_maps_a_physical_inset_into_canvas_units():
	# 80 physical px inset on the left (e.g. a notch cutout), on a
	# 2340-wide physical window whose canvas is ~1690 wide — the same
	# scenario design.md §3's "Latent unit bug" section describes.
	MobileLayoutManager.force_native_safe_area_for_test = Rect2i(80, 0, 2260, 1080)
	var safe := MobileLayoutManager.safe_area(_win)
	assert_almost_eq(safe.position.x, 57.8, 1.0,
		"An 80 physical-px inset must land at ~57.8 canvas px, not 80 (the pre-fix bug)")
	assert_almost_eq(safe.size.y, 780.0, 1.0)


func test_safe_area_is_a_noop_on_a_subviewport_test_double():
	# Existing tests across the project mock the viewport with a plain
	# SubViewport (identity final_transform) — this fix must not change
	# their numeric behavior at all.
	var sv := SubViewport.new()
	sv.size = Vector2i(2340, 1080)
	add_child(sv)
	MobileLayoutManager.force_native_safe_area_for_test = Rect2i(80, 0, 2260, 1080)
	var safe := MobileLayoutManager.safe_area(sv)
	assert_eq(safe.position.x, 80.0)
	sv.queue_free()


func test_safe_area_margin_applies_the_48dp_floor_when_the_inset_is_smaller():
	MobileLayoutManager.force_native_safe_area_for_test = Rect2i(80, 0, 2260, 1080)
	var margin := SafeAreaMargin.new()
	_win.add_child(margin)
	await wait_frames(2)
	# 57.8 canvas-px inset < the 96 canvas-px (48dp) floor, so the floor wins.
	assert_eq(margin.get_theme_constant("margin_left"), 96)


func test_safe_area_margin_uses_the_real_inset_when_it_exceeds_the_floor():
	# A 300 physical-px inset maps to ~216.7 canvas px — bigger than the
	# 96-canvas-px floor, so the real inset must win here instead.
	MobileLayoutManager.force_native_safe_area_for_test = Rect2i(300, 0, 2040, 1080)
	var margin := SafeAreaMargin.new()
	_win.add_child(margin)
	await wait_frames(2)
	var left: int = margin.get_theme_constant("margin_left")
	assert_gt(left, 96)
	assert_almost_eq(float(left), 216.7, 2.0)

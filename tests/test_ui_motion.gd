extends GutTest

# test_ui_motion.gd
# M22 Phase 7.1 (design.md §10, Requirement 9.1/9.4) — every UIMotion helper
# returns a live Tween, animates from its documented start state, and with
# reduced motion forced on jumps straight to its final state (duration 0).

const SettingsManagerClassDefaults = preload("res://scripts/managers/SettingsManager.gd")

var _root: Control


func before_each():
	UIMotion.force_reduced_motion_for_test = false
	_root = Control.new()
	_root.size = Vector2(400, 300)
	add_child_autofree(_root)


func after_each():
	UIMotion.force_reduced_motion_for_test = false


func _panel() -> Control:
	var c := Control.new()
	c.size = Vector2(200, 100)
	_root.add_child(c)
	return c


func _label(text := "Hello there, captain") -> Label:
	var l := Label.new()
	l.text = text
	_root.add_child(l)
	return l


func test_every_helper_returns_a_valid_tween():
	var tweens := [
		UIMotion.pop_in(_panel()),
		UIMotion.shine(_panel()),
		UIMotion.tick_number(_label("0"), 0, 50),
		UIMotion.stamp(_panel()),
		UIMotion.float_up(_panel()),
		UIMotion.typewrite(_label()),
	]
	for t in tweens:
		assert_true(t is Tween and t.is_valid(), "each helper hands back its running Tween")


func test_pop_in_starts_small_and_transparent_then_settles_at_full_size():
	var c := _panel()
	UIMotion.pop_in(c)
	assert_almost_eq(c.scale.x, UITokens.POP_IN_FROM, 0.01)
	assert_almost_eq(c.modulate.a, 0.0, 0.01)
	await wait_seconds(UITokens.POP_IN_SEC + 0.15)
	assert_almost_eq(c.scale.x, 1.0, 0.01)
	assert_almost_eq(c.modulate.a, 1.0, 0.01)
	assert_eq(c.pivot_offset, c.size * 0.5, "pops about its centre, not a corner")


func test_tick_number_counts_to_the_target():
	var l := _label("0")
	UIMotion.tick_number(l, 10, 250)
	await wait_seconds(UITokens.TICK_SEC + 0.15)
	assert_eq(l.text, "250")


func test_shine_is_one_pulse_that_returns_to_white():
	var c := _panel()
	UIMotion.shine(c)
	await wait_seconds(UITokens.SHINE_SEC * 0.5)
	assert_gt(c.self_modulate.r, 1.0, "brightens mid-pulse")
	await wait_seconds(UITokens.SHINE_SEC * 0.5 + 0.15)
	assert_eq(c.self_modulate, Color.WHITE)
	# Requirement 9.4: nothing flashes above 3 Hz — a single pulse this long
	# is at most 1 / SHINE_SEC flashes per second.
	assert_lt(1.0 / UITokens.SHINE_SEC, 3.0)


func test_typewrite_reveals_the_whole_text():
	var l := _label()
	UIMotion.typewrite(l)
	assert_almost_eq(l.visible_ratio, 0.0, 0.01)
	await wait_seconds(l.get_total_character_count() / UITokens.TYPEWRITER_CPS + 0.15)
	assert_almost_eq(l.visible_ratio, 1.0, 0.01)


func test_reduced_motion_collapses_every_helper_to_its_final_state():
	UIMotion.force_reduced_motion_for_test = true
	assert_true(UIMotion.reduced_motion())
	assert_eq(UIMotion.duration(0.45), 0.0)
	var popped := _panel()
	UIMotion.pop_in(popped)
	assert_eq(popped.scale, Vector2.ONE)
	assert_eq(popped.modulate.a, 1.0)
	var stamped := _panel()
	UIMotion.stamp(stamped)
	assert_eq(stamped.scale, Vector2.ONE)
	var ticked := _label("0")
	UIMotion.tick_number(ticked, 0, 999)
	assert_eq(ticked.text, "999", "no count-up: the final number at once")
	var typed := _label()
	UIMotion.typewrite(typed)
	assert_eq(typed.visible_ratio, 1.0, "no typewriter: the whole line at once")
	var shone := _panel()
	UIMotion.shine(shone)
	assert_eq(shone.self_modulate, Color.WHITE, "no flash at all")


# M22 6f (deliberate): SettingsManager now HAS reduce_motion (Settings >
# Display > Reduce motion) — this used to assert the field's absence. It
# defaults off, and flipping it is all it takes to still every helper.
func test_reduced_motion_follows_the_settings_toggle():
	var saved: bool = SettingsManager.reduce_motion
	assert_false(SettingsManagerClassDefaults.DEFAULT_REDUCE_MOTION, "defaults to full motion")
	SettingsManager.reduce_motion = false
	assert_false(UIMotion.reduced_motion())
	SettingsManager.reduce_motion = true
	assert_true(UIMotion.reduced_motion(), "the Settings toggle is the one query point")
	var c := _panel()
	UIMotion.pop_in(c)
	assert_eq(c.scale, Vector2.ONE, "...and it really stills the helpers")
	SettingsManager.reduce_motion = saved

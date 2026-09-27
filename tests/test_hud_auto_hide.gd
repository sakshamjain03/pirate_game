extends GutTest

# test_hud_auto_hide.gd
# M22 Phase 6e — HudAutoHide fades unwanted HUD widgets out (alpha + mouse
# passthrough, never `visible`, so layout never shifts), wakes them for a
# timed peek, and shows everything when Settings > "HUD details" = Always.

var _ah: HudAutoHide
var _w: PanelContainer
var _btn: Button
var _saved_detail := 0


func before_each():
	_saved_detail = SettingsManager.hud_detail
	SettingsManager.hud_detail = HudAutoHide.DETAIL_AUTO
	UIMotion.force_reduced_motion_for_test = true  # instant fades
	_ah = HudAutoHide.new()
	add_child_autofree(_ah)
	_w = PanelContainer.new()
	_btn = Button.new()
	_w.add_child(_btn)
	add_child_autofree(_w)


func after_each():
	SettingsManager.hud_detail = _saved_detail
	UIMotion.force_reduced_motion_for_test = false


func test_unwanted_widget_fades_out_and_stops_eating_taps():
	_ah.set_wanted(_w, false)
	assert_eq(_w.modulate.a, 0.0)
	assert_true(_w.visible, "never hidden — container layout must not shift")
	assert_eq(_btn.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a faded button must not catch taps")
	_ah.set_wanted(_w, true)
	assert_eq(_w.modulate.a, 1.0)
	assert_eq(_btn.mouse_filter, Control.MOUSE_FILTER_STOP, "the button's own filter comes back")


func test_wake_shows_for_a_while_then_lets_it_fade():
	_ah.set_wanted(_w, false)
	_ah.wake(_w, 0.15)
	assert_eq(_w.modulate.a, 1.0, "a peek shows it at once")
	assert_true(_ah.is_awake(_w))
	await wait_seconds(0.25)
	_ah.set_wanted(_w, false)
	assert_eq(_w.modulate.a, 0.0, "after the peek it fades again")


func test_always_show_setting_overrides_auto_hide():
	SettingsManager.hud_detail = HudAutoHide.DETAIL_ALWAYS
	_ah.set_wanted(_w, false)
	assert_eq(_w.modulate.a, 1.0, "HUD details = Always keeps everything on screen")

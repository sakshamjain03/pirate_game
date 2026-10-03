extends GutTest

## Touch drag-scrolling (TouchScrollDriver) and the main menu fitting a wide
## phone. Both were found on a real Galaxy A35 (2026-10-04): Settings/Credits
## could not be scrolled by finger, and the 19.5:9 screen cut the main menu's
## emblem and Quit button off.

const MainMenuScene = preload("res://scenes/ui/MainMenu.tscn")

var _scroll: ScrollContainer
var _driver: TouchScrollDriver


func _make_scroll(vertical := true) -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2.ZERO
	_scroll.size = Vector2(400, 300)
	if not vertical:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in 20:
		var b := Button.new()
		b.text = "Row %d" % i
		b.custom_minimum_size = Vector2(0, 60)
		list.add_child(b)
	_scroll.add_child(list)
	add_child_autofree(_scroll)
	TouchScrollDriver.attach(_scroll)
	for c in _scroll.get_children(true):
		if c is TouchScrollDriver:
			_driver = c


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	_driver._input(e)


func _drag(from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = to
	e.relative = to - from
	_driver._input(e)


func test_attach_is_internal_and_idempotent() -> void:
	_make_scroll()
	await wait_process_frames(2)
	assert_not_null(_driver, "driver attached")
	assert_eq(_scroll.get_child_count(), 1, "scripts that read get_child(0) still see the content")
	TouchScrollDriver.attach(_scroll)
	var drivers := _scroll.get_children(true).filter(func(c): return c is TouchScrollDriver)
	assert_eq(drivers.size(), 1, "attaching twice adds one driver")


func test_vertical_drag_over_buttons_scrolls() -> void:
	_make_scroll()
	await wait_process_frames(2)
	_touch(Vector2(200, 250), true)
	_drag(Vector2(200, 250), Vector2(200, 245))
	assert_false(_driver.is_dragging(), "under the threshold it is still a tap")
	assert_eq(_scroll.scroll_vertical, 0)
	_drag(Vector2(200, 245), Vector2(200, 200))
	_drag(Vector2(200, 200), Vector2(200, 120))
	assert_true(_driver.is_dragging(), "past the threshold the drag is taken over")
	assert_gt(_scroll.scroll_vertical, 60, "content followed the finger upward")
	_touch(Vector2(200, 120), false)
	assert_false(_driver.is_dragging())


func test_sideways_drag_on_a_vertical_list_is_left_alone() -> void:
	_make_scroll()
	await wait_process_frames(2)
	_touch(Vector2(100, 150), true)
	_drag(Vector2(100, 150), Vector2(180, 152))
	assert_false(_driver.is_dragging(), "a slider-style sideways drag is not hijacked")
	assert_eq(_scroll.scroll_vertical, 0)


func test_touch_outside_the_container_is_ignored() -> void:
	_make_scroll()
	await wait_process_frames(2)
	_touch(Vector2(800, 150), true)
	_drag(Vector2(800, 150), Vector2(800, 50))
	assert_false(_driver.is_dragging())
	assert_eq(_scroll.scroll_vertical, 0)


func test_input_manager_attaches_a_driver_to_new_scroll_containers() -> void:
	var s := ScrollContainer.new()
	add_child_autofree(s)
	await wait_process_frames(2)
	var found := s.get_children(true).any(func(c): return c is TouchScrollDriver)
	assert_true(found, "InputManager auto-attaches on node_added")


func test_main_menu_fits_a_wide_phone_canvas() -> void:
	# canvas_items + expand on a 2340x1080 phone yields ~1690x780 canvas units.
	var vp := SubViewport.new()
	vp.size = Vector2i(1690, 780)
	vp.disable_3d = true
	add_child_autofree(vp)
	var menu = MainMenuScene.instantiate()
	vp.add_child(menu)
	await wait_process_frames(4)
	var screen := Rect2(Vector2.ZERO, Vector2(vp.size))
	var checked := 0
	for b in menu.find_children("*", "Button", true, false):
		if not (b as Button).is_visible_in_tree():
			continue
		checked += 1
		var r: Rect2 = (b as Button).get_global_rect()
		assert_true(screen.encloses(r), "%s fully on screen (%s)" % [b.name, r])
	var plaque: Control = menu.get_node("Control/MainVBox/TitlePlaque")
	assert_true(screen.encloses(plaque.get_global_rect()), "title plaque (emblem) fully on screen")
	assert_gt(checked, 3, "menu buttons were checked")


func test_scrolling_off_a_slider_restores_its_value() -> void:
	# Found on device: the thumb that starts a scroll lands on a volume slider,
	# the slider jumps to that point on press, and the scroll then carried the
	# changed volume away with it.
	_make_scroll()
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 0.0
	slider.custom_minimum_size = Vector2(0, 60)
	_scroll.get_child(0).add_child(slider)
	_scroll.get_child(0).move_child(slider, 0)
	await wait_process_frames(2)
	watch_signals(slider)
	var p := slider.get_global_rect().get_center()
	_touch(p, true)
	slider.value = 0.55  # what Godot's Slider does on the emulated press
	_drag(p, p + Vector2(0, -40))
	assert_true(_driver.is_dragging(), "the gesture became a scroll")
	assert_almost_eq(slider.value, 0.0, 0.001, "the slider went back to its value before the touch")
	assert_signal_emitted_with_parameters(slider, "value_changed", [0.0], 1)


func test_sideways_drag_on_a_slider_keeps_the_new_value() -> void:
	_make_scroll()
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(0, 60)
	_scroll.get_child(0).add_child(slider)
	_scroll.get_child(0).move_child(slider, 0)
	await wait_process_frames(2)
	var p := slider.get_global_rect().get_center()
	_touch(p, true)
	slider.value = 0.4
	_drag(p, p + Vector2(60, 3))
	assert_false(_driver.is_dragging(), "a sideways drag is the slider's, not a scroll")
	assert_almost_eq(slider.value, 0.4, 0.001, "a deliberate slider change is kept")


func test_main_menu_never_shows_a_crash_dialog() -> void:
	# Owner decision 2026-10-04: an abnormal exit (Android kills a swiped-away
	# app without a clean shutdown) is recorded silently, never shown.
	var had := CrashReporter.has_pending_report
	CrashReporter.has_pending_report = true
	var vp := SubViewport.new()
	vp.size = Vector2i(1690, 780)
	vp.disable_3d = true
	add_child_autofree(vp)
	var menu = MainMenuScene.instantiate()
	vp.add_child(menu)
	await wait_process_frames(4)
	var dialogs := menu.find_children("*", "ChoiceDialog", true, false)
	assert_eq(dialogs.size(), 0, "no crash notice on the main menu")
	assert_true(CrashReporter.has_pending_report, "the local report is untouched")
	CrashReporter.has_pending_report = had

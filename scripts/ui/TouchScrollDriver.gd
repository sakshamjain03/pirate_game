class_name TouchScrollDriver extends Node

## Drag-to-scroll for a ScrollContainer on touchscreens.
##
## Godot's ScrollContainer only scrolls when a drag reaches it, and almost every
## page in this game fills its scroll area with controls that stop the drag first:
## Settings is buttons, sliders and toggles; Credits is one RichTextLabel. On a
## phone those pages simply would not move. InputManager attaches one of these as
## an internal child of every ScrollContainer that enters the tree.
##
## It watches touches in _input (before the GUI). Once a finger travels past
## DRAG_THRESHOLD along an axis the container can scroll, it takes the gesture:
## it cancels the press the control underneath received (a release far
## off-screen, so no button fires), scrolls with the finger, swallows the rest of
## the gesture, and coasts with decaying momentum after release. A drag across a
## horizontal slider (sideways intent) is left alone. Desktop mice never produce
## ScreenTouch events, so this is inert there.

## Finger travel, in canvas units, before a press becomes a scroll.
const DRAG_THRESHOLD := 12.0
## Momentum: release speeds below this stop immediately (units/second).
const MIN_FLING_SPEED := 40.0
## Fraction of momentum kept per second; lower stops sooner.
const FLING_DECAY_PER_SEC := 0.04

var _scroll: ScrollContainer
var _touch_index := -1
var _start := Vector2.ZERO
var _dragging := false
var _axis_vertical := true
var _velocity := 0.0
var _last_drag_msec := 0
## After a takeover, emulated mouse events keep arriving until the finger lifts;
## they must not reach the control the drag started on.
var _swallow_mouse := false
## Sliders jump to the touched point on PRESS, before a drag can be recognised
## as a scroll — so a thumb landing on a volume slider while scrolling Settings
## would silently change the volume. Values are recorded at touch-down and put
## back if the gesture turns out to be a scroll.
var _slider_values := {}  # Slider -> value at touch-down


func _ready() -> void:
	_scroll = get_parent() as ScrollContainer
	set_process(false)


func is_dragging() -> bool:
	return _dragging


func _can_scroll_vertical() -> bool:
	return _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
		and _scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page > 0.5


func _can_scroll_horizontal() -> bool:
	return _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
		and _scroll.get_h_scroll_bar().max_value - _scroll.get_h_scroll_bar().page > 0.5


func _input(event: InputEvent) -> void:
	if not _scroll or not _scroll.is_visible_in_tree():
		return

	if _swallow_mouse and event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		if event is InputEventMouseButton and not event.pressed:
			_swallow_mouse = false
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and _scroll.get_global_rect().has_point(event.position) \
					and (_can_scroll_vertical() or _can_scroll_horizontal()):
				_touch_index = event.index
				_start = event.position
				_dragging = false
				_velocity = 0.0
				set_process(false)
				_record_sliders_under(event.position)
		elif event.index == _touch_index:
			if _dragging:
				get_viewport().set_input_as_handled()
				# A finger that stopped before lifting should not fling.
				if Time.get_ticks_msec() - _last_drag_msec > 80:
					_velocity = 0.0
				set_process(absf(_velocity) > MIN_FLING_SPEED)
			_touch_index = -1
			_dragging = false
		return

	if event is InputEventScreenDrag and event.index == _touch_index:
		if not _dragging:
			var travel: Vector2 = event.position - _start
			var vertical_intent := absf(travel.y) >= absf(travel.x)
			if travel.length() < DRAG_THRESHOLD:
				return
			if vertical_intent and _can_scroll_vertical():
				_axis_vertical = true
			elif not vertical_intent and _can_scroll_horizontal():
				_axis_vertical = false
			else:
				# Wrong axis for this container (e.g. a slider drag): let go.
				_touch_index = -1
				return
			_dragging = true
			_cancel_press_underneath()
			_restore_sliders()
		var step: float = event.relative.y if _axis_vertical else event.relative.x
		_apply_scroll(-step)
		var now := Time.get_ticks_msec()
		var dt := maxf((now - _last_drag_msec) / 1000.0, 1.0 / 240.0)
		_last_drag_msec = now
		_velocity = lerpf(_velocity, -step / dt, 0.4)
		get_viewport().set_input_as_handled()


func _record_sliders_under(point: Vector2) -> void:
	_slider_values.clear()
	for node in _scroll.find_children("*", "Slider", true, false):
		var slider := node as Slider
		if slider.is_visible_in_tree() and slider.get_global_rect().has_point(point):
			_slider_values[slider] = slider.value


func _restore_sliders() -> void:
	for slider in _slider_values:
		if is_instance_valid(slider) and not is_equal_approx(slider.value, _slider_values[slider]):
			# A real assignment (not set_value_no_signal): listeners that already
			# saved the jumped value save the original back.
			slider.value = _slider_values[slider]
	_slider_values.clear()


func _apply_scroll(amount: float) -> void:
	if _axis_vertical:
		_scroll.scroll_vertical = int(round(_scroll.scroll_vertical + amount))
	else:
		_scroll.scroll_horizontal = int(round(_scroll.scroll_horizontal + amount))


## The control under the finger already got the (emulated) press. A release far
## outside every rect ends that press without triggering it.
func _cancel_press_underneath() -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(-100000, -100000)
	release.global_position = release.position
	get_viewport().push_input(release)
	_swallow_mouse = true


func _process(delta: float) -> void:
	_apply_scroll(_velocity * delta)
	_velocity *= pow(FLING_DECAY_PER_SEC, delta)
	if absf(_velocity) < MIN_FLING_SPEED:
		_velocity = 0.0
		set_process(false)


## Attach a driver to `scroll` once (as an internal child, so get_child(0) and
## child counts that scripts rely on are unchanged).
static func attach(scroll: ScrollContainer) -> void:
	for c in scroll.get_children(true):
		if c is TouchScrollDriver:
			return
	var driver := TouchScrollDriver.new()
	driver.name = "TouchScrollDriver"
	scroll.add_child(driver, false, Node.INTERNAL_MODE_BACK)

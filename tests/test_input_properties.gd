extends GutTest

# test_input_properties.gd
# Property-based tests for InputManager (M2 Properties 8, 14, 15, 23, 24, 25).

const InputManagerClass = preload("res://scripts/managers/InputManager.gd")

var im: Node

func before_each():
	im = InputManagerClass.new()
	add_child(im)

func after_each():
	if is_instance_valid(im):
		im.queue_free()

# Property 8: Input Response Latency
# "For any valid input command, the system shall process and respond with visible movement within 100 milliseconds."
func test_property_8_input_response_latency():
	var passed = true
	var iterations = 20
	
	for i in range(iterations):
		var start_time = Time.get_ticks_usec()
		
		var event = InputEventKey.new()
		event.physical_keycode = KEY_W
		event.pressed = true
		
		im._unhandled_input(event)
		
		var end_time = Time.get_ticks_usec()
		var elapsed_ms = (end_time - start_time) / 1000.0
		
		if elapsed_ms > 100.0:
			passed = false
			break
			
	assert_true(passed, "Input must be processed within 100ms")

# Property 14: Input Method Priority
# "For any sequence of inputs from multiple devices, the system shall process the most recently active input method."
func test_property_14_input_method_priority():
	var passed = true
	var iterations = 20
	
	for i in range(iterations):
		var events = [
			{"event": InputEventKey.new(), "expected": "keyboard"},
			{"event": InputEventJoypadButton.new(), "expected": "gamepad"},
			{"event": InputEventScreenTouch.new(), "expected": "touch"}
		]
		
		# Shuffle array manually
		for j in range(events.size() - 1, 0, -1):
			var swap_idx = randi() % (j + 1)
			var temp = events[j]
			events[j] = events[swap_idx]
			events[swap_idx] = temp
			
		for item in events:
			im._detect_input_method(item.event)
			if im.active_input_method != item.expected:
				passed = false
				
	assert_true(passed, "System must process the most recently active input method")

# Property 15: Input Sensitivity Application
# "For any change to input sensitivity settings, subsequent input processing shall immediately reflect the new sensitivity values."
func test_property_15_input_sensitivity_application():
	var passed = true
	var iterations = 20
	
	for i in range(iterations):
		var new_sens = randf_range(0.1, 5.0)
		im.set_sensitivity(new_sens)
		
		if not is_equal_approx(im.sensitivity, new_sens):
			passed = false
			break
			
	assert_true(passed, "Input sensitivity changes must apply immediately")

# Property 23: Input Gesture Mapping
# "For any valid touch gesture (swipe, tap, pinch), the system shall interpret it as the corresponding command."
func test_property_23_input_gesture_mapping():
	var passed = true
	var iterations = 20
	
	var gestures = []
	im.touch_gesture_detected.connect(func(g, d): gestures.append(g))
	
	for i in range(iterations):
		gestures.clear()
		
		var drag = InputEventScreenDrag.new()
		drag.relative = Vector2(randf(), randf())
		im._unhandled_input(drag)
		
		var tap = InputEventScreenTouch.new()
		tap.pressed = true
		tap.position = Vector2(randf(), randf())
		im._unhandled_input(tap)
		
		if gestures.size() != 2 or gestures[0] != im.GESTURE_SWIPE or gestures[1] != im.GESTURE_TAP:
			passed = false
			break
			
	assert_true(passed, "Valid touch gestures must map to corresponding commands")

# Property 24: Gamepad Button Mapping
# "For any gamepad button press, the system shall trigger the corresponding ship action according to the configured button mapping."
func test_property_24_gamepad_button_mapping():
	var passed = true
	var actions = [
		"sail_level_up", "sail_level_down", "ship_left", "ship_right",
		"dock", "interact", "pause", "camera_zoom_in",
		"camera_zoom_out", "camera_rotate_left", "camera_rotate_right"
	]
	
	for action in actions:
		var has_joypad = false
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				if event is InputEventJoypadButton or event is InputEventJoypadMotion:
					has_joypad = true
					break
		if not has_joypad:
			passed = false
			break
			
	assert_true(passed, "Gamepad buttons must be mapped to corresponding ship actions")

# Property 25: Keyboard Input Precision
# "For any keyboard input for movement, the resulting ship movement shall be precise and correspond directly to the key press duration and timing."
func test_property_25_keyboard_input_precision():
	var passed = true
	var iterations = 20
	
	for i in range(iterations):
		var fw = randf()
		var bw = randf()
		var l = randf()
		var r = randf()
		
		# Mock action presses
		Input.action_press("sail_level_up", fw)
		Input.action_press("sail_level_down", bw)
		Input.action_press("ship_left", l)
		Input.action_press("ship_right", r)
		
		var v = im.get_movement_vector()
		var expected = Vector2(r - l, fw - bw)
		
		if not v.is_equal_approx(expected):
			passed = false
			
		Input.action_release("sail_level_up")
		Input.action_release("sail_level_down")
		Input.action_release("ship_left")
		Input.action_release("ship_right")
		
		if not passed:
			break

	assert_true(passed, "Keyboard input must be precise and correspond directly to key press")

# Tilt-to-steer: _tilt_delta_to_turn() is the pure scaling/clamping/dead-zone
# logic behind phone-tilt steering — the only part of that feature testable
# without a real accelerometer.
func test_tilt_delta_to_turn_dead_zone():
	assert_eq(im._tilt_delta_to_turn(0.0), 0.0, "No tilt must produce no turn")
	assert_eq(im._tilt_delta_to_turn(0.3), 0.0, "Small jitter within the dead zone must be ignored")
	assert_eq(im._tilt_delta_to_turn(-0.3), 0.0, "Small jitter within the dead zone must be ignored (negative)")

func test_tilt_delta_to_turn_scaling():
	assert_almost_eq(im._tilt_delta_to_turn(2.0), 0.5, 0.001, "Half of full-turn accel must yield half turn")
	assert_almost_eq(im._tilt_delta_to_turn(-2.0), -0.5, 0.001, "Half of full-turn accel must yield half turn (negative)")

func test_tilt_delta_to_turn_clamping():
	assert_eq(im._tilt_delta_to_turn(4.0), 1.0, "Full-turn accel must yield a max +1.0 turn")
	assert_eq(im._tilt_delta_to_turn(40.0), 1.0, "Extreme tilt must clamp to +1.0, not overshoot")
	assert_eq(im._tilt_delta_to_turn(-40.0), -1.0, "Extreme tilt must clamp to -1.0, not overshoot")

func test_recalibrate_tilt_zeroes_baseline_against_current_reading():
	# Headless/no-sensor environments report a zero accelerometer, so the
	# baseline this captures is 0.0 here — the point of this test is only
	# that recalibrate_tilt() actually reads and stores _read_tilt_raw_accel(),
	# not any particular device-reported value.
	im.recalibrate_tilt()
	assert_eq(im._tilt_baseline_accel, im._read_tilt_raw_accel(), "Recalibrating must zero the baseline against the current tilt reading")

# Tilt now drives ship_left/ship_right through the same action-strength
# pipeline the on-screen nav buttons and a gamepad stick already use
# (_apply_turn_to_actions()), instead of a separate v.x branch — single
# source of truth for "turn" regardless of input method.
func test_apply_turn_to_actions_drives_ship_left_right():
	im._apply_turn_to_actions(0.7)
	assert_almost_eq(Input.get_action_strength("ship_right"), 0.7, 0.001, "Positive turn must drive ship_right")
	assert_eq(Input.get_action_strength("ship_left"), 0.0, "Positive turn must not also hold ship_left")

	im._apply_turn_to_actions(-0.4)
	assert_almost_eq(Input.get_action_strength("ship_left"), 0.4, 0.001, "Negative turn must drive ship_left")
	assert_eq(Input.get_action_strength("ship_right"), 0.0, "Negative turn must release ship_right")

	im._apply_turn_to_actions(0.0)
	assert_eq(Input.get_action_strength("ship_left"), 0.0, "Zero turn must release ship_left")
	assert_eq(Input.get_action_strength("ship_right"), 0.0, "Zero turn must release ship_right")

# Axis selection: which raw accelerometer component counts as left/right
# roll is device/orientation-dependent (SettingsManager.mobile_tilt_axis) —
# this is the pure mapping, independent of the actual hardware read.
func test_select_tilt_axis_all_settings():
	var raw := Vector3(1.0, 2.0, 3.0)
	assert_eq(im._select_tilt_axis(raw, 0), 2.0, "Default (0) must read .y")
	assert_eq(im._select_tilt_axis(raw, 1), -2.0, "Inverted (1) must read -.y")
	assert_eq(im._select_tilt_axis(raw, 2), 1.0, "Alt axis (2) must read .x")
	assert_eq(im._select_tilt_axis(raw, 3), -1.0, "Alt axis inverted (3) must read -.x")

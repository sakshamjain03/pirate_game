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
		"ship_forward", "ship_backward", "ship_left", "ship_right", 
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
		Input.action_press("ship_forward", fw)
		Input.action_press("ship_backward", bw)
		Input.action_press("ship_left", l)
		Input.action_press("ship_right", r)
		
		var v = im.get_movement_vector()
		var expected = Vector2(r - l, fw - bw)
		
		if not v.is_equal_approx(expected):
			passed = false
			
		Input.action_release("ship_forward")
		Input.action_release("ship_backward")
		Input.action_release("ship_left")
		Input.action_release("ship_right")
		
		if not passed:
			break
			
	assert_true(passed, "Keyboard input must be precise and correspond directly to key press")

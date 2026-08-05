extends Node

signal input_action_triggered(action: String, strength: float)
signal touch_gesture_detected(gesture: String, data: Dictionary)

# Movement
const ACTION_SHIP_FORWARD = "ship_forward"
const ACTION_SHIP_BACKWARD = "ship_backward"
const ACTION_SHIP_LEFT = "ship_left"
const ACTION_SHIP_RIGHT = "ship_right"

# Camera
const ACTION_CAMERA_ZOOM_IN = "camera_zoom_in"
const ACTION_CAMERA_ZOOM_OUT = "camera_zoom_out"
const ACTION_CAMERA_ROTATE_LEFT = "camera_rotate_left"
const ACTION_CAMERA_ROTATE_RIGHT = "camera_rotate_right"

# Interactions
const ACTION_DOCK = "dock"
const ACTION_INTERACT = "interact"
const ACTION_PAUSE = "pause"

# Touch gestures (mobile)
const GESTURE_SWIPE = "swipe"
const GESTURE_TAP = "tap"
const GESTURE_PINCH = "pinch"

var sensitivity: float = 1.0
var active_input_method: String = "keyboard" # keyboard, gamepad, touch

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_DOCK):
		emit_signal("input_action_triggered", ACTION_DOCK, 1.0)
	elif event.is_action_pressed(ACTION_INTERACT):
		emit_signal("input_action_triggered", ACTION_INTERACT, 1.0)
	elif event.is_action_pressed(ACTION_PAUSE):
		emit_signal("input_action_triggered", ACTION_PAUSE, 1.0)
	elif event.is_action_pressed(ACTION_CAMERA_ZOOM_IN):
		emit_signal("input_action_triggered", ACTION_CAMERA_ZOOM_IN, 1.0)
	elif event.is_action_pressed(ACTION_CAMERA_ZOOM_OUT):
		emit_signal("input_action_triggered", ACTION_CAMERA_ZOOM_OUT, 1.0)
		
	_detect_input_method(event)
	
	if active_input_method == "touch":
		# Simplified touch parsing for gesture simulation
		if event is InputEventScreenDrag:
			emit_signal("touch_gesture_detected", GESTURE_SWIPE, {"relative": event.relative})
		elif event is InputEventScreenTouch and event.pressed:
			emit_signal("touch_gesture_detected", GESTURE_TAP, {"position": event.position})
			
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# Emulate camera rotation with right click drag
		emit_signal("input_action_triggered", ACTION_CAMERA_ROTATE_RIGHT, event.relative.x * sensitivity * 0.1)
		# We can use the same event for Y axis as rotate_down/up if needed, but design only specifies left/right

func _detect_input_method(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouse:
		active_input_method = "keyboard"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		active_input_method = "gamepad"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		active_input_method = "touch"

func get_movement_vector() -> Vector2:
	var v = Vector2.ZERO
	v.y = Input.get_action_strength(ACTION_SHIP_FORWARD) - Input.get_action_strength(ACTION_SHIP_BACKWARD)
	v.x = Input.get_action_strength(ACTION_SHIP_RIGHT) - Input.get_action_strength(ACTION_SHIP_LEFT)
	return v

func set_sensitivity(val: float) -> void:
	sensitivity = val

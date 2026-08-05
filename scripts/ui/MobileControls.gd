extends CanvasLayer

## Purpose: Provides on-screen virtual buttons for mobile devices.
## Responsibilities: Injects action events into the Input map when virtual buttons are pressed.

@onready var btn_forward = %BtnForward
@onready var btn_left = %BtnLeft
@onready var btn_right = %BtnRight
@onready var btn_fire_port = %BtnFirePort
@onready var btn_fire_star = %BtnFireStar

func _ready() -> void:
	# Hide on desktop platforms if desired, but for now we'll show it or let it be toggled
	if OS.has_feature("pc"):
		# Could hide here, but let's keep it visible for testing
		pass

	_setup_button(btn_forward, "sail_forward")
	_setup_button(btn_left, "steer_left")
	_setup_button(btn_right, "steer_right")
	_setup_button(btn_fire_port, "fire_port")
	_setup_button(btn_fire_star, "fire_starboard")

func _setup_button(btn: Button, action_name: String) -> void:
	btn.button_down.connect(func(): _inject_action(action_name, true))
	btn.button_up.connect(func(): _inject_action(action_name, false))

func _inject_action(action_name: String, pressed: bool) -> void:
	var ev = InputEventAction.new()
	ev.action = action_name
	ev.pressed = pressed
	Input.parse_input_event(ev)

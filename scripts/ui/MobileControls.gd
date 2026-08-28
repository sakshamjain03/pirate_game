extends CanvasLayer

## Purpose: Provides on-screen virtual buttons for mobile devices.
## Responsibilities: Injects action events into the Input map when virtual buttons are pressed.

@onready var btn_forward = %BtnForward
@onready var btn_backward = %BtnBackward
@onready var btn_left = %BtnLeft
@onready var btn_right = %BtnRight
@onready var btn_fire_port = %BtnFirePort
@onready var btn_fire_star = %BtnFireStar
@onready var btn_dock = %BtnDock
@onready var btn_pause = %BtnPause
@onready var btn_captain_ability = %BtnCaptainAbility
@onready var btn_special_broadside = %BtnSpecialBroadside

func _ready() -> void:
	# These are on-screen touch buttons — on desktop they just sit on top of
	# the HUD (overlapping HealthBarContainer) and are unthemed, since this
	# is a CanvasLayer and WorldHUD._apply_theme() only themes Control
	# children.
	if OS.has_feature("pc"):
		visible = false
		return

	_setup_button(btn_forward, "ship_forward")
	_setup_button(btn_backward, "ship_backward")
	_setup_button(btn_left, "ship_left")
	_setup_button(btn_right, "ship_right")
	_setup_button(btn_fire_port, "fire_port")
	_setup_button(btn_fire_star, "fire_starboard")
	_setup_button(btn_dock, "dock")
	_setup_button(btn_pause, "pause")
	_setup_button(btn_captain_ability, "captain_ability")
	_setup_button(btn_special_broadside, "special_broadside")

func _setup_button(btn: Button, action_name: String) -> void:
	btn.button_down.connect(func(): _inject_action(action_name, true))
	btn.button_up.connect(func(): _inject_action(action_name, false))

func _inject_action(action_name: String, pressed: bool) -> void:
	var ev = InputEventAction.new()
	ev.action = action_name
	ev.pressed = pressed
	Input.parse_input_event(ev)

extends CanvasLayer

## Purpose: Provides on-screen virtual buttons for mobile devices.
## Responsibilities: Injects action events into the Input map when virtual buttons are pressed.

## Icons for the sail/anchor buttons, loaded directly from their .svg source
## at runtime instead of via a scene ext_resource. They were added in the same
## change as this script, so no editor session has generated their .import
## cache yet — ResourceLoader.load() fails on an un-imported file, while
## Image.load_svg_from_string() rasterizes raw SVG text with no import step,
## the same way it will forever (this isn't a workaround to later remove).
## Every other MobileControls icon still goes through the normal import path.
const _CUSTOM_ICON_PATHS := {
	"sail_up": "res://assets/icons/controls/sail_level_up.svg",
	"sail_down": "res://assets/icons/controls/sail_level_down.svg",
	"set_sail": "res://assets/icons/controls/action_set_sail.svg",
	"anchor": "res://assets/icons/controls/action_anchor.svg",
}

@onready var btn_sail_up = %BtnSailUp
@onready var btn_sail_down = %BtnSailDown
@onready var btn_left = %BtnLeft
@onready var btn_right = %BtnRight
@onready var btn_fire_port = %BtnFirePort
@onready var btn_fire_star = %BtnFireStar
@onready var btn_dock = %BtnDock
@onready var btn_pause = %BtnPause
@onready var btn_captain_ability = %BtnCaptainAbility
@onready var btn_special_broadside = %BtnSpecialBroadside
@onready var btn_set_sail = %BtnSetSail
@onready var btn_anchor = %BtnAnchor

func _ready() -> void:
	# M15.5 — this CanvasLayer's own children never picked up
	# WorldHUD._apply_theme()'s theme (that loop only themes Control
	# children, and a CanvasLayer isn't one), so every button here rendered
	# as an unthemed default Godot button. Applied directly since a
	# CanvasLayer can't hold/propagate a Theme itself the way a Control does.
	var theme := PirateThemeBuilder.build()
	for child in get_children():
		if child is Control:
			child.theme = theme
	PirateThemeBuilder.apply_button_juice(self)

	# These are on-screen touch buttons — on desktop they just sit on top of
	# the HUD (overlapping HealthBarContainer).
	if OS.has_feature("pc"):
		visible = false
		return

	btn_sail_up.icon = _load_svg_icon(_CUSTOM_ICON_PATHS["sail_up"])
	btn_sail_down.icon = _load_svg_icon(_CUSTOM_ICON_PATHS["sail_down"])
	btn_set_sail.icon = _load_svg_icon(_CUSTOM_ICON_PATHS["set_sail"])
	btn_anchor.icon = _load_svg_icon(_CUSTOM_ICON_PATHS["anchor"])

	_setup_button(btn_sail_up, "sail_level_up")
	_setup_button(btn_sail_down, "sail_level_down")
	_setup_button(btn_left, "ship_left")
	_setup_button(btn_right, "ship_right")
	_setup_button(btn_fire_port, "fire_port")
	_setup_button(btn_fire_star, "fire_starboard")
	_setup_button(btn_dock, "dock")
	_setup_button(btn_pause, "pause")
	_setup_button(btn_captain_ability, "captain_ability")
	_setup_button(btn_special_broadside, "special_broadside")
	_setup_button(btn_set_sail, "set_sail")
	_setup_button(btn_anchor, "anchor")

func _load_svg_icon(path: String) -> Texture2D:
	var svg_text := FileAccess.get_file_as_string(path)
	if svg_text.is_empty():
		push_warning("MobileControls: could not read icon at %s" % path)
		return null
	var img := Image.new()
	if img.load_svg_from_string(svg_text) != OK:
		push_warning("MobileControls: could not rasterize icon at %s" % path)
		return null
	return ImageTexture.create_from_image(img)

func _setup_button(btn: Button, action_name: String) -> void:
	btn.button_down.connect(func(): _inject_action(action_name, true))
	btn.button_up.connect(func(): _inject_action(action_name, false))

func _inject_action(action_name: String, pressed: bool) -> void:
	var ev = InputEventAction.new()
	ev.action = action_name
	ev.pressed = pressed
	Input.parse_input_event(ev)

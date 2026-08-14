extends CanvasLayer
class_name SettingsMenu

## SettingsMenu.gd
## Handles the settings menu UI interactions and updates the SettingsManager.
##
## Responsibilities:
## - Populate controls from SettingsManager on ready
## - Update SettingsManager properties when controls change
## - Apply audio settings via AudioManager.set_bus_volume() for volume sliders
## - Apply display settings via SettingsManager.apply_display_settings() for display controls
## - Save settings via SettingsManager.save_settings() after each change
## - Navigate back via SceneManager.go_back() on Back button press or ui_cancel
## - Set initial focus on MasterSlider for keyboard/gamepad navigation
##
## Dependencies:
## - SettingsManager (autoload singleton for settings persistence and application)
## - AudioManager (autoload singleton for audio bus volume control)
## - SceneManager (for scene navigation with go_back())
##
## Limitations:
## - Only works with three audio buses: Master, Music, SFX (hardcoded in signal handlers)
## - Resolution strings must match exactly those in the OptionButton items
## - Control node structure must match the expected scene hierarchy
##
## TODOs:
## - Add input validation for slider values before applying
## - Implement debounce for rapid setting changes (e.g., fast slider movement)
## - Add visual feedback for successful settings save

@onready var master_slider: HSlider = $Control/TabContainer/General/GridContainer/MasterSlider
@onready var music_slider: HSlider = $Control/TabContainer/General/GridContainer/MusicSlider
@onready var sfx_slider: HSlider = $Control/TabContainer/General/GridContainer/SFXSlider
@onready var fullscreen_check: CheckButton = $Control/TabContainer/General/GridContainer/FullscreenCheckButton
@onready var resolution_option: OptionButton = $Control/TabContainer/General/GridContainer/ResolutionOptionButton
@onready var vsync_check: CheckButton = $Control/TabContainer/General/GridContainer/VSyncCheckButton
@onready var back_button: Button = $Control/BackButton
@onready var replay_tutorial_button: Button = $Control/TabContainer/General/GridContainer/ReplayTutorialButton

@onready var controls_vbox: VBoxContainer = $Control/TabContainer/Controls/ScrollContainer/ControlsVBox

var _awaiting_rebind: String = ""

var settings_manager: Node = SettingsManager
var audio_manager: Node = AudioManager

func _ready() -> void:
	# Populate controls from SettingsManager
	master_slider.value = settings_manager.master_volume
	music_slider.value = settings_manager.music_volume
	sfx_slider.value = settings_manager.sfx_volume
	
	fullscreen_check.button_pressed = settings_manager.fullscreen
	vsync_check.button_pressed = settings_manager.vsync
	
	for i in range(resolution_option.item_count):
		if resolution_option.get_item_text(i) == settings_manager.resolution:
			resolution_option.select(i)
			break
	
	# Connect signals
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)
	
	back_button.pressed.connect(_on_back_pressed)
	replay_tutorial_button.pressed.connect(_on_replay_tutorial_pressed)

	# Set focus on first slider for keyboard/gamepad navigation
	master_slider.grab_focus()
	_populate_controls()

func _populate_controls() -> void:
	for child in controls_vbox.get_children():
		child.queue_free()
		
	var actions = ["ship_forward", "ship_backward", "ship_left", "ship_right", "camera_zoom_in", "camera_zoom_out", "camera_rotate_left", "camera_rotate_right", "dock", "interact", "pause"]
	for action in actions:
		if InputMap.has_action(action):
			var hbox = HBoxContainer.new()
			var label = Label.new()
			label.text = action.capitalize().replace("_", " ")
			label.custom_minimum_size.x = 200
			hbox.add_child(label)
			
			var btn = Button.new()
			var events = InputMap.action_get_events(action)
			if events.size() > 0 and events[0] is InputEventKey:
				btn.text = OS.get_keycode_string(events[0].keycode)
			else:
				btn.text = "Unbound"
			
			btn.pressed.connect(func(): _on_rebind_pressed(action, btn))
			hbox.add_child(btn)
			controls_vbox.add_child(hbox)
			
	var reset_btn = Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.pressed.connect(func():
		var im = get_tree().root.get_node_or_null("InputManager")
		if im and im.has_method("reset_to_defaults"):
			im.reset_to_defaults()
			_populate_controls()
	)
	controls_vbox.add_child(reset_btn)

func _on_rebind_pressed(action: String, btn: Button) -> void:
	_awaiting_rebind = action
	btn.text = "Press any key..."

func _input(event: InputEvent) -> void:
	if _awaiting_rebind != "" and event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		var im = get_tree().root.get_node_or_null("InputManager")
		if im and im.has_method("rebind_action"):
			im.rebind_action(_awaiting_rebind, event)
		_awaiting_rebind = ""
		_populate_controls()

func _on_master_slider_changed(value: float) -> void:
	settings_manager.master_volume = value
	audio_manager.set_bus_volume("Master", value)
	settings_manager.save_settings()

func _on_music_slider_changed(value: float) -> void:
	settings_manager.music_volume = value
	audio_manager.set_bus_volume("Music", value)
	settings_manager.save_settings()

func _on_sfx_slider_changed(value: float) -> void:
	settings_manager.sfx_volume = value
	audio_manager.set_bus_volume("SFX", value)
	settings_manager.save_settings()

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	settings_manager.fullscreen = button_pressed
	settings_manager.save_settings()
	settings_manager.apply_display_settings()

func _on_vsync_toggled(button_pressed: bool) -> void:
	settings_manager.vsync = button_pressed
	settings_manager.save_settings()
	settings_manager.apply_display_settings()

func _on_resolution_selected(index: int) -> void:
	settings_manager.resolution = resolution_option.get_item_text(index)
	settings_manager.save_settings()
	settings_manager.apply_display_settings()

func _on_back_pressed() -> void:
	SceneManager.go_back()

func _on_replay_tutorial_pressed() -> void:
	# Non-destructive: World.gd still calls SaveManager.load_game() on load,
	# so the player's existing save is untouched — only the tutorial re-arms.
	TutorialManager.reset_and_replay()
	SceneManager.change_scene_with_fade("res://scenes/world/World.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.go_back()

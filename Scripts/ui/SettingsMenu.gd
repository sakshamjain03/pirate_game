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

@onready var master_slider: HSlider = $Control/GridContainer/MasterSlider
@onready var music_slider: HSlider = $Control/GridContainer/MusicSlider
@onready var sfx_slider: HSlider = $Control/GridContainer/SFXSlider
@onready var fullscreen_check: CheckButton = $Control/GridContainer/FullscreenCheckButton
@onready var resolution_option: OptionButton = $Control/GridContainer/ResolutionOptionButton
@onready var vsync_check: CheckButton = $Control/GridContainer/VSyncCheckButton
@onready var back_button: Button = $Control/BackButton

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
	
	# Set focus on first slider for keyboard/gamepad navigation
	master_slider.grab_focus()

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.go_back()

extends Node

# SettingsManager.gd
# Manages game settings persistence and application for audio and display configuration.
#
# Responsibilities:
# - Persist settings to user://settings.cfg using ConfigFile API
# - Load and apply default values when no saved file exists
# - Apply display settings (fullscreen, resolution, vsync) via DisplayServer
# - Apply audio settings (master, music, SFX volumes) via AudioManager
# - Emit settings_changed signal after successful save
#
# Dependencies:
# - Godot Engine (ConfigFile, DisplayServer, AudioServer)
# - AudioManager (for audio volume control)
#
# Limitations:
# - Resolution strings must follow WxH format (e.g., "1920x1080")
# - Only works with three audio buses: Master, Music, SFX
# - Settings are loaded on first call to load_settings() or save_settings()
#
# TODOs:
# - Add validation for resolution values against DisplayServer.get_display_count()
# - Implement settings change notification to registered listeners

signal settings_changed

# Default values
const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_MUSIC_VOLUME: float = 0.8
const DEFAULT_SFX_VOLUME: float = 1.0
const DEFAULT_FULLSCREEN: bool = false
const DEFAULT_RESOLUTION: String = "1920x1080"
const DEFAULT_VSYNC: bool = true
## Input feel (M2 Task 6.3). Sensitivity scales `InputManager`'s look/rotate
## input; dead zone is applied to every analogue action so a drifting stick
## doesn't creep the ship.
const DEFAULT_INPUT_SENSITIVITY: float = 1.0
const DEFAULT_INPUT_DEAD_ZONE: float = 0.2
## Graphics quality (M2 Task 12.1). 0: Low, 1: Medium, 2: High — matches
## OceanController.quality_level's existing ladder.
const DEFAULT_GRAPHICS_QUALITY: int = 1

## The gameplay actions the player may rebind. Single source of truth — this
## list was previously duplicated verbatim in both save_settings() and
## load_settings(), so the two could drift out of sync silently.
const REBINDABLE_ACTIONS: Array[String] = [
	"ship_forward", "ship_backward", "ship_left", "ship_right",
	"camera_zoom_in", "camera_zoom_out", "camera_rotate_left", "camera_rotate_right",
	"dock", "interact", "pause",
	"special_broadside", "captain_ability",
]

# Typed member variables
var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var fullscreen: bool = DEFAULT_FULLSCREEN
var resolution: String = DEFAULT_RESOLUTION
var vsync: bool = DEFAULT_VSYNC
var input_sensitivity: float = DEFAULT_INPUT_SENSITIVITY
var input_dead_zone: float = DEFAULT_INPUT_DEAD_ZONE
var graphics_quality: int = DEFAULT_GRAPHICS_QUALITY

var _settings_path: String = "user://settings.cfg"

## Whether load_settings() should also push saved key bindings into the global
## InputMap.
##
## This is opt-in because InputMap is process-global while a SettingsManager is
## an ordinary object: `tests/test_settings_manager.gd` constructs 50+ throwaway
## managers per property test and round-trips each one, and having every load
## erase and re-add key events for 11 actions turned a 3-second test file into a
## multi-minute one (and left the InputMap progressively mangled for every test
## that ran afterwards). The autoload sets this true in _ready(); transient
## instances leave it false and touch only their own fields.
var apply_input_bindings_on_load: bool = false
var audio_manager: Node = null


func _ready() -> void:
	## Only the real autoload singleton owns the global InputMap. Transient
	## instances constructed by tests enter the tree too, but they are not the
	## autoload, so they must not rewrite process-global input state.
	if get_tree() and get_tree().root.get_node_or_null("SettingsManager") == self:
		apply_input_bindings_on_load = true


func load_input_bindings(config: ConfigFile) -> void:
	## Pushes saved key bindings into the global InputMap.
	##
	## Every call is guarded on has_action() — save_settings() already had that
	## guard and load did not, so this could erase events from actions that were
	## never bound in the first place. An empty stored array is treated as
	## "nothing authored" rather than "unbind this action", which would otherwise
	## leave the player unable to steer after a corrupt or partial save.
	if not config.has_section("input"):
		return

	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		if not config.has_section_key("input", action):
			continue
		var keycodes = config.get_value("input", action, [])
		if typeof(keycodes) != TYPE_ARRAY or keycodes.is_empty():
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
		for code in keycodes:
			var new_event := InputEventKey.new()
			new_event.keycode = int(code)
			InputMap.action_add_event(action, new_event)


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(_settings_path)
	
	if err != OK:
		# No saved file exists - apply defaults
		_apply_defaults()
		apply_display_settings()
		apply_audio_settings()
		return
	
	# Read audio settings from "audio" section
	var _master = config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)
	master_volume = _master if typeof(_master) in [TYPE_FLOAT, TYPE_INT] else DEFAULT_MASTER_VOLUME
	
	var _music = config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
	music_volume = _music if typeof(_music) in [TYPE_FLOAT, TYPE_INT] else DEFAULT_MUSIC_VOLUME
	
	var _sfx = config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
	sfx_volume = _sfx if typeof(_sfx) in [TYPE_FLOAT, TYPE_INT] else DEFAULT_SFX_VOLUME
	
	# Read display settings from "display" section
	var _fullscreen = config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN)
	fullscreen = _fullscreen if typeof(_fullscreen) == TYPE_BOOL else DEFAULT_FULLSCREEN
	
	var _resolution = config.get_value("display", "resolution", DEFAULT_RESOLUTION)
	resolution = _resolution if typeof(_resolution) == TYPE_STRING else DEFAULT_RESOLUTION
	
	var _vsync = config.get_value("display", "vsync", DEFAULT_VSYNC)
	vsync = _vsync if typeof(_vsync) == TYPE_BOOL else DEFAULT_VSYNC

	var _sens = config.get_value("input", "sensitivity", DEFAULT_INPUT_SENSITIVITY)
	input_sensitivity = _sens if typeof(_sens) in [TYPE_FLOAT, TYPE_INT] else DEFAULT_INPUT_SENSITIVITY
	var _dz = config.get_value("input", "dead_zone", DEFAULT_INPUT_DEAD_ZONE)
	input_dead_zone = _dz if typeof(_dz) in [TYPE_FLOAT, TYPE_INT] else DEFAULT_INPUT_DEAD_ZONE

	var _quality = config.get_value("display", "quality", DEFAULT_GRAPHICS_QUALITY)
	graphics_quality = _quality if typeof(_quality) == TYPE_INT else DEFAULT_GRAPHICS_QUALITY

	if apply_input_bindings_on_load:
		load_input_bindings(config)

	# Apply loaded settings
	apply_display_settings()
	apply_audio_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	
	# Write audio settings under "audio" section
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	
	# Write display settings under "display" section
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "quality", graphics_quality)

	config.set_value("input", "sensitivity", input_sensitivity)
	config.set_value("input", "dead_zone", input_dead_zone)

	# Write input bindings under the "input" section. Only actions that actually
	# carry key events are written — persisting an empty array would read back
	# on the next load as "this action is unbound".
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var keycodes := []
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				keycodes.append(e.keycode)
		if not keycodes.is_empty():
			config.set_value("input", action, keycodes)

	# Save to disk
	var err := config.save(_settings_path)
	if err != OK:
		push_error("SettingsManager: Failed to save settings: %s" % error_string(err))
		return
	
	# Emit signal on success
	emit_signal("settings_changed")


func apply_display_settings() -> void:
	# Validate resolution format (WxH)
	var resolution_pattern := RegEx.new()
	resolution_pattern.compile("^[0-9]+x[0-9]+$")
	
	if not resolution_pattern.search(resolution):
		push_error("SettingsManager: Invalid resolution format: %s (expected WxH)" % resolution)
		return
	
	# Parse resolution
	var parts: PackedStringArray = resolution.split("x")
	if parts.size() != 2:
		push_error("SettingsManager: Failed to parse resolution: %s" % resolution)
		return
	
	var width: int = int(parts[0])
	var height: int = int(parts[1])
	
	# Apply display settings
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2(width, height))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func apply_audio_settings() -> void:
	var am = audio_manager
	if am == null:
		if is_inside_tree() and get_tree().root.has_node("AudioManager"):
			am = get_tree().root.get_node("AudioManager")
		elif Engine.has_singleton("AudioManager"):
			am = Engine.get_singleton("AudioManager")
		else:
			push_error("SettingsManager: AudioManager not available")
			return
	
	# Apply audio bus volumes
	am.set_bus_volume("Master", master_volume)
	am.set_bus_volume("Music", music_volume)
	am.set_bus_volume("SFX", sfx_volume)


func _apply_defaults() -> void:
	# Apply default values without saving
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	fullscreen = DEFAULT_FULLSCREEN
	resolution = DEFAULT_RESOLUTION
	vsync = DEFAULT_VSYNC
	input_sensitivity = DEFAULT_INPUT_SENSITIVITY
	input_dead_zone = DEFAULT_INPUT_DEAD_ZONE
	graphics_quality = DEFAULT_GRAPHICS_QUALITY

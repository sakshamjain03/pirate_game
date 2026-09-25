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
const DEFAULT_MOBILE_LEFT_HANDED: bool = false
const DEFAULT_HAPTICS_ENABLED: bool = true
## Auto-fire remains the phone default; this opt-in restores the two manual
## broadside buttons for players who explicitly prefer direct firing.
const DEFAULT_MOBILE_ADVANCED_COMBAT_CONTROLS: bool = false
## On-screen left/right buttons remain the phone default; this opt-in hides
## them and steers from phone tilt instead (InputManager.get_movement_vector()).
const DEFAULT_MOBILE_TILT_STEERING_ENABLED: bool = false
## Which raw accelerometer component InputManager._select_tilt_axis() reads
## as left/right roll — device/orientation-dependent and unverifiable from
## this environment (no accelerometer here), so it's a player-facing escape
## hatch rather than a second hardcoded guess: 0=y, 1=-y, 2=x, 3=-x (see
## InputManager.TiltAxis). 1 (-y) confirmed correct on a real device
## 2026-09-24 — plain accelerometer.y (0) turned the ship the wrong way.
const DEFAULT_MOBILE_TILT_AXIS: int = 1
## Player-selectable body/UI font (2026-09-24), read by PirateThemeBuilder.build().
## 0: Default (Cinzel — the readable choice dense HUD text needed), 1: Pirate
## (PirataOne, the original blackletter-style face), 2: Times New Roman (an
## OS-resolved SystemFont, not a bundled asset).
const DEFAULT_UI_FONT: int = 0
## M23 Requirement 6 — player-selected enemy difficulty. Index into
## AI_DIFFICULTY_PATHS: 0 Relaxed, 1 Normal (default), 2 Hard (the authored
## enemy stats unscaled), 3 Brutal. Applied at use time by ShipCombat/EnemyAI
## via AIDifficultyData.for_ship(), so a change takes effect mid-session.
const DEFAULT_AI_DIFFICULTY: int = 1
const AI_DIFFICULTY_PATHS: Array[String] = [
	"res://resources/combat/ai_difficulty/Relaxed.tres",
	"res://resources/combat/ai_difficulty/Normal.tres",
	"res://resources/combat/ai_difficulty/Hard.tres",
	"res://resources/combat/ai_difficulty/Brutal.tres",
]
## M22 (2026-09-25) — mobile_control_overrides' stored "position" deltas are
## in MobileLayoutManager.REFERENCE_LANDSCAPE units (see that var's own
## comment), which moved from a 1080-tall reference to a 780-tall one when
## the project base changed (design.md §3/§9). A config file with no
## "hud_layout_version" key predates that change (version 1); load_settings()
## rescales its stored positions by HUD_LAYOUT_MIGRATION_RATIO once, in
## memory, so a returning player's saved HUD customization still lands in
## the same real screen location instead of drifting — never silently reset
## (CLAUDE.md fragile-area rule). HUD_LAYOUT_VERSION_CURRENT is the version
## this build understands; a fresh install with no config file at all starts
## already at the current version (nothing to migrate).
const HUD_LAYOUT_VERSION_CURRENT: int = 2
const HUD_LAYOUT_MIGRATION_RATIO: float = 780.0 / 1080.0

## The gameplay actions the player may rebind. Single source of truth — this
## list was previously duplicated verbatim in both save_settings() and
## load_settings(), so the two could drift out of sync silently.
const REBINDABLE_ACTIONS: Array[String] = [
	"sail_level_up", "sail_level_down", "ship_left", "ship_right",
	"set_sail", "anchor",
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
var mobile_left_handed: bool = DEFAULT_MOBILE_LEFT_HANDED
var haptics_enabled: bool = DEFAULT_HAPTICS_ENABLED
var mobile_advanced_combat_controls: bool = DEFAULT_MOBILE_ADVANCED_COMBAT_CONTROLS
var mobile_tilt_steering_enabled: bool = DEFAULT_MOBILE_TILT_STEERING_ENABLED
var mobile_tilt_axis: int = DEFAULT_MOBILE_TILT_AXIS
var ui_font: int = DEFAULT_UI_FONT
var ai_difficulty: int = DEFAULT_AI_DIFFICULTY:
	set(value):
		ai_difficulty = clampi(value, 0, AI_DIFFICULTY_PATHS.size() - 1)
		_ai_difficulty_profile = null
var _ai_difficulty_profile: AIDifficultyData = null
## Per-control HUD layout customization (drag to move/resize on mobile).
## Keyed by control id (e.g. "movement", "top_bar"); each entry is
## {"position": Vector2, "scale_mult": float}, where "position" is a delta
## from the computed default in reference-scale units — see
## MobileLayoutManager.apply_control_override(). An empty dict is both the
## default and the fully-reset state.
var mobile_control_overrides: Dictionary = {}
## Not written to save_settings() directly by name here — see save_settings(),
## which always writes HUD_LAYOUT_VERSION_CURRENT (this var only matters
## in-memory, between a load_settings() migration and the next save).
var hud_layout_version: int = HUD_LAYOUT_VERSION_CURRENT

## Transient handoff flag, not persisted (mirrors SaveManager._pending_offline_ticks'
## pattern) — "Customize HUD Layout" is only meaningful with a live HUD on
## screen, but SettingsMenu is always reached via a full scene swap (never an
## overlay on World.tscn), so there is no live HUD node to open the editor on
## directly. Set here, then SceneManager.go_back() returns to World.tscn,
## which reloads and calls SaveManager.load_game() as it always does; WorldHUD.
## _ready() checks and consumes this flag the same way it already checks
## SaveManager._pending_offline_ticks after a fresh load.
var pending_hud_customize_request: bool = false

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
	var _left_handed = config.get_value("mobile", "left_handed", DEFAULT_MOBILE_LEFT_HANDED)
	mobile_left_handed = _left_handed if typeof(_left_handed) == TYPE_BOOL else DEFAULT_MOBILE_LEFT_HANDED
	var _haptics = config.get_value("mobile", "haptics_enabled", DEFAULT_HAPTICS_ENABLED)
	haptics_enabled = _haptics if typeof(_haptics) == TYPE_BOOL else DEFAULT_HAPTICS_ENABLED
	var _advanced_combat = config.get_value("mobile", "advanced_combat_controls", DEFAULT_MOBILE_ADVANCED_COMBAT_CONTROLS)
	mobile_advanced_combat_controls = _advanced_combat if typeof(_advanced_combat) == TYPE_BOOL else DEFAULT_MOBILE_ADVANCED_COMBAT_CONTROLS
	var _tilt_steering = config.get_value("mobile", "tilt_steering_enabled", DEFAULT_MOBILE_TILT_STEERING_ENABLED)
	mobile_tilt_steering_enabled = _tilt_steering if typeof(_tilt_steering) == TYPE_BOOL else DEFAULT_MOBILE_TILT_STEERING_ENABLED
	var _tilt_axis = config.get_value("mobile", "tilt_axis", DEFAULT_MOBILE_TILT_AXIS)
	mobile_tilt_axis = _tilt_axis if typeof(_tilt_axis) == TYPE_INT else DEFAULT_MOBILE_TILT_AXIS
	var _overrides = config.get_value("mobile", "control_overrides", {})
	mobile_control_overrides = _overrides if typeof(_overrides) == TYPE_DICTIONARY else {}
	# A config file with no "hud_layout_version" key predates M22's base-
	# resolution change — default 1 (not HUD_LAYOUT_VERSION_CURRENT) so its
	# absence is correctly read as "needs migrating," not "already current."
	var _hud_layout_version = config.get_value("mobile", "hud_layout_version", 1)
	hud_layout_version = _hud_layout_version if typeof(_hud_layout_version) == TYPE_INT else 1
	_migrate_hud_layout_if_needed()
	var _ui_font = config.get_value("display", "ui_font", DEFAULT_UI_FONT)
	ui_font = _ui_font if typeof(_ui_font) == TYPE_INT else DEFAULT_UI_FONT
	var _ai_difficulty = config.get_value("gameplay", "ai_difficulty", DEFAULT_AI_DIFFICULTY)
	ai_difficulty = _ai_difficulty if typeof(_ai_difficulty) == TYPE_INT else DEFAULT_AI_DIFFICULTY

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
	config.set_value("display", "ui_font", ui_font)
	config.set_value("gameplay", "ai_difficulty", ai_difficulty)

	config.set_value("input", "sensitivity", input_sensitivity)
	config.set_value("input", "dead_zone", input_dead_zone)
	config.set_value("mobile", "left_handed", mobile_left_handed)
	config.set_value("mobile", "haptics_enabled", haptics_enabled)
	config.set_value("mobile", "advanced_combat_controls", mobile_advanced_combat_controls)
	config.set_value("mobile", "tilt_steering_enabled", mobile_tilt_steering_enabled)
	config.set_value("mobile", "tilt_axis", mobile_tilt_axis)
	config.set_value("mobile", "control_overrides", mobile_control_overrides)
	config.set_value("mobile", "hud_layout_version", HUD_LAYOUT_VERSION_CURRENT)

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


## M22 Phase 1.6 (design.md §9) — rescales mobile_control_overrides'
## "position" deltas by HUD_LAYOUT_MIGRATION_RATIO in memory when loading a
## pre-M22 config file, then marks the in-memory version current so a
## repeat call this same session is a no-op. Does not touch "scale_mult" —
## that is already a dimensionless ratio, not a distance, so it needs no
## rescaling. Idempotent and safe to call even with an empty overrides dict.
func _migrate_hud_layout_if_needed() -> void:
	if hud_layout_version >= HUD_LAYOUT_VERSION_CURRENT:
		return
	var migrated := {}
	for control_id in mobile_control_overrides:
		var entry = mobile_control_overrides[control_id]
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("position"):
			migrated[control_id] = entry
			continue
		var new_entry: Dictionary = entry.duplicate()
		new_entry["position"] = Vector2(entry["position"]) * HUD_LAYOUT_MIGRATION_RATIO
		migrated[control_id] = new_entry
	mobile_control_overrides = migrated
	if not mobile_control_overrides.is_empty():
		print("[SettingsManager] Migrated %d HUD layout override(s) from version %d to %d (x%.4f)" %
			[mobile_control_overrides.size(), hud_layout_version, HUD_LAYOUT_VERSION_CURRENT, HUD_LAYOUT_MIGRATION_RATIO])
	hud_layout_version = HUD_LAYOUT_VERSION_CURRENT


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
	mobile_left_handed = DEFAULT_MOBILE_LEFT_HANDED
	haptics_enabled = DEFAULT_HAPTICS_ENABLED
	mobile_advanced_combat_controls = DEFAULT_MOBILE_ADVANCED_COMBAT_CONTROLS
	mobile_tilt_steering_enabled = DEFAULT_MOBILE_TILT_STEERING_ENABLED
	mobile_tilt_axis = DEFAULT_MOBILE_TILT_AXIS
	mobile_control_overrides = {}
	hud_layout_version = HUD_LAYOUT_VERSION_CURRENT
	ui_font = DEFAULT_UI_FONT
	ai_difficulty = DEFAULT_AI_DIFFICULTY


## M23 — the active enemy difficulty profile (cached until ai_difficulty changes).
## An unloadable path is a push_error, never a silent fallback to "no scaling".
func get_ai_difficulty_profile() -> AIDifficultyData:
	if _ai_difficulty_profile:
		return _ai_difficulty_profile
	var path: String = AI_DIFFICULTY_PATHS[ai_difficulty]
	var res = load(path)
	if not (res is AIDifficultyData):
		push_error("SettingsManager: AI difficulty resource '%s' missing or wrong type" % path)
		return null
	_ai_difficulty_profile = res
	return _ai_difficulty_profile


func get_ai_difficulty_names() -> Array[String]:
	var names: Array[String] = []
	for path in AI_DIFFICULTY_PATHS:
		var res = load(path)
		names.append(res.display_name if res is AIDifficultyData else path.get_file().get_basename())
	return names

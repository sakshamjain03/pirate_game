# Requirements Document

## Introduction

Milestone M1 — App Shell establishes the navigable skeleton of Pirate Empire before any gameplay systems exist.
It delivers a Boot scene, a MainMenu, a SettingsMenu, a CreditsScreen, and the three autoload managers (SceneManager, AudioManager, SettingsManager) that every future milestone depends on.
No gameplay, combat, economy, or world systems are in scope. The goal is a stable, visually polished shell that a player can boot, navigate, configure, and exit correctly on Android (primary) and desktop targets.

---

## Glossary

- **SceneManager**: Autoload singleton (`Scripts/managers/SceneManager.gd`) responsible for all scene transitions, fade animations, and back-navigation history.
- **AudioManager**: Autoload singleton (`Scripts/managers/AudioManager.gd`) responsible for reading and writing audio bus volumes.
- **SettingsManager**: Autoload singleton (`Scripts/managers/SettingsManager.gd`) responsible for persisting and applying display and audio settings via `user://settings.cfg`.
- **SaveManager**: Autoload singleton (`Scripts/managers/SaveManager.gd`) — stub only in M1, no persistent data written.
- **GameManager**: Autoload singleton (`Scripts/managers/GameManager.gd`) — manages high-level game state enum.
- **Boot_Scene**: `Scenes/core/Boot.tscn` — the project's initial scene, performs no rendering beyond a brief splash moment.
- **MainMenu**: `Scenes/ui/MainMenu.tscn` — the primary navigation hub presented after boot.
- **SettingsMenu**: `Scenes/ui/SettingsMenu.tscn` — the settings panel for audio and display configuration.
- **CreditsScreen**: `Scenes/ui/CreditsScreen.tscn` — a scrollable credits display.
- **Fade_Overlay**: A full-viewport black `ColorRect` owned by SceneManager, always rendered above all scenes.
- **Scene_History**: An ordered stack (`Array[String]`) maintained by SceneManager recording the path of each scene navigated to.
- **ConfigFile**: Godot's built-in `ConfigFile` class used to read/write `user://settings.cfg`.
- **ui_cancel**: Godot input action (default: Escape on desktop, B-button on gamepad) used to trigger back-navigation.
- **linear_volume**: A `float` in the range `[0.0, 1.0]` representing volume as a linear scalar before dB conversion.
- **Bus_Name**: A `String` matching one of the three Godot audio bus names: `"Master"`, `"Music"`, or `"SFX"`.
- **FULL_RECT**: Godot `Control` anchor preset that stretches the node to fill its parent, used for responsive scaling.
- **canvas_items**: Godot stretch mode setting applied in `project.godot`; scales UI elements at integer ratios relative to the 1920×1080 base resolution.

---

## Requirements

### Requirement 1: Boot Sequence

**User Story:** As a player, I want the game to start and reach the main menu automatically, so that I can begin playing without any manual navigation.

#### Acceptance Criteria

1. WHEN the application launches, THE Boot_Scene SHALL be the first scene loaded by the SceneTree, as configured by the `application/run/main_scene` entry in `project.godot`.
2. WHEN Boot_Scene's `_ready()` callback executes, THE Boot_Scene SHALL call `SceneManager.change_scene_with_fade("res://Scenes/ui/MainMenu.tscn")` with a duration of `0.4` seconds or less.
3. WHEN the fade transition from Boot_Scene to MainMenu completes, THE SceneManager SHALL emit the `scene_changed` signal with the path `"res://Scenes/ui/MainMenu.tscn"`.
4. THE Boot_Scene SHALL NOT contain any `Button`, `TouchScreenButton`, or other input-consuming control nodes that are visible before the transition begins.
5. IF the scene file at `"res://Scenes/ui/MainMenu.tscn"` does not exist when Boot_Scene calls `change_scene_with_fade`, THEN THE SceneManager SHALL log an error and the active scene SHALL remain Boot_Scene.

---

### Requirement 2: SceneManager — Scene Transition

**User Story:** As a developer, I want a centralised scene transition system, so that all navigation in the game uses a consistent, maintainable API.

#### Acceptance Criteria

1. THE SceneManager SHALL expose a `change_scene_with_fade(path: String, duration: float = 0.4)` method that transitions to the scene at `path` using a fade animation of total duration `duration` seconds, where `duration` SHALL be greater than `0.0`.
2. WHEN `change_scene_with_fade` is called, THE SceneManager SHALL execute the fade sequence in this order: fade the overlay from transparent to opaque (half duration) → swap the active scene → fade the overlay from opaque to transparent (half duration).
3. WHEN `change_scene_with_fade` is called, THE SceneManager SHALL push `path` onto the Scene_History stack immediately after the scene swap and before the fade-in begins.
4. WHEN `change_scene_with_fade` completes, THE SceneManager SHALL emit `scene_changed(path: String)`.
5. THE SceneManager SHALL expose a `change_scene(path: String)` method that transitions without a fade animation.
6. WHEN `change_scene` is called, THE SceneManager SHALL push `path` onto the Scene_History stack.
7. IF a transition is already in progress when `change_scene_with_fade` or `change_scene` is called, THEN THE SceneManager SHALL ignore the new call and log a warning.
8. IF `change_scene_with_fade` or `change_scene` is called with a `path` that does not resolve to a valid scene file, THEN THE SceneManager SHALL abort the transition, keep the currently active scene, and log an error.

---

### Requirement 3: SceneManager — Fade Overlay

**User Story:** As a player, I want scene transitions to be visually smooth, so that the game feels polished rather than abruptly cutting between screens.

#### Acceptance Criteria

1. THE SceneManager SHALL create a `ColorRect` (`_fade_overlay`) anchored to `FULL_RECT` with color `Color(0, 0, 0, 1)` as a direct child of itself during `_ready()`, so that it persists across scene swaps.
2. THE Fade_Overlay SHALL have a `z_index` of `100` so that it renders above all scene content.
3. WHILE a fade transition is in progress, THE Fade_Overlay SHALL be visible with `modulate.a` animating from `0.0` to `1.0` during fade-out and from `1.0` to `0.0` during fade-in.
4. WHEN a fade transition completes, THE Fade_Overlay SHALL have `visible` set to `false`.
5. WHEN `change_scene_with_fade` is called while a prior tween is still running, THE SceneManager SHALL kill the prior tween before creating a new one via `create_tween()`.
6. THE SceneManager SHALL create a new `Tween` via `create_tween()` for each transition call, so that concurrent calls do not share tween state.

---

### Requirement 4: SceneManager — Back Navigation

**User Story:** As a player, I want to navigate back to the previous screen using the Escape key or Back button, so that I can exit sub-menus intuitively.

#### Acceptance Criteria

1. THE SceneManager SHALL expose a `go_back()` method that pops the most recent entry from Scene_History and navigates to it using `change_scene_with_fade` with the default duration; the departing scene's path SHALL NOT be re-pushed onto Scene_History during this navigation.
2. WHEN `go_back()` is called and Scene_History contains at least one entry, THE SceneManager SHALL navigate to the popped path with a fade transition of `0.4` seconds.
3. IF `go_back()` is called and Scene_History is empty, THEN THE SceneManager SHALL log a warning and leave Scene_History unchanged, taking no further action.
4. WHEN the `ui_cancel` input action fires in any scene that does not consume it, THE scene SHALL call `SceneManager.go_back()` from within its `_unhandled_input()` callback.

---

### Requirement 5: MainMenu Scene

**User Story:** As a player, I want a clear main menu with labelled navigation buttons, so that I can choose what to do when I start the game.

#### Acceptance Criteria

1. THE MainMenu SHALL display, in top-to-bottom order within a `VBoxContainer`: a Play button, a Settings button, a Credits button, and a Quit button.
2. WHEN the Play button is pressed, THE MainMenu SHALL call `SceneManager.change_scene_with_fade("res://Scenes/ui/GameWorld.tscn")`.
3. IF a scene transition initiated from MainMenu fails (invalid path or transition already in progress), THEN THE MainMenu SHALL remain the active scene and SHALL log an error.
4. WHEN the Settings button is pressed, THE MainMenu SHALL call `SceneManager.change_scene_with_fade("res://Scenes/ui/SettingsMenu.tscn")`.
5. WHEN the Credits button is pressed, THE MainMenu SHALL call `SceneManager.change_scene_with_fade("res://Scenes/ui/CreditsScreen.tscn")`.
6. WHEN the Quit button is pressed, THE MainMenu SHALL call `get_tree().quit()`.
7. THE MainMenu root node SHALL be a `CanvasLayer` containing a `Control` child anchored to `FULL_RECT`.
8. THE MainMenu SHALL display a `Label` with the text `"Pirate Empire"` as the game title.

---

### Requirement 6: SettingsMenu Scene

**User Story:** As a player, I want to adjust audio volumes and display preferences from a settings screen, so that the game suits my device and personal preferences.

#### Acceptance Criteria

1. THE SettingsMenu SHALL display three labelled `HSlider` controls — one each for Master volume, Music volume, and SFX volume — each with `min_value = 0.0`, `max_value = 1.0`, and `step = 0.01`.
2. THE SettingsMenu SHALL display a labelled `CheckButton` for fullscreen toggle and a labelled `CheckButton` for vsync toggle.
3. THE SettingsMenu SHALL display a labelled `OptionButton` for resolution selection, populated with the items `"1920x1080"`, `"1280x720"`, `"2560x1440"`, and `"3840x2160"` in that order.
4. WHEN SettingsMenu's `_ready()` completes, THE SettingsMenu SHALL populate each control from SettingsManager: volume sliders via `slider.value = SettingsManager.get(property)`, CheckButtons via `button.button_pressed = SettingsManager.get(property)`, and the resolution OptionButton by selecting the item whose text matches `SettingsManager.resolution`.
5. WHEN a volume slider's `value_changed` signal fires, THE SettingsMenu SHALL first update the corresponding SettingsManager property, then call `AudioManager.set_bus_volume(bus_name, linear_value)`, and finally call `SettingsManager.save_settings()`.
6. WHEN a display control (fullscreen CheckButton, vsync CheckButton, or resolution OptionButton) emits a change signal, THE SettingsMenu SHALL first update the corresponding SettingsManager property, then call `SettingsManager.save_settings()`, and finally call `SettingsManager.apply_display_settings()`.
7. WHEN the Back button is pressed, THE SettingsMenu SHALL call `SceneManager.go_back()`.
8. WHEN the `ui_cancel` input action is received in `_unhandled_input()`, THE SettingsMenu SHALL call `SceneManager.go_back()`.
9. THE SettingsMenu root node SHALL be a `CanvasLayer` containing a `Control` child anchored to `FULL_RECT`.

---

### Requirement 7: CreditsScreen Scene

**User Story:** As a player, I want to view a scrollable credits screen, so that I can read acknowledgements at my own pace.

#### Acceptance Criteria

1. THE CreditsScreen SHALL display credits text inside a `RichTextLabel` (with `scroll_active = false`) wrapped in a `ScrollContainer` (with `horizontal_scroll_mode = SCROLL_MODE_DISABLED`), enabling only vertical scrolling.
2. THE CreditsScreen SHALL display a Back button.
3. WHEN the Back button is pressed, THE CreditsScreen SHALL call `SceneManager.go_back()`.
4. WHEN the `ui_cancel` input action is received in `_unhandled_input()`, THE CreditsScreen SHALL call `SceneManager.go_back()`.
5. THE CreditsScreen root node SHALL be a `CanvasLayer` containing a `Control` child anchored to `FULL_RECT`.

---

### Requirement 8: AudioManager

**User Story:** As a developer, I want a centralised audio volume API, so that any system can read or write bus volumes without directly coupling to Godot's audio bus internals.

#### Acceptance Criteria

1. THE AudioManager SHALL expose `set_bus_volume(bus_name: String, linear: float)` which converts `linear` from the range `[0.0, 1.0]` to decibels via `linear_to_db()` and applies it to the named Godot audio bus.
2. THE AudioManager SHALL expose `get_bus_volume(bus_name: String) -> float` which returns the current linear volume of the named bus by converting from dB via `db_to_linear()`.
3. WHEN `set_bus_volume` is called with a valid `bus_name` and a `linear` value in `[0.0, 1.0]`, THE AudioManager SHALL emit `volume_changed(bus_name: String, linear: float)` with the applied linear value.
4. THE AudioManager SHALL manage exactly three buses: `"Master"`, `"Music"`, and `"SFX"`.
5. IF `set_bus_volume` or `get_bus_volume` is called with a `bus_name` that does not match a known bus, THEN THE AudioManager SHALL log an error message indicating the unrecognised bus name and take no further action.
6. IF `set_bus_volume` is called with a `linear` value outside `[0.0, 1.0]`, THEN THE AudioManager SHALL clamp the value to the nearest bound of `[0.0, 1.0]`, apply the clamped value, and emit `volume_changed` with the clamped linear value.
7. THE AudioManager SHALL NOT play any audio streams or reference any scene nodes.

---

### Requirement 9: SettingsManager — Persistence

**User Story:** As a player, I want my settings to be saved automatically, so that my preferences are restored the next time I launch the game.

#### Acceptance Criteria

1. THE SettingsManager SHALL persist settings to `user://settings.cfg` using Godot's `ConfigFile` API.
2. THE SettingsManager SHALL expose `load_settings()` which reads `user://settings.cfg` and populates internal state with stored values, falling back to the defined defaults when a key is absent or when the stored value is of the wrong type.
3. THE SettingsManager SHALL expose `save_settings()` which writes all current setting values to `user://settings.cfg`.
4. WHEN `save_settings()` completes successfully, THE SettingsManager SHALL emit `settings_changed`.
5. THE SettingsManager SHALL use the following default values when no saved file exists: `master_volume = 1.0`, `music_volume = 0.8`, `sfx_volume = 1.0`, `fullscreen = false`, `resolution = "1920x1080"`, `vsync = true`.
6. IF `user://settings.cfg` does not exist when `load_settings()` is called, THEN THE SettingsManager SHALL apply the default values without error.
7. THE SettingsManager SHALL store audio settings under the `"audio"` section and display settings under the `"display"` section of `user://settings.cfg`.
8. IF `save_settings()` fails to write to disk (e.g., filesystem error), THEN THE SettingsManager SHALL log an error and SHALL NOT emit `settings_changed`.

---

### Requirement 10: SettingsManager — Apply Settings

**User Story:** As a player, I want the game to apply my saved display and audio settings immediately when the game starts, so that I never have to reconfigure them each session.

#### Acceptance Criteria

1. THE SettingsManager SHALL expose `apply_display_settings()` which calls `DisplayServer` APIs to apply the current `fullscreen`, `resolution`, and `vsync` values.
2. THE SettingsManager SHALL expose `apply_audio_settings()` which calls `AudioManager.set_bus_volume("Master", master_volume)`, `AudioManager.set_bus_volume("Music", music_volume)`, and `AudioManager.set_bus_volume("SFX", sfx_volume)` with values in `[0.0, 1.0]`.
3. WHEN `load_settings()` is called, THE SettingsManager SHALL call `apply_display_settings()` and `apply_audio_settings()` to immediately reflect loaded values.
4. THE SettingsManager SHALL NOT reference any UI scene nodes directly.
5. IF `apply_display_settings()` is called with a `resolution` string that does not match a supported format (e.g., not `"WxH"`), THEN THE SettingsManager SHALL log an error and skip applying the resolution without crashing.
6. IF `apply_audio_settings()` is called when AudioManager is not available in the scene tree, THEN THE SettingsManager SHALL log an error and skip the audio application without crashing.

---

### Requirement 11: UI Layout and Responsive Scaling

**User Story:** As a player on a mobile device, I want the UI to display correctly at any supported resolution, so that buttons and text are always readable and tappable.

#### Acceptance Criteria

1. THE `project.godot` SHALL configure `display/window/size/viewport_width = 1920`, `display/window/size/viewport_height = 1080`, `display/window/stretch/mode = "canvas_items"`, and `display/window/stretch/aspect = "keep"`.
2. THE MainMenu, SettingsMenu, and CreditsScreen SHALL each have their root `Control` node anchored to `FULL_RECT` so they fill the viewport at all resolutions.
3. THE SettingsMenu SHALL arrange its label-control pairs in a `GridContainer` with `columns = 2`.
4. THE MainMenu, SettingsMenu, and CreditsScreen SHALL each be structured as `CanvasLayer → Control (FULL_RECT)` at their scene root.
5. ALL interactive controls (buttons, sliders, checkboxes) in MainMenu, SettingsMenu, and CreditsScreen SHALL have a minimum size of at least `44×44` pixels to meet mobile tap-target accessibility standards.

---

### Requirement 12: Keyboard and Gamepad Navigation

**User Story:** As a player on desktop or with a gamepad, I want to navigate all menus using the keyboard or gamepad, so that I can play without requiring touch or mouse input.

#### Acceptance Criteria

1. WHILE SettingsMenu is the active scene, WHEN the `ui_cancel` input action fires, THE SettingsMenu SHALL call `SceneManager.go_back()`.
2. WHILE CreditsScreen is the active scene, WHEN the `ui_cancel` input action fires, THE CreditsScreen SHALL call `SceneManager.go_back()`.
3. THE SettingsMenu and CreditsScreen SHALL handle `ui_cancel` inside `_unhandled_input()` so that focused controls receive input first.
4. THE MainMenu, SettingsMenu, and CreditsScreen SHALL allow all interactive controls to receive keyboard/gamepad focus through Godot's built-in focus system without custom focus management code.
5. WHEN any of MainMenu, SettingsMenu, or CreditsScreen is entered, THE first interactive control in scene order SHALL receive focus automatically so that gamepad users have a defined starting control.

---

### Requirement 13: Navigation Flow Integrity

**User Story:** As a player, I want every screen to navigate to the correct destination, so that I never end up on the wrong screen or in a broken state.

#### Acceptance Criteria

1. THE navigation path Boot → MainMenu SHALL be the only entry path into the application after launch.
2. WHEN the player is on MainMenu, THE only valid navigation actions SHALL be: navigate to SettingsMenu, navigate to CreditsScreen, navigate to GameWorld (stub), and call `get_tree().quit()`.
3. WHEN the player is on SettingsMenu, THE only valid navigation action SHALL be `SceneManager.go_back()`.
4. WHEN the player is on CreditsScreen, THE only valid navigation action SHALL be `SceneManager.go_back()`.
5. WHEN `SceneManager.go_back()` is called and Scene_History contains `"res://Scenes/ui/MainMenu.tscn"` as its last entry, THE SceneManager SHALL transition to MainMenu.

---

### Requirement 14: SaveManager Stub

**User Story:** As a developer, I want a SaveManager autoload present in M1, so that future milestones can add save functionality without changing the autoload registry.

#### Acceptance Criteria

1. THE SaveManager SHALL be registered as an autoload in `project.godot`.
2. THE SaveManager SHALL expose the placeholder method signatures `save_game() -> void`, `load_game() -> void`, and `has_save_data() -> bool`, each returning immediately without side effects.
3. THE SaveManager SHALL NOT write any data to disk during M1.

---

### Requirement 15: Signal Architecture

**User Story:** As a developer, I want all cross-system communication to use signals, so that autoload singletons remain decoupled from UI scenes and from each other.

#### Acceptance Criteria

1. THE SceneManager SHALL communicate scene swap completion exclusively through the `scene_changed(path: String)` signal.
2. THE AudioManager SHALL communicate volume updates exclusively through the `volume_changed(bus_name: String, linear: float)` signal.
3. THE SettingsManager SHALL communicate settings persistence exclusively through the `settings_changed` signal.
4. THE autoload singletons (SceneManager, AudioManager, SettingsManager) SHALL NOT call methods on UI scene nodes directly, and SHALL NOT connect signals to UI scene node methods.
5. THE UI scenes SHALL call autoload singleton methods directly and SHALL NOT emit signals to other UI scenes.

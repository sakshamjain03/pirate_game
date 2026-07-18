# Design Document: Milestone M1 — App Shell

## 1. Scene Hierarchy

```
Root (SceneTree)
├── [Autoloads]
│   ├── GameManager        # game state enum + change_state()
│   ├── SceneManager       # navigation, transitions, fade overlay
│   ├── SettingsManager    # ConfigFile read/write/apply
│   ├── AudioManager       # audio bus volume control only
│   └── SaveManager        # stub, out of scope for M1
└── [Active Scene — swapped by SceneManager]
    ├── Scenes/core/Boot.tscn
    ├── Scenes/ui/MainMenu.tscn
    ├── Scenes/ui/SettingsMenu.tscn
    └── Scenes/ui/CreditsScreen.tscn
```

SceneManager maintains a `ColorRect` fade overlay as a direct child of itself (always on top), injected into the scene tree at `_ready()`.

---

## 2. UI Scene Structure

Each UI scene root is a `CanvasLayer` → `Control (anchor: full rect)`.

**MainMenu.tscn**
```
CanvasLayer
└── Control
    ├── BackgroundTexture (TextureRect)
    ├── TitleLabel
    └── VBoxContainer
        ├── PlayButton
        ├── SettingsButton
        ├── CreditsButton
        └── QuitButton
```

**SettingsMenu.tscn**
```
CanvasLayer
└── Control
    ├── TitleLabel
    ├── GridContainer
    │   ├── MasterVolumeLabel + HSlider
    │   ├── MusicVolumeLabel  + HSlider
    │   ├── SFXVolumeLabel    + HSlider
    │   ├── FullscreenLabel   + CheckButton
    │   ├── ResolutionLabel   + OptionButton
    │   └── VSyncLabel        + CheckButton
    └── BackButton
```

**CreditsScreen.tscn**
```
CanvasLayer
└── Control
    ├── TitleLabel
    ├── ScrollContainer → RichTextLabel
    └── BackButton
```

All scenes use `stretch_mode = canvas_items` (already set in project.godot, 1920×1080 base). Control nodes anchor to `FULL_RECT` for responsive scaling.

---

## 3. SceneManager Responsibilities

- Owns `change_scene(path: String)` — replaces current scene via `get_tree().change_scene_to_file()`
- Owns `change_scene_with_fade(path: String, duration: float = 0.4)` — runs fade-out → swap → fade-in
- Owns the `ColorRect` fade overlay (`_fade_overlay`) added as autoload child, `z_index = 100`
- Maintains a `_scene_history: Array[String]` stack for back-navigation
- Exposes `go_back()` — pops history and navigates with fade
- Notifies via signal `scene_changed(new_path: String)`
- Does NOT know which buttons exist; UI scenes call SceneManager directly

---

## 4. AudioManager Responsibilities

- New autoload: `Scripts/managers/AudioManager.gd`
- Owns three audio buses: `Master`, `Music`, `SFX` (configured in Godot Audio panel)
- Exposes:
  - `set_bus_volume(bus_name: String, linear: float)` — converts to dB, applies to bus
  - `get_bus_volume(bus_name: String) -> float` — returns linear volume
- Does NOT reference any UI nodes
- Does NOT play sounds (gameplay audio handled by future systems)
- Emits `volume_changed(bus_name: String, linear: float)` signal

---

## 5. SettingsManager Responsibilities

Extends existing stub. Manages `user://settings.cfg` via `ConfigFile`.

Tracks these values (all with defaults):

| Key | Section | Default |
|-----|---------|---------|
| `master_volume` | `audio` | `1.0` |
| `music_volume` | `audio` | `0.8` |
| `sfx_volume` | `audio` | `1.0` |
| `fullscreen` | `display` | `false` |
| `resolution` | `display` | `"1920x1080"` |
| `vsync` | `display` | `true` |

- `load_settings()` — reads file, applies to AudioManager + DisplayServer
- `save_settings()` — writes current values to file
- `apply_display_settings()` — calls `DisplayServer` APIs (fullscreen, resolution, vsync)
- `apply_audio_settings()` — calls `AudioManager.set_bus_volume()` for each bus
- Does NOT reference UI nodes. SettingsMenu reads values from SettingsManager and writes back on change.
- Emits `settings_changed()` signal after save

---

## 6. Navigation Flow

```
Boot.tscn
  └─[_ready]─► SceneManager.change_scene_with_fade("res://Scenes/ui/MainMenu.tscn")

MainMenu
  ├── [Play]     ─► SceneManager.change_scene_with_fade("res://Scenes/ui/GameWorld.tscn")  [M2+]
  ├── [Settings] ─► SceneManager.change_scene_with_fade("res://Scenes/ui/SettingsMenu.tscn")
  ├── [Credits]  ─► SceneManager.change_scene_with_fade("res://Scenes/ui/CreditsScreen.tscn")
  └── [Quit]     ─► get_tree().quit()

SettingsMenu
  └── [Back / Escape] ─► SceneManager.go_back()

CreditsScreen
  └── [Back / Escape] ─► SceneManager.go_back()
```

Keyboard: `ui_cancel` (Escape / B-button) mapped in each UI scene's `_unhandled_input()` → calls `SceneManager.go_back()`. Tab/arrow keys navigate between focusable controls natively via Godot's focus system.

---

## 7. Fade Transition Flow

```
change_scene_with_fade(path, duration):
  1. _fade_overlay.visible = true
  2. Tween: modulate.a  0.0 → 1.0  (duration * 0.5 s)
  3. await tween.finished
  4. get_tree().change_scene_to_file(path)
  5. _scene_history.push_back(path)
  6. Tween: modulate.a  1.0 → 0.0  (duration * 0.5 s)
  7. await tween.finished
  8. _fade_overlay.visible = false
  9. emit signal scene_changed(path)
```

`_fade_overlay` is a black `ColorRect` stretching the full viewport, parented to SceneManager (autoload), so it persists across scene swaps. Tween created fresh each call (`create_tween()`).

---

## 8. Files to Create

| File | Type | Notes |
|------|------|-------|
| `Scripts/managers/AudioManager.gd` | GDScript | New autoload |
| `Scenes/ui/MainMenu.tscn` | Scene | + `Scripts/ui/MainMenu.gd` |
| `Scenes/ui/SettingsMenu.tscn` | Scene | + `Scripts/ui/SettingsMenu.gd` |
| `Scenes/ui/CreditsScreen.tscn` | Scene | + `Scripts/ui/CreditsScreen.gd` |

**Extend (do not recreate):**

| File | Change |
|------|--------|
| `Scripts/managers/SceneManager.gd` | Add fade overlay, history stack, `change_scene_with_fade()`, `go_back()` |
| `Scripts/managers/SettingsManager.gd` | Add ConfigFile logic, `apply_display_settings()`, `apply_audio_settings()` |
| `Scripts/core/Boot.gd` | Replace stub transition with `SceneManager.change_scene_with_fade(...)` |
| `project.godot` | Add `AudioManager` autoload entry |

---

## 9. Signals Between Systems

| Emitter | Signal | Subscriber | Purpose |
|---------|--------|------------|---------|
| `SceneManager` | `scene_changed(path)` | *(future systems)* | Notify scene swap complete |
| `AudioManager` | `volume_changed(bus, linear)` | SettingsMenu | Sync slider UI if changed externally |
| `SettingsManager` | `settings_changed()` | *(future systems)* | Notify settings were written to disk |
| `SettingsMenu.gd` | *(none — calls directly)* | `SettingsManager` | On slider/toggle change → `SettingsManager.save_settings()` |
| `SettingsMenu.gd` | *(none — calls directly)* | `AudioManager` | On volume slider change → `AudioManager.set_bus_volume()` |

No UI scene emits signals to other UI scenes. All cross-system communication routes through the autoload singletons. UI scripts are the only callers of singleton methods; singletons never call into UI.


---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

---

### Property 1: Scene navigation always pushes to history

*For any* valid scene path string, calling either `change_scene_with_fade(path)` or `change_scene(path)` on SceneManager must result in `path` appearing as the most recent entry in the Scene_History stack, and the stack length must increase by exactly one compared to before the call.

**Validates: Requirements 2.3, 2.6**

---

### Property 2: scene_changed signal is emitted with the correct path

*For any* valid scene path, when `change_scene_with_fade(path)` completes the entire fade sequence, the `scene_changed` signal must have been emitted exactly once with that same `path` as its argument.

**Validates: Requirements 2.4**

---

### Property 3: Fade overlay is hidden after every transition

*For any* call to `change_scene_with_fade` with any valid path and any positive duration, after the method fully completes the `_fade_overlay.visible` property must be `false`.

**Validates: Requirements 3.4**

---

### Property 4: go_back() correctly pops and navigates history

*For any* Scene_History stack of length N ≥ 1, calling `go_back()` must result in a Scene_History stack of length N − 1, and SceneManager must initiate a transition to the path that was at position N − 1 (the most recently pushed entry).

**Validates: Requirements 4.1, 4.2, 13.5**

---

### Property 5: AudioManager volume round-trip

*For any* Bus_Name in `{"Master", "Music", "SFX"}` and any `linear_volume` in `[0.0, 1.0]`, calling `AudioManager.set_bus_volume(bus_name, linear_volume)` followed by `AudioManager.get_bus_volume(bus_name)` must return a value equal to `linear_volume` (within floating-point tolerance).

**Validates: Requirements 8.1, 8.2**

---

### Property 6: volume_changed signal carries correct arguments

*For any* Bus_Name in `{"Master", "Music", "SFX"}` and any `linear_volume` in `[0.0, 1.0]`, calling `AudioManager.set_bus_volume(bus_name, linear_volume)` must cause the `volume_changed` signal to be emitted exactly once with `bus_name` and `linear_volume` as its arguments.

**Validates: Requirements 8.3**

---

### Property 7: AudioManager clamps out-of-range volumes

*For any* Bus_Name in `{"Master", "Music", "SFX"}` and any `float` value (including values below `0.0` or above `1.0`), calling `AudioManager.set_bus_volume(bus_name, value)` must result in `AudioManager.get_bus_volume(bus_name)` returning a value in `[0.0, 1.0]`.

**Validates: Requirements 8.6**

---

### Property 8: Settings persistence round-trip

*For any* combination of valid settings values (`master_volume`, `music_volume`, `sfx_volume` ∈ `[0.0, 1.0]`; `fullscreen` ∈ `{true, false}`; `vsync` ∈ `{true, false}`; `resolution` ∈ the supported resolution strings), writing those values via `SettingsManager.save_settings()` and then calling `SettingsManager.load_settings()` must restore all values to exactly what was written.

**Validates: Requirements 9.1, 9.2, 9.3**

---

### Property 9: settings_changed signal is emitted on every save

*For any* valid settings state, calling `SettingsManager.save_settings()` must cause the `settings_changed` signal to be emitted exactly once.

**Validates: Requirements 9.4**

---

### Property 10: Settings saved under correct ConfigFile sections

*For any* valid settings state, after `SettingsManager.save_settings()` the resulting `ConfigFile` at `user://settings.cfg` must store `master_volume`, `music_volume`, and `sfx_volume` under the `"audio"` section and `fullscreen`, `resolution`, and `vsync` under the `"display"` section.

**Validates: Requirements 9.7**

---

### Property 11: apply_audio_settings calls set_bus_volume for all three buses

*For any* valid audio settings state (`master_volume`, `music_volume`, `sfx_volume` ∈ `[0.0, 1.0]`), calling `SettingsManager.apply_audio_settings()` must call `AudioManager.set_bus_volume` exactly three times — once for each of `"Master"`, `"Music"`, and `"SFX"` — with the corresponding stored volume values.

**Validates: Requirements 10.2**

---

### Property 12: SettingsMenu controls reflect current settings state

*For any* valid persisted settings state, when SettingsMenu's `_ready()` completes, each UI control (the three volume sliders, the fullscreen CheckButton, the vsync CheckButton, and the resolution OptionButton) must display the value returned by SettingsManager for that setting.

**Validates: Requirements 6.4**

---

### Property 13: Volume slider changes propagate to AudioManager and SettingsManager

*For any* Bus_Name in `{"Master", "Music", "SFX"}` and any `linear_volume` in `[0.0, 1.0]`, when a SettingsMenu volume slider emits a value change, `AudioManager.set_bus_volume(bus_name, linear_volume)` and `SettingsManager.save_settings()` must each be called exactly once with the correct arguments.

**Validates: Requirements 6.5**

---

### Property 14: Display control changes trigger save and apply

*For any* valid display settings combination (`fullscreen`, `resolution`, `vsync`), when any SettingsMenu display control emits a change, `SettingsManager.save_settings()` must be called before `SettingsManager.apply_display_settings()`, and both must be called exactly once.

**Validates: Requirements 6.6**

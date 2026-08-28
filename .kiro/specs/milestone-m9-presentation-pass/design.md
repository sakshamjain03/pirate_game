# Design Document — M9 Presentation Pass

## How these were found

Not by reading code, and not by trusting the prior "Resolved" status in `docs/05_CURRENT_SYSTEMS.md`
— by actually running the game:

```
<godot-binary> --path d:/Pirate-game scenes/debug/CaptureHarness.tscn --capture-dir=<abs path>
```

Run headful (no `--headless`), zero player input, screenshots at t=0/1/3/7/12s. Two defects this
document already recorded as fixed (D32, D36) reproduced identically to their original
descriptions. Five further findings came from reading the UI source directly once the screenshots
made clear something was off, then grepping for the pattern across every screen to see how far it
spread (e.g. once `SettingsMenu` was suspected unthemed, grepping `PirateThemeBuilder` across
`scripts/ui/` confirmed it was the only gap of its kind).

---

## Requirement 1 — D36: notoriety/resource-bar overlap

### Why the previous fix didn't hold

```gdscript
# WorldHUD.gd, current
_notoriety_label.offset_top = 52.0     # meant to sit flush under ResourceBar
_notoriety_label.offset_bottom = 96.0
```

```gdscript
# WorldHUD.tscn, ResourceBar
offset_top = 12.0
offset_bottom = 52.0
```

On paper, `52.0` is exactly `ResourceBar`'s own `offset_bottom` — they should be flush. In
practice they visibly overlap. The two most likely explanations, both pointing at the same fix:

1. `ResourceBar` is a `PanelContainer` wrapping an `HBoxContainer` of `Label`s with no explicit
   height — its actual rendered height is driven by its children's font metrics plus
   `PirateThemeBuilder`'s panel content margins (`content_margin_top/bottom = 6.0` each), which can
   exceed the authored `offset_top`/`offset_bottom` window (40px) once real multi-digit resource
   values are showing. The container may be rendering *taller* than its anchor rect claims.
2. Two independently-hardcoded numbers (`ResourceBar`'s `52.0` and the label's `52.0`) are a
   coincidence of authoring, not a structural guarantee — anyone changing one without the other
   (already nearly happened once, per D36's own history) breaks it again with no error.

### The fix

Stop maintaining two independently-hardcoded `52.0`s. Read `ResourceBar`'s actual rect at runtime
and position the label relative to it:

```gdscript
# WorldHUD.gd
@onready var resource_bar: PanelContainer = %ResourceBar   # give ResourceBar a unique name

func _create_notoriety_label() -> void:
    _notoriety_label = Label.new()
    ...
    _notoriety_label.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
    _notoriety_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _notoriety_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _notoriety_label.offset_left = -320.0
    _notoriety_label.offset_right = -16.0
    add_child(_notoriety_label)
    # Position below ResourceBar using its *actual* rendered rect, not a duplicated constant.
    await get_tree().process_frame   # let ResourceBar settle its own layout first
    var gap := 8.0
    _notoriety_label.offset_top = resource_bar.position.y + resource_bar.size.y + gap
    _notoriety_label.offset_bottom = _notoriety_label.offset_top + 44.0
```

This still isn't perfectly dynamic (it snapshots the position once), but it derives from
`ResourceBar`'s real measured size instead of a second hand-typed constant that has to be kept in
sync by convention. A more robust alternative — wrapping `ResourceBar` and the notoriety label in a
shared `VBoxContainer` anchored top-right, letting Godot's own container layout stack them — is
preferred if it doesn't disturb `ResourceBar`'s existing internal structure; try that first, fall
back to the runtime-measured offset above if `ResourceBar`'s current `PanelContainer` setup doesn't
compose cleanly inside a `VBoxContainer`.

### Verification

Requirement 1 AC3 requires this to hold across at least two viewport sizes. `CaptureHarness` runs
at whatever `project.godot`'s declared viewport is; testing a second size means either a second
capture run with `--resolution` (verify Godot 4.7 exposes this at the CLI, or temporarily override
`window/size/viewport_width/height` for the second run) or adding a GUT property test that
constructs `WorldHUD` at two different `Control` rect sizes and asserts the two label rects don't
intersect (`Rect2.intersects()`), which is faster and doesn't need a real render.

---

## Requirement 2 — D32: material-null startup errors

### A new lead, not available to the original diagnosis

The 2026-08-26 capture's own log shows cannon fire happening at the very first captured frame, with
no player input:

```
WARNING: AudioManager: No audio asset for 'cannon' — assets/audio/ is empty...
   [2] fire_cannons (res://scripts/world/ShipController.gd:207)
```

This means an ambient encounter is starting essentially immediately on world load. The 4
material-null errors also fire at startup, before frame 2's capture. **Investigate whether the
material-null calls come from combat-side geometry spawned by this early encounter (cannonball,
muzzle effect, or the encounter's spawned enemy hull) querying a material before its
`KenneyMaterialApplier` pass has run, rather than from the camera spring arm** (the D31-attributed
cause, which is confirmed still fixed and still not explaining these errors). Reproduce with the
ambient encounter suppressed (temporarily raise `EncounterManager`'s ambient-start delay, or
comment out the pool) — if the errors disappear, the encounter/combat spawn path is the real
source, not the camera.

### Method

Same instrumentation discipline as D64's diagnosis (`docs/05_CURRENT_SYSTEMS.md`): don't guess,
print. Temporarily add a print at the top of whatever call chain leads to
`material_casts_shadows`/etc (Godot doesn't expose a GDScript stack trace for engine-internal
renderer calls directly, so bisect instead — disable subsystems one at a time: ambient encounter
spawning, camera spring arm, `KenneyMaterialApplier`'s tint pass — and re-run the capture after
each, noting which removal makes the error count go to 0). Revert all instrumentation once the real
cause is confirmed, per this project's established practice.

---

## Requirement 3 — Theme `SettingsMenu` / `CreditsScreen`

Mechanical — follow the exact pattern every other themed screen already uses:

```gdscript
# SettingsMenu.gd, add to _ready()
theme = PirateThemeBuilder.build()
```

```gdscript
# CreditsScreen.gd, add to _ready()
theme = PirateThemeBuilder.build()
```

For the missing background panel, copy `PauseMenu.tscn`'s or `DeathScreen.tscn`'s existing
background-panel node structure (a `ColorRect` dark overlay, or a themed `PanelContainer` framing
the content) rather than inventing a new pattern — reuse, per `AGENTS.md`.

---

## Requirement 4 — MainMenu typography

```gdscript
# MainMenu.tscn, TitleLabel
theme_override_font_sizes/font_size = 56

# SubtitleLabel
theme_override_font_sizes/font_size = 20

# CreditsButton, QuitButton — match the other three
theme_override_font_sizes/font_size = 28
```

Emoji prefixes: either strip `"📜  "`/`"✖  "` from `CreditsButton`/`QuitButton`'s `text`, or add a
matching icon convention to all five (an anchor icon for Continue, a sail for New Game, a gear for
Settings) — stripping is the smaller change and consistent with the other three today.

`VignetteOverlay`: cheapest correct option is deleting the unused node (it does nothing today and
nothing in `docs/03_ART_DIRECTION.md` specifically calls for a vignette). If a subtle vignette is
wanted for atmosphere, wire it via the same tween pattern `_animate_title()` already uses
(`modulate.a` 0 → target on `_ready()`), reusing that function rather than adding a second
animation system.

---

## Requirement 5 — HUD panel arbitration

Minimal, explicit rule rather than a general focus-stack (Non-Goal, per `AGENTS.md`'s
"no unnecessary complexity"):

```gdscript
# WorldHUD.gd
func _on_tutorial_dialogue_visibility_changed() -> void:
    var dialogue_open := tutorial_dialogue.visible
    cannons_container.modulate.a = 0.35 if dialogue_open else 1.0
```

Connect to `TutorialDialogue`'s existing `visibility_changed` signal (a built-in `Control` signal,
no new signal needed) in `WorldHUD._ready()`.

For ambient encounters not starting during dialogue: gate `EncounterManager._start_random_ambient()`
behind a check of whatever `WorldHUD`/`CampaignManager` already exposes for "a blocking dialogue is
open" — if nothing does yet, add a single `TutorialDialogue.is_blocking() -> bool` (returns
`visible`) and have `EncounterManager` check it before drawing, mirroring the existing
`required_chapter_id` gate pattern from M7.5 (`EncounterManager` already filters candidates through
one boolean gate; add a second one rather than a new mechanism).

---

## Requirement 6 — Framed announcement banner

```gdscript
# WorldHUD.gd, announce_event()
func announce_event(text_content: String, is_warning: bool = false) -> void:
    var panel := PanelContainer.new()
    panel.theme = PirateThemeBuilder.build()   # or reuse a cached instance, see note below
    var label := Label.new()
    label.text = text_content
    label.add_theme_color_override("font_color",
        PirateThemeBuilder.COLOR_RED_HEALTH if is_warning else PirateThemeBuilder.COLOR_GOLD_BRIGHT)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(label)
    ...same full-width anchoring and fade tween as today, applied to `panel` instead of `label`...
```

Existing callers of `announce_event()` (raid results, chapter progress, offline catch-up, dock
prompts) don't need to change — the new `is_warning` parameter defaults to `false`, and only a
couple of call sites (e.g. `"Too fast to dock — slow down!"`) would opt into `true`.

**Perf note:** `PirateThemeBuilder.build()` currently allocates a brand-new `Theme` + all its
styleboxes on every single call site across the whole UI layer (every screen's `_ready()` calls it
independently). That's pre-existing and out of this milestone's scope, but `announce_event()`
firing repeatedly (e.g. rapid boarding successes) makes the redundant allocation more visible —
if profiling during this milestone's checkpoint shows it's measurable, cache one built `Theme`
instance in `PirateThemeBuilder` itself (a static/autoload-held instance) rather than rebuilding
per call; flag as a follow-up if not fixed here, don't silently scope-creep into a bigger theming
refactor.

---

## Requirement 7 — Responsive `IslandMenu`

```gdscript
# IslandMenu.tscn, Panel (replacing custom_minimum_size = Vector2(600, 400))
anchors_preset = 15
anchor_left = 0.1
anchor_top = 0.1
anchor_right = 0.9
anchor_bottom = 0.9
custom_minimum_size = Vector2(480, 320)   # floor, so it never collapses below usable on a tiny viewport
```

10% margin on all sides scales with viewport; the `custom_minimum_size` floor keeps it usable if
anchoring alone would make it too small on an unusually narrow viewport. Verify all 6 tabs
(`IslandMenu.gd`'s tab-building code, which constructs content programmatically) still lay out
without clipping inside the new dynamic size — the tab content itself may also need its fixed
assumptions checked (e.g. any `custom_minimum_size` on inner rows sized for exactly 600px width).

---

## Requirement 8 — Portrait fallback

```gdscript
# New: scripts/ui/PortraitFallback.gd (or a function on an existing shared UI utility)
static func get_portrait_texture(portrait_path: String) -> Texture2D:
    if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
        return load(portrait_path)
    return load("res://assets/art/ui/portrait_fallback.png")   # or a themed placeholder built at runtime
```

If no fallback art asset exists yet (art production is out of this milestone's scope per
Requirement 8 AC1's "reads as intentional," not "is finished art"), build the fallback
programmatically the same way `PirateThemeBuilder` builds styleboxes — a `PanelContainer` with the
gold border style plus a simple flag/anchor `Label` glyph, so no new asset dependency is
introduced. Replace the current ad hoc purple-skull-icon call sites (search `scripts/ui/` for
wherever a `TextureRect`/`Label` resolves a missing portrait today) with a single call to this
function.

---

## Verification

Standard command:
```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Baseline entering this milestone: 324 tests, 323 passing, 1 known LOD failure.

**This milestone's checkpoint additionally requires a fresh headful `CaptureHarness` run reviewed
by a human**, not just a passing GUT suite — the entire reason this milestone exists is that two
defects passed exactly that automated bar before and were not actually fixed. A green test suite
alone is not sufficient sign-off here.

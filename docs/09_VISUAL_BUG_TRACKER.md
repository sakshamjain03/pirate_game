# Visual & Physics Bug Tracker

Working list of the "the game looks/feels wrong" defects, split into one
independently-verifiable item each.

**Method: screenshot first, one bug at a time.** Every item here was
characterised from an actual rendered frame before any code was changed, then
re-captured afterwards to validate. Reading source and reasoning about it
produced four wrong diagnoses across this work (see "Wrong turns" below), so it
is not an acceptable substitute for looking at the game.

## How to capture screenshots

A debug harness is checked in for this:

```
<godot> --path D:\Pirate-game res://scenes/debug/CaptureHarness.tscn --capture-dir=D:\Pirate-game\.capture
```

It instances `World.tscn`, captures the real viewport at frames 2 / 60 / 180 /
420 / 720 (≈0s, 1s, 3s, 7s, 12s) and quits on its own. The spread matters —
a physics bug looks fine at frame 2 and only shows itself seconds later.

Run it from **PowerShell, not Bash** — Bash strips the backslashes in
`--capture-dir=D:\...`, and every `save_png` then fails with err=12.

Engine on this machine (not vendored, gitignored):
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`

Files: `scenes/debug/CaptureHarness.tscn`, `scripts/debug/ScreenshotCapture.gd`.
Delete both once the visual bugs are closed.

## Status legend

- `[ ]` not started
- `[~]` fix written, validated by screenshot, not yet confirmed by a human playing
- `[x]` fixed and confirmed

---

## V1 — Ships capsize and tumble `[~]`

**Symptom (user):** ship is not floating on water correctly, turning around and
around.

This had **four** independent causes stacked on top of each other. Each fix was
real but only partial, which is why the bug kept surviving a "fix".

**1. Sign-inverted restoring torque** (`BuoyancySimulator.gd`). The old
expression `right * up.dot(forward) - forward * up.dot(right)` has a negative
dot product with the true restoring torque `body_up × world_up` for a tilt in
any direction. "Stability" actively drove the hull away from upright. Fixed to
`up.cross(Vector3.UP)`.

**2. Inverted pendulum — the big one** (`PlayerShip/EnemyShip/BossShip.tscn`).
No ship declared `center_of_mass`, so Godot computed it at the collision
shape's centre, `y = +1.0`. Every float point sits at `y = 0.0`. Buoyancy
therefore pushed up from a metre *below* the centre of mass, so any small tilt
generated **more** tilting torque — textbook inverted pendulum. No amount of
restoring torque can beat that. Fixed by ballasting `center_of_mass` below the
float points, which is what makes a real hull self-righting.

**3. Steering clobbered self-righting** (`ShipMovement.gd`). The turn servo did
`body.angular_velocity.y = lerp(...)`, overwriting the whole world-Y component
every frame — precisely the component the restoring torque needs to accumulate
to right a heeled hull. Ships that steer continuously (i.e. every AI enemy) had
their self-righting cancelled on every physics tick, while the player ship,
steered only on input, recovered. This is why it read as "*other* ships spinning
around". Fixed by servoing only the yaw component and preserving roll/pitch.

**4. `sin(tilt)` gain falls away past 90°** (`BuoyancySimulator.gd`).
`up.cross(Vector3.UP)` has magnitude `sin(tilt)`, which peaks at 90° and then
*decreases*. At 175° the gain is 0.087 — essentially zero. So a hull knocked
past horizontal got weaker correction the further it went and stayed capsized
forever. Added a backstop past 60° using a `1 - cos(tilt)` gain, which is 1.996
at 175°. Verified numerically.

Also fixed on the way: `EnemySpawner` set `enemy.global_rotation.y = randf()`
*after* `add_child`. Assigning one Euler component to a RigidBody3D decomposes
and recomposes the whole basis, folding any existing roll/pitch back in instead
of clearing it. Replaced with a single explicit `Transform3D(Basis(UP, yaw),
pos)` assignment plus a velocity reset. `BossShip` was also missing
`can_sleep = false`, so a settled boss would stop receiving buoyancy entirely.

**Validation:** `.capture_v6/0060_t1.00s.png` — all ships upright and level.
`.capture_v6/0720_t12.00s.png` — player ship and open-water enemies upright.

**Remaining:** ships that sail into island terrain still end up beached and
tipped. That is AI navigation (no obstacle avoidance), not buoyancy — tracked
separately as V8. Needs a human to confirm sailing feel.

---

## V2 — Camera clips inside the hull `[~]`

**Found by screenshot, not reported.** By t=12s (`.capture/0720_t12.00s.png`)
the camera ended up *inside* the player ship's hull, frame filled with
backfaces.

**Root cause:** `CameraRig.tscn`'s `SpringArm3D` had `collision_mask = 3` —
layers 1 (player ship) **and** 2 (enemy ships). The rig rides at the target's
origin (`EYE_HEIGHT = 0.0`), so the arm's 1.5-radius sphere starts *inside* the
followed ship's own collision shape, collides immediately, and collapses the
arm to ~0.

The mask was 3 because someone wanted the camera to avoid islands — but
`Island.tscn`'s `StaticBody3D` declared no `collision_layer` at all and so
defaulted to layer 1, indistinguishable from the player ship.

**Fix:** islands moved to `collision_layer = 17` (layer 1 so ships still collide
with them, plus layer 5 "terrain"); spring arm masks layer 5 only. Plus
`CameraRig._exclude_target_from_spring_arm()` excludes the followed body by RID,
so the fix survives a ship changing layers later.

**Validation:** `.capture_v6/0720_t12.00s.png` — camera outside the hull, full
ocean view. Collision matrix re-checked: ships still collide with islands,
camera collides with terrain only.

---

## V3 — Island / ship colours `[x, not a bug]`

**Ruled out by screenshot.** At t=3s and t=7s the islands and ships render with
correct, consistent Kenney palette colours — sand, green palms, wood hulls,
white sails. There is no random-colour problem in the current build.

The earlier "completely random colours" report appears to have been the frame-2
capture, where the camera is still mid-transition and the scene is seen against
an empty sky before the ocean is in view — alarming, but a camera timing
artefact, not a colour bug.

Also ruled out on the way: the `KHR_texture_transform` on the Kenney models is
identity and the raw mesh UVs already address the correct atlas swatch
(`patch-sand.glb` UVs at u=0.969, v=0.825–0.925). Texture sampling was never
broken.

The colour work already in the working tree (shader `light()` PI/albedo-squared
fixes, `tint_strength` defaulting to 0) is what made this correct — that part
was a real fix.

---

## V4 — Sky is a permanent sunset `[~]`

**Confirmed by screenshot**, but the cause was **not** what source-reading
suggested.

The initial diagnosis — "`EnvironmentController` overwrites the sky every frame,
and `sky_horizon_noon` is orange" — was only half right. Correcting those
colours alone left the horizon just as orange in the re-capture.

**The actual dominant cause was fog.** `World.tscn` authored
`fog_light_color = Color(0.9, 0.72, 0.52)` — a warm sunset orange — and nothing
in the codebase ever updated it, so it tinted the entire distance at every time
of day regardless of what the sky did. `ground_horizon_color` had the same
problem.

**Fix:**
- `sky_horizon_noon` → pale daylight blue; `sky_horizon_morning` → soft warm
  grey (was peach, reading as a second sunset). Only morning/evening are warm now.
- All sky/ambient keyframes pinned explicitly in `EnvironmentSettings.tres`, so
  the resource is the single source of truth rather than half-falling-through to
  script defaults.
- `EnvironmentController` now also drives `ground_horizon_color` and
  `fog_light_color` from the same computed horizon colour, so the three can no
  longer disagree.

**Decision recorded:** `EnvironmentController` + `EnvironmentSettings.tres` win.
`World.tscn`'s authored sky values are only the frame-0 seed.

**Validation:** `.capture_v6/0060_t1.00s.png` — clean blue gradient, proper
horizon, no orange anywhere.

---

## V5 — `Parameter "material" is null` at startup (×4) `[x]` RESOLVED (M9, real root cause traced)

Four of these were emitted during startup from the renderer
(`material_casts_shadows`, `material_is_animated`,
`material_get_instance_shader_parameters`, `material_update_dependency`).

**Previously recorded as resolved as a side effect of V2** — believed to be the
camera spring arm's shape cast querying ship hull geometry, with a full capture
run reported as "0 errors."

**Reopened 2026-08-26,** then **resolved for real in M9.** The V2/camera fix was
confirmed still correctly in place and was never the actual explanation. Traced
via ~15 fast headful reproductions (`godot -s` loading `World.tscn` or pieces of
it directly, quitting after ~10 frames instead of running the full capture),
disabling/removing whole subsystems one at a time from a live scene: ambient
encounters off, `EnemySpawner.initial_enemies = 0`, `CameraRig` removed,
`Systems` (all managers) removed, `WorldUI` removed, `Islands` removed,
`Enemies` removed — the 4 errors persisted through every one of those. Only
`Ocean` + `PlayerShip` remained, and even that pairing only reproduced when
loaded through the real `World.tscn`, not a synthetic recreation — pointing at
something in `World.gd`'s own `_ready()`. **Actual cause:** `World.gd` calls
`SaveManager.call_deferred("load_game")`; confirmed by moving the real save file
aside (0 errors) and restoring it (4 errors, reproduced twice). When a save
exists, `load_game()` reassigns `player.ship_stats` to the saved active ship
(`SaveManager.gd`); `ShipController.ship_stats`'s setter emits
`ship_stats_changed` once the ship is in the tree (true by then), re-triggering
`ShipVisuals._rebuild_model()` a second time — freeing and rebuilding the hull
model on a frame after its first, correctly-materialed build has already been
submitted for that frame's render. The renderer's dirty-material sync catches
the old/new model mid-swap during that one transition. **Confirmed harmless:**
every captured frame (including the very first) shows the ship correctly
modeled; no test failure, no visible glitch. Documented rather than fixed —
restructuring `ShipVisuals`/`KenneyMaterialApplier`'s rebuild timing for a
one-time cosmetic log line is disproportionate. Full detail:
`docs/05_CURRENT_SYSTEMS.md` D32.

Note the earlier guard added in `KenneyMaterialApplier` against assigning a null
override was already measured as **not** what fixed this the first time (count
unchanged at 4 with the guard alone) — that finding still stands, and is now
fully explained: the null material was never inside `KenneyMaterialApplier` at
all. It is left in place as defensive-only, with a comment saying so.

---

## V6 — `ManOWar.tres` exceeds its authored export range `[x]`

`resources/ships/ManOWar.tres` set `stability_torque_multiplier = 25.0` against
`@export_range(0.0, 20.0)`.

The authored ships form a deliberate ladder scaling with hull size (Dinghy 8 →
Sloop/Schooner 10 → Corvette 11 → Brigantine 12 → Frigate 15 → Galleon 20 →
ManOWar 25), so 25 is intentional design and the **range** was what was wrong.
Widened to `0.0, 30.0`. Out-of-range values load fine at runtime, so this was
never silently dropped — but the inspector would have snapped it to 20 the first
time anyone opened ManOWar in the editor.

---

## V7 — Two ship models have no texture `[ ]`

Of the 74 models in `assets/models/`, 72 are stock Kenney (1 material, 1 embedded
`colormap` image, `baseColorTexture` present). **Two are not:**

| Model | Materials | Images | Textured |
|---|---|---|---|
| `ships/pirate-sloop-lvl1.glb` | 6 | 0 | 0 |
| `ships/pirate-fleet-standard-l2.glb` | 8 | 0 | 0 |

These carry colour purely in `baseColorFactor` (`hullWood`, `sailCanvas`,
`flagCrimson`, …). They therefore depend on `KenneyMaterialApplier`'s
`base_albedo` path while every other model depends on the texture path — so any
change to the applier affects the two groups differently.

`pirate-sloop-lvl1.glb` **is** referenced — it is `Sloop.tres`'s `model_path`,
and Sloop is the default enemy ship. So this is active, not latent as previously
recorded. It renders acceptably in captures, so it is cosmetic-risk rather than
a visible defect right now.

---

## V8 — Ships beach themselves on islands `[ ]`

**Found by screenshot.** Enemy ships sail into island terrain, ride up the
collision cylinder (which sits at `y = +2.0`, above the waterline) and end up
stranded and tipped over. The buoyancy fixes in V1 cannot help — the hull is
resting on static geometry, not floating.

`EnemyAI` steers straight at its target with no obstacle avoidance
(`scripts/combat/EnemyAI.gd` — `set_input(throttle, turn)` from a simple
cross-product heading error). Needs either avoidance steering or a
repulsion/no-sail radius around islands.

---

## V9 — HUD layout defects `[x]` RESOLVED (M9)

Both found by screenshot, neither reported.

**Overlapping top-right text.** `_create_notoriety_label()` used
`PRESET_TOP_RIGHT` plus a manual `position.x -= 300` nudge, which anchored only
the label's *left* edge to the screen edge — so the text both ran off the right
of the screen and printed on top of the resource bar. Replaced with a
right-aligned, explicitly-offset rect that grows leftwards, positioned below the
bar.

**Reopened 2026-08-26,** then **resolved for real in M9.** The hardcoded-offset
fix above never reliably cleared `ResourceBar`. Replaced with a `TopRightPanel`
`VBoxContainer` (`WorldHUD.tscn`) holding `ResourceBar`, the notoriety label, the
Captain's Log button, and the World Map button as siblings — Godot's own
container layout, not a second hand-typed constant, now guarantees none of them
can overlap regardless of `ResourceBar`'s actual rendered height. A first
version of this fix cleared the original resource-bar/notoriety-label overlap
but introduced a *new* one (notoriety label vs. the Log button, still on its own
independent hardcoded offset) — caught by a follow-up fresh `CaptureHarness`
capture, not by the new GUT test alone (`tests/test_world_hud_layout.gd`
originally only checked the one pair the bug report named). Fixed by moving the
Log button into the same container; the test now checks all three pairwise.
Validated: fresh headful captures at t=0.00s/1s/3s/7s/12s with real gameplay
values (non-zero notoriety, populated resource bar) show no overlap between any
of the four top-right HUD elements. Full detail: `docs/05_CURRENT_SYSTEMS.md`
D36.

**Announcement banner ran off screen.** `announce_event()` used `PRESET_CENTER`,
which anchors a zero-width rect at the centre, so a 42px message grew rightwards
off the frame — "While you were away: your empire kept running (78 ticks)" was
cut off mid-sentence. Replaced with a full-width wrapping rect. Its tween also
faded `modulate:a` from 1.0 *to* 1.0 (a no-op "fade in", so the banner popped);
it now starts transparent and actually fades.

**Still true today, no regression** — the banner is fully on screen, centred,
and fades in. **But it's a new problem now (see V13):** at full width and no
panel it renders as a giant unframed red wall of text over the 3D world.
Fixing "off-screen" wasn't the same as fixing "looks designed."

**Validation:** `.capture_v6/0060_t1.00s.png` — banner fully on screen and
centred; resource bar and notoriety no longer overlap **(superseded — see the
2026-08-26 reopening above; that capture predates the regression or never
actually caught it).**

---

## V10 — Missing `icon.svg` `[x]`

`project.godot` set `config/icon="res://icon.svg"` but the file did not exist,
so every launch logged `ERROR: Error opening file 'res://icon.svg'`. Added a
project icon rather than removing the setting, since an exported build needs one.

---

## V11 — Double-click launcher never worked `[x]`

`Play Pirate Empire.cmd` was added earlier in the session but **never actually
verified to launch** — it was assumed working. It had two separate defects, and
it failed silently on both:

**1. Unix line endings.** The file was written with LF only (measured: 0 CR, 60
LF). `cmd.exe` cannot parse an LF-only batch file — it eats the first character
of every line, so `setlocal` ran as `etlocal`, `REM` as `M`, and so on. Fixed by
rewriting as CRLF, and a `.gitattributes` now pins `*.cmd`/`*.bat` to
`eol=crlf` so a future checkout cannot silently reintroduce it.

**2. Trailing backslash swallowed the closing quote.** `%~dp0` always ends in
`\`, so `--path "%PROJECT%"` expanded to `"D:\Pirate-game\"` — the `\"` escapes
the quote and Godot reported `Invalid project path specified: "D:\Pirate-game""`.
Fixed by stripping the trailing backslash before use.

**Validation:** launcher run from its double-click path starts the engine
cleanly — `Godot Engine v4.7.1.stable`, Vulkan Forward+ on the RTX 4060,
gameplay running, no errors. Confirmed by process check (PID alive, 659 MB).

Note this is **not** a packaged `.exe`. Building one needs Godot's export
templates, which are not installed on this machine (no `export_templates` dir,
no `export_presets.cfg`) — that is a ~1 GB download plus export configuration.

---

## V12 — Ship spawns black on load, no error anywhere `[~]`

**Found by screenshot, not reported.** A fresh headful `CaptureHarness` run (M7.5 stabilization
pass, 2026-08-25) rendered correctly at t=0/1/3s, then the entire 3D viewport went solid black
from ~t=4s onward and stayed black through t=12s — while the HUD kept updating normally the whole
time (resource bar, notoriety label, and a combat-ability reload percentage visibly advancing from
13% to 48%, proving the game logic was still running fine underneath).

**Wrong theories, disproved by measurement, in order tried:**
1. *"The day/night cycle is running too fast and it's just gone to night."* Disproved by printing
   `EnvironmentController.current_time`/sun energy/sun color every capture frame: the sun was
   getting *brighter* (`0.950 → 0.960`) the entire time, not dimmer.
2. *"The camera lost its active flag, or the WorldEnvironment/sky broke."* Disproved the same way
   — `get_viewport().get_camera_3d()` returned the same valid camera every frame, and
   `WorldEnvironment`'s background mode/ambient energy/sky reference never changed.
3. *"An ambient encounter or the in-battle upgrade screen started and paused the game."* Disproved
   by `EncounterManager.is_active()` staying `false` throughout, and by the reload-percentage HUD
   readout visibly advancing — `UpgradeChoiceScreen`/a paused tree would have frozen that number.

**Actual root cause:** printing the camera's own `global_position` (not just whether it existed)
showed it collapsing toward the tracked ship's height and staying there — the `SpringArm3D` had
collided with something close and stayed collapsed. Printing the *ship's* `global_position` showed
it sitting at almost exactly `(0, -2.49, 0)` — the game's authored spawn is `(0, 0.3, 40)`, 40
units clear of Port Royal. A stale `user://save_data.json` (left over from a prior session's
verification run, with `"player": {}` — no position ever recorded) explained it:
`SaveManager.load_game()` defaulted a missing position to `Vector3(0, 1, 0)`, which is Port
Royal's own island origin now that M7 made it the home island. The ship loaded embedded in the
island's terrain; the camera's spring arm (collision mask includes terrain, V2) collapsed into
that same terrain from point-blank range, filling the frame with unlit close-up geometry.

**Fix:** `SaveManager.gd` — `save_game()` no longer writes a `"player"` key at all when no
`player_ship` exists to read from; `load_game()` only restores position/rotation when the save
actually recorded `pos_x`. Full detail: `docs/05_CURRENT_SYSTEMS.md` D64,
`.kiro/specs/milestone-m7.5-stabilization/`.

**Validation:** re-ran the identical capture with the same corrupting save still on disk after the
fix — world renders normally through t=12s (ship sailing away from Port Royal under fire, full
lighting, wake/smoke particles, no camera collapse).

---

## V13 — "While you were away" banner has no frame `[x]` RESOLVED (M9)

**Found by screenshot, 2026-08-26.** `announce_event()`'s label renders as
large, raw red text with no background panel, no border, no styling consistent
with the rest of the HUD — it cuts directly across the 3D world and the island
geometry behind it. V9 fixed the banner running off-screen; it never addressed
how it actually looks once on-screen. Reads as a debug print, not a moment the
game wants the player to feel good about — especially since Higgins has an
in-fiction line for the exact same moment one panel down, which the banner
visually steamrolls. **Resolved (M9):** `announce_event()` now wraps its label
in a themed `PanelContainer` (dark-navy `StyleBoxFlat`, gold border, matching
`PauseMenu`/`DeathScreen`), with a new `is_warning` parameter defaulting the
color to gold/cream — the original alarm-red is now opt-in for genuine
warnings only. Validated: a fresh capture's "While you were away" banner
renders as a framed panel, not raw text over the 3D world. Full detail:
`docs/05_CURRENT_SYSTEMS.md` D68.

---

## V14 — Tutorial dialogue and the combat HUD render stacked, uncoordinated `[x]` RESOLVED (M9)

**Found by screenshot, 2026-08-26.** In the same capture, the Higgins tutorial
dialogue box sits directly on top of the "STARBOARD CANNONS / RELOADING 48%"
combat panel, which is visibly bleeding through underneath it — while actual
cannonfire is happening in the background (confirmed in the run's own log
output: `fire_cannons` called with zero player input, from an ambient
encounter). Nothing in `WorldHUD.gd` arbitrates which of tutorial
dialogue / combat HUD / ambient-encounter feedback should have visual priority.
**Resolved (M9):** `WorldHUD.gd` dims `CannonsContainer` (`modulate.a = 0.35`)
while `TutorialDialogue` is visible, via its `visibility_changed` signal.
`EncounterManager._start_random_ambient()` now checks a new
`TutorialDialogue.is_blocking()` gate and returns early while a tutorial
dialogue is open — a second boolean gate alongside the existing
`required_chapter_id` check, not a general focus-stack system. Full detail:
`docs/05_CURRENT_SYSTEMS.md` D69.

---

## V15 — Settings and Credits screens are unthemed `[x]` RESOLVED (M9)

**Found by source read, confirmed by grep, 2026-08-26.** Every other screen in
`scenes/ui/` (MainMenu, IslandMenu, DeathScreen, PauseMenu, CaptainsLog,
RaidReportScreen, TutorialDialogue, UpgradeChoiceScreen, WorldHUD) calls
`PirateThemeBuilder.build()`. `SettingsMenu.gd` and `CreditsScreen.gd` do not —
zero matches for `PirateThemeBuilder` in either file. `SettingsMenu.tscn` has
no background panel at all, just a bare `Control` + `TabContainer`, so it
renders as raw default-grey Godot UI. The single most-visited non-gameplay
screen (everyone checks Settings at least once) looks like a different,
unfinished game bolted onto the themed one. **Resolved (M9):** both scripts now
apply `root_control.theme = PirateThemeBuilder.build()` in `_ready()` (their
`CanvasLayer` roots can't carry a theme directly, matching `MainMenu.gd`'s
existing pattern), and both `.tscn`s gained a `ColorRect(0,0,0,0.7)` background
overlay copied from `PauseMenu.tscn`. No settings-functionality regressions —
`tests/test_settings_menu.gd` still passes unchanged. Full detail:
`docs/05_CURRENT_SYSTEMS.md` D70.

---

## V16 — MainMenu has no typographic hierarchy `[x]` RESOLVED (M9)

**Found by source read, 2026-08-26.** `MainMenu.tscn`'s `TitleLabel` ("PIRATE
EMPIRE") and `SubtitleLabel` have no `theme_override_font_sizes` and no
`label_settings` — they render at the theme's default body size (15px),
identical to a tooltip, for the game's own title on its own main menu.
Separately, in the same five-button `VBoxContainer`:
`ContinueButton`/`NewGameButton`/`SettingsButton` are explicitly sized to 28px,
but `CreditsButton`/`QuitButton` are not — and only those same two carry an
emoji prefix ("📜 Credits", "✖ Quit") the other three don't. Three
inconsistencies stacked in one menu. There's also a `VignetteOverlay`
`ColorRect` authored at `Color(0,0,0,0)` (fully transparent) that
`MainMenu.gd` never references — dead, no-op decoration. **Resolved (M9):**
`TitleLabel` → 56px, `SubtitleLabel` → 20px (title > subtitle > buttons
hierarchy); `CreditsButton`/`QuitButton` now carry the same 28px override as
the other three, with their emoji prefixes stripped to match; `VignetteOverlay`
deleted (confirmed zero code references first). `MainMenu.gd`'s navigation
logic untouched. Full detail: `docs/05_CURRENT_SYSTEMS.md` D71.

---

## V17 — IslandMenu's main panel is a fixed 600×400px box `[x]` RESOLVED (M9)

**Found by source read, 2026-08-26.** `IslandMenu.tscn`'s `Panel` node sets
`custom_minimum_size = Vector2(600, 400)` — a hardcoded pixel size, not
responsive anchoring, for what `docs/05_CURRENT_SYSTEMS.md` calls "the largest
UI file in the project" (6 tabs: Buildings/Shipyard/Tavern/Fleet/Research/
Trade) in a project whose `AGENTS.md` states the platform is mobile-first. A
fixed desktop-monitor box on the game's single most-used management screen.
**Resolved (M9):** removed the `CenterContainer` wrapper (which ignored its
child's anchors entirely, silently defeating any anchor-based fix) and
reparented `Panel` directly under the root `Control`, with
`anchor_left/top = 0.1`, `anchor_right/bottom = 0.9`, and a
`Vector2(480, 320)` minimum-size floor for narrow viewports.
`IslandMenu.gd` resolves every node via `%UniqueName`, so the reparent needed
no script changes; all six tabs already used `SIZE_EXPAND_FILL` with no
fixed-width assumption. Tier/ownership gating logic unchanged. Full detail:
`docs/05_CURRENT_SYSTEMS.md` D72.

---

## Wrong turns (kept deliberately, so they are not repeated)

1. **"The stability torque axes are swapped."** Wrong. The axis was correct;
   only the sign was inverted. Caught by deriving the torque numerically.
2. **"The shader ignores `uv1_scale`/`uv1_offset`, so every surface samples the
   wrong palette swatch."** Wrong. The `KHR_texture_transform` is identity and
   the UVs were already correct. Caught by parsing the GLB binary.
3. **"The null material comes from `KenneyMaterialApplier` assigning null."**
   Wrong. Guarding it left the error count unchanged at 4. It was actually the
   camera spring arm (V2). Caught by measuring before and after.
4. **"The permanent sunset is the sky colours."** Half right, and the half that
   was wrong was the half that mattered — correcting every sky keyframe left the
   horizon just as orange, because the real cause was an un-animated orange
   `fog_light_color`. Caught by re-capturing instead of trusting the edit.

5. **"The launcher works."** It never did — it was written and reported as done
   without once being run (V11). It failed on the very first line of the file.
   Caught only by actually executing it and reading the output.
6. **"The world went black because of the day/night cycle / camera state / an
   encounter starting."** All three (V12) were disproved the same way, in
   order, by printing the actual values instead of reasoning about what a
   plausible cause would look like — the sun was getting brighter, the camera
   object was valid, no encounter was active. The real cause (a stale save
   defaulting the ship's position into the home island's own collision) only
   surfaced once the *ship's and camera's own position* were printed, not just
   whether the systems around them looked healthy.

7. **"V5 and V9 are fixed."** Both were marked resolved on the strength of one
   validating capture each. Both reproduced cleanly on a completely fresh run
   nine days later (2026-08-26), with no code changes to those systems in the
   interim that would explain a regression — meaning the original "fix"
   probably never fully held, and the one validating capture that seemed to
   confirm it was not sufficient evidence. One passing screenshot is not the
   same claim as "always passes." Re-verify on every subsequent capture run
   that touches anything nearby, not just once at fix time.
8. **Wrong turn #3 above, itself wrong.** "It was actually the camera spring
   arm" was believed correct for months (V2's fix genuinely explained the
   symptom at the time). M9's re-diagnosis of the reopened V5 removed
   `CameraRig` entirely from a live `World.tscn` load — the 4 errors persisted
   unchanged. The spring-arm explanation was never re-tested after being
   accepted; it happened to correlate with a fix that was correct for a
   *different* reason (D31's collision-mask change was still worth having,
   just not for this). The real cause, found only by systematically removing
   whole subsystems one at a time from a live scene until the error
   disappeared: a save-triggered second `ShipVisuals._rebuild_model()` call
   racing the renderer's first-frame sync (`docs/05_CURRENT_SYSTEMS.md` D32).
   A "fix" that correlates with a symptom going away is not the same claim as
   "explains why it happened" — re-derive the mechanism, don't just note that
   changing something nearby made the symptom stop.
9. **"The resource-bar/notoriety-label fix is done" (M9, first pass).** The fix
   (wrapping both in a shared `VBoxContainer`) was verified by a new GUT
   property test and looked correct in isolation — but a follow-up headful
   capture showed the notoriety label now overlapping the Captain's Log
   button instead, because the Log button still used an independently
   hardcoded offset calibrated against the label's old position. The GUT test
   only asserted the two elements the original bug report named; it had no
   way to catch a *different* pair overlapping. Caught by re-capturing after
   the fix, not by trusting the passing test — the same discipline #7 above
   already named, just one layer more specific: a passing test only proves
   what it actually asserts, not that the whole layout cluster is clean.

The pattern in all nine: a plausible story that a two-minute measurement
disproved. **Measure first, and re-measure after the fix** — six of these were
only caught because a fix (or a healthy-looking system) that "should have
explained it" visibly didn't, one because a deliverable that was never run
was assumed to work, and two (V5/V9, both on their M9 re-fix) because
"validated once" — by one capture, or by one test scoped to the original
report — was treated as "fixed forever" or "fixed completely."

A note on how V11 stayed hidden: two earlier attempts to verify it used
`Start-Process` and concluded "FAILED — no Godot process", which was a false
negative from process timing. Only running the command synchronously and reading
its **stdout** revealed the actual errors. When a check reports failure, confirm
the check itself works before trusting or dismissing the result.

Also worth recording: V1 had **four** independent causes. Each fix was correct
and each one alone left the bug fully visible. A symptom that survives a
verified-correct fix is evidence of an additional cause, not of a wrong fix.

---

## Verification

GUT suite after all the above: **103 tests, 102 passing, 1 failing** — the one
failure is `test_property_21_lod_distance_transitions`, the known/accepted
pre-existing gap documented in `CLAUDE.md`. Baseline restored.

`test_camera_properties.gd` Property 2 needed updating alongside V2: it created
its obstacle on `collision_layer = 3` with a comment pinning it to the spring
arm's old mask. The assertion (camera pulls in for obstructions) is still the
right property; only the layer number was stale.

Per `CLAUDE.md`, camera feel and shader appearance cannot be fully verified
headlessly — but the screenshot harness gives real rendered evidence, which is
how every item above was confirmed or ruled out.

## 2026-08-26 presentation audit

Ran `CaptureHarness` fresh (see V5/V9 reopenings above) and added V13–V17 from
direct source reading against what the captures showed. Full narrative
findings and the resulting roadmap change (new milestone **M9 — Presentation
Pass**): `docs/15_MASTER_PLAN.md` §8. Ledger entries: `docs/05_CURRENT_SYSTEMS.md`'s
"Presentation audit (2026-08-26)" section (D32, D36 reopened; D68–D72 new).
`docs/14_SYSTEM_INVENTORY.md` §7.7 mirrors the same table. This tracker's own
GUT-suite verification above (103/102) is stale — see
`docs/14_SYSTEM_INVENTORY.md` §0 for the current baseline (324/323); this pass
did not run the suite, since none of V5/V9/V13–V17 are asserted by any test.

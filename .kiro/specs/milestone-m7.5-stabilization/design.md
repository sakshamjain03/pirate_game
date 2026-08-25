# Design Document — M7.5 Stabilization Pass

## How these were found

Not by reading code, and not by the GUT suite (which stayed green the entire time both defects
were live — it asserts no rendered-frame state at all). Both came from actually running the game:

```
<godot-binary> scenes/debug/CaptureHarness.tscn --capture-dir=<abs path>
```

Run **headful** (no `--headless` — the dummy renderer produces blank images) with **zero player
input**. This boots straight into `World.tscn` and screenshots the real rendered viewport at
t=0/1/3/7/12s. Note the argument convention: pass `--capture-dir=...` **without** a `--`
separator before it — `ScreenshotCapture.gd` reads it via `OS.get_cmdline_args()`, and a `--`
separator was observed to make the game ignore it silently (the harness would run to completion
but never write a single frame). This is worth recording since the harness's own header comment
suggests `--`.

D64 was root-caused by temporarily instrumenting `scripts/debug/ScreenshotCapture.gd` (already a
throwaway debug harness, per its own header) with extra print statements covering: active camera,
`WorldEnvironment`/sky/ambient state, `EncounterManager.is_active()`, the day/night controller's
`current_time`/sun energy/color, and the `CameraRig`'s target/position/pitch plus the tracked
ship's own position/freeze-state/velocity. Every environmental/lighting value was reported
completely healthy the whole time; the ship's own `global_position` was the value that didn't
match its authored scene spawn. That pointed at `SaveManager.load_game()`, and a real save file
found in `user://save_data.json` (created by the prior session's own verification pass) confirmed
it: `"player": {}`. The extra instrumentation was reverted once the root cause was confirmed —
`ScreenshotCapture.gd` is back to its original form.

---

## D64 — save/load position default

### The bug

```gdscript
# SaveManager.gd, load_game(), before this pass
if data.has("player"):
    var player_data = data["player"]
    var player = get_tree().get_first_node_in_group("player_ship")
    if player and is_instance_valid(player):
        var pos = Vector3(
            player_data.get("pos_x", 0.0),
            player_data.get("pos_y", 1.0),
            player_data.get("pos_z", 0.0)
        )
        player.global_position = pos
```

`data.has("player")` is true whether `player_data` is a real recorded position or an empty `{}`.
`save_game()` produced the empty case whenever it ran with no `player_ship` in the tree:

```gdscript
# SaveManager.gd, save_game(), before this pass
var save_dict = { "player": {}, ... }
var player = get_tree().get_first_node_in_group("player_ship")
if player and is_instance_valid(player):
    save_dict["player"]["pos_x"] = player.global_position.x
    ...
```

`Vector3(0, 1, 0)` used to be a harmless default — nothing was ever near the world origin. M7's
`_seed_port_royal_as_home()` didn't create this defect, but it made the default dangerous: Port
Royal sits at `(0, 0, 0)` with a ~13.7-unit collision union (per the D25 comment in
`scenes/world/World.tscn`), so `(0, 1, 0)` is now *inside the home island's own terrain*.

### The fix

Two independent, mutually-reinforcing guards — either alone would fix the observed symptom, both
together close the actual defect class (a save silently missing a section vs. a save with a real
empty section becoming indistinguishable):

1. **`save_game()`**: don't write the `"player"` key at all unless a real player was found.
   ```gdscript
   var save_dict = { "economy": {}, ... }  # no "player" key up front
   var player = get_tree().get_first_node_in_group("player_ship")
   if player and is_instance_valid(player):
       save_dict["player"] = {}
       save_dict["player"]["pos_x"] = player.global_position.x
       ...
   ```
2. **`load_game()`**: only apply position/rotation when the save actually recorded one.
   ```gdscript
   if player_data.has("pos_x"):
       var pos = Vector3(player_data.get("pos_x", 0.0), ...)
       player.global_position = pos
       player.global_rotation.y = player_data.get("rot_y", 0.0)
   ```
   Everything else under the `player` key (`damage`, `health`, `captain_id`) is unaffected — this
   only gates the transform restore.

### Why the symptom looked like a rendering bug

The camera never lost its target, its `current` flag, or its environment — confirmed by
instrumented diagnostics that were all normal for the entire 12-second capture. What actually
happened: the ship's position landed inside the island's terrain, and `CameraRig`'s
`SpringArm3D` (collision mask includes terrain layer, per D31) collapsed toward that terrain,
pinning the camera at the ship's own height, aimed steeply down into the hull/ground. The HUD is a
separate `CanvasLayer` drawn independently of the 3D viewport, so it kept updating normally the
whole time — which is exactly why the symptom read as "the world vanished, the UI didn't."

---

## D65 — Chapter 4/5 bosses unreachable

### Constraint check before implementing

`EncounterData.Kind.BOSS` already exists and both `IntransigentBoss.tres`/`CardenasBoss.tres`
already use it with dedicated (non-shared) `ShipStats`/scenes — verified necessary in the M7 pass,
not redone here. The only missing piece is *how a normal player's ambient encounter draw can
reach them, gated to the right chapter*.

### Design

`EncounterData` gains one field:

```gdscript
## Empty = always eligible for the ambient scheduler. Non-empty gates this
## encounter to only draw while CampaignManager reports that chapter current.
@export var required_chapter_id: String = ""
```

`CampaignManager` gains one public helper, mirroring its existing `is_chapter_completed()`:

```gdscript
func is_chapter_current(chapter_id: String) -> bool:
    if chapter_id.is_empty():
        return true
    var chapter := _current_chapter()
    return chapter != null and chapter.chapter_id == chapter_id
```

`EncounterManager._start_random_ambient()` filters candidates through it:

```gdscript
func _start_random_ambient() -> void:
    if encounter_pool.is_empty():
        return
    var candidates: Array[EncounterData] = []
    for e in encounter_pool:
        if e and CampaignManager.is_chapter_current(e.required_chapter_id):
            candidates.append(e)
    if candidates.is_empty():
        return
    start_encounter(candidates.pick_random())
```

Content: `IntransigentBoss.tres.required_chapter_id = "ch4_the_admirals_gambit"`,
`CardenasBoss.tres.required_chapter_id = "ch5_the_silver_fleet"`. Both added to
`World.tscn`'s `EncounterManager.encounter_pool` (previously only the 6 non-chapter-gated
encounters).

### Why this and not a location trigger

Chapter 4's opening beat says "I will be at Frostbite Reef" — a location-anchored spawn (only
within some radius of a named point) would read better than a floating ambient chance. That needs
a waypoint/location concept the game doesn't have yet — M9 already owns discovery/fog/the world
map, which is the natural home for it. Gating by chapter alone is the smallest change that makes
the fight reachable *at all* today; noted as a follow-up in `docs/05_CURRENT_SYSTEMS.md` rather
than built here, per this project's own "flag it, don't silently scope-creep" precedent (see
M4/M5's spec notes for the same discipline).

### Why the ambient pool and not a new trigger system

`EncounterManager` already has exactly the mechanism needed — a pool it draws random members from
on a timer, already excludes members that can't currently fire in spirit (nothing currently does
this, but the mechanism generalizes trivially). Adding a second, boss-specific scheduling path
would be the "never duplicate systems" failure this project's own `AGENTS.md`/`docs/05_...md`
repeatedly flags.

---

## Verification

Standard command:
```
<godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Baseline entering this pass: 320 tests / 319 passing. After: **323 / 322**, same one known LOD
failure. Also re-ran the headful `CaptureHarness` capture with the same previously-corrupting save
still on disk and confirmed the world renders normally at t=7s/t=12s (screenshots: ship sailing
away from Port Royal, full lighting, no camera collapse).

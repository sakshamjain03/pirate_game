# Design Document: Milestone M29 — Stabilize & Wire

## 1. Why this design shape

Nothing in M29 is a new system. Every fix does one of three things:
- connects an existing signal that nothing listens to (`world_event_triggered`, `enemy_destroyed`,
  `boarding_resolved`)
- moves a literal into an existing data pattern (`@export` on `FactionData`/`ShipStats`, a new
  `Resource` like the existing `*Data` family)
- adds a guard at an existing integration point

The three lint tests turn whole bug classes that have shipped before into test failures: silently
dropped `.tres` keys (D3/D14), save sections that don't round-trip, and dead signals.

**Signals over direct calls:** `FactionManager` reacts to combat; combat never calls
`FactionManager`. `WorldHUD` reacts to `EventManager` and `EncounterManager`; neither of them
reaches into the HUD. The drafted `get_node("WorldHUD")` call inside `EncounterManager` is replaced
by an `encounter_failed` signal.

## 2. New/changed files

| File | Lane | Change |
|------|------|--------|
| `scripts/combat/BoardingSystem.gd` | A | grant loot once, mark the target `loot_claimed`; use `LootScaling` helper |
| `scripts/world/ShipController.gd` | A | `_on_died` skips `_spawn_loot` when `loot_claimed`; use helper |
| `scripts/world/ShipCombat.gd` | A | zero-crew guard in `_spawn_cannonball`; bounded reload penalty; life-generation guard on reload and ripple callbacks; drop dead target lock |
| `scripts/world/ShipStats.gd` | A | `@export min_crew_fire_rate_mult = 0.25`, `max_reload_seconds = 40.0` |
| `scripts/combat/LootScalingData.gd` (new) + `resources/combat/LootScaling.tres` (new) | A | data + `static func multiplier(class_crew, notoriety) -> float` |
| `scripts/combat/EncounterManager.gd` | A | `_validate(data) -> String` (empty = ok); `signal encounter_failed(encounter_id, reason)` |
| `scripts/combat/EncounterData.gd` | A | `time_limit` range cap 3600 |
| `scripts/managers/FactionData.gd` | B | 7 `@export`s (§4) + 2 art seams (F1) |
| `resources/factions/*.tres` | B | empire factions set non-default values |
| `scripts/managers/FactionManager.gd` | B | signal handlers, event hunters, tribute from data, `get_island_owner_display()` |
| `scripts/managers/EmpireManager.gd` | B | `signal island_captured_from(island_id, previous_faction_id)`; raid odds × `raid_frequency_mult` |
| `scripts/world/Island.gd` | B | record the previous owner before reassigning (`:196`) and pass it to `notify_island_captured` |
| `scripts/managers/CampaignManager.gd` | C | `campaign_completed` state, signal, save; the final chapter triggers epilogue + celebration; free-roam display line |
| `resources/campaign/chapters/Ch2/Ch4/Ch5*.tres` | C | text fixes, Ch4 beat and objective, epilogue beats, portrait paths |
| `resources/world/Tortuga.tres`, `resources/buildings/Fortress_L1.tres`, `Watchtower_L1.tres` | C | text |
| `scripts/ui/CaptainsLog.gd` | C | free-roam line |
| `scripts/ui/WorldHUD.gd` | D (additive) | event banner host + queue; owner on dock prompt; free-roam objective line (reads C's API) |
| `scripts/ui/EventBanner.gd` + `scenes/ui/EventBanner.tscn` (new) | D | non-modal banner |
| `scripts/managers/EventAnnouncementData.gd` (new) + `resources/events/EventAnnouncements.tres` (new) | D | event name → `tr()` key + icon |
| `scripts/managers/EventManager.gd` | D | (only if D3 reproduces) schedule save data |
| `scripts/managers/SaveManager.gd` | D (additive) | (only if D3 reproduces) the `events` section + reset-list entry |
| `tests/test_lint_*.gd` (3 new) | D | §8 |
| `project.godot` `[rendering]` | E | explicit mobile renderer; tier-driven settings, if the probe justifies them |
| `scripts/tests/ScreenshotHarness.gd` / `CaptureHarness` | E | `--perf-log=` flag |
| `scripts/world/OceanController.gd`, a new `QualityTierData` resource | E | tier responses chosen from probe data |
| `docs/10_ASSET_REQUESTS.md`, `scripts/world/IslandData.gd` | F | request table; 2 seam `@export`s |

## 3. Lane A — combat

### 3.1 One loot grant (C-003)
**The bug.** `BoardingSystem.gd:131-133` adds the rolled loot to `ResourceManager`. Then `:140`
calls `enemy_dmg.mark_destroyed()`. That leads to `ShipCombat.died` → `ShipController._on_died()`
(`:378`), which calls `_spawn_loot()`: a second, independent roll.

**The fix.** Before `mark_destroyed()`, call `enemy_ship.set_meta("loot_claimed", true)`. In
`_on_died()`:
```gdscript
if not is_in_group("player_ship") and SceneManager.is_campaign():
    if not get_meta("loot_claimed", false):
        _spawn_loot()
    # notoriety block unchanged: applied once on both paths
```
Do not route the grant through `boarding_resolved`. The drafted design did that, but the signal
lives on the player's `BoardingSystem`, so the enemy's `ShipController` would have to connect to
the player's node.

**M-004 (re-looting a boss):** a sunk node is freed, so this is covered by the same flag plus the
existing despawn. Write the test anyway: board → respawn → assert no second grant.

### 3.2 Crew and reload (M-002, C-004, M-001)
- **`_spawn_cannonball()`:** return early when the parent's `ShipDamage.crew <= 0`. This one place
  covers every firing path (the manual, auto, ripple and chaser paths all end there; confirm with a
  grep).
- **`_start_cooldown()`:** today the code does `rate *= max(penalty, 0.1)`. Change it to:
  ```gdscript
  rate *= clampf(penalty, ship_stats.min_crew_fire_rate_mult, 1.0)
  var cooldown := minf(1.0 / maxf(rate, 0.01), ship_stats.max_reload_seconds)
  ```
- **Stale callbacks.** `SceneTreeTimer` has no `kill()` in 4.3, so the drafted design doesn't work.
  Use a life counter instead:
  - add `var _life_id := 0`
  - increment it in `_on_died()`/respawn and in any reset path
  - every deferred lambda captures `var my_life := _life_id` and returns if `my_life != _life_id`
    or the node is invalid

  The same guard covers the ripple callbacks (§3.4).

### 3.3 Loot scaling (C-005, BALANCE-002)
```gdscript
class_name LootScalingData extends Resource
@export var notoriety_divisor := 100.0
@export var class_multiplier_max := 3.0
@export var max_multiplier := 5.0
static func multiplier(max_crew: int, notoriety: float) -> float  # loads LootScaling.tres once (cached static)
```
Both call sites (`ShipController._spawn_loot` around `:471-478`, and `BoardingSystem`) are replaced
by this helper. The class-multiplier formula `max_crew / 8.0` keeps its `8.0` as another `@export`
(`crew_per_class_step`).

### 3.4 Encounters (C-006, C-015, C-019, M-005)
`start_encounter(data)`:
- **First:** `var reason := _validate(data)`. If it is not empty: `push_error`, `_restore_spawning()`,
  `encounter_failed.emit(data.encounter_id, reason)`, return `false`.
- **After spawning:** if `PROTECT_TARGET` and no escort node is valid, fail the same way. A spawned
  escort that fails to instantiate is the case validation alone can't catch.

The ripple guard is in `_fire_rippled_gun()`: `is_instance_valid(marker)`, the parent, and
`is_inside_tree()`, plus the life id.

## 4. Lane B — faction consequences

**New fields** on `FactionData`. All the defaults equal today's behaviour, so `.tres` files that
leave them out don't change:
```gdscript
@export_group("Consequences")
@export var sink_reputation_loss: int = 0          # empires set 5-10 in .tres
@export var boarding_reputation_loss: int = 0
@export var hunter_cooldown_seconds: float = 120.0
@export var tribute_cost_gold: int = 500           # was FactionManager.TRIBUTE_COST_GOLD
@export var tribute_cooldown_seconds: float = 300.0 # was TRIBUTE_COOLDOWN_SECONDS
@export var raid_frequency_mult: float = 1.0
@export_group("Art seams (owner-supplied, M31)")
@export var flag_texture_path: String = ""
@export var sail_texture_path: String = ""
```

**Wiring** goes in `FactionManager`. `EnemySpawner` and `BoardingSystem` are scene nodes, not
autoloads, so connect them when World is ready. Use the hook `FactionManager` already has for World
entry. If it doesn't have one, connect via `get_tree().node_added`, filtered by group/class. **Do
not hardcode a node path.**
- **`_on_enemy_destroyed(enemy)`:**
  - Skip if not campaign, if `enemy.get_meta("loot_claimed", false)` (boarded: the boarding path
    owns it), or if there is no `faction`.
  - Otherwise `add_reputation(id, -faction.sink_reputation_loss)`.
- **`_on_boarding_resolved(success, _loot, faction_id, _ship)`:** on success, apply the boarding
  loss, then `_try_event_hunter(faction_id)`.
- **Faction lookup.** Resolve the id through the same lookup `FactionManager` already uses for
  `reputation_scores`/`get_player_faction()`, or `ResourceLookup` if that's the project's resolver.
  **Never** use `"%s.tres" % id.to_pascal_case()` (the draft's suggestion: fragile). An unknown id
  → `push_error`.

**Who lost the island.**
- `Island.gd:196` sets `island_data.owner_faction = new_faction`. Read the old value first, then
  call `EmpireManager.notify_island_captured(island_id, prev_id)`. The new parameter defaults to
  `""`, so existing callers still work.
- `notify_island_captured` emits `island_captured(island_id)` unchanged, because it has 3
  subscribers: Campaign, Entitlement and Seasonal. It **also** emits
  `island_captured_from(island_id, prev_id)`.
- `FactionManager` connects only to the new signal.

**Hazard.** Check every Ch1-5 `CHANGE_REPUTATION` objective against the chapter's forced fights.
For example, Ch4 has a merchants'-trust objective; the Merchant Guild must keep
`sink_reputation_loss = 0`, or the convoy content must not force sinking Guild ships. Task B.5's
test asserts this.

## 5. Lane C — ending and free roam

**State.** Add `var campaign_completed := false`. It goes in `get_save_data()`, is read with a
default of `false`, and is reset by the existing New Game snapshot automatically.

**Trigger.** In `_complete_chapter(chapter)`: if no enabled chapter follows `chapter`, then
- set the flag
- `campaign_completed_signal.emit()`
- queue the celebration through `CelebrationQueue`

The epilogue beats are appended to the final chapter's closing beats in the `.tres`. They play
through the path that already plays closing beats, so there's no private `_show_queue()` call and
no new dialogue entry point.

**Epilogue content** (author it in the voice of the existing Ch1-5 beats; read them first):
1. **Higgins:** the fleet is taken, and what that means for the empire.
2. **Marguerite callback** to her Ch3 line about "building something bigger to lose".
3. **Higgins on Vane's chart:** the hook. It says outright that the story continues.

No generic "rest easy, Captain" filler. The draft's sample lines are rejected as off-voice.

**Free roam.**
- `get_display_objective()` (new, public) returns the current objective, or a free-roam line, for
  example "Your empire is yours. Raid, build, and sail the Maelstrom."
- `WorldHUD:1127/1154` and `CaptainsLog:73` currently call the private `_current_chapter()`. Move
  them to the public getter. That move is part of Lane D's additive edit for WorldHUD and Lane C's
  for CaptainsLog.

**Golden-path test.** Build a table that maps `ObjectiveData.Condition` → the `CampaignManager`
handler and its source signal. Read it out of `CampaignManager._ready()`'s connections. Then, per
objective, resolve the target id against the MVP content lists: islands from `IslandData` with
`content_enabled`, buildings from `resources/buildings`, bosses from encounter data, captains from
the 12-captain list. `SelfPlayHarness` (headless) is the separate end-to-end smoke test at the
checkpoint. This test is the cheap static guard.

## 6. Lane D — events, owner HUD, persistence

**Banner.**
- `EventBanner` is a `PanelContainer` with an icon and a label, shown by tween. It emits
  `dismissed`. It goes in the HUD's existing top-centre container (a fragile-area rule: container
  layout, not pixel offsets).
- `WorldHUD` keeps `_event_queue: Array[Dictionary]` and connects:
  - `EventManager.world_event_triggered` → enqueue
  - `EncounterManager.encounter_failed` → enqueue, at a quiet severity

  `EncounterManager` is a scene node; connect it the same way as Lane B, without a node path.
- Text comes from `EventAnnouncements.tres`, which maps the event name to a title key and an icon.
  The 12 names are the `trigger_event` literals in `EventManager.gd:67-399`.
- An unknown name: show nothing and `push_warning`. A missing table entry means an unannounced
  event, not a crash.

**Owner on approach.**
- Change `show_dock_prompt(show)` to `show_dock_prompt(show, island_data := null)`.
- `_on_dock_area_entered(island_id)` resolves the island through the existing island lookup.
- The label text is `"%s · %s" % [island_name, display.name]` with `modulate = display.color`.
- The phone path, `_set_mobile_context_state("dock", true)`, gets the same text.

**D3.**
- **First the repro test:** save at `_timer` = 0.9 × interval, load, and assert whether the next
  event is duplicated or lost.
- Only if it reproduces: persist `{timer, next_event_time}`, omit the section when `_timer == 0`,
  and add `EventManager` to `_NEW_GAME_RESET_MANAGERS`.

## 7. Lane E — frame rate

**Probe.** Add `--perf-log=<abs path>` to the capture harness. At each capture time it writes one
CSV row per scenario:
- `Performance.TIME_FPS`
- `TIME_PROCESS`
- `TIME_PHYSICS_PROCESS`
- `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`
- `RENDER_TOTAL_OBJECTS_IN_FRAME`
- `RENDER_TOTAL_PRIMITIVES_IN_FRAME`

It runs headful, because a headless dummy renderer reports zero draw calls.

**Process.**
1. Record a baseline.
2. Change one tier lever at a time and record the delta.
3. Keep only the levers that move the numbers.

Levers go in `QualityTierData` (per tier: shadow on/off and distance, MSAA, SSAO, glow, ocean
sparkle and ring density, ambient hull cap). They are applied where each setting lives (the World
`Environment`, `DirectionalLight3D`, `OceanController`, the `EnemySpawner` cap), all keyed off
`graphics_quality`. If an `EnemySpawner` cap is needed, it is a one-line read of the tier data; Lane
A doesn't own `EnemySpawner`, so it's E's additive edit.

**Device.** The owner measures FPS on the reference device using the 3 scenarios, and records it in
`RELEASE_CHECKLIST` §6. Until then the result is reported as unverified, not claimed.

## 8. Lint tests (Lane D)

| Test | Mechanism | Known traps |
|------|-----------|-------------|
| `test_lint_resource_exports` | `DirAccess` walk `res://resources`; per `.tres`, read the text, track the current `[resource]` or `[sub_resource type=... script=...]` section, and collect the keys of `key = value` lines; resolve the section's script via its `ext_resource` id; compare against `script.get_script_property_list()` names plus the base `Resource` properties (`script`, `resource_name`, `resource_local_to_scene`, `resource_path`, `metadata/*`) | default-omitted fields are fine (absent, not wrong); built-in typed sub-resources (no script) are checked against `ClassDB.class_get_property_list` |
| `test_lint_save_roundtrip` | per autoload with `get_save_data`: `a = JSON.parse_string(JSON.stringify(get_save_data()))`, `load_save_data(a)`, `b = …same…`, `assert_eq(a, b)`; then the reset-list coverage check | JSON turns ints into floats, so compare normalised forms; snapshot and restore each manager around the test (test isolation gotcha, see the M26-M28 wrap-up memory); never `save_game()` |
| `test_lint_signal_wiring` | `FileAccess` scan with `RegEx` for `^\s*signal (\w+)`, `\b\1\.emit\(`, `emit_signal\("\1"`, `\.\1\.connect\(`, `connect\("\1"`, `.tscn` `\[connection signal="\1"` | signals that are only `await`ed count as connected; the allowlist is seeded from the first run, with a reason per entry |

## 9. Lane F — art pipeline

`docs/10_ASSET_REQUESTS.md` gets a new section with the table described in F1.

The story cast to cover is everyone with a `speaker_name` in the Ch1-5 `.tres` files: grep them.
Known so far: Higgins (done), Hale, Hollis, Vance, Cárdenas, Marguerite, Morrow.

Each has a path convention of `res://assets/portraits/<Name>.png`, 512×512, transparent, bust. Lane
C writes these paths into the beats. `PortraitFallback` renders initials until each file exists.

Seam fields on `IslandData`: `port_scene_path`, `owner_banner_path`.

# Design Document: Milestone M5 — Launch Readiness

## 1. Why this design shape

Both gaps close by extending existing systems, not adding new ones — same philosophy as M4:

- **Offline gameplay** reuses the exact per-tick logic `Island.gd` and `FleetManager.gd` already
  run in response to `ResourceManager.global_economy_tick` during live play — but calls each of
  their tick methods directly N times on load, rather than re-emitting the shared signal itself.
  This distinction matters: `FactionManager.gd` *also* subscribes to `global_economy_tick` (to
  probabilistically dispatch Royal Navy hunter ships when reputation is very negative — see §3),
  a combat/threat side effect that has nothing to do with economy catch-up and would misfire at
  an absurd rate if the raw signal were replayed hundreds of times in a tight loop. Offline
  catch-up must target island production and fleet missions specifically, not "whatever is
  currently subscribed to this signal" — a signal's subscriber list is not a stable contract to
  build a feature on top of.
- **Captain roster** reuses `CaptainData.gd`'s existing schema and `IslandMenu.gd`'s existing
  hardcoded-name-list loading pattern (`ship_names`/`cap_names` arrays at lines ~72–81) — the
  same pattern already used for the 8 ships and 5 captains. Adding 15 more captains is adding 15
  more `.tres` files and 15 more strings to that array, not a new content pipeline.

---

## 2. New/changed files

| File | Change |
|------|--------|
| `scripts/managers/SaveManager.gd` | Persist `last_saved_unix`; on load, compute elapsed time and emit `ResourceManager.global_economy_tick` N times (capped) |
| `scripts/ui/WorldHUD.gd` | Show a one-time "while you were away" notice via the existing `announce_event()` pattern when offline ticks > 0 |
| `scripts/world/CaptainData.gd` | Add `hire_cost_gold: int = 500` export field (additive; default preserves current flat-500 behavior) |
| `resources/captains/*.tres` (15 new files) | New captains, schema-identical to the existing 5 |
| `scripts/ui/IslandMenu.gd` | Extend `cap_names` array (line ~78) with the 15 new names; change the Tavern tab's hardcoded `cost_dict = {"gold": 500}` (line ~373) to `{"gold": cap.hire_cost_gold}` |

---

## 3. Offline catch-up — exact integration point

`SaveManager.load_game()` currently restores, in order: player position → economy → fleet →
islands → tech → factions → empire → tutorial. Offline catch-up must run **after** islands and
fleet are both restored (it needs `Island.built_buildings` and `FleetManager.active_missions` to
already reflect the loaded save), so it's appended as a new final step:

```gdscript
# after all existing load_game() steps:
if data.has("last_saved_unix"):
    var elapsed = int(Time.get_unix_time_from_system()) - int(data["last_saved_unix"])
    elapsed = max(elapsed, 0)
    var max_offline_seconds = 4 * 60 * 60  # 4 hours, tune later — a data constant, not a redesign
    elapsed = min(elapsed, max_offline_seconds)
    var offline_ticks = int(elapsed / ResourceManager.ECONOMY_TICK_INTERVAL)
    var islands = get_tree().get_nodes_in_group("islands")
    for i in range(offline_ticks):
        for island in islands:
            island._on_economy_tick()
        FleetManager._on_economy_tick()
    if offline_ticks > 0:
        _pending_offline_ticks = offline_ticks  # read once by WorldHUD, then cleared
```

This deliberately calls `Island._on_economy_tick()` and `FleetManager._on_economy_tick()`
directly rather than emitting `global_economy_tick` — see §1's note on why the shared signal
isn't safe to replay wholesale (`FactionManager` is also on it). Both methods already do exactly
the right thing (produce resources per built building; tick missions for gold/reputation/XP);
this replays their existing, already-tested logic verbatim, scoped to only the two systems this
milestone actually intends to catch up. No new production math anywhere. (The leading
underscore on `_on_economy_tick` is Godot's signal-handler naming convention, not enforced
privacy — direct external calls are valid GDScript, and `SaveManager` already calls other
managers' internals directly elsewhere, e.g. `island.restore_buildings(...)`.)

`save_game()` gets one new line in its dictionary: `"last_saved_unix":
Time.get_unix_time_from_system()`, at the top level (sibling to `player`/`economy`/etc., not
nested under any manager) since it's not owned by any single manager.

**Order-of-operations risk to watch:** `SaveManager._process()` also calls `save_game()` on its
own 60s timer and the existing `player_docked` hookup — make sure `last_saved_unix` is written
on *every* save (it's set inside `save_game()` itself, not `load_game()`, so this is automatic),
not just a manual save, or a player who reloads shortly after an autosave would see an
artificially small `elapsed`.

## 4. Offline-return notice

`WorldHUD.gd` already has `announce_event(text: String)` (used for region-activation and island
capture notices, per milestone-m4-empire-escalation). On `_ready()`, if
`SaveManager._pending_offline_ticks > 0` (read once, then reset to 0 so it doesn't re-show),
show `announce_event("While you were away: economy kept running (%d ticks)" % ticks)` — or a
slightly richer message if a resource-delta snapshot is cheap to capture (diff
`ResourceManager.current_resources` before/after the catch-up loop in `SaveManager`, pass the
delta dict to the HUD). Keep this simple for the first slice; a snapshot diff is a nice-to-have,
not required by Requirement 3.

## 5. Captain roster expansion

`CaptainData.gd`'s schema needs exactly one additive field:

```gdscript
@export_group("Progression")
@export var hire_cost_gold: int = 500  # NEW — matches IslandMenu.gd's current flat cost as the default
```

The 15 new `.tres` files follow the existing 5's exact structure (see
`resources/captains/Anne.tres` as the reference — **use the `base_*_modifier` field names**,
not the bare `speed_modifier`/etc. names; see `docs/05_CURRENT_SYSTEMS.md` D14 for why the
bare names are silently inert). Suggested starting roster (names/flavor are placeholders for
whoever authors the final list — the mechanical requirement is 15 distinct, schema-valid
resources, not these specific names):

| Captain | speed | turn | dmg | hp | hire_cost_gold |
|---|---|---|---|---|---|
| (existing 5) | — | — | — | — | 500 |
| 6–20 (new) | vary within [0.7, 1.4] | vary within [0.7, 1.4] | vary within [0.8, 1.5] | vary within [0.7, 1.5] | ramp 750→4000 across the 15, roughly geometric, so later hires cost meaningfully more |

`IslandMenu.gd`'s changes are two one-line edits: append 15 strings to `cap_names`, and swap the
hardcoded `{"gold": 500}` for `{"gold": cap.hire_cost_gold}` in the Tavern-tab button-building
loop (~line 373) plus the cost label text (~line 376, currently a hardcoded `"500 Gold  "`
string — must read from `cap.hire_cost_gold` too, or the label will lie for every captain past
the first 5).

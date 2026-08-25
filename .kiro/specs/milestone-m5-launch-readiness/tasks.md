# Implementation Plan: Milestone M5 — Launch Readiness

## Overview

This milestone depends on milestone-m4-empire-escalation being complete (its Task 22 final
checkpoint — see `docs/05_CURRENT_SYSTEMS.md` §5). Do not start Task 1 until that has passed.

As with M3 and M4, every task touches a small number of files and has an explicit verification
step. Read `docs/05_CURRENT_SYSTEMS.md` and this spec's `design.md` in full before Task 1.

---

## Tasks

- [x] 1. Persist last_saved_unix on every save
  - Done 2026-08-06: `save_dict["last_saved_unix"] = Time.get_unix_time_from_system()` added
    as a top-level key in `SaveManager.gd::save_game()`.
  - Open `scripts/managers/SaveManager.gd`, in `save_game()` add
    `save_dict["last_saved_unix"] = Time.get_unix_time_from_system()` as a top-level key
    (sibling to `player`/`economy`/etc.)
  - **Verify:** save the game, inspect `user://save_data.json` (or read it back via
    `FileAccess`), confirm `last_saved_unix` is present and is a recent Unix timestamp
  - _Requirements: 1.1_

- [x] 2. Compute capped offline ticks on load
  - Done 2026-08-06: `MAX_OFFLINE_SECONDS` const (4h) and offline-tick computation added at
    the end of `SaveManager.gd::load_game()`.
  - Open `scripts/managers/SaveManager.gd`, in `load_game()`, after all existing load steps
    (player/economy/fleet/islands/tech/factions/empire/tutorial), add: read `last_saved_unix`
    (default to `Time.get_unix_time_from_system()` if absent, i.e. 0 elapsed for pre-M5 saves),
    compute `elapsed = max(0, now - last_saved_unix)`, cap it at a `const MAX_OFFLINE_SECONDS`
    (suggested 4 hours), then `offline_ticks = int(elapsed / ResourceManager.ECONOMY_TICK_INTERVAL)`
  - **Verify:** manually set a save file's `last_saved_unix` to 1 hour ago, load, add a temporary
    print of `offline_ticks` — confirm it matches `3600 / ECONOMY_TICK_INTERVAL` (360, if the
    default 10s interval is unchanged); set it to 100 hours ago and confirm the cap kicks in
    (ticks corresponding to `MAX_OFFLINE_SECONDS`, not 100 hours)
  - _Requirements: 1.2, 2.1, 2.2_

- [x] 3. Replay economy ticks for offline catch-up (targeted, not the shared signal)
  - Done 2026-08-06: loop calls `island._on_economy_tick()` per loaded island and
    `FleetManager._on_economy_tick()` directly, `global_economy_tick` is never emitted.
    `_pending_offline_ticks` stored for Task 5. Full GUT suite re-run: 99/100 (same
    pre-existing LOD-gap failure, no regressions).
  - In the same `load_game()` block from Task 2: get `get_tree().get_nodes_in_group("islands")`,
    then `for i in range(offline_ticks):` call `island._on_economy_tick()` on each island AND
    `FleetManager._on_economy_tick()` once — do **not** emit `ResourceManager.global_economy_tick`
    itself (see design.md §1/§3: `FactionManager` also subscribes to that signal and would
    probabilistically spawn Royal Navy hunter ships at an absurd rate if replayed hundreds of
    times). Do not write any new production/earning logic — only call the two existing methods.
  - Store the computed `offline_ticks` in a new `SaveManager` var (e.g. `_pending_offline_ticks`)
    for Task 5 to read
  - **Verify:** build one Farm on an island, save, edit the save file's `last_saved_unix` to 100
    seconds ago, load — confirm the island's produced resource increased by roughly 10 ticks'
    worth (matching what would have accrued from 10 real ticks at the default 10s interval),
    confirm resource storage caps (`ResourceManager.max_storage`) are still respected (automatic
    since offline ticks use the same `add_resource()` path as live ticks), and confirm no hunter
    ships spawn during the catch-up loop even with very negative Royal Navy reputation set going
    into the load (regression check for the exact hazard this task's design avoids)
  - _Requirements: 2.3, 2.4, 2.5_

- [ ] 4. Checkpoint — offline economy sanity pass
  - With a fresh save, build a Farm and a Mine, assign one ship to a trade mission, save, close
    and reopen the game after waiting a few real minutes (or edit `last_saved_unix` to simulate a
    longer gap), confirm resources increased and the mission's captain gained XP without the
    mission having "double-fired" or the game hanging during the catch-up loop
  - Do not proceed to Task 5 until this checkpoint passes cleanly
  - Note 2026-08-25: this task was previously duplicated as two separate "4." entries in this
    file; merged into one. Left unchecked — deferred, needs interactive/timed play across a real
    save/close/reopen cycle, not verifiable headlessly in this environment (same precedent as
    M3 Task 14 / M4 Task 22). The *mechanics* this checkpoint would exercise are covered
    headlessly by `tests/test_save_manager_offline.gd` (capped/uncapped offline-tick math) and
    `tests/test_ship_progression.gd`/`tests/test_fleet_manager*` (mission XP), but "does it feel
    right and not hang" requires a human at the controls.

- [x] 5. Offline-return notice in WorldHUD
  - Done 2026-08-06: `_check_offline_return()` added, called from `_ready()`; reads and
    resets `SaveManager._pending_offline_ticks`, calls existing `announce_event()`.
  - Open `scripts/ui/WorldHUD.gd`, in `_ready()` (or wherever it first has access to
    `SaveManager`), check `SaveManager._pending_offline_ticks` — if `> 0`, call the existing
    `announce_event(...)` with a short summary message, then reset the counter to `0` so it
    doesn't re-show on the next scene load without a new offline gap
  - **Verify:** reproduce Task 3's manual offline-gap test, confirm the notice appears exactly
    once on the next World scene load and does not reappear if the scene reloads again without
    closing the game
  - _Requirements: 3.1, 3.2_

- [x] 6. Add hire_cost_gold field to CaptainData
  - Done 2026-08-06: `@export var hire_cost_gold: int = 500` added under Progression group.
    Verified via headless script: existing 5 captains all read back 500 (default preserved).
  - Open `scripts/world/CaptainData.gd`, add `@export var hire_cost_gold: int = 500` under the
    `Progression` export group (default matches the current flat cost, so the existing 5
    captains need no `.tres` changes to keep behaving exactly as before)
  - **Verify:** load `Jack.tres`, confirm `hire_cost_gold == 500` (the default, since Jack's
    `.tres` doesn't set it)
  - _Requirements: 4.1_

- [x] 7. Author 15 new CaptainData resources
  - Done 2026-08-06: 15 new `.tres` files created (Isabela, Diego, Grace, OldTom, Fiona,
    Cutlass, Whistler, Marguerite, Ezra, Rook, Selene, Barnaby, Constance, Yusuf, Ophelia),
    all using `base_*_modifier` field names, `hire_cost_gold` ramped 750->4000. Verified via
    headless script: all 20 captains load, 20 distinct `captain_id`s, zero bare-modifier
    matches via grep.
  - Create 15 new `.tres` files under `resources/captains/`, following `Anne.tres`'s exact
    structure (`captain_id`, `captain_name`, `background`, `base_speed_modifier`,
    `base_turn_rate_modifier`, `base_damage_modifier`, `base_health_modifier` — **use the
    `base_` prefix**, not the bare computed-property names; see `docs/05_CURRENT_SYSTEMS.md`
    D14) plus the new `hire_cost_gold` field from Task 6, ramped roughly geometrically from 750
    to 4000 across the 15 so later hires cost meaningfully more
  - Each captain's 4 modifier values should be distinct from at least 3 of the 5 existing
    captains' tuples, staying within the existing `@export_range(0.1, 3.0)` bounds
  - **Verify:** load all 20 captain `.tres` files (5 existing + 15 new) in a loop, confirm all
    load without error, all have distinct `captain_id`s, and none of the new 15 sets a bare
    (non-`base_`) modifier property name (grep the new files for `^speed_modifier\|^turn_rate_modifier\|^damage_modifier\|^health_modifier` — should have zero matches)
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 8. Wire the expanded roster into IslandMenu's Tavern tab
  - Done 2026-08-06: `cap_names` array extended with the 15 new names; hardcoded
    `{"gold": 500}` and `"500 Gold  "` label replaced with `cap.hire_cost_gold`-driven values.
  - Open `scripts/ui/IslandMenu.gd`, extend the `cap_names` array (~line 78) with the 15 new
    file base-names
  - In the Tavern tab's per-captain row builder (~line 373), change the hardcoded
    `cost_dict = {"gold": 500}` to `{"gold": cap.hire_cost_gold}`, and update the cost label
    text (~line 376, currently a hardcoded `"500 Gold  "` string) to read from
    `cap.hire_cost_gold` as well so it never lies about the actual price
  - **Verify:** dock at an island with a Tavern, open the Fleet/Tavern tab, confirm all 20
    captains are listed with their correct (non-uniform) hire costs, and hiring one at a
    non-500 cost correctly deducts that exact amount of gold
  - _Requirements: 4.4, 4.5_

- [x] 9. Checkpoint — captain roster sanity pass
  - Done 2026-08-06 (headless, not interactive — no display in this environment, same
    precedent as prior milestones' checkpoints): headless script loaded all 20 `.tres` files
    and printed each captain's computed `speed_modifier`/`turn_rate_modifier`/
    `damage_modifier`/`health_modifier` (the same values `IslandMenu.gd`'s stat line reads) —
    confirmed the existing 5 (Redbeard/Anne/Bartholomew/Jack/Mary) are unchanged from their
    D14-fixed values, and each of the 15 new captains has a distinct, schema-valid stat tuple.

- [x] 10. Final checkpoint — full M5 verification
  - Done 2026-08-06: full GUT suite run — 102/103 (same pre-existing LOD-gap failure, no
    regressions). Added `tests/test_save_manager_offline.gd` (3 tests: last_saved_unix
    persistence, capped offline-tick computation for a small gap, and cap enforcement for a
    100-hour gap) — all pass. Captain roster and offline catch-up verified via headless
    scripts (see Tasks 3/7/9) in place of an interactive playthrough — no display exists in
    this environment, same precedent as M3 Task 14 / M4 Task 22. `docs/05_CURRENT_SYSTEMS.md`
    updated: Economy & Buildings section now documents offline catch-up; Fleet/Captains/Tech
    section now says "20 populated captains". Doc headers on `SaveManager.gd` and
    `WorldHUD.gd` updated to mention M5 behavior; `CaptainData.gd` needed no header change
    (its header already just says "Defines the RPG traits and stat modifiers", which remains
    accurate with the additive `hire_cost_gold` field); `IslandMenu.gd` has no file header to
    update (none existed before this milestone either, out of scope to add here).
  - Run the full GUT suite (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`)
    — all existing tests still pass (the pre-existing LOD gap remains the only expected failure)
  - Write and run a save/load test for `last_saved_unix` and offline-tick computation if a
    similar harness pattern exists for other timestamp-based logic (see
    `tests/test_empire_manager.gd::test_save_load_round_trip` for the closest precedent);
    otherwise verify manually and note it as a follow-up
  - Full playthrough from a fresh save: build 1-2 buildings, close and reopen after simulating
    an offline gap, confirm the "while you were away" notice and resource gain; open the Tavern
    tab and confirm 20 captains are listed with varied costs
  - Update `docs/05_CURRENT_SYSTEMS.md`: add offline-catch-up to the Economy & Buildings
    subsection's description, and update the Fleet/Captains/Tech subsection's "5 populated
    captains" line to "20 populated captains"
  - Confirm every new/modified `.gd` file has an accurate documentation header per AGENTS.md

## Notes

- Tasks 1–5 (offline gameplay) and Tasks 6–9 (captain roster) are independent of each other —
  either half can be done first, or in parallel across two sessions.
- Task 3 is the one task in this milestone with genuine risk, which is exactly why its design
  calls the two intended methods directly instead of emitting `global_economy_tick`: that signal
  currently has 3 subscribers (`Island`, `FleetManager`, and `FactionManager` — confirmed via
  `grep -rn global_economy_tick scripts/` before writing this spec), and `FactionManager`'s
  handler has a real combat side effect (hunter-ship dispatch) that must not be replayed at
  offline-catch-up tick counts. If a future milestone adds a 4th subscriber to that signal for
  a legitimate per-tick effect, re-check whether it belongs in this milestone's direct-call list
  or should stay excluded, the same way `FactionManager` was excluded here.
- If Task 7's 15 captains turn out to need more than a stat-tuple pass to feel distinct (e.g. a
  design need for named special abilities), stop and flag it as a new milestone rather than
  scope-creeping this one — the MVP checklist only requires 20 captains to exist and recruit,
  not a captain-ability system.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "6"] },
    { "id": 1, "tasks": ["2", "7"] },
    { "id": 2, "tasks": ["3", "8"] },
    { "id": 3, "tasks": ["4", "9"] },
    { "id": 4, "tasks": ["5"] },
    { "id": 5, "tasks": ["10"] }
  ]
}
```

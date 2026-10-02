# Implementation Plan: Milestone M29 — Stabilize & Wire

## Overview

This depends on the M26-M28 joint wrap-up (`7e7cbd9`, done). Before Task 1, read this spec's
`requirements.md` (including its false-positive list) and `design.md`, plus the
`docs/05_CURRENT_SYSTEMS.md` sections for every file your lane touches.

**Every fix task starts with a failing test.** If the test passes before you change anything, the
finding is stale: tick the task, append `(stale: <one line why>)`, and move on.

Single-file run:
`.godot-tools/<console exe> --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`.
Full suite: the same command with `-gdir=res://tests`. Never use `--check-only`.

## Tasks

### Wave 1: lanes run in parallel

**Lane A: combat**
- [ ] A.1 Loot granted once on boarding (`loot_claimed` meta), plus the respawn re-loot check: `BoardingSystem.gd`, `ShipController.gd`
  - **Verify:** `tests/test_m29_boarding_loot_once.gd`. Board → resources rise by the roll exactly once, and no `LootDrop` spawns. Sink → one `LootDrop`. Notoriety +once each. `tests/test_ship_combat.gd` passes unmodified.
  - _Requirements: A1_
- [ ] A.2 Zero-crew guard, bounded reload penalty (`ShipStats` fields), and the `_life_id` guard on deferred reload callbacks: `ShipCombat.gd`, `ShipStats.gd`
  - **Verify:** `tests/test_m29_crew_fire.gd`. crew=0 → 0 cannonballs on manual, auto and ripple. crew=1/8 → cooldown ≤ `max_reload_seconds`. Die mid-cooldown, then respawn → the old callback doesn't flip `can_fire_*`.
  - _Requirements: A2_
- [ ] A.3 `LootScalingData` + `LootScaling.tres` + the shared helper; replace both formula sites: `LootScalingData.gd`, `ShipController.gd`/`BoardingSystem.gd` (one-line call each)
  - **Verify:** `tests/test_m29_loot_scaling.gd`. Notoriety 300 with an 8×3-crew hull → multiplier = 5.0. A missing resource → 1.0 plus a `push_error`. `grep -n "notoriety / 100" scripts/` finds nothing.
  - _Requirements: A3_
- [ ] A.4 Encounter validation + `encounter_failed` signal + `time_limit` cap; ripple-fire and target-lock guards: `EncounterManager.gd`, `EncounterData.gd` (ripple and lock guards in `ShipCombat.gd`, after A.2)
  - **Verify:** `tests/test_m29_encounter_validation.gd`. Each invalid case (in requirements A4.1) → `false` + signal + ambient restored. Free the parent mid-ripple → no error. Plus `tests/test_lint_encounter_data.gd`: every encounter `.tres` validates.
  - _Requirements: A4, A5_

**Lane B: faction consequences**
- [ ] B.1 `FactionData` consequence and seam `@export`s; empire `.tres` values: `FactionData.gd`, `resources/factions/*.tres`
  - **Verify:** `tests/test_m29_faction_data.gd`. Fields exist with the design §4 defaults. RoyalNavy/Spain `sink_reputation_loss` > 0. MerchantGuild's value is chosen per the B.5 hazard.
  - _Requirements: B1, B3, F1_
- [ ] B.2 Reputation loss on sink and on board (signals, campaign-only, no double count with `loot_claimed`): `FactionManager.gd`
  - **Verify:** `tests/test_m29_reputation_consequences.gd`. Sink Spain → −N. Board Navy → −M, and the sink loss is not also applied. Maelstrom mode → unchanged. Unknown faction → `push_error`.
  - _Requirements: B1_
- [ ] B.3 Previous owner on capture + `island_captured_from`; event hunters with a cooldown: `Island.gd`, `EmpireManager.gd`, `FactionManager.gd`
  - **Verify:** `tests/test_m29_event_hunters.gd`. Capture a Spanish island → the signal carries `spain`, and one hunter spawns. A second capture inside the cooldown → no hunter. The `island_captured` subscribers' existing tests still pass.
  - _Requirements: B2_
- [ ] B.4 Tribute from data; `raid_frequency_mult` in the raid odds; `get_island_owner_display()`: `FactionManager.gd`, `EmpireManager.gd`
  - **Verify:** `tests/test_m29_faction_tuning.gd`. Navy tribute cost and cooldown come from the `.tres`. Raid chance scales by the multiplier, inside the existing clamp. Owner display covers all 4 island types plus null.
  - _Requirements: B3, B4_
- [ ] B.5 Reputation-objective conflict check across Ch1-5
  - **Verify:** `tests/test_m29_reputation_objectives.gd`. For each `CHANGE_REPUTATION` objective, the faction's sink and boarding losses can't drive it out of reach, given the chapter's mandatory fights.
  - _Requirements: B1.6_

**Lane C: campaign ending and story**
- [ ] C.1 `campaign_completed` state, signal, save, celebration; `get_display_objective()`; `CaptainsLog` uses it: `CampaignManager.gd`, `CaptainsLog.gd`
  - **Verify:** `tests/test_m29_campaign_complete.gd`. Completing the final chapter → flag + signal + one celebration. Save/load round-trips the flag. New Game resets it. Free roam → `_current_chapter()` is null and the display line is the free-roam text.
  - _Requirements: C1_
- [ ] C.2 Author the epilogue beats (Higgins → Marguerite callback → Vane's chart hook) in the existing voice: `Ch5_TheSilverFleet.tres`
  - **Verify:** `tests/test_m29_campaign_complete.gd` asserts the final chapter's closing beats include the 3 epilogue speakers in order. The text is read in the headful pass at the checkpoint.
  - _Requirements: C1.2_
- [ ] C.3 Golden-path completability test
  - **Verify:** `tests/test_campaign_golden_path.gd` passes. Temporarily point one objective at a disabled island → it fails, naming the chapter and objective. Revert.
  - _Requirements: C2_
- [ ] C.4 Text: Obj_2_4, the Ch4 goals beat, the Pelican Cay raid follow-up objective (append the id, never renumber), the optional Obj_4_8 acknowledgment only if beats support conditions; Tortuga codex; Fortress/Watchtower descriptions: the `Ch2/Ch4.tres`, `Tortuga.tres` and building `.tres` files
  - **Verify:** `tests/test_m29_text_fixes.gd`. There's no "(Future Combat)" in `resources/buildings`, Obj_2_4 text mentions two, and the Ch4 follow-up objective exists and passes the golden-path test.
  - _Requirements: C3.1-C3.6_
- [ ] C.5 Story-cast `portrait_path` on every named Ch1-5 speaker, using the Lane F paths: the `Ch1-5.tres` files
  - **Verify:** `tests/test_m29_dialogue_portraits.gd`. Every beat with a `speaker_name` other than narrator/blank has a non-empty `portrait_path` under `res://assets/portraits/`.
  - _Requirements: C3.7_

**Lane D: events, HUD, integrity**
- [ ] D.1 `EventBanner` scene + `EventAnnouncementData` table (all 12 event names) + the `WorldHUD` queue and connection: `EventBanner.gd/.tscn`, `EventAnnouncementData.gd`, `EventAnnouncements.tres`, `WorldHUD.gd` (additive)
  - **Verify:** `tests/test_m29_event_banner.gd`. Three `trigger_event` calls → three banners FIFO, one visible at a time. An unknown name → no banner plus a warning. Every `trigger_event` literal in `EventManager.gd` has a table entry.
  - _Requirements: D1_
- [ ] D.2 D3 repro test; persist the schedule only if it reproduces: `EventManager.gd`, `SaveManager.gd` (additive)
  - **Verify:** `tests/test_m29_event_schedule_persist.gd`. Either it proves the defect and then passes after the fix, or the task is ticked stale.
  - _Requirements: D3_
- [ ] D.3 Resource lint
  - **Verify:** `tests/test_lint_resource_exports.gd` prints its counts. Fix every real violation it finds in the same task (likely the D3/D14 class), each fix listed in `docs/05`'s M29 section.
  - _Requirements: D4.1_
- [ ] D.4 Persistence lint and signal lint
  - **Verify:** `tests/test_lint_save_roundtrip.gd` and `tests/test_lint_signal_wiring.gd` pass. Allowlists are seeded with a reason per entry. Each real dead signal is either wired or deleted, never just allowlisted without a reason.
  - _Requirements: D4.2, D4.3_

**Lane E: performance**
- [ ] E.1 `--perf-log` flag on the capture harness; baseline CSV for the 4 scenarios: `ScreenshotHarness.gd` (or the CaptureHarness script)
  - **Verify:** run headful with `--perf-log=<scratch>/m29_base.csv`. The file has 4 scenario rows with non-zero draw calls.
  - _Requirements: E1.1_
- [ ] E.2 Explicit mobile renderer; `QualityTierData` + a lever per measured cost, one at a time: `project.godot` `[rendering]`, `QualityTierData.gd` + `resources/settings/QualityTiers.tres`, the apply sites
  - **Verify:** re-run the probe per lever, and write a before/after table into `docs/05`'s M29 section. `tests/test_m29_quality_tiers.gd`: switching `graphics_quality` applies each lever and no literal tier values remain.
  - _Requirements: E1.2, E1.5_
- [ ] E.3 Release plumbing doc: the GitHub Pages step and the device FPS protocol, in `docs/RELEASE_CHECKLIST.md`
  - **Verify:** both sections exist. **Owner actions** (enable Pages, measure device FPS) are listed as open, not done.
  - _Requirements: E1.4, E2_

**Lane F: art pipeline**
- [ ] F.1 Asset requests section in `docs/10_ASSET_REQUESTS.md` (grep every `speaker_name` in Ch1-5 for the cast); `IslandData` seam `@export`s: `docs/10_ASSET_REQUESTS.md`, `IslandData.gd`
  - **Verify:** every item in requirement F1.2 has a row with a path, a format, a budget, the milestone that needs it, and its placeholder. The resource lint (D.3) passes with the new fields.
  - _Requirements: F1_

### Wave 2: cross-lane joins (each needs its upstream task)
- [ ] J.1 The dock prompt shows the owner on both the desktop and the phone (needs B.4): `WorldHUD.gd`
  - **Verify:** `tests/test_m29_owner_hud.gd`. A Spanish island prompt text contains the faction name, tinted with `sail_color`. The player island shows the player faction. A null owner doesn't crash.
  - _Requirements: D2_
- [ ] J.2 The HUD objective panel uses `get_display_objective()`, and the banner shows `encounter_failed` (needs C.1, A.4): `WorldHUD.gd`
  - **Verify:** `tests/test_m29_free_roam_hud.gd`. In free roam the objective label shows the free-roam line. A failed encounter → one quiet banner.
  - _Requirements: C1.4, D1.3_

- [ ] **Checkpoint A**
  - **Verify:**
    - Full suite passes; count ≥ 1046 + new tests; 0 failures.
    - `checkpoint-reviewer` on Wave 1-2.
    - `SelfPlayHarness.gd` headless: grep for runtime-error signatures and expect zero.
    - Commit and push, scoped to M29 files.

### Wave 3: close-out
- [ ] Z.1 Docs: an M29 section in `docs/05_CURRENT_SYSTEMS.md` (own section; each lane's changes, the stale-closed findings, perf before/after), plus `docs/15_MASTER_PLAN.md` §2.5 updated to the M29-M35 roadmap
  - **Verify:** `sync-systems-doc` reports nothing undocumented for M29 files.
- [ ] **Checkpoint B (final)**
  - **Verify:**
    - Rebase on `main`, then the full suite.
    - `checkpoint-reviewer` against this spec.
    - One headful `CaptureHarness` pass, reviewing the screenshots of: an event banner, the dock prompt with the owner, the epilogue beats, the free-roam HUD line.
    - Commit and push.

## Notes

- **File ownership.** Implement the lanes in parallel by file:

  | Lane | Owns |
  |---|---|
  | A | `ShipController`, `ShipCombat`, `ShipStats`, `BoardingSystem`, `EncounterManager`, `EncounterData`, `LootScalingData`, `resources/combat/LootScaling.tres` |
  | B | `FactionData`, `FactionManager`, `EmpireManager`, `Island.gd`, `resources/factions/*` |
  | C | `CampaignManager`, `CaptainsLog`, `resources/campaign/**`, `Tortuga.tres`, building `.tres` text |
  | D | `EventManager`, `EventBanner`, `EventAnnouncementData`, `resources/events/*`, `tests/test_lint_*` |
  | E | `project.godot` `[rendering]`, the capture-harness script, `OceanController`, `QualityTierData`, `resources/settings/QualityTiers.tres`, `RELEASE_CHECKLIST` |
  | F | `docs/10`, `IslandData.gd` |

  - **Additive only:** `WorldHUD.gd` (D, then J.1/J.2), `SaveManager.gd` (D.2 only), `docs/05` (Z.1 only).
  - A lane needing an edit in another lane's file asks that lane's task to add it. For example, an
    `EnemySpawner` cap needed for E.2 is a one-line additive edit, noted in E.2's commit.
- **Data shared across lanes is defined once in `design.md`.** Read it, don't re-derive:
  - the `loot_claimed` meta (A writes it, B reads it)
  - `encounter_failed` (A emits it, D consumes it)
  - `get_island_owner_display` (B provides it, D consumes it)
  - `get_display_objective` (C provides it, D consumes it)
  - the portrait paths (F defines them, C writes them)
- **Fragile areas this milestone must not touch** (CLAUDE.md):
  - buoyancy, stability torque and the yaw servo
  - the cannon-forward basis
  - `EnemyAI` avoidance (measure only)
  - `test_ship_combat.gd`, which must pass unmodified
  - the save-section omission rule
  - the HUD container-layout rule
  - the push_error-on-unresolvable-id rule
- **`ObjectiveData.Condition` is int-serialized.** Append only. Ch4's new objective gets an
  appended id. Never renumber.
- **Stale, by-design and deferred findings** (with reasons):
  - C-009: the paused-tree prompt; playtest it.
  - C-011: no captain range stat exists.
  - M-003: the ambient cadence reset is by design.
  - C-010/C-013/C-017: polish, M33.
  - C-012/C-016: balance, playtest.
  - E1-E4/E9/MISSED-2/PERSISTENCE-005/F019: false positives (see `requirements.md`).
- **Not verifiable here:** device FPS (owner), touch feel of the banner and dock prompt, and
  whether the epilogue lands emotionally. Report these as unverified at the checkpoints.
- **Owner actions still open:**
  1. Enable GitHub Pages, which publishes the privacy and terms pages.
  2. Name the reference device and run the FPS protocol.
  3. Commission and supply the art in `docs/10`.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["A.1", "A.2", "A.3", "B.1", "C.1", "C.3", "D.1", "D.2", "D.3", "E.1", "F.1"] },
    { "id": 1, "tasks": ["A.4", "B.2", "B.3", "C.2", "C.4", "C.5", "D.4", "E.2", "E.3"] },
    { "id": 2, "tasks": ["B.4", "B.5"] },
    { "id": 3, "tasks": ["J.1", "J.2"] },
    { "id": 4, "tasks": ["Checkpoint A"] },
    { "id": 5, "tasks": ["Z.1", "Checkpoint B"] }
  ]
}
```

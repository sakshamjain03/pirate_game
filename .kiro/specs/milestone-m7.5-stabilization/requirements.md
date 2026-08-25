# Requirements Document

## Introduction

Milestone M7.5 is a small stabilization pass, the same role `milestone-m3-stabilization` played
for M1/M2: M7 (Campaign Spine) and the M1/M2 tail items were completed and independently
checkpoint-verified by a parallel session (GUT suite at 320 tests / 319 passing, confirmed
independently rather than taken on self-report). This milestone exists to catch what a
tasks.md/checkbox audit and a passing test suite cannot: real runtime defects only visible by
actually running the game and looking at the rendered output, plus the specific gap the M7 session
itself flagged as unresolved when it shipped (Chapters 4/5's bosses had no in-world trigger).

Both defects found here were found by running `scenes/debug/CaptureHarness.tscn` headfully (not
`--headless`, which produces blank renders) and inspecting the actual screenshots — the same
method the 2026-08-09 visual pass used for D23–D28 in `docs/05_CURRENT_SYSTEMS.md`. The GUT suite
was green the entire time both defects were live; neither would have been caught by more tests
alone.

Full technical detail lives in `docs/05_CURRENT_SYSTEMS.md`'s "M7.5 Stabilization Pass" section
and `docs/14_SYSTEM_INVENTORY.md` §7.5, referenced here as D64/D65.

---

## Requirements

### Requirement 1 — Fix the save/load position-default bug (D64)

**User Story:** As a player, I want loading a save to never place my ship somewhere physically
impossible, so a rough edge in how a save was produced can never turn into a broken, unplayable
render.

#### Acceptance Criteria

1. `SaveManager.save_game()` SHALL NOT write a `"player"` key at all when no `player_ship` group
   member exists in the tree at save time. Previously it wrote `"player": {}`, indistinguishable
   on load from a save that legitimately had nothing else to restore.
2. `SaveManager.load_game()` SHALL only restore the player's position/rotation when the save data
   actually recorded a position (`player_data.has("pos_x")`). When absent, the ship SHALL remain
   at the scene's authored spawn transform rather than defaulting to `Vector3(0, 1, 0)`.
3. This SHALL NOT change position restoration for any save that does record a position — existing
   saves with real player data continue to load exactly as before.
4. Confirmed via a real headful `CaptureHarness` run: with the fix applied, loading the same
   previously-corrupting save (`"player": {}`) leaves the ship at its normal spawn point and sailing
   normally, rather than embedding it in Port Royal's collision and collapsing the camera into the
   terrain.

### Requirement 2 — Make Chapters 4/5's bosses reachable through normal play (D65)

**User Story:** As a player progressing the campaign, I want Chapter 4 and Chapter 5's boss fights
to actually happen while I sail, so completing those chapters doesn't require developer tooling.

#### Acceptance Criteria

1. `EncounterData` SHALL gain `required_chapter_id: String`, defaulting to `""` (no gate, eligible
   for the ambient scheduler at any time — the behavior every pre-existing encounter keeps).
2. `IntransigentBoss.tres` (Chapter 4) and `CardenasBoss.tres` (Chapter 5) SHALL set
   `required_chapter_id` to their respective chapter's real `chapter_id`
   (`"ch4_the_admirals_gambit"` / `"ch5_the_silver_fleet"`).
3. `EncounterManager._start_random_ambient()` SHALL exclude any pool candidate whose
   `required_chapter_id` is non-empty and does not match `CampaignManager`'s currently-active
   chapter (via a new public `CampaignManager.is_chapter_current()`, mirroring the existing
   `is_chapter_completed()`).
4. Both bosses SHALL be added to `World.tscn`'s `EncounterManager.encounter_pool`.
5. A player who has not reached Chapter 4 or 5 SHALL NOT be able to draw that chapter's boss from
   the ambient pool — a Chapter 1 player must not stumble into a Chapter 4 fight.
6. `tests/test_encounters.gd` SHALL cover: the gate excluding a candidate before its chapter, the
   gate admitting it once that chapter is current, and both authored bosses actually carrying the
   right `required_chapter_id`. The existing authored-content coherence test SHALL also cover both
   boss `.tres` files, which it had never done.

### Requirement 3 — Documentation

**User Story:** As a maintainer, I want this pass's findings recorded the same way every prior
defect has been, so this doesn't become the next thing a future audit has to rediscover.

#### Acceptance Criteria

1. `docs/05_CURRENT_SYSTEMS.md` SHALL gain a dated "M7.5 Stabilization Pass" section documenting
   D64/D65, their root cause, and their resolution, with the updated GUT baseline.
2. `docs/14_SYSTEM_INVENTORY.md` SHALL have its test-count snapshot and defect table updated to
   match.
3. `docs/15_MASTER_PLAN.md`'s M7 exit-criteria results SHALL be corrected to reflect that the
   Ch4/Ch5 boss-trigger gap is now closed.

---

## Non-Goals

- Re-auditing M1–M7's task docs for checkbox/process hygiene — that pass already happened (M7
  itself, plus the M1/M2 tail and an M5 doc fix), independently verified before this milestone
  started.
- Giving the Ch4/Ch5 boss fights a real *location* (e.g. "only spawns near Frostbite Reef"). The
  chapter gate is the smallest change that makes them reachable at all; a location-anchored
  trigger needs the discovery/waypoint system M9 already owns, and is noted there, not built here.
- Any of the M9–M13 roadmap items in `docs/15_MASTER_PLAN.md` — reviewed during this pass and
  found still accurately scoped; nothing here needed a new bucket.

# Implementation Plan — M7 Campaign Spine & Economy Correction

> **Read before starting any task, in this order:** `AGENTS.md` (constitution) →
> `docs/05_CURRENT_SYSTEMS.md` (what actually exists today) → this milestone's `requirements.md`
> and `design.md` → the specific companion doc a task references
> (`docs/06_NARRATIVE_AND_WORLD.md`, `docs/12_CHARACTER_BIBLE.md`, or
> `docs/13_CAMPAIGN_LEVELS_1-5.md`).
>
> **Verification command** (never use `--check-only`, it does not terminate in this project):
> ```
> <godot-binary> --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
> ```
> Baseline entering this milestone: **126 tests, 125 passing, 1 known failure**
> (`test_property_21_lod_distance_transitions` — a tracked LOD gap, not a regression). **Do not
> trust a stale number pasted into a prompt** — run the suite yourself before and after each wave
> and compare the real totals, per `docs/08_PROMPT_LIBRARY.md`'s baseline note. Any failure beyond
> the one known gap, or a drop in total test count, is a regression.
>
> **Checkpoints are blocking.** Do not begin a task wave until the preceding checkpoint has been
> *verified* by the `checkpoint-reviewer` agent — never on a self-report that it "looks done"
> (`docs/07_AI_AGENT_WORKFLOW.md` Rules 4/7/8). M6's own final checkpoint was accepted on a
> self-report ("skipped local execution of GUT since binary is unavailable") and the binary was,
> in fact, available the whole time at the path recorded in
> `docs/14_SYSTEM_INVENTORY.md` §6 — do not repeat that.

---

## Wave 1 — Economy correction

Everything in Wave 2 is tuned against the corrected numbers this wave produces. Do not start
Wave 2 before this wave's checkpoint passes.

- [x] 1. Extend `ShipStats` with identity and cost fields
  - Done 2026-08-16 as part of M8 Phase 2 (combat rework's economy-correction wave, ahead of this
    spec being executed) — `ship_id`/`display_name`/`ship_class`/`cost_*` authored on all 8 hulls
    plus the enemy raider and ghost-ship boss stats.
  - Open `scripts/world/ShipStats.gd`. Add `ship_id: String`, `display_name: String`,
    `ship_class: int` (1–5), and `cost_gold`/`cost_wood`/`cost_iron`/`cost_rum: int` per
    `design.md` Part A1.
  - Author all 8 `resources/ships/*.tres` to the exact ladder table in `design.md` A1.
  - **Before authoring, confirm** these are real `@export`ed properties on the script you just
    edited — a `.tres` setting a property the script doesn't export fails silently
    (`docs/05_CURRENT_SYSTEMS.md` D3/D14).
  - _Requirements: 1.1, 1.2_

- [x] 2. Fix `IslandMenu`'s ship pricing and naming
  - Done 2026-08-16 as part of M8 Phase 2.
  - Delete the `cost_gold = int(ship.mass / 100)` block and its wood/iron equivalents in
    `_create_ship_entry()`. Read the four new `cost_*` fields directly.
  - Replace the filename-derived ship name with `ship.display_name`.
  - Do not add a fallback to the old formula for ships missing the new fields — Task 1 already
    authors all 8.
  - Verify manually: a level-5 Farm (1350 gold, already authored) costs less than the cheapest
    ship, and a Man O'War costs more than any single level-5 building.
  - _Requirements: 1.3, 1.4, 1.5_

- [x] 3. Author captain boarding modifier and hire cost
  - Done 2026-08-16 as part of M8 Phase 2 (`base_boarding_modifier` closed D55 in M8 Phase 1;
    `hire_cost_gold` on the 5 missing captains closed here).
  - Add `base_boarding_modifier` to all 20 `resources/captains/*.tres`, using the suggested
    values in `docs/12_CHARACTER_BIBLE.md` §5 (C1) or an equivalent ordering.
  - Add `hire_cost_gold` to the 5 captains currently missing it, scaled per
    `docs/12_CHARACTER_BIBLE.md` §4's chapter-tier table.
  - No script change — both fields already exist on `CaptainData.gd`.
  - _Requirements: 2.1, 2.2_

- [x] 4. Add captain identity fields
  - Done 2026-08-16. `home_island_id`/`allegiance_faction_id`/`unlock_chapter_id`/`portrait_path`
    added to `CaptainData.gd` and authored on all 20 captains per `docs/12_CHARACTER_BIBLE.md` §4,
    verified against the real `island_id`/`faction_id` values in `resources/world/`/`resources/factions/`.
    `unlock_chapter_id` used the fixed chapter ids from `docs/13_CAMPAIGN_LEVELS_1-5.md` up front
    (per this task's own note that they're fixed by that doc) rather than waiting for Wave 2/Task 13.
  - Add `home_island_id`, `allegiance_faction_id`, `unlock_chapter_id`, `portrait_path` to
    `scripts/world/CaptainData.gd` per `design.md` A4.
  - Author `home_island_id` and `allegiance_faction_id` on all 20 captains per
    `docs/12_CHARACTER_BIBLE.md` §4's table. Every value must match a real `island_id` /
    `faction_id` — check the actual `.tres` files, don't guess spellings.
  - Leave `unlock_chapter_id` and `portrait_path` at their defaults for now — chapter ids don't
    exist until Wave 2. Task 13 comes back to fill these in.
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 5. Fix input rebinding (D57)
  - Done 2026-08-16. Chose option 2 (promote to autoload): confirmed `MainMenu.gd` reaches
    Settings via a full `SceneManager.change_scene_with_fade()` scene change, so no World scene
    (and so no scene-local InputManager) exists there — a group lookup would still fail. Registered
    after `SettingsManager` in `project.godot`; removed the node from `World.tscn`; `WorldManager`'s
    sibling lookup and `SettingsMenu`'s two dead `get_tree().root.get_node_or_null()` calls now
    reference the autoload directly. `tests/test_input_rebinding.gd` added (3 tests).
  - Read `scripts/ui/SettingsMenu.gd` and `scenes/world/World.tscn` in full before choosing an
    approach — `design.md` A5 lays out two options (group lookup vs. promoting `InputManager` to
    an autoload) with a tradeoff that depends on whether Settings must work from the main menu.
    Check that before picking.
  - Implement the chosen fix.
  - Write `tests/test_input_rebinding.gd`: instantiate a `World` scene (mirror
    `tests/test_region_gates.gd`'s `before_each` pattern), instantiate `SettingsMenu`, simulate
    a rebind action, and assert `InputMap` actually changed afterward.
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 6. Fix cold start — seed Port Royal as home on new game
  - Done 2026-08-16. Guarded on `not SaveManager.has_save_data()` (a real "no save file exists"
    check) rather than an empty `home_island_id`, so a Continue onto an existing save with a
    different home island is never touched. `World._seed_port_royal_as_home()`, called deferred
    from `World._ready()`. `tests/test_cold_start.gd` added (2 tests).
  - Locate the actual new-game code path (the `SaveManager.delete_save()` call site
    `TutorialManager.gd`'s comments reference is a good anchor).
  - On a genuinely new game only, set Port Royal's `island_type` to `CAPITAL`, its
    `owner_faction` to `PlayerFaction.tres`, and `EmpireManager.home_island_id` to `"port_royal"`.
  - Guard this so an **existing save** with a different home island is never overwritten — key
    the check on "is this a new game," not "is `home_island_id` currently empty."
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 7. **Checkpoint — economy correction** (automated portion verified 2026-08-16)
  - GUT: **254 tests, 253 passing, 1 known failure** (`test_property_21_lod_distance_transitions`),
    up from the 249/248 baseline entering this pass. No regressions.
  - **Manual pass deferred, not skipped** — bundled into the single end-of-milestone manual
    checkpoint (Task 26) per this project's precedent for interactive-only verification
    (`CLAUDE.md`). Not yet confirmed: Shipyard/Tavern *feel*, and rebinding *in actual gameplay*
    rather than through the automated `InputMap` assertion.

---

## Wave 2 — Campaign data model

- [x] 8. Create `DialogueBeatData`, `ObjectiveData`, `ChapterData`
  - Done 2026-08-16, exactly per `design.md` Part B1 (typed `Array[DialogueBeatData]`/
    `Array[ObjectiveData]`, `required_notoriety` dropped in favor of `required_region_id` alone).
  - Create all three resource scripts under `scripts/world/` exactly per `design.md` Part B1.
  - Do not add fields beyond what's specified — this is intentionally the smallest schema that
    covers all 5 chapters in `docs/13_CAMPAIGN_LEVELS_1-5.md`.
  - _Requirements: 6.1_

- [x] 9. Create the `CampaignManager` autoload
  - Done 2026-08-16. `_gate_satisfied()` per design.md; `_catch_up()` (the overshoot case) walks
    forward using the strict gate check only — never speculatively marking a chapter complete just
    because a later one's gate happens to be open, only when `completed_chapter_ids` already holds
    real completions. Boarding/kill signals extended to carry ship/faction identity (see Task 11).
    `tests/test_campaign_manager.gd` (19 tests) covers gating, all 15 objective conditions'
    dispatch, rewards, discovery, and save/load.
  - Create `scripts/managers/CampaignManager.gd` per `design.md` Part B2–B4: chapter loading,
    gate checking (including the "already satisfied on `_ready()`" overshoot case), the generic
    condition-dispatch handler reusing `TutorialManager`'s pattern, and `get_save_data()`/
    `load_save_data()` following the established autoload convention (return duplicates, never
    live containers — see the `FleetManager` D12 lesson in `docs/05_CURRENT_SYSTEMS.md`).
  - Register it in `project.godot`'s `[autoload]` list **immediately after `EmpireManager`**,
    before `TutorialManager`.
  - Wire `SaveManager` to call this autoload's `get_save_data()`/`load_save_data()` alongside the
    others it already round-trips.
  - _Requirements: 6.2–6.8_

- [x] 10. Generalize `TutorialManager`
  - Done 2026-08-16, thin-wrapper path (design.md Part C option 2) — `is_ui_unlocked()` has real
    callers (`IslandMenu.gd`) and retiring the whole file would have dropped
    `tests/test_tutorial_manager.gd`'s coverage, a regression by this project's own rule. Steps/
    dialogue-driving deleted entirely; Chapter 1's own opening/closing beats now cover that role.
    Kept: UI-tab unlock tracking, driven by `CampaignManager.objective_completed`/
    `chapter_completed` via a small authored map, and the completion-flag file. Folded in Wave 4's
    Task 24 (dialogue queue) here too, since `TutorialDialogue.gd` and this manager's signals were
    too tightly coupled to split across phases without a broken intermediate state —
    `TutorialDialogue` now renders `CampaignManager`'s chapter events directly.
  - Read `scripts/managers/TutorialManager.gd` in full. Choose between retiring its step logic
    entirely (preferred) or reducing it to a thin wrapper over `CampaignManager`, per
    `design.md` Part C — the choice depends on how many other places call
    `TutorialManager.is_ui_unlocked()` or similar; check before deciding.
  - Whichever path is chosen, confirm `user://tutorial_state.json`'s completion flag still
    suppresses the mentor dialogue from replaying for an existing player.
  - _Requirements: 7.1, 7.2, 7.3_

- [x] 11. Small enablers: boss id, discovery write path
  - Done 2026-08-16. `ShipStats.ship_id` is only safe for boss identification when the boss uses a
    **dedicated** (non-shared) ShipStats — the current `BossShip.tscn` reuses `ManOWar.tres`, the
    same template sold to the player, which would have misidentified a player-owned Man O'War as
    the boss. Chapter 4/5's boss encounters (Task 16/18) must author their own dedicated ShipStats
    with a unique `ship_id` rather than reuse a purchasable hull. `EncounterManager` gained a
    `ship_destroyed(ship)` signal mirroring `EnemySpawner.enemy_destroyed` (bounded-encounter kills
    weren't visible to anything outside `EncounterManager` before). `BoardingSystem.boarding_resolved`
    gained `target_faction_id`/`target_ship_id` params (previously carried no identity of what was
    boarded at all). Discovery: `CampaignManager._on_player_docked()` sets `IslandData.discovered`.
  - Add a `boss_id` parameter to whatever signal currently reports a boss's death (`design.md`
    E1) — check if bosses already carry an id via `ShipStats.ship_id` from Task 1 before adding
    a second field.
  - Add a write path for `IslandData.discovered`: set true on the existing `player_docked`
    signal, per `design.md` E2. Do not build approach-radius detection — that's M9 scope.
  - _Requirements: 10.1, 10.2_

- [x] 12. **Checkpoint — campaign data model** (verified 2026-08-16)
  - GUT: **275 tests, 274 passing, 1 known failure**, up from 254/253 entering this wave.
  - Authored `resources/campaign/chapters/_TestChapter.tres` (one `DOCK_AT_ISLAND` objective, no
    gate) and confirmed the real `CampaignManager` autoload loaded it, gated it as current, and
    completed it end-to-end on a real `player_docked` signal — zero script changes required, which
    is the milestone's own exit criterion, verified early rather than only at Task 26. Deleted the
    throwaway resource and its verification test afterward, per this task's own instruction.

---

## Wave 3 — Content authoring (Chapters 1–5)

- [x] 13. Fill in captain `unlock_chapter_id`
  - Done in Wave 1's Task 4 instead — the chapter ids were fixed by
    `docs/13_CAMPAIGN_LEVELS_1-5.md` in advance (`ch1_the_drowned_port` … `ch5_the_silver_fleet`),
    per this task's own note that doing so up front is an acceptable sequencing choice.
  - Now that chapter ids exist, go back to Task 4's 20 captain files and set `unlock_chapter_id`
    per `docs/12_CHARACTER_BIBLE.md` §4 — empty for the 4 Chapter-1 captains, set for every other
    captain.
  - _Requirements: 3.2_

- [x] 14. Author Chapter 1 — The Drowned Port
  - Done 2026-08-16. All 8 objectives + 3 opening / 2 closing dialogue beats authored.
  - Create `resources/campaign/chapters/Ch1_TheDrownedPort.tres` and its 8 objectives / opening
    and closing dialogue beats, per `docs/13_CAMPAIGN_LEVELS_1-5.md` §3.
  - This chapter replaces `TutorialManager`'s 8 hardcoded steps — map each old step to its new
    objective 1:1 (sail→1.1 is folded into dock, dock→1.1, build→1.2–1.4/1.6, recruit→1.7,
    combat→1.5, capture→**removed**, since Task 6 already grants Port Royal).
  - _Requirements: 8.1, 8.4_

- [x] 15. Author Chapter 2 — Blood in the Shallows
  - Done 2026-08-16.
  - Per `docs/13_CAMPAIGN_LEVELS_1-5.md` §4. Gate: `required_previous_chapter = "ch1_..."`,
    `required_region_id = ""` (no region gate — it's still Beginner Waters).
  - _Requirements: 8.1, 8.4_

- [x] 16. Author Chapter 3 — The King's Answer
  - Done 2026-08-16. 3.5 (defend-home assignment) is authored as plain `OWN_SHIP_CLASS` — it does
    not additionally verify the ship is flagged via `FleetManager.set_defend_home()`, a disclosed
    simplification rather than extending the fixed `ObjectiveData.Condition` enum for one objective.
  - Per `docs/13_CAMPAIGN_LEVELS_1-5.md` §5. Gate: `required_region_id = "contested_waters"`.
  - _Requirements: 8.1, 8.2, 8.4_

- [x] 17. Author Chapter 4 — The Admiral's Gambit
  - Done 2026-08-16. HMS Intransigent authored as a **dedicated** boss hull
    (`resources/enemies/IntransigentStats.tres`, `scenes/world/IntransigentBoss.tscn`,
    `resources/combat/encounters/IntransigentBoss.tres`) rather than reusing `BossShip.tscn`'s
    shared `ManOWar.tres` — the shared template is also sold to the player, which would have let a
    player-owned Man O'War satisfy `DEFEAT_BOSS`. The "two escort Corvettes" flavor detail is
    deferred (boss-only fight); **the fight has no in-world trigger yet** — it isn't wired into
    the ambient encounter pool (that would let a Chapter 1 player stumble into a Chapter 4 boss)
    nor into any location/chapter-gated trigger, since building one is a real system, not content.
    Reachable today only via a manual `EncounterManager.start_encounter()` call. Flagged as a real
    gap for a follow-up pass, not silently left broken.
  - Per `docs/13_CAMPAIGN_LEVELS_1-5.md` §6. Gate: `required_previous_chapter = "ch3_..."`.
  - _Requirements: 8.1, 8.4_

- [x] 18. Author Chapter 5 — The Silver Fleet
  - Done 2026-08-16. Cárdenas' flagship authored the same way as Task 17's Intransigent — a
    dedicated `CardenasEscortStats.tres`/`CardenasBoss.tscn`/`CardenasBoss.tres`, the "screen +
    shore guns" staging deferred to a single boss-only fight, same disclosed trigger gap.
  - Per `docs/13_CAMPAIGN_LEVELS_1-5.md` §7. Gate: `required_region_id = "imperial_waters"`.
  - _Requirements: 8.1, 8.2, 8.4_

- [x] 19. Verify Cartagena as a second buildable island
  - Verified 2026-08-16 via `tests/test_cartagena_buildable.gd` (5 tests) against Cartagena's real
    `CartagenaOutpost.tres` data: capture, build, upgrade, and tier recalculation all work exactly
    like Port Royal — `Island.gd`/`IslandMenu.gd` have no home-island special-casing. No gap found.
  - _Requirements: 10.3_

- [x] 20. Write the objective-integrity test
  - Done 2026-08-16, `tests/test_campaign_content.gd` (9 tests) — and it earned its keep
    immediately: caught that `BUILD_STRUCTURE` target_ids must be the level-suffixed
    `building_id` (`"farm_l1"`, not `"farm"` — `structure_changed` emits the real
    `BuildingData.building_id`), and that `BOARD_SHIPS`'s target can legitimately be either a
    faction or a dedicated boss `ship_id`.
  - _Requirements: 8.3, 10.4_

- [x] 21. **Checkpoint — content authoring** (verified 2026-08-16)
  - GUT: **290 tests, 289 passing, 1 known failure**, up from 275/274 entering this wave.
  - `tests/test_chapter1_playthrough.gd` (4 tests) drives the real Chapter 1 resource through
    every one of its 8 objectives via the actual signals a playthrough fires — dock, 4 builds,
    3 kills, 1 recruit — confirming completion, the authored gold reward landing, the optional
    objective not blocking, and the hand-off to Chapter 2. This is the mechanical half of this
    checkpoint's manual-pass instruction; **whether it feels right in 25-40 minutes without a
    wiki still needs a human at the controls**, per `CLAUDE.md`'s standing precedent for
    interactive-only verification (same caveat already carried by every combat-feel item in
    `docs/05_CURRENT_SYSTEMS.md`).

---

## Wave 4 — UI and polish

- [x] 22. Captain's Log panel
  - Done 2026-08-16. `scenes/ui/CaptainsLog.tscn` + `scripts/ui/CaptainsLog.gd`, instanced in
    `WorldHUD.tscn` the same way `DeathScreen`/`UpgradeChoiceScreen` already are. The trigger is a
    dynamically-positioned `Button` (`WorldHUD._create_captains_log_button()`) rather than a node
    hand-placed inside `TopBar` — that container is already tightly sized for the speed label
    alone, and every other HUD readout added since M8 (notoriety, objective, ability labels)
    already uses this same anchor-and-grow-inward pattern instead of touching it.
    `tests/test_captains_log.gd` (6 tests): open/close/toggle, completed-chapter summaries,
    required-vs-optional objective sections, and live refresh on `CampaignManager` signals.
  - _Requirements: 9.1_

- [x] 23. HUD objective feedback
  - Done 2026-08-16, via `_on_campaign_objective_completed`/`_chapter_completed`/`_chapter_started`
    hooked in `WorldHUD._ready()`, all routed through the existing `announce_event()`. Stall-hint:
    `_check_objective_stall()` runs from the HUD's existing per-frame `_process()`, tracks time
    since the last real `objective_progressed` signal, and surfaces the first incomplete
    non-optional objective's `hint_text` once per stall (re-armed the next time real progress
    resets the clock).
  - _Requirements: 9.2, 9.4_
  - Connect `WorldHUD` to `CampaignManager.objective_completed` / `chapter_completed`, routing
    through the existing `announce_event()` — no new announcement system.
  - Implement the objective-stall hint: if an objective's progress hasn't advanced in a
    configured duration, surface its `hint_text` the same way.
  - _Requirements: 9.2, 9.4_

- [x] 24. Dialogue beat queue support
  - Done in Wave 2's Task 10 instead — `TutorialDialogue.gd` and `TutorialManager`'s signals were
    too tightly coupled to split across waves without a broken intermediate state (retiring the
    step list would have orphaned `TutorialDialogue`'s only signal connections). It now listens to
    `CampaignManager.chapter_started`/`chapter_completed` directly and advances through
    `opening_beats`/`closing_beats` on Continue.
  - _Requirements: 9.3_

- [x] 25. Update `docs/05_CURRENT_SYSTEMS.md`
  - Document `CampaignManager`, the new autoload registry, the ship/captain schema additions,
    and mark D53–D58 as resolved (D59 was already resolved in the map-reposition pass that
    preceded this milestone).
  - Done 2026-08-25: added the "M7 — Campaign Spine" section to `docs/05_CURRENT_SYSTEMS.md`
    (data model, `CampaignManager`, `TutorialManager` reduction, D57/D58 fixes, content summary,
    exit-criterion verification, the two test-isolation bugs found while writing this pass's
    tests); updated its §2 defect table (D57/D58 now Fixed) and §4 autoload/scene-local-systems
    registry. Also refreshed `docs/14_SYSTEM_INVENTORY.md` (§0 snapshot, §1/§3/§4 system rows,
    §6 process test counts, §7 defect table) and `docs/15_MASTER_PLAN.md` (M7 marked COMPLETE with
    real exit-criteria results, noting the M8-before-M7 execution-order swap).

- [x] 26. **Checkpoint — M7 Complete** (blocking, `checkpoint-reviewer`)
  - Run the full GUT suite; paste real totals.
  - Confirm the milestone's exit criteria from `docs/15_MASTER_PLAN.md`'s M7 section: Chapter 1
    completable without a wiki; every chapter's objectives resolve from real signals; a Man
    O'War costs more than a level-5 Farm; a throwaway Chapter 6 `.tres` loads with zero script
    changes.
  - **PASSED — verified 2026-08-25 by an independent `checkpoint-reviewer` agent run** (not
    self-reported): it ran the real GUT suite itself and got **320 tests / 319 passing / 1
    failing** (the known `test_property_21_lod_distance_transitions` LOD gap), confirmed
    `project.godot`'s autoload order (`InputManager` after `SettingsManager`; `CampaignManager`
    after `EmpireManager`, before `TutorialManager`), confirmed `CampaignManager.gd`/
    `ChapterData.gd`/`ObjectiveData.gd`/`DialogueBeatData.gd` and all 5 chapter `.tres` files
    exist on disk, spot-checked Tasks 1/5/9's actual file contents against their tasks.md claims,
    and confirmed all required test files are present and passing. Exit criteria: every
    chapter's objectives resolve from real signals (PASS, 19 tests in
    `test_campaign_manager.gd`) — a Man O'War costs more than a level-5 Farm (PASS) — throwaway
    Chapter 6 loads with zero script changes (PASS, verified and cleaned up this same pass) —
    "Chapter 1 completable without a wiki" is explicitly a human-feel judgment this environment
    cannot make headlessly (mechanically satisfied per `test_chapter1_playthrough.gd`; see
    `docs/15_MASTER_PLAN.md`'s M7 exit-criteria results for the honest disposition). No
    discrepancies found between any tasks.md checkbox and actual file state.

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

- [ ] 1. Extend `ShipStats` with identity and cost fields
  - Open `scripts/world/ShipStats.gd`. Add `ship_id: String`, `display_name: String`,
    `ship_class: int` (1–5), and `cost_gold`/`cost_wood`/`cost_iron`/`cost_rum: int` per
    `design.md` Part A1.
  - Author all 8 `resources/ships/*.tres` to the exact ladder table in `design.md` A1.
  - **Before authoring, confirm** these are real `@export`ed properties on the script you just
    edited — a `.tres` setting a property the script doesn't export fails silently
    (`docs/05_CURRENT_SYSTEMS.md` D3/D14).
  - _Requirements: 1.1, 1.2_

- [ ] 2. Fix `IslandMenu`'s ship pricing and naming
  - Delete the `cost_gold = int(ship.mass / 100)` block and its wood/iron equivalents in
    `_create_ship_entry()`. Read the four new `cost_*` fields directly.
  - Replace the filename-derived ship name with `ship.display_name`.
  - Do not add a fallback to the old formula for ships missing the new fields — Task 1 already
    authors all 8.
  - Verify manually: a level-5 Farm (1350 gold, already authored) costs less than the cheapest
    ship, and a Man O'War costs more than any single level-5 building.
  - _Requirements: 1.3, 1.4, 1.5_

- [ ] 3. Author captain boarding modifier and hire cost
  - Add `base_boarding_modifier` to all 20 `resources/captains/*.tres`, using the suggested
    values in `docs/12_CHARACTER_BIBLE.md` §5 (C1) or an equivalent ordering.
  - Add `hire_cost_gold` to the 5 captains currently missing it, scaled per
    `docs/12_CHARACTER_BIBLE.md` §4's chapter-tier table.
  - No script change — both fields already exist on `CaptainData.gd`.
  - _Requirements: 2.1, 2.2_

- [ ] 4. Add captain identity fields
  - Add `home_island_id`, `allegiance_faction_id`, `unlock_chapter_id`, `portrait_path` to
    `scripts/world/CaptainData.gd` per `design.md` A4.
  - Author `home_island_id` and `allegiance_faction_id` on all 20 captains per
    `docs/12_CHARACTER_BIBLE.md` §4's table. Every value must match a real `island_id` /
    `faction_id` — check the actual `.tres` files, don't guess spellings.
  - Leave `unlock_chapter_id` and `portrait_path` at their defaults for now — chapter ids don't
    exist until Wave 2. Task 13 comes back to fill these in.
  - _Requirements: 3.1, 3.2, 3.3_

- [ ] 5. Fix input rebinding (D57)
  - Read `scripts/ui/SettingsMenu.gd` and `scenes/world/World.tscn` in full before choosing an
    approach — `design.md` A5 lays out two options (group lookup vs. promoting `InputManager` to
    an autoload) with a tradeoff that depends on whether Settings must work from the main menu.
    Check that before picking.
  - Implement the chosen fix.
  - Write `tests/test_input_rebinding.gd`: instantiate a `World` scene (mirror
    `tests/test_region_gates.gd`'s `before_each` pattern), instantiate `SettingsMenu`, simulate
    a rebind action, and assert `InputMap` actually changed afterward.
  - _Requirements: 4.1, 4.2, 4.3_

- [ ] 6. Fix cold start — seed Port Royal as home on new game
  - Locate the actual new-game code path (the `SaveManager.delete_save()` call site
    `TutorialManager.gd`'s comments reference is a good anchor).
  - On a genuinely new game only, set Port Royal's `island_type` to `CAPITAL`, its
    `owner_faction` to `PlayerFaction.tres`, and `EmpireManager.home_island_id` to `"port_royal"`.
  - Guard this so an **existing save** with a different home island is never overwritten — key
    the check on "is this a new game," not "is `home_island_id` currently empty."
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ] 7. **Checkpoint — economy correction** (blocking, `checkpoint-reviewer`)
  - Run the full GUT suite; paste the real totals, not an assumed number.
  - Manual pass: start a new game, confirm Port Royal is owned immediately; open the Shipyard,
    confirm prices match Task 1's table and a Man O'War can't be bought in the first five
    minutes; open the Tavern, confirm all 20 captains show a hire cost; open Settings, rebind a
    key, confirm it takes effect in actual gameplay.
  - Do not proceed to Wave 2 until this passes.

---

## Wave 2 — Campaign data model

- [ ] 8. Create `DialogueBeatData`, `ObjectiveData`, `ChapterData`
  - Create all three resource scripts under `scripts/world/` exactly per `design.md` Part B1.
  - Do not add fields beyond what's specified — this is intentionally the smallest schema that
    covers all 5 chapters in `docs/13_CAMPAIGN_LEVELS_1-5.md`.
  - _Requirements: 6.1_

- [ ] 9. Create the `CampaignManager` autoload
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

- [ ] 10. Generalize `TutorialManager`
  - Read `scripts/managers/TutorialManager.gd` in full. Choose between retiring its step logic
    entirely (preferred) or reducing it to a thin wrapper over `CampaignManager`, per
    `design.md` Part C — the choice depends on how many other places call
    `TutorialManager.is_ui_unlocked()` or similar; check before deciding.
  - Whichever path is chosen, confirm `user://tutorial_state.json`'s completion flag still
    suppresses the mentor dialogue from replaying for an existing player.
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 11. Small enablers: boss id, discovery write path
  - Add a `boss_id` parameter to whatever signal currently reports a boss's death (`design.md`
    E1) — check if bosses already carry an id via `ShipStats.ship_id` from Task 1 before adding
    a second field.
  - Add a write path for `IslandData.discovered`: set true on the existing `player_docked`
    signal, per `design.md` E2. Do not build approach-radius detection — that's M9 scope.
  - _Requirements: 10.1, 10.2_

- [ ] 12. **Checkpoint — campaign data model** (blocking, `checkpoint-reviewer`)
  - Run the full GUT suite.
  - Author one throwaway test chapter (`resources/campaign/chapters/_TestChapter.tres`) with one
    trivial objective, confirm it loads, gates correctly, and its objective completes when the
    underlying signal fires. Delete the throwaway file after confirming — Wave 3 authors the
    real chapters.

---

## Wave 3 — Content authoring (Chapters 1–5)

- [ ] 13. Fill in captain `unlock_chapter_id`
  - Now that chapter ids exist, go back to Task 4's 20 captain files and set `unlock_chapter_id`
    per `docs/12_CHARACTER_BIBLE.md` §4 — empty for the 4 Chapter-1 captains, set for every other
    captain.
  - _Requirements: 3.2_

- [ ] 14. Author Chapter 1 — The Drowned Port
  - Create `resources/campaign/chapters/Ch1_TheDrownedPort.tres` and its 8 objectives / opening
    and closing dialogue beats, per `docs/13_CAMPAIGN_LEVELS_1-5.md` §3.
  - This chapter replaces `TutorialManager`'s 8 hardcoded steps — map each old step to its new
    objective 1:1 (sail→1.1 is folded into dock, dock→1.1, build→1.2–1.4/1.6, recruit→1.7,
    combat→1.5, capture→**removed**, since Task 6 already grants Port Royal).
  - _Requirements: 8.1, 8.4_

- [ ] 15. Author Chapter 2 — Blood in the Shallows
  - Per `docs/13_CAMPAIGN_LEVELS_1-5.md` §4. Gate: `required_previous_chapter = "ch1_..."`,
    `required_region_id = ""` (no region gate — it's still Beginner Waters).
  - _Requirements: 8.1, 8.4_

- [ ] 16. Author Chapter 3 — The King's Answer
  - Per `docs/13_CAMPAIGN_LEVELS_1-5.md` §5. Gate: `required_region_id = "contested_waters"`.
  - _Requirements: 8.1, 8.2, 8.4_

- [ ] 17. Author Chapter 4 — The Admiral's Gambit
  - Per `docs/13_CAMPAIGN_LEVELS_1-5.md` §6. Gate: `required_previous_chapter = "ch3_..."`.
  - _Requirements: 8.1, 8.4_

- [ ] 18. Author Chapter 5 — The Silver Fleet
  - Per `docs/13_CAMPAIGN_LEVELS_1-5.md` §7. Gate: `required_region_id = "imperial_waters"`.
  - _Requirements: 8.1, 8.2, 8.4_

- [ ] 19. Verify Cartagena as a second buildable island
  - Load or construct a save state with Cartagena captured. Open `IslandMenu` while docked
    there; confirm build/upgrade/tier work identically to Port Royal.
  - If a gap surfaces, fix it as part of this task — Chapter 5 (Task 18) depends on it.
  - _Requirements: 10.3_

- [ ] 20. Write the objective-integrity test
  - `tests/test_campaign_content.gd`, per `design.md` E4: load every authored chapter/objective
    resource and assert every `target_id` resolves against a real island/building/faction/
    captain id.
  - _Requirements: 8.3, 10.4_

- [ ] 21. **Checkpoint — content authoring** (blocking, `checkpoint-reviewer`)
  - Run the full GUT suite.
  - Manual pass: play from a fresh new game through Chapter 1's completion, confirming each
    objective's progress is tracked and the chapter-complete signal fires with the right
    rewards. Per `CLAUDE.md`, a full 5-chapter manual playthrough is not required for this
    checkpoint, but Chapter 1 end-to-end is.

---

## Wave 4 — UI and polish

- [ ] 22. Captain's Log panel
  - `scenes/ui/CaptainsLog.tscn` + `scripts/ui/CaptainsLog.gd` per `design.md` D1. Open it from a
    new button in `WorldHUD.tscn`, matching the existing Pause/Settings button pattern.
  - _Requirements: 9.1_

- [ ] 23. HUD objective feedback
  - Connect `WorldHUD` to `CampaignManager.objective_completed` / `chapter_completed`, routing
    through the existing `announce_event()` — no new announcement system.
  - Implement the objective-stall hint: if an objective's progress hasn't advanced in a
    configured duration, surface its `hint_text` the same way.
  - _Requirements: 9.2, 9.4_

- [ ] 24. Dialogue beat queue support
  - Confirm `TutorialDialogue.tscn`/`.gd` can advance through an `Array[DialogueBeatData]` on
    Continue, not just a single step. Extend it if it currently only handles one step at a time.
  - _Requirements: 9.3_

- [ ] 25. Update `docs/05_CURRENT_SYSTEMS.md`
  - Document `CampaignManager`, the new autoload registry, the ship/captain schema additions,
    and mark D53–D58 as resolved (D59 was already resolved in the map-reposition pass that
    preceded this milestone).

- [ ] 26. **Checkpoint — M7 Complete** (blocking, `checkpoint-reviewer`)
  - Run the full GUT suite; paste real totals.
  - Confirm the milestone's exit criteria from `docs/15_MASTER_PLAN.md`'s M7 section: Chapter 1
    completable without a wiki; every chapter's objectives resolve from real signals; a Man
    O'War costs more than a level-5 Farm; a throwaway Chapter 6 `.tres` loads with zero script
    changes.

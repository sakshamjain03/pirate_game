# Requirements Document

## Introduction

Milestone M7 — Campaign Spine & Economy Correction gives the world a reason and fixes the
economy that reason depends on. M1–M6 built systems that work in isolation; nothing tells the
player why any of them matter, and one of the numbers underneath the M6 economy is broken badly
enough to make M6's own headline requirement (a circular economy where combat funds the empire
and the empire funds a better ship) untestable.

Full design context lives in four companion documents, all written 2026-08-14 and treated as
authoritative for this milestone:

- `docs/06_NARRATIVE_AND_WORLD.md` — the premise, tone, and `ChapterData`/`ObjectiveData`/
  `DialogueBeatData` schemas.
- `docs/11_WORLD_MAP.md` — the corrected island layout (already applied to `World.tscn` and
  verified by `tests/test_world_map_layout.gd` — **not** part of this milestone's remaining
  scope, listed here only so the numbers below are traceable).
- `docs/12_CHARACTER_BIBLE.md` — all 20 existing captains assigned a home, allegiance, and
  unlock chapter, plus the two authoring defects in their stat data.
- `docs/13_CAMPAIGN_LEVELS_1-5.md` — the five chapters' objectives, pacing, and the corrected
  ship-price ladder.

`docs/14_SYSTEM_INVENTORY.md` §7 catalogs seven defects found while writing those documents,
numbered D53–D59 in `docs/05_CURRENT_SYSTEMS.md`. **D53 (ship pricing) must be fixed before any
other work in this milestone**, because every economy target in the campaign chapters is tuned
against the corrected ladder, not the current one.

This milestone assumes M1–M6 are complete and does **not** include the combat-identity rework
described in `docs/navalCombat.md` (auto-fire, captain active abilities, ship modules) — that is
scoped as milestone M8, deliberately kept separate because it touches the core input loop and
this milestone's chapter objectives are written against today's manual-fire combat and do not
depend on it changing.

---

## Glossary

- **Chapter** — a bundle of 3–8 objectives with a gate in front of it and a reward behind it,
  authored as a `ChapterData` resource. See `docs/06_NARRATIVE_AND_WORLD.md` §6.
- **Objective** — a single trackable goal within a chapter, authored as an `ObjectiveData`
  resource, resolved by an existing gameplay signal.
- **Dialogue beat** — a short (≤3 sentence) piece of narrative text shown through the existing
  `TutorialDialogue.tscn` panel, authored as a `DialogueBeatData` resource.
- **Cold start** — the current defect (D58) where a new player owns no island and cannot afford
  to colonize one.

---

## Requirements

### Requirement 1 — Ship pricing correction (D53/D54)

**User Story:** As a player, I want ship prices to reflect their combat power, so that buying a
warship is a real economic decision the way upgrading a building already is.

#### Acceptance Criteria

1. `ShipStats` SHALL gain `cost_gold: int`, `cost_wood: int`, `cost_iron: int`, `cost_rum: int`,
   `ship_id: String`, `display_name: String`, and `ship_class: int`.
2. Every one of the 8 `resources/ships/*.tres` files SHALL set these seven fields to the values
   in `docs/13_CAMPAIGN_LEVELS_1-5.md` §2's target ladder.
3. `IslandMenu._create_ship_entry()` and `_on_buy_ship_pressed()` SHALL read cost from
   `ShipStats`'s new fields. The `cost_gold = int(ship.mass / 100)` formula and its wood/iron
   equivalents SHALL be deleted, not left as a fallback.
4. `IslandMenu`'s ship list SHALL display `ShipStats.display_name` instead of a value derived
   from `resource_path.get_file()`.
5. A level-5 Farm (1350 gold) SHALL cost strictly less than the cheapest new-player-affordable
   warship, and a Man O'War SHALL cost strictly more than any single level-5 building.
6. Existing saves that reference a `ShipStats` by resource path SHALL continue to load — this
   requirement adds fields, it does not change how ships are identified in `FleetManager`'s
   saved roster.

### Requirement 2 — Captain data correction (D55/D56)

**User Story:** As a player, I want my choice of captain to matter in boarding actions the way
it already matters for speed and damage, so that a captain described as a boarder is actually
better at boarding.

#### Acceptance Criteria

1. All 20 `resources/captains/*.tres` files SHALL set `base_boarding_modifier`, using the
   suggested values in `docs/12_CHARACTER_BIBLE.md` §5 (C1) or values a designer substitutes
   that preserve the same relative ordering.
2. All 20 `resources/captains/*.tres` files SHALL set `hire_cost_gold`, scaled by the chapter
   tier in `docs/12_CHARACTER_BIBLE.md` §4 (roughly 400–600 for Chapter 1 captains, 2500–4000
   for Chapter 5 captains).
3. `BoardingSystem`'s existing read of `active_captain.boarding_modifier` SHALL require no code
   change — this requirement is data-only.

### Requirement 3 — Captain identity fields

**User Story:** As a player, I want captains to feel like they come from somewhere and belong to
someone, so the roster reads as a cast rather than a stat table.

#### Acceptance Criteria

1. `CaptainData` SHALL gain `home_island_id: String`, `allegiance_faction_id: String`,
   `unlock_chapter_id: String`, and `portrait_path: String`, per
   `docs/12_CHARACTER_BIBLE.md` §6.
2. All 20 captain files SHALL set `home_island_id` and `allegiance_faction_id` to values matching
   a real `IslandData.island_id` / `FactionData.faction_id`, per the roster table in
   `docs/12_CHARACTER_BIBLE.md` §4. `unlock_chapter_id` SHALL be empty for the four Chapter-1
   captains and set for every other captain.
3. `portrait_path` SHALL default to `""` on every captain; no portrait assets are required by
   this milestone.
4. The Tavern hire list in `IslandMenu` SHALL only show a captain whose `unlock_chapter_id` is
   empty or already completed (per `CampaignManager.is_chapter_completed()`, Requirement 6).
   A locked captain SHALL NOT appear in the list at all (not shown-disabled).

### Requirement 4 — Input rebinding fix (D57)

**User Story:** As a player, I want the control-rebinding screen I can already open to actually
change my controls.

#### Acceptance Criteria

1. `SettingsMenu`'s rebind flow SHALL successfully locate the running `InputManager` instance
   and call `rebind_action()` / `reset_to_defaults()` on it.
2. The fix SHALL NOT change `InputManager`'s location in the scene tree in a way that breaks any
   other caller — verify by searching for all references before deciding between promoting it
   to an autoload or fixing the lookup to a scene-relative or group-based one.
3. A GUT test SHALL simulate the rebind flow end-to-end (open settings while a World scene is
   loaded, trigger a rebind, verify `InputMap` actually changed) — the previous absence of such
   a test is why this defect shipped silently in M6.

### Requirement 5 — Cold start fix (D58)

**User Story:** As a new player, I want to own my starting port from the moment I begin, so
building and upgrading are available immediately rather than gated behind an unreachable cost.

#### Acceptance Criteria

1. WHEN a new game begins THEN Port Royal's `IslandData.island_type` SHALL be `CAPITAL`,
   `owner_faction` SHALL be `PlayerFaction.tres`, and `EmpireManager.home_island_id` SHALL be
   set to `"port_royal"`.
2. The 1000-gold colonize cost SHALL remain unchanged for every island other than Port Royal.
3. A save made before this change (Port Royal still neutral, no home island set) SHALL still
   load without error — this requirement changes new-game initialization, not save loading.
4. This SHALL NOT retroactively grant Port Royal to an existing save where the player already
   colonized a different island as home.

### Requirement 6 — Campaign data model and director

**User Story:** As a designer, I want to author a chapter's story and objectives entirely as
resource files, so that adding Chapter 6 later requires no script changes.

#### Acceptance Criteria

1. The system SHALL define `ChapterData`, `ObjectiveData`, and `DialogueBeatData` resource
   scripts exactly per the schemas in `docs/06_NARRATIVE_AND_WORLD.md` §6.
2. A new autoload `CampaignManager` SHALL be registered in `project.godot`, after
   `EmpireManager`.
3. `CampaignManager` SHALL load all `resources/campaign/chapters/*.tres` on `_ready()`, ordered
   by `chapter_number`.
4. `CampaignManager` SHALL track, per objective, current progress against its target count, by
   subscribing only to signals that already exist (enumerated in
   `docs/13_CAMPAIGN_LEVELS_1-5.md` §8).
5. `CampaignManager` SHALL emit `chapter_started(ChapterData)`,
   `objective_progressed(objective_id, current, target)`, `objective_completed(objective_id)`,
   and `chapter_completed(ChapterData)`.
6. `CampaignManager` SHALL expose `is_chapter_completed(chapter_id: String) -> bool`.
7. `CampaignManager` SHALL implement `get_save_data()` / `load_save_data()` following the
   existing autoload convention, persisting `current_chapter_id`, `completed_chapter_ids`, and
   per-objective progress.
8. A chapter whose gate condition (region activation and/or previous-chapter completion) is
   already satisfied when `CampaignManager` initializes (e.g. a save loaded after the player
   overshot notoriety) SHALL start immediately rather than waiting for a new signal — this is
   the "chapters can be skipped by overshooting" anti-softlock rule in
   `docs/06_NARRATIVE_AND_WORLD.md` §7.

### Requirement 7 — Generalize `TutorialManager`, do not duplicate it

**User Story:** As a maintainer, I want one narrative-content system, not two, so that the
tutorial and the campaign do not diverge or need to be kept in sync by hand.

#### Acceptance Criteria

1. `TutorialManager`'s 8 hardcoded steps SHALL be re-authored as Chapter 1's objectives in
   `docs/13_CAMPAIGN_LEVELS_1-5.md` §3.
2. `TutorialManager`'s `wait_for` / `_check_condition()` dispatch pattern SHALL be reused by
   `CampaignManager` rather than reimplemented — either by `CampaignManager` absorbing
   `TutorialManager`'s responsibility outright, or by `TutorialManager` becoming a thin
   compatibility shim over `CampaignManager` for its one remaining first-launch responsibility
   (the mentor dialogue sequence). The implementer SHALL choose the smaller diff after reading
   both scripts in full; either satisfies "never duplicate systems."
3. Existing tutorial-completion save data (`user://tutorial_state.json`) SHALL continue to
   prevent the tutorial dialogue from replaying for existing players, whichever approach is
   taken.

### Requirement 8 — Chapters 1–5 authored as content

**User Story:** As a player, I want a story that follows my empire's growth from a drowned ruin
to a contested naval power, so the grind has a shape.

#### Acceptance Criteria

1. All 5 chapters in `docs/13_CAMPAIGN_LEVELS_1-5.md` §3–7 SHALL be authored as `ChapterData`
   resources under `resources/campaign/chapters/`, with their objectives and dialogue beats as
   sibling resources under `resources/campaign/objectives/` and `resources/campaign/dialogue/`.
2. Chapter 2 and Chapter 5's gate conditions SHALL be `EmpireManager.region_activated` for
   `contested_waters` and `imperial_waters` respectively — not a new notoriety threshold
   authored independently of `RegionData`.
3. Every `target_id` referenced by an objective (building id, island id, faction id) SHALL
   resolve to a real, existing resource. A test SHALL enforce this (Requirement 10.4).
4. A player who completes every non-optional objective in a chapter SHALL trigger that chapter's
   `chapter_completed` signal without any further action.

### Requirement 9 — Captain's Log UI and HUD objective feedback

**User Story:** As a player, I want to see what chapter I'm on and what's left to do, so I don't
have to guess what the game wants from me.

#### Acceptance Criteria

1. A new UI panel ("Captain's Log") SHALL list completed chapters and the active chapter's
   incomplete objectives with live progress.
2. `WorldHUD` SHALL announce objective completion and chapter completion via the existing
   `announce_event()` mechanism — no new announcement system.
3. Dialogue beats SHALL render through the existing `TutorialDialogue.tscn` scene.
4. An objective with no progress for a configured stall duration SHALL surface its
   `hint_text` through `announce_event()`, per `docs/06_NARRATIVE_AND_WORLD.md` §7 rule 4.

### Requirement 10 — Small enablers and verification

**User Story:** As a developer, I want the remaining small gaps the chapters depend on closed,
so no chapter objective silently fails to resolve.

#### Acceptance Criteria

1. The boss-death signal used by `DEFEAT_BOSS` objectives SHALL carry a boss id string so an
   objective can distinguish "HMS Intransigent defeated" from any other boss.
2. `IslandData.discovered` SHALL gain at least one real write path (e.g. set true on first dock
   or first approach within a configured radius), sufficient for a `DISCOVER_ISLAND` objective
   to resolve. Full fog-of-war/map UI remains out of scope (M9).
3. Cartagena Outpost SHALL be verified to function as a second buildable island through the
   existing `IslandMenu` flow (build, upgrade, tier) with no code changes required — if a gap is
   found, it SHALL be fixed as part of this milestone since Chapter 5 depends on it.
4. A GUT test SHALL load every authored `ChapterData`/`ObjectiveData` resource and assert every
   `target_id` field resolves against the real `IslandData`/`BuildingData`/`FactionData`/
   `CaptainData` registries.

---

## Non-Goals

Explicitly **out of scope** for M7:

- The combat-identity rework in `docs/navalCombat.md` (auto-fire, captain active abilities,
  ship modules, temporary battle upgrades) — milestone M8.
- Ocean LOD, the Expanded map, discovery/fog UI beyond Requirement 10.2, a world map screen,
  per-region weather — milestone M9.
- New islands, new techs, new world events beyond what Requirement 8 authors — milestone M10.
- Portrait art — `portrait_path` ships empty per Requirement 3.3.
- Chapters 6+ — shape only, per `docs/13_CAMPAIGN_LEVELS_1-5.md` §9.
- Any change to the map layout — already applied to `World.tscn` and verified by
  `tests/test_world_map_layout.gd` prior to this milestone's start.

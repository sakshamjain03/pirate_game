# Requirements Document

## Introduction

The five-chapter campaign ships and is completable, but it doesn't **teach the game**, and a
chunk of the game isn't part of it at all. Chapter objectives exercise sailing, docking,
building, combat, capture, captains, ship classes, boarding, raids, research and bosses — but
seven systems have no lesson and no objective anywhere:

| Never taught | Exists in |
|---|---|
| Manual fire (M25) | `ShipCombat`, `fire_port`/`fire_starboard` |
| Ammo swap and the hull/sails/crew triangle (M25) | `ShipCombat.cycle_ammo()`, `EnemyHealthBarWidget` |
| Factions and reputation | `FactionManager.reputation_changed` |
| Pieces of Eight | `ResourceManager.PREMIUM_CURRENCY`, `EmpireManager.spend_to_reduce_heat()` |
| Repair | `IslandMenu` repair, `DockingSystem` passive repair |
| Fleet management / captain assignment | `FleetManager.active_ship_changed` |
| World-map navigation | `WorldMapScreen.course_requested` |

Heat (M25) is touched by one objective (3.4 "Survive a raid") but never explained, and there is no
skippable onboarding: `TutorialManager.skip_tutorial()` exists but no UI calls it, and the only
skip button skips the *current dialogue*, not onboarding.

This milestone adds **lessons** — short, non-blocking coach cards triggered in context — plus a
**cohesion pass** that gives every system at least one objective, so the five chapters teach the
whole game in the order a player needs it. A **skip** at New Game turns lessons off without
touching the story or objectives; Settings can replay them.

**Onboarding stays in `CampaignManager` + `ChapterData`** (CLAUDE.md fragile area: "check
`CampaignManager` before adding a second onboarding system"). Lessons are chapter content;
`TutorialManager` only holds the on/off flag and the seen-lesson set.

**Already met, no work needed:** 5 shipping chapters with dialogue beats, objectives and rewards;
`CampaignManager` objective tracking off existing signals; `TutorialDialogue` renders chapter
beats; `TutorialManager` tab-unlock flags and completion flag; `content_enabled` gating and
`tests/test_content_gate_integrity.gd`.

## Glossary

- **Lesson** — one authored `LessonData`: an id, a short title and body, a trigger, an optional UI
  highlight, attached to a chapter. Shown at most once per profile.
- **Coach card** — the non-modal UI a lesson appears in. Never pauses the game, never blocks
  input, dismisses itself after an authored time or on tap.
- **Trigger** — the event that shows a lesson: chapter start, an objective becoming current, or
  one of a fixed set of game events (first enemy in range, first dock, heat tier up, first job
  started, first Eights granted, …).
- **Lessons enabled** — `TutorialManager.lessons_enabled`. False after "I know these waters".
- **System coverage table** — the list, in a test, of every player-facing system and the lesson
  and objective that cover it.

## Requirements

### Requirement 1: Lessons as chapter content

**User Story:** As a new player, I want short hints at the moment a system becomes relevant, so
that I learn the game while playing it.

#### Acceptance Criteria

1. `LessonData` SHALL export `lesson_id`, `title`, `body`, `trigger`, `trigger_arg`,
   `highlight_group`, `display_seconds`.
2. `ChapterData` SHALL gain `@export var lessons: Array[LessonData]`.
3. `CampaignManager` SHALL show a lesson WHEN its trigger fires, its chapter is current
   (`is_chapter_current()`), lessons are enabled, and it hasn't been seen.
4. A shown lesson's id SHALL be recorded in `TutorialManager` and persisted.
5. An unknown `lesson_id` referenced anywhere SHALL `push_error`, never skip silently.
6. Lessons SHALL appear on a non-modal coach card that never pauses the tree and never
   overlaps `TutorialDialogue`. WHILE a dialogue is blocking, lessons SHALL queue.

### Requirement 2: Every system is taught and used

**User Story:** As a player, I want each chapter to make me use what it just taught, so that the
five chapters add up to knowing the whole game.

#### Acceptance Criteria

1. Every system in the coverage table SHALL have at least one lesson and at least one objective
   in chapters 1-5. Systems: sailing, docking, building, economy/storage, manual fire, ammo swap
   and the damage triangle, boarding, capture, captains, fleet/captain assignment, ship classes,
   repair, heat, factions/reputation, world map, research, raids/defence, Pieces of Eight, timers
   (after M27), the Maelstrom (lesson only).
2. New `ObjectiveData.Condition` values SHALL be **appended** after `SURVIVE_RAID`:
   `SWAP_AMMO`, `CRIPPLE_SAILS`, `LOWER_HEAT`, `ASSIGN_CAPTAIN`, `CHANGE_REPUTATION`,
   `SET_COURSE`, `REPAIR_SHIP`. Existing values SHALL keep their integers.
3. Each new condition SHALL be tracked in `CampaignManager` from an existing signal:
   `ShipCombat.ammo_changed`, enemy `ShipDamage.pool_changed` (sails → 0) on a player-damaged
   ship, `EmpireManager.heat_tier_changed` (downward), `FleetManager.active_ship_changed`,
   `FactionManager.reputation_changed`, `WorldMapScreen.course_requested`, player
   `ShipDamage.pool_changed` (increase while docked).
4. New objectives SHALL only progress while their chapter is current.
5. `TutorialManager`'s objective→tab unlock map SHALL point at the objectives it describes
   (it currently reads "1.7 recruit, 1.5 combat" but Ch1's 1.7 is the tavern, 1.8 recruits and
   1.6 is combat).
6. Each chapter's closing dialogue SHALL set up the next chapter's first need, and
   `docs/13_CAMPAIGN_LEVELS_1-5.md` SHALL record the final objective list per chapter.

### Requirement 3: Skip and replay

**User Story:** As an experienced player, I want to skip the lessons but keep the story; as a
returning player, I want to see them again.

#### Acceptance Criteria

1. WHEN the player starts a New Game, THE main menu SHALL ask "Teach me the ropes" / "I know
   these waters". Returning players whose completion flag is set SHALL default to the latter.
2. "I know these waters" SHALL set `lessons_enabled = false` and call the existing
   `skip_tutorial()` (unlocks all tabs). Chapter 1's dialogue, objectives and rewards SHALL still
   run.
3. Settings SHALL offer "Replay lessons", which clears the seen set and sets
   `lessons_enabled = true`.
4. `lessons_enabled` and the seen set SHALL persist in the `tutorial` save section.

### Requirement 4: Timer lesson (depends on M27)

**User Story:** As a player, I want to learn that builds take time and how to speed them up.

#### Acceptance Criteria

1. A lesson with trigger `FIRST_JOB_STARTED` SHALL be authored against
   `ScheduleManager.job_started`.
2. WHILE `ScheduleManager` does not exist, the trigger SHALL never fire and SHALL NOT error, and
   the coverage test SHALL mark timers as pending rather than failing.

## Out of Scope

- **Rewriting the chapter stories.** Dialogue edits are limited to hand-offs between chapters and
  lines needed to introduce a new objective.
- **Voice-over, animated tutorials, forced tutorial steps.** Lessons never block play.
- **Chapters 6-10** (content-gated off since M24).
- **A Maelstrom tutorial.** One pointer lesson; the mode teaches itself.
- **Balance changes to rewards.** M33's zero-spend balance pass owns that.

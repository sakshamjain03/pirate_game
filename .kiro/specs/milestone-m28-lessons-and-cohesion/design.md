# Design Document: Milestone M28 — Lessons & Campaign Cohesion

## 1. Why this design shape

**Lessons are chapter content, not a tutorial system.** The project already retired one
hardcoded onboarding system (`TutorialManager`'s old 8 steps) in favour of `CampaignManager` +
`ChapterData`. Lessons go the same way: authored resources hanging off the chapter that needs
them, fired by `CampaignManager` from signals it already listens to. `TutorialManager` gains a
flag and a seen-set, nothing more.

**Teach by objective, remind by lesson.** A lesson alone is a tooltip players dismiss. Each
system gets an objective that makes the player *do* it, and a lesson that appears the moment it
becomes relevant. The coverage test is what stops a future system from shipping untaught.

**Non-modal.** `TutorialDialogue` is the modal channel (story). The coach card is the other
channel (mechanics), and it must never pause the tree or steal input — a lesson that interrupts
a fight teaches the player to dismiss lessons.

## 2. New/changed files

| File | Change |
|---|---|
| **new** `scripts/world/LessonData.gd` | the resource |
| **new** `resources/campaign/lessons/*.tres` | ~20 lessons |
| `scripts/world/ChapterData.gd` | `@export var lessons: Array[LessonData] = []` |
| `scripts/world/ObjectiveData.gd` | append 7 `Condition` values |
| `scripts/managers/CampaignManager.gd` | lesson triggers; new condition tracking; `lesson_requested(lesson)` signal |
| `scripts/managers/TutorialManager.gd` | `lessons_enabled`, `_seen_lessons`, `mark_seen()`, `has_seen()`, `replay_lessons()`; save data; fix the unlock map |
| **new** `scripts/ui/LessonCoachCard.gd` (+ `.tscn`) | non-modal card, queue, highlight pulse |
| `scripts/ui/WorldHUD.gd` | additive: instance the coach card inside the existing HUD container |
| `scripts/ui/MainMenu.gd` + `.tscn` | additive: New Game → lessons prompt |
| `scripts/ui/SettingsMenu.gd` | "Replay lessons" |
| `resources/campaign/chapters/Ch1-5_*.tres` | new objectives, lessons, hand-off lines |
| `docs/13_CAMPAIGN_LEVELS_1-5.md` | final objective + lesson list |
| **new** `tests/test_lessons.gd`, `test_campaign_coverage.gd`, `test_new_objective_conditions.gd` | |

## 3. `LessonData`

```gdscript
class_name LessonData extends Resource
enum Trigger {
	CHAPTER_STARTED,       # trigger_arg unused
	OBJECTIVE_CURRENT,     # trigger_arg = objective_id
	FIRST_ENEMY_IN_RANGE,  # FiringSolver arc-lock on the player ship, first time
	FIRST_DOCK,
	FIRST_DAMAGE_TAKEN,
	HEAT_TIER_UP,
	FIRST_EIGHTS,          # ResourceManager.resources_changed with eights > 0
	FIRST_JOB_STARTED,     # ScheduleManager.job_started (M27; no-op if absent)
	CHAPTER_COMPLETED,
}
@export var lesson_id: String
@export var title: String
@export_multiline var body: String
@export var trigger: Trigger
@export var trigger_arg: String = ""
@export var highlight_group: StringName = &""   # a node group, e.g. &"hud_ammo_button"
@export var display_seconds: float = 8.0
```

`Trigger` is int-serialized like `Condition`: append only once shipped.

## 4. Firing lessons

`CampaignManager` already connects to scene signals in `_connect_scene_signals()` (L85-110) and
re-runs it per scene. Add the lesson sources there; add `_fire_trigger(trigger, arg)`:

```gdscript
func _fire_trigger(trigger: int, arg: String = "") -> void:
	if not TutorialManager.lessons_enabled or not _current_chapter:
		return
	for lesson in _current_chapter.lessons:
		if lesson.trigger == trigger and (lesson.trigger_arg == "" or lesson.trigger_arg == arg) \
				and not TutorialManager.has_seen(lesson.lesson_id):
			TutorialManager.mark_seen(lesson.lesson_id)
			lesson_requested.emit(lesson)
```

`ScheduleManager` is optional until M27 lands: `if Engine.has_singleton(...)`/`get_node_or_null
("/root/ScheduleManager")` and `has_signal("job_started")` before connecting. No error either
way.

`LessonCoachCard` listens to `CampaignManager.lesson_requested`, queues, and shows one at a time
**only when `TutorialDialogue.is_blocking()` is false**. It adds a pulse to the first node in
`highlight_group` (if any). The card is placed in the HUD's existing container layout, not at a
pixel offset (CLAUDE.md fragile-area rule).

## 5. New conditions — signal sources

| Condition | Source | Progress rule |
|---|---|---|
| `SWAP_AMMO` | player `ShipCombat.ammo_changed(ammo)` | `ammo.ammo_id == target_id` (or any, if empty) |
| `CRIPPLE_SAILS` | enemy `ShipDamage.pool_changed("sails", 0, _)`, connected via `EnemySpawner.enemy_spawned` + encounter spawns | count; only if the player damaged it (`EnemyAI` provoked flag) |
| `LOWER_HEAT` | `EmpireManager.heat_tier_changed(tier)` | tier dropped below the tier when the objective became current |
| `ASSIGN_CAPTAIN` | `FleetManager.active_ship_changed(ship, captain)` | captain not null |
| `CHANGE_REPUTATION` | `FactionManager.reputation_changed(id, rep)` | `id == target_id` and `rep >= target_value` |
| `SET_COURSE` | `WorldMapScreen.course_requested(island)` | `island.id == target_id` (or any) |
| `REPAIR_SHIP` | player `ShipDamage.pool_changed(hull, cur, _)` rising while docked | once |

**Hazard — `ammo_changed` fires from `set_ammo()` on load/ship swap too.** `SWAP_AMMO` must only
count a change made after the objective became current, and only to a *different* ammo.

**Hazard — M27 changes repair.** Under M27 a shipyard repair becomes a job that applies on
completion; the `pool_changed`-rising rule works both before and after. Don't hook
`IslandMenu._on_repair_ship_pressed` (M27 owns that file).

## 6. Where the new objectives go

| Ch | New objective | Condition | Lessons in this chapter |
|---|---|---|---|
| 1 | "Load chain shot" (after 1.6) | SWAP_AMMO chain | sailing, docking, building/economy, manual fire, ammo & triangle, captains |
| 2 | "Shred a raider's rigging" | CRIPPLE_SAILS ×1 | boarding, ship classes, capture, **repair**, **timers** (M27) |
| 2 | "Patch her up at the shipyard" (after 2.2) | REPAIR_SHIP | |
| 3 | "Let the Navy lose your scent" (after 3.1) | LOWER_HEAT | **heat**, raids/defence, **fleet & captain assignment**, **Eights** (first reward) |
| 3 | "Give the new hull a captain" | ASSIGN_CAPTAIN | |
| 4 | "Plot a course to the cay" (before 4.1) | SET_COURSE | **world map**, research, **factions** |
| 4 | "Earn the merchants' trust" | CHANGE_REPUTATION merchant_guild | |
| 5 | — | — | the Maelstrom (pointer, at chapter completion) |

Final ids are appended (1.10, 2.8, 2.9, …) so existing ids — which `TutorialManager` and saves
reference — never renumber.

## 7. Skip / replay

- New Game → a two-button dialog (kit `PirateThemeBuilder` styling). "Teach me the ropes":
  `lessons_enabled = true`. "I know these waters": `lessons_enabled = false` +
  `skip_tutorial()`. Then the existing New Game path runs unchanged.
- Settings → "Replay lessons" → `TutorialManager.replay_lessons()` (clear seen, enable). Lessons
  for the current chapter fire again as their triggers recur.
- Save: `tutorial` section gains `lessons_enabled` and `seen_lessons`. Old saves without them
  load as `lessons_enabled = true`, empty seen set.

@tool
class_name LessonData extends Resource

## Purpose: one M28 lesson — a short, non-blocking coach card shown the moment a
## system becomes relevant. Lessons are chapter content, not a second onboarding
## system: they hang off `ChapterData.lessons`, `CampaignManager` fires them from
## signals it already listens to, and `TutorialManager` only remembers which ids
## have been seen and whether lessons are on at all.
## Responsibilities: pure data. `CampaignManager` is the only thing that
## interprets `trigger`/`trigger_arg`; `LessonCoachCard` only renders.

## Int-serialized in every chapter `.tres`, exactly like `ObjectiveData.Condition`:
## APPEND ONLY. Inserting a value silently re-targets every lesson after it.
enum Trigger {
	CHAPTER_STARTED,       # trigger_arg unused
	OBJECTIVE_CURRENT,     # trigger_arg = objective_id (becomes the first incomplete objective)
	FIRST_ENEMY_IN_RANGE,  # player ShipCombat.arc_lock_changed(side, true)
	FIRST_DOCK,
	FIRST_DAMAGE_TAKEN,
	HEAT_TIER_UP,
	FIRST_EIGHTS,          # ResourceManager.resources_changed with eights > 0
	FIRST_JOB_STARTED,     # ScheduleManager.job_started; trigger_arg = job kind, or empty for any
	CHAPTER_COMPLETED,
}

## Unique across every chapter. Saved in `TutorialManager`'s seen set, so never
## rename one once shipped.
@export var lesson_id: String = ""
@export var title: String = ""
@export_multiline var body: String = ""
@export var trigger: Trigger = Trigger.CHAPTER_STARTED
@export var trigger_arg: String = ""
## A node group the coach card pulses while the lesson is up, e.g.
## &"hud_ammo_button". Empty = no highlight. A group with no member is fine —
## on desktop some HUD controls simply do not exist.
@export var highlight_group: StringName = &""
@export var display_seconds: float = 8.0

@tool
class_name SeasonalEventData extends Resource

## Purpose: M14 Requirement 3 — a repeatable, seasonally-windowed piece of
## content (the Spring Crossing). Deliberately NOT `ChapterData`: that
## resource's `CampaignManager.is_chapter_completed()` model is a permanent
## one-way flag, wrong for "available again next spring." Reuses
## `ObjectiveData` for its objectives — the same condition/dispatch model
## chapters already use — since the objective shape itself doesn't change,
## only how completion is tracked (see `SeasonalEventManager`).

@export var event_id: String = ""
@export var display_name: String = ""
@export_multiline var log_summary: String = ""

@export_group("Window")
## "MM-DD" — the authored local fallback window, used whenever
## `LiveOpsConfig`'s remote value is absent (M14 Requirement 6). Deliberately
## a plain string, not a Date struct: month/day only, no year, since the
## window recurs every year.
@export var fallback_window_start_month_day: String = "03-01"
@export var fallback_window_end_month_day: String = "05-31"

@export_group("Content")
@export var objectives: Array[ObjectiveData] = []

@export_group("Rewards")
@export var reward_gold: int = 0
@export var reward_captain_id: String = ""
@export var reward_ship_id: String = ""
@export var reward_tech_id: String = ""

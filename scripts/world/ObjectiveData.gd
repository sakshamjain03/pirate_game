@tool
class_name ObjectiveData extends Resource

## Purpose: one chapter objective — the smallest unit `CampaignManager` tracks
## progress against (`docs/13_CAMPAIGN_LEVELS_1-5.md` §8's condition-coverage
## audit maps every `Condition` value to a real, already-existing signal).
## Responsibilities: pure data. `CampaignManager` is the only thing that
## interprets `condition`/`target_id`/`target_count` — nothing else should
## branch on this enum, per AGENTS.md's "never duplicate systems".

enum Condition {
	BUILD_STRUCTURE, UPGRADE_STRUCTURE_TO_LEVEL, REACH_ISLAND_TIER,
	DESTROY_SHIPS, BOARD_SHIPS, DEFEAT_BOSS,
	CAPTURE_ISLAND, DISCOVER_ISLAND, DOCK_AT_ISLAND,
	RECRUIT_CAPTAIN, OWN_SHIP_CLASS, UNLOCK_TECH,
	ACCUMULATE_RESOURCE, REACH_NOTORIETY, SURVIVE_RAID,
}

@export var objective_id: String = ""
@export var description: String = ""
@export var condition: Condition = Condition.DOCK_AT_ISLAND
## Meaning depends on `condition`: a building/island/faction/tech/encounter id
## for most conditions, a resource key for ACCUMULATE_RESOURCE, empty for
## conditions with no target (RECRUIT_CAPTAIN, SURVIVE_RAID, REACH_NOTORIETY).
@export var target_id: String = ""
## Kill/board/recruit counts. Ignored by the level-check conditions below.
@export_range(1, 50) var target_count: int = 1
## Absolute-value threshold for REACH_ISLAND_TIER / REACH_NOTORIETY /
## ACCUMULATE_RESOURCE — these set progress to the current value rather than
## incrementing a counter.
@export var target_value: float = 0.0
@export var is_optional: bool = false
## Surfaced through WorldHUD.announce_event() if progress stalls.
@export var hint_text: String = ""


func is_level_check() -> bool:
	return condition in [Condition.REACH_ISLAND_TIER, Condition.REACH_NOTORIETY,
		Condition.ACCUMULATE_RESOURCE]

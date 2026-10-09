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
	# M28 — appended, never inserted: every chapter .tres stores these as ints,
	# so a value added mid-list silently re-targets every objective after it
	# (tests/test_new_objective_conditions.gd pins the existing ints).
	SWAP_AMMO, CRIPPLE_SAILS, LOWER_HEAT, ASSIGN_CAPTAIN,
	CHANGE_REPUTATION, SET_COURSE, REPAIR_SHIP,
	# M30 W2 (2.9) - appended, never inserted (same rule as above). CAPTURE_SHIPS: take ships by
	# their colours (target_id = a faction id or a hull ship_id, empty for any). SELL_PRIZE: sell a
	# prize to a port's prize court (target_id = a court_id, empty for any).
	CAPTURE_SHIPS, SELL_PRIZE,
}

@export var objective_id: String = ""
@export var description: String = ""
@export var condition: Condition = Condition.DOCK_AT_ISLAND
## Meaning depends on `condition`: a building/island/faction/tech/encounter id
## for most conditions, a resource key for ACCUMULATE_RESOURCE, an
## `AmmoData.ammo_id` for SWAP_AMMO, an island id for SET_COURSE, a faction id
## for CHANGE_REPUTATION/CRIPPLE_SAILS, empty for conditions with no target
## (RECRUIT_CAPTAIN, SURVIVE_RAID, REACH_NOTORIETY, LOWER_HEAT, ASSIGN_CAPTAIN,
## REPAIR_SHIP) or to accept any.
@export var target_id: String = ""
## Kill/board/recruit counts. Ignored by the level-check conditions below.
@export_range(1, 50) var target_count: int = 1
## Absolute-value threshold for REACH_ISLAND_TIER / REACH_NOTORIETY /
## ACCUMULATE_RESOURCE / CHANGE_REPUTATION — these set progress to the current
## value rather than incrementing a counter.
@export var target_value: float = 0.0
@export var is_optional: bool = false
## Surfaced through WorldHUD.announce_event() if progress stalls.
@export var hint_text: String = ""


func is_level_check() -> bool:
	return condition in [Condition.REACH_ISLAND_TIER, Condition.REACH_NOTORIETY,
		Condition.ACCUMULATE_RESOURCE, Condition.CHANGE_REPUTATION]

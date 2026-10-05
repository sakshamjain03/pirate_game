@tool
class_name StarConditionData extends Resource

## Purpose: one authored star condition (M30 1.13) — a cosmetic achievement
## in an encounter. Stars never gate campaign content; they are purely tracking
## and UI rewards.
## Responsibilities: pure data. `EncounterManager` evaluates each on resolve
## and emits their count. `CampaignManager` saves the best count per encounter.

enum Condition {
	QUICK_VICTORY,  ## encounter won in <= target_value seconds
	PERFECT_DEFENSE,  ## no damage taken (target_value = 0, ignored)
	ZERO_LOSSES,  ## no crew lost (target_value = 0, ignored)
}

@export var condition: Condition = Condition.QUICK_VICTORY
@export var target_value: float = 0.0  # placeholder: tune in M31


func get_display_name() -> String:
	match condition:
		Condition.QUICK_VICTORY:
			return "Quick Victory"
		Condition.PERFECT_DEFENSE:
			return "Perfect Defense"
		Condition.ZERO_LOSSES:
			return "Zero Losses"
		_:
			return "Unknown Star"

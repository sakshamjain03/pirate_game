@tool
class_name StarConditionData extends Resource

## Purpose: one authored star condition (M30 1.13) — a cosmetic achievement
## in an encounter. Stars never gate campaign content; they are purely tracking
## and UI rewards.
## Responsibilities: pure data. `EncounterManager` evaluates each on resolve
## and emits their count (`stars_awarded`). `CampaignManager` saves the best
## count per encounter id. The Spyglass Briefing shows the second condition as
## its "star-2 hint", so author the conditions easiest first.

## Int-serialized in every encounter .tres: APPEND ONLY, never reorder.
enum Condition {
	QUICK_VICTORY,  ## encounter won in <= target_value seconds
	PERFECT_DEFENSE,  ## no hull damage taken this battle (target_value ignored)
	ZERO_LOSSES,  ## no crew lost this battle (target_value ignored)
	VICTORY,  ## the encounter was won at all (target_value ignored) — the 1st star
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
		Condition.VICTORY:
			return "Victory"
		_:
			return "Unknown Star"


## The player-facing goal, e.g. "Win within 120 s".
func describe() -> String:
	match condition:
		Condition.QUICK_VICTORY:
			return "Win within %d s" % int(round(target_value))
		Condition.PERFECT_DEFENSE:
			return "Win without taking hull damage"
		Condition.ZERO_LOSSES:
			return "Win without losing crew"
		Condition.VICTORY:
			return "Win the fight"
		_:
			return get_display_name()

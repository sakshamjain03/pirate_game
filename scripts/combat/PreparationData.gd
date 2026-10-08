@tool
class_name PreparationData extends Resource

## Purpose: one Spyglass Briefing preparation (M30 1.9, W1-2.1) — the single
##   pre-battle order the player picks before a fight ("double-shot the guns").
## Responsibilities: pure data. Its effect IS a BattleUpgradeData, applied by
##   `EncounterManager.apply_briefing()` through the same
##   `CombatModifiers.apply_upgrade()` the in-battle offers use, so it is
##   temporary for this battle (reset on resolve) without a second modifier
##   system.

@export var preparation_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Shown on the briefing card (emoji; the project has no icon set yet).
@export var icon: String = "⚙"
## Give it its own `upgrade_id` (prep_*), so it never shares stacks with an
## in-battle offer of the same effect.
@export var effect: BattleUpgradeData


func describe() -> String:
	if description != "":
		return description
	return effect.describe() if effect else ""

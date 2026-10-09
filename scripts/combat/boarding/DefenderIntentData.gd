@tool
class_name DefenderIntentData extends Resource

## Purpose: one telegraphed thing a boarding defender will do on the next bell (M30 2.2).
## Responsibilities: pure data. A defender cycles through its `intents` in order; the
##   BoardingOverlay shows the upcoming one so the player can answer it (Parry cancels it,
##   Shove moves the defender out of reach, a Brace shrugs off the outside guns).

enum Kind {
	STRIKE,  ## melee: hurts the boarding party, but only if the defender shares its zone
	SHOOT,   ## ranged: hurts the boarding party from any zone
	GUARD,   ## braces behind cover: takes less damage from the NEXT player phase
	RALLY,   ## shouts the crew back into line: restores enemy morale
	CHARGE,  ## closes one zone toward the boarding party
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.STRIKE
## Added to the defender's own `attack` for STRIKE/SHOOT; the morale restored for RALLY.
@export var power: int = 0  # placeholder: tune in M31
## Glyph for the telegraph disc until real art lands (docs/10_ASSET_REQUESTS.md).
@export var glyph: String = ""

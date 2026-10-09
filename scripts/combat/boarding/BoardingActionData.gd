@tool
class_name BoardingActionData extends Resource

## Purpose: one verb the player can spend command points on during a Three Bells boarding (M30 2.2).
## Responsibilities: pure data, read by `BoardingBattle.queue_action()`.

enum TargetRule {
	DEFENDER_MELEE,   ## a defender in the boarding party's own zone
	DEFENDER_RANGED,  ## a defender in the party's zone or an adjacent one
	OUTSIDE_THREAT,   ## a hostile still firing from outside the grapple
	NONE,             ## no target: affects the whole bell
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(0, 3) var cp_cost: int = 1  # placeholder: tune in M31
@export var target_rule: TargetRule = TargetRule.DEFENDER_MELEE
## Damage to the target defender (or to an outside threat for OUTSIDE_THREAT).
@export var damage: int = 0  # placeholder: tune in M31
## Zones the target defender is shoved away from the boarding party (0 = none).
@export var push: int = 0
## The target defender's telegraphed intent does nothing this bell.
@export var cancels_intent: bool = false
## Damage each outside threat has taken off it this bell (a Brace); 0 = none.
@export var outside_guard: int = 0  # placeholder: tune in M31
## The squad role this action needs (2.10); empty means anyone can do it.
@export var required_role: StringName = &""
@export var glyph: String = ""

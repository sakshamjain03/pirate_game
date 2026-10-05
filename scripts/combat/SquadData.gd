@tool
class_name SquadData extends Resource

## Purpose: one authored squad (M30 1.7) — the unit a heat tier's `squad_pool`
##   holds, so higher heat can mean harder compositions without a script change.
## Responsibilities: pure data. `EncounterManager.encounter_with_squad()` copies
##   `slots`/`tactic` onto an encounter's `squad`/`squad_tactic`.

@export var squad_id: String = ""
@export var display_name: String = ""
@export var slots: Array[SquadSlotData] = []
@export var tactic: SquadTacticData


## Hulls this squad fields, before EncounterManager's hostile cap.
func hull_count() -> int:
	var n := 0
	for slot in slots:
		if slot:
			n += slot.count
	return n

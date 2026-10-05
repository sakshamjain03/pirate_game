@tool
class_name SquadTacticData extends Resource

## Purpose: how a squad arranges itself around its target (M30 1.7).
## Responsibilities: pure data. Gives each slot index a `preferred_bearing_deg`
##   override (relative to the target's heading: 0 = dead ahead, 180 = astern,
##   +90 = starboard beam) that `EncounterManager` hands to that slot's AI
##   profile. `formation` is what the Spyglass Briefing names.

enum Formation { PINCER, SCREEN, LINE_AHEAD, CRESCENT }

@export var formation: Formation = Formation.PINCER
@export var display_name: String = ""
## Per slot index. A slot past the end of this list keeps its profile's own bearing.
@export var slot_bearings_deg: Array[float] = []  # placeholder: tune in M31


func has_bearing_for_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slot_bearings_deg.size()


func bearing_for_slot(slot_index: int) -> float:
	return slot_bearings_deg[slot_index] if has_bearing_for_slot(slot_index) else 0.0


func get_formation_name() -> String:
	if display_name != "":
		return display_name
	return str(Formation.keys()[formation]).capitalize()

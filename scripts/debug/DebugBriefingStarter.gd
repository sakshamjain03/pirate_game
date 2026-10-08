extends Node

## DEBUG HARNESS — not part of the game. Starts one authored encounter shortly
## after World loads so SpyglassCaptureHarness.tscn can capture the M30 1.9
## Spyglass Briefing with zero player input. `--watchtower=<0..5>` sets the
## intel level (EncounterManager's test seam); `--encounter=<res path>` picks
## the encounter (default the Skirmish, which draws a heat squad).

const DEFAULT_ENCOUNTER := "res://resources/combat/encounters/Skirmish.tres"
const START_FRAME := 30

var _frame := 0
var _watchtower := 3
var _encounter_path := DEFAULT_ENCOUNTER


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--watchtower="):
			_watchtower = int(a.trim_prefix("--watchtower="))
		elif a.begins_with("--encounter="):
			_encounter_path = a.trim_prefix("--encounter=")


func _process(_delta: float) -> void:
	_frame += 1
	if _frame != START_FRAME:
		return
	var mgr := get_tree().get_first_node_in_group("encounter_manager") as EncounterManager
	if not mgr:
		push_error("DebugBriefingStarter: no EncounterManager in the scene")
		return
	mgr.watchtower_level_override = _watchtower
	var data := load(_encounter_path) as EncounterData
	if not data:
		push_error("DebugBriefingStarter: %s is not an EncounterData" % _encounter_path)
		return
	var tier: HeatTierData = EmpireManager.get_heat_tier() if EmpireManager.has_method("get_heat_tier") else null
	print("[briefing] start ", data.encounter_id, " -> ", mgr.start_encounter(mgr.encounter_with_heat_squad(data, tier)))

@tool
class_name SpyglassBriefingData extends Resource

## Purpose: the Spyglass Briefing's tuning (M30 1.9, W1-2.1) — which three
##   Preparations are on offer and how much intel each Watchtower level buys.
## Responsibilities: pure data. `EncounterManager.build_briefing()` reads it;
##   `SpyglassBriefing` (UI) shows the result.
##
## Intel always includes the roster as role icons. Each gate below is the
## lowest owned Watchtower level (best on any player island, 0 = none) that
## adds that line. 0 shows it to everyone.

@export var preparations: Array[PreparationData] = []

@export_group("Intel gates")
@export_range(0, 5) var formation_intel_level: int = 1  # placeholder: tune in M31
@export_range(0, 5) var weakness_intel_level: int = 2  # placeholder: tune in M31
@export_range(0, 5) var star_hint_intel_level: int = 3  # placeholder: tune in M31

@export_group("Text")
## AIProfileData.Role key ("RAIDER") -> roster icon.
@export var role_icons: Dictionary = {}
## AIProfileData.Tactic key ("STERN_RAKER") -> the weakness line. STANDARD
## hulls fall back to `role_weaknesses`.
@export var tactic_weaknesses: Dictionary = {}
## AIProfileData.Role key -> the weakness line for a STANDARD-tactic hull.
@export var role_weaknesses: Dictionary = {}

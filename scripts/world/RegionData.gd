extends Resource
class_name RegionData

## Purpose: Defines one of the 3 empire-escalation regions (M4).
## Responsibilities: Groups a set of islands under a tier, dominant faction, and the notoriety
##   threshold at which EmpireManager activates it (dormant regions have no defenders and can't
##   be colonized — see Island.gd's _should_be_active()).
## Dependencies: None — pure data, loaded by EmpireManager from resources/world/regions/.

@export var id: String
@export var display_name: String
@export var tier: int
@export var dominant_faction: String
@export var activation_notoriety_threshold: float
@export var island_ids: Array[String]

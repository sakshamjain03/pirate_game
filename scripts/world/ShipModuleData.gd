@tool
class_name ShipModuleData extends Resource

## Purpose: one authored ship module — `docs/navalCombat.md` §13's Hull / Cannon
## / Sail / Utility / Special slots, the thing that lets two players build a
## "Fast Sloop" vs a "Tank Sloop" from the same hull.
## Responsibilities: pure data. `OwnedShipData.get_effective_stats()` applies
## these multipliers to a duplicated `ShipStats` — never to the shared template,
## the same duplicate-never-mutate rule `EncounterManager._apply_strength()`
## and `CombatModifiers` already follow.

enum Slot { HULL, CANNON, SAIL, UTILITY, SPECIAL }

@export var module_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var slot: Slot = Slot.HULL

@export_group("Cost")
@export_range(0, 20000) var cost_gold: int = 0
@export_range(0, 2000) var cost_wood: int = 0
@export_range(0, 1000) var cost_iron: int = 0

@export_group("Modifiers")
## Multiplicative; 1.0 = no change. Only the fields relevant to a module's own
## slot are ever authored away from 1.0 — a Sail module tunes speed/sails, not
## cannon damage.
@export_range(0.5, 3.0) var max_health_mult: float = 1.0
@export_range(0.5, 3.0) var cannon_damage_mult: float = 1.0
@export_range(0.5, 3.0) var fire_rate_mult: float = 1.0
@export_range(0.5, 3.0) var max_speed_mult: float = 1.0
@export_range(0.5, 3.0) var max_sails_mult: float = 1.0
@export_range(0.5, 3.0) var max_crew_mult: float = 1.0
@export_range(0.5, 3.0) var cannon_range_mult: float = 1.0


func get_slot_name() -> String:
	return Slot.keys()[slot].capitalize()


func describe() -> String:
	return "%s (%s): %s" % [display_name, get_slot_name(), description]

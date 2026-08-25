@tool
class_name CaptainData extends Resource

## CaptainData
## Defines the RPG traits and stat modifiers for a captain.

@export var captain_id: String = ""
@export var captain_name: String = "Unknown Captain"
@export_multiline var background: String = ""

@export_group("Identity")
## Must match a real `IslandData.island_id`. Empty is legitimate — Marguerite's
## home port was burned and never retaken (`docs/12_CHARACTER_BIBLE.md` §4).
@export var home_island_id: String = ""
## Must match a real `FactionData.faction_id`.
@export var allegiance_faction_id: String = ""
## The chapter that must be *completed* before this captain appears in the
## Tavern. Empty means available from the start. `IslandMenu` filters the hire
## list by this rather than showing a locked entry — a disabled list of 20 is
## noise on a phone (`docs/12_CHARACTER_BIBLE.md` §6).
@export var unlock_chapter_id: String = ""
## Empty renders name-only; portraits are a later art pass, not a blocker.
@export var portrait_path: String = ""

@export_group("Progression")
@export var level: int = 1
@export var current_xp: int = 0
@export var hire_cost_gold: int = 500

@export_group("Base Modifiers")
@export_range(0.1, 3.0) var base_speed_modifier: float = 1.0
@export_range(0.1, 3.0) var base_turn_rate_modifier: float = 1.0
@export_range(0.1, 3.0) var base_damage_modifier: float = 1.0
@export_range(0.1, 3.0) var base_health_modifier: float = 1.0
@export_range(0.1, 3.0) var base_boarding_modifier: float = 1.0

@export_group("Active Ability")
## The player-triggered battle verb (`docs/navalCombat.md` §10). The passives above
## say what a captain *is*; this says what they *do*, and is what makes each of the
## 20 captains distinct in a fight rather than a different set of five numbers.
## Executed by the `CaptainAbility` component on the player ship.
@export var active_ability: CaptainAbilityData

# Dynamic modifiers (computed from base + level)
var speed_modifier: float:
	get: return base_speed_modifier + (level - 1) * 0.05
var turn_rate_modifier: float:
	get: return base_turn_rate_modifier + (level - 1) * 0.05
var damage_modifier: float:
	get: return base_damage_modifier + (level - 1) * 0.1
var health_modifier: float:
	get: return base_health_modifier + (level - 1) * 0.1
var boarding_modifier: float:
	get: return base_boarding_modifier + (level - 1) * 0.1

func add_xp(amount: int) -> void:
	current_xp += amount
	var xp_needed = level * 100
	while current_xp >= xp_needed:
		current_xp -= xp_needed
		level += 1
		xp_needed = level * 100

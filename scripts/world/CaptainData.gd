@tool
class_name CaptainData extends Resource

## CaptainData
## Defines the RPG traits and stat modifiers for a captain.

@export var captain_id: String = ""
@export var captain_name: String = "Unknown Captain"
@export_multiline var background: String = ""

@export_group("Progression")
@export var level: int = 1
@export var current_xp: int = 0
@export var hire_cost_gold: int = 500

@export_group("Base Modifiers")
@export_range(0.1, 3.0) var base_speed_modifier: float = 1.0
@export_range(0.1, 3.0) var base_turn_rate_modifier: float = 1.0
@export_range(0.1, 3.0) var base_damage_modifier: float = 1.0
@export_range(0.1, 3.0) var base_health_modifier: float = 1.0

# Dynamic modifiers (computed from base + level)
var speed_modifier: float:
	get: return base_speed_modifier + (level - 1) * 0.05
var turn_rate_modifier: float:
	get: return base_turn_rate_modifier + (level - 1) * 0.05
var damage_modifier: float:
	get: return base_damage_modifier + (level - 1) * 0.1
var health_modifier: float:
	get: return base_health_modifier + (level - 1) * 0.1

func add_xp(amount: int) -> void:
	current_xp += amount
	var xp_needed = level * 100
	while current_xp >= xp_needed:
		current_xp -= xp_needed
		level += 1
		xp_needed = level * 100
		print(captain_name, " leveled up to ", level, "!")

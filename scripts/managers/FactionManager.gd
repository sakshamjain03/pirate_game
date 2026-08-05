extends Node

## Purpose: Tracks player reputation with various factions (M7).
## Responsibilities: Holds reputation scores, provides hostility status.

signal reputation_changed(faction_id: String, new_rep: int)

# Reputation ranges from -100 to 100.
# < 0 means Hostile
# >= 0 means Neutral/Friendly
var reputation_scores: Dictionary = {
	"pirate_clans": -50,
	"royal_navy": -50,
	"merchant_guild": 20
}

func _ready() -> void:
	if ResourceManager.has_signal("global_economy_tick"):
		ResourceManager.global_economy_tick.connect(_on_economy_tick)

func _on_economy_tick() -> void:
	# Check for negative reputation and spawn hunters
	if get_reputation("royal_navy") <= -50:
		# 20% chance per tick to spawn a hunter
		if randf() < 0.2:
			var spawner = get_tree().current_scene.get_node_or_null("Systems/EnemySpawner")
			if spawner and spawner.has_method("spawn_hunter"):
				var navy = load("res://resources/factions/RoyalNavy.tres")
				spawner.spawn_hunter(navy)
				print("Royal Navy dispatched a hunter!")

func get_reputation(faction_id: String) -> int:
	return reputation_scores.get(faction_id, 0)

func add_reputation(faction_id: String, amount: int) -> void:
	if not reputation_scores.has(faction_id):
		reputation_scores[faction_id] = 0
		
	reputation_scores[faction_id] = clamp(reputation_scores[faction_id] + amount, -100, 100)
	reputation_changed.emit(faction_id, reputation_scores[faction_id])

func is_hostile(faction_id: String) -> bool:
	return get_reputation(faction_id) < 0

func get_player_faction() -> Resource:
	return load("res://resources/factions/PlayerFaction.tres")

func get_save_data() -> Dictionary:
	return reputation_scores.duplicate()

func load_save_data(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
		
	for key in data:
		reputation_scores[key] = int(data[key])

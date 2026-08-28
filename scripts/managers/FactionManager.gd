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

## M11 Requirement 6 — treaty/tribute: the inverse of the existing "attacking
## a faction's ship reduces reputation" dynamic (docs/05_CURRENT_SYSTEMS.md).
## Spends resources for a reputation bump, on a cooldown per faction so a
## player can't spam it back to friendly instantly.
const TRIBUTE_COOLDOWN_SECONDS: float = 300.0
const TRIBUTE_REPUTATION_GAIN: int = 15
const TRIBUTE_COST_GOLD: int = 500
## Namespaced with a leading underscore so it can't collide with a real
## faction_id key in the flat save dict below.
const _TRIBUTE_COOLDOWN_SAVE_KEY := "_tribute_cooldown_remaining"

var _tribute_cooldown_remaining: Dictionary = {}  # faction_id -> float seconds

func _ready() -> void:
	if ResourceManager.has_signal("global_economy_tick"):
		ResourceManager.global_economy_tick.connect(_on_economy_tick)

func _process(delta: float) -> void:
	if _tribute_cooldown_remaining.is_empty():
		return
	for faction_id in _tribute_cooldown_remaining.keys():
		if _tribute_cooldown_remaining[faction_id] > 0.0:
			_tribute_cooldown_remaining[faction_id] = maxf(0.0, _tribute_cooldown_remaining[faction_id] - delta)

func _on_economy_tick() -> void:
	# Check for negative reputation and spawn hunters
	if get_reputation("royal_navy") <= -50:
		# 20% chance per tick to spawn a hunter
		if randf() < 0.2:
			var spawner = get_tree().current_scene.get_node_or_null("Systems/EnemySpawner")
			if spawner and spawner.has_method("spawn_hunter"):
				var navy = load("res://resources/factions/RoyalNavy.tres")
				if navy:
					spawner.spawn_hunter(navy)

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

func get_tribute_cooldown_remaining(faction_id: String) -> float:
	return _tribute_cooldown_remaining.get(faction_id, 0.0)

func can_pay_tribute(faction_id: String) -> bool:
	return get_tribute_cooldown_remaining(faction_id) <= 0.0

## Spends TRIBUTE_COST_GOLD for TRIBUTE_REPUTATION_GAIN reputation with
## `faction_id`, then starts that faction's cooldown. Returns false (no
## resources spent, no cooldown started) if on cooldown or unaffordable.
func pay_tribute(faction_id: String) -> bool:
	if not can_pay_tribute(faction_id):
		return false
	if not ResourceManager or not ResourceManager.can_afford({"gold": TRIBUTE_COST_GOLD}):
		return false
	if not ResourceManager.spend_resources({"gold": TRIBUTE_COST_GOLD}):
		return false
	add_reputation(faction_id, TRIBUTE_REPUTATION_GAIN)
	_tribute_cooldown_remaining[faction_id] = TRIBUTE_COOLDOWN_SECONDS
	return true

## Kept flat (reputation scores directly at the top level, same as pre-M11)
## rather than nesting under a "reputation_scores" key — test_faction_manager.gd's
## existing round-trip test reads `saved[faction_id]` directly, and there's no
## real need to break that shape just to add one more field.
func get_save_data() -> Dictionary:
	var data := reputation_scores.duplicate()
	if not _tribute_cooldown_remaining.is_empty():
		data[_TRIBUTE_COOLDOWN_SAVE_KEY] = _tribute_cooldown_remaining.duplicate()
	return data

func load_save_data(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	_tribute_cooldown_remaining.clear()
	for key in data:
		if key == _TRIBUTE_COOLDOWN_SAVE_KEY:
			for faction_id in data[key]:
				_tribute_cooldown_remaining[faction_id] = float(data[key][faction_id])
		else:
			reputation_scores[key] = int(data[key])

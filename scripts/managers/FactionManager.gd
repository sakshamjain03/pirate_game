extends Node

## Purpose: Tracks player reputation with various factions (M7).
## Responsibilities: Holds reputation scores, provides hostility status.

signal reputation_changed(faction_id: String, new_rep: int)

# Reputation ranges from -100 to 100.
# < 0 means Hostile
# >= 0 means Neutral/Friendly
const _DEFAULT_REPUTATION := {
	"pirate_clans": -50,
	"royal_navy": -50,
	"merchant_guild": 20
}
var reputation_scores: Dictionary = _DEFAULT_REPUTATION.duplicate()

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
var _event_hunter_cooldown: Dictionary = {}  # faction_id -> float seconds
var _faction_cache: Dictionary = {}  # faction_id -> FactionData, filled once from res://resources/factions/
var _spawner: Node = null  # the live World's EnemySpawner, captured in _on_node_added

func _ready() -> void:
	if ResourceManager.has_signal("global_economy_tick"):
		ResourceManager.global_economy_tick.connect(_on_economy_tick)

	# M29 — connect to EnemySpawner and BoardingSystem when they're added to the tree
	# Use get_tree().node_added to avoid hardcoded node paths
	get_tree().node_added.connect(_on_node_added)

	# M29 B.3 — connect to EmpireManager's island capture signal
	if EmpireManager and EmpireManager.has_signal("island_captured_from"):
		EmpireManager.island_captured_from.connect(_on_island_captured_from)

func _process(delta: float) -> void:
	if _tribute_cooldown_remaining.is_empty() and _event_hunter_cooldown.is_empty():
		return
	for faction_id in _tribute_cooldown_remaining.keys():
		if _tribute_cooldown_remaining[faction_id] > 0.0:
			_tribute_cooldown_remaining[faction_id] = maxf(0.0, _tribute_cooldown_remaining[faction_id] - delta)

	# M29 — event hunter cooldown
	for faction_id in _event_hunter_cooldown.keys():
		if _event_hunter_cooldown[faction_id] > 0.0:
			_event_hunter_cooldown[faction_id] = maxf(0.0, _event_hunter_cooldown[faction_id] - delta)

func _on_node_added(node: Node) -> void:
	# M29 — connect to EnemySpawner and BoardingSystem signals
	if node is EnemySpawner:
		_spawner = node
		if not node.enemy_destroyed.is_connected(_on_enemy_destroyed):
			node.enemy_destroyed.connect(_on_enemy_destroyed)
	elif node.get_script() and node.get_script().get_global_name() == "BoardingSystem":
		if not node.boarding_resolved.is_connected(_on_boarding_resolved):
			node.boarding_resolved.connect(_on_boarding_resolved)

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

# M29 — signal handlers for faction consequences
func _on_enemy_destroyed(enemy: Node3D) -> void:
	# Only apply reputation loss in campaign mode
	if not SceneManager.is_campaign():
		return

	# Skip if this ship was boarded (the boarding loss is applied instead)
	if enemy.get_meta("loot_claimed", false):
		return

	# ShipController exposes `faction` as an @export property (same read as
	# BoardingSystem / EnemyAI), not as node metadata.
	var faction: FactionData = null
	if "faction" in enemy:
		faction = enemy.get("faction") as FactionData
	if not faction:
		return

	# Apply the reputation loss
	if faction.sink_reputation_loss > 0:
		add_reputation(faction.faction_id, -faction.sink_reputation_loss)

func _on_boarding_resolved(success: bool, loot: Dictionary, target_faction_id: String, target_ship_id: String) -> void:
	# Only apply reputation loss on successful boarding in campaign mode
	if not success or not SceneManager.is_campaign():
		return

	# Resolve the faction
	var faction = _resolve_faction(target_faction_id)
	if not faction:
		return

	# Apply boarding reputation loss
	if faction.boarding_reputation_loss > 0:
		add_reputation(target_faction_id, -faction.boarding_reputation_loss)

	# Try to spawn an event hunter
	_try_event_hunter(target_faction_id)

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

func _resolve_faction(faction_id: String) -> FactionData:
	# M29 — resolve by the resource's own faction_id (never a guessed file name).
	# The directory is scanned once and cached; enemy deaths call this often.
	if _faction_cache.is_empty():
		var dir := DirAccess.open("res://resources/factions/")
		if dir:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".tres"):
					var f := load("res://resources/factions/" + file_name) as FactionData
					if f:
						_faction_cache[f.faction_id] = f
				file_name = dir.get_next()
	var faction: FactionData = _faction_cache.get(faction_id)
	if not faction:
		push_error("FactionManager: unknown faction_id '%s'" % faction_id)
	return faction

func get_island_owner_display(island_data: IslandData) -> Dictionary:
	# M29 B.4 — return {faction_id, name, color} for the island owner
	if not island_data:
		return {"faction_id": "", "name": "Unclaimed", "color": Color.GRAY}

	var owner = island_data.owner_faction as FactionData
	if not owner:
		return {"faction_id": "", "name": "Unclaimed", "color": Color.GRAY}

	match island_data.island_type:
		IslandData.IslandType.FRIENDLY, IslandData.IslandType.CAPITAL:
			var player = get_player_faction() as FactionData
			return {
				"faction_id": player.faction_id,
				"name": player.faction_name,
				"color": player.sail_color
			}
		IslandData.IslandType.ENEMY:
			return {
				"faction_id": owner.faction_id,
				"name": owner.faction_name,
				"color": owner.sail_color
			}
		IslandData.IslandType.NEUTRAL, IslandData.IslandType.LEGENDARY:
			return {"faction_id": "", "name": "Unclaimed", "color": Color.GRAY}

	return {"faction_id": "", "name": "Unclaimed", "color": Color.GRAY}

func _on_island_captured_from(island_id: String, previous_faction_id: String) -> void:
	# M29 B.3 — when an island is captured from a faction, try to spawn an event hunter
	if not previous_faction_id.is_empty():
		_try_event_hunter(previous_faction_id)

func _try_event_hunter(faction_id: String) -> void:
	# M29 B.3 — spawn an event hunter for the faction, subject to cooldown
	var faction = _resolve_faction(faction_id)
	if not faction:
		return

	# Check cooldown
	if _event_hunter_cooldown.get(faction_id, 0.0) > 0.0:
		return

	# Spawn a hunter (safely handle absence in test context)
	if not is_instance_valid(_spawner) or not _spawner.has_method("spawn_hunter"):
		return
	_spawner.spawn_hunter(faction)
	_event_hunter_cooldown[faction_id] = faction.hunter_cooldown_seconds

func get_tribute_cooldown_remaining(faction_id: String) -> float:
	return _tribute_cooldown_remaining.get(faction_id, 0.0)

func can_pay_tribute(faction_id: String) -> bool:
	return get_tribute_cooldown_remaining(faction_id) <= 0.0

## Spends tribute_cost_gold for reputation with `faction_id`, then starts that
## faction's cooldown. Returns false (no resources spent, no cooldown started)
## if on cooldown or unaffordable.
func pay_tribute(faction_id: String) -> bool:
	if not can_pay_tribute(faction_id):
		return false

	var faction = _resolve_faction(faction_id)
	if not faction:
		return false

	var cost = {"gold": faction.tribute_cost_gold}
	if not ResourceManager or not ResourceManager.can_afford(cost):
		return false
	if not ResourceManager.spend_resources(cost):
		return false

	add_reputation(faction_id, TRIBUTE_REPUTATION_GAIN)
	_tribute_cooldown_remaining[faction_id] = faction.tribute_cooldown_seconds
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

	# Replace, never merge: a faction first met during play (M29 B.2 adds an
	# entry the moment you sink one of its ships) must not survive New Game or
	# leak into a different save. Keys the save lacks fall back to defaults.
	reputation_scores = _DEFAULT_REPUTATION.duplicate()
	_tribute_cooldown_remaining.clear()
	for key in data:
		if key == _TRIBUTE_COOLDOWN_SAVE_KEY:
			for faction_id in data[key]:
				_tribute_cooldown_remaining[faction_id] = float(data[key][faction_id])
		else:
			reputation_scores[key] = int(data[key])

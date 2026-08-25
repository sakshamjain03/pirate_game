extends Node3D

func _ready() -> void:
	var ship = get_node_or_null("PlayerShip")
	
	var islands = []
	var islands_node = get_node_or_null("Islands")
	if islands_node:
		islands = islands_node.get_children()
		
	# The manager is local in this scene under Systems/WorldManager
	var world_manager = get_node_or_null("Systems/WorldManager")
	if world_manager and world_manager.has_method("initialize_world"):
		world_manager.initialize_world(ship, islands)

	# Give the DockingSystem a reference to the player ship. Without this the
	# state machine's attempt_dock()/attempt_undock() calls have nothing to
	# operate on (ship_controller stays null forever).
	var docking_system = get_node_or_null("Systems/DockingSystem")
	if docking_system and docking_system.has_method("initialize") and ship:
		docking_system.initialize(ship)

	# D58 cold start fix: a genuinely new game (no save file at all — Continue
	# always leaves one) starts owning no island and no production, gated behind
	# an unreachable 1000-gold colonize cost against a 200-gold starting purse.
	# Guarded on "is this a new game", never "is home_island_id empty" — an
	# existing save with a different home island must never be overwritten.
	if not SaveManager.has_save_data():
		call_deferred("_seed_port_royal_as_home", islands)

	# Load game state (if coming from Continue)
	if SaveManager.has_method("load_game"):
		# Use call_deferred to ensure physics and all nodes are fully ready
		SaveManager.call_deferred("load_game")

	# Deferred (and queued after load_game above) so resumed campaign progress
	# from a loaded save is already in place before signals start firing.
	if world_manager and CampaignManager.has_method("on_world_ready"):
		CampaignManager.call_deferred("on_world_ready", world_manager)


func _seed_port_royal_as_home(islands: Array) -> void:
	for island in islands:
		if not (island.has_method("get_island_id") and island.get_island_id() == "port_royal"):
			continue
		if not island.island_data:
			return
		island.island_data.island_type = IslandData.IslandType.CAPITAL
		island.island_data.owner_faction = load("res://resources/factions/PlayerFaction.tres")
		EmpireManager.home_island_id = "port_royal"
		return

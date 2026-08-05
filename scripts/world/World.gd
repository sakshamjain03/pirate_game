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

	# Load game state (if coming from Continue)
	if SaveManager.has_method("load_game"):
		# Use call_deferred to ensure physics and all nodes are fully ready
		SaveManager.call_deferred("load_game")

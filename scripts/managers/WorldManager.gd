extends Node

signal world_loaded()
signal island_discovered(island_id: String)
signal player_docked(island_id: String)

var is_world_loaded: bool = false
var time_of_day: float = 8.0 # 0-24 hours

# Nodes we might track
var player_ship: Node3D = null
var active_islands: Dictionary = {}

# Cached sibling system references. These are resolved once in _ready()
# instead of via get_node_or_null() every frame in _process() — repeated
# string-based node lookups in a hot loop are an explicit perf anti-pattern
# (see AGENTS.md Performance Rules).
var _docking_system: Node = null
var _input_manager: Node = null
var _event_manager: Node = null

func _ready() -> void:
	_docking_system = get_node_or_null("../DockingSystem")
	_input_manager = get_node_or_null("../InputManager")
	_event_manager = get_node_or_null("../EventManager")

	if _docking_system:
		_docking_system.dock_completed.connect(_on_dock_completed)

func _process(delta: float) -> void:
	if is_world_loaded:
		_process_time(delta)

		# Process ship input
		if player_ship and player_ship.has_method("set_input"):
			if _input_manager:
				var move_input = _input_manager.get_movement_vector()
				player_ship.set_input(move_input.y, move_input.x)

		# Process combat input
		if player_ship and player_ship.has_method("fire_cannons"):
			# Input is global in Godot, so these are read directly.
			if Input.is_action_just_pressed("fire_port"):
				player_ship.fire_cannons("port")
			if Input.is_action_just_pressed("fire_starboard"):
				player_ship.fire_cannons("starboard")

			# Process dock/undock input
			if Input.is_action_just_pressed("dock"):
				_toggle_docking()

func _toggle_docking() -> void:
	if not _docking_system:
		return
	if _docking_system.current_state == _docking_system.DockState.DOCKED:
		_docking_system.attempt_undock()
	elif _docking_system.current_state == _docking_system.DockState.APPROACHING:
		_docking_system.attempt_dock()

func _on_dock_completed(island_id: String) -> void:
	on_player_docked(island_id)
	if _event_manager and _event_manager.has_method("handle_docking_event"):
		_event_manager.handle_docking_event(island_id)

func _process_time(delta: float) -> void:
	# 1 real second = 1 in-game minute
	# 24 real minutes = 24 in-game hours
	var time_scale = 1.0 / 60.0 # hours per second
	time_of_day += delta * time_scale
	if time_of_day >= 24.0:
		time_of_day -= 24.0

func initialize_world(ship: Node3D, islands: Array) -> void:
	player_ship = ship
	for island in islands:
		if island.has_method("get_island_id"):
			active_islands[island.get_island_id()] = island
			
	is_world_loaded = true
	emit_signal("world_loaded")

func on_island_discovered(island_id: String) -> void:
	emit_signal("island_discovered", island_id)

func on_player_docked(island_id: String) -> void:
	emit_signal("player_docked", island_id)

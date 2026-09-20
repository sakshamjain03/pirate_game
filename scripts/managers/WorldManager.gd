extends Node

## Purpose: Per-scene coordinator for the World scene (autoload-adjacent scene-local manager).
## Responsibilities: Routes input to the player ship, drives the day/night timer, handles
##   dock/undock via DockingSystem, and auto-shows RaidReportScreen on world load when
##   EmpireManager has an unshown pending_raid_report (M4).
## Dependencies: DockingSystem, InputManager, CameraRig (siblings), EmpireManager, RaidReportScreen.tscn

signal world_loaded()
signal island_discovered(island_id: String)
signal player_docked(island_id: String)

var is_world_loaded: bool = false

# Nodes we might track
var player_ship: Node3D = null
var active_islands: Dictionary = {}

## M10 Requirement 4 — how close the player must sail to an undiscovered
## island before it reveals (docking already implies discovery via
## CampaignManager._on_player_docked; this extends that to reveal-on-approach
## rather than reveal-only-on-dock, per docs/11_WORLD_MAP.md's fog-of-war
## intent). Configurable rather than hardcoded, per AGENTS.md.
@export var discovery_radius: float = 80.0

# Cached sibling system references. These are resolved once in _ready()
# instead of via get_node_or_null() every frame in _process() — repeated
# string-based node lookups in a hot loop are an explicit perf anti-pattern
# (see AGENTS.md Performance Rules).
var _docking_system: Node = null
var _boarding_system: Node = null
var _input_manager: Node = null
var _camera_rig: Node = null

const CAMERA_ROTATE_SPEED: float = 90.0 # degrees/sec while held
const CAMERA_ZOOM_STEP: float = 3.0 # distance units per wheel tick

func _ready() -> void:
	_docking_system = get_node_or_null("../DockingSystem")
	_boarding_system = get_node_or_null("../BoardingSystem")
	# InputManager was promoted to an autoload in M7 (D57): rebinding is reachable
	# from the main menu, where no World scene — and so no scene-local
	# InputManager — exists.
	_input_manager = InputManager
	# Re-zero tilt steering against however the player is actually holding the
	# phone right now, at the moment gameplay starts — not just whatever angle
	# they happened to be holding it at when they flipped the Settings toggle.
	# A no-op read when the setting is off.
	_input_manager.recalibrate_tilt()
	_camera_rig = get_node_or_null("../../CameraRig")
	if AudioManager: AudioManager.play_music("in_world")

	if _docking_system:
		_docking_system.dock_completed.connect(_on_dock_completed)

func _process(delta: float) -> void:
	if is_world_loaded:
		_check_island_discovery()

		# Process ship input. Forward thrust comes from the ship's own sail
		# state (see sail input block below), not a held key — only turn
		# (rudder) is still read continuously here.
		if player_ship and player_ship.has_method("set_input"):
			if _input_manager:
				var move_input = _input_manager.get_movement_vector()
				player_ship.set_input(player_ship.get_sail_forward_input(), move_input.x)

		# Process sail/anchor input (Property: Sail Level/Set Sail/Anchor
		# are one-notch-per-press actions, not held throttle).
		if player_ship:
			if Input.is_action_just_pressed("sail_level_up") and player_ship.has_method("adjust_sail_level"):
				player_ship.adjust_sail_level(1)
			if Input.is_action_just_pressed("sail_level_down") and player_ship.has_method("adjust_sail_level"):
				player_ship.adjust_sail_level(-1)
			if Input.is_action_just_pressed("set_sail") and player_ship.has_method("toggle_sail"):
				player_ship.toggle_sail()
			if Input.is_action_just_pressed("anchor") and player_ship.has_method("toggle_anchor"):
				player_ship.toggle_anchor()

		# Process dock/undock input
		if Input.is_action_just_pressed("dock"):
			var boarded = false
			if _boarding_system and _boarding_system.get("_eligible_enemy") != null:
				if _boarding_system.has_method("attempt_boarding"):
					boarded = _boarding_system.attempt_boarding()
			if not boarded:
				_toggle_docking()

		# Process camera input
		if _camera_rig:
			var rotate_input = Input.get_action_strength("camera_rotate_right") - Input.get_action_strength("camera_rotate_left")
			if rotate_input != 0.0:
				_camera_rig.add_yaw(rotate_input * CAMERA_ROTATE_SPEED * delta)

			if Input.is_action_just_pressed("camera_zoom_in"):
				_camera_rig.add_zoom(CAMERA_ZOOM_STEP)
			if Input.is_action_just_pressed("camera_zoom_out"):
				_camera_rig.add_zoom(-CAMERA_ZOOM_STEP)

func _unhandled_input(event: InputEvent) -> void:
	if _handle_camera_drag(event):
		get_viewport().set_input_as_handled()
		return

	# Firing goes through _unhandled_input rather than the global Input
	# polling above so a UI element (e.g. an IslandMenu button) can consume
	# the click first — global Input.is_action_just_pressed() ignored that
	# entirely, so clicking any button while docked also fired a broadside.
	if not is_world_loaded or not player_ship or not player_ship.has_method("fire_cannons"):
		return

	var combat = player_ship.get_node_or_null("ShipCombat")

	# The special broadside is the player's active firing verb now. Ordinary
	# broadsides fire themselves whenever the arc lines up
	# (`ShipCombat._physics_process`), so tapping is no longer how damage happens
	# — positioning is (`docs/navalCombat.md` §4).
	if event.is_action_pressed("special_broadside"):
		if combat and combat.has_method("fire_special_broadside"):
			combat.fire_special_broadside()
		get_viewport().set_input_as_handled()
		return

	# The captain's ability — the other half of the player's active verbs
	# (`docs/navalCombat.md` §10). Follows the captain, not the ship.
	if event.is_action_pressed("captain_ability"):
		var ability_node = player_ship.get_node_or_null("CaptainAbility")
		if ability_node and ability_node.has_method("activate"):
			ability_node.activate()
		get_viewport().set_input_as_handled()
		return

	# Manual per-side fire is retained only as an escape hatch while auto-fire is
	# being verified, per the M8 risk-register mitigation. With auto_fire_enabled
	# true it is redundant, not harmful: the same per-side reload gates both.
	if event.is_action_pressed("fire_port"):
		player_ship.fire_cannons("port")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fire_starboard"):
		player_ship.fire_cannons("starboard")
		get_viewport().set_input_as_handled()


func _handle_camera_drag(event: InputEvent) -> bool:
	## Strategy-style camera control: drag unused world space to orbit the
	## camera horizontally and tilt it vertically. UI Controls accept their
	## events before this unhandled path, so steering, sail, ability, and menu
	## touches cannot move the camera. Desktop uses middle/right drag because
	## left click remains a combat input.
	if not _camera_rig:
		return false
	var drag_delta := Vector2.ZERO
	if event is InputEventScreenDrag:
		drag_delta = event.relative
	elif event is InputEventMouseMotion:
		var held_rotation_button: int = event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT)
		if held_rotation_button == 0:
			return false
		drag_delta = event.relative
	else:
		return false
	var settings: CameraSettings = _camera_rig.settings
	if not settings:
		return false
	_camera_rig.add_yaw(drag_delta.x * settings.drag_yaw_degrees_per_pixel)
	_camera_rig.add_pitch(drag_delta.y * settings.drag_pitch_degrees_per_pixel)
	return true

func _toggle_docking() -> void:
	if not _docking_system:
		return
	if _docking_system.current_state == _docking_system.DockState.DOCKED:
		_docking_system.attempt_undock()
	elif _docking_system.current_state == _docking_system.DockState.APPROACHING:
		_docking_system.attempt_dock()

func _on_dock_completed(island_id: String) -> void:
	on_player_docked(island_id)
	if EventManager.has_method("handle_docking_event"):
		EventManager.handle_docking_event(island_id)

func initialize_world(ship: Node3D, islands: Array) -> void:
	player_ship = ship
	for island in islands:
		if island.has_method("get_island_id"):
			active_islands[island.get_island_id()] = island

	is_world_loaded = true
	emit_signal("world_loaded")

	# A save's pending_raid_report is only restored once SaveManager.load_game() finishes
	# (it runs deferred, after this method), so check now for the no-save-to-load case and
	# again once loading completes for the Continue-from-save case.
	_check_pending_raid_report()
	if SaveManager.has_signal("game_loaded") and not SaveManager.game_loaded.is_connected(_check_pending_raid_report):
		SaveManager.game_loaded.connect(_check_pending_raid_report)

func _check_pending_raid_report() -> void:
	var empire = get_tree().root.get_node_or_null("EmpireManager")
	if empire and empire.get("pending_raid_report") != null:
		var raid_screen = load("res://scenes/ui/RaidReportScreen.tscn").instantiate()
		get_tree().current_scene.add_child(raid_screen)
		raid_screen.open(empire.pending_raid_report)

func on_island_discovered(island_id: String) -> void:
	if AudioManager: AudioManager.play_sound("discovery")
	emit_signal("island_discovered", island_id)

func _check_island_discovery() -> void:
	## Read-only distance check — the actual IslandData.discovered write
	## happens in CampaignManager._on_island_discovered (the existing single
	## source of truth also used by the dock path), reached via the signal
	## emitted below. That write is synchronous, so island_data.discovered
	## is already true by the next frame's check — no local dedup needed here.
	if not player_ship or not is_instance_valid(player_ship):
		return
	for island in active_islands.values():
		if not is_instance_valid(island) or not island.island_data:
			continue
		if island.island_data.discovered:
			continue
		if player_ship.global_position.distance_to(island.global_position) <= discovery_radius:
			on_island_discovered(island.get_island_id())

func on_player_docked(island_id: String) -> void:
	emit_signal("player_docked", island_id)

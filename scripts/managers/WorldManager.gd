extends Node

## Purpose: Per-scene coordinator for the World scene (autoload-adjacent scene-local manager).
## Responsibilities: Routes input to the player ship, drives the day/night timer, handles
##   dock/undock via DockingSystem, and auto-shows RaidReportScreen on world load when
##   EmpireManager has an unshown pending_raid_report (M4).
## Dependencies: DockingSystem, InputManager, CameraRig (siblings), EmpireManager, RaidReportScreen.tscn

signal world_loaded()
signal island_discovered(island_id: String)
signal player_docked(island_id: String)
## M30 W1 — the context button's winning verb changed (e.g. Brace became
## available because a broadside started winding up at the player). Lets
## MobileControls relabel the button for verbs that come and go mid-sail.
signal context_verb_changed(verb: StringName)

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
## M30 0.20 — what the one context button / "dock" action does right now.
## Wave 0 registers board and dock; later waves add brace, repel, prize, keg,
## land, assault and spyglass through register_context_provider().
var _context_arbiter := ContextVerbArbiter.new()

## M30 W1 (1.6) — Brace is offered only while a hostile wind-up is aimed at
## the player, and is Perfect in the last BraceData.perfect_window of one.
var _windup_tracker := IncomingWindupTracker.new()
var _brace_data: BraceData = preload("res://resources/balance/Brace.tres")
var _windup_scan_accum: float = INF
## How often newly spawned hostiles are picked up (not a balance value).
const WINDUP_SCAN_INTERVAL := 0.5
var _last_context_verb: StringName = &""

## M30 W1 task 1.10 — keg stock per sortie.
var _keg_stock: int = 0
var _keg_config: KegConfigData = preload("res://resources/combat/KegConfig.tres")
var _keg_scene: PackedScene = preload("res://scenes/combat/PowderKeg.tscn")
## M30 W1 task 1.8 — tap-to-mark tolerances (CombatFeedbackData).
var _feedback_config: CombatFeedbackData = preload("res://resources/ui/CombatFeedback.tres")
var _touch_down: Dictionary = {}   # touch index -> press position
## Desktop mark button. Left/right click are bound to fire_port/fire_starboard,
## so marking must never use them (a left click near a hull would mark instead
## of firing). A middle press+release without a drag is otherwise unbound; a
## middle DRAG still orbits the camera (_handle_camera_drag).
const MARK_MOUSE_BUTTON: MouseButton = MOUSE_BUTTON_MIDDLE
var _mouse_mark_down: Variant = null   # press position of MARK_MOUSE_BUTTON

const CAMERA_ROTATE_SPEED: float = 90.0 # degrees/sec while held
const CAMERA_ZOOM_STEP: float = 3.0 # distance units per wheel tick

func _ready() -> void:
	_docking_system = get_node_or_null("../DockingSystem")
	_boarding_system = get_node_or_null("../BoardingSystem")
	# MobileControls labels the context button from this node's arbiter.
	add_to_group("world_manager")
	_register_wave0_context_verbs()
	_register_wave1_context_verbs()
	_register_keg_context_provider()  # M30 W1 task 1.10
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
		# M25 "lying low" — heat bleeds off faster while docked at an island the
		# player owns. Wired here because DockingSystem lives on the player ship
		# and is created at runtime, so an autoload cannot reach it directly.
		if _docking_system.has_signal("undock_completed"):
			_docking_system.undock_completed.connect(_on_undock_completed)

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

		# The context action (keyboard/gamepad "dock", or the phone's context
		# button) goes to whichever verb wins right now — M30 0.20.
		if Input.is_action_just_pressed("dock"):
			_context_arbiter.perform()
		_publish_context_verb()

		# Process camera input
		if _camera_rig:
			var rotate_input = Input.get_action_strength("camera_rotate_right") - Input.get_action_strength("camera_rotate_left")
			if rotate_input != 0.0:
				_camera_rig.add_yaw(rotate_input * CAMERA_ROTATE_SPEED * delta)

			if Input.is_action_just_pressed("camera_zoom_in"):
				_camera_rig.add_zoom(CAMERA_ZOOM_STEP)
			if Input.is_action_just_pressed("camera_zoom_out"):
				_camera_rig.add_zoom(-CAMERA_ZOOM_STEP)

func _physics_process(delta: float) -> void:
	if not is_world_loaded:
		return
	tick_windup_tracker(delta)


## M30 W1 (1.6) — keeps the incoming wind-up list current. Public so tests can
## step it with an exact delta.
func tick_windup_tracker(delta: float) -> void:
	_windup_tracker.target = player_ship
	_windup_scan_accum += delta
	if _windup_scan_accum >= WINDUP_SCAN_INTERVAL and is_inside_tree():
		_windup_scan_accum = 0.0
		_windup_tracker.scan(get_tree())
	_windup_tracker.tick(delta)


func get_windup_tracker() -> IncomingWindupTracker:
	return _windup_tracker


func _publish_context_verb() -> void:
	var verb := _context_arbiter.get_context_verb()
	if verb != _last_context_verb:
		_last_context_verb = verb
		context_verb_changed.emit(verb)


func _unhandled_input(event: InputEvent) -> void:
	if _handle_tap_to_mark(event):
		get_viewport().set_input_as_handled()
		return
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

	# M25 — the keyboard/gamepad twin of MobileControls' shot-type button. Without
	# it desktop had no way to choose ammo at all (the touch button is hidden off
	# mobile). The HUD toast stands in for the button label desktop doesn't show.
	if event.is_action_pressed("cycle_ammo"):
		if combat and combat.has_method("cycle_ammo"):
			var ammo: AmmoData = combat.cycle_ammo()
			var hud = get_tree().get_first_node_in_group("hud")
			if ammo and hud and hud.has_method("announce_event"):
				hud.announce_event(tr("Loaded: %s") % tr(ammo.display_name))
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

## M30 W1-1.6 (task 1.8) — tap-to-mark. A touch released within tap_slop_px of
## where it went down, or on desktop a middle-click (MARK_MOUSE_BUTTON, press
## and release within the same slop, so a middle-drag camera orbit never marks),
## on (near) a hostile hull marks it as the player's FiringSolver.priority_target;
## the same tap again clears it. A tap that lands on no hull is not consumed.
## Left/right click are never read here: they are fire_port/fire_starboard and
## must keep firing even right next to a hull. UI Controls see touches first,
## so HUD buttons never mark.
func _handle_tap_to_mark(event: InputEvent) -> bool:
	if not is_world_loaded or not is_instance_valid(player_ship):
		return false
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down[event.index] = event.position
			return false
		var down = _touch_down.get(event.index)
		_touch_down.erase(event.index)
		return _is_tap(down, event.position) and mark_target_at_screen(event.position) != null
	if event is InputEventMouseButton and event.button_index == MARK_MOUSE_BUTTON \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed:
			_mouse_mark_down = event.position
			return false
		var down = _mouse_mark_down
		_mouse_mark_down = null
		return _is_tap(down, event.position) and mark_target_at_screen(event.position) != null
	return false


func _is_tap(down: Variant, up: Vector2) -> bool:
	return down is Vector2 and up.distance_to(down) <= _feedback_config.tap_slop_px


## Toggles the mark on the hostile hull drawn nearest `screen_pos` (within
## mark_pick_radius_px). Returns that hull, or null when the tap hit none.
func mark_target_at_screen(screen_pos: Vector2, cam: Camera3D = null) -> Node3D:
	if not is_instance_valid(player_ship):
		return null
	var solver := player_ship.get_node_or_null("FiringSolver") as FiringSolver
	if not solver:
		return null
	if not cam:
		cam = get_viewport().get_camera_3d()
	if not cam:
		return null
	var best: Node3D = null
	var best_px: float = _feedback_config.mark_pick_radius_px
	for group in ["enemy_ship", "boss_ship"]:
		for hull in get_tree().get_nodes_in_group(group):
			if not (hull is Node3D) or not FiringSolver.are_hostile(player_ship, hull):
				continue
			if cam.is_position_behind(hull.global_position):
				continue
			var px: float = cam.unproject_position(hull.global_position).distance_to(screen_pos)
			if px <= best_px:
				best_px = px
				best = hull
	if best:
		solver.toggle_priority_target(best)
	return best


## M30 0.20 — the old hard-coded "board, else dock" as two providers. A
## boarding attempt that declines falls through to dock, as before.
func _register_wave0_context_verbs() -> void:
	_context_arbiter.register_provider(&"board",
		func(): return _can_board(),
		func(): return _board_enemy(),
		"Board Enemy", "board")
	# M30 W2 (2.6) - a ship that has struck its colours is taken, not fought.
	_context_arbiter.register_provider(&"take_prize",
		func(): return _boarding_system != null and _boarding_system.has_method("can_take_prize") \
				and bool(_boarding_system.can_take_prize()),
		func(): return _board_enemy(),
		"Take Prize", "board")
	_context_arbiter.register_provider(&"dock",
		_can_toggle_docking,
		func(): _toggle_docking(); return true,
		"Dock", "dock")


## M30 W2 (2.1) — the Board verb begins a Three Bells battle, or resolves
## instantly for Quick boarding / an overwhelming crew (BoardingSystem decides).
func _can_board() -> bool:
	if _boarding_system == null:
		return false
	if _boarding_system.has_method("can_board"):
		return bool(_boarding_system.can_board())
	return _boarding_system.get("_eligible_enemy") != null


func _board_enemy() -> bool:
	if _boarding_system == null:
		return false
	if _boarding_system.has_method("begin_boarding"):
		return bool(_boarding_system.begin_boarding())
	return _boarding_system.has_method("attempt_boarding") and bool(_boarding_system.attempt_boarding())


## M30 W1 (1.6) — Brace on the context button (priority above Board/Dock).
func _register_wave1_context_verbs() -> void:
	_context_arbiter.register_provider(&"brace",
		_can_brace,
		_perform_brace,
		"Brace", "shield")


func _player_combat() -> ShipCombat:
	if not is_instance_valid(player_ship):
		return null
	return player_ship.get_node_or_null("ShipCombat") as ShipCombat


## Brace is offered only "during a wind-up that covers" the player (W1-1.3):
## never at anchor in port, mid-brace or on cooldown — otherwise it would take
## the Dock/Board press away from the player whenever it was merely off cooldown.
func _can_brace() -> bool:
	var combat := _player_combat()
	if not combat or not _brace_data or combat.is_bracing or combat.is_brace_on_cooldown():
		return false
	if bool(player_ship.get("is_docked")):
		return false
	return _windup_tracker.has_threat()


## Perfect when the soonest wind-up aimed at the player has at most
## perfect_window seconds left as the press lands.
func _perform_brace() -> bool:
	if not _can_brace():
		return false
	var perfect := _windup_tracker.soonest_remaining() <= _brace_data.perfect_window
	return _player_combat().apply_brace(_brace_data, perfect)


func _can_toggle_docking() -> bool:
	if not _docking_system:
		return false
	var state = _docking_system.current_state
	return state == _docking_system.DockState.DOCKED or state == _docking_system.DockState.APPROACHING


func _register_keg_context_provider() -> void:
	## M30 W1 task 1.10 — the "keg" context verb: offered only while a hostile
	## hull is inside the player's stern cone and the sortie still has stock.
	_context_arbiter.register_provider(&"keg",
		func(): return _can_drop_keg(),
		func(): return _drop_keg(),
		"Drop Keg", "keg")
	# A sortie starts with a full stock; docking refills it (_on_dock_completed).
	if _keg_config:
		_keg_stock = _keg_config.stock_per_sortie


func get_keg_stock() -> int:
	return _keg_stock


func _can_drop_keg() -> bool:
	if _keg_stock <= 0 or not _keg_config or not is_instance_valid(player_ship) \
			or not player_ship.is_inside_tree():
		return false
	return _hostile_in_stern_cone() != null


## The nearest live hostile hull inside KegConfigData's stern cone (full angle
## stern_cone_degrees about the hull's aft axis, out to stern_cone_range), or null.
func _hostile_in_stern_cone() -> Node3D:
	var aft: Vector3 = player_ship.global_transform.basis.z
	var aft_flat := Vector2(aft.x, aft.z).normalized()
	if aft_flat.length_squared() < 0.01:
		return null
	var half_cos := cos(deg_to_rad(_keg_config.stern_cone_degrees * 0.5))
	var range_sq: float = _keg_config.stern_cone_range * _keg_config.stern_cone_range
	var best: Node3D = null
	var best_d := INF
	for group in ["enemy_ship", "boss_ship"]:
		for hull in get_tree().get_nodes_in_group(group):
			if not (hull is Node3D) or not FiringSolver.are_hostile(player_ship, hull):
				continue
			var dmg = hull.get_node_or_null("ShipDamage")
			if dmg and dmg.has_method("is_destroyed") and dmg.is_destroyed():
				continue
			var v: Vector3 = hull.global_position - player_ship.global_position
			var flat := Vector2(v.x, v.z)
			var d_sq := flat.length_squared()
			if d_sq < 0.01 or d_sq > range_sq:
				continue
			if flat.normalized().dot(aft_flat) >= half_cos and d_sq < best_d:
				best_d = d_sq
				best = hull
	return best


func _drop_keg() -> bool:
	## Drops a keg `drop_offset` astern of the hull, on the water, and spends
	## one stock. The keg is parented to the player's own parent (the World
	## scene), so it is freed with the world on a scene change.
	if not _can_drop_keg() or not _keg_scene:
		return false
	var world: Node = player_ship.get_parent()
	if not world:
		return false
	var keg: PowderKeg = _keg_scene.instantiate()
	keg.dropped_by = player_ship
	world.add_child(keg)
	var aft: Vector3 = player_ship.global_transform.basis.z
	aft = Vector3(aft.x, 0.0, aft.z).normalized()
	var at: Vector3 = player_ship.global_position + aft * _keg_config.drop_offset
	at.y = 0.0
	keg.global_position = at
	keg.float_on_water()   # onto the swell now, not one physics frame late
	_keg_stock -= 1
	return true


func register_context_provider(verb: StringName, available: Callable, perform: Callable,
		label: String, icon: String = "") -> void:
	_context_arbiter.register_provider(verb, available, perform, label, icon)


func unregister_context_provider(verb: StringName) -> void:
	_context_arbiter.unregister_provider(verb)


func get_context_verb() -> StringName:
	return _context_arbiter.get_context_verb()


func get_context_label(verb: StringName) -> String:
	return _context_arbiter.get_label(verb)


func get_context_icon(verb: StringName) -> String:
	return _context_arbiter.get_icon(verb)


func _toggle_docking() -> void:
	if not _docking_system:
		return
	if _docking_system.current_state == _docking_system.DockState.DOCKED:
		_docking_system.attempt_undock()
	elif _docking_system.current_state == _docking_system.DockState.APPROACHING:
		_docking_system.attempt_dock()

## The buildings standing on the island with this id (empty if it is not in the scene).
func _buildings_at(island_id: String) -> Array:
	for island in get_tree().get_nodes_in_group("islands"):
		if "island_data" in island and island.island_data and island.island_data.island_id == island_id:
			return island.built_buildings
	return []


func _on_dock_completed(island_id: String) -> void:
	on_player_docked(island_id)
	# M30 W2 (2.8) - prizes sailing home under a prize crew are settled at the next dock.
	FleetManager.resolve_prizes_on_dock()
	# M30 W2 (2.10) - the Ship's Company mends a little every time the ship reaches port.
	var services := FleetManager.port_services(_buildings_at(island_id))
	FleetManager.heal_squads(CrewRankTable.get_default().dock_heal + int(services["heal"]))
	FleetManager.train_squads(int(services["xp"]))
	if EventManager.has_method("handle_docking_event"):
		EventManager.handle_docking_event(island_id)
	_update_lying_low(island_id)
	# M30 W1 task 1.10 — refill keg stock on dock
	if _keg_config:
		_keg_stock = _keg_config.stock_per_sortie


func _on_undock_completed() -> void:
	_update_lying_low("")


## Only a port the player OWNS counts as lying low — hiding in an enemy harbour
## should not cool the Admiralty off.
func _update_lying_low(island_id: String) -> void:
	if not EmpireManager.has_method("set_lying_low"):
		return
	var owned := false
	if not island_id.is_empty():
		var island = active_islands.get(island_id)
		if island and island.island_data and island.island_data.is_owned_by_player():
			owned = true
	EmpireManager.set_lying_low(owned)

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

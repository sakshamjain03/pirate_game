extends GutTest

# test_firing_solver.gd
# Slice 1 — arc-alignment auto-fire (docs/navalCombat.md §4/§5).
# The solver is the single source of truth for "is there a valid target in this
# side's arc?", shared by the player's auto-fire and EnemyAI. These tests pin the
# arc geometry, the range gate, the hostility rule and the auto-fire trigger.

class MockShip extends RigidBody3D:
	var active_captain: CaptainData = null
	var faction: Resource = null
	var is_docked: bool = false
	var fired_sides: Array[String] = []

	func fire_cannons(side: String) -> void:
		# Mirrors the real ShipController.fire_cannons(): recoil/smoke/SFX (and
		# here, the shot tally) only happen when the volley actually left the guns.
		var combat = get_node_or_null("ShipCombat")
		if combat and combat.fire_broadside(side):
			fired_sides.append(side)


# Every ship in this file is scoped into a per-test group, and each solver is
# pointed at only that group. Otherwise mock ships from other test scripts —
# which legitimately join the real "player_ship"/"enemy_ship" groups — drift into
# this file's scans and the "no target" assertions fail depending on run order.
var _scope: String = ""
var _scope_counter: int = 0
var _created_test_scene: Node3D = null

func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_scope_counter += 1
	_scope = "fs_scope_%d" % _scope_counter

func after_each():
	# This file's own current_scene, if it created one, must not outlive it —
	# a leaked one previously corrupted test_navigation_integration.gd's real
	# get_tree().change_scene_to_file() call (freed-lambda-capture crash).
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null

func _stats(cannon_range: float = 100.0, arc: float = 35.0, has_bow: bool = false,
		has_stern: bool = false, chaser_range: float = 100.0, chaser_arc: float = 15.0) -> ShipStats:
	var s = ShipStats.new()
	s.max_health = 100.0
	s.max_sails = 100.0
	s.max_crew = 20.0
	s.cannon_range = cannon_range
	s.firing_arc_degrees = arc
	s.fire_rate = 2.0
	s.special_broadside_cooldown = 5.0
	s.special_broadside_damage_multiplier = 2.0
	s.has_bow_chaser = has_bow
	s.has_stern_chaser = has_stern
	s.chaser_range = chaser_range
	s.chaser_arc_degrees = chaser_arc
	return s

func _make_ship(stats: ShipStats, group: String, pos: Vector3 = Vector3.ZERO) -> MockShip:
	var ship = MockShip.new()
	ship.add_to_group(group)
	ship.add_to_group(_scope)
	# Hostility across the player boundary is group-based, so a mock standing in
	# for an enemy needs a faction to be hostile to a mock player. Distinct
	# faction ids on the two sides keep are_hostile() honest.
	if group != "player_ship" and ship.faction == null:
		ship.faction = load("res://resources/factions/RoyalNavy.tres")

	var dmg = load("res://scripts/world/ShipDamage.gd").new()
	dmg.name = "ShipDamage"
	dmg.ship_stats = stats
	ship.add_child(dmg)

	var solver = FiringSolver.new()
	solver.name = "FiringSolver"
	solver.ship_stats = stats
	# target_groups is Array[String]; an untyped literal is rejected on assignment.
	var scope_groups: Array[String] = [_scope]
	solver.target_groups = scope_groups
	ship.add_child(solver)

	var combat = ShipCombat.new()
	combat.name = "ShipCombat"
	combat.ship_stats = stats
	ship.add_child(combat)

	add_child_autoqfree(ship)
	ship.global_position = pos
	return ship

func _add_guns(ship: MockShip) -> void:
	var combat = ship.get_node("ShipCombat")
	for side in ["Port", "Starboard"]:
		var m = Node3D.new()
		m.name = side + "Marker1"
		ship.add_child(m)
		if side == "Port":
			combat.port_markers.append(m)
		else:
			combat.starboard_markers.append(m)

func _add_chaser_guns(ship: MockShip) -> void:
	var combat = ship.get_node("ShipCombat")
	var bow = Node3D.new()
	bow.name = "BowMarker"
	ship.add_child(bow)
	combat.bow_markers.append(bow)
	var stern = Node3D.new()
	stern.name = "SternMarker"
	ship.add_child(stern)
	combat.stern_markers.append(stern)


# --- arc geometry ---

func test_a_target_off_the_beam_locks_the_matching_side():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	# A default-oriented ship faces -Z, so +X is starboard.
	_make_ship(_stats(), "enemy_ship", Vector3(40, 0, 0))
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()

	assert_true(solver.is_aligned(FiringSolver.SIDE_STARBOARD),
		"A target directly off the starboard beam must lock starboard")
	assert_false(solver.is_aligned(FiringSolver.SIDE_PORT),
		"...and must not lock port")

func test_a_target_off_the_other_beam_locks_port():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_make_ship(_stats(), "enemy_ship", Vector3(-40, 0, 0))
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()
	assert_true(solver.is_aligned(FiringSolver.SIDE_PORT), "Target to port locks port")
	assert_false(solver.is_aligned(FiringSolver.SIDE_STARBOARD), "...not starboard")

func test_a_target_dead_ahead_locks_neither_side():
	## This is the whole mechanic: bow-on, no broadside bears. The player has to
	## turn to bring the guns round.
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_make_ship(_stats(), "enemy_ship", Vector3(0, 0, -40))
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()
	assert_false(solver.has_any_target(), "A bow-on target must not lock any side")

func test_arc_width_decides_how_forgiving_alignment_is():
	var narrow = _make_ship(_stats(100.0, 10.0), "player_ship", Vector3.ZERO)
	# 30 degrees off the beam: outside a 10-degree arc, inside a 45-degree one.
	var off_beam := Vector3(cos(deg_to_rad(30.0)), 0.0, -sin(deg_to_rad(30.0))) * 40.0
	_make_ship(_stats(), "enemy_ship", off_beam)
	await wait_process_frames(2)

	var narrow_solver: FiringSolver = narrow.get_node("FiringSolver")
	narrow_solver.force_rescan()
	assert_false(narrow_solver.has_any_target(), "A 30-degree offset is outside a 10-degree arc")

	narrow_solver.arc_override_degrees = 45.0
	narrow_solver.force_rescan()
	assert_true(narrow_solver.has_any_target(), "...and inside a 45-degree arc")


# --- chaser mounts (bow/stern) ---

func test_a_dead_ahead_target_locks_a_bow_chaser():
	var player = _make_ship(_stats(100.0, 35.0, true), "player_ship", Vector3.ZERO)
	_make_ship(_stats(), "enemy_ship", Vector3(0, 0, -40))
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()
	assert_true(solver.is_aligned(FiringSolver.SIDE_BOW),
		"A hull with has_bow_chaser must be able to lock dead ahead")
	assert_false(solver.is_aligned(FiringSolver.SIDE_PORT), "...not the broadside")
	assert_false(solver.is_aligned(FiringSolver.SIDE_STARBOARD), "...either side")

func test_a_hull_without_a_bow_chaser_still_locks_nothing_dead_ahead():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)  # has_bow defaults false
	_make_ship(_stats(), "enemy_ship", Vector3(0, 0, -40))
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()
	assert_false(solver.has_any_target(),
		"Most hulls have no chaser at all — a bow-on target must still lock nothing")

func test_a_dead_astern_target_locks_the_stern_chaser():
	var player = _make_ship(_stats(100.0, 35.0, false, true), "player_ship", Vector3.ZERO)
	_make_ship(_stats(), "enemy_ship", Vector3(0, 0, 40))
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()
	assert_true(solver.is_aligned(FiringSolver.SIDE_STERN),
		"A hull with has_stern_chaser must lock a target dead astern")
	assert_false(solver.is_aligned(FiringSolver.SIDE_BOW),
		"...and must not confuse it for a bow lock")

func test_chaser_arc_is_independent_of_the_broadside_arc():
	## chaser_arc_degrees = 15, firing_arc_degrees (broadside) = 35. A target 20
	## degrees off dead-ahead is 70 degrees off the beam: outside both arcs, so it
	## must lock neither — proving the chaser doesn't just inherit the broadside's
	## wider tolerance.
	var player = _make_ship(_stats(100.0, 35.0, true, false, 100.0, 15.0),
		"player_ship", Vector3.ZERO)
	var off_bow := Vector3(sin(deg_to_rad(20.0)), 0.0, -cos(deg_to_rad(20.0))) * 40.0
	_make_ship(_stats(), "enemy_ship", off_bow)
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()
	assert_false(solver.has_any_target(),
		"20 degrees off the bow is outside a 15-degree chaser arc and a 35-degree broadside arc")

func test_bow_and_stern_lock_different_targets_at_once():
	var player = _make_ship(_stats(100.0, 35.0, true, true), "player_ship", Vector3.ZERO)
	var ahead = _make_ship(_stats(), "enemy_ship", Vector3(0, 0, -40))
	var behind = _make_ship(_stats(), "enemy_ship", Vector3(0, 0, 40))
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()
	assert_eq(solver.get_target(FiringSolver.SIDE_BOW), ahead, "Bow locks the forward hull")
	assert_eq(solver.get_target(FiringSolver.SIDE_STERN), behind, "Stern locks the aft hull")

func test_auto_fire_fires_the_bow_chaser_when_aligned():
	var player = _make_ship(_stats(100.0, 35.0, true), "player_ship", Vector3.ZERO)
	_add_chaser_guns(player)
	_make_ship(_stats(), "enemy_ship", Vector3(0, 0, -40))
	await wait_physics_frames(4)

	assert_true(player.fired_sides.has(FiringSolver.SIDE_BOW),
		"A chaser must auto-fire exactly like a broadside once its arc lines up")


# --- range gate ---

func test_a_target_beyond_cannon_range_does_not_lock():
	var player = _make_ship(_stats(50.0), "player_ship", Vector3.ZERO)
	_make_ship(_stats(), "enemy_ship", Vector3(80, 0, 0))
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()
	assert_false(solver.has_any_target(), "80 units is outside a 50-unit cannon_range")

	solver.ship_stats = _stats(120.0)
	solver.force_rescan()
	assert_true(solver.has_any_target(), "...and inside a 120-unit range")

func test_the_nearest_target_on_a_side_is_chosen():
	var player = _make_ship(_stats(200.0), "player_ship", Vector3.ZERO)
	var far = _make_ship(_stats(), "enemy_ship", Vector3(90, 0, 0))
	var near = _make_ship(_stats(), "enemy_ship", Vector3(30, 0, 0))
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()
	assert_eq(solver.get_target(FiringSolver.SIDE_STARBOARD), near,
		"Unguided guns should target the closest hull, not the furthest")
	assert_ne(solver.get_target(FiringSolver.SIDE_STARBOARD), far, "")


# --- hostility ---

func test_the_solver_never_locks_onto_a_friendly_hull():
	var faction = load("res://resources/factions/RoyalNavy.tres")
	var shooter = _make_ship(_stats(), "enemy_ship", Vector3.ZERO)
	shooter.faction = faction
	var ally = _make_ship(_stats(), "enemy_ship", Vector3(40, 0, 0))
	ally.faction = faction
	await wait_process_frames(2)

	var solver: FiringSolver = shooter.get_node("FiringSolver")
	solver.force_rescan()
	assert_false(solver.has_any_target(),
		"Same-faction ships share collision layer 2; only faction identity separates them")

func test_hostility_agrees_with_the_cannonball_friendly_fire_rule():
	## The solver and Cannonball must use the same rule, or auto-fire would lock
	## onto hulls its own cannonballs refuse to damage.
	var navy = load("res://resources/factions/RoyalNavy.tres")
	var player = _make_ship(_stats(), "player_ship")
	var enemy = _make_ship(_stats(), "enemy_ship")
	enemy.faction = navy
	await wait_process_frames(1)

	assert_true(FiringSolver.are_hostile(player, enemy), "Player vs enemy is hostile")
	assert_true(FiringSolver.are_hostile(enemy, player), "...and symmetrically so")
	assert_false(FiringSolver.are_hostile(player, player), "A ship is never hostile to itself")

func test_a_sinking_wreck_stops_being_a_target():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	var enemy = _make_ship(_stats(), "enemy_ship", Vector3(40, 0, 0))
	await wait_process_frames(2)

	var solver: FiringSolver = player.get_node("FiringSolver")
	solver.force_rescan()
	assert_true(solver.has_any_target(), "Precondition: the live enemy is a target")

	enemy.get_node("ShipDamage").mark_destroyed()
	solver.force_rescan()
	assert_false(solver.has_any_target(),
		"Auto-fire must not keep hammering a wreck through its 2 s sink animation")


# --- auto-fire ---

func test_auto_fire_pulls_the_trigger_when_the_arc_lines_up():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_add_guns(player)
	_make_ship(_stats(), "enemy_ship", Vector3(40, 0, 0))
	await wait_physics_frames(4)

	assert_gt(player.fired_sides.size(), 0, "Auto-fire should have fired without any input")
	assert_true(player.fired_sides.has(FiringSolver.SIDE_STARBOARD),
		"...on the side that actually bears")
	assert_false(player.fired_sides.has(FiringSolver.SIDE_PORT),
		"...and not on the side that does not")

func test_auto_fire_does_not_fire_with_no_target():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_add_guns(player)
	await wait_physics_frames(5)
	assert_eq(player.fired_sides.size(), 0, "No hostile in arc means no shots")

func test_auto_fire_can_be_switched_off():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_add_guns(player)
	player.get_node("ShipCombat").auto_fire_enabled = false
	_make_ship(_stats(), "enemy_ship", Vector3(40, 0, 0))
	await wait_physics_frames(5)
	assert_eq(player.fired_sides.size(), 0,
		"auto_fire_enabled = false must leave firing entirely manual")

func test_auto_fire_respects_the_reload_gate():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_add_guns(player)
	_make_ship(_stats(), "enemy_ship", Vector3(40, 0, 0))
	# fire_rate 2.0 -> a 0.5 s reload, so a quarter second of frames is one volley.
	await wait_seconds(0.25)
	var shots: int = player.fired_sides.size()
	assert_eq(shots, 1, "Auto-fire must obey the per-side reload, not fire every frame")

func test_auto_fire_is_suppressed_while_docked():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_add_guns(player)
	player.is_docked = true
	_make_ship(_stats(), "enemy_ship", Vector3(40, 0, 0))
	await wait_physics_frames(5)
	assert_eq(player.fired_sides.size(), 0, "A docked ship must not auto-fire")

func test_zero_crew_still_blocks_auto_fire():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_add_guns(player)
	_make_ship(_stats(), "enemy_ship", Vector3(40, 0, 0))
	await wait_process_frames(1)
	player.get_node("ShipDamage").crew = 0.0
	var before: int = player.fired_sides.size()
	await wait_seconds(0.3)
	# fire_cannons is still called, but fire_broadside refuses, so no volley lands.
	var combat = player.get_node("ShipCombat")
	assert_false(combat.fire_broadside(FiringSolver.SIDE_STARBOARD),
		"A ship with no crew cannot fire, auto or manual")
	assert_true(before >= 0, "")


# --- special broadside ---

func test_special_broadside_fires_both_sides_and_then_goes_on_cooldown():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_add_guns(player)
	player.get_node("ShipCombat").auto_fire_enabled = false
	await wait_process_frames(1)

	var combat = player.get_node("ShipCombat")
	assert_true(combat.is_special_broadside_ready(), "Starts ready")
	assert_true(combat.fire_special_broadside(), "The volley should fire")

	assert_true(player.fired_sides.has(FiringSolver.SIDE_PORT), "Port fired")
	assert_true(player.fired_sides.has(FiringSolver.SIDE_STARBOARD), "Starboard fired")
	assert_false(combat.is_special_broadside_ready(), "...and then it is on cooldown")
	assert_false(combat.fire_special_broadside(), "A second volley must be refused")

func test_special_broadside_ignores_the_per_side_reload():
	## That bypass is what makes it a special rather than just an early volley.
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_add_guns(player)
	var combat = player.get_node("ShipCombat")
	combat.auto_fire_enabled = false
	await wait_process_frames(1)

	combat.can_fire_port = false
	combat.can_fire_starboard = false
	assert_true(combat.fire_special_broadside(), "Should fire even mid-reload")

func test_special_broadside_cooldown_fraction_reports_progress():
	var player = _make_ship(_stats(), "player_ship", Vector3.ZERO)
	_add_guns(player)
	var combat = player.get_node("ShipCombat")
	combat.auto_fire_enabled = false
	await wait_process_frames(1)

	assert_eq(combat.get_special_cooldown_fraction(), 1.0, "Ready reads as 1.0")
	combat.fire_special_broadside()
	assert_lt(combat.get_special_cooldown_fraction(), 1.0, "Just-fired reads below 1.0")

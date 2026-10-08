extends GutTest
## M30 W1 task 1.8 — aim-by-bearing priority_mode (player) + tap-to-mark.
## Verify: of two hulls in the arc, the one nearer the centre line wins for the
## player and the nearer one wins for the AI. A marked target wins while it's in
## the arc (and only then: out of arc, normal ranking resumes).

class StubDamage extends Node:
	var destroyed := false
	func is_destroyed() -> bool:
		return destroyed


var _scene: Node3D
var _solver: FiringSolver
var _ship: Node3D
var _group: String
var _counter := 0


func before_each() -> void:
	_counter += 1
	_group = "aim_bearing_targets_%d" % _counter
	_scene = Node3D.new()
	_scene.name = "AimBearingScene"
	add_child_autofree(_scene)
	_ship = Node3D.new()
	_ship.name = "Player"
	_ship.add_to_group("player_ship")
	_scene.add_child(_ship)
	_solver = _make_solver(_ship, FiringSolver.PriorityMode.AIM_BY_BEARING)


func _make_solver(ship: Node3D, mode: FiringSolver.PriorityMode) -> FiringSolver:
	var solver := FiringSolver.new()
	solver.name = "FiringSolver"
	var stats := ShipStats.new()
	stats.cannon_range = 100.0
	stats.firing_arc_degrees = 35.0
	solver.ship_stats = stats
	solver.target_groups = [_group]
	solver.priority_mode = mode
	ship.add_child(solver)
	return solver


func _enemy(pos: Vector3) -> Node3D:
	var e := Node3D.new()
	var dmg := StubDamage.new()
	dmg.name = "ShipDamage"
	e.add_child(dmg)
	e.add_to_group(_group)
	_scene.add_child(e)
	e.global_position = pos
	return e


# Two hulls both inside the 35 deg starboard arc: `square` dead abeam at 80,
# `angled` ~30 deg off the beam but nearer (~69).
func _pair() -> Array:
	var square := _enemy(Vector3(80, 0, 0))
	var angled := _enemy(Vector3(60, 0, -35))
	assert_lt(_ship.global_position.distance_to(angled.global_position),
		_ship.global_position.distance_to(square.global_position), "precondition: angled is nearer")
	assert_lt(_solver.get_broadside_angle((angled.global_position).normalized()), 35.0,
		"precondition: angled is inside the arc")
	return [square, angled]


func test_player_prefers_the_hull_nearest_the_centre_line() -> void:
	var p := _pair()
	_solver._rescan()
	assert_eq(_solver.get_target("starboard"), p[0], "aim-by-bearing: the square-on hull wins")


func test_ai_keeps_the_nearest_hull() -> void:
	var p := _pair()
	_solver.priority_mode = FiringSolver.PriorityMode.NEAREST
	_solver._rescan()
	assert_eq(_solver.get_target("starboard"), p[1], "nearest mode: the nearer hull wins")


func test_scenes_set_bearing_for_the_player_and_nearest_for_the_ai() -> void:
	var player: Node = load("res://scenes/world/PlayerShip.tscn").instantiate()
	var enemy: Node = load("res://scenes/world/EnemyShip.tscn").instantiate()
	assert_eq(player.get_node("FiringSolver").priority_mode, FiringSolver.PriorityMode.AIM_BY_BEARING,
		"PlayerShip.tscn's solver aims by bearing")
	assert_eq(enemy.get_node("FiringSolver").priority_mode, FiringSolver.PriorityMode.NEAREST,
		"EnemyShip.tscn's solver keeps nearest")
	player.free()
	enemy.free()


func test_a_marked_target_wins_while_in_the_arc() -> void:
	var p := _pair()
	_solver.set_priority_target(p[1])
	_solver._rescan()
	assert_eq(_solver.get_target("starboard"), p[1], "the mark beats the square-on hull")


func test_a_mark_out_of_arc_does_not_silence_the_guns() -> void:
	var square := _enemy(Vector3(80, 0, 0))
	var ahead := _enemy(Vector3(0, 0, -60))   # dead ahead: no broadside arc covers it
	_solver.set_priority_target(ahead)
	_solver._rescan()
	assert_eq(_solver.get_target("starboard"), square, "normal ranking resumes while the mark is out of arc")
	assert_eq(_solver.priority_target, ahead, "the mark itself is kept")
	ahead.global_position = Vector3(50, 0, -10)   # swings into the starboard arc
	_solver._rescan()
	assert_eq(_solver.get_target("starboard"), ahead, "and wins again once it is in the arc")


func test_a_mark_on_one_side_leaves_the_other_side_alone() -> void:
	var port_mark := _enemy(Vector3(-50, 0, 0))
	var starboard := _enemy(Vector3(80, 0, 0))
	_solver.set_priority_target(port_mark)
	_solver._rescan()
	assert_eq(_solver.get_target("port"), port_mark)
	assert_eq(_solver.get_target("starboard"), starboard, "starboard keeps its own target")


func test_a_sunk_mark_is_cleared() -> void:
	var p := _pair()
	_solver.set_priority_target(p[1])
	watch_signals(_solver)
	p[1].get_node("ShipDamage").destroyed = true
	_solver._rescan()
	assert_null(_solver.priority_target, "a sinking mark is dropped")
	assert_signal_emitted(_solver, "priority_target_changed")
	assert_eq(_solver.get_target("starboard"), p[0])


func test_toggle_marks_then_clears() -> void:
	var e := _enemy(Vector3(80, 0, 0))
	_solver.toggle_priority_target(e)
	assert_eq(_solver.priority_target, e)
	_solver.toggle_priority_target(e)
	assert_null(_solver.priority_target, "tapping the marked hull again clears it")


func test_a_friendly_hull_cannot_be_marked() -> void:
	var ally := Node3D.new()
	ally.add_to_group("friendly_ship")
	_scene.add_child(ally)
	_solver.set_priority_target(ally)
	assert_null(_solver.priority_target)


func test_world_manager_tap_marks_the_hull_under_the_finger() -> void:
	var enemy := _enemy(Vector3(80, 0, 0))
	enemy.add_to_group("enemy_ship")
	var cam := Camera3D.new()
	_scene.add_child(cam)
	cam.look_at_from_position(Vector3(0, 60, 0.01), Vector3(40, 0, 0))
	var wm: Node = load("res://scripts/managers/WorldManager.gd").new()
	add_child_autofree(wm)
	wm.player_ship = _ship
	var on_screen: Vector2 = cam.unproject_position(enemy.global_position)
	assert_eq(wm.mark_target_at_screen(on_screen + Vector2(10, -8), cam), enemy,
		"a tap near the hull's screen position picks it")
	assert_eq(_solver.priority_target, enemy, "and marks it on the player's solver")
	assert_null(wm.mark_target_at_screen(on_screen + Vector2(400, 300), cam),
		"a tap far from every hull picks nothing")
	assert_eq(_solver.priority_target, enemy, "and leaves the mark alone")
	wm.mark_target_at_screen(on_screen, cam)
	assert_null(_solver.priority_target, "a second tap on the hull clears the mark")

extends GutTest
## M30 W1 task 1.8 — aim-by-bearing priority mode and tap-to-mark.
## The player's FiringSolver prefers the hull nearest the arc's centre line
## (aim-by-bearing), plus an optional tap-to-mark override (priority_target).
## The AI keeps nearest-target behaviour.

var _solver: FiringSolver
var _ship: Node3D
var _scope: String = ""
var _scope_counter: int = 0
var _target_group: String = ""
var _scene: Node3D = null
var _prev_scene: Node = null


func before_each() -> void:
	# Create a fresh isolated scene for each test with a unique target group
	_prev_scene = get_tree().current_scene
	var scene = Node3D.new()
	scene.name = "TestScene"
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	_scene = scene

	_scope_counter += 1
	_scope = "aim_bearing_scope_%d" % _scope_counter
	_target_group = "test_enemies_%d" % _scope_counter

	_ship = Node3D.new()
	_ship.name = "Player"
	_ship.add_to_group("player_ship")
	_ship.add_to_group(_scope)
	scene.add_child(_ship)

	_solver = FiringSolver.new()
	var stats = ShipStats.new()
	stats.cannon_range = 100.0
	stats.firing_arc_degrees = 35.0
	_solver.ship_stats = stats
	_solver.target_groups = [_target_group]
	_ship.add_child(_solver)


## Free the per-test scene (ship, solver, enemies) immediately so the plain
## Node3D "Player" in group player_ship cannot leak into later test scripts
## (MaelstromRun / SaveManager look up get_first_node_in_group("player_ship")),
## and hand current_scene back to whatever it was before this test.
func after_each() -> void:
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = _prev_scene if is_instance_valid(_prev_scene) else null
		_scene.get_parent().remove_child(_scene)
		_scene.free()
	_scene = null
	_ship = null
	_solver = null
	_prev_scene = null


func _make_enemy(pos: Vector3) -> Node3D:
	var e = Node3D.new()
	var dmg = Node.new()
	dmg.name = "ShipDamage"
	e.add_child(dmg)
	e.add_to_group(_target_group)
	e.add_to_group(_scope)
	get_tree().current_scene.add_child(e)
	e.global_position = pos
	return e


func test_aim_by_bearing_prefers_perpendicular_angle() -> void:
	var perpendicular = _make_enemy(Vector3(80, 0, 0))
	var angled = _make_enemy(Vector3(60, 0, -35))

	_solver.priority_mode = "aim_by_bearing"
	_solver._rescan()

	var target = _solver.get_target("starboard")
	assert_eq(target, perpendicular, "aim_by_bearing prefers perpendicular target")


func test_priority_target_forces_selection() -> void:
	var marked = _make_enemy(Vector3(40, 0, -20))
	var other = _make_enemy(Vector3(80, 0, 0))

	_solver.priority_mode = "aim_by_bearing"
	_solver.priority_target = marked
	_solver._rescan()

	var target = _solver.get_target("starboard")
	assert_eq(target, marked, "priority_target overrides selection")


func test_mode_can_be_toggled() -> void:
	var perpendicular = _make_enemy(Vector3(80, 0, 0))
	var angled = _make_enemy(Vector3(60, 0, -35))

	# With aim_by_bearing, perpendicular should win
	_solver.priority_mode = "aim_by_bearing"
	_solver._rescan()
	assert_eq(_solver.get_target("starboard"), perpendicular, "aim_by_bearing active")

	# Clear priority mode and rescan - behavior changes
	_solver.priority_mode = ""
	_solver._rescan()
	var target = _solver.get_target("starboard")
	assert_not_null(target, "default mode also selects a target")

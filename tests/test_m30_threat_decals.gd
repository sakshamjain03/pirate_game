extends GutTest
## M30 W1 task 1.5 — threat decals. When an enemy broadside winds up
## (ShipCombat.broadside_windup, added by the gunnery lane) the player sees a
## wedge on the water in the attacker's ammo colour, plus a screen-rim arrow when
## the attacker is off-screen. At most `max_visible` (2) at once, ranked by
## soonest-to-fire, then nearest. The stub below emits the signal directly so
## this test does not depend on the gunnery lane's wind-up gate.

class StubCombat extends Node:
	signal broadside_windup(side: String, duration: float)
	var current_ammo: AmmoData = null


class StubCombat3 extends Node:
	## The requirement's three-argument form (side, duration, target).
	signal broadside_windup(side: String, duration: float, target: Node)
	var current_ammo: AmmoData = null


var _decals: ThreatDecals
var _player: Node3D
var _cfg: ThreatDecalsData


func before_each() -> void:
	_cfg = load("res://resources/ui/ThreatDecals.tres")
	_player = Node3D.new()
	_player.name = "StubPlayer"
	add_child_autofree(_player)
	_decals = ThreatDecals.new()
	_decals.auto_scan = false
	_decals.player = _player
	add_child_autofree(_decals)


func _enemy(pos: Vector3, ammo_path: String = "res://resources/combat/ammo/RoundShot.tres",
		three_arg := false) -> Node3D:
	var ship := Node3D.new()
	var combat: Node = StubCombat3.new() if three_arg else StubCombat.new()
	combat.name = "ShipCombat"
	combat.current_ammo = load(ammo_path)
	ship.add_child(combat)
	add_child_autofree(ship)
	ship.global_position = pos
	assert_true(_decals.watch_ship(ship), "a hull with broadside_windup is watched")
	return ship


func _wedge_shown(ship: Node3D) -> bool:
	var w: MeshInstance3D = _decals.get_wedge(ship)
	return w != null and w.visible


func _windup(ship: Node3D, side: String, duration: float) -> void:
	ship.get_node("ShipCombat").broadside_windup.emit(side, duration)


func test_config_is_authored_with_a_budget_of_two() -> void:
	assert_eq(_cfg.max_visible, 2)
	assert_eq(_decals.config.max_visible, 2, "ThreatDecals reads the authored config")


func test_a_windup_shows_a_wedge_tinted_by_the_attackers_ammo() -> void:
	var e := _enemy(Vector3(30, 0, 0), "res://resources/combat/ammo/ChainShot.tres")
	_windup(e, "port", 1.0)
	_decals.refresh(0.0)
	assert_eq(_decals.get_visible_threats(), [e])
	var wedge: MeshInstance3D = _decals.get_wedge(e)
	assert_not_null(wedge, "a wedge decal exists for the attacker")
	assert_true(wedge.visible)
	var mat := wedge.material_override as StandardMaterial3D
	var want: Color = _cfg.color_for_ammo("chain")
	assert_almost_eq(mat.albedo_color.r, want.r, 0.001, "tinted by chain shot's colour")
	assert_almost_eq(mat.albedo_color.g, want.g, 0.001)
	assert_almost_eq(mat.albedo_color.b, want.b, 0.001)
	assert_ne(_cfg.color_for_ammo("chain"), _cfg.color_for_ammo("round"),
		"ammo types must be tellable apart")


func test_the_wedge_points_out_of_the_winding_up_side() -> void:
	var e := _enemy(Vector3(30, 0, 0))
	_windup(e, "port", 1.0)
	_decals.refresh(0.0)
	var wedge: MeshInstance3D = _decals.get_wedge(e)
	# The wedge's local +X is its centre line; port is the hull's -X.
	var centre: Vector3 = wedge.global_transform.basis.x.normalized()
	assert_almost_eq(centre.dot(-e.global_transform.basis.x), 1.0, 0.01)
	assert_almost_eq(wedge.global_position.x, 30.0, 0.01, "anchored on the attacker")


func test_three_argument_signal_form_is_accepted() -> void:
	var e := _enemy(Vector3(30, 0, 0), "res://resources/combat/ammo/RoundShot.tres", true)
	e.get_node("ShipCombat").broadside_windup.emit("starboard", 1.0, _player)
	_decals.refresh(0.0)
	assert_eq(_decals.get_visible_threats(), [e])


func test_a_windup_aimed_at_someone_else_is_not_a_threat_to_the_player() -> void:
	var e := _enemy(Vector3(30, 0, 0), "res://resources/combat/ammo/RoundShot.tres", true)
	var other := Node3D.new()
	add_child_autofree(other)
	e.get_node("ShipCombat").broadside_windup.emit("starboard", 1.0, other)
	_decals.refresh(0.0)
	assert_eq(_decals.get_visible_threats(), [])


func test_budget_never_exceeds_two_and_the_nearest_win_a_tie() -> void:
	var far := _enemy(Vector3(90, 0, 0))
	var near := _enemy(Vector3(20, 0, 0))
	var mid := _enemy(Vector3(0, 0, 50))
	for e in [far, near, mid]:
		_windup(e, "port", 1.5)
	_decals.refresh(0.0)
	var shown: Array = _decals.get_visible_threats()
	assert_eq(shown.size(), 2, "at most two at once")
	assert_eq(shown, [near, mid], "equal fuse: nearest first")
	assert_false(_wedge_shown(far), "the third wedge is hidden, not drawn")
	assert_true(_wedge_shown(near) and _wedge_shown(mid))


func test_soonest_to_fire_outranks_nearer() -> void:
	var near := _enemy(Vector3(15, 0, 0))
	var mid := _enemy(Vector3(30, 0, 0))
	var far := _enemy(Vector3(100, 0, 0))
	_windup(near, "port", 2.0)
	_windup(mid, "port", 2.0)
	_windup(far, "port", 0.4)
	_decals.refresh(0.0)
	assert_eq(_decals.get_visible_threats(), [far, near], "the volley about to land wins the slot")


func test_a_threat_clears_once_its_windup_elapses() -> void:
	var e := _enemy(Vector3(30, 0, 0))
	_windup(e, "port", 0.5)
	_decals.refresh(0.3)
	assert_eq(_decals.get_visible_threats().size(), 1)
	_decals.refresh(0.3)
	assert_eq(_decals.get_visible_threats().size(), 0, "fired: nothing left to read")
	assert_false(_wedge_shown(e))


func test_a_freed_attacker_is_dropped() -> void:
	var e := _enemy(Vector3(30, 0, 0))
	_windup(e, "port", 3.0)
	_decals.refresh(0.0)
	e.free()
	_decals.refresh(0.0)
	assert_eq(_decals.get_visible_threats().size(), 0)


class StubAI extends Node:
	signal ram_telegraphed(target: Node3D, seconds: float)


func test_a_ram_telegraph_shows_a_wedge_out_of_the_bow() -> void:
	# M30 W1-1.1: EnemyAI.ram_telegraphed is the ram's read window; the decal layer
	# draws it like a wind-up, pointing out of the rammer's bow.
	var ship := Node3D.new()
	var combat := StubCombat.new()
	combat.name = "ShipCombat"
	combat.current_ammo = load("res://resources/combat/ammo/RoundShot.tres")
	ship.add_child(combat)
	var ai := StubAI.new()
	ai.name = "EnemyAI"
	ship.add_child(ai)
	add_child_autofree(ship)
	ship.global_position = Vector3(25, 0, 0)
	assert_true(_decals.watch_ship(ship))
	ai.ram_telegraphed.emit(_player, 1.5)
	_decals.refresh(0.0)
	assert_eq(_decals.get_visible_threats(), [ship], "a telegraphed ram is a threat")
	var wedge: MeshInstance3D = _decals.get_wedge(ship)
	var centre: Vector3 = wedge.global_transform.basis.x.normalized()
	assert_almost_eq(centre.dot(-ship.global_transform.basis.z), 1.0, 0.01, "the wedge points out of the bow")
	_decals.refresh(1.6)
	assert_eq(_decals.get_visible_threats().size(), 0, "cleared once the telegraph elapses")


func test_a_ram_telegraph_at_someone_else_is_ignored() -> void:
	var ship := Node3D.new()
	var combat := StubCombat.new()
	combat.name = "ShipCombat"
	ship.add_child(combat)
	var ai := StubAI.new()
	ai.name = "EnemyAI"
	ship.add_child(ai)
	add_child_autofree(ship)
	_decals.watch_ship(ship)
	var other := Node3D.new()
	add_child_autofree(other)
	ai.ram_telegraphed.emit(other, 1.5)
	_decals.refresh(0.0)
	assert_eq(_decals.get_visible_threats(), [])


func test_rim_arrow_only_for_an_off_screen_attacker() -> void:
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.global_position = Vector3(0, 10, 0)   # looks down -Z by default
	_decals.camera = cam
	var ahead := _enemy(Vector3(0, 0, -60))
	var behind := _enemy(Vector3(0, 0, 60))
	_windup(ahead, "port", 2.0)
	_windup(behind, "port", 2.0)
	_decals.refresh(0.0)
	assert_eq(_decals.get_visible_threats().size(), 2)
	assert_false(_decals.get_rim_arrow(ahead).visible, "on screen: the wedge is enough")
	var arrow: Node2D = _decals.get_rim_arrow(behind)
	assert_true(arrow.visible, "off screen: the rim arrow points at it")
	var vp := _decals.get_viewport_rect().size
	assert_true(arrow.position.y > vp.y * 0.5, "an attacker behind the camera is flagged at the bottom edge")
	var want: Color = _cfg.color_for_ammo("round")
	assert_almost_eq(arrow.color.r, want.r, 0.001, "the arrow carries the ammo tint too")

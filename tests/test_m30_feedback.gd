extends GutTest
## M30 W1 task 1.11 — the feedback pack (W1-2.3). Verify bullets:
##   - Ribbon cap holds (max_ribbons from CombatFeedback.tres; the 4th frees
##     the oldest ribbon node).
##   - The camera punch moves Camera3D.h_offset/v_offset and never touches
##     Engine.time_scale.
##   - Reduced motion -> no punch.
## Plus the rest of the pack, driven through real hulls: a rake (stern hit)
## landed by the player raises a ribbon, buzzes REWARD and punches; a hit taken
## buzzes DAMAGE; a kill and a Perfect Brace raise their ribbons; damage numbers
## are coloured by ammo (rake overrides); the rake cone sits off the current
## target's stern; WorldHUD.tscn instances and wires the pack.

const PLAYER_SHIP := "res://scenes/world/PlayerShip.tscn"
const ENEMY_SHIP := "res://scenes/world/EnemyShip.tscn"
const CAMERA_RIG := "res://scenes/world/CameraRig.tscn"
const ROUND := "res://resources/combat/ammo/RoundShot.tres"
const CHAIN := "res://resources/combat/ammo/ChainShot.tres"

var _cfg: CombatFeedbackData
var _root: Node3D
var _created_test_scene: Node3D = null
var _haptics: Array = []
var _saved_time_scale: float = 1.0


func before_each() -> void:
	if not get_tree().current_scene:
		var scene := Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_cfg = load("res://resources/ui/CombatFeedback.tres")
	_root = Node3D.new()
	_root.name = "FeedbackRoot"
	add_child_autofree(_root)
	_haptics = []
	HapticFeedbackManager.requested.connect(_on_haptic)
	UIMotion.force_reduced_motion_for_test = false
	_saved_time_scale = Engine.time_scale


func after_each() -> void:
	if HapticFeedbackManager.requested.is_connected(_on_haptic):
		HapticFeedbackManager.requested.disconnect(_on_haptic)
	UIMotion.force_reduced_motion_for_test = false
	Engine.time_scale = _saved_time_scale
	# Damage numbers spawned into current_scene by real hits.
	var cs := get_tree().current_scene
	if cs:
		for c in cs.get_children():
			if c is Label3D:
				c.free()
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.free()
	_created_test_scene = null


func _on_haptic(kind: Dictionary) -> void:
	_haptics.append(kind)


func _spawn(path: String, pos: Vector3) -> Node3D:
	var ship := load(path).instantiate() as Node3D
	_root.add_child(ship)
	ship.global_position = pos
	if ship is RigidBody3D:
		ship.freeze = true
	var combat = ship.get_node_or_null("ShipCombat")
	if combat:
		combat.auto_fire_enabled = false
	var ai = ship.get_node_or_null("EnemyAI")
	if ai:
		ai.set_physics_process(false)
		ai.set_process(false)
	return ship


func _rig() -> CameraRig:
	var rig: CameraRig = load(CAMERA_RIG).instantiate()
	_root.add_child(rig)
	rig.set_physics_process(false)
	rig.set_process(false)   # punch decay is stepped by hand below
	return rig


func _ribbons() -> RibbonStack:
	var rs := RibbonStack.new()
	add_child_autofree(rs)
	rs.set_process(false)
	return rs


## A CombatFeedback wired to a real player hull, its own ribbons and camera rig.
func _pack() -> Dictionary:
	var player := _spawn(PLAYER_SHIP, Vector3.ZERO)
	var fb := CombatFeedback.new()
	fb.auto_scan = false
	fb.ribbons = _ribbons()
	fb.camera_rig = _rig()
	add_child_autofree(fb)
	fb.set_process(false)
	fb.wire_player(player)
	return {"player": player, "fb": fb, "ribbons": fb.ribbons, "rig": fb.camera_rig}


func _offset(rig: CameraRig) -> Vector2:
	return Vector2(rig.camera.h_offset, rig.camera.v_offset)


# ------------------------------------------------------------------ ribbons

func test_ribbon_cap_holds_and_the_fourth_frees_the_oldest_node() -> void:
	assert_eq(_cfg.max_ribbons, 3, "authored cap is 3 (W1-2.3)")
	var rs := _ribbons()
	assert_eq(rs.config.max_ribbons, 3, "RibbonStack reads the cap from CombatFeedback.tres")
	var first: Label = rs.add_ribbon("a", "A")
	rs.add_ribbon("b", "B")
	rs.add_ribbon("c", "C")
	assert_eq(rs.get_child_count(), 3, "three ribbon nodes on screen")
	rs.add_ribbon("d", "D")
	assert_eq(rs.get_ribbon_count(), 3, "the cap holds")
	assert_eq(rs.get_child_count(), 3, "and so does the node count")
	assert_false(is_instance_valid(first), "the oldest ribbon node is freed at once")
	var texts: Array = []
	for l in rs.get_ribbon_labels():
		texts.append(l.text)
	assert_eq(texts, ["B", "C", "D"], "the newest three remain, oldest first")


func test_a_repeat_ribbon_counts_up_instead_of_taking_a_slot() -> void:
	var rs := _ribbons()
	var l: Label = rs.add_ribbon("rake", "Rake!")
	rs.add_ribbon("rake", "Rake!")
	assert_eq(rs.get_child_count(), 1)
	assert_eq(l.text, "Rake! x2")


func test_ribbons_retire_after_their_lifetime() -> void:
	var rs := _ribbons()
	var l: Label = rs.add_ribbon("kill", "Sunk!")
	rs.tick(_cfg.ribbon_lifetime * 0.5)
	assert_eq(rs.get_ribbon_count(), 1)
	rs.tick(_cfg.ribbon_lifetime)
	assert_eq(rs.get_ribbon_count(), 0, "a ribbon is gone after ribbon_lifetime")
	assert_false(is_instance_valid(l))


# ------------------------------------------------------------------ punch

func test_punch_moves_h_and_v_offset_and_never_time_scale() -> void:
	var rig := _rig()
	var rig_xform := rig.global_transform
	assert_eq(_offset(rig), Vector2.ZERO, "precondition: lens centred")
	assert_true(rig.punch(0.4, 0.25))
	assert_almost_eq(_offset(rig).length(), 0.4, 0.001, "the lens shifts by the punch strength")
	assert_eq(Engine.time_scale, _saved_time_scale, "a punch never slows the world")
	assert_eq(rig.global_transform, rig_xform, "the rig itself does not move")
	rig.update_punch(0.1)
	assert_gt(_offset(rig).length(), 0.0)
	assert_lt(_offset(rig).length(), 0.4, "it decays")
	rig.update_punch(0.5)
	assert_eq(_offset(rig), Vector2.ZERO, "and settles back to centre")
	assert_false(rig.is_punching())
	assert_eq(Engine.time_scale, _saved_time_scale)


func test_punch_is_capped() -> void:
	var rig := _rig()
	rig.punch(5.0, 0.25, _cfg.punch_max)
	assert_almost_eq(_offset(rig).length(), _cfg.punch_max, 0.001)


func test_no_feedback_script_writes_time_scale() -> void:
	for path in ["res://scripts/world/CameraRig.gd", "res://scripts/ui/CombatFeedback.gd",
			"res://scripts/ui/RibbonStack.gd", "res://scripts/ui/FloatingDamage.gd"]:
		var src := FileAccess.get_file_as_string(path)
		for line in src.split("\n"):
			var code := line.split("#")[0]
			assert_false(code.contains("time_scale"), "%s: '%s'" % [path, line.strip_edges()])


func test_reduced_motion_means_no_punch() -> void:
	var rig := _rig()
	UIMotion.force_reduced_motion_for_test = true
	assert_false(rig.punch(0.4, 0.25), "punch refuses under reduced motion")
	assert_eq(_offset(rig), Vector2.ZERO)
	var s := _pack()
	var enemy := _spawn(ENEMY_SHIP, Vector3(40, 0, 0))
	s["player"].get_node("ShipDamage").apply_hit(10.0, load(ROUND), Vector3(1, 0, 0), enemy)
	assert_eq(_offset(s["rig"]), Vector2.ZERO, "a hit taken does not punch under reduced motion")
	assert_false(_haptics.is_empty(), "haptics are their own setting, not reduced motion")


func test_reduced_motion_switched_on_mid_punch_settles_at_once() -> void:
	var rig := _rig()
	rig.punch(0.4, 1.0)
	UIMotion.force_reduced_motion_for_test = true
	rig.update_punch(0.01)
	assert_eq(_offset(rig), Vector2.ZERO)


# ------------------------------------------------------------------ events

func test_a_rake_landed_raises_a_ribbon_buzzes_and_punches() -> void:
	var s := _pack()
	var enemy := _spawn(ENEMY_SHIP, Vector3(0, 0, -40))
	# hit_direction points from the target back toward the shot's origin; +Z
	# is the (unrotated) enemy's aft axis, so this lands in its stern arc.
	enemy.get_node("ShipDamage").apply_hit(10.0, load(ROUND), Vector3(0, 0, 1), s["player"])
	var labels: Array = s["ribbons"].get_ribbon_labels()
	assert_eq(labels.size(), 1, "a rake raises one ribbon")
	assert_eq(labels[0].text, "Rake!")
	assert_has(_haptics, HapticFeedbackManager.REWARD, "a rake buzzes REWARD")
	assert_gt(_offset(s["rig"]).length(), 0.0, "and punches the camera")


func test_a_beam_hit_landed_is_not_a_rake() -> void:
	var s := _pack()
	var enemy := _spawn(ENEMY_SHIP, Vector3(40, 0, 0))
	enemy.get_node("ShipDamage").apply_hit(10.0, load(ROUND), Vector3(1, 0, 0), s["player"])
	assert_eq(s["ribbons"].get_ribbon_count(), 0)
	assert_eq(_offset(s["rig"]), Vector2.ZERO)


func test_an_enemy_hit_on_someone_else_is_not_the_players() -> void:
	var s := _pack()
	var a := _spawn(ENEMY_SHIP, Vector3(0, 0, -40))
	var b := _spawn(ENEMY_SHIP, Vector3(0, 0, -80))
	a.get_node("ShipDamage").apply_hit(10.0, load(ROUND), Vector3(0, 0, 1), b)
	assert_eq(s["ribbons"].get_ribbon_count(), 0, "only the player's own shots raise ribbons")


func test_a_hit_taken_buzzes_damage_and_punches() -> void:
	var s := _pack()
	var enemy := _spawn(ENEMY_SHIP, Vector3(40, 0, 0))
	s["player"].get_node("ShipDamage").apply_hit(10.0, load(ROUND), Vector3(1, 0, 0), enemy)
	assert_has(_haptics, HapticFeedbackManager.DAMAGE)
	assert_gt(_offset(s["rig"]).length(), 0.0)


func test_a_kill_raises_the_sunk_ribbon() -> void:
	var s := _pack()
	var enemy := _spawn(ENEMY_SHIP, Vector3(40, 0, 0))
	enemy.get_node("ShipDamage").hull = 1.0
	enemy.get_node("ShipDamage").apply_hit(50.0, load(ROUND), Vector3(1, 0, 0), s["player"])
	var texts: Array = []
	for l in s["ribbons"].get_ribbon_labels():
		texts.append(l.text)
	assert_has(texts, "Sunk!")


func test_a_perfect_brace_raises_its_ribbon_and_a_plain_brace_does_not() -> void:
	var s := _pack()
	var combat: ShipCombat = s["player"].get_node("ShipCombat")
	assert_true(combat.apply_brace(load("res://resources/balance/Brace.tres"), false))
	assert_eq(s["ribbons"].get_ribbon_count(), 0, "a plain brace is not a ribbon")
	assert_has(_haptics, HapticFeedbackManager.TAP)
	var s2 := _pack()
	var combat2: ShipCombat = s2["player"].get_node("ShipCombat")
	assert_true(combat2.apply_brace(load("res://resources/balance/Brace.tres"), true))
	assert_eq(s2["ribbons"].get_ribbon_labels()[0].text, "Perfect Brace!")


# ------------------------------------------------------------------ damage numbers

func _numbers() -> Array:
	var out: Array = []
	for c in get_tree().current_scene.get_children():
		if c is Label3D and "ammo_id" in c:
			out.append(c)
	return out


func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func test_damage_numbers_are_coloured_by_ammo_and_a_rake_overrides() -> void:
	var player := _spawn(PLAYER_SHIP, Vector3.ZERO)
	var enemy := _spawn(ENEMY_SHIP, Vector3(40, 0, 0))
	var dmg = enemy.get_node("ShipDamage")
	dmg.apply_hit(5.0, load(CHAIN), Vector3(1, 0, 0), player)
	var nums := _numbers()
	assert_eq(nums.size(), 1, "one number per hit")
	assert_almost_eq(_rgb(nums[0].modulate), _rgb(_cfg.ammo_palette.color_for_ammo("chain")),
		Vector3.ONE * 0.001, "a chain-shot hit reads in chain's palette colour")
	nums[0].free()
	dmg.apply_hit(5.0, load(ROUND), Vector3(0, 0, 1), player)
	nums = _numbers()
	assert_eq(nums.size(), 1)
	assert_almost_eq(_rgb(nums[0].modulate), _rgb(_cfg.rake_color), Vector3.ONE * 0.001,
		"a stern hit reads in the rake colour")


func test_rake_colour_is_tellable_from_every_ammo_colour() -> void:
	for ammo_id in _cfg.ammo_palette.ammo_colors:
		var c: Color = _cfg.ammo_palette.ammo_colors[ammo_id]
		assert_gt(_rgb(c).distance_to(_rgb(_cfg.rake_color)), 0.3,
			"rake vs %s must not be confused" % ammo_id)


# ------------------------------------------------------------------ rake cone

func test_rake_cone_sits_off_the_current_targets_stern() -> void:
	var s := _pack()
	var fb: CombatFeedback = s["fb"]
	fb.refresh()
	assert_null(fb.get_rake_cone(), "no target, no cone")
	var enemy := _spawn(ENEMY_SHIP, Vector3(40, 0, 0))
	enemy.rotation.y = 0.6
	s["player"].get_node("FiringSolver").force_rescan()
	fb.refresh()
	var cone := fb.get_rake_cone()
	assert_not_null(cone, "a target in range gets a rake cone")
	assert_eq(fb.get_rake_cone_target(), enemy)
	assert_almost_eq(cone.global_position.x, enemy.global_position.x, 0.01, "apex at the target")
	assert_almost_eq(cone.global_position.z, enemy.global_position.z, 0.01)
	# WedgeMesh points along local +X; the cone must point out of the target's
	# stern (its +Z axis), not along any world axis.
	var cone_dir: Vector3 = cone.global_transform.basis.x
	var aft: Vector3 = enemy.global_transform.basis.z
	assert_gt(Vector2(cone_dir.x, cone_dir.z).normalized().dot(Vector2(aft.x, aft.z).normalized()), 0.99,
		"the cone opens astern of the target")
	enemy.get_node("ShipDamage")._is_destroyed = true
	enemy.remove_from_group("enemy_ship")
	s["player"].get_node("FiringSolver").force_rescan()
	fb.refresh()
	assert_null(fb.get_rake_cone(), "the cone goes with the target")


func test_a_marked_target_carries_the_rake_cone() -> void:
	var s := _pack()
	var fb: CombatFeedback = s["fb"]
	var near := _spawn(ENEMY_SHIP, Vector3(40, 0, 0))
	var marked := _spawn(ENEMY_SHIP, Vector3(-70, 0, 0))
	var solver: FiringSolver = s["player"].get_node("FiringSolver")
	solver.set_priority_target(marked)
	solver.force_rescan()
	fb.refresh()
	assert_eq(fb.get_rake_cone_target(), marked, "the mark is the player's current target")
	assert_ne(fb.get_rake_cone_target(), near)


# ------------------------------------------------------------------ HUD wiring

func test_world_hud_instances_and_wires_the_pack() -> void:
	var hud: Node = load("res://scenes/ui/WorldHUD.tscn").instantiate()
	var rs := hud.get_node_or_null("RibbonStack")
	var fb := hud.get_node_or_null("CombatFeedback")
	assert_true(rs is RibbonStack, "WorldHUD has a RibbonStack")
	assert_true(fb is CombatFeedback, "WorldHUD has the CombatFeedback node")
	assert_true(rs is VBoxContainer, "ribbon spacing is container layout")
	assert_true(fb.auto_scan, "the HUD's pack finds the player by itself")
	hud.free()


func test_auto_scan_wires_the_player_hull() -> void:
	var player := _spawn(PLAYER_SHIP, Vector3.ZERO)
	var rs := _ribbons()
	var fb := CombatFeedback.new()
	fb.ribbons = rs
	fb.camera_rig = _rig()
	add_child_autofree(fb)
	fb._process(_cfg.scan_interval + 0.01)
	assert_eq(fb.player, player, "auto-scan finds the player_ship hull")
	var enemy := _spawn(ENEMY_SHIP, Vector3(0, 0, -40))
	enemy.get_node("ShipDamage").apply_hit(10.0, load(ROUND), Vector3(0, 0, 1), player)
	assert_eq(rs.get_ribbon_count(), 1, "and its rakes reach the HUD's ribbons")

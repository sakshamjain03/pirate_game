extends GutTest

# test_ship_damage_visuals.gd
# Slice 9b — visible hull damage (docs/navalCombat.md §7's one remaining open
# item: "a visible 'critical' state at low hull, then Sunk"). ShipDamage.pool_changed
# already fired on every hit; nothing listened to it for visuals until now. These
# tests pin the STATE the damage tint/smoke drive (emitting flag, shader param
# values) rather than how it renders, which cannot be checked headlessly.

const ENEMY_SHIP := "res://scenes/world/EnemyShip.tscn"

# M11 — EnemyShipStats.tres now authors bow_armor_multiplier/bow_arc_degrees
# (Requirement 4), so a Vector3.FORWARD hit would take reduced damage and
# these hull-fraction thresholds would no longer land where they're tuned
# for. Vector3.RIGHT is squarely broadside (outside both the bow and stern
# arcs), keeping these tests exercising exactly the fraction they name.

var _root: Node3D
var _created_test_scene: Node3D = null


func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		_created_test_scene = scene
	_root = Node3D.new()
	_root.name = "VisualsRoot"
	add_child_autoqfree(_root)

func after_each():
	# This file's own current_scene, if it created one, must not outlive it —
	# a leaked one previously corrupted test_navigation_integration.gd's real
	# get_tree().change_scene_to_file() call (freed-lambda-capture crash).
	if is_instance_valid(_created_test_scene):
		if get_tree().current_scene == _created_test_scene:
			get_tree().current_scene = null
		_created_test_scene.queue_free()
	_created_test_scene = null


func _spawn() -> Node3D:
	var ship = load(ENEMY_SHIP).instantiate() as Node3D
	_root.add_child(ship)
	ship.global_position = Vector3.ZERO
	if ship is RigidBody3D:
		ship.freeze = true
	return ship


func _first_clean_albedo(visuals: Node) -> Color:
	var it: Dictionary = visuals._clean_albedo
	assert_false(it.is_empty(), "Precondition: at least one surface must have a cached clean color")
	return it.values()[0]


func test_a_healthy_hull_has_no_smoke_and_no_tint():
	var ship = _spawn()
	var visuals = ship.get_node("ShipModel")

	assert_false(visuals._smoke.emitting, "A full-health hull must not smoke")


func test_damage_below_the_threshold_starts_smoke():
	var ship = _spawn()
	var visuals = ship.get_node("ShipModel")
	var dmg = ship.get_node("ShipDamage")
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")

	dmg.apply_hit(dmg.get_pool_maximum("hull") * 0.6, round_shot, Vector3.RIGHT)

	assert_true(visuals._smoke.emitting,
		"Hull below the damaged threshold must start smoking")


func test_critical_damage_darkens_the_hull_and_repair_restores_it():
	var ship = _spawn()
	var visuals = ship.get_node("ShipModel")
	var dmg = ship.get_node("ShipDamage")
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")

	var clean := _first_clean_albedo(visuals)
	dmg.apply_hit(dmg.get_pool_maximum("hull") * 0.8, round_shot, Vector3.RIGHT)

	var mesh: MeshInstance3D = _find_mesh(visuals._model_instance)
	assert_not_null(mesh, "Precondition: the hull must have at least one mesh surface")
	var current: Color = mesh.get_surface_override_material(0).get_shader_parameter("albedo")
	assert_ne(current, clean, "Critical hull damage must actually darken the surface color")

	dmg.repair("hull", dmg.get_pool_maximum("hull"))
	var restored: Color = mesh.get_surface_override_material(0).get_shader_parameter("albedo")
	assert_eq(restored, clean, "Repairing back above the critical threshold must restore the clean color exactly")


func test_sinking_damage_lists_the_hull_and_heals_upright():
	# M10 Requirement 6 — the one remaining open item from docs/navalCombat.md
	# §7: a distinct near-destruction state below hull_critical_threshold,
	# reusing the same ShipDamage.pool_changed signal, no new mechanism.
	var ship = _spawn()
	var visuals = ship.get_node("ShipModel")
	var dmg = ship.get_node("ShipDamage")
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")

	dmg.apply_hit(dmg.get_pool_maximum("hull") * 0.6, round_shot, Vector3.RIGHT)
	assert_eq(visuals._model_instance.rotation.z, 0.0,
		"Merely damaged (above the sinking threshold) must not list")

	dmg.apply_hit(dmg.get_pool_maximum("hull") * 0.32, round_shot, Vector3.RIGHT)
	assert_ne(visuals._model_instance.rotation.z, 0.0,
		"Hull below the sinking threshold must visibly list")

	dmg.repair("hull", dmg.get_pool_maximum("hull"))
	assert_eq(visuals._model_instance.rotation.z, 0.0,
		"Repairing back above the sinking threshold must return the hull upright")


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.get_surface_override_material_count() > 0:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null

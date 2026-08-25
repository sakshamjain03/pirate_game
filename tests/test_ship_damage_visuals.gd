extends GutTest

# test_ship_damage_visuals.gd
# Slice 9b — visible hull damage (docs/navalCombat.md §7's one remaining open
# item: "a visible 'critical' state at low hull, then Sunk"). ShipDamage.pool_changed
# already fired on every hit; nothing listened to it for visuals until now. These
# tests pin the STATE the damage tint/smoke drive (emitting flag, shader param
# values) rather than how it renders, which cannot be checked headlessly.

const ENEMY_SHIP := "res://scenes/world/EnemyShip.tscn"

var _root: Node3D


func before_each():
	if not get_tree().current_scene:
		var scene = Node3D.new()
		scene.name = "TestScene"
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
	_root = Node3D.new()
	_root.name = "VisualsRoot"
	add_child_autoqfree(_root)


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

	dmg.apply_hit(dmg.get_pool_maximum("hull") * 0.6, round_shot, Vector3.FORWARD)

	assert_true(visuals._smoke.emitting,
		"Hull below the damaged threshold must start smoking")


func test_critical_damage_darkens_the_hull_and_repair_restores_it():
	var ship = _spawn()
	var visuals = ship.get_node("ShipModel")
	var dmg = ship.get_node("ShipDamage")
	var round_shot = preload("res://resources/combat/ammo/RoundShot.tres")

	var clean := _first_clean_albedo(visuals)
	dmg.apply_hit(dmg.get_pool_maximum("hull") * 0.8, round_shot, Vector3.FORWARD)

	var mesh: MeshInstance3D = _find_mesh(visuals._model_instance)
	assert_not_null(mesh, "Precondition: the hull must have at least one mesh surface")
	var current: Color = mesh.get_surface_override_material(0).get_shader_parameter("albedo")
	assert_ne(current, clean, "Critical hull damage must actually darken the surface color")

	dmg.repair("hull", dmg.get_pool_maximum("hull"))
	var restored: Color = mesh.get_surface_override_material(0).get_shader_parameter("albedo")
	assert_eq(restored, clean, "Repairing back above the critical threshold must restore the clean color exactly")


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.get_surface_override_material_count() > 0:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null

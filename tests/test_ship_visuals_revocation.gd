extends GutTest

## M17 Task 12/Requirement 8.3 — a refund revoking a currently-equipped
## cosmetic must fall back to default appearance live, mid-session, not
## just on the next save load (M16 Requirement 3.6 already covers that load
## path). Pins the STATE this drives (_equipped_cosmetics), not the render,
## matching test_ship_damage_visuals.gd's own established precedent for why
## that's the right thing to assert headlessly.

const ENEMY_SHIP := "res://scenes/world/EnemyShip.tscn"

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


func test_revoking_the_equipped_cosmetic_clears_it_and_rebuilds():
	var ship := _spawn()
	var visuals: Node = ship.get_node("ShipModel")
	var cosmetic := CosmeticCatalogue.get_cosmetic(&"hull_deep_ocean_blue")
	assert_not_null(cosmetic, "fixture assumes this M16 cosmetic is authored")

	visuals.apply_cosmetic("hull", cosmetic)
	assert_eq(visuals._equipped_cosmetics.get("hull"), cosmetic)

	visuals._on_entitlement_revoked(&"hull_deep_ocean_blue")

	assert_false(visuals._equipped_cosmetics.has("hull"),
		"the revoked slot must fall back to default, not keep the removed cosmetic")


func test_revoking_an_unrelated_id_leaves_the_equipped_cosmetic_untouched():
	var ship := _spawn()
	var visuals: Node = ship.get_node("ShipModel")
	var cosmetic := CosmeticCatalogue.get_cosmetic(&"hull_deep_ocean_blue")

	visuals.apply_cosmetic("hull", cosmetic)
	visuals._on_entitlement_revoked(&"some_other_cosmetic_id")

	assert_eq(visuals._equipped_cosmetics.get("hull"), cosmetic,
		"revoking an id that isn't equipped anywhere must not touch other slots")


func test_a_real_revocation_signal_reaches_ship_visuals():
	var ship := _spawn()
	var visuals: Node = ship.get_node("ShipModel")
	var cosmetic := CosmeticCatalogue.get_cosmetic(&"hull_deep_ocean_blue")
	visuals.apply_cosmetic("hull", cosmetic)

	EntitlementManager.entitlement_revoked.emit(&"hull_deep_ocean_blue")

	assert_false(visuals._equipped_cosmetics.has("hull"))

extends GutTest

# test_ship_stats_swap.gd — regression for the "120/50" enemy health bar:
# stats assigned to a ShipController before it enters the tree (EnemySpawner's
# path) or swapped at runtime (EncounterManager's strength rescale, ship
# upgrades) must keep every damage pool within, and proportional to, the new
# maximum.

const ENEMY_SHIP := preload("res://scenes/world/EnemyShip.tscn")

var _scene: Node3D = null


func before_each():
	_scene = Node3D.new()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func after_each():
	if is_instance_valid(_scene):
		if get_tree().current_scene == _scene:
			get_tree().current_scene = null
		_scene.queue_free()
	_scene = null


func _enemy_with(stats: ShipStats) -> ShipController:
	var ship := ENEMY_SHIP.instantiate() as ShipController
	var ai := ship.get_node("EnemyAI")
	ship.remove_child(ai)
	ai.free()
	ship.ship_stats = stats  # before add_child, exactly as EnemySpawner does
	_scene.add_child(ship)
	return ship


func test_stats_assigned_before_spawn_set_the_hull_to_the_new_maximum():
	var dinghy: ShipStats = load("res://resources/ships/Dinghy.tres").duplicate()
	var ship := _enemy_with(dinghy)
	var dmg: ShipDamage = ship.get_node("ShipDamage")
	assert_almost_eq(dmg.get_pool_maximum("hull"), dinghy.max_health, 0.01)
	assert_almost_eq(dmg.hull, dinghy.max_health, 0.01, "a fresh Dinghy must read 50/50, not 120/50")
	assert_true(dmg.crew <= dmg.get_pool_maximum("crew") + 0.01)
	assert_true(dmg.sails <= dmg.get_pool_maximum("sails") + 0.01)


func test_runtime_swap_keeps_the_damage_fraction():
	var base: ShipStats = load("res://resources/ships/Sloop.tres").duplicate()
	var ship := _enemy_with(base)
	var dmg: ShipDamage = ship.get_node("ShipDamage")
	dmg.hull = dmg.get_pool_maximum("hull") * 0.5
	var stronger: ShipStats = base.duplicate()
	stronger.max_health = base.max_health * 2.0
	ship.ship_stats = stronger
	assert_almost_eq(dmg.hull / dmg.get_pool_maximum("hull"), 0.5, 0.01, "half a hull stays half a hull")


func test_a_wreck_stays_a_wreck_through_a_swap():
	var base: ShipStats = load("res://resources/ships/Sloop.tres").duplicate()
	var ship := _enemy_with(base)
	var dmg: ShipDamage = ship.get_node("ShipDamage")
	dmg.mark_destroyed()
	ship.ship_stats = base.duplicate()
	assert_eq(dmg.hull, 0.0)
	assert_true(dmg.is_destroyed())

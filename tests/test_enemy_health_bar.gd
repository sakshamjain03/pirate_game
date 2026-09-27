extends GutTest

const EnemyHealthBarWidgetScene = preload("res://scenes/ui/EnemyHealthBarWidget.tscn")
const EnemyShipScene = preload("res://scenes/world/EnemyShip.tscn")


func test_enemy_health_bar_widget_is_visible_before_any_damage():
	# The old Label3D deliberately hid itself until the enemy had taken
	# damage; the replacement must show a full bar immediately once bound —
	# that gap ("opponent health bar isn't visible") was the reported bug.
	var ship: Node3D = EnemyShipScene.instantiate()
	add_child_autofree(ship)

	var widget = EnemyHealthBarWidgetScene.instantiate()
	add_child_autofree(widget)
	widget.bind(ship)

	assert_true(widget.visible)
	assert_gt(widget._bar.max_value, 0.0)
	assert_eq(widget._bar.max_value, ship.combat.current_health)


func test_enemy_health_bar_widget_tracks_health_changed():
	var ship: Node3D = EnemyShipScene.instantiate()
	add_child_autofree(ship)

	var widget = EnemyHealthBarWidgetScene.instantiate()
	add_child_autofree(widget)
	widget.bind(ship)

	var max_health: float = ship.combat.current_health
	ship.combat.health_changed.emit(max_health * 0.5, max_health)

	assert_almost_eq(widget._bar.max_value, max_health, 0.01)
	assert_string_contains(widget._value_label.text, str(int(max_health * 0.5)))


func test_enemy_health_bar_widget_hides_on_died():
	var ship: Node3D = EnemyShipScene.instantiate()
	add_child_autofree(ship)

	var widget = EnemyHealthBarWidgetScene.instantiate()
	add_child_autofree(widget)
	widget.bind(ship)

	ship.combat.died.emit()

	assert_false(widget.visible)


# ------------------------------------------------ Damage triangle (M25)
## The three pools have always had distinct consequences — chain wrecks sails so
## a target cannot flee, grape kills crew so boarding succeeds, round kills hull
## so you get loot instead of a prize — and the widget showed hull ONLY. Nobody
## could see the mechanic, so nobody would ever change ammo. These pin that the
## triangle is actually on screen.

func _bound_widget() -> Array:
	var ship: Node3D = EnemyShipScene.instantiate()
	add_child_autofree(ship)
	var widget = EnemyHealthBarWidgetScene.instantiate()
	add_child_autofree(widget)
	widget.bind(ship)
	return [ship, widget]


func test_widget_shows_sails_and_crew_not_just_hull():
	var pair := _bound_widget()
	var widget = pair[1]
	assert_not_null(widget._sails_bar, "Sails must be visible or chain shot is invisible")
	assert_not_null(widget._crew_bar, "Crew must be visible or grape shot is invisible")


func test_pool_bars_track_ship_damage():
	var pair := _bound_widget()
	var ship: Node3D = pair[0]
	var widget = pair[1]
	var dmg = ship.get_node("ShipDamage")

	var sails_max: float = dmg.get_pool_maximum("sails")
	dmg.pool_changed.emit("sails", sails_max * 0.5, sails_max)
	assert_almost_eq(widget._sails_bar.value, sails_max * 0.5, 0.01,
		"The rigging bar must follow ShipDamage.pool_changed")


func test_crippled_rigging_is_announced():
	# The payoff for firing chain shot: the player must be told it worked.
	var pair := _bound_widget()
	var ship: Node3D = pair[0]
	var widget = pair[1]
	var dmg = ship.get_node("ShipDamage")

	var sails_max: float = dmg.get_pool_maximum("sails")
	dmg.pool_changed.emit("sails", sails_max * 0.05, sails_max)
	assert_true(widget._status_label.visible, "Wrecked rigging must be called out")
	assert_string_contains(widget._status_label.text, "RIGGING")


func test_broken_crew_is_announced():
	# The payoff for firing grape shot.
	var pair := _bound_widget()
	var ship: Node3D = pair[0]
	var widget = pair[1]
	var dmg = ship.get_node("ShipDamage")

	var crew_max: float = dmg.get_pool_maximum("crew")
	dmg.pool_changed.emit("crew", crew_max * 0.05, crew_max)
	assert_true(widget._status_label.visible, "A broken crew must be called out")
	assert_string_contains(widget._status_label.text, "CREW")


func test_a_healthy_ship_announces_nothing():
	var pair := _bound_widget()
	var widget = pair[1]
	assert_false(widget._status_label.visible,
		"An undamaged ship must not claim to be crippled")


func test_pools_are_distinguishable_without_colour():
	# docs/18_ACCESSIBILITY.md — colour alone must never carry meaning. Each pool
	# bar is paired with a text tag in its own cell.
	var pair := _bound_widget()
	var widget = pair[1]
	for bar in [widget._sails_bar, widget._crew_bar]:
		var cell: Node = bar.get_parent()
		var has_label := false
		for child in cell.get_children():
			if child is Label and not str(child.text).is_empty():
				has_label = true
		assert_true(has_label,
			"Each pool bar needs a text tag — colour alone cannot distinguish them")

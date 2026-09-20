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

extends GutTest

const EnemyHealthBarScene = preload("res://scenes/ui/EnemyHealthBar.tscn")


func test_enemy_health_bar_uses_a_readable_segmented_percentage():
	var health_bar = EnemyHealthBarScene.instantiate()
	add_child(health_bar)
	health_bar._update_display(50.0, 100.0)

	assert_string_contains(health_bar.text, "50%")
	assert_string_contains(health_bar.text, EnemyHealthBar.FILLED_SEGMENT)
	assert_string_contains(health_bar.text, EnemyHealthBar.EMPTY_SEGMENT)

	health_bar.queue_free()

extends GutTest

# test_world_map_screen_layout.gd
# M13 Task 16.5 follow-up #2 (2026-09-20) — WorldMapScreen (the in-game map
# popup, not to be confused with test_world_map_layout.gd's 3D region-layout
# tests) had no layout test before this pass added mobile sizing to it. GUT
# only exercises the PC branch (see test_pirate_theme_builder_mobile_scaling
# .gd's header); the mobile branch is verified by real-device screenshot.

const WorldMapScreenScene = preload("res://scenes/ui/WorldMapScreen.tscn")

var _screen: WorldMapScreen


func after_each():
	get_tree().paused = false
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func _instantiate() -> void:
	_screen = WorldMapScreenScene.instantiate()
	add_child_autofree(_screen)
	_screen.show()


func test_panel_and_map_display_are_wired_and_sized_on_pc():
	_instantiate()
	assert_eq(_screen.panel.custom_minimum_size, Vector2(560, 640),
		"PC panel size must be untouched by the mobile pass")
	assert_eq(_screen.map_display.custom_minimum_size, Vector2(500, 500),
		"PC map display size must be untouched by the mobile pass")


func test_view_log_and_close_buttons_never_overlap():
	_instantiate()
	await wait_seconds(0.1)

	var log_rect := _screen.view_log_button.get_global_rect()
	var close_rect := _screen.close_button.get_global_rect()
	assert_false(log_rect.intersects(close_rect),
		"View Log (%s) and Close (%s) buttons must not overlap" % [log_rect, close_rect])

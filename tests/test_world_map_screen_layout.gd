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
	assert_eq(_screen.panel.custom_minimum_size, Vector2(560, 720),
		"PC panel size must be untouched by the mobile pass (grown to fit the InfoPanel)")
	assert_eq(_screen.map_display.custom_minimum_size, Vector2(500, 500),
		"PC map display size must be untouched by the mobile pass")


func test_view_log_and_close_buttons_never_overlap():
	_instantiate()
	await wait_seconds(0.1)

	var log_rect := _screen.view_log_button.get_global_rect()
	var close_rect := _screen.close_button.get_global_rect()
	assert_false(log_rect.intersects(close_rect),
		"View Log (%s) and Close (%s) buttons must not overlap" % [log_rect, close_rect])


func test_default_info_panel_prompts_for_a_tap():
	_instantiate()
	assert_true(_screen.info_panel.text.contains("Tap an island"),
		"Before any selection, the info panel should prompt the player to tap an island")


func test_tapping_a_discovered_island_selects_it_and_updates_the_info_panel():
	_instantiate()
	await wait_seconds(0.1)

	var island: Node = load("res://scripts/world/Island.gd").new()
	var data := IslandData.new()
	data.island_id = "test_isle"
	data.island_name = "Test Isle"
	data.discovered = true
	data.world_position = Vector2(100, 0)
	data.codex_summary = "A test dossier."
	island.island_data = data
	add_child_autofree(island)
	await wait_process_frames(1)

	var display_radius: float = max(0.0, min(_screen.map_display.size.x, _screen.map_display.size.y) * 0.5 - 16.0)
	var marker_pos: Vector2 = _screen._world_to_local(data.world_position, display_radius)

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = marker_pos
	_screen._on_map_display_gui_input(event)

	assert_eq(_screen._selected_island, data, "Tapping the marker must select its IslandData")
	assert_true(_screen.info_panel.text.contains("Test Isle"), "Info panel must show the selected island's name")
	assert_true(_screen.info_panel.text.contains("A test dossier."), "...and its codex summary")


func test_tapping_open_water_deselects() -> void:
	_instantiate()
	await wait_seconds(0.1)

	var island: Node = load("res://scripts/world/Island.gd").new()
	var data := IslandData.new()
	data.island_id = "test_isle"
	data.island_name = "Test Isle"
	data.discovered = true
	data.world_position = Vector2(100, 0)
	island.island_data = data
	add_child_autofree(island)
	await wait_process_frames(1)

	var display_radius: float = max(0.0, min(_screen.map_display.size.x, _screen.map_display.size.y) * 0.5 - 16.0)
	var marker_pos: Vector2 = _screen._world_to_local(data.world_position, display_radius)

	var select_event := InputEventMouseButton.new()
	select_event.button_index = MOUSE_BUTTON_LEFT
	select_event.pressed = true
	select_event.position = marker_pos
	_screen._on_map_display_gui_input(select_event)
	assert_eq(_screen._selected_island, data, "Precondition: the island is selected")

	var miss_event := InputEventMouseButton.new()
	miss_event.button_index = MOUSE_BUTTON_LEFT
	miss_event.pressed = true
	miss_event.position = marker_pos + Vector2(200, 200)
	_screen._on_map_display_gui_input(miss_event)

	assert_null(_screen._selected_island, "Tapping open water must deselect")
	assert_true(_screen.info_panel.text.contains("Tap an island"), "...and reset the info panel")

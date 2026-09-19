extends GutTest

# test_pause_menu_layout.gd
# M13 Task 16.5 follow-up #2 (2026-09-20) — PauseMenu had no layout test at
# all before this pass added mobile sizing to it. GUT only exercises the PC
# branch (see test_pirate_theme_builder_mobile_scaling.gd's header) so this
# checks the PC-authored geometry stays intact and sane; the mobile branch is
# verified by real-device screenshot.

const PauseMenuScene = preload("res://scenes/ui/PauseMenu.tscn")

var _menu: PauseMenu


func after_each():
	get_tree().paused = false
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


func _instantiate() -> void:
	_menu = PauseMenuScene.instantiate()
	add_child_autofree(_menu)


func test_buttons_meet_the_minimum_touch_target_on_pc():
	_instantiate()
	for btn in [_menu.resume_button, _menu.settings_button, _menu.quit_button]:
		var size: Vector2 = btn.custom_minimum_size
		assert_true(size.x >= 48.0 and size.y >= 48.0,
			"PauseMenu button '%s' (%s) must meet the 48x48 minimum touch target" % [btn.text, size])


func test_buttons_never_overlap_each_other():
	_instantiate()
	_menu.show()
	await wait_seconds(0.1)

	var rects := [
		_menu.resume_button.get_global_rect(),
		_menu.settings_button.get_global_rect(),
		_menu.quit_button.get_global_rect(),
	]
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			assert_false(rects[i].intersects(rects[j]),
				"PauseMenu buttons %d and %d must not overlap (%s vs %s)" % [i, j, rects[i], rects[j]])

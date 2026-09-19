extends GutTest

# test_island_menu_layout.gd
# M13 Task 16.5 follow-up #2 (2026-09-20) — IslandMenu had no layout test
# before this pass. It's the largest screen touched (dozens of dynamically
# built building/ship/captain/fleet/research/trade rows), so mobile sizing
# there uses PirateThemeBuilder.apply_mobile_control_scaling() to sweep each
# freshly-rebuilt container rather than touching every Button.new()/
# Label.new() call site (that helper's PC no-op guarantee is covered
# generically by test_pirate_theme_builder_mobile_scaling.gd — reaching a
# real dynamic row here would need a full Island stub, out of scope for a
# sizing pass). This just confirms the static chrome (Panel/CloseButton) is
# wired and its PC-authored geometry untouched. GUT only exercises the PC
# branch; the mobile branch is verified by real-device screenshot.

const IslandMenuScene = preload("res://scenes/ui/IslandMenu.tscn")

var _menu: IslandMenu


func after_each():
	get_tree().paused = false
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


func _instantiate() -> void:
	_menu = IslandMenuScene.instantiate()
	add_child_autofree(_menu)


func test_panel_and_close_button_are_wired_and_sized_on_pc():
	_instantiate()
	assert_eq(_menu.panel.custom_minimum_size, Vector2(480, 320),
		"PC panel size must be untouched by the mobile pass")
	var size: Vector2 = _menu.close_button.custom_minimum_size
	assert_true(size.x >= 48.0 and size.y >= 48.0,
		"CloseButton (%s) must meet the 48x48 minimum touch target" % size)


func test_colonize_button_is_created_and_untouched_on_pc():
	_instantiate()
	assert_not_null(_menu.colonize_btn, "Colonize button must be created in _ready()")
	assert_eq(_menu.colonize_btn.custom_minimum_size, Vector2(150, 48),
		"PC colonize button size must be untouched by the mobile pass")

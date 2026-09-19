extends GutTest

# test_captains_log_layout.gd
# M13 Task 16.5 follow-up #2 (2026-09-20) — CaptainsLog had no layout test
# before this pass added mobile sizing to it (separate from the existing
# behavior-focused test_captains_log.gd, which never touches layout/sizing).
# Its dynamically-rebuilt objective list (_refresh()) is swept with
# PirateThemeBuilder.apply_mobile_control_scaling() the same way
# WhatsNewScreen's is — that helper's PC no-op guarantee is covered
# generically by test_pirate_theme_builder_mobile_scaling.gd. GUT only
# exercises the PC branch; the mobile branch is verified by real-device
# screenshot.

const CaptainsLogScene = preload("res://scenes/ui/CaptainsLog.tscn")

var _log: CaptainsLog


func after_each():
	get_tree().paused = false
	if is_instance_valid(_log):
		_log.queue_free()
	_log = null


func test_panel_and_scroll_container_are_wired_and_sized_on_pc():
	_log = CaptainsLogScene.instantiate()
	add_child_autofree(_log)
	assert_eq(_log.panel.custom_minimum_size, Vector2(480, 560),
		"PC panel size must be untouched by the mobile pass")
	assert_eq(_log.scroll_container.custom_minimum_size, Vector2(0, 420),
		"PC scroll container size must be untouched by the mobile pass")

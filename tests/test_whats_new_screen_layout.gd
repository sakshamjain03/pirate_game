extends GutTest

# test_whats_new_screen_layout.gd
# M13 Task 16.5 follow-up #2 (2026-09-20) — WhatsNewScreen had no layout test
# before this pass added mobile sizing to it. Its dynamically-rebuilt entry
# list (_refresh()) is swept with PirateThemeBuilder.apply_mobile_control_
# scaling() the same way CaptainsLog's is — that helper's PC no-op guarantee
# is covered generically by test_pirate_theme_builder_mobile_scaling.gd. GUT
# only exercises the PC branch; the mobile branch is verified by real-device
# screenshot.

const WhatsNewScreenScene = preload("res://scenes/ui/WhatsNewScreen.tscn")

var _screen: WhatsNewScreen


func after_each():
	get_tree().paused = false
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func _instantiate() -> void:
	_screen = WhatsNewScreenScene.instantiate()
	add_child_autofree(_screen)


func test_panel_and_scroll_container_are_wired_and_sized_on_pc():
	_instantiate()
	assert_eq(_screen.panel.custom_minimum_size, Vector2(480, 560),
		"PC panel size must be untouched by the mobile pass")
	assert_eq(_screen.scroll_container.custom_minimum_size, Vector2(0, 420),
		"PC scroll container size must be untouched by the mobile pass")


func test_open_populates_content_without_error():
	_instantiate()
	_screen.open()
	get_tree().paused = false
	await wait_seconds(0.1)
	assert_gt(_screen.content.get_child_count(), 0,
		"Opening What's New must populate at least one entry (or the 'nothing to report' body label)")

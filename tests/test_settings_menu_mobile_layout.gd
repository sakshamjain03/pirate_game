extends GutTest

# test_settings_menu_mobile_layout.gd
# M13 Task 16.5 follow-up #2 (2026-09-20) — SettingsMenu hides Fullscreen/
# Resolution/VSync (PC-only display concepts with no phone equivalent) on
# mobile, then enlarges everything that remains. Separate from the existing
# behavior-focused test_settings_menu.gd, which never touches layout/sizing.
#
# GUT runs on a desktop binary, so it can only ever exercise the PC branch
# (see test_pirate_theme_builder_mobile_scaling.gd's header for why). What
# that lets us actually prove here: the PC-only rows must stay visible and
# untouched on PC — i.e. the mobile-hiding branch must never fire when it
# shouldn't. Whether they actually get hidden on a real phone is verified by
# real-device screenshot, not by this suite.

const SettingsMenuScene = preload("res://scenes/ui/SettingsMenu.tscn")

var _menu: SettingsMenu


func after_each():
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


func _instantiate() -> void:
	_menu = SettingsMenuScene.instantiate()
	add_child_autofree(_menu)


func _instantiate_mobile_layout() -> void:
	_menu = SettingsMenuScene.instantiate()
	_menu.force_mobile_layout_for_test = true
	add_child_autofree(_menu)


func test_pc_only_display_controls_stay_visible_and_default_sized_on_pc():
	_instantiate()

	assert_true(_menu.fullscreen_check.visible, "Fullscreen must stay visible on PC")
	assert_true(_menu.resolution_option.visible, "Resolution must stay visible on PC")
	assert_true(_menu.vsync_check.visible, "VSync must stay visible on PC")

	var pc_default := Vector2(44, 44)
	# M22 Phase 3: PirateThemeBuilder.apply_button_juice() adds a small width
	# buffer to every Button-derived control (CheckButton included) to work
	# around a confirmed Godot 4.3 engine bug where a button/toggle sized to
	# its EXACT natural minimum silently drops its own last character under
	# this project's canvas_items stretch mode (godotengine/godot#97417,
	# fixed for 4.4, not backported to our pinned 4.3.stable — see
	# PirateThemeBuilder.apply_button_juice's own header). fullscreen_check
	# IS a CheckButton (a Button subtype), so it now carries that buffer on
	# PC too — HSlider is NOT a Button subtype and stays genuinely untouched.
	assert_eq(_menu.fullscreen_check.custom_minimum_size, Vector2(64, 44),
		"PC's Fullscreen control height must be untouched by the mobile pass; width now carries Phase 3's text-clip-bug-workaround buffer")
	assert_eq(_menu.master_slider.custom_minimum_size, pc_default,
		"PC's slider sizes must be untouched by the mobile pass")


func test_mobile_layout_uses_a_framed_scrollable_settings_surface():
	_instantiate_mobile_layout()

	assert_not_null(_menu.root_control.get_node_or_null("SettingsCard"),
		"Phone Settings needs a framed surface rather than edge-to-edge tabs.")
	assert_false(_menu.fullscreen_check.visible)
	assert_false(_menu.resolution_option.visible)
	assert_false(_menu.vsync_check.visible)
	assert_eq(_menu.grid_container.columns, 1,
		"Phone settings must use readable vertical rows instead of desktop columns.")
	assert_not_null(_menu.general_tab.get_node_or_null("GeneralScrollContainer"))
	assert_eq(_menu.grid_container.get_parent().name, "GeneralScrollContainer")
	assert_true(_menu.master_slider.custom_minimum_size.y >= 64.0)
	assert_true(_menu.back_button.custom_minimum_size.y >= 62.0)

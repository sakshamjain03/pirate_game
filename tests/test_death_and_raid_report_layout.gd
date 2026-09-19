extends GutTest

# test_death_and_raid_report_layout.gd
# M13 Task 16.5 follow-up #2 (2026-09-20) — DeathScreen and RaidReportScreen
# share near-identical layout/sizes (500x300 panel, 200x50 button, 42/18/24
# font sizes) and neither had a layout test before this pass added mobile
# sizing to both. One shared file rather than two near-duplicates. GUT only
# exercises the PC branch (see test_pirate_theme_builder_mobile_scaling.gd's
# header); the mobile branch is verified by real-device screenshot.

const DeathScreenScene = preload("res://scenes/ui/DeathScreen.tscn")
const RaidReportScreenScene = preload("res://scenes/ui/RaidReportScreen.tscn")


func test_death_screen_panel_and_button_are_wired_and_sized_on_pc():
	var screen: DeathScreen = DeathScreenScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.panel.custom_minimum_size, Vector2(500, 300),
		"PC panel size must be untouched by the mobile pass")
	var size: Vector2 = screen.respawn_button.custom_minimum_size
	assert_true(size.x >= 48.0 and size.y >= 48.0,
		"RespawnButton (%s) must meet the 48x48 minimum touch target" % size)


func test_raid_report_screen_panel_and_button_are_wired_and_sized_on_pc():
	var screen: RaidReportScreen = RaidReportScreenScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.panel.custom_minimum_size, Vector2(500, 300),
		"PC panel size must be untouched by the mobile pass")
	var size: Vector2 = screen.dismiss_button.custom_minimum_size
	assert_true(size.x >= 48.0 and size.y >= 48.0,
		"DismissButton (%s) must meet the 48x48 minimum touch target" % size)

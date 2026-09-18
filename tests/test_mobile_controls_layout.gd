extends GutTest

# test_mobile_controls_layout.gd
# M13 device-verification regression: on a real device (Galaxy A35, 2340x1080
# landscape), WorldHUD's CannonsContainer (bottom-center) and MobileControls'
# Actions cluster (BtnDock/BtnPause/BtnCaptainAbility/BtnSpecialBroadside,
# also bottom-center) turned out to occupy the exact same screen rect —
# CannonsContainer is declared later in WorldHUD.tscn's child order, so it
# draws on top and completely buries the Actions buttons, making dock/pause/
# ability/broadside unreachable by touch. GUT never caught this because no
# prior test checked MobileControls against WorldHUD's own content, only
# WorldHUD's panels against each other (test_world_hud_layout.gd). Moving
# Actions into the horizontal gap right of the movement d-pad fixed that, but
# a real-device screenshot then caught a second, smaller overlap against
# HealthBarContainer (its right edge at x=352 clipped into Actions' first
# column) — both are now checked here.

const WorldHUDScene = preload("res://scenes/ui/WorldHUD.tscn")

var _viewport: SubViewport
var _hud

func after_each():
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null
	_hud = null

func _instantiate_hud_at_size(size: Vector2i):
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_hud = WorldHUDScene.instantiate()
	_viewport.add_child(_hud)

# Property: no MobileControls button (Movement d-pad, Combat, Actions) ever
# overlaps the cannon status panels or the health bar, at the real device's
# own resolution plus one other aspect ratio. Extended 2026-09-19 (M13 Task
# 16.5 follow-up) to cover Movement/Combat too, not just Actions — all three
# clusters were enlarged for real touch-target sizing in that pass, and a
# bigger d-pad reaching further toward HealthBarContainer's bottom-left
# corner is exactly the kind of regression this property exists to catch.
func test_property_mobile_buttons_never_overlap_hud_panels():
	var sizes: Array[Vector2i] = [Vector2i(2340, 1080), Vector2i(1920, 1080)]
	for size in sizes:
		_instantiate_hud_at_size(size)
		await wait_seconds(0.1)

		var mobile_controls = _hud.get_node("MobileControls")
		var blockers := {
			"CannonsContainer": _hud.get_node("CannonsContainer").get_global_rect(),
			"HealthBarContainer": _hud.get_node("HealthBarContainer").get_global_rect(),
		}
		var mobile_buttons := {
			"BtnForward": mobile_controls.get_node("Movement/BtnForward"),
			"BtnLeft": mobile_controls.get_node("Movement/BtnLeft"),
			"BtnRight": mobile_controls.get_node("Movement/BtnRight"),
			"BtnBackward": mobile_controls.get_node("Movement/BtnBackward"),
			"BtnFirePort": mobile_controls.get_node("Combat/BtnFirePort"),
			"BtnFireStar": mobile_controls.get_node("Combat/BtnFireStar"),
			"BtnDock": mobile_controls.get_node("Actions/BtnDock"),
			"BtnPause": mobile_controls.get_node("Actions/BtnPause"),
			"BtnCaptainAbility": mobile_controls.get_node("Actions/BtnCaptainAbility"),
			"BtnSpecialBroadside": mobile_controls.get_node("Actions/BtnSpecialBroadside"),
		}

		for blocker_name in blockers:
			var blocker_rect: Rect2 = blockers[blocker_name]
			for btn_name in mobile_buttons:
				var btn_rect: Rect2 = mobile_buttons[btn_name].get_global_rect()
				assert_false(blocker_rect.intersects(btn_rect),
					"%s (%s) must not overlap %s (%s) at viewport size %s" %
						[blocker_name, blocker_rect, btn_name, btn_rect, size])

		_viewport.queue_free()
		_viewport = null
		_hud = null

# Property: every MobileControls button meets the same 48x48 minimum touch
# target docs/18_ACCESSIBILITY.md §6 and test_wardrobe_layout.gd already
# enforce elsewhere — added 2026-09-19 (M13 Task 16.5 follow-up) alongside
# the resize that fixed BtnDock/BtnPause/BtnCaptainAbility/BtnSpecialBroadside
# (95x60, 21dp) and the d-pad/fire buttons (80x80-100x80, 21-28dp) all
# measuring below this bar on the real device that prompted the audit.
func test_property_every_mobile_control_button_meets_the_minimum_touch_target():
	_instantiate_hud_at_size(Vector2i(2340, 1080))
	await wait_seconds(0.1)

	var mobile_controls = _hud.get_node("MobileControls")
	var button_paths := [
		"Movement/BtnForward", "Movement/BtnLeft", "Movement/BtnRight", "Movement/BtnBackward",
		"Combat/BtnFirePort", "Combat/BtnFireStar",
		"Actions/BtnDock", "Actions/BtnPause", "Actions/BtnCaptainAbility", "Actions/BtnSpecialBroadside",
	]
	for path in button_paths:
		var btn: Button = mobile_controls.get_node(path)
		var rect := btn.get_global_rect()
		assert_true(rect.size.x >= 48.0 and rect.size.y >= 48.0,
			"MobileControls/%s (%s) must meet the 48x48 minimum touch target" % [path, rect.size])

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

# Property: the mobile Actions buttons never overlap the cannon status
# panels, at the real device's own resolution plus one other aspect ratio.
func test_property_actions_buttons_never_overlap_cannons_container():
	var sizes: Array[Vector2i] = [Vector2i(2340, 1080), Vector2i(1920, 1080)]
	for size in sizes:
		_instantiate_hud_at_size(size)
		await wait_seconds(0.1)

		var mobile_controls = _hud.get_node("MobileControls")
		var blockers := {
			"CannonsContainer": _hud.get_node("CannonsContainer").get_global_rect(),
			"HealthBarContainer": _hud.get_node("HealthBarContainer").get_global_rect(),
		}
		var actions_buttons := {
			"BtnDock": mobile_controls.get_node("Actions/BtnDock"),
			"BtnPause": mobile_controls.get_node("Actions/BtnPause"),
			"BtnCaptainAbility": mobile_controls.get_node("Actions/BtnCaptainAbility"),
			"BtnSpecialBroadside": mobile_controls.get_node("Actions/BtnSpecialBroadside"),
		}

		for blocker_name in blockers:
			var blocker_rect: Rect2 = blockers[blocker_name]
			for btn_name in actions_buttons:
				var btn_rect: Rect2 = actions_buttons[btn_name].get_global_rect()
				assert_false(blocker_rect.intersects(btn_rect),
					"%s (%s) must not overlap %s (%s) at viewport size %s" %
						[blocker_name, blocker_rect, btn_name, btn_rect, size])

		_viewport.queue_free()
		_viewport = null
		_hud = null

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


func _instantiate_mobile_hud_at_size(size: Vector2i):
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_hud = WorldHUDScene.instantiate()
	_hud.force_mobile_utility_menu = true
	_hud.get_node("MobileControls").force_mobile_layout_for_test = true
	_viewport.add_child(_hud)

# Property: no MobileControls button (Movement d-pad, Combat, Actions) ever
# overlaps the cannon status panels or the health bar, at the real device's
# own resolution plus one other aspect ratio. Extended 2026-09-19 (M13 Task
# 16.5 follow-up) to cover Movement/Combat too, not just Actions — all three
# clusters were enlarged for real touch-target sizing in that pass, and a
# bigger d-pad reaching further toward HealthBarContainer's bottom-left
# corner is exactly the kind of regression this property exists to catch.
func test_property_mobile_buttons_never_overlap_hud_panels():
	var sizes: Array[Vector2i] = [Vector2i(2340, 1080), Vector2i(1920, 1080), Vector2i(750, 1334), Vector2i(1024, 768)]
	for size in sizes:
		_instantiate_mobile_hud_at_size(size)
		await wait_seconds(0.1)

		var mobile_controls = _hud.get_node("MobileControls")
		# The real mobile HUD removes cannon cooldown panels and places player
		# hull health at the top. The test forces that same branch on desktop CI.
		_hud.cannons_container.hide()
		_hud._apply_mobile_safe_area()
		var blockers := {
			"HealthBarContainer": _hud.get_node("HealthBarContainer").get_global_rect(),
			# D-something: BtnPause used to sit at a hardcoded "150 * this
			# script's own mobile_scale()" offset, unrelated to the fixed
			# hud_scale=1.45 WorldHUD actually positions this panel with — the
			# two drifted apart on real devices, leaving only BtnPause's bottom
			# sliver clickable under the panel. Guards that regression.
			"TopRightPanel": _hud.top_right_panel.get_global_rect(),
		}
		var mobile_buttons := {
			"BtnLeft": mobile_controls.get_node("Movement/BtnLeft"),
			"BtnRight": mobile_controls.get_node("Movement/BtnRight"),
			"SailControl": mobile_controls.get_node("Movement/SailControl"),
			"BtnPause": mobile_controls.get_node("BtnPause"),
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
	_instantiate_mobile_hud_at_size(Vector2i(2340, 1080))
	await wait_seconds(0.1)

	var mobile_controls = _hud.get_node("MobileControls")
	var button_paths := [
		"Movement/BtnLeft", "Movement/BtnRight", "Movement/SailControl",
		"BtnPause", "Actions/BtnCaptainAbility", "Actions/BtnSpecialBroadside",
	]
	for path in button_paths:
		var btn: Button = mobile_controls.get_node(path)
		var rect := btn.get_global_rect()
		assert_true(rect.size.x >= 72.0 and rect.size.y >= 72.0,
			"MobileControls/%s (%s) must meet the 72x72 phone touch target" % [path, rect.size])


# Property: each bottom cluster sits just above the safe-area's true bottom
# edge — never past it (would clip into the gesture-nav bar) and never with
# excessive unused slack below it either. Movement/Combat/Actions previously
# used three independently-hardcoded offsets from safe.end.y (680/580/420)
# that only "happened" not to overlap; Movement in particular left ~300px of
# unscaled dead space below it instead of sitting near the reachable bottom
# edge. _apply_mobile_layout() now derives each cluster's placement from its
# own measured content height plus one shared gap constant instead.
func test_property_mobile_clusters_sit_just_above_the_safe_area_bottom():
	var sizes: Array[Vector2i] = [Vector2i(2340, 1080), Vector2i(1920, 1080), Vector2i(750, 1334), Vector2i(1024, 768)]
	for size in sizes:
		_instantiate_mobile_hud_at_size(size)
		await wait_seconds(0.1)

		var mobile_controls = _hud.get_node("MobileControls")
		var safe: Rect2 = MobileLayoutManager.safe_area(_hud.get_viewport())
		var scale: float = maxf(0.55, MobileLayoutManager.mobile_scale(_hud.get_viewport()))
		var max_slack: float = (mobile_controls._CLUSTER_EDGE_GAP + 40.0) * scale

		# The cluster Control's own .size is an authored container rect left
		# over from the old anchor-based scene layout, not the real bounding
		# box of its (individually-positioned) children — the actual rendered
		# bottom edge is the cluster's placed position plus its measured
		# visible content height, which is exactly what _apply_mobile_layout()
		# itself derives placement from.
		for cluster_name in ["Movement", "Combat", "Actions"]:
			var cluster: Control = mobile_controls.get_node(cluster_name)
			var rendered_bottom: float = cluster.position.y + mobile_controls._measured_bottom(cluster) * scale
			assert_true(rendered_bottom <= safe.end.y + 0.5,
				"%s (rendered bottom %s) must not clip past the safe-area bottom (%s) at viewport size %s" %
					[cluster_name, rendered_bottom, safe.end.y, size])
			# Combat is deliberately stacked above Actions (and its fire-port/
			# starboard buttons are hidden by default), not anchored to
			# safe.end.y directly, so "no excess slack below the safe edge"
			# only applies to the two clusters actually anchored to it.
			if cluster_name != "Combat":
				assert_true(rendered_bottom >= safe.end.y - max_slack,
					"%s (rendered bottom %s) should sit close to the reachable bottom edge (%s), not float with excess slack, at viewport size %s" %
						[cluster_name, rendered_bottom, safe.end.y, size])

		_viewport.queue_free()
		_viewport = null
		_hud = null


# Property: the "Next Production" economy label never overlaps TopBar or
# TopRightPanel on a phone-width viewport. It kept its desktop-authored
# PRESET_CENTER_TOP anchor + fixed "+20" offset on mobile too — on a narrow
# phone screen, "screen-center" lands under TopRightPanel's much wider
# (scaled) footprint, hiding all but a sliver of the text behind it
# (device-test feedback 2026-09-20).
func test_property_economy_label_never_overlaps_top_clusters():
	var sizes: Array[Vector2i] = [Vector2i(900, 1600), Vector2i(2340, 1080), Vector2i(750, 1334)]
	for size in sizes:
		_instantiate_hud_at_size(size)
		await wait_seconds(0.3)

		_hud._apply_mobile_safe_area()
		var economy_rect: Rect2 = _hud._economy_label.get_global_rect()
		var top_bar_rect: Rect2 = _hud.get_node("%TopBar").get_global_rect()
		var panel_rect: Rect2 = _hud.top_right_panel.get_global_rect()

		assert_false(top_bar_rect.intersects(economy_rect),
			"TopBar (%s) must not overlap the economy label (%s) at viewport size %s" %
				[top_bar_rect, economy_rect, size])
		assert_false(panel_rect.intersects(economy_rect),
			"TopRightPanel (%s) must not overlap the economy label (%s) at viewport size %s" %
				[panel_rect, economy_rect, size])

		_viewport.queue_free()
		_viewport = null
		_hud = null


func test_mobile_hud_keeps_only_persistent_controls_and_one_context_action():
	_instantiate_mobile_hud_at_size(Vector2i(2340, 1080))
	await wait_seconds(0.1)

	var mobile_controls = _hud.get_node("MobileControls")
	assert_true(mobile_controls.visible)
	assert_null(mobile_controls.get_node_or_null("Movement/BtnSailUp"))
	assert_null(mobile_controls.get_node_or_null("Movement/BtnSailDown"))
	assert_not_null(mobile_controls.get_node_or_null("Movement/SailControl"),
		"Phone sailing must use one sail-state control, not separate up/down buttons.")
	assert_false(mobile_controls.get_node("Actions/BtnDock").visible)
	assert_false(mobile_controls.get_node("Actions/BtnSetSail").visible)
	assert_false(mobile_controls.get_node("Actions/BtnAnchor").visible)
	assert_false(mobile_controls.get_node("Combat/BtnFirePort").visible)
	assert_false(mobile_controls.get_node("Combat/BtnFireStar").visible)

	var context_action: Button = mobile_controls.get_node("Actions/ContextAction")
	mobile_controls.set_dock_available(true)
	assert_true(context_action.visible)
	assert_eq(context_action.text, "Dock")
	mobile_controls.set_board_available(true)
	assert_eq(context_action.text, "Board Enemy",
		"Boarding must take priority over docking when both are available.")
	mobile_controls.set_board_available(false)
	assert_eq(context_action.text, "Dock")

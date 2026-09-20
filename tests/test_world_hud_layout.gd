extends GutTest

# test_world_hud_layout.gd
# M9 Requirement 1 — D36 regression: the notoriety/next-escalation label must
# never overlap the resource bar, at any viewport size, once ResourceBar's
# actual rendered height (driven by real content, not a hardcoded constant)
# is accounted for. Also covers the Captain's Log button, stacked below the
# notoriety label in the same TopRightPanel — a first version of this fix
# cleared the resource-bar/notoriety-label overlap but silently introduced a
# NEW one against the Log button's own still-hardcoded offset, only caught by
# a real headful CaptureHarness screenshot, not this test's first draft.
# Checking all three pairwise is what would have caught that the first time.

const WorldHUDScene = preload("res://scenes/ui/WorldHUD.tscn")

var _viewport: SubViewport
var _hud

func after_each():
	PirateThemeBuilder.force_mobile_scaling_for_test = false
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

func _populate_multi_digit_resources() -> void:
	# D36 specifically only reproduced once real (multi-digit) resource
	# values grew ResourceBar taller than its authored rect — a fresh "0"
	# state never overlapped.
	_hud.gold_label.text = "123456 / 999999"
	_hud.wood_label.text = "54321 / 99999"
	_hud.iron_label.text = "8888 / 9999"
	_hud.rum_label.text = "7777 / 9999"

# Property 1: the notoriety/escalation label never overlaps the resource bar,
# at at least two different viewport sizes/aspect ratios (Requirement 1 AC3).
func test_property_1_notoriety_label_never_overlaps_resource_bar():
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(750, 1334)]
	for size in sizes:
		_instantiate_hud_at_size(size)
		await wait_seconds(0.1)

		_populate_multi_digit_resources()
		_hud._on_notoriety_changed(1234.5)
		await wait_seconds(0.1)

		var resource_rect: Rect2 = _hud.resource_bar.get_global_rect()
		var notoriety_rect: Rect2 = _hud.notoriety_label.get_global_rect()
		var log_rect: Rect2 = _hud.captains_log_button.get_global_rect()

		assert_false(resource_rect.intersects(notoriety_rect),
			"ResourceBar (%s) and notoriety label (%s) must not overlap at viewport size %s" %
				[resource_rect, notoriety_rect, size])
		assert_false(notoriety_rect.intersects(log_rect),
			"Notoriety label (%s) and the Log button (%s) must not overlap at viewport size %s" %
				[notoriety_rect, log_rect, size])
		assert_false(resource_rect.intersects(log_rect),
			"ResourceBar (%s) and the Log button (%s) must not overlap at viewport size %s" %
				[resource_rect, log_rect, size])

		_viewport.queue_free()
		_viewport = null
		_hud = null


# Property 2: on a phone build, the speed/sail TopBar and the hull
# HealthBarContainer below it must never overlap, at multiple viewport sizes.
# _apply_mobile_safe_area() previously positioned HealthBarContainer at a
# hardcoded offset independent of TopBar's own scaled, measured height — the
# same "two independently hardcoded pixel offsets drift apart" failure mode
# already fixed once for the notoriety label/resource bar pair above.
func test_property_2_mobile_topbar_and_health_bar_never_overlap():
	var sizes: Array[Vector2i] = [Vector2i(750, 1334), Vector2i(1080, 2340)]
	for size in sizes:
		_instantiate_hud_at_size(size)
		await wait_seconds(0.1)

		_hud._apply_mobile_safe_area()
		await wait_seconds(0.1)

		var top_bar_rect: Rect2 = _hud.get_node("%TopBar").get_global_rect()
		var health_rect: Rect2 = _hud.health_container.get_global_rect()

		assert_false(top_bar_rect.intersects(health_rect),
			"TopBar (%s) and HealthBarContainer (%s) must not overlap at viewport size %s" %
				[top_bar_rect, health_rect, size])

		_viewport.queue_free()
		_viewport = null
		_hud = null


# The notoriety chip must shrink to fit its own text rather than stretching
# across the full width of TopRightPanel — a full-width tinted panel behind a
# short "Notoriety: 0.0" readout rendered as an oversized, mostly-empty bar.
func test_notoriety_chip_shrinks_to_content_width():
	_instantiate_hud_at_size(Vector2i(1920, 1080))
	await wait_seconds(0.1)

	_populate_multi_digit_resources()
	_hud._on_notoriety_changed(0.0)
	await wait_seconds(0.1)

	var chip: Control = _hud.notoriety_label.get_parent()
	assert_true(chip.size.x < _hud.resource_bar.size.x * 0.6,
		"Notoriety chip (%s wide) should hug its text, not stretch to ResourceBar's width (%s)" %
			[chip.size.x, _hud.resource_bar.size.x])


func test_mobile_utility_controls_are_collapsed_behind_one_menu_button():
	_instantiate_hud_at_size(Vector2i(750, 1334))
	await wait_seconds(0.1)

	# _mobile_utility_button_size() now sources its multiplier from
	# PirateThemeBuilder.control_scale() (phone/tablet-aware) rather than a
	# bare constant, so exercising the "touch-friendly mobile scale" this
	# test checks for requires forcing PirateThemeBuilder's own mobile
	# detection too, not just WorldHUD's force_mobile_utility_menu seam —
	# on a real phone build both are driven by the same OS feature check and
	# never diverge.
	PirateThemeBuilder.force_mobile_scaling_for_test = true
	_hud.force_mobile_utility_menu = true
	await _hud._rebuild_utility_controls()
	await wait_seconds(0.1)

	assert_not_null(_hud.mobile_utility_menu_button)
	assert_eq(_hud.mobile_utility_menu_button.custom_minimum_size, Vector2(180, 78),
		"The collapsed mobile menu must use the project's touch-friendly mobile scale.")
	assert_false(_hud.mobile_utility_drawer.visible,
		"The infrequent utility destinations must not permanently obscure the mobile world view.")
	assert_null(_hud.captains_log_button)
	assert_null(_hud.world_map_button)
	assert_null(_hud.codex_button)
	assert_null(_hud.whats_new_button)
	assert_null(_hud.wardrobe_button)

	_hud.mobile_utility_menu_button.emit_signal("pressed")
	assert_true(_hud.mobile_utility_drawer.visible)
	assert_eq(_hud.mobile_utility_drawer.get_node("Items").get_child_count(), 5,
		"The mobile drawer must retain every destination that desktop exposes directly.")
	for item in _hud.mobile_utility_drawer.get_node("Items").get_children():
		assert_eq(item.custom_minimum_size, Vector2(180, 78),
			"Every destination in the mobile menu must remain as touch-friendly as its opener.")

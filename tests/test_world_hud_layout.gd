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
	_hud.gold_label.text = "💰 123456 / 999999"
	_hud.wood_label.text = "🪵 54321 / 99999"
	_hud.iron_label.text = "⛏️ 8888 / 9999"
	_hud.rum_label.text = "🍷 7777 / 9999"

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

extends GutTest

# test_wardrobe_layout.gd
# M16 Requirements 4.4, 4.6 — same property-based approach as
# test_world_hud_layout.gd: no fixed-pixel panel sizing (the wardrobe's root
# panel must actually track viewport size, not stay a constant absolute size
# regardless of it), every interactive slot tab/cosmetic entry meets the
# 48x48 minimum touch target (docs/18_ACCESSIBILITY.md §6), and nothing
# overlaps at any tested viewport size.

const WardrobeScreenScene = preload("res://scenes/ui/WardrobeScreen.tscn")

var _viewport: SubViewport
var _screen: WardrobeScreen


func after_each():
	# open() (not exercised directly here, but _select_slot()'s revert path
	# touches _ship_visuals only) never sets get_tree().paused in this test —
	# only open() itself does, which none of these tests call — but guard
	# anyway so a future change here can't leak a paused tree into whatever
	# test file runs next.
	get_tree().paused = false
	if is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = null
	_screen = null


func _instantiate_at_size(size: Vector2i) -> void:
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_screen = WardrobeScreenScene.instantiate()
	_viewport.add_child(_screen)
	_screen._select_slot("hull")
	_screen.show()


func test_property_panel_tracks_viewport_size_rather_than_a_fixed_pixel_size():
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(750, 1334)]
	var panel_sizes: Array[Vector2] = []
	for size in sizes:
		_instantiate_at_size(size)
		await wait_seconds(0.1)
		var panel: Control = _screen.get_node("Panel")
		panel_sizes.append(panel.size)
		_viewport.queue_free()
		_viewport = null
		_screen = null

	assert_ne(panel_sizes[0], panel_sizes[1],
		"The wardrobe panel must resize with the viewport (anchor-based), not stay a fixed pixel size across very different screen sizes")


func test_property_no_overlap_between_tabs_content_and_buttons():
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(750, 1334)]
	for size in sizes:
		_instantiate_at_size(size)
		await wait_seconds(0.1)

		var tabs_rect: Rect2 = _screen.slot_tabs.get_global_rect()
		var content_rect: Rect2 = _screen.content.get_global_rect()
		var equip_rect: Rect2 = _screen.equip_button.get_global_rect()
		var close_rect: Rect2 = _screen.close_button.get_global_rect()

		assert_false(tabs_rect.intersects(content_rect),
			"Slot tabs (%s) and the cosmetic grid (%s) must not overlap at viewport size %s" % [tabs_rect, content_rect, size])
		assert_false(equip_rect.intersects(close_rect),
			"Equip (%s) and Close (%s) buttons must not overlap at viewport size %s" % [equip_rect, close_rect, size])

		_viewport.queue_free()
		_viewport = null
		_screen = null


func test_property_every_slot_tab_meets_the_minimum_touch_target():
	_instantiate_at_size(Vector2i(750, 1334))
	await wait_seconds(0.1)

	for child in _screen.slot_tabs.get_children():
		if child is Button:
			var rect: Rect2 = child.get_global_rect()
			assert_true(rect.size.x >= 48.0 and rect.size.y >= 48.0,
				"Slot tab '%s' (%s) must meet the 48x48 minimum touch target" % [child.text, rect.size])


func test_property_every_cosmetic_entry_meets_the_minimum_touch_target():
	_instantiate_at_size(Vector2i(750, 1334))
	await wait_seconds(0.1)

	var checked_any := false
	for child in _screen.content.get_children():
		if child is Button:
			checked_any = true
			var rect: Rect2 = child.get_global_rect()
			assert_true(rect.size.x >= 48.0 and rect.size.y >= 48.0,
				"Cosmetic entry '%s' (%s) must meet the 48x48 minimum touch target" % [child.text, rect.size])
	assert_true(checked_any, "Precondition: the hull slot must have at least one authored cosmetic to check")

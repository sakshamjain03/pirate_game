extends GutTest

## M17 Tasks 13-15 — StoreScreen: anchor-based sizing (not a fixed-pixel
## panel, same property-based approach as test_wardrobe_layout.gd), real
## price/owned/unavailable states, and the hard Requirement 4.5 constraint
## that no countdown/scarcity/random node ever exists in this scene.

const StoreScreenScene = preload("res://scenes/ui/StoreScreen.tscn")
const _BUYABLE_SKU := &"cosmetic_hull_deep_ocean_blue"
const _BUYABLE_COSMETIC_ID := &"hull_deep_ocean_blue"

var _viewport: SubViewport
var _screen: StoreScreen
var _saved_entitlements: Dictionary


var _saved_price_strings: Dictionary


func before_each():
	_saved_entitlements = EntitlementManager._entitlements.duplicate(true)
	EntitlementManager._entitlements.erase(_BUYABLE_COSMETIC_ID)
	_saved_price_strings = StoreManager._price_strings.duplicate(true)
	StoreManager._price_strings.clear()


func after_each():
	get_tree().paused = false
	EntitlementManager._entitlements = _saved_entitlements.duplicate(true)
	StoreManager._price_strings = _saved_price_strings.duplicate(true)
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
	_screen = StoreScreenScene.instantiate()
	_viewport.add_child(_screen)
	_screen._refresh()
	_screen.show()


func test_property_panel_tracks_viewport_size_rather_than_a_fixed_pixel_size():
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(750, 1334), Vector2i(1280, 800)]
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
		"The store panel must resize with the viewport, not stay a fixed pixel size")
	assert_ne(panel_sizes[1], panel_sizes[2])


func test_property_no_overlap_between_content_and_close_button():
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(750, 1334)]
	for size in sizes:
		_instantiate_at_size(size)
		await wait_seconds(0.1)
		var content_rect: Rect2 = _screen.content.get_global_rect()
		var close_rect: Rect2 = _screen.close_button.get_global_rect()
		assert_false(content_rect.intersects(close_rect),
			"Content (%s) and Close (%s) must not overlap at %s" % [content_rect, close_rect, size])
		_viewport.queue_free()
		_viewport = null
		_screen = null


func test_a_buyable_product_shows_its_real_stub_price_and_is_not_disabled():
	StoreManager.refresh_products()
	await wait_for_signal(StoreManager.products_updated, 1.0)
	_instantiate_at_size(Vector2i(1920, 1080))
	await wait_seconds(0.1)

	var found_buy_button := false
	for child in _screen.content.get_children():
		for grandchild in child.get_children():
			if grandchild is Button and grandchild.text == "$0.00 (stub)":
				found_buy_button = true
				assert_false(grandchild.disabled)
	assert_true(found_buy_button, "expected the stub-fetched price string to appear on an unowned product")


func test_an_owned_product_shows_owned_and_is_disabled():
	EntitlementManager.grant(_BUYABLE_COSMETIC_ID, "test")
	_instantiate_at_size(Vector2i(1920, 1080))
	await wait_seconds(0.1)

	var found_owned := false
	for child in _screen.content.get_children():
		for grandchild in child.get_children():
			if grandchild is Button and grandchild.text == "Owned":
				found_owned = true
				assert_true(grandchild.disabled)
	assert_true(found_owned, "an owned product must be marked Owned and never re-offered")


func test_price_unavailable_state_shows_no_number():
	_instantiate_at_size(Vector2i(1920, 1080))
	# Never called StoreManager.refresh_products()/_on_products_ready, so
	# get_price_string() is still "" for every sku — Requirement 4.7.
	_screen._refresh()
	await wait_seconds(0.1)

	var found_unavailable := false
	for child in _screen.content.get_children():
		for grandchild in child.get_children():
			if grandchild is Button and grandchild.text == "Unavailable":
				found_unavailable = true
				assert_true(grandchild.disabled)
	assert_true(found_unavailable,
		"with no fetched price, the button must say Unavailable, never a blank/placeholder price")


func test_buy_button_press_begins_a_purchase():
	StoreManager.refresh_products()
	await wait_for_signal(StoreManager.products_updated, 1.0)
	_instantiate_at_size(Vector2i(1920, 1080))
	await wait_seconds(0.1)

	var buy_button: Button = null
	for child in _screen.content.get_children():
		for grandchild in child.get_children():
			if grandchild is Button and not grandchild.disabled:
				buy_button = grandchild
	assert_not_null(buy_button, "precondition: at least one buyable product must render")

	watch_signals(StoreManager)
	buy_button.pressed.emit()
	assert_eq(StoreManager.state, StoreManager.State.PENDING)
	await wait_for_signal(StoreManager.purchase_succeeded, 1.0)


func test_scene_contains_no_timer_countdown_scarcity_or_random_node():
	# Requirement 4.5 — grep-style check against the real instantiated tree,
	# not just the source file, so a node added at runtime would be caught
	# too.
	_instantiate_at_size(Vector2i(1920, 1080))
	await wait_seconds(0.1)
	var banned_terms := ["timer", "countdown", "limited", "scarcity", "random"]
	var stack: Array = [_screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Timer:
			fail_test("StoreScreen must never contain a Timer node (%s)" % node.name)
		var lower_name := node.name.to_lower()
		for term in banned_terms:
			assert_false(lower_name.contains(term),
				"node name '%s' suggests a countdown/scarcity/random mechanic, banned by Requirement 4.5" % node.name)
		for child in node.get_children():
			stack.append(child)

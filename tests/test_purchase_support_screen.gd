extends GutTest

## M17 Task 10/Requirement 3.5 — PurchaseSupportScreen surfaces order ids and
## the support contact route. Follows test_entitlements.gd's own account-data
## backup/restore convention since it reads real EntitlementManager state.

const PurchaseSupportScreenScene := preload("res://scenes/ui/PurchaseSupportScreen.tscn")

var _screen: Control
var _saved_entitlements: Dictionary


func before_each():
	_saved_entitlements = EntitlementManager._entitlements.duplicate(true)


func after_each():
	EntitlementManager._entitlements = _saved_entitlements.duplicate(true)
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func test_opening_shows_the_panel_and_pauses():
	_screen = PurchaseSupportScreenScene.instantiate()
	add_child(_screen)
	_screen.open()
	assert_true(_screen.visible)
	assert_true(get_tree().paused)
	get_tree().paused = false


func test_no_purchases_shows_a_clear_empty_state():
	EntitlementManager._entitlements.clear()
	_screen = PurchaseSupportScreenScene.instantiate()
	add_child(_screen)
	_screen.open()
	var label: Label = _screen.get_node("%OrderIdsLabel")
	assert_string_contains(label.text, "No purchases")
	get_tree().paused = false


func test_a_purchase_order_id_is_listed():
	EntitlementManager._entitlements[&"hull_deep_ocean_blue"] = {
		"source": "purchase", "granted_at": 0, "order_id": "order_xyz",
	}
	_screen = PurchaseSupportScreenScene.instantiate()
	add_child(_screen)
	_screen.open()
	var label: Label = _screen.get_node("%OrderIdsLabel")
	assert_string_contains(label.text, "order_xyz")
	get_tree().paused = false


func test_closing_hides_unpauses_and_frees():
	_screen = PurchaseSupportScreenScene.instantiate()
	add_child(_screen)
	_screen.open()
	_screen.close()
	await wait_frames(1)
	assert_false(is_instance_valid(_screen))
	get_tree().paused = false

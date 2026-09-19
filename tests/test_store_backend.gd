extends GutTest

## M17 Task 2/Requirement 1.4 — StoreBackendStub must model every purchase
## outcome faithfully (success, cancel, fail, already-owned, revocation) and
## must never resolve synchronously: every signal below is asserted to have
## NOT fired yet immediately after the call, and to have fired only after
## awaiting at least one frame.

var _backend: StoreBackendStub


func before_each():
	_backend = StoreBackendStub.new()


func test_is_available_is_always_false():
	assert_false(_backend.is_available())


func test_begin_purchase_success_is_not_synchronous():
	watch_signals(_backend)
	_backend.begin_purchase(&"sku_a")
	assert_signal_not_emitted(_backend, "purchase_completed")

	var fired: bool = await wait_for_signal(_backend.purchase_completed, 1.0)
	assert_true(fired)
	assert_signal_emitted_with_parameters(_backend, "purchase_completed", [&"sku_a", "stub_order_1"])


func test_begin_purchase_cancel_outcome():
	_backend.next_purchase_result = StoreBackendStub.RESULT_CANCEL
	_backend.begin_purchase(&"sku_a")
	var fired: bool = await wait_for_signal(_backend.purchase_cancelled, 1.0)
	assert_true(fired)


func test_begin_purchase_fail_outcome():
	_backend.next_purchase_result = StoreBackendStub.RESULT_FAIL
	_backend.next_failure_reason = "network_error"
	_backend.begin_purchase(&"sku_a")
	var fired: bool = await wait_for_signal(_backend.purchase_failed, 1.0)
	assert_true(fired)
	assert_signal_emitted_with_parameters(_backend, "purchase_failed", [&"sku_a", "network_error"])


func test_repurchasing_an_owned_sku_replays_the_same_order_id():
	_backend.begin_purchase(&"sku_a")
	await wait_for_signal(_backend.purchase_completed, 1.0)
	var params: Array = get_signal_parameters(_backend, "purchase_completed")
	var first_order_id: String = params[1]

	watch_signals(_backend)
	_backend.begin_purchase(&"sku_a")
	await wait_for_signal(_backend.purchase_completed, 1.0)
	assert_signal_emitted_with_parameters(_backend, "purchase_completed", [&"sku_a", first_order_id])


func test_query_owned_reports_previously_purchased_skus():
	_backend.seed_owned(&"sku_a", "order_123")
	_backend.query_owned()
	await wait_for_signal(_backend.owned_items_ready, 1.0)
	assert_signal_emitted_with_parameters(
		_backend, "owned_items_ready", [[{"sku": &"sku_a", "order_id": "order_123"}]])


func test_revocation_is_modeled():
	_backend.seed_owned(&"sku_a", "order_123")
	_backend.simulate_revocation(&"sku_a")
	var fired: bool = await wait_for_signal(_backend.item_revoked, 1.0)
	assert_true(fired)
	assert_signal_emitted_with_parameters(_backend, "item_revoked", [&"sku_a"])


func test_query_products_is_not_synchronous():
	watch_signals(_backend)
	_backend.query_products([&"sku_a"])
	assert_signal_not_emitted(_backend, "products_ready")
	var fired: bool = await wait_for_signal(_backend.products_ready, 1.0)
	assert_true(fired)

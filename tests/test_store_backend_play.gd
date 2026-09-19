extends GutTest

## M17 Task 8 — StoreBackendPlay cannot be functionally verified without a
## real Google Play Billing Android plugin (none vendored) and Play Console
## products; see this milestone's tasks.md for the recorded blocker. What
## IS verified here, headlessly: Requirement 1.5's graceful degradation —
## every method is safe to call when the plugin is absent, never crashes,
## and never reports itself available.

var _backend: StoreBackendPlay


func before_each():
	_backend = StoreBackendPlay.new()


func test_is_available_is_false_without_the_plugin():
	assert_false(_backend.is_available())


func test_query_products_reports_empty_rather_than_crashing():
	watch_signals(_backend)
	_backend.query_products([&"sku_a"])
	var fired: bool = await wait_for_signal(_backend.products_ready, 1.0)
	assert_true(fired)
	assert_signal_emitted_with_parameters(_backend, "products_ready", [[]])


func test_begin_purchase_fails_safely_rather_than_crashing():
	watch_signals(_backend)
	_backend.begin_purchase(&"sku_a")
	var fired: bool = await wait_for_signal(_backend.purchase_failed, 1.0)
	assert_true(fired)
	assert_signal_emitted_with_parameters(_backend, "purchase_failed", [&"sku_a", "store_unavailable"])


func test_query_owned_reports_empty_rather_than_crashing():
	watch_signals(_backend)
	_backend.query_owned()
	var fired: bool = await wait_for_signal(_backend.owned_items_ready, 1.0)
	assert_true(fired)
	assert_signal_emitted_with_parameters(_backend, "owned_items_ready", [[]])


func test_acknowledge_does_not_crash_without_the_plugin():
	_backend.acknowledge("some_order_id")
	assert_true(true, "acknowledge() must be a safe no-op without the plugin")

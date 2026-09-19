class_name StoreBackendStub extends IStoreBackend

## StoreBackendStub
## Deterministic no-op billing backend for desktop and every GUT test
## (Requirement 1.4). Not a throwaway: this is what makes the entire purchase
## state machine — success, cancellation, failure, an already-owned replay,
## and a revocation — testable headlessly, so it models each outcome
## faithfully rather than only the happy path (design.md §3).
##
## Every outcome is reported one deferred call later, never synchronously —
## a real store never resolves within the call that started it, and a test
## that only ever saw a synchronous stub would prove nothing about the real
## purchase flow's async handling.

## Test/StoreManager control: what the next begin_purchase() call resolves
## to. Left as plain strings (not an enum) so a scratch test can drive every
## outcome without importing this class's own type.
const RESULT_SUCCESS := "success"
const RESULT_CANCEL := "cancel"
const RESULT_FAIL := "fail"

var next_purchase_result: String = RESULT_SUCCESS
var next_failure_reason: String = "stub_failure"

## sku -> order_id, for query_owned()/the already-owned replay. Purchasing an
## already-owned sku again (Requirement 2.3 idempotence) replays the same
## order id rather than minting a new one — exactly what a real store does
## for a non-consumable.
var _owned: Dictionary = {}
var _next_order_id := 1


func is_available() -> bool:
	return false


func query_products(skus: Array) -> void:
	var products: Array = []
	for sku in skus:
		products.append({
			"sku": sku,
			"price_string": "$0.00 (stub)",
			"title": str(sku),
		})
	call_deferred("emit_signal", "products_ready", products)


func begin_purchase(sku: StringName) -> void:
	if _owned.has(sku):
		call_deferred("emit_signal", "purchase_completed", sku, _owned[sku])
		return
	match next_purchase_result:
		RESULT_CANCEL:
			call_deferred("emit_signal", "purchase_cancelled", sku)
		RESULT_FAIL:
			call_deferred("emit_signal", "purchase_failed", sku, next_failure_reason)
		_:
			var order_id := "stub_order_%d" % _next_order_id
			_next_order_id += 1
			_owned[sku] = order_id
			call_deferred("emit_signal", "purchase_completed", sku, order_id)


func query_owned() -> void:
	var purchases: Array = []
	for sku in _owned:
		purchases.append({"sku": sku, "order_id": _owned[sku]})
	call_deferred("emit_signal", "owned_items_ready", purchases)


func acknowledge(_order_id: String) -> void:
	pass


## Test-only: simulates the store reporting a refund/chargeback for a sku
## already recorded as owned by this stub.
func simulate_revocation(sku: StringName) -> void:
	if not _owned.has(sku):
		return
	_owned.erase(sku)
	call_deferred("emit_signal", "item_revoked", sku)


## Test-only: seeds an already-owned sku without going through
## begin_purchase(), so a test can exercise query_owned()/reconciliation in
## isolation from the purchase flow that created the ownership.
func seed_owned(sku: StringName, order_id: String) -> void:
	_owned[sku] = order_id

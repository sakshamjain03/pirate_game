class_name IStoreBackend extends RefCounted

## IStoreBackend
## Platform-agnostic billing interface (design.md §3). Play Billing implements
## this in M17; StoreKit implements it in M20; StoreBackendStub implements it
## for desktop and every headless test. StoreManager is the only caller —
## game code, UI, and EntitlementManager never reference a platform SDK or a
## concrete backend class directly (Requirement 1.1/1.2).
##
## Every signal below is the sole channel a concrete backend uses to report an
## outcome back to StoreManager. A conforming backend NEVER returns a result
## synchronously from the methods below — even the stub emits on a later
## frame, because a real store never resolves within the same call.

signal products_ready(products: Array)                    # [{sku, price_string, title}]
signal purchase_completed(sku: StringName, order_id: String)
signal purchase_cancelled(sku: StringName)
signal purchase_failed(sku: StringName, reason: String)
signal owned_items_ready(purchases: Array)                 # [{sku, order_id}]
signal item_revoked(sku: StringName)


## True only when a real store is actually reachable right now — the signal
## StoreManager/StoreScreen use to decide whether to show a purchase
## affordance at all (Requirement 1.5). The stub always returns false: it
## exists to make the state machine testable, not to pose as an available
## store on desktop.
func is_available() -> bool:
	return false


func query_products(_skus: Array) -> void:
	pass


func begin_purchase(_sku: StringName) -> void:
	pass


func query_owned() -> void:
	pass


func acknowledge(_order_id: String) -> void:
	pass

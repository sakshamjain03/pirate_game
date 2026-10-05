extends Node

## StoreManager
## Autoload. Owns the product catalogue (resources/store/*.tres), selects an
## IStoreBackend implementation once at startup, and drives the purchase
## state machine (design.md §4). Every non-consumable purchase — single or
## bundled — routes through EntitlementManager.grant_batch(), the one write path
## M16 already established; StoreManager never writes an entitlement itself.
## M27 consumables (ProductData.grants_eights > 0, the Eights packs) instead add
## Pieces of Eight through SaveManager.persist_purchased_eights(), once per order
## id (STORE_ORDERS_PATH), then consume the order.
##
## Nothing above this autoload ever learns which concrete backend it got
## (Requirement 1.1/1.2) — StoreScreen, SettingsMenu, and every test talk to
## StoreManager only.

signal products_updated
signal purchase_succeeded(sku: StringName)
signal purchase_cancelled(sku: StringName)
signal purchase_failed(sku: StringName, reason: String)
signal restore_completed(granted_count: int)

const PRODUCTS_ROOT := "res://resources/store/"

## M27 — every consumable order id that has already granted its Eights. Its own
## eagerly-written file (EntitlementManager's pattern), not the main save: a
## cloud-save conflict that rolls the campaign back must never make an order
## grantable again.
const STORE_ORDERS_PATH := "user://store_orders.json"

enum State { IDLE, PENDING }

var state: State = State.IDLE
var _backend: IStoreBackend
var _products_by_sku: Dictionary = {}       # StringName -> ProductData
var _price_strings: Dictionary = {}         # StringName -> String
var _pending_sku: StringName = &""
var _granted_orders: Dictionary = {}        # order_id -> true


func _ready() -> void:
	_load_granted_orders()
	_scan_products()
	_backend = _create_backend()
	_backend.products_ready.connect(_on_products_ready)
	_backend.purchase_completed.connect(_on_purchase_completed)
	_backend.purchase_cancelled.connect(_on_purchase_cancelled)
	_backend.purchase_failed.connect(_on_purchase_failed)
	_backend.owned_items_ready.connect(_on_owned_items_ready)
	_backend.item_revoked.connect(_on_item_revoked)
	reconcile_owned_purchases()


func is_available() -> bool:
	return _backend.is_available()


func get_all_products() -> Array[ProductData]:
	var result: Array[ProductData] = []
	for product in _products_by_sku.values():
		result.append(product)
	return result


func get_product(sku: StringName) -> ProductData:
	return _products_by_sku.get(sku, null)


## True only when every entitlement a product grants is already owned — the
## "don't re-offer" check (Requirement 4.3). A product with no entitlement
## ids at all is never considered owned.
func is_owned(sku: StringName) -> bool:
	var product := get_product(sku)
	if not product or product.entitlement_ids.is_empty():
		return false
	for id in product.entitlement_ids:
		if not EntitlementManager.has_entitlement(id):
			return false
	return true


## "" means unknown/unavailable — Requirement 4.7's unavailable state, never
## a placeholder or stale price.
func get_price_string(sku: StringName) -> String:
	return _price_strings.get(sku, "")


func refresh_products() -> void:
	_backend.query_products(_products_by_sku.keys())


func begin_purchase(sku: StringName) -> void:
	if state != State.IDLE or not _products_by_sku.has(sku):
		return
	state = State.PENDING
	_pending_sku = sku
	_backend.begin_purchase(sku)


## Explicit "Restore purchases" action (Requirement 3.2) — same underlying
## mechanism as the launch-time reconciliation below, just player-invoked.
func restore_purchases() -> void:
	reconcile_owned_purchases()


## Re-queries owned non-consumables and grants anything missing, silently
## (Requirement 1.6/2.6/3.1). Runs on every launch and can also be called
## directly by a test to simulate "the app was killed mid-flow and just
## relaunched" without a real process restart.
func reconcile_owned_purchases() -> void:
	_backend.query_owned()


func _create_backend() -> IStoreBackend:
	if OS.get_name() == "Android":
		return StoreBackendPlay.new()
	# W0-3.1: Release builds on non-Android platforms use unavailable backend
	if not OS.is_debug_build():
		return StoreBackendUnavailable.new()
	return StoreBackendStub.new()


func _scan_products() -> void:
	_products_by_sku.clear()
	for path in ResourceLookup.list_resource_paths(PRODUCTS_ROOT):
		var product := load(path) as ProductData
		if product and product.sku != &"":
			_products_by_sku[product.sku] = product


func _on_products_ready(products: Array) -> void:
	for entry in products:
		_price_strings[entry.get("sku", &"")] = entry.get("price_string", "")
	products_updated.emit()


func _on_purchase_completed(sku: StringName, order_id: String) -> void:
	var product := get_product(sku)
	if product and product.grants_eights > 0:
		_grant_consumable(product, order_id)
	else:
		_grant_product(sku, order_id)
		_backend.acknowledge(order_id)
	if sku == _pending_sku:
		state = State.IDLE
		_pending_sku = &""
		purchase_succeeded.emit(sku)


func _on_purchase_cancelled(sku: StringName) -> void:
	if sku == _pending_sku:
		state = State.IDLE
		_pending_sku = &""
	purchase_cancelled.emit(sku)


func _on_purchase_failed(sku: StringName, reason: String) -> void:
	if sku == _pending_sku:
		state = State.IDLE
		_pending_sku = &""
	purchase_failed.emit(sku, reason)


## Requirement 1.6/3.1 — runs on every launch (from _ready()) and whenever
## the player taps "Restore purchases." An owned purchase is re-acknowledged
## every time, not just the first: acknowledging an already-acknowledged
## non-consumable is a safe no-op on a real store, and this is what actually
## satisfies "an unacknowledged purchase SHALL be re-acknowledged on next
## launch" — the game re-asserts it on its own schedule rather than trusting
## a single acknowledgement to have landed.
func _on_owned_items_ready(purchases: Array) -> void:
	var granted := 0
	for entry in purchases:
		var order_id: String = entry.get("order_id", "")
		# M27 — an unconsumed Eights order (the app died between payment and
		# grant) is granted once here, then consumed; one already granted is
		# only consumed. The granted-order record is what stops a double grant.
		var product := get_product(entry.get("sku", &""))
		if product and product.grants_eights > 0:
			if _grant_consumable(product, order_id):
				granted += 1
			continue
		if _grant_product(entry.get("sku", &""), order_id):
			granted += 1
		if order_id != "":
			_backend.acknowledge(order_id)
	restore_completed.emit(granted)


func _on_item_revoked(sku: StringName) -> void:
	var product := get_product(sku)
	if not product:
		return
	for id in product.entitlement_ids:
		EntitlementManager.revoke(id)


## Grants every entitlement a sku's ProductData lists, in one batch
## (Requirement 2.4 atomicity), and returns whether anything new was
## actually granted — the launch-time replay of an already-owned purchase is
## expected to return false every time, silently (Requirement 2.3).
func _grant_product(sku: StringName, order_id: String) -> bool:
	var product := get_product(sku)
	if not product or product.entitlement_ids.is_empty():
		return false
	var already_owned := is_owned(sku)
	EntitlementManager.grant_batch(product.entitlement_ids, "purchase", order_id)
	return not already_owned


## M27 Requirement 6.3 — adds a consumable's Eights exactly once per order id,
## then consumes it. Returns whether Eights were granted by this call. If the
## Eights can't be written, the order is left unconsumed so the next launch's
## reconciliation retries it. Eights are persisted before the order id is
## recorded: a crash between the two errs toward the player (granted again on
## restore), never toward losing a paid pack.
func _grant_consumable(product: ProductData, order_id: String) -> bool:
	if order_id.is_empty():
		push_error("StoreManager: consumable %s delivered without an order id." % product.sku)
		return false
	if _granted_orders.has(order_id):
		_backend.consume(order_id)
		return false
	if not SaveManager.persist_purchased_eights(product.grants_eights):
		push_error("StoreManager: could not persist Eights for order %s; left unconsumed." % order_id)
		return false
	_granted_orders[order_id] = true
	_write_granted_orders()
	_backend.consume(order_id)
	return true


func _load_granted_orders() -> void:
	_granted_orders.clear()
	if not FileAccess.file_exists(STORE_ORDERS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STORE_ORDERS_PATH))
	if not parsed is Dictionary or not parsed.get("granted_orders") is Array:
		push_error("StoreManager: %s is unreadable; granted-order record starts empty." % STORE_ORDERS_PATH)
		return
	for id in parsed["granted_orders"]:
		_granted_orders[str(id)] = true


func _write_granted_orders() -> void:
	var file := FileAccess.open(STORE_ORDERS_PATH, FileAccess.WRITE)
	if not file:
		push_error("StoreManager: failed to write %s." % STORE_ORDERS_PATH)
		return
	file.store_string(JSON.stringify({"granted_orders": _granted_orders.keys()}, "\t"))
	file.close()

extends Node

## StoreManager
## Autoload. Owns the product catalogue (resources/store/*.tres), selects an
## IStoreBackend implementation once at startup, and drives the purchase
## state machine (design.md §4). Every purchase — single or bundled — routes
## through EntitlementManager.grant_batch(), the one write path M16 already
## established; StoreManager never writes an entitlement itself.
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

enum State { IDLE, PENDING }

var state: State = State.IDLE
var _backend: IStoreBackend
var _products_by_sku: Dictionary = {}       # StringName -> ProductData
var _price_strings: Dictionary = {}         # StringName -> String
var _pending_sku: StringName = &""


func _ready() -> void:
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
	return StoreBackendStub.new()


func _scan_products() -> void:
	_products_by_sku.clear()
	var dir := DirAccess.open(PRODUCTS_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".tres"):
			var product := load(PRODUCTS_ROOT.path_join(entry)) as ProductData
			if product and product.sku != &"":
				_products_by_sku[product.sku] = product
		entry = dir.get_next()
	dir.list_dir_end()


func _on_products_ready(products: Array) -> void:
	for entry in products:
		_price_strings[entry.get("sku", &"")] = entry.get("price_string", "")
	products_updated.emit()


func _on_purchase_completed(sku: StringName, order_id: String) -> void:
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

class_name StoreBackendPlay extends IStoreBackend

## StoreBackendPlay
## Google Play Billing implementation of IStoreBackend (design.md §3,
## Requirement 1.3). Not functionally verifiable in this environment yet:
## no Google Play Billing Android plugin (e.g. a GDExtension/.aar exposing a
## Play Billing singleton) is vendored in this repo, and Play Console has no
## products configured. Recorded as a real, explicit blocker in this
## milestone's tasks.md — Task 8 — rather than guessed at.
##
## Until that plugin exists, is_available() always reports false (the same
## graceful-degradation path Requirement 1.5 already requires for "no store,
## no network, unsupported platform"), and every other method safely reports
## failure instead of crashing, so selecting this backend before the plugin
## is added can never leave the game in a broken state. When the plugin
## lands, each method below replaces its guard clause with the real call —
## the signal contract (IStoreBackend) does not change.

## The expected Android plugin singleton name. Not yet vendored — checked by
## name rather than assumed present, so this stays honestly false today.
const _PLUGIN_SINGLETON_NAME := "GodotGooglePlayBilling"


func is_available() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(_PLUGIN_SINGLETON_NAME)


func query_products(skus: Array) -> void:
	if not is_available():
		call_deferred("emit_signal", "products_ready", [])
		return
	# TODO(M17 Wave 1, blocked): route to the real plugin's product-details
	# query once it is vendored; map its result to [{sku, price_string, title}].
	call_deferred("emit_signal", "products_ready", [])


func begin_purchase(sku: StringName) -> void:
	if not is_available():
		call_deferred("emit_signal", "purchase_failed", sku, "store_unavailable")
		return
	# TODO(M17 Wave 1, blocked): route to the real plugin's purchase flow.
	call_deferred("emit_signal", "purchase_failed", sku, "store_unavailable")


func query_owned() -> void:
	if not is_available():
		call_deferred("emit_signal", "owned_items_ready", [])
		return
	# TODO(M17 Wave 1, blocked): route to the real plugin's owned-purchases
	# query; acknowledge any unacknowledged purchase internally here before
	# emitting (Requirement 1.6) — StoreManager only learns skus/order ids,
	# never raw acknowledgement state, per IStoreBackend's contract.
	call_deferred("emit_signal", "owned_items_ready", [])


func acknowledge(_order_id: String) -> void:
	if not is_available():
		return
	# TODO(M17 Wave 1, blocked): route to the real plugin's acknowledge call.
	pass

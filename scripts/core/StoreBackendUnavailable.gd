class_name StoreBackendUnavailable extends IStoreBackend

## StoreBackendUnavailable
## A guard backend used in release builds on non-Android platforms (Requirement W0-3.1).
## The store is not available, all purchases fail, and nothing is ever granted.
## This prevents a desktop release build from giving away paid content.

func is_available() -> bool:
	return false


func query_products(skus: Array) -> void:
	var products: Array = []
	for sku in skus:
		products.append({
			"sku": sku,
			"price_string": "Unavailable",
			"title": str(sku),
		})
	call_deferred("emit_signal", "products_ready", products)


func begin_purchase(sku: StringName) -> void:
	# W0-3.1: Release builds never grant anything for free
	call_deferred("emit_signal", "purchase_failed", sku, "Store is unavailable on this platform")


func query_owned() -> void:
	call_deferred("emit_signal", "owned_items_ready", [])


func acknowledge(_order_id: String) -> void:
	pass


func consume(_order_id: String) -> void:
	pass

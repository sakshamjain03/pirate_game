class_name StoreScreen extends Control

## StoreScreen (M17 Requirement 4)
## Real-store-fetched prices only, never hardcoded (Requirement 4.2) — every
## price shown comes from StoreManager.get_price_string(), which is empty
## until the backend actually reports one and stays empty forever on the
## desktop stub, driving Requirement 4.7's unavailable state rather than a
## placeholder or stale number. Owned items are marked and never re-offered
## (Requirement 4.3). Same pause-and-show modal pattern as WardrobeScreen —
## a persistent node wired into whichever scene opens it (WardrobeScreen,
## MainMenu), never dynamically created per-open.
##
## Requirement 4.5 is a hard constraint enforced by
## tests/test_monetization_invariants.gd's grep check: no countdown, scarcity
## claim, or randomized reward may ever be added to this scene or script.

@onready var content: VBoxContainer = %Content
@onready var close_button: Button = %CloseButton
@onready var title_label: Label = %TitleLabel

## Requirement 4.6 / docs/18_ACCESSIBILITY.md §6 — minimum touch target size,
## same constant WardrobeScreen already uses.
const _MIN_TOUCH_SIZE := Vector2(48, 48)


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	close_button.pressed.connect(close)
	StoreManager.products_updated.connect(_refresh)
	StoreManager.purchase_succeeded.connect(_on_purchase_succeeded)
	StoreManager.purchase_cancelled.connect(_on_purchase_cancelled)
	StoreManager.purchase_failed.connect(_on_purchase_failed)
	PirateThemeBuilder.apply_button_juice(self)

	if PirateThemeBuilder.is_mobile():
		title_label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(24))
		close_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(close_button.custom_minimum_size)


func open() -> void:
	AnalyticsManager.log_event("store_opened")
	_refresh()
	StoreManager.refresh_products()
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _refresh() -> void:
	for child in content.get_children():
		child.queue_free()
	for product in StoreManager.get_all_products():
		content.add_child(_build_entry(product))
	PirateThemeBuilder.apply_button_juice(content)


func _build_entry(product: ProductData) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = PirateThemeBuilder.scaled_size(_MIN_TOUCH_SIZE)
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = product.display_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var action := Button.new()
	action.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_MIN_TOUCH_SIZE)

	if StoreManager.is_owned(product.sku):
		action.text = tr("Owned")
		action.disabled = true
	else:
		var price := StoreManager.get_price_string(product.sku)
		if price.is_empty():
			# Requirement 4.7 — unavailable, never a placeholder/stale price.
			action.text = tr("Unavailable")
			action.disabled = true
		else:
			action.text = price
			action.pressed.connect(_on_buy_pressed.bind(product.sku))

	row.add_child(action)
	return row


func _on_buy_pressed(sku: StringName) -> void:
	AnalyticsManager.log_event("product_viewed", {"sku": str(sku)})
	AnalyticsManager.log_event("purchase_started", {"sku": str(sku)})
	StoreManager.begin_purchase(sku)


func _on_purchase_succeeded(sku: StringName) -> void:
	AnalyticsManager.log_event("purchase_completed", {"sku": str(sku)})
	_refresh()


func _on_purchase_cancelled(sku: StringName) -> void:
	# No error modal for a simple cancellation (Requirement 2.5) — just
	# refresh so the button reverts to its normal state.
	AnalyticsManager.log_event("purchase_cancelled", {"sku": str(sku)})
	_refresh()


func _on_purchase_failed(_sku: StringName, _reason: String) -> void:
	_refresh()

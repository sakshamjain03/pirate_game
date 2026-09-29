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
@onready var page: PanelContainer = %Page

## Requirement 4.6 / docs/18_ACCESSIBILITY.md §6 — minimum touch target size,
## same constant WardrobeScreen already uses.
const _MIN_TOUCH_SIZE := Vector2(48, 48)
## Wide enough that "Owned"/"Unavailable"/a localised price never resizes
## the column row to row.
const _BUY_BUTTON_SIZE := Vector2(280, 48)

## M27 — the Eights section's live balance (rebuilt with every _refresh()).
var _eights_balance_label: Label = null


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	PirateThemeBuilder.dress_modal_dim($ColorRect)  # M22 6c: v0.3 teal-black backdrop
	# M22 6b: the shared journal page. Buy buttons stay brass on purpose —
	# a coral glowing "buy" is exactly the pressure AGENTS.md forbids.
	PirateThemeBuilder.dress_parchment_page(page)
	close_button.pressed.connect(close)
	StoreManager.products_updated.connect(_refresh)
	StoreManager.purchase_succeeded.connect(_on_purchase_succeeded)
	StoreManager.purchase_cancelled.connect(_on_purchase_cancelled)
	StoreManager.purchase_failed.connect(_on_purchase_failed)
	ResourceManager.resources_changed.connect(_update_eights_balance)
	PirateThemeBuilder.apply_button_juice(self)

	if PirateThemeBuilder.is_mobile():
		close_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(close_button.custom_minimum_size)


func open() -> void:
	AnalyticsManager.log_event("store_opened")
	_refresh()
	StoreManager.refresh_products()
	show()
	UIMotion.modal_enter($Panel, $ColorRect)
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
	_eights_balance_label = null
	# M27 Requirement 6.5 — Eights packs first, under the current balance; the
	# cosmetics and supporter pack follow unchanged.
	var packs: Array[ProductData] = []
	var others: Array[ProductData] = []
	for product in StoreManager.get_all_products():
		if product.grants_eights > 0:
			packs.append(product)
		else:
			others.append(product)
	packs.sort_custom(func(a, b): return a.grants_eights < b.grants_eights)
	if not packs.is_empty():
		content.add_child(_build_eights_header())
		for product in packs:
			content.add_child(HSeparator.new())
			content.add_child(_build_entry(product))
	for product in others:
		if content.get_child_count() > 0:
			content.add_child(HSeparator.new())
		content.add_child(_build_entry(product))
	PirateThemeBuilder.apply_button_juice(content)


## "Pieces of Eight" + the live balance, above the packs.
func _build_eights_header() -> Control:
	var row := HBoxContainer.new()
	row.name = "EightsHeader"
	row.custom_minimum_size = PirateThemeBuilder.scaled_size(_MIN_TOUCH_SIZE)
	row.add_theme_constant_override("separation", 12)
	var heading := Label.new()
	heading.text = tr("Pieces of Eight")
	heading.theme_type_variation = &"InkTitleLabel"
	heading.add_theme_font_size_override("font_size", UITokens.FONT_HUD_NUM)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var icon := TextureRect.new()
	icon.texture = UIIcons.get_icon("eights")
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_eights_balance_label = Label.new()
	_eights_balance_label.name = "EightsBalance"
	_eights_balance_label.theme_type_variation = &"InkTitleLabel"
	_eights_balance_label.add_theme_font_size_override("font_size", UITokens.FONT_HUD_NUM)
	_eights_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_eights_balance_label)
	# The content scrollbar overlays the row's right edge; keep the number clear of it.
	var gutter := Control.new()
	gutter.custom_minimum_size = Vector2(16, 0)
	row.add_child(gutter)
	_update_eights_balance()
	return row


func _update_eights_balance(_res: Dictionary = {}) -> void:
	if is_instance_valid(_eights_balance_label):
		_eights_balance_label.text = str(ResourceManager.get_resource(ResourceManager.PREMIUM_CURRENCY))


func _build_entry(product: ProductData) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = PirateThemeBuilder.scaled_size(_MIN_TOUCH_SIZE)
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = product.display_name
	if product.grants_eights > 0:
		label.text = tr("%s — %d Pieces of Eight") % [product.display_name, product.grants_eights]
	label.theme_type_variation = &"InkTitleLabel"
	label.add_theme_font_size_override("font_size", UITokens.FONT_HUD_NUM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var action := Button.new()
	action.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_BUY_BUTTON_SIZE)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER

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

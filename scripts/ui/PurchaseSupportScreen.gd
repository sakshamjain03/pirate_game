class_name PurchaseSupportScreen extends Control

## PurchaseSupportScreen (M17 Requirement 3.5/§4.3 layer 3)
## Surfaces every order id EntitlementManager knows about and the support
## contact route, for the cases store restore and cloud sync both miss.
## Unlike WardrobeScreen/WhatsNewScreen (persistent nodes wired into a real
## scene) this one is only ever reachable from SettingsMenu, has no state of
## its own worth preserving, and is created on demand and freed on close —
## SettingsMenu instantiates it fresh each time it's opened.

const SUPPORT_EMAIL := "sj@passthebot.dev"

@onready var order_ids_label: Label = %OrderIdsLabel
@onready var close_button: Button = %CloseButton
@onready var contact_button: Button = %ContactButton
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	close_button.pressed.connect(close)
	contact_button.pressed.connect(_on_contact_pressed)
	PirateThemeBuilder.apply_button_juice(self)

	if PirateThemeBuilder.is_mobile():
		panel.custom_minimum_size = PirateThemeBuilder.scaled_size(panel.custom_minimum_size)
		title_label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(24))
		contact_button.custom_minimum_size = PirateThemeBuilder.scaled_size(contact_button.custom_minimum_size)
		close_button.custom_minimum_size = PirateThemeBuilder.scaled_size(close_button.custom_minimum_size)


func open() -> void:
	_refresh()
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false
	queue_free()


func _refresh() -> void:
	var order_ids := EntitlementManager.get_all_order_ids()
	if order_ids.is_empty():
		order_ids_label.text = tr("No purchases on this account yet.")
	else:
		order_ids_label.text = tr("Order ID(s):\n%s") % "\n".join(order_ids)


func _on_contact_pressed() -> void:
	OS.shell_open("mailto:%s" % SUPPORT_EMAIL)

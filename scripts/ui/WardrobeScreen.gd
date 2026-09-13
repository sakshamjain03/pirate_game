class_name WardrobeScreen extends Control

## WardrobeScreen (M16)
## Browse, preview, and equip ship cosmetics. Same pause-and-show modal
## pattern as CaptainsLog/WorldMapScreen/CodexScreen: opens paused, closes
## back to gameplay. Preview reuses the existing live player ship
## (ShipVisuals.preview_cosmetic()/cancel_preview(), design.md §8) rather than
## a second ship instance — equip-on-confirm only, so backing out (or
## switching slots) without confirming leaves the ship exactly as it was
## equipped before this screen opened.
## Requirement 4.5 is a hard constraint: no purchase affordance, price,
## currency, or store link anywhere in this screen — absent, not disabled.

@onready var slot_tabs: HBoxContainer = %SlotTabs
@onready var content: GridContainer = %Content
@onready var equip_button: Button = %EquipButton
@onready var close_button: Button = %CloseButton
@onready var detail_label: Label = %DetailLabel

const _SLOTS: Array[String] = ["hull", "sails", "flag", "figurehead", "decoration"]
## Requirement 4.6 / `docs/18_ACCESSIBILITY.md` §6 — minimum touch target size.
const _MIN_TOUCH_SIZE := Vector2(48, 48)

var _ship_visuals: Node = null
var _current_slot: String = ""
var _previewing_cosmetic: CosmeticData = null


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	close_button.pressed.connect(close)
	equip_button.pressed.connect(_on_equip_pressed)
	equip_button.disabled = true
	_build_slot_tabs()
	PirateThemeBuilder.apply_button_juice(self)


func open() -> void:
	_ship_visuals = _find_player_ship_visuals()
	_previewing_cosmetic = null
	equip_button.disabled = true
	detail_label.text = ""
	_select_slot(_SLOTS[0])
	show()
	get_tree().paused = true


func close() -> void:
	_revert_active_preview()
	hide()
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _build_slot_tabs() -> void:
	for slot in _SLOTS:
		var btn := Button.new()
		btn.name = "Slot_%s" % slot
		btn.text = slot.capitalize()
		btn.custom_minimum_size = _MIN_TOUCH_SIZE
		btn.toggle_mode = true
		btn.pressed.connect(_select_slot.bind(slot))
		slot_tabs.add_child(btn)


func _select_slot(slot: String) -> void:
	if slot == _current_slot:
		return
	# Leaving a slot without confirming reverts whatever was being previewed
	# there — the same "no silent commit" rule as closing the whole screen.
	_revert_active_preview()
	_current_slot = slot
	for child in slot_tabs.get_children():
		if child is Button:
			child.button_pressed = (child.name == "Slot_%s" % slot)
	_refresh_content()


func _refresh_content() -> void:
	for child in content.get_children():
		child.queue_free()
	for cosmetic in CosmeticCatalogue.get_by_slot(_current_slot):
		content.add_child(_build_entry(cosmetic))
	PirateThemeBuilder.apply_button_juice(content)


func _build_entry(cosmetic: CosmeticData) -> Button:
	var owned: bool = EntitlementManager.has_entitlement(cosmetic.id)

	var btn := Button.new()
	btn.custom_minimum_size = _MIN_TOUCH_SIZE
	btn.text = cosmetic.display_name if owned else tr("%s (Not Owned)") % cosmetic.display_name
	btn.disabled = not owned
	if cosmetic.icon:
		btn.icon = cosmetic.icon
	btn.pressed.connect(_on_cosmetic_selected.bind(cosmetic))
	return btn


func _on_cosmetic_selected(cosmetic: CosmeticData) -> void:
	if not _ship_visuals or not _ship_visuals.has_method("preview_cosmetic"):
		return
	_ship_visuals.preview_cosmetic(_current_slot, cosmetic)
	_previewing_cosmetic = cosmetic
	equip_button.disabled = false
	detail_label.text = "%s\n%s" % [cosmetic.display_name, cosmetic.description]


func _on_equip_pressed() -> void:
	if not _previewing_cosmetic or not _ship_visuals or not _ship_visuals.has_method("apply_cosmetic"):
		return
	_ship_visuals.apply_cosmetic(_current_slot, _previewing_cosmetic)
	_previewing_cosmetic = null
	equip_button.disabled = true


func _revert_active_preview() -> void:
	if _previewing_cosmetic and _ship_visuals and _ship_visuals.has_method("cancel_preview"):
		_ship_visuals.cancel_preview(_current_slot)
	_previewing_cosmetic = null
	if equip_button:
		equip_button.disabled = true


func _find_player_ship_visuals() -> Node:
	var player := get_tree().get_first_node_in_group("player_ship")
	if not player:
		return null
	return player.get_node_or_null("ShipModel")

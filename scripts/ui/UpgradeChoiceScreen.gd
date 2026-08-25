class_name UpgradeChoiceScreen extends Control

## Purpose: the "Choose One" moment of `docs/navalCombat.md` §11.
## Responsibilities: present 2–4 temporary battle upgrades, take one pick, hand it
##   back to EncounterManager, unpause.
## Dependencies: EncounterManager (offers + application), PirateThemeBuilder.
##
## Cards are built in code rather than authored in the scene because the offer size
## varies per encounter (§12: 2–4 normally, more for a boss). `IslandMenu` already
## establishes code-built UI as this project's convention for variable content.

signal upgrade_chosen(upgrade: BattleUpgradeData)

var _encounter_manager: Node = null
var _cards_row: HBoxContainer
var _subtitle: Label
var _offered: Array = []


func _ready() -> void:
	# Must keep processing while the tree is paused, same as DeathScreen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	_build()
	hide()


func bind_encounter_manager(mgr: Node) -> void:
	_encounter_manager = mgr
	if mgr and mgr.has_signal("upgrade_offer_requested"):
		mgr.upgrade_offer_requested.connect(_on_offer)
	if mgr and mgr.has_signal("encounter_ended"):
		# A fight that ends mid-choice (the player was sunk by the volley that
		# triggered the offer) must not leave a modal panel over the death screen.
		mgr.encounter_ended.connect(_on_encounter_ended)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	add_child(centre)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.05, 0.97)
	style.set_border_width_all(4)
	style.border_color = Color(0.85, 0.68, 0.30)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	var title := Label.new()
	title.text = "CHOOSE ONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	col.add_child(title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 15)
	_subtitle.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60))
	col.add_child(_subtitle)

	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 16)
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_cards_row)


func _on_offer(choices: Array, offer_index: int, total_offers: int) -> void:
	if choices.is_empty():
		return
	_offered = choices
	_subtitle.text = "Lasts this battle only  ·  offer %d of %d" % [offer_index, total_offers]

	for child in _cards_row.get_children():
		child.queue_free()

	var first: Button = null
	for upgrade in choices:
		var card := _make_card(upgrade)
		_cards_row.add_child(card)
		if first == null:
			first = card

	show()
	get_tree().paused = true
	if first:
		first.grab_focus()


func _make_card(upgrade: BattleUpgradeData) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(228, 210)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.text = "%s\n\n%s\n\n%s" % [upgrade.icon, upgrade.display_name, upgrade.describe()]
	card.add_theme_font_size_override("font_size", 17)
	card.tooltip_text = upgrade.describe()
	card.pressed.connect(_on_card_pressed.bind(upgrade))
	return card


func _on_card_pressed(upgrade: BattleUpgradeData) -> void:
	if _encounter_manager and _encounter_manager.has_method("apply_upgrade_choice"):
		_encounter_manager.apply_upgrade_choice(upgrade)
	upgrade_chosen.emit(upgrade)
	_close()


func _on_encounter_ended(_victory: bool, _rewards: Dictionary) -> void:
	if visible:
		_close()


func _close() -> void:
	hide()
	_offered.clear()
	get_tree().paused = false

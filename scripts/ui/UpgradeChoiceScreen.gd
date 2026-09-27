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
var _panel: PanelContainer
var _dim: ColorRect

const _CARD_SIZE := Vector2(300, 330)


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
	PirateThemeBuilder.dress_modal_dim(dim)
	_dim = dim
	dim.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	add_child(centre)

	# M22 6b: kit frame + parchment page of BoardTile cards (was a flat
	# navy StyleBoxFlat with hand-picked colours).
	var panel := PanelContainer.new()
	_panel = panel
	panel.theme_type_variation = &"WoodFramePanel"
	centre.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := Label.new()
	title.text = tr("Choose One")
	title.theme_type_variation = &"DisplayLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"ChipLabel"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_subtitle)

	var page := PanelContainer.new()
	PirateThemeBuilder.dress_parchment_page(page)
	col.add_child(page)
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 20)
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_cards_row)


func _on_offer(choices: Array, offer_index: int, total_offers: int) -> void:
	if choices.is_empty():
		return
	_offered = choices
	_subtitle.text = tr("Lasts this battle only  ·  offer %d of %d") % [offer_index, total_offers]

	for child in _cards_row.get_children():
		child.queue_free()

	var first: Button = null
	for upgrade in choices:
		var card := _make_card(upgrade)
		_cards_row.add_child(card)
		if first == null:
			first = card

	PirateThemeBuilder.apply_button_juice(_cards_row)
	show()
	UIMotion.modal_enter(_panel, _dim)
	get_tree().paused = true
	if first:
		first.grab_focus()


## One upgrade = one tappable BoardTile card: the authored glyph, the name
## in ink Germania and the effect line. The children ignore the mouse so the
## whole card is the touch target.
func _make_card(upgrade: BattleUpgradeData) -> Button:
	var card := Button.new()
	card.theme_type_variation = &"BoardTile"
	card.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_CARD_SIZE)
	card.tooltip_text = upgrade.describe()
	card.pressed.connect(_on_card_pressed.bind(upgrade))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_top = 14
	v.offset_right = -14
	v.offset_bottom = -14
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var glyph := Label.new()
	glyph.text = upgrade.icon
	glyph.theme_type_variation = &"InkTitleLabel"
	glyph.add_theme_font_size_override("font_size", UITokens.FONT_DISPLAY)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(glyph)
	var name_lbl := Label.new()
	name_lbl.text = upgrade.display_name
	name_lbl.theme_type_variation = &"InkTitleLabel"
	name_lbl.add_theme_font_size_override("font_size", UITokens.FONT_HUD_NUM)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_lbl)
	var desc := Label.new()
	desc.text = upgrade.describe()
	desc.theme_type_variation = &"ChipLabel"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	for child in v.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _on_card_pressed(upgrade: BattleUpgradeData) -> void:
	if _encounter_manager and _encounter_manager.has_method("apply_upgrade_choice"):
		_encounter_manager.apply_upgrade_choice(upgrade)
	upgrade_chosen.emit(upgrade)
	# A confirmed battle-upgrade pick is a meaningful player-visible success —
	# one short reward pulse via the central gateway (HapticFeedbackManager is
	# a no-op on PC and when the player's toggle is off).
	HapticFeedbackManager.reward()
	_close()


func _on_encounter_ended(_victory: bool, _rewards: Dictionary) -> void:
	if visible:
		_close()


func _close() -> void:
	hide()
	_offered.clear()
	get_tree().paused = false

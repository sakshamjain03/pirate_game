class_name PrizeLedger extends Control

## Purpose: the choice after a ship's colours come down (M30 2.8): Keep her, Ransom the
##   officers, or Break her up for salvage.
## Responsibilities: opens on `BoardingSystem.boarding_outcome` for a Colours outcome that
##   actually captured a hull, shows what each choice costs and pays (from `PrizeOffers`), applies
##   the pick, and closes. The tree is paused while it is open and there is no way to dismiss it
##   without choosing, so the taken ship is never left in limbo.
## Dependencies: PrizeOffers (what is offered and what a pick does), BoardingSystem.
## Note: opened AFTER the BoardingOverlay has closed (it closes before it resolves), so the two
##   modals never overlap and this one's pause is the only one standing.

signal choice_made(choice: int, result: Dictionary)

const AUTOSAVE_HOLD := &"prize_ledger"
const FONT_TITLE := 40
const FONT_CARD_TITLE := 30
const FONT_CARD_BODY := 22

var record: Dictionary = {}
var offers: Array[Dictionary] = []
var is_open: bool = false

var _system: BoardingSystem = null
var _player: Node = null
var _dim: ColorRect
var _panel: PanelContainer
var _subtitle: Label
var _cards_row: HBoxContainer


func _ready() -> void:
	# Must keep processing while the tree is paused, same as UpgradeChoiceScreen/DeathScreen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	_build()
	hide()


func _exit_tree() -> void:
	if is_open:
		is_open = false
		SaveManager.hold_autosave(AUTOSAVE_HOLD, false)
		if is_inside_tree():
			get_tree().paused = false


func bind_boarding_system(system: BoardingSystem) -> void:
	_system = system
	if system and not system.boarding_outcome.is_connected(_on_boarding_outcome):
		system.boarding_outcome.connect(_on_boarding_outcome)


func _on_boarding_outcome(outcome_id: String, details: Dictionary) -> void:
	if SceneManager and not SceneManager.is_campaign():
		return
	var rec := PrizeOffers.record_from_outcome(outcome_id, details)
	if rec.is_empty():
		return
	var players := get_tree().get_nodes_in_group("player_ship")
	open(rec, players[0] if players.size() > 0 else null)


func open(prize_record: Dictionary, player: Node = null) -> void:
	if is_open:
		return
	var built := PrizeOffers.build(prize_record)
	if built.is_empty():
		return
	record = prize_record
	offers = built
	_player = player
	_subtitle.text = _ship_title()
	_rebuild_cards()
	is_open = true
	SaveManager.hold_autosave(AUTOSAVE_HOLD, true)  # the taken ship exists only in this modal until a pick
	show()
	UIMotion.modal_enter(_panel, _dim)
	get_tree().paused = true


## Applies a choice and closes. A choice that is not open does nothing (the modal stays).
func choose(choice: int) -> void:
	if not is_open:
		return
	var result := PrizeOffers.apply(choice, record, _player)
	if not bool(result.get("ok", false)):
		return
	is_open = false
	SaveManager.hold_autosave(AUTOSAVE_HOLD, false)
	hide()
	get_tree().paused = false
	choice_made.emit(choice, result)


func offer_for(choice: int) -> Dictionary:
	for o in offers:
		if int(o["choice"]) == choice:
			return o
	return {}


# === Building ===

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	PirateThemeBuilder.dress_modal_dim(_dim)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"WoodFramePanel"
	centre.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	var title := Label.new()
	title.text = tr("The Colours Come Down")
	title.theme_type_variation = &"DisplayLabel"
	title.add_theme_font_size_override("font_size", FONT_TITLE)
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
	_cards_row.name = "Cards"
	_cards_row.add_theme_constant_override("separation", 14)
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_cards_row)


func _ship_title() -> String:
	var hull := PrizeOffers.is_enemy_only(str(record.get("ship_id", "")))
	var name_text := str(record.get("ship_id", "")).capitalize().replace("_", " ")
	var found := ResourceLookup.find_by_id(PrizeOffers.SHIPS_DIR, "ship_id", str(record.get("ship_id", ""))) as ShipStats
	if found and not found.display_name.is_empty():
		name_text = found.display_name
	var faction_part := ""
	if not str(record.get("faction_id", "")).is_empty():
		faction_part = "  ·  " + str(record["faction_id"]).capitalize().replace("_", " ")
	return "%s%s%s" % [name_text, faction_part, ("  ·  " + tr("enemy-built")) if hull else ""]


func _rebuild_cards() -> void:
	for c in _cards_row.get_children():
		_cards_row.remove_child(c)
		c.queue_free()
	var first: Button = null
	for o in offers:
		var card := _make_card(o)
		_cards_row.add_child(card)
		if first == null and not card.disabled:
			first = card
	PirateThemeBuilder.apply_button_juice(_cards_row)
	if first and is_inside_tree():
		first.grab_focus()


func card_title(choice: int) -> String:
	match choice:
		PrizeOffers.Choice.KEEP:
			return tr("Keep Her")
		PrizeOffers.Choice.RANSOM:
			return tr("Ransom the Officers")
		PrizeOffers.Choice.BREAK:
			return tr("Break Her Up")
	return ""


func card_body(o: Dictionary) -> String:
	if not bool(o["available"]):
		return tr(str(o["reason"]))
	match int(o["choice"]):
		PrizeOffers.Choice.KEEP:
			return tr("A prize crew sails her home. She joins your fleet at your next dock, damaged.\n%d%% she is retaken on the way. Costs %d%% of your crew.") % [
				roundi(float(o["chance"]) * 100.0), roundi(float(o["crew_fraction"]) * 100.0)]
		PrizeOffers.Choice.RANSOM:
			return tr("Her officers are bought back.\n+%d gold, +%d standing with their flag.") % [int(o["gold"]), int(o["reputation"])]
		PrizeOffers.Choice.BREAK:
			return tr("Stripped for timber and iron.\n+%d wood, +%d iron. Word gets around.") % [int(o["wood"]), int(o["iron"])]
	return ""


func _make_card(o: Dictionary) -> Button:
	var choice := int(o["choice"])
	var card := Button.new()
	card.name = "Card_%s" % PrizeOffers.Choice.keys()[choice].capitalize()
	card.theme_type_variation = &"BoardTile"
	card.custom_minimum_size = Vector2(460, 250)
	card.disabled = not bool(o["available"])
	card.pressed.connect(choose.bind(choice))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_top = 16
	v.offset_right = -16
	v.offset_bottom = -16
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var name_lbl := Label.new()
	name_lbl.text = card_title(choice)
	name_lbl.theme_type_variation = &"InkTitleLabel"
	name_lbl.add_theme_font_size_override("font_size", FONT_CARD_TITLE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)
	var body := Label.new()
	body.name = "Body"
	body.text = card_body(o)
	body.theme_type_variation = &"InkTitleLabel"
	body.add_theme_font_size_override("font_size", FONT_CARD_BODY)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)
	return card

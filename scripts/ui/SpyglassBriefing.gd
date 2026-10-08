class_name SpyglassBriefing extends Control

## Purpose: the Spyglass Briefing (M30 1.9, W1-2.1) — the read before a fight.
## Responsibilities: when an encounter starts, show the enemy roster as role
##   icons plus whatever intel the player's Watchtower buys (formation,
##   weaknesses, the star-2 hint), let the player pick an opening ammo per side
##   and 1 of 3 Preparations, hand the pick to EncounterManager, unpause.
## Dependencies: EncounterManager (`build_briefing()`/`apply_briefing()`, the
##   only place the data and the effects live), PirateThemeBuilder.
##
## Built in code like UpgradeChoiceScreen (the roster and gating vary per
## fight). Pauses the tree while open, as every other modal here does, so the
## squad does not close in while the player reads.

signal briefing_confirmed(preparation: PreparationData, port_ammo: AmmoData, starboard_ammo: AmmoData)

const SIDES := ["port", "starboard"]

var _encounter_manager: Node = null
var _briefing: Dictionary = {}
var _preparation_index: int = 0
var _ammo_index := {"port": 0, "starboard": 0}

var _panel: PanelContainer
var _dim: ColorRect
var _title: Label
var _intel: Label
var _roster: Label
var _formation: Label
var _weaknesses: Label
var _star_hint: Label
var _ammo_buttons := {}
var _prep_row: HBoxContainer
var _prep_buttons: Array[Button] = []
var _engage: Button

const _PREP_SIZE := Vector2(200, 185)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	_build()
	hide()


func bind_encounter_manager(mgr: Node) -> void:
	_encounter_manager = mgr
	if not mgr:
		return
	if mgr.has_signal("encounter_started") and not mgr.encounter_started.is_connected(_on_encounter_started):
		mgr.encounter_started.connect(_on_encounter_started)
	if mgr.has_signal("encounter_ended") and not mgr.encounter_ended.is_connected(_on_encounter_ended):
		# A fight that ends while the briefing is up must not leave it open.
		mgr.encounter_ended.connect(_on_encounter_ended)


func _on_encounter_started(_data) -> void:
	if _encounter_manager and _encounter_manager.has_method("build_briefing"):
		present(_encounter_manager.build_briefing())


func _on_encounter_ended(_victory: bool, _rewards: Dictionary) -> void:
	if visible:
		_close()


## Shows a briefing built by `EncounterManager.build_briefing()`.
func present(briefing: Dictionary) -> void:
	if briefing.is_empty():
		return
	_briefing = briefing
	_title.text = "%s — %s" % [briefing.get("kind", ""), briefing.get("title", "")]
	var level: int = int(briefing.get("intel_level", 0))
	_intel.text = tr("Watchtower Lv %d intel") % level if level > 0 else tr("No Watchtower — the glass shows only their sails")

	# One icon per hull; the role names collapse repeats ("Balanced ×4").
	var icons: PackedStringArray = []
	var role_counts := {}
	for entry in briefing.get("roster", []):
		icons.append(str(entry.get("icon", "?")))
		var role := str(entry.get("role", "")).capitalize()
		role_counts[role] = int(role_counts.get(role, 0)) + 1
	var roles: PackedStringArray = []
	for role in role_counts:
		roles.append(role if role_counts[role] == 1 else "%s ×%d" % [role, role_counts[role]])
	_roster.text = "%s   %s" % ["  ".join(icons), ", ".join(roles)]

	_formation.text = _gated_line(briefing, "formation", tr("Formation: %s"),
		tr("Loose order"), str(briefing.get("formation", "")))
	var weak: Array = briefing.get("weaknesses", [])
	_weaknesses.text = _gated_line(briefing, "weaknesses", "%s", tr("No weakness spotted"),
		"\n".join(PackedStringArray(weak)))
	_star_hint.text = _gated_line(briefing, "star_hint", tr("★★ %s"), tr("No star hint"),
		str(briefing.get("star_hint", "")))

	var options: Array = briefing.get("ammo_options", [])
	for side in SIDES:
		var current = briefing.get("%s_ammo" % side)
		_ammo_index[side] = maxi(options.find(current), 0)
		_refresh_ammo(side)

	for b in _prep_buttons:
		b.queue_free()
	_prep_buttons.clear()
	var preps: Array = briefing.get("preparations", [])
	for i in range(preps.size()):
		var card := _make_prep_card(preps[i], i)
		_prep_row.add_child(card)
		_prep_buttons.append(card)
	select_preparation(0)

	PirateThemeBuilder.apply_button_juice(_panel)
	show()
	UIMotion.modal_enter(_panel, _dim)
	get_tree().paused = true
	_engage.grab_focus()


func _gated_line(briefing: Dictionary, key: String, fmt: String, empty_text: String, value: String) -> String:
	if bool(briefing.get("%s_locked" % key, false)):
		return tr("Watchtower Lv %d reveals this") % int(briefing.get("%s_level" % key, 0))
	if value.is_empty():
		return empty_text
	return fmt % value if fmt.contains("%s") else value


func select_preparation(index: int) -> void:
	var preps: Array = _briefing.get("preparations", [])
	if preps.is_empty():
		_preparation_index = -1
		return
	_preparation_index = clampi(index, 0, preps.size() - 1)
	for i in range(_prep_buttons.size()):
		_prep_buttons[i].button_pressed = i == _preparation_index


func cycle_ammo(side: String) -> void:
	var options: Array = _briefing.get("ammo_options", [])
	if options.is_empty():
		return
	_ammo_index[side] = (int(_ammo_index[side]) + 1) % options.size()
	_refresh_ammo(side)


func get_selected_preparation() -> PreparationData:
	var preps: Array = _briefing.get("preparations", [])
	if _preparation_index < 0 or _preparation_index >= preps.size():
		return null
	return preps[_preparation_index]


func get_selected_ammo(side: String) -> AmmoData:
	var options: Array = _briefing.get("ammo_options", [])
	if options.is_empty():
		return null
	return options[int(_ammo_index[side]) % options.size()]


func confirm() -> void:
	var prep := get_selected_preparation()
	var port := get_selected_ammo("port")
	var starboard := get_selected_ammo("starboard")
	if _encounter_manager and _encounter_manager.has_method("apply_briefing"):
		_encounter_manager.apply_briefing(prep, port, starboard)
	briefing_confirmed.emit(prep, port, starboard)
	HapticFeedbackManager.reward()
	_close()


func _close() -> void:
	hide()
	_briefing = {}
	get_tree().paused = false


## Freed while open (the World unloading mid-briefing): never leave the whole
## tree paused behind it.
func _exit_tree() -> void:
	if visible and not _briefing.is_empty():
		_close()


func _refresh_ammo(side: String) -> void:
	var btn: Button = _ammo_buttons.get(side)
	if not btn:
		return
	var ammo := get_selected_ammo(side)
	btn.text = "%s: %s" % [tr("Port") if side == "port" else tr("Starboard"),
		ammo.display_name if ammo else "—"]


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

	# Two columns, so the whole card fits a phone-landscape screen (780 px
	# tall in the capture harness) with Engage on screen: the read on the
	# left, the choices on the right.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 24)
	col.add_child(header)
	var heading := Label.new()
	heading.text = tr("Spyglass")
	heading.theme_type_variation = &"DisplayLabel"
	header.add_child(heading)
	var chips := VBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(chips)
	_title = _chip(chips)
	_intel = _chip(chips)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	col.add_child(body)

	var page := PanelContainer.new()
	PirateThemeBuilder.dress_parchment_page(page)
	body.add_child(page)
	var intel := VBoxContainer.new()
	intel.alignment = BoxContainer.ALIGNMENT_CENTER
	intel.add_theme_constant_override("separation", 6)
	page.add_child(intel)
	_roster = _ink(intel, UITokens.FONT_SECTION)
	_formation = _ink(intel, UITokens.FONT_BODY)
	_weaknesses = _ink(intel, UITokens.FONT_BODY)
	_star_hint = _ink(intel, UITokens.FONT_BODY)

	var choices := VBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 10)
	body.add_child(choices)

	var ammo_row := HBoxContainer.new()
	ammo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ammo_row.add_theme_constant_override("separation", 12)
	choices.add_child(ammo_row)
	for side in SIDES:
		var b := Button.new()
		b.custom_minimum_size = PirateThemeBuilder.scaled_button_size(Vector2(300, 60))
		b.pressed.connect(cycle_ammo.bind(side))
		ammo_row.add_child(b)
		_ammo_buttons[side] = b

	_prep_row = HBoxContainer.new()
	_prep_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prep_row.add_theme_constant_override("separation", 12)
	choices.add_child(_prep_row)

	_engage = Button.new()
	_engage.text = tr("Engage")
	_engage.custom_minimum_size = PirateThemeBuilder.scaled_button_size(Vector2(320, 68))
	_engage.pressed.connect(confirm)
	PirateThemeBuilder.mark_primary(_engage)
	var engage_row := CenterContainer.new()
	engage_row.add_child(_engage)
	choices.add_child(engage_row)


func _chip(parent: Node) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"ChipLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _ink(parent: Node, size: int) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"InkTitleLabel"
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PirateThemeBuilder.scaled(560), 0)
	parent.add_child(l)
	return l


## One Preparation = one toggle card: glyph, name, effect line.
func _make_prep_card(prep: PreparationData, index: int) -> Button:
	var card := Button.new()
	card.theme_type_variation = &"BoardTile"
	card.toggle_mode = true
	card.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_PREP_SIZE)
	card.tooltip_text = prep.describe()
	card.pressed.connect(select_preparation.bind(index))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_top = 10
	v.offset_right = -10
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	for text in ["%s  %s" % [prep.icon, prep.display_name], prep.describe()]:
		var l := Label.new()
		l.text = text
		l.theme_type_variation = &"ChipLabel"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	return card

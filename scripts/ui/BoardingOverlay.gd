class_name BoardingOverlay extends Control

## Purpose: the Three Bells boarding screen (M30 2.5): the player spends 3 command points a
##   bell on the deck of the enemy ship their gunnery shaped, then the bell rings.
## Responsibilities:
##   - opens on `BoardingSystem.boarding_started`, pauses the tree and holds autosave while open,
##   - shows zones, defenders with their telegraphed next intent, outside threats as intents,
##     morale, the party's strength, CP and the bell timer,
##   - queues orders into the pure `BoardingBattle`, rings the bell (by hand or after
##     `bell_seconds`), shows what happened, and on the result hands it to
##     `BoardingSystem.resolve_tactical()`.
## Dependencies: BoardingSystem (battle + resolve), PirateThemeBuilder, UIMotion.
## Limitations: art is glyph discs only. `GLYPH_DIR/<id>.png` is the seam a real icon drops
##   into (docs/10_ASSET_REQUESTS.md); nothing else changes when one appears.
##
## The overlay closes (unpausing the tree) BEFORE it resolves the boarding: resolving can open
## the battle-upgrade screen, and a close that ran after it would unpause underneath that modal.

signal closed(outcome: Dictionary)

const GLYPH_DIR := "res://assets/ui/boarding/"
const AUTOSAVE_HOLD := &"boarding"
const ENEMY_DISC := Color(0.62, 0.2, 0.17)
const PARTY_DISC := Color(0.18, 0.42, 0.58)
const DISC_SIZE := 40
## The panel fills most of the 1688-wide canvas; a deck is four columns across.
const PANEL_WIDTH := 1580.0
const RIGHT_WIDTH := 500.0
const ZONE_MIN_WIDTH := 236.0
const FONT_NAME := 22
const FONT_INTENT := 21
const FONT_ZONE := 28
const MAX_LOG_LINES := 3

var battle: BoardingBattle = null
var is_open: bool = false
var selected_action: BoardingActionData = null

var _system: BoardingSystem = null
var _rules: BoardingData = null
var _target_name: String = ""
var _names: Dictionary = {}  ## defender uid -> display name (kept after they fall)
var _bell_clock: float = 0.0
var _log_lines: Array[String] = []
var _showing_result: bool = false

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _bell_label: Label
var _cp_label: Label
var _timer_bar: ProgressBar
var _morale_label: Label
var _morale_bar: ProgressBar
var _party_label: Label
var _party_bar: ProgressBar
var _zones_row: HBoxContainer
var _threat_row: HBoxContainer
var _action_row: GridContainer
var _queue_label: Label
var _undo_button: Button
var _log_label: Label
var _ring_button: Button
var _cut_button: Button
var _orders_box: VBoxContainer
var _result_box: VBoxContainer
var _result_label: Label
var _continue_button: Button


func _ready() -> void:
	# Must keep processing while the tree is paused, same as UpgradeChoiceScreen/DeathScreen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	_build()
	hide()


func _exit_tree() -> void:
	if is_open:
		_release()


func bind_boarding_system(system: BoardingSystem) -> void:
	_system = system
	if system and not system.boarding_started.is_connected(_on_boarding_started):
		system.boarding_started.connect(_on_boarding_started)


# === Opening and closing ===

func _on_boarding_started(enemy: Node) -> void:
	if is_open or _system == null or _system.battle == null:
		return
	battle = _system.battle
	_rules = _system.boarding_data
	_target_name = tr("Enemy")
	var dmg = enemy.get_node_or_null("ShipDamage") if is_instance_valid(enemy) else null
	if dmg and dmg.ship_stats and not dmg.ship_stats.display_name.is_empty():
		_target_name = dmg.ship_stats.display_name
	_names.clear()
	for d in battle.defenders:
		_names[d.uid] = d.label if not d.label.is_empty() \
				else (d.data.display_name if not d.data.display_name.is_empty() else str(d.data.id))
	_log_lines.clear()
	selected_action = null
	_showing_result = false
	_bell_clock = 0.0
	is_open = true
	get_tree().paused = true
	SaveManager.hold_autosave(AUTOSAVE_HOLD, true)
	show()
	_result_box.visible = false
	_refresh()
	UIMotion.modal_enter(_panel, _dim)
	_ring_button.grab_focus()


## Unpause and release autosave. Idempotent.
func _release() -> void:
	if not is_open:
		return
	is_open = false
	SaveManager.hold_autosave(AUTOSAVE_HOLD, false)
	if is_inside_tree():
		get_tree().paused = false


func _close() -> void:
	hide()
	_release()


# === Player input (also the test seam) ===

func select_action(action: BoardingActionData) -> void:
	if not is_open or _showing_result or battle == null:
		return
	if selected_action == action:
		selected_action = null
	elif action.target_rule == BoardingActionData.TargetRule.NONE:
		battle.queue_action(action)  # no target to pick: it goes straight on the list
		selected_action = null
	elif action.cp_cost <= battle.cp_left():
		selected_action = action
	_refresh()


func tap_defender(uid: int) -> void:
	if not is_open or _showing_result or battle == null:
		return
	var action := selected_action if selected_action != null else _default_action_for(uid)
	if action != null and battle.queue_action(action, uid):
		selected_action = null
	_refresh()


func tap_threat(index: int) -> void:
	if not is_open or _showing_result or battle == null:
		return
	var action := selected_action
	if action == null or action.target_rule != BoardingActionData.TargetRule.OUTSIDE_THREAT:
		action = _action_with_rule(BoardingActionData.TargetRule.OUTSIDE_THREAT)
	if action != null and battle.queue_action(action, index):
		selected_action = null
	_refresh()


func advance_to(zone: int) -> void:
	if not is_open or _showing_result or battle == null:
		return
	battle.queue_advance(zone)
	_refresh()


func undo() -> void:
	if not is_open or _showing_result or battle == null:
		return
	battle.unqueue_last()
	_refresh()


func ring() -> void:
	if not is_open or _showing_result or battle == null:
		return
	var events := battle.ring_bell()
	for e in events:
		_log_lines.append(describe_event(e))
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	selected_action = null
	_bell_clock = 0.0
	HapticFeedbackManager.tap()
	if battle.is_over():
		_show_result()
	else:
		_refresh()


func cut_loose() -> void:
	if not is_open or _showing_result or battle == null:
		return
	battle.retreat()
	_log_lines.append(tr("You cut the grapples."))
	_show_result()


## The result screen's Continue: close first (unpause), then pay out.
func finish() -> void:
	if not is_open or battle == null or not battle.is_over():
		return
	var outcome: Dictionary = battle.outcome
	var ratio := float(outcome.get("casualties", 0)) / maxf(float(battle.player_hp_start), 1.0)
	var loss: float = ratio * _rules.casualty_crew_fraction
	if str(outcome["id"]) in ["cut_loose", "repulsed"]:
		loss += _rules.cut_loose_crew_loss_fraction
	var details := {"rng": battle.rng, "loot_mult": float(outcome.get("loot_mult", 1.0)),
			"crew_loss_fraction": loss, "captures_ship": bool(outcome.get("captures_ship", false)),
			"officers_escaped": bool(outcome.get("officers_escaped", false)),
			"grants_elite_squad": bool(outcome.get("grants_elite_squad", false)),
			"captain_xp": int(outcome.get("captain_xp", 0)), "casualty_ratio": ratio,
			"no_quarter": battle.no_quarter}
	var system := _system
	_close()
	closed.emit(outcome)
	battle = null
	if system:
		system.resolve_tactical(str(outcome["id"]), bool(outcome["success"]), details)


func _process(delta: float) -> void:
	if not is_open or _showing_result or battle == null or _rules == null:
		return
	_bell_clock += delta
	if _timer_bar:
		_timer_bar.max_value = _rules.bell_seconds
		_timer_bar.value = _bell_clock
	if _bell_clock >= _rules.bell_seconds:
		ring()


func _default_action_for(uid: int) -> BoardingActionData:
	var d := battle.defender_by_uid(uid)
	if d == null or _rules == null:
		return null
	var want := BoardingActionData.TargetRule.DEFENDER_MELEE if d.zone == battle.projected_zone() \
			else BoardingActionData.TargetRule.DEFENDER_RANGED
	for a in _rules.actions:
		if a.target_rule == want and a.damage > 0:
			return a
	return null


func _action_with_rule(rule: int) -> BoardingActionData:
	for a in _rules.actions:
		if a.target_rule == rule:
			return a
	return null


# === The result ===

func _show_result() -> void:
	_showing_result = true
	var outcome: Dictionary = battle.outcome
	_result_label.text = result_text(outcome)
	_result_box.visible = true
	_refresh()
	_continue_button.grab_focus()
	if outcome.get("success", false):
		HapticFeedbackManager.reward()


func result_text(outcome: Dictionary) -> String:
	match str(outcome.get("id", "")):
		"colours":
			return tr("The colours come down. The ship is yours.")
		"struck":
			return tr("They strike their colours!")
		"hold":
			return tr("The hold is yours. Cargo seized.")
		"brig":
			return tr("The brig is broken open. The prisoners swear to you.")
		"cabin":
			return tr("The great cabin is yours. The officers' papers, and the strongbox.")
		"magazine":
			return tr("The magazine goes up. Nothing left to take.")
		"repulsed":
			return tr("Your boarders are driven back.")
		"cut_loose":
			return tr("You cut loose. The grapples part.")
	return tr("The boarding is over.")


## One short line per event, for the log under the deck.
func describe_event(e: Dictionary) -> String:
	var who: String = str(_names.get(int(e.get("defender", -1)), tr("A defender")))
	match str(e["type"]):
		"hit":
			return tr("%s takes %d.") % [who, int(e["damage"])]
		"defender_down":
			return tr("%s falls. Morale %d.") % [who, int(e["morale"])]
		"party_hit":
			return tr("%s hits your boarders for %d.") % [who, int(e["damage"])]
		"whiff":
			return tr("%s swings at nothing.") % who
		"intent_cancelled":
			return tr("%s is stopped.") % who
		"intent_fizzled":
			return tr("%s's move is spoiled.") % who
		"pushed":
			return tr("%s is shoved back.") % who
		"guarding":
			return tr("%s takes cover.") % who
		"rally":
			return tr("%s rallies the crew. Morale %d.") % [who, int(e["morale"])]
		"charge":
			return tr("%s charges.") % who
		"advance":
			return tr("Your boarders push on to the %s.") % tr(BoardingZone.NAMES[int(e["to"])])
		"advance_blocked":
			return tr("The way is blocked.")
		"outside_fire":
			return tr("Outside guns hit you for %d.") % int(e["damage"])
		"outside_hit":
			return tr("The escort is sunk.") if e.get("sunk", false) else tr("The escort is hit.")
		"guard":
			return tr("You brace against the outside guns.")
		"jettison":
			return tr("They are heaving cargo overboard!")
		"officers_escape":
			return tr("The officers slip away in a boat!")
		"fizzle":
			return tr("The order finds nothing.")
	return ""


# === Building and refreshing ===

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
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	centre.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)

	# Header: title, bell, CP.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	_title = Label.new()
	_title.theme_type_variation = &"DisplayLabel"
	_title.add_theme_font_size_override("font_size", UITokens.FONT_SECTION)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_bell_label = _chip(head)
	_cp_label = _chip(head)

	_timer_bar = ProgressBar.new()
	_timer_bar.name = "BellTimer"
	_timer_bar.custom_minimum_size = Vector2(0, 6)
	_timer_bar.show_percentage = false
	col.add_child(_timer_bar)

	# Meters: one line each, label beside its bar.
	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 24)
	col.add_child(meters)
	_morale_label = _chip(null)
	_morale_bar = _meter(meters, _morale_label, "MoraleBar")
	_party_label = _chip(null)
	_party_bar = _meter(meters, _party_label, "PartyBar")

	# Body: the deck on the left, the player's orders on the right.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	col.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	var page := PanelContainer.new()
	PirateThemeBuilder.dress_parchment_page(page)
	left.add_child(page)
	var deck_col := VBoxContainer.new()
	deck_col.add_theme_constant_override("separation", 8)
	page.add_child(deck_col)
	_zones_row = HBoxContainer.new()
	_zones_row.name = "Zones"
	_zones_row.add_theme_constant_override("separation", 10)
	deck_col.add_child(_zones_row)
	_threat_row = HBoxContainer.new()
	_threat_row.name = "Threats"
	_threat_row.add_theme_constant_override("separation", 10)
	deck_col.add_child(_threat_row)
	_log_label = Label.new()
	_log_label.name = "Log"
	_log_label.theme_type_variation = &"ChipLabel"
	_log_label.add_theme_font_size_override("font_size", FONT_INTENT)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_log_label)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_WIDTH, 0)
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)

	_orders_box = VBoxContainer.new()
	_orders_box.name = "Orders"
	_orders_box.add_theme_constant_override("separation", 6)
	right.add_child(_orders_box)
	_action_row = GridContainer.new()
	_action_row.name = "Actions"
	_action_row.columns = 2
	_action_row.add_theme_constant_override("h_separation", 6)
	_action_row.add_theme_constant_override("v_separation", 6)
	_orders_box.add_child(_action_row)
	_queue_label = Label.new()
	_queue_label.theme_type_variation = &"ChipLabel"
	_queue_label.add_theme_font_size_override("font_size", FONT_INTENT)
	_queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_queue_label.custom_minimum_size = Vector2(0, 84)
	_orders_box.add_child(_queue_label)
	var order_buttons := HBoxContainer.new()
	order_buttons.add_theme_constant_override("separation", 6)
	_orders_box.add_child(order_buttons)
	_undo_button = _button(order_buttons, "Undo", tr("Undo"), undo)
	_cut_button = _button(order_buttons, "CutLoose", tr("Cut Loose"), cut_loose)
	_ring_button = _button(_orders_box, "RingBell", tr("Ring the Bell"), ring)

	_result_box = VBoxContainer.new()
	_result_box.name = "Result"
	_result_box.add_theme_constant_override("separation", 8)
	right.add_child(_result_box)
	_result_label = Label.new()
	_result_label.theme_type_variation = &"DisplayLabel"
	_result_label.add_theme_font_size_override("font_size", FONT_ZONE)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_box.add_child(_result_label)
	_continue_button = _button(_result_box, "Continue", tr("Continue"), finish)


## A small light label on the wood frame.
func _chip(parent: Node) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"ChipLabel"
	l.add_theme_font_size_override("font_size", FONT_INTENT)
	if parent:
		parent.add_child(l)
	return l


## "Label  [bar]" on one line, taking an even share of the row.
func _meter(row: HBoxContainer, label: Label, bar_name: String) -> ProgressBar:
	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	h.add_child(label)
	var bar := ProgressBar.new()
	bar.name = bar_name
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	return bar


func _button(parent: Node, node_name: String, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", UITokens.FONT_CHIP)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _refresh() -> void:
	if battle == null or _rules == null:
		return
	_title.text = tr("Boarding — %s") % _target_name
	if not battle.hero.is_empty():
		_title.text += "  ·  " + tr("%s leads the boarding") % str(battle.hero.get("name", tr("The captain")))
	if battle.no_quarter:
		_title.text += "  ·  " + tr("No quarter")
	_bell_label.text = tr("Bell %d of %d") % [battle.bell, battle.bells_total]
	_cp_label.text = tr("CP %d / %d") % [battle.cp_left(), battle.cp]
	_morale_bar.max_value = BoardingBattle.MORALE_MAX
	_morale_bar.value = battle.morale
	_morale_label.text = tr("Morale %d (strikes at %d)") % [battle.morale, _rules.strike_morale]
	_party_bar.max_value = maxf(float(battle.player_hp_start), 1.0)
	_party_bar.value = maxf(float(battle.player_hp), 0.0)
	_party_label.text = tr("Boarders %d / %d") % [maxi(battle.player_hp, 0), battle.player_hp_start]

	_rebuild_zones()
	_rebuild_threats()
	_rebuild_actions()
	_queue_label.text = _queue_text()
	_undo_button.disabled = battle.queued_count() == 0 or _showing_result
	_ring_button.disabled = _showing_result
	_cut_button.disabled = _showing_result
	_log_label.text = "\n".join(_log_lines)
	_result_box.visible = _showing_result
	_orders_box.visible = not _showing_result
	PirateThemeBuilder.apply_button_juice(_panel)


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _planned_damage() -> Dictionary:
	var planned := {}
	for q in battle.queued():
		if q["kind"] == "action":
			var a: BoardingActionData = q["action"]
			planned[int(q["target"])] = int(planned.get(int(q["target"]), 0)) + a.damage
	return planned


func _cancelled_uids() -> Dictionary:
	var out := {}
	for q in battle.queued():
		if q["kind"] == "action" and (q["action"] as BoardingActionData).cancels_intent:
			out[int(q["target"])] = true
	return out


func _rebuild_zones() -> void:
	_clear(_zones_row)
	var here := battle.projected_zone()
	var planned := _planned_damage()
	var cancelled := _cancelled_uids()
	for z in BoardingZone.COUNT:
		var v := VBoxContainer.new()
		v.name = "Zone_%s" % BoardingZone.NAMES[z]
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.custom_minimum_size = Vector2(ZONE_MIN_WIDTH, 0)  # equal columns whatever they hold
		v.add_theme_constant_override("separation", 6)
		_zones_row.add_child(v)
		var title := Label.new()
		title.theme_type_variation = &"InkTitleLabel"
		title.add_theme_font_size_override("font_size", FONT_ZONE)
		var text: String = tr(BoardingZone.NAMES[z])
		if z == here:
			text += "  ◀"
		title.text = text
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.clip_text = true
		v.add_child(title)
		for o in _objectives_in(z):
			var goal := Label.new()
			goal.theme_type_variation = &"InkTitleLabel"
			goal.add_theme_font_size_override("font_size", FONT_INTENT)
			goal.text = "★ " + tr(o.display_name)
			goal.tooltip_text = tr(o.display_name)
			goal.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			goal.clip_text = true
			v.add_child(goal)
		for d in battle.defenders_in(z):
			v.add_child(_make_defender_tile(d, planned, cancelled))
		if BoardingZone.are_adjacent(here, z) and not _showing_result:
			var go := Button.new()
			go.name = "Advance_%s" % BoardingZone.NAMES[z]
			go.text = tr("Advance ▸")
			go.clip_text = true
			go.add_theme_font_size_override("font_size", UITokens.FONT_CHIP)
			go.disabled = not battle.can_advance(z)
			go.pressed.connect(advance_to.bind(z))
			v.add_child(go)


func _objectives_in(z: int) -> Array[BoardingObjectiveData]:
	var out: Array[BoardingObjectiveData] = []
	for o in battle.objectives:
		if o.zone == z:
			out.append(o)
	return out


func _make_defender_tile(d: BoardingBattle.DefenderState, planned: Dictionary, cancelled: Dictionary) -> Button:
	var tile := Button.new()
	tile.name = "Defender_%d" % d.uid
	tile.theme_type_variation = &"BoardTile"
	tile.custom_minimum_size = Vector2(0, 84)
	tile.clip_contents = true
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.tooltip_text = _intent_text(d, cancelled)
	if selected_action != null:
		tile.disabled = not battle.can_queue(selected_action, d.uid)
	tile.pressed.connect(tap_defender.bind(d.uid))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_top = 8
	h.offset_right = -8
	h.offset_bottom = -8
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	tile.add_child(h)
	h.add_child(_make_disc(d.data.id, d.data.glyph, ENEMY_DISC))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	var hp_lbl := Label.new()
	hp_lbl.theme_type_variation = &"InkTitleLabel"
	hp_lbl.add_theme_font_size_override("font_size", FONT_NAME)
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_lbl.text = "%d/%d" % [d.hp, d.data.hp]
	if planned.has(d.uid):
		hp_lbl.text += " −%d" % int(planned[d.uid])
	var name_lbl := Label.new()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.text = str(_names.get(d.uid, ""))
	name_lbl.theme_type_variation = &"InkTitleLabel"
	name_lbl.add_theme_font_size_override("font_size", FONT_NAME)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(name_lbl)
	top.add_child(hp_lbl)
	var intent_lbl := Label.new()
	intent_lbl.name = "Intent"
	intent_lbl.text = _intent_text(d, cancelled)
	intent_lbl.theme_type_variation = &"InkTitleLabel"
	intent_lbl.add_theme_font_size_override("font_size", FONT_INTENT)
	intent_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	intent_lbl.clip_text = true
	intent_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(intent_lbl)
	return tile


## "Next: Slash 2" — the telegraph. A queued Parry shows the blow as stopped.
func _intent_text(d: BoardingBattle.DefenderState, cancelled: Dictionary) -> String:
	var intent := d.next_intent()
	if intent == null:
		return tr("No move")
	if cancelled.has(d.uid):
		return tr("Next: %s — stopped") % tr(intent.display_name)
	match intent.kind:
		DefenderIntentData.Kind.STRIKE, DefenderIntentData.Kind.SHOOT:
			var amount := d.data.attack + intent.power
			var in_reach := intent.kind == DefenderIntentData.Kind.SHOOT or d.zone == battle.zone
			return tr("Next: %s %d") % [tr(intent.display_name), amount] if in_reach \
					else tr("Next: %s (out of reach)") % tr(intent.display_name)
		DefenderIntentData.Kind.RALLY:
			return tr("Next: %s +%d morale") % [tr(intent.display_name), intent.power]
	return tr("Next: %s") % tr(intent.display_name)


func _rebuild_threats() -> void:
	_clear(_threat_row)
	var any := false
	for i in battle.outside_threats.size():
		var t: Dictionary = battle.outside_threats[i]
		if int(t["hp"]) <= 0:
			continue
		any = true
		var tile := Button.new()
		tile.name = "Threat_%d" % i
		tile.theme_type_variation = &"BoardTile"
		tile.custom_minimum_size = Vector2(0, 60)
		tile.add_theme_font_size_override("font_size", FONT_INTENT)
		tile.clip_text = true
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var planned := 0
		for q in battle.queued():
			if q["kind"] == "action" and (q["action"] as BoardingActionData).target_rule == \
					BoardingActionData.TargetRule.OUTSIDE_THREAT and int(q["target"]) == i:
				planned += (q["action"] as BoardingActionData).damage
		tile.text = tr("%s — hull %d%s — fires %d next bell") % [
			str(t["name"]), int(t["hp"]), (" (−%d)" % planned) if planned > 0 else "", int(t["damage"])]
		if selected_action != null:
			tile.disabled = not battle.can_queue(selected_action, i)
		tile.pressed.connect(tap_threat.bind(i))
		_threat_row.add_child(tile)
	_threat_row.visible = any


func _rebuild_actions() -> void:
	_clear(_action_row)
	for a in _rules.actions:
		var b := Button.new()
		b.name = "Action_%s" % a.id
		b.text = "%s %s  (%d)" % [a.glyph, tr(a.display_name), a.cp_cost]
		b.toggle_mode = true
		b.button_pressed = selected_action == a
		b.disabled = _showing_result or a.cp_cost > battle.cp_left()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", UITokens.FONT_CHIP)
		b.pressed.connect(select_action.bind(a))
		_action_row.add_child(b)


func _queue_text() -> String:
	var parts: Array[String] = []
	for q in battle.queued():
		if q["kind"] == "advance":
			parts.append(tr("Advance ▸ %s") % tr(BoardingZone.NAMES[int(q["to"])]))
		else:
			var a: BoardingActionData = q["action"]
			var target := ""
			match a.target_rule:
				BoardingActionData.TargetRule.DEFENDER_MELEE, BoardingActionData.TargetRule.DEFENDER_RANGED:
					target = " → " + str(_names.get(int(q["target"]), "?"))
				BoardingActionData.TargetRule.OUTSIDE_THREAT:
					target = " → " + tr("escort")
			parts.append(tr(a.display_name) + target)
	if parts.is_empty():
		return tr("Pick a verb and a target — or tap a man to strike him. Orders resolve when the bell rings.")
	return tr("Queued: ") + "  ·  ".join(parts)


## A glyph in a coloured disc. A real icon dropped at GLYPH_DIR/<id>.png replaces the glyph
## with no code change.
func _make_disc(id: StringName, glyph: String, tint: Color) -> Control:
	var disc := PanelContainer.new()
	disc.custom_minimum_size = Vector2(DISC_SIZE, DISC_SIZE)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.set_corner_radius_all(DISC_SIZE)
	sb.set_border_width_all(2)
	sb.border_color = UITokens.palette().ink
	disc.add_theme_stylebox_override("panel", sb)
	var icon_path := "%s%s.png" % [GLYPH_DIR, id]
	if ResourceLoader.exists(icon_path):
		var tex := TextureRect.new()
		tex.texture = load(icon_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.add_child(tex)
	else:
		var lbl := Label.new()
		lbl.text = glyph
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_color_override("font_color", Color.WHITE)
		disc.add_child(lbl)
	return disc

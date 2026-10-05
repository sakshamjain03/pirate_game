extends CanvasLayer

## Purpose: Provides on-screen virtual buttons for mobile devices.
## Responsibilities: Injects action events into the Input map when virtual buttons are pressed.

## Icons for the sail/anchor buttons, loaded directly from their .svg source
## at runtime instead of via a scene ext_resource. They were added in the same
## change as this script, so no editor session has generated their .import
## cache yet — ResourceLoader.load() fails on an un-imported file, while
## Image.load_svg_from_string() rasterizes raw SVG text with no import step,
## the same way it will forever (this isn't a workaround to later remove).
## Every other MobileControls icon still goes through the normal import path.
const _CUSTOM_ICON_PATHS := {
	"sail_up": "res://assets/icons/controls/sail_level_up.svg",
	"set_sail": "res://assets/icons/controls/action_set_sail.svg",
	"anchor": "res://assets/icons/controls/action_anchor.svg",
}

@onready var btn_left = %BtnLeft
@onready var btn_right = %BtnRight
@onready var btn_fire_port = %BtnFirePort
@onready var btn_fire_star = %BtnFireStar
@onready var btn_dock = %BtnDock
@onready var btn_pause = %BtnPause
@onready var btn_captain_ability = %BtnCaptainAbility
@onready var btn_special_broadside = %BtnSpecialBroadside
@onready var btn_set_sail = %BtnSetSail
@onready var btn_anchor = %BtnAnchor

## Desktop test runners cannot advertise a phone OS feature. This keeps the
## phone composition independently testable without changing a real build.
@export var force_mobile_layout_for_test: bool = false

var _context_action: Button
var _dock_available := false
var _board_available := false
var _context_action_name := ""
var _advanced_buttons_wired := false
var _sail_control: Button
var _port_alignment_label: Label
var _stbd_alignment_label: Label

## M22 Phase 5.3 — every on-screen control except the context action is a
## round wood button (v0.3's right-thumb cluster); the context action is the
## one wide pill, and the coral Primary only while it reads "Set Sail".
## Widths in canvas px; heights follow the art (round_button_size()).
const _ROUND_BIG := 150.0     # steering, sail, ability, broadside
const _ROUND_SMALL := 96.0    # pause — the 48dp floor, a utility not an action
## Sweep over a round button's face while its cooldown runs (5.4): dark ink,
## not a grey-out, so the icon under it stays legible (v0.3: "cooldown = dark
## conic sweep"). Purely visual — reads the existing cooldown fractions.
const _COOLDOWN_SWEEP_ALPHA := 0.62
var _cooldown_sweeps: Dictionary = {}

func _uses_mobile_layout() -> bool:
	# M22 (2026-09-25): OR in PirateThemeBuilder.is_mobile() the same way
	# SettingsMenu._uses_mobile_layout() already does — without it, a
	# --profile=phone UIScreenSweep run (which only sets
	# PirateThemeBuilder.force_mobile_scaling_for_test, a shared static, not
	# this per-instance @export) never showed the touch controls a real
	# phone does (design.md §8's "known harness gap").
	return force_mobile_layout_for_test or PirateThemeBuilder.is_mobile()

func _ready() -> void:
	# M15.5 — this CanvasLayer's own children never picked up
	# WorldHUD._apply_theme()'s theme (that loop only themes Control
	# children, and a CanvasLayer isn't one), so every button here rendered
	# as an unthemed default Godot button. Applied directly since a
	# CanvasLayer can't hold/propagate a Theme itself the way a Control does.
	var theme := PirateThemeBuilder.build()
	for child in get_children():
		if child is Control:
			child.theme = theme
	PirateThemeBuilder.apply_button_juice(self)

	# These are on-screen touch buttons — on desktop they just sit on top of
	# the HUD (overlapping HealthBarContainer).
	if not _uses_mobile_layout():
		visible = false
		return
	# These clusters used bottom/right anchors in the original PC-sized scene.
	# A phone layout is calculated from the safe rectangle, so normalise them to
	# local coordinates before assigning their positions.
	for cluster: Control in [$Movement, $Combat, $Actions]:
		cluster.set_anchors_preset(Control.PRESET_TOP_LEFT)
	MobileLayoutManager.layout_changed.connect(_apply_mobile_layout)
	get_viewport().size_changed.connect(_apply_mobile_layout)
	_apply_mobile_layout()

	# Sail speed is a state, not two unrelated actions. The old up/down scene
	# targets have been removed entirely; one large control cycles Furled → full
	# sail and back without leaving empty touch targets on screen.
	btn_dock.hide()
	btn_set_sail.hide()
	btn_anchor.hide()
	for button: Button in [btn_left, btn_right, btn_fire_port, btn_fire_star]:
		_make_round(button, _ROUND_BIG)
	# Positioning and automatic broadside are the default phone combat model.
	# Manual side-fire is a deliberate accessibility/preference opt-in.
	_apply_advanced_combat_controls()
	# On-screen steering is the default; tilt-to-steer is an opt-in that hides
	# the left/right buttons in favor of phone tilt (InputManager).
	_apply_tilt_steering()
	# Pause is a global utility, not a combat action. Pull it out of the lower
	# action cluster so it is compact and consistently reachable at top-right.
	btn_pause.reparent(self)
	# Reparenting under this CanvasLayer drops the theme it inherited from
	# Actions (a CanvasLayer can't hold one — see _ready()'s header), so the
	# WoodRoundButton variation silently fell back to the stock grey button.
	btn_pause.theme = theme
	_make_round(btn_pause, _ROUND_SMALL)
	# Same pause-gate fix as WorldHUD's captains_log_button/etc: without this,
	# the moment PauseMenu.open() sets get_tree().paused = true, this button
	# (inheriting process mode from the paused tree) stops receiving input —
	# so a second tap can never close the menu back, only Resume can.
	btn_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_create_sail_control()
	_create_context_action()
	_layout_primary_actions()
	_create_action_captions()
	_apply_mobile_layout()

	_setup_button(btn_left, "ship_left")
	_setup_button(btn_right, "ship_right")
	_setup_button(btn_pause, "pause")
	_setup_button(btn_captain_ability, "captain_ability")
	_setup_button(btn_special_broadside, "special_broadside")
	if SettingsManager.has_signal("settings_changed"):
		SettingsManager.settings_changed.connect(_apply_advanced_combat_controls)
		SettingsManager.settings_changed.connect(_apply_tilt_steering)
	_bind_ship_context()


## Gap kept between a cluster's true rendered bottom edge and the reference
## edge below it (the safe-area bottom, or the next cluster stacked on it).
## One number, reused everywhere a cluster is placed — not one hardcoded
## offset per cluster that can silently drift apart (see CLAUDE.md's
## documented "two independently hardcoded pixel offsets" failure mode).
## Combat/Actions/Movement previously used three unrelated safe.end.y offsets
## (420/580/680) that only "happened" not to overlap — Movement in particular
## sat ~300px of unscaled slack above the reachable bottom edge for no reason.
const _CLUSTER_EDGE_GAP := 24.0

func _measured_bottom(cluster: Control) -> float:
	# Local-space (unscaled) bottom edge of the lowest *visible* child — a
	# hidden fire-port/starboard button (advanced combat controls off) must
	# not reserve dead space in the cluster's placement.
	var max_bottom := 0.0
	for child in cluster.get_children():
		if child is Control and child.visible:
			max_bottom = maxf(max_bottom, child.position.y + child.size.y)
	return max_bottom

func _apply_mobile_layout() -> void:
	_layout_context_row()
	var safe := MobileLayoutManager.safe_area(get_viewport())
	var scale := maxf(0.55, MobileLayoutManager.mobile_scale(get_viewport()))
	var movement: Control = $Movement
	var combat: Control = $Combat
	var actions: Control = $Actions
	var action_width := 378.0 * scale
	var movement_width := 540.0 * scale
	var left_handed := MobileLayoutManager.is_left_handed()
	# The action cluster is on the dominant side; steering moves to the other.
	var action_x := safe.position.x + 16.0 if left_handed else safe.end.x - action_width - 16.0
	var movement_x := safe.end.x - movement_width - 16.0 if left_handed else safe.position.x + 16.0
	var actions_y := safe.end.y - _CLUSTER_EDGE_GAP * scale - _measured_bottom(actions) * scale
	var movement_y := safe.end.y - _CLUSTER_EDGE_GAP * scale - _measured_bottom(movement) * scale
	# Stacked ON Actions' own placed position, not an independent safe.end.y
	# budget — structurally cannot drift apart or overlap regardless of
	# either cluster's content height.
	var combat_y := actions_y - _CLUSTER_EDGE_GAP * scale - _measured_bottom(combat) * scale

	# A player's saved drag/resize customization (Settings > Customize HUD
	# Layout) is applied as a bounded delta on top of this clip-safe default —
	# never a replacement of it — so a customization can never reintroduce
	# the clipping/overlap this function exists to prevent.
	var vp := get_viewport()
	var actions_result := MobileLayoutManager.apply_control_override(
		"actions", Vector2(action_x, actions_y), scale, vp, Vector2(378.0, _measured_bottom(actions)))
	var movement_result := MobileLayoutManager.apply_control_override(
		"movement", Vector2(movement_x, movement_y), scale, vp, Vector2(540.0, _measured_bottom(movement)))
	var combat_result := MobileLayoutManager.apply_control_override(
		"combat", Vector2(action_x, combat_y), scale, vp, Vector2(378.0, _measured_bottom(combat)))
	actions.position = actions_result.position
	actions.scale = Vector2.ONE * float(actions_result.scale)
	movement.position = movement_result.position
	movement.scale = Vector2.ONE * float(movement_result.scale)
	combat.position = combat_result.position
	combat.scale = Vector2.ONE * float(combat_result.scale)
	# This is a starting position only — WorldHUD._apply_mobile_safe_area()
	# relocates it (currently: left side, under the health bar) right after it
	# lays out the panels this depends on, since that function, not this one,
	# knows their real on-screen bottom edges for the current device.
	var pause_size := PirateThemeBuilder.round_button_size(_ROUND_SMALL)
	btn_pause.position = Vector2(safe.end.x - pause_size.x * scale - 16.0, safe.position.y + 150.0 * scale)
	btn_pause.size = pause_size * scale
	_fit_combat_cluster()


## Top edge (canvas px) the Combat cluster must stay below: WorldHUD's
## TopRightPanel bottom, which only WorldHUD can measure. -INF = no limit.
var _combat_top_limit: float = -INF

## Called by WorldHUD._apply_mobile_safe_area() once it has laid out
## TopRightPanel. Stacking Combat on top of Actions from the bottom up (above)
## keeps those two apart, but on a short 19.5:9 phone the stack then reached up
## into the notoriety card: since M25 made the fire buttons always visible,
## their top edge sat under it. Stored as well as applied, so a later
## _apply_mobile_layout() (both passes run on every resize) re-applies it
## instead of undoing it.
func fit_combat_cluster_below(top_limit: float) -> void:
	_combat_top_limit = top_limit
	_fit_combat_cluster()


## Re-seats Combat so it clears _combat_top_limit. Preferred: stacked above
## Actions (the default layout), shrunk only as much as the band between the
## limit and Actions' top edge requires. On a 19.5:9 phone that band can be
## shorter than a fire button at the 48dp touch-target floor
## (docs/18_ACCESSIBILITY.md §6) — then Combat moves BESIDE Actions instead,
## bottom-aligned with the Ability/Broadside row, on the screen-centre side.
## WorldHUD._fit_tutorial_between_thumb_clusters() measures Combat's children,
## so the dialogue/lesson band narrows to match either placement.
func _fit_combat_cluster() -> void:
	if not _uses_mobile_layout() or _combat_top_limit == -INF:
		return
	var combat: Control = $Combat
	var actions: Control = $Actions
	var column_width := 378.0
	# Actions itself can reach the notoriety card on a 19.5:9 phone when the
	# card shows its bar (a few px into the context action / ammo row). Shrink
	# it, anchored at its bottom outer corner, just enough to clear — never
	# below the touch-target floor of its big round buttons.
	if actions.position.y < _combat_top_limit:
		var a_height := _measured_bottom(actions)
		# The floor comes from the cluster's SMALLEST button (the ammo button),
		# or shrinking to clear the panel would push it under 48dp.
		var a_side := minf(btn_captain_ability.size.x, btn_captain_ability.size.y)
		if _btn_ammo and is_instance_valid(_btn_ammo) and _btn_ammo.visible:
			a_side = minf(a_side, minf(_btn_ammo.size.x, _btn_ammo.size.y))
		if a_height > 0.0 and a_side > 0.0:
			var a_bottom := actions.position.y + a_height * actions.scale.y
			var a_right := actions.position.x + column_width * actions.scale.x
			var a_scale := clampf((a_bottom - _combat_top_limit) / a_height,
				PirateThemeBuilder.MOBILE_MIN_TOUCH_TARGET.x / a_side, actions.scale.x)
			actions.scale = Vector2.ONE * a_scale
			actions.position.y = a_bottom - a_height * a_scale
			if not MobileLayoutManager.is_left_handed():
				actions.position.x = a_right - column_width * a_scale
	if combat.position.y >= _combat_top_limit:
		return
	var height := _measured_bottom(combat)
	var width := _measured_right(combat)
	if height <= 0.0 or width <= 0.0:
		return
	var button_side := minf(btn_fire_port.size.x, btn_fire_port.size.y)
	var floor_scale := PirateThemeBuilder.MOBILE_MIN_TOUCH_TARGET.x / button_side if button_side > 0.0 else combat.scale.x
	var band_bottom := actions.position.y - _CLUSTER_EDGE_GAP * actions.scale.y
	var stacked_scale := minf((band_bottom - _combat_top_limit) / height, combat.scale.x)
	if stacked_scale >= floor_scale:
		combat.scale = Vector2.ONE * stacked_scale
		combat.position = Vector2(
			actions.position.x + (column_width * actions.scale.x - width * stacked_scale) * 0.5,
			band_bottom - height * stacked_scale)
		return
	var side_scale := maxf(floor_scale, minf(combat.scale.x, actions.scale.x * 0.7))
	var row_bottom: float = actions.position.y + (btn_captain_ability.position.y + btn_captain_ability.size.y) * actions.scale.y
	var gap := _CLUSTER_EDGE_GAP * actions.scale.x
	var x: float = actions.position.x - gap - width * side_scale
	if MobileLayoutManager.is_left_handed():
		x = actions.position.x + column_width * actions.scale.x + gap
	combat.scale = Vector2.ONE * side_scale
	combat.position = Vector2(x, row_bottom - height * side_scale)


## Local-space right edge of the widest visible child (the horizontal twin of
## _measured_bottom()).
func _measured_right(cluster: Control) -> float:
	var max_right := 0.0
	for child in cluster.get_children():
		if child is Control and child.visible:
			max_right = maxf(max_right, child.position.x + child.size.x)
	return max_right


func _layout_primary_actions() -> void:
	## The action cluster intentionally has four targets only: one contextual
	## world action, ability, broadside, and pause. This prevents six permanent
	## buttons from competing with moment-to-moment steering.
	# Matches Movement's 150x150 touch targets (_create_sail_control()) — these
	# were previously 180x120, noticeably shorter than the movement cluster's
	# buttons, reading as visibly smaller/less important despite serving
	# equally primary actions (device-test feedback 2026-09-20).
	# Same 378-wide column as the context action above them: two round
	# buttons centred in each half of it.
	var round_size := PirateThemeBuilder.round_button_size(_ROUND_BIG)
	for button: Button in [btn_captain_ability, btn_special_broadside]:
		_make_round(button, _ROUND_BIG)
	btn_captain_ability.position = Vector2((189.0 - round_size.x) * 0.5, 136)
	btn_special_broadside.position = Vector2(189.0 + (189.0 - round_size.x) * 0.5, 136)
	for button in [btn_pause, btn_captain_ability, btn_special_broadside]:
		_center_button_content(button)
	_add_cooldown_sweep("ability", btn_captain_ability)
	_add_cooldown_sweep("broadside", btn_special_broadside)
	_create_ammo_selector()


func _create_action_captions() -> void:
	## The ability/broadside icons alone gave no indication of what they do —
	## a small label under each, matching that button's own width, makes their
	## purpose legible without changing the icon buttons themselves.
	_create_caption_label(tr("Ability"), 0.0, 189.0)
	_create_caption_label(tr("Broadside"), 189.0, 189.0)
	_create_alignment_status_row()


func _create_alignment_status_row() -> void:
	## docs/navalCombat.md §5.2 — the pre-lock firing-arc/alignment feedback
	## WorldHUD shows on desktop via CannonsContainer. That container must
	## stay hidden on mobile (a real device test found it burying this very
	## cluster — see test_mobile_controls_layout.gd), so this mirrors the same
	## data as its own row here instead of attaching it to the Ability/
	## Broadside buttons above, which it has nothing to do with. Added below
	## the existing captions so _measured_bottom() folds its height into the
	## cluster-stacking math the rest of this file already relies on.
	var row_y: float = btn_captain_ability.position.y + btn_captain_ability.size.y + 4.0 + 36.0 + 4.0
	_port_alignment_label = Label.new()
	_port_alignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_port_alignment_label.position = Vector2(0.0, row_y)
	_port_alignment_label.size = Vector2(189.0, 64.0)
	_port_alignment_label.theme_type_variation = &"ChipLabel"
	# "STARBOARD: OUT OF RANGE" is wider than its 189px column at chip size;
	# the two used to overprint each other and run off the screen edge.
	_port_alignment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_port_alignment_label.text = tr("PORT: NO TARGET")
	$Actions.add_child(_port_alignment_label)

	_stbd_alignment_label = Label.new()
	_stbd_alignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stbd_alignment_label.position = Vector2(189.0, row_y)
	_stbd_alignment_label.size = Vector2(189.0, 64.0)
	_stbd_alignment_label.theme_type_variation = &"ChipLabel"
	# "STARBOARD: OUT OF RANGE" is wider than its 189px column at chip size;
	# the two used to overprint each other and run off the screen edge.
	_stbd_alignment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stbd_alignment_label.text = tr("STARBOARD: NO TARGET")
	$Actions.add_child(_stbd_alignment_label)


func update_alignment_caption(port_preview: Dictionary, stbd_preview: Dictionary, port_locked: bool, stbd_locked: bool) -> void:
	_apply_alignment_caption(_port_alignment_label, tr("PORT"), port_preview, port_locked)
	_apply_alignment_caption(_stbd_alignment_label, tr("STARBOARD"), stbd_preview, stbd_locked)


func _apply_alignment_caption(label: Label, side_name: String, preview: Dictionary, locked: bool) -> void:
	if not label:
		return
	if locked:
		label.text = "%s: ON TARGET" % side_name
		label.add_theme_color_override("font_color", UITokens.palette().hp_low)
	elif not preview.get("found", false):
		label.text = "%s: NO TARGET" % side_name
		label.add_theme_color_override("font_color", WorldHUD._hud_muted())
	elif not preview.get("in_range", false):
		label.text = "%s: OUT OF RANGE" % side_name
		label.add_theme_color_override("font_color", WorldHUD._hud_muted())
	else:
		var angle: float = preview.get("angle_off_deg", 180.0)
		label.text = "%s: %d°" % [side_name, int(ceil(angle))]
		label.add_theme_color_override("font_color", UITokens.palette().horizon_gold)


func _create_caption_label(caption: String, x: float, width: float) -> void:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(x, btn_captain_ability.position.y + btn_captain_ability.size.y + 4.0)
	label.size = Vector2(width, 36.0)
	label.theme_type_variation = &"ChipLabel"
	$Actions.add_child(label)


func _apply_advanced_combat_controls() -> void:
	# M25 — the fire buttons are now ALWAYS visible. They used to be hidden behind
	# `mobile_advanced_combat_controls` (default OFF) because auto-fire pulled the
	# trigger and per-side buttons were a power-user extra. Firing is the player's
	# action now, so leaving them gated would have shipped a mobile build with no
	# way to shoot at all. The setting no longer gates them; see
	# .kiro/specs/milestone-m25-heat-and-combat-feel/design.md.
	btn_fire_port.visible = true
	btn_fire_star.visible = true
	if not _advanced_buttons_wired:
		_setup_button(btn_fire_port, "fire_port")
		_setup_button(btn_fire_star, "fire_starboard")
		_advanced_buttons_wired = true


func _apply_tilt_steering() -> void:
	## Tilt-to-steer opt-in (Settings > Mobile Controls) hides the on-screen
	## left/right buttons in favor of phone tilt — InputManager.get_movement_vector()
	## reads the accelerometer instead of these actions' strength while it's on.
	var enabled := bool(SettingsManager.mobile_tilt_steering_enabled)
	btn_left.visible = not enabled
	btn_right.visible = not enabled


func _create_context_action() -> void:
	_context_action = Button.new()
	_context_action.name = "ContextAction"
	# Narrower than the 378 column by the ammo button's slot at the row's right
	# end (_create_ammo_selector), so the two share a row instead of overlapping.
	var width := 378.0 - _ammo_slot_width()
	_context_action.custom_minimum_size = Vector2(width, 120)
	_context_action.size = Vector2(width, 120)
	_context_action.tooltip_text = tr("Context Action")
	_center_button_content(_context_action)
	_context_action.pressed.connect(_on_context_action_pressed)
	$Actions.add_child(_context_action)
	_context_action.add_child(ButtonJuice.new())
	_refresh_context_action()


func set_dock_available(available: bool) -> void:
	_dock_available = available
	_refresh_context_action()


func set_board_available(available: bool) -> void:
	_board_available = available
	_refresh_context_action()


func _bind_ship_context() -> void:
	await get_tree().process_frame
	var ship := get_tree().get_first_node_in_group("player_ship")
	if ship:
		for signal_name in ["sail_level_changed", "anchor_dropped", "anchor_raised", "ship_docked", "ship_undocked"]:
			if ship.has_signal(signal_name):
				ship.connect(signal_name, _refresh_mobile_controls)
	_refresh_sail_control()
	_refresh_context_action()


func _refresh_mobile_controls(_unused = null, _unused_b = null) -> void:
	_refresh_sail_control()
	_refresh_context_action()


func _refresh_context_action(_unused = null, _unused_b = null) -> void:
	if not _context_action:
		return
	var ship := get_tree().get_first_node_in_group("player_ship")
	_context_action_name = ""
	# M30 0.20 — the verb (and so the label) comes from WorldManager's
	# arbiter, the same one that performs the press; every verb is sent as the
	# "dock" action. The board/dock flags are the fallback when no World
	# arbiter exists yet (scene start, or a test tree).
	var verb := _arbitrated_context_verb()
	if not verb.is_empty():
		_context_action_name = "dock"
		_context_action.text = tr(_context_verb_label(verb))
	elif ship and not bool(ship.get("is_docked")):
		if bool(ship.get("is_anchored")):
			_context_action_name = "anchor"
			_context_action.text = tr("Raise Anchor")
		elif int(ship.get("sail_level")) <= 0:
			_context_action_name = "set_sail"
			_context_action.text = tr("Set Sail")
		else:
			_context_action_name = "anchor"
			_context_action.text = tr("Drop Anchor")
	_context_action.visible = not _context_action_name.is_empty()
	# One Primary per screen (design.md §7): coral only for the hero "go"
	# moment, brass for the utility states (anchor, dock, board).
	if _context_action_name == "set_sail":
		PirateThemeBuilder.mark_primary(_context_action)
	else:
		PirateThemeBuilder.unmark_primary(_context_action)


func _arbitrated_context_verb() -> StringName:
	var wm := get_tree().get_first_node_in_group("world_manager") if is_inside_tree() else null
	if wm and wm.has_method("get_context_verb"):
		var verb: StringName = wm.get_context_verb()
		if not verb.is_empty():
			return verb
	for verb in ContextVerbArbiter.PRIORITY:
		if (verb == &"board" and _board_available) or (verb == &"dock" and _dock_available):
			return verb
	return &""


func _context_verb_label(verb: StringName) -> String:
	var wm := get_tree().get_first_node_in_group("world_manager")
	var label: String = wm.get_context_label(verb) if wm and wm.has_method("get_context_label") else ""
	if label.is_empty():
		label = "Board Enemy" if verb == &"board" else "Dock"
	return label


func _on_context_action_pressed() -> void:
	if _context_action_name.is_empty():
		return
	_inject_action(_context_action_name, true)
	_inject_action(_context_action_name, false)
	HapticFeedbackManager.tap()
	call_deferred("_refresh_mobile_controls")


func _create_sail_control() -> void:
	var sail := Button.new()
	sail.name = "SailControl"
	# Matches BtnLeft/BtnRight's 150x150 (down from 180x180) — the three-square
	# cluster read as oversized/heavy on a real device (device-test feedback
	# 2026-09-20). Centred in the 180px gap between the two 180-wide arrow
	# slots: 180 + (180-150)/2 = 195.
	_make_round(sail, _ROUND_BIG)
	sail.position = Vector2(195, 0)
	# Text makes the control meaningful even if an SVG import is unavailable on
	# a device. The old icon-only control rendered as an empty square.
	_center_button_content(sail)
	sail.tooltip_text = tr("Sail State")
	sail.pressed.connect(_cycle_sail_state)
	$Movement.add_child(sail)
	_sail_control = sail
	_refresh_sail_control()
	sail.add_child(ButtonJuice.new())


func _cycle_sail_state() -> void:
	var ship := get_tree().get_first_node_in_group("player_ship")
	if not ship or not ("sail_level" in ship) or not ship.ship_stats or not ship.has_method("adjust_sail_level"):
		return
	var levels: int = max(1, int(ship.ship_stats.sail_levels))
	var current: int = int(ship.sail_level)
	var target := (current + 1) % (levels + 1)
	# Applied directly rather than via repeated sail_level_up/down action
	# injection: WorldManager only applies those on Input.is_action_just_pressed,
	# polled once per _process() frame, so firing multiple press/release pairs
	# in this single call (no frame yield between them) collapsed to one
	# effective step. Invisible for a normal +1 step, but the max-level-back-
	# to-furled wrap needs several steps at once, so it silently only moved
	# one notch — the sail got stuck oscillating between the top two levels
	# and never made it back down to furled.
	ship.adjust_sail_level(target - current)
	HapticFeedbackManager.tap()
	call_deferred("_refresh_sail_control")


func _refresh_sail_control() -> void:
	if not _sail_control:
		return
	var ship := get_tree().get_first_node_in_group("player_ship")
	if not ship or not ship.ship_stats:
		_sail_control.text = tr("Sail")
		return
	_sail_control.text = "%s\n%d / %d" % [tr("Sail"), int(ship.sail_level), int(ship.ship_stats.sail_levels)]


func _make_round(button: Button, width: float) -> void:
	var round_size := PirateThemeBuilder.round_button_size(width)
	button.theme_type_variation = &"WoodRoundButton"
	button.custom_minimum_size = round_size
	button.size = round_size
	button.expand_icon = true


func _add_cooldown_sweep(kind: String, button: Button) -> void:
	## A clockwise TextureProgressBar over the button's face circle. The art
	## centres the face on the canvas and draws it at 116/128 of the width.
	var sweep := TextureProgressBar.new()
	sweep.name = "CooldownSweep"
	sweep.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	sweep.texture_progress = load(PirateThemeBuilder.TEX_COOLDOWN_DISC)
	var ink := UITokens.palette().ink
	sweep.tint_progress = Color(ink.r, ink.g, ink.b, _COOLDOWN_SWEEP_ALPHA)
	sweep.nine_patch_stretch = true
	sweep.min_value = 0.0
	sweep.max_value = 1.0
	sweep.step = 0.0
	sweep.value = 0.0
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var diameter := button.size.x * 116.0 / PirateThemeBuilder.ROUND_BUTTON_ART_SIZE.x
	sweep.size = Vector2(diameter, diameter)
	sweep.position = (button.size - sweep.size) * 0.5
	button.add_child(sweep)
	_cooldown_sweeps[kind] = sweep


## M22 Phase 5.4 — WorldHUD feeds the existing ready-fractions in (0 = just
## used, 1 = ready); the sweep shows what's LEFT, so a full dark disc right
## after use that unwinds clockwise to nothing as the button readies.
func set_cooldown_fraction(kind: String, ready_fraction: float) -> void:
	var sweep: TextureProgressBar = _cooldown_sweeps.get(kind)
	if not sweep:
		return
	sweep.value = clampf(1.0 - ready_fraction, 0.0, 1.0)


func get_cooldown_sweep_value(kind: String) -> float:
	var sweep: TextureProgressBar = _cooldown_sweeps.get(kind)
	return sweep.value if sweep else -1.0


func _center_button_content(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER

func _load_svg_icon(path: String) -> Texture2D:
	var svg_text := FileAccess.get_file_as_string(path)
	if svg_text.is_empty():
		push_warning("MobileControls: could not read icon at %s" % path)
		return null
	var img := Image.new()
	if img.load_svg_from_string(svg_text) != OK:
		push_warning("MobileControls: could not rasterize icon at %s" % path)
		return null
	return ImageTexture.create_from_image(img)

func _setup_button(btn: Button, action_name: String) -> void:
	_center_button_content(btn)
	btn.button_down.connect(func():
		_inject_action(action_name, true)
		HapticFeedbackManager.tap())
	btn.button_up.connect(func(): _inject_action(action_name, false))

func _inject_action(action_name: String, pressed: bool) -> void:
	var ev = InputEventAction.new()
	ev.action = action_name
	ev.pressed = pressed
	Input.parse_input_event(ev)


# ---------------------------------------------------------------- Ammo (M25)
## The three ammo types have always existed with real, distinct effects — chain
## wrecks sails so a target cannot flee, grape kills crew so boarding succeeds,
## round kills hull so you get loot instead of a prize — and there has never been
## a way to choose between them in play. Auto-fire meant the player never even
## had a moment to. Now that firing is an action, the choice becomes the decision
## that makes the damage triangle matter.
##
## Deliberately NOT behind a settings toggle: an option defaulting off would hide
## the mechanic from every player who never opens Settings.

## Order matches ShipCombat.AMMO_CYCLE, which owns the cycle itself.
const AMMO_LABELS := ["Round", "Chain", "Grape"]

var _btn_ammo: Button
var _ammo_index: int = 0
var _ammo_combat: Node = null


func _create_ammo_selector() -> void:
	if _btn_ammo and is_instance_valid(_btn_ammo):
		return
	_btn_ammo = Button.new()
	_btn_ammo.name = "BtnAmmo"
	_btn_ammo.tooltip_text = tr("Shot type")
	_make_round(_btn_ammo, _ROUND_SMALL)
	# Its own slot at the right end of the context-action row (the context
	# action is narrowed by _ammo_slot_width() to make room). It used to sit
	# "above the ability button", at y 136 - height - 12, which is inside the
	# context action's 0-120 band, so it covered "Set Sail" on every phone.
	var size := PirateThemeBuilder.round_button_size(_ROUND_SMALL)
	_btn_ammo.position = Vector2(378.0 - size.x, (120.0 - size.y) * 0.5)
	_center_button_content(_btn_ammo)
	_btn_ammo.pressed.connect(_cycle_ammo)
	_btn_ammo.add_to_group(&"hud_ammo_button")   # M28 lesson highlight
	btn_captain_ability.get_parent().add_child(_btn_ammo)
	_sync_ammo_from_ship()
	_refresh_ammo_button()
	_layout_context_row()


## Reads the ship's current ammo so the button never contradicts what is loaded
## (e.g. after a ship swap, a save that restored a different shot type, or a swap
## made with the keyboard/gamepad `cycle_ammo` action).
## Width the ammo button's slot takes from the context-action row, gap included.
## Reads the button's real size once it exists: the theme renders it larger
## than its nominal _ROUND_SMALL width, and sizing the slot off the nominal
## width pushed the button past the column's right edge (off-screen on phones).
func _ammo_slot_width() -> float:
	if _btn_ammo and is_instance_valid(_btn_ammo):
		return _ammo_button_size().x + 12.0
	return PirateThemeBuilder.round_button_size(_ROUND_SMALL).x + 12.0


func _ammo_button_size() -> Vector2:
	return _btn_ammo.size.max(_btn_ammo.get_combined_minimum_size())


## Shares the top row of the 378-wide Actions column: the context action on the
## left, the ammo button in its own slot on the right. Re-run on every layout
## pass, since the ammo button's real size is only known once it is themed.
func _layout_context_row() -> void:
	if not _btn_ammo or not is_instance_valid(_btn_ammo) or not _context_action:
		return
	var ammo_size := _ammo_button_size()
	_btn_ammo.size = ammo_size
	_btn_ammo.position = Vector2(378.0 - ammo_size.x, maxf(0.0, (120.0 - ammo_size.y) * 0.5))
	var width := 378.0 - _ammo_slot_width()
	_context_action.custom_minimum_size = Vector2(width, 120)
	_context_action.size = Vector2(width, 120)


func _sync_ammo_from_ship() -> void:
	var combat := _player_combat()
	if not combat:
		return
	if combat != _ammo_combat and combat.has_signal("ammo_changed"):
		if _ammo_combat and is_instance_valid(_ammo_combat) and _ammo_combat.ammo_changed.is_connected(_on_ammo_changed):
			_ammo_combat.ammo_changed.disconnect(_on_ammo_changed)
		combat.ammo_changed.connect(_on_ammo_changed)
		_ammo_combat = combat
	if combat.has_method("get_ammo_cycle_index"):
		var found: int = combat.get_ammo_cycle_index()
		if found >= 0:
			_ammo_index = found


func _player_combat() -> Node:
	var player := get_tree().get_first_node_in_group("player_ship")
	return player.get_node_or_null("ShipCombat") if player else null


func _cycle_ammo() -> void:
	_sync_ammo_from_ship()
	var combat := _player_combat()
	if combat and combat.has_method("cycle_ammo"):
		combat.cycle_ammo()
	_sync_ammo_from_ship()
	_refresh_ammo_button()
	HapticFeedbackManager.tap()


func _on_ammo_changed(_ammo: AmmoData) -> void:
	_sync_ammo_from_ship()
	_refresh_ammo_button()


func _refresh_ammo_button() -> void:
	if not _btn_ammo or not is_instance_valid(_btn_ammo):
		return
	_btn_ammo.text = tr(AMMO_LABELS[_ammo_index])


func get_ammo_index() -> int:
	return _ammo_index

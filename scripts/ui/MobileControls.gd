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

func _uses_mobile_layout() -> bool:
	return force_mobile_layout_for_test or not OS.has_feature("pc")

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
	# Positioning and automatic broadside are the default phone combat model.
	# Manual side-fire is a deliberate accessibility/preference opt-in.
	_apply_advanced_combat_controls()
	# On-screen steering is the default; tilt-to-steer is an opt-in that hides
	# the left/right buttons in favor of phone tilt (InputManager).
	_apply_tilt_steering()
	# Pause is a global utility, not a combat action. Pull it out of the lower
	# action cluster so it is compact and consistently reachable at top-right.
	btn_pause.reparent(self)
	btn_pause.custom_minimum_size = Vector2(108, 72)
	btn_pause.expand_icon = false
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
	# This is a starting position only, nudged down by WorldHUD._apply_mobile_safe_area()
	# right after it lays out top_right_panel (see the comment there) — that
	# function, not this one, knows that panel's real on-screen bottom edge for
	# the current device, since it positions the panel itself.
	btn_pause.position = Vector2(safe.end.x - 108.0 * scale - 16.0, safe.position.y + 150.0 * scale)
	btn_pause.size = Vector2(108.0 * scale, 72.0 * scale)


func _layout_primary_actions() -> void:
	## The action cluster intentionally has four targets only: one contextual
	## world action, ability, broadside, and pause. This prevents six permanent
	## buttons from competing with moment-to-moment steering.
	# Matches Movement's 150x150 touch targets (_create_sail_control()) — these
	# were previously 180x120, noticeably shorter than the movement cluster's
	# buttons, reading as visibly smaller/less important despite serving
	# equally primary actions (device-test feedback 2026-09-20).
	btn_captain_ability.position = Vector2(0, 136)
	btn_captain_ability.size = Vector2(180, 150)
	btn_special_broadside.position = Vector2(198, 136)
	btn_special_broadside.size = Vector2(180, 150)
	for button in [btn_pause, btn_captain_ability, btn_special_broadside]:
		_center_button_content(button)


func _create_action_captions() -> void:
	## The ability/broadside icons alone gave no indication of what they do —
	## a small label under each, matching that button's own width, makes their
	## purpose legible without changing the icon buttons themselves.
	_create_caption_label(tr("Ability"), btn_captain_ability.position.x, btn_captain_ability.size.x)
	_create_caption_label(tr("Broadside"), btn_special_broadside.position.x, btn_special_broadside.size.x)
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
	var row_y: float = btn_captain_ability.position.y + btn_captain_ability.size.y + 4.0 + 28.0 + 6.0
	_port_alignment_label = Label.new()
	_port_alignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_port_alignment_label.position = Vector2(btn_captain_ability.position.x, row_y)
	_port_alignment_label.size = Vector2(btn_captain_ability.size.x, 24.0)
	_port_alignment_label.add_theme_font_size_override("font_size", 13)
	_port_alignment_label.text = tr("PORT: NO TARGET")
	$Actions.add_child(_port_alignment_label)

	_stbd_alignment_label = Label.new()
	_stbd_alignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stbd_alignment_label.position = Vector2(btn_special_broadside.position.x, row_y)
	_stbd_alignment_label.size = Vector2(btn_special_broadside.size.x, 24.0)
	_stbd_alignment_label.add_theme_font_size_override("font_size", 13)
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
		label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	elif not preview.get("found", false):
		label.text = "%s: NO TARGET" % side_name
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	elif not preview.get("in_range", false):
		label.text = "%s: OUT OF RANGE" % side_name
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	else:
		var angle: float = preview.get("angle_off_deg", 180.0)
		label.text = "%s: %d°" % [side_name, int(ceil(angle))]
		label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))


func _create_caption_label(caption: String, x: float, width: float) -> void:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(x, btn_captain_ability.position.y + btn_captain_ability.size.y + 4.0)
	label.size = Vector2(width, 28.0)
	label.add_theme_font_size_override("font_size", 14)
	$Actions.add_child(label)


func _apply_advanced_combat_controls() -> void:
	var enabled := bool(SettingsManager.mobile_advanced_combat_controls)
	btn_fire_port.visible = enabled
	btn_fire_star.visible = enabled
	if enabled and not _advanced_buttons_wired:
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
	_context_action.custom_minimum_size = Vector2(378, 120)
	_context_action.size = Vector2(378, 120)
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
	if _board_available:
		_context_action_name = "dock"
		_context_action.text = tr("Board Enemy")
	elif _dock_available:
		_context_action_name = "dock"
		_context_action.text = tr("Dock")
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
	sail.custom_minimum_size = Vector2(150, 150)
	sail.position = Vector2(195, 0)
	# Text makes the control meaningful even if an SVG import is unavailable on
	# a device. The old icon-only control rendered as an empty square.
	sail.add_theme_font_size_override("font_size", 20)
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

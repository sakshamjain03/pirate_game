extends CanvasLayer
class_name SettingsMenu

## SettingsMenu.gd
## Handles the settings menu UI interactions and updates the SettingsManager.
##
## Responsibilities:
## - Populate controls from SettingsManager on ready
## - Update SettingsManager properties when controls change
## - Apply audio settings via AudioManager.set_bus_volume() for volume sliders
## - Apply display settings via SettingsManager.apply_display_settings() for display controls
## - Save settings via SettingsManager.save_settings() after each change
## - Navigate back via SceneManager.go_back() on Back button press or ui_cancel
## - Set initial focus on MasterSlider for keyboard/gamepad navigation
##
## Dependencies:
## - SettingsManager (autoload singleton for settings persistence and application)
## - AudioManager (autoload singleton for audio bus volume control)
## - SceneManager (for scene navigation with go_back())
##
## Limitations:
## - Only works with three audio buses: Master, Music, SFX (hardcoded in signal handlers)
## - Resolution strings must match exactly those in the OptionButton items
## - Control node structure must match the expected scene hierarchy
##
## TODOs:
## - Add input validation for slider values before applying
## - Implement debounce for rapid setting changes (e.g., fast slider movement)
## - Add visual feedback for successful settings save

@onready var root_control: Control = $Control
@onready var title_label: Label = $Control/TitleLabel
@onready var tab_container: TabContainer = $Control/TabContainer
@onready var general_tab: Control = $Control/TabContainer/General
@onready var master_slider: HSlider = $Control/TabContainer/General/GridContainer/MasterRow/MasterSlider
@onready var music_slider: HSlider = $Control/TabContainer/General/GridContainer/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Control/TabContainer/General/GridContainer/SFXRow/SFXSlider
## M22 Phase 4.3 (design.md's v0.3 row anatomy — "value in Baloo 800 at right").
@onready var master_value_label: Label = $Control/TabContainer/General/GridContainer/MasterRow/MasterValueLabel
@onready var music_value_label: Label = $Control/TabContainer/General/GridContainer/MusicRow/MusicValueLabel
@onready var sfx_value_label: Label = $Control/TabContainer/General/GridContainer/SFXRow/SFXValueLabel
@onready var fullscreen_check: CheckButton = $Control/TabContainer/General/GridContainer/FullscreenCheckButton
@onready var resolution_option: OptionButton = $Control/TabContainer/General/GridContainer/ResolutionOptionButton
@onready var vsync_check: CheckButton = $Control/TabContainer/General/GridContainer/VSyncCheckButton
@onready var back_button_container: CenterContainer = $Control/BackButtonContainer
@onready var back_button: Button = $Control/BackButtonContainer/BackButton
@onready var replay_tutorial_button: Button = $Control/TabContainer/General/GridContainer/ReplayTutorialButton
@onready var grid_container: GridContainer = $Control/TabContainer/General/GridContainer
@onready var fullscreen_label: Label = $Control/TabContainer/General/GridContainer/FullscreenLabel
@onready var resolution_label: Label = $Control/TabContainer/General/GridContainer/ResolutionLabel
@onready var vsync_label: Label = $Control/TabContainer/General/GridContainer/VSyncLabel

@onready var controls_vbox: VBoxContainer = $Control/TabContainer/Controls/ScrollContainer/ControlsVBox
@onready var account_vbox: VBoxContainer = $Control/TabContainer/Account/ScrollContainer/AccountVBox

var _awaiting_rebind: String = ""
## Gap between a slider and its value readout — must exceed half the rope
## knob (52 canvas px, and center_grabber lets it overhang the track end at
## 100%), or the knob overlaps the "100%" (M22 Phase 4 sweep).
const _SLIDER_VALUE_GAP := 36
## Row-label column for the runtime-built Controls rows. Was 200, narrower
## than "Enemy Difficulty"/"Graphics Quality" at the M22 32px body size, so
## those labels ran straight into their dropdown with no gap.
const _ROW_LABEL_WIDTH := 320
var _settings_card: Panel
var _mobile_general_scroll: ScrollContainer

## Desktop test runners cannot report an Android/iOS feature. This allows the
## phone presentation to be layout-tested without changing a shipping build.
@export var force_mobile_layout_for_test: bool = false

var settings_manager: Node = SettingsManager
var audio_manager: Node = AudioManager
var auth_manager: Node = AuthManager

## M15 Requirement 9.1 — placeholder until M13's hosted privacy/terms pages exist (M13 hasn't
## started yet; tasks.md explicitly allows linking a placeholder and revisiting before this
## milestone's final checkpoint). Points at this repo's likely eventual GitHub Pages URL.
const TERMS_URL := "https://sakshamjain03.github.io/pirate_game/terms.html"
const PRIVACY_URL := "https://sakshamjain03.github.io/pirate_game/privacy.html"

## preload rather than the bare global class name — headless GUT runs don't always have a
## freshly rebuilt global-script-class cache, and the bare identifier can fail to resolve.
const ChoiceDialogScript := preload("res://scripts/ui/ChoiceDialog.gd")
const PurchaseSupportScreenScene := preload("res://scenes/ui/PurchaseSupportScreen.tscn")
const ConsentPanelScene := preload("res://scenes/ui/ConsentPanel.tscn")

var _account_email_field: LineEdit
var _account_password_field: LineEdit
var _account_terms_check: CheckBox
var _account_sign_up_button: Button

func _ready() -> void:
	# M9 Requirement 3 (D70) — the only screen in scenes/ui/ that never applied
	# the theme, rendering as raw default Godot UI.
	root_control.theme = PirateThemeBuilder.build()
	_apply_settings_visual_language()

	# Populate controls from SettingsManager
	master_slider.value = settings_manager.master_volume
	music_slider.value = settings_manager.music_volume
	sfx_slider.value = settings_manager.sfx_volume
	master_value_label.text = "%d%%" % roundi(settings_manager.master_volume * 100.0)
	music_value_label.text = "%d%%" % roundi(settings_manager.music_volume * 100.0)
	sfx_value_label.text = "%d%%" % roundi(settings_manager.sfx_volume * 100.0)

	fullscreen_check.button_pressed = settings_manager.fullscreen
	vsync_check.button_pressed = settings_manager.vsync
	
	for i in range(resolution_option.item_count):
		if resolution_option.get_item_text(i) == settings_manager.resolution:
			resolution_option.select(i)
			break
	
	# Connect signals
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)
	
	back_button.pressed.connect(_on_back_pressed)
	replay_tutorial_button.pressed.connect(_on_replay_tutorial_pressed)

	auth_manager.signed_in.connect(_on_auth_signed_in)
	auth_manager.signed_out.connect(_on_auth_signed_out)
	auth_manager.auth_error.connect(_on_auth_error)
	auth_manager.sign_up_pending_confirmation.connect(_on_sign_up_pending_confirmation)

	# Set focus on first slider for keyboard/gamepad navigation
	master_slider.grab_focus()
	_populate_controls()
	_build_display_tab()
	_populate_account_tab()
	PirateThemeBuilder.apply_button_juice(root_control)

	if _uses_mobile_layout():
		_apply_mobile_sizing()


func _uses_mobile_layout() -> bool:
	return force_mobile_layout_for_test or PirateThemeBuilder.is_mobile()


func _apply_settings_visual_language() -> void:
	## Settings used to be an unframed, edge-to-edge TabContainer. Give every
	## device a deliberate surface, while the mobile branch below narrows it to
	## a readable, thumb-friendly panel instead of scaling a desktop rectangle.
	## M22 Phase 4.3 — was a hand-rolled flat navy/gold StyleBoxFlat (the exact
	## pre-M22 look this milestone replaces); now the kit's WoodFramePanel via
	## the theme's own default Panel style, like every other screen.
	_settings_card = Panel.new()
	_settings_card.name = "SettingsCard"
	_settings_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_card.offset_left = 72.0
	_settings_card.offset_top = 32.0
	_settings_card.offset_right = -72.0
	_settings_card.offset_bottom = -32.0
	root_control.add_child(_settings_card)
	# Above Background + its dark overlay (indices 0, 1), below everything else.
	root_control.move_child(_settings_card, 2)

	title_label.theme_type_variation = &"TitleLabel"
	# Pages are parchment (v0.3: the active parchment tab bleeds into the
	# page) with ink text — a colour-only sub-theme layered on this
	# TabContainer, so runtime-built Controls/Account rows get ink too
	# without a per-label colour override each.
	tab_container.theme = PirateThemeBuilder.build_parchment_page_theme()
	UIMotion.fade_tabs(tab_container)  # M22 6c: pages fade in on tab change
	# The frame intentionally leaves an even margin around all pages.
	tab_container.offset_left = 100.0
	tab_container.offset_top = 104.0
	tab_container.offset_right = -100.0
	tab_container.offset_bottom = -104.0

## Fullscreen/Resolution/VSync are PC display concepts with no mobile
## equivalent (a phone app is always "fullscreen" and its OS controls actual
## resolution) — hidden outright on mobile rather than resized, per explicit
## direction, then everything that remains is enlarged the same way every
## other screen in this pass is.
func _apply_mobile_sizing() -> void:
	var safe := MobileLayoutManager.safe_area(get_viewport())
	var viewport_size := get_viewport().get_visible_rect().size
	var side_margin := clampf(viewport_size.x * 0.045, 24.0, 56.0)
	var top_margin := maxf(20.0, safe.position.y + 12.0)
	var bottom_margin := maxf(20.0, viewport_size.y - safe.end.y + 12.0)

	# Phone/tablet pages stay inside a surfaced frame rather than running to
	# display edges. This protects against cut-outs and makes text scannable.
	_settings_card.offset_left = side_margin
	_settings_card.offset_top = top_margin
	_settings_card.offset_right = -side_margin
	_settings_card.offset_bottom = -bottom_margin
	title_label.position = Vector2(0.0, top_margin + 12.0)
	title_label.size = Vector2(viewport_size.x, 52.0)
	tab_container.offset_left = side_margin + 16.0
	tab_container.offset_top = top_margin + 78.0
	tab_container.offset_right = -side_margin - 16.0
	# offset_bottom is set below, from the Back button's real height.
	# M22: no per-control font-size overrides on mobile any more. The old
	# 19-34px values were tuned for the pre-M22 1080-tall base; at the
	# 1688x780 base the theme's own token sizes (body 32) are already
	# phone-sized, so those overrides made phone text SMALLER than desktop.

	for ctrl in [fullscreen_label, fullscreen_check, resolution_label, resolution_option,
			vsync_label, vsync_check]:
		ctrl.visible = false

	# General becomes a vertical, scrollable set of settings rows. A phone
	# should never compress a label and its control into an unreadable two-column
	# desktop grid, especially in landscape or split-screen tablet mode.
	grid_container.columns = 1
	grid_container.add_theme_constant_override("h_separation", 12)
	grid_container.add_theme_constant_override("v_separation", 10)
	# Width comes from the ScrollContainer (horizontal scroll disabled +
	# EXPAND_FILL), not tab_container.size: that ignored the page stylebox's
	# own content margins, so content overflowed sideways — a horizontal
	# scrollbar, off-screen % readouts, a clipped Replay button (M22 sweep).
	grid_container.custom_minimum_size = Vector2.ZERO
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if not _mobile_general_scroll:
		_mobile_general_scroll = ScrollContainer.new()
		_mobile_general_scroll.name = "GeneralScrollContainer"
		_mobile_general_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_mobile_general_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		_mobile_general_scroll.offset_left = 12.0
		_mobile_general_scroll.offset_top = 12.0
		_mobile_general_scroll.offset_right = -12.0
		_mobile_general_scroll.offset_bottom = -12.0
		general_tab.add_child(_mobile_general_scroll)
		grid_container.reparent(_mobile_general_scroll)
	for label in [
		grid_container.get_node("MasterVolumeLabel"),
		grid_container.get_node("MusicVolumeLabel"),
		grid_container.get_node("SFXVolumeLabel"),
		grid_container.get_node("TutorialLabel"),
	]:
		label.custom_minimum_size = Vector2(0.0, 32.0)
	for slider in [master_slider, music_slider, sfx_slider]:
		slider.custom_minimum_size = Vector2(0.0, 64.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_tutorial_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(Vector2(260.0, 80.0))
	# Container-laid (design.md §11's own fragile-area lesson, applied here):
	# BackButtonContainer's CenterContainer keeps the button horizontally
	# centred on its own — only the container's vertical offsets (safe-area
	# clearance) are touched here, never the button's own position, so its
	# size and its placement can never drift apart the way two independently
	# hardcoded numbers did before.
	back_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(Vector2(220.0, 80.0))
	back_button_container.offset_bottom = -bottom_margin - 8.0
	# Real combined minimum, not custom_minimum_size: the lip-aware content
	# margins can make the button taller than its requested 80, and the page
	# bottom below is derived from this — sizing them independently let Back
	# cover the page's last row (M22 Phase 4 phone sweep).
	var back_h := maxf(back_button.custom_minimum_size.y, back_button.get_combined_minimum_size().y)
	back_button_container.offset_top = back_button_container.offset_bottom - back_h - 16.0
	tab_container.offset_bottom = back_button_container.offset_top - 4.0

	_style_mobile_scroll_content(controls_vbox)
	_style_mobile_scroll_content(account_vbox)


func _style_mobile_scroll_content(container: VBoxContainer) -> void:
	## Controls and Account are built at runtime, so normalise their type and
	## touch targets after population. The internal page margin is deliberately
	## consistent with General's scroll view.
	container.add_theme_constant_override("separation", 14)
	# Section headers/cards (added by _add_section_header/_add_section_card)
	# nest rows inside PanelContainer > VBoxContainer, so this needs to recurse
	# rather than assume every row is a direct child of `container`.
	_style_mobile_rows_recursive(container)


func _style_mobile_rows_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Button or child is CheckButton or child is OptionButton or child is LineEdit:
			child.custom_minimum_size.y = maxf(child.custom_minimum_size.y, 64.0)
		elif child is HBoxContainer:
			child.custom_minimum_size.y = maxf(child.custom_minimum_size.y, 64.0)
			for row_child in child.get_children():
				if row_child is Button or row_child is OptionButton:
					row_child.custom_minimum_size.y = maxf(row_child.custom_minimum_size.y, 60.0)
				elif row_child is HSlider:
					row_child.custom_minimum_size.y = maxf(row_child.custom_minimum_size.y, 60.0)
		elif child is PanelContainer or child is VBoxContainer:
			_style_mobile_rows_recursive(child)

func _populate_controls() -> void:
	for child in controls_vbox.get_children():
		child.queue_free()

	_add_section_header(controls_vbox, tr("Input Feel"))
	var feel_card := _add_section_card(controls_vbox)
	_add_input_feel_controls(feel_card)

	if not OS.has_feature("pc"):
		_add_section_header(controls_vbox, tr("Mobile Controls"))
		var mobile_card := _add_section_card(controls_vbox)
		_add_mobile_controls(mobile_card)

	_add_section_header(controls_vbox, tr("Gameplay"))
	var gameplay_card := _add_section_card(controls_vbox)
	_add_ai_difficulty_control(gameplay_card)

	_add_section_header(controls_vbox, tr("Display"))
	var display_card := _add_section_card(controls_vbox)
	_add_graphics_quality_control(display_card)
	_add_ui_font_control(display_card)

	_add_section_header(controls_vbox, tr("Key Bindings"))
	var bindings_card := _add_section_card(controls_vbox)
	# Was a hardcoded copy of the action list, which had already drifted — it
	# predated M8 and so offered no way to rebind `special_broadside` or
	# `captain_ability`. SettingsManager.REBINDABLE_ACTIONS is the single source
	# of truth the save/load path already uses.
	for action in SettingsManager.REBINDABLE_ACTIONS:
		if InputMap.has_action(action):
			var hbox = HBoxContainer.new()
			var label = _make_row_label(tr(action.capitalize().replace("_", " ")))
			label.custom_minimum_size.x = _ROW_LABEL_WIDTH
			hbox.add_child(label)

			var btn = Button.new()
			var events = InputMap.action_get_events(action)
			if events.size() > 0 and events[0] is InputEventKey:
				btn.text = OS.get_keycode_string(events[0].keycode)
			else:
				btn.text = tr("Unbound")

			btn.pressed.connect(func(): _on_rebind_pressed(action, btn))
			hbox.add_child(btn)
			bindings_card.add_child(hbox)

	var reset_btn = Button.new()
	reset_btn.text = tr("Reset to Defaults")
	reset_btn.pressed.connect(func():
		InputManager.reset_to_defaults()
		_populate_controls()
	)
	bindings_card.add_child(reset_btn)

	PirateThemeBuilder.apply_mobile_control_scaling(controls_vbox)
	if _uses_mobile_layout():
		_style_mobile_scroll_content(controls_vbox)

func _add_input_feel_controls(card: VBoxContainer) -> void:
	## M2 Task 6.3 — adjustable sensitivity and dead zone. Persisted through
	## SettingsManager alongside every other setting; InputManager picks the new
	## values up from its `settings_changed` connection.
	_add_input_slider(card, tr("Sensitivity"), 0.1, 3.0, 0.05, settings_manager.input_sensitivity,
		func(v: float):
			settings_manager.input_sensitivity = v
			InputManager.set_sensitivity(v)
			settings_manager.save_settings())

	_add_input_slider(card, tr("Dead Zone"), 0.0, 0.9, 0.05, settings_manager.input_dead_zone,
		func(v: float):
			settings_manager.input_dead_zone = v
			InputManager.set_dead_zone(v)
			settings_manager.save_settings())


func _add_mobile_controls(card: VBoxContainer) -> void:
	var handed := CheckButton.new()
	handed.text = tr("Left-handed Controls")
	handed.button_pressed = settings_manager.mobile_left_handed
	handed.toggled.connect(func(enabled: bool):
		settings_manager.mobile_left_handed = enabled
		settings_manager.save_settings()
		MobileLayoutManager.notify_layout_changed())
	card.add_child(handed)
	var haptics := CheckButton.new()
	haptics.text = tr("Haptic Feedback")
	haptics.button_pressed = settings_manager.haptics_enabled
	haptics.toggled.connect(func(enabled: bool):
		settings_manager.haptics_enabled = enabled
		settings_manager.save_settings())
	card.add_child(haptics)
	# M25 — the "Advanced Fire Controls" row was removed. It gated the port/starboard
	# fire buttons, which are now the core combat action and always shown; the toggle
	# would only have let a player hide their own trigger. The
	# `mobile_advanced_combat_controls` key is still read by SettingsManager so an
	# existing config file loads unchanged, it simply no longer drives anything.
	# Auto-fire moved to Display > Accessibility, where an accessibility option belongs.
	var tilt_steer := CheckButton.new()
	tilt_steer.text = tr("Tilt to Steer")
	tilt_steer.button_pressed = settings_manager.mobile_tilt_steering_enabled
	card.add_child(tilt_steer)

	# Which raw accelerometer component counts as left/right roll is
	# device/orientation-dependent and can't be verified from this
	# environment (no accelerometer here) — so instead of a second hardcoded
	# guess, the player picks it directly. Only meaningful (and only shown)
	# while tilt steering itself is on.
	var tilt_axis := OptionButton.new()
	tilt_axis.add_item(tr("Y Axis"), 0)
	tilt_axis.add_item(tr("Y Axis (Inverted)"), 1)
	tilt_axis.add_item(tr("X Axis"), 2)
	tilt_axis.add_item(tr("X Axis (Inverted)"), 3)
	tilt_axis.select(clampi(settings_manager.mobile_tilt_axis, 0, 3))
	tilt_axis.tooltip_text = tr("Try the other options if tilt steering feels backwards, or doesn't respond in one direction.")
	tilt_axis.visible = settings_manager.mobile_tilt_steering_enabled
	tilt_axis.item_selected.connect(func(index: int):
		settings_manager.mobile_tilt_axis = index
		settings_manager.save_settings())
	card.add_child(tilt_axis)

	tilt_steer.toggled.connect(func(enabled: bool):
		settings_manager.mobile_tilt_steering_enabled = enabled
		settings_manager.save_settings()
		tilt_axis.visible = enabled)

	# Only meaningful with a live HUD to edit — Settings is always its own
	# scene (never an overlay on World.tscn), so "would going back return to
	# gameplay" is the only signal available; see SceneManager.
	# get_previous_scene_path()'s own comment for why.
	if SceneManager.get_previous_scene_path() == "res://scenes/world/World.tscn":
		var customize := Button.new()
		customize.text = tr("Customize HUD Layout")
		customize.pressed.connect(func():
			settings_manager.pending_hud_customize_request = true
			SceneManager.go_back())
		card.add_child(customize)


func _add_graphics_quality_control(card: VBoxContainer) -> void:
	## M2 Task 12.1 — quality settings adaptation. Drives
	## OceanController.quality_level (currently the only quality-scaled
	## system) via SettingsManager.settings_changed, the same pattern
	## InputManager uses for sensitivity/dead zone.
	var hbox := HBoxContainer.new()
	var label := _make_row_label(tr("Graphics Quality"))
	label.custom_minimum_size.x = _ROW_LABEL_WIDTH
	hbox.add_child(label)

	var option := OptionButton.new()
	option.add_item(tr("Low"), 0)
	option.add_item(tr("Medium"), 1)
	option.add_item(tr("High"), 2)
	option.select(settings_manager.graphics_quality)
	option.item_selected.connect(func(index: int):
		settings_manager.graphics_quality = index
		settings_manager.save_settings())
	hbox.add_child(option)

	card.add_child(hbox)


func _add_ui_font_control(card: VBoxContainer) -> void:
	## 2026-09-24 — player-selectable body/UI font. Default (Baloo 2 as of
	## M22 2026-09-25; previously Cinzel) is what PirateThemeBuilder.build()
	## now uses project-wide after PirataOne was found illegible for dense
	## HUD numeric text at small sizes; kept here as opt-in choices for
	## players who want the original pirate blackletter look, or their own
	## OS Times New Roman. See PirateThemeBuilder._load_body_font().
	var hbox := HBoxContainer.new()
	var label := _make_row_label(tr("UI Font"))
	label.custom_minimum_size.x = _ROW_LABEL_WIDTH
	hbox.add_child(label)

	var option := OptionButton.new()
	option.add_item(tr("Default"), 0)
	option.add_item(tr("Pirate"), 1)
	option.add_item(tr("Times New Roman"), 2)
	option.select(settings_manager.ui_font)
	option.item_selected.connect(func(index: int):
		settings_manager.ui_font = index
		settings_manager.save_settings()
		# Immediate preview on this same screen, not just on next screen load —
		# the whole point of this control is to let the player see the choice.
		root_control.theme = PirateThemeBuilder.build())
	hbox.add_child(option)

	card.add_child(hbox)


func _add_ai_difficulty_control(card: VBoxContainer) -> void:
	## M23 Requirement 6 — how hard enemy ships hit, reload and aim. Names and
	## descriptions come from the AIDifficultyData resources, not this file.
	var hbox := HBoxContainer.new()
	var label := _make_row_label(tr("Enemy Difficulty"))
	label.custom_minimum_size.x = _ROW_LABEL_WIDTH
	hbox.add_child(label)

	var option := OptionButton.new()
	var names: Array[String] = settings_manager.get_ai_difficulty_names()
	for i in names.size():
		option.add_item(tr(names[i]), i)
	option.select(settings_manager.ai_difficulty)
	hbox.add_child(option)
	card.add_child(hbox)

	var hint := _make_row_label("")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(hint)
	var refresh_hint := func():
		var profile: AIDifficultyData = settings_manager.get_ai_difficulty_profile()
		hint.text = tr(profile.description) if profile else ""
	refresh_hint.call()
	option.item_selected.connect(func(index: int):
		settings_manager.ai_difficulty = index
		settings_manager.save_settings()
		refresh_hint.call())


func _add_input_slider(card: VBoxContainer, label_text: String, min_v: float, max_v: float, step: float,
		value: float, on_changed: Callable) -> void:
	var hbox := HBoxContainer.new()
	var label := _make_row_label(label_text)
	label.custom_minimum_size.x = _ROW_LABEL_WIDTH
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = 200
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", _SLIDER_VALUE_GAP)
	hbox.add_child(slider)

	var value_label := _make_row_label("%.2f" % value)
	value_label.theme_type_variation = &"HudNumLabel"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 96
	hbox.add_child(value_label)

	slider.value_changed.connect(func(v: float):
		value_label.text = "%.2f" % v
		on_changed.call(v))

	card.add_child(hbox)


## M18 settings uplift — every dynamically-built row label goes through this
## single helper. M22: colour now comes from the parchment page sub-theme
## (build_parchment_page_theme) rather than a per-label override, which is
## what used to force light text onto what is now a light page.
func _make_row_label(text_content: String) -> Label:
	var label := Label.new()
	label.text = text_content
	return label


## Germania ink section title heading each grouped card in Controls/Account.
func _add_section_header(parent: VBoxContainer, text_content: String) -> void:
	var label := Label.new()
	label.text = text_content
	label.theme_type_variation = &"InkTitleLabel"
	label.add_theme_font_size_override("font_size", UITokens.FONT_HUD_NUM)
	parent.add_child(label)


## Nested gold-bordered card grouping one logical settings section — the
## CoC-style "settings group panel" look, replacing a single flat column of
## unrelated rows with no visual separation.
func _add_section_card(parent: VBoxContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	# Theme variation (PirateThemeBuilder), was a per-card StyleBoxFlat.
	panel.theme_type_variation = &"InkInsetPanel"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	parent.add_child(panel)
	parent.add_child(HSeparator.new())
	return vbox


# ---------------------------------------------------------------------------
# M22 Phase 6f — Display tab (v0.3 Settings 07b/07c/07a/07d, trimmed to what
# this game can actually honour; every row writes a SettingsManager field
# that a real system reads — see SettingsManager's DEFAULT_HUD_DETAIL note).
# Rows use v0.3's layout: a bold label with a soft caption on the left, the
# control on the right, one row per setting.
# ---------------------------------------------------------------------------
var display_vbox: VBoxContainer


func _setting(key: String, fallback):
	var v = settings_manager.get(key) if settings_manager else null
	return fallback if v == null else v


func _commit_setting(key: String, value) -> void:
	settings_manager.set(key, value)
	settings_manager.save_settings()
	if key == "max_fps" and settings_manager.has_method("apply_display_settings"):
		Engine.max_fps = int(value)


func _build_display_tab() -> void:
	var page := Control.new()
	page.name = "Display"
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(scroll)
	display_vbox = VBoxContainer.new()
	display_vbox.name = "DisplayVBox"
	display_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(display_vbox)
	tab_container.add_child(page)
	var account := tab_container.get_node_or_null("Account")
	if account:
		tab_container.move_child(page, account.get_index())
	tab_container.set_tab_title(page.get_index(), tr("Display"))

	_add_section_header(display_vbox, tr("Screen & HUD"))
	var hud_card := _add_section_card(display_vbox)
	_add_segment_row(hud_card, tr("HUD details"), tr("Auto-hide shows panels only when they matter"),
		[tr("Auto-hide"), tr("Always")], int(_setting("hud_detail", 0)),
		func(i: int): _commit_setting("hud_detail", i))
	var fps_values: Array = [30, 60, 0]
	_add_segment_row(hud_card, tr("Frame rate"), tr("60 fps uses more battery"),
		["30", "60", tr("Max")], maxi(0, fps_values.find(int(_setting("max_fps", 60)))),
		func(i: int): _commit_setting("max_fps", fps_values[i]))
	_add_toggle_row(hud_card, tr("FPS counter"), "", bool(_setting("show_fps", false)),
		func(on: bool): _commit_setting("show_fps", on))

	_add_section_header(display_vbox, tr("Accessibility"))
	var access_card := _add_section_card(display_vbox)
	_add_segment_row(access_card, tr("Text size"), tr("Applies to every screen"),
		[tr("Normal"), tr("Large"), tr("Largest")], int(_setting("text_size", 0)),
		func(i: int):
			_commit_setting("text_size", i)
			root_control.theme = PirateThemeBuilder.build())
	_add_toggle_row(access_card, tr("Reduce motion"), tr("No pops, glows, ticking numbers or typing"),
		bool(_setting("reduce_motion", false)),
		func(on: bool): _commit_setting("reduce_motion", on))
	# M25 — firing is a player action now. This restores the pre-M25 behaviour for
	# anyone who cannot comfortably time a tap; positioning still decides whether a
	# side may fire either way, so nothing about the skill of aiming changes.
	_add_toggle_row(access_card, tr("Auto-fire cannons"),
		tr("Guns fire themselves whenever a broadside lines up"),
		bool(_setting("auto_fire", false)),
		func(on: bool): _commit_setting("auto_fire", on))

	_add_section_header(display_vbox, tr("Sound & Alerts"))
	var alert_card := _add_section_card(display_vbox)
	_add_toggle_row(alert_card, tr("Mute in background"), tr("Silence the game when you switch away"),
		bool(_setting("mute_in_background", true)),
		func(on: bool): _commit_setting("mute_in_background", on))
	_add_toggle_row(alert_card, tr("Raid alerts"), tr("A note from Higgins when a raid on your island ends"),
		bool(_setting("notify_raids", true)),
		func(on: bool): _commit_setting("notify_raids", on))

	PirateThemeBuilder.apply_mobile_control_scaling(display_vbox)
	if _uses_mobile_layout():
		_style_mobile_scroll_content(display_vbox)


## v0.3 row: title (+ soft caption) on the left, the control on the right.
func _setting_row(card: VBoxContainer, title: String, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var t := _make_row_label(title)
	text.add_child(t)
	if not caption.is_empty():
		var c := Label.new()
		c.text = caption
		c.theme_type_variation = &"InkSubLabel"
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(c)
	row.add_child(text)
	card.add_child(row)
	return row


func _add_toggle_row(card: VBoxContainer, title: String, caption: String, value: bool, on_toggled: Callable) -> CheckButton:
	var row := _setting_row(card, title, caption)
	var toggle := CheckButton.new()
	toggle.button_pressed = value
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.tooltip_text = title
	toggle.toggled.connect(on_toggled)
	row.add_child(toggle)
	return toggle


func _add_segment_row(card: VBoxContainer, title: String, caption: String, options: Array,
		selected: int, on_selected: Callable) -> HBoxContainer:
	var row := _setting_row(card, title, caption)
	var well := PanelContainer.new()
	well.theme_type_variation = &"SegmentWell"
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 4)
	well.add_child(seg)
	var group := ButtonGroup.new()
	for i in options.size():
		var b := Button.new()
		b.text = str(options[i])
		b.theme_type_variation = &"SegmentButton"
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == selected
		b.pressed.connect(on_selected.bind(i))
		seg.add_child(b)
	row.add_child(well)
	return seg


func _on_rebind_pressed(action: String, btn: Button) -> void:
	_awaiting_rebind = action
	btn.text = tr("Press any key...")

func _input(event: InputEvent) -> void:
	if _awaiting_rebind != "" and event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		# Was `get_tree().root.get_node_or_null("InputManager")` — a lookup for an
		# autoload that did not exist, so it always returned null, the null guard
		# swallowed the keypress, and rebinding silently did nothing (D57).
		InputManager.rebind_action(_awaiting_rebind, event)
		_awaiting_rebind = ""
		_populate_controls()

func _on_master_slider_changed(value: float) -> void:
	settings_manager.master_volume = value
	audio_manager.set_bus_volume("Master", value)
	settings_manager.save_settings()
	master_value_label.text = "%d%%" % roundi(value * 100.0)

func _on_music_slider_changed(value: float) -> void:
	settings_manager.music_volume = value
	audio_manager.set_bus_volume("Music", value)
	settings_manager.save_settings()
	music_value_label.text = "%d%%" % roundi(value * 100.0)

func _on_sfx_slider_changed(value: float) -> void:
	settings_manager.sfx_volume = value
	audio_manager.set_bus_volume("SFX", value)
	settings_manager.save_settings()
	sfx_value_label.text = "%d%%" % roundi(value * 100.0)

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	settings_manager.fullscreen = button_pressed
	settings_manager.save_settings()
	settings_manager.apply_display_settings()

func _on_vsync_toggled(button_pressed: bool) -> void:
	settings_manager.vsync = button_pressed
	settings_manager.save_settings()
	settings_manager.apply_display_settings()

func _on_resolution_selected(index: int) -> void:
	settings_manager.resolution = resolution_option.get_item_text(index)
	settings_manager.save_settings()
	settings_manager.apply_display_settings()

func _on_back_pressed() -> void:
	SceneManager.go_back()

func _on_replay_tutorial_pressed() -> void:
	# Non-destructive: World.gd still calls SaveManager.load_game() on load,
	# so the player's existing save is untouched — only the tutorial re-arms.
	TutorialManager.reset_and_replay()
	SceneManager.change_scene_with_fade("res://scenes/world/World.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.go_back()

## M15 Requirement 1.1 — Account section. Rebuilt from scratch on every auth state change,
## same pattern _populate_controls() already uses for the Controls tab.
func _populate_account_tab() -> void:
	for child in account_vbox.get_children():
		child.queue_free()

	if auth_manager.is_signed_in():
		_build_signed_in_account_ui()
	else:
		_build_signed_out_account_ui()
	_build_purchases_ui()
	PirateThemeBuilder.apply_button_juice(account_vbox)
	PirateThemeBuilder.apply_mobile_control_scaling(account_vbox)
	if _uses_mobile_layout():
		_style_mobile_scroll_content(account_vbox)

## M17 Requirement 3.2/3.5 — restore purchases and purchase support, shown
## regardless of sign-in state since store restore works independently of
## an M15 account.
func _build_purchases_ui() -> void:
	_add_section_header(account_vbox, tr("Purchases"))
	var card := _add_section_card(account_vbox)

	var restore_button := Button.new()
	restore_button.text = tr("Restore Purchases")
	restore_button.custom_minimum_size = Vector2(0, 44)
	restore_button.pressed.connect(_on_restore_purchases_pressed)
	card.add_child(restore_button)

	var support_button := Button.new()
	support_button.text = tr("Purchase Support")
	support_button.custom_minimum_size = Vector2(0, 44)
	support_button.pressed.connect(_on_purchase_support_pressed)
	card.add_child(support_button)

	var ad_prefs_button := Button.new()
	ad_prefs_button.text = tr("Ad Preferences")
	ad_prefs_button.custom_minimum_size = Vector2(0, 44)
	ad_prefs_button.pressed.connect(_on_ad_preferences_pressed)
	card.add_child(ad_prefs_button)

func _on_restore_purchases_pressed() -> void:
	if not StoreManager.restore_completed.is_connected(_on_restore_completed):
		StoreManager.restore_completed.connect(_on_restore_completed, CONNECT_ONE_SHOT)
	StoreManager.restore_purchases()

func _on_restore_completed(granted_count: int) -> void:
	if granted_count > 0:
		_show_message(tr("Restored %d purchase(s).") % granted_count)
	else:
		_show_message(tr("No new purchases to restore."))

func _on_purchase_support_pressed() -> void:
	var screen: Control = PurchaseSupportScreenScene.instantiate()
	root_control.add_child(screen)
	screen.open()

## M17 Requirement 5.6 — review/change the ad consent choice later. Only
## meaningful once AdManager has actually resolved past the age gate; a
## fresh account with no ad-permission history yet has nothing to review.
func _on_ad_preferences_pressed() -> void:
	if AdManager.state == AdManager.State.UNKNOWN or AdManager.state == AdManager.State.AGE_GATE_PENDING:
		_show_message(tr("Ad preferences haven't been set up yet."))
		return
	if AdManager.state == AdManager.State.CHILD_DIRECTED:
		_show_message(tr("Ads are set to non-personalized and can't be changed on this account."))
		return
	var panel: Control = ConsentPanelScene.instantiate()
	root_control.add_child(panel)
	var free_when_resolved := func(new_state: AdManager.State) -> void:
		if new_state != AdManager.State.CONSENT_PENDING and is_instance_valid(panel):
			panel.queue_free()
	AdManager.state_changed.connect(free_when_resolved, CONNECT_ONE_SHOT)
	AdManager.reopen_consent()

func _build_signed_out_account_ui() -> void:
	_add_section_header(account_vbox, tr("Sign In / Sign Up"))
	var card := _add_section_card(account_vbox)

	card.add_child(_make_row_label(tr("Email")))

	_account_email_field = LineEdit.new()
	_account_email_field.custom_minimum_size = Vector2(0, 44)
	card.add_child(_account_email_field)

	card.add_child(_make_row_label(tr("Password")))

	_account_password_field = LineEdit.new()
	_account_password_field.secret = true
	_account_password_field.custom_minimum_size = Vector2(0, 44)
	card.add_child(_account_password_field)

	card.add_child(HSeparator.new())

	var terms_hbox := HBoxContainer.new()
	terms_hbox.add_theme_constant_override("separation", 6)
	_account_terms_check = CheckBox.new()
	_account_terms_check.toggled.connect(func(_pressed: bool): _update_sign_up_enabled())
	terms_hbox.add_child(_account_terms_check)

	terms_hbox.add_child(_make_row_label(tr("I agree to the ")))

	var terms_link := LinkButton.new()
	terms_link.text = tr("Terms of Service")
	terms_link.pressed.connect(func(): OS.shell_open(TERMS_URL))
	terms_hbox.add_child(terms_link)

	terms_hbox.add_child(_make_row_label(tr(" and ")))

	var privacy_link := LinkButton.new()
	privacy_link.text = tr("Privacy Policy")
	privacy_link.pressed.connect(func(): OS.shell_open(PRIVACY_URL))
	terms_hbox.add_child(privacy_link)

	card.add_child(terms_hbox)

	_account_sign_up_button = Button.new()
	_account_sign_up_button.text = tr("Sign Up")
	_account_sign_up_button.custom_minimum_size = Vector2(0, 44)
	_account_sign_up_button.disabled = true
	_account_sign_up_button.pressed.connect(_on_sign_up_pressed)
	card.add_child(_account_sign_up_button)

	var sign_in_button := Button.new()
	sign_in_button.text = tr("Sign In")
	sign_in_button.custom_minimum_size = Vector2(0, 44)
	sign_in_button.pressed.connect(_on_sign_in_pressed)
	card.add_child(sign_in_button)

	var forgot_link := LinkButton.new()
	forgot_link.text = tr("Forgot password?")
	forgot_link.pressed.connect(_on_forgot_password_pressed)
	card.add_child(forgot_link)

func _update_sign_up_enabled() -> void:
	if _account_sign_up_button:
		_account_sign_up_button.disabled = not _account_terms_check.button_pressed

func _build_signed_in_account_ui() -> void:
	_add_section_header(account_vbox, tr("Account"))
	var card := _add_section_card(account_vbox)

	var status_label := _make_row_label(tr("Signed in"))
	card.add_child(status_label)

	var sign_out_button := Button.new()
	sign_out_button.text = tr("Sign Out")
	sign_out_button.custom_minimum_size = Vector2(0, 44)
	sign_out_button.pressed.connect(_on_sign_out_pressed)
	card.add_child(sign_out_button)

	card.add_child(HSeparator.new())

	var delete_button := Button.new()
	delete_button.text = tr("Delete my account")
	delete_button.custom_minimum_size = Vector2(0, 44)
	delete_button.pressed.connect(_on_delete_account_pressed)
	card.add_child(delete_button)

func _on_sign_up_pressed() -> void:
	auth_manager.sign_up(_account_email_field.text, _account_password_field.text)

func _on_sign_in_pressed() -> void:
	auth_manager.sign_in(_account_email_field.text, _account_password_field.text)

func _on_sign_out_pressed() -> void:
	auth_manager.sign_out()

func _on_forgot_password_pressed() -> void:
	if not _account_email_field or _account_email_field.text.is_empty():
		_show_message(tr("Enter your email above first."), true)
		return
	auth_manager.request_password_reset(_account_email_field.text)
	_show_message(tr("If that email has an account, a reset link is on its way."))

func _on_delete_account_pressed() -> void:
	var choice: int = await ChoiceDialogScript.new(
		tr("Delete Account?"),
		tr("This permanently deletes your cloud account and save. Your local save is untouched. This cannot be undone."),
		PackedStringArray([tr("Cancel"), tr("Delete Account")])
	).ask(self)
	if choice == 1:
		auth_manager.delete_account()

func _on_auth_signed_in(_user_id: String) -> void:
	_populate_account_tab()
	_show_message(tr("Signed in."))

func _on_auth_signed_out() -> void:
	_populate_account_tab()

func _on_auth_error(message: String) -> void:
	_show_message(message, true)

func _on_sign_up_pending_confirmation() -> void:
	_show_message(tr("Check your email to confirm your account, then sign in."))

## M15 Requirement 1.6 — themed error/status toast, matching WorldHUD.announce_event()'s visual
## recipe (M9's framed-announcement pattern). Self-contained rather than calling WorldHUD
## directly, since SettingsMenu is also reachable from MainMenu where no WorldHUD exists.
func _show_message(text_content: String, is_warning: bool = false) -> void:
	# M22: the kit's wood frame (was a flat navy StyleBoxFlat), added to
	# root_control — outside the parchment page — so its text stays light.
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WoodFramePanel"

	var label := Label.new()
	label.text = text_content
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_warning:
		label.add_theme_color_override("font_color", UITokens.palette().hp_low)
	panel.add_child(label)

	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -300.0
	panel.offset_right = 300.0
	panel.offset_top = 100.0
	# Height comes from the content (the wood frame's margins + wrapped text),
	# not a fixed 60px band that the kit frame's own margins would overflow.
	panel.offset_bottom = panel.offset_top
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	PirateThemeBuilder.apply_mobile_control_scaling(panel)

	root_control.add_child(panel)

	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(panel.queue_free)

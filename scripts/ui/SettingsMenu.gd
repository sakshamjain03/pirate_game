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
@onready var master_slider: HSlider = $Control/TabContainer/General/GridContainer/MasterSlider
@onready var music_slider: HSlider = $Control/TabContainer/General/GridContainer/MusicSlider
@onready var sfx_slider: HSlider = $Control/TabContainer/General/GridContainer/SFXSlider
@onready var fullscreen_check: CheckButton = $Control/TabContainer/General/GridContainer/FullscreenCheckButton
@onready var resolution_option: OptionButton = $Control/TabContainer/General/GridContainer/ResolutionOptionButton
@onready var vsync_check: CheckButton = $Control/TabContainer/General/GridContainer/VSyncCheckButton
@onready var back_button: Button = $Control/BackButton
@onready var replay_tutorial_button: Button = $Control/TabContainer/General/GridContainer/ReplayTutorialButton
@onready var grid_container: GridContainer = $Control/TabContainer/General/GridContainer
@onready var fullscreen_label: Label = $Control/TabContainer/General/GridContainer/FullscreenLabel
@onready var resolution_label: Label = $Control/TabContainer/General/GridContainer/ResolutionLabel
@onready var vsync_label: Label = $Control/TabContainer/General/GridContainer/VSyncLabel

@onready var controls_vbox: VBoxContainer = $Control/TabContainer/Controls/ScrollContainer/ControlsVBox
@onready var account_vbox: VBoxContainer = $Control/TabContainer/Account/ScrollContainer/AccountVBox

var _awaiting_rebind: String = ""
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
	_settings_card = Panel.new()
	_settings_card.name = "SettingsCard"
	_settings_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_card.offset_left = 72.0
	_settings_card.offset_top = 32.0
	_settings_card.offset_right = -72.0
	_settings_card.offset_bottom = -32.0
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("17243a")
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color("b98a3f")
	card_style.corner_radius_top_left = 18
	card_style.corner_radius_top_right = 18
	card_style.corner_radius_bottom_left = 18
	card_style.corner_radius_bottom_right = 18
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	card_style.shadow_size = 16
	_settings_card.add_theme_stylebox_override("panel", card_style)
	root_control.add_child(_settings_card)
	root_control.move_child(_settings_card, 1)

	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_GOLD_BRIGHT)
	title_label.add_theme_color_override("font_outline_color", Color("07101d"))
	title_label.add_theme_constant_override("outline_size", 6)
	tab_container.add_theme_font_size_override("font_size", 18)
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
	title_label.add_theme_font_size_override("font_size", 34)
	tab_container.offset_left = side_margin + 16.0
	tab_container.offset_top = top_margin + 78.0
	tab_container.offset_right = -side_margin - 16.0
	tab_container.offset_bottom = -bottom_margin - 76.0
	tab_container.add_theme_font_size_override("font_size", 22)

	for ctrl in [fullscreen_label, fullscreen_check, resolution_label, resolution_option,
			vsync_label, vsync_check]:
		ctrl.visible = false

	# General becomes a vertical, scrollable set of settings rows. A phone
	# should never compress a label and its control into an unreadable two-column
	# desktop grid, especially in landscape or split-screen tablet mode.
	grid_container.columns = 1
	grid_container.add_theme_constant_override("h_separation", 12)
	grid_container.add_theme_constant_override("v_separation", 10)
	grid_container.custom_minimum_size = Vector2(maxf(320.0, tab_container.size.x - 32.0), 0.0)
	grid_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	grid_container.position = Vector2(16.0, 16.0)
	if not _mobile_general_scroll:
		_mobile_general_scroll = ScrollContainer.new()
		_mobile_general_scroll.name = "GeneralScrollContainer"
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
		label.add_theme_font_size_override("font_size", 21)
		label.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_GOLD_BRIGHT)
		label.custom_minimum_size = Vector2(0.0, 32.0)
	for slider in [master_slider, music_slider, sfx_slider]:
		slider.custom_minimum_size = Vector2(0.0, 64.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_tutorial_button.custom_minimum_size = Vector2(0.0, 68.0)
	replay_tutorial_button.add_theme_font_size_override("font_size", 20)
	back_button.custom_minimum_size = Vector2(176.0, 62.0)
	back_button.position = Vector2(viewport_size.x * 0.5 - 88.0, viewport_size.y - bottom_margin - 66.0)
	back_button.add_theme_font_size_override("font_size", 21)

	_style_mobile_scroll_content(controls_vbox)
	_style_mobile_scroll_content(account_vbox)


func _style_mobile_scroll_content(container: VBoxContainer) -> void:
	## Controls and Account are built at runtime, so normalise their type and
	## touch targets after population. The internal page margin is deliberately
	## consistent with General's scroll view.
	container.add_theme_constant_override("separation", 14)
	container.add_theme_constant_override("margin_left", 18)
	container.add_theme_constant_override("margin_right", 18)
	container.custom_minimum_size.x = maxf(320.0, tab_container.size.x - 36.0)
	# Section headers/cards (added by _add_section_header/_add_section_card)
	# nest rows inside PanelContainer > VBoxContainer, so this needs to recurse
	# rather than assume every row is a direct child of `container`.
	_style_mobile_rows_recursive(container)


func _style_mobile_rows_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Button or child is CheckButton or child is OptionButton or child is LineEdit:
			child.custom_minimum_size.y = maxf(child.custom_minimum_size.y, 64.0)
			child.add_theme_font_size_override("font_size", 20)
		elif child is Label:
			if not child.has_theme_font_size_override("font_size"):
				child.add_theme_font_size_override("font_size", 19)
		elif child is HBoxContainer:
			child.custom_minimum_size.y = maxf(child.custom_minimum_size.y, 64.0)
			for row_child in child.get_children():
				if row_child is Label:
					row_child.add_theme_font_size_override("font_size", 19)
				elif row_child is Button or row_child is OptionButton:
					row_child.custom_minimum_size.y = maxf(row_child.custom_minimum_size.y, 60.0)
					row_child.add_theme_font_size_override("font_size", 19)
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
			label.custom_minimum_size.x = 200
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
	var advanced_fire := CheckButton.new()
	advanced_fire.text = tr("Advanced Fire Controls")
	advanced_fire.button_pressed = settings_manager.mobile_advanced_combat_controls
	advanced_fire.toggled.connect(func(enabled: bool):
		settings_manager.mobile_advanced_combat_controls = enabled
		settings_manager.save_settings())
	card.add_child(advanced_fire)
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
	tilt_axis.add_item(tr("Default"), 0)
	tilt_axis.add_item(tr("Inverted"), 1)
	tilt_axis.add_item(tr("Alt Axis"), 2)
	tilt_axis.add_item(tr("Alt Axis (Inverted)"), 3)
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
	label.custom_minimum_size.x = 200
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
	## 2026-09-24 — player-selectable body/UI font. Default (Cinzel) is what
	## PirateThemeBuilder.build() now uses project-wide after PirataOne was
	## found illegible for dense HUD numeric text at small sizes; kept here as
	## opt-in choices for players who want the original pirate blackletter
	## look, or their own OS Times New Roman. See PirateThemeBuilder._load_body_font().
	var hbox := HBoxContainer.new()
	var label := _make_row_label(tr("UI Font"))
	label.custom_minimum_size.x = 200
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


func _add_input_slider(card: VBoxContainer, label_text: String, min_v: float, max_v: float, step: float,
		value: float, on_changed: Callable) -> void:
	var hbox := HBoxContainer.new()
	var label := _make_row_label(label_text)
	label.custom_minimum_size.x = 200
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = 200
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)

	var value_label := _make_row_label("%.2f" % value)
	value_label.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_GOLD_BRIGHT)
	value_label.custom_minimum_size.x = 50
	hbox.add_child(value_label)

	slider.value_changed.connect(func(v: float):
		value_label.text = "%.2f" % v
		on_changed.call(v))

	card.add_child(hbox)


## M18 settings uplift — every screen-built Label previously relied on the
## theme's fallback Label color, which reads fine on some panels but low-
## contrast on others (Account/Controls tabs reported as hard to read).
## Every dynamically-built row label now goes through this single helper so
## color stays consistent and correctable in one place.
func _make_row_label(text_content: String) -> Label:
	var label := Label.new()
	label.text = text_content
	label.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_TEXT_LIGHT)
	return label


## Bold gold section title used to head each grouped card in Controls/Account.
func _add_section_header(parent: VBoxContainer, text_content: String) -> void:
	var label := Label.new()
	label.text = text_content
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_GOLD_BRIGHT)
	label.add_theme_color_override("font_outline_color", PirateThemeBuilder.COLOR_SHADOW_DARK)
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)


## Nested gold-bordered card grouping one logical settings section — the
## CoC-style "settings group panel" look, replacing a single flat column of
## unrelated rows with no visual separation.
func _add_section_card(parent: VBoxContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.071, 0.102, 0.18, 0.55)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = PirateThemeBuilder.COLOR_GOLD.darkened(0.3)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	parent.add_child(panel)
	parent.add_child(HSeparator.new())
	return vbox


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

func _on_music_slider_changed(value: float) -> void:
	settings_manager.music_volume = value
	audio_manager.set_bus_volume("Music", value)
	settings_manager.save_settings()

func _on_sfx_slider_changed(value: float) -> void:
	settings_manager.sfx_volume = value
	audio_manager.set_bus_volume("SFX", value)
	settings_manager.save_settings()

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
	terms_link.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_GOLD_BRIGHT)
	terms_link.pressed.connect(func(): OS.shell_open(TERMS_URL))
	terms_hbox.add_child(terms_link)

	terms_hbox.add_child(_make_row_label(tr(" and ")))

	var privacy_link := LinkButton.new()
	privacy_link.text = tr("Privacy Policy")
	privacy_link.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_GOLD_BRIGHT)
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
	forgot_link.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_GOLD)
	forgot_link.pressed.connect(_on_forgot_password_pressed)
	card.add_child(forgot_link)

func _update_sign_up_enabled() -> void:
	if _account_sign_up_button:
		_account_sign_up_button.disabled = not _account_terms_check.button_pressed

func _build_signed_in_account_ui() -> void:
	_add_section_header(account_vbox, tr("Account"))
	var card := _add_section_card(account_vbox)

	var status_label := _make_row_label(tr("Signed in"))
	status_label.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_GOLD_BRIGHT)
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
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.95)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = PirateThemeBuilder.COLOR_GOLD
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text_content
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override(
		"font_color",
		PirateThemeBuilder.COLOR_RED_HEALTH if is_warning else PirateThemeBuilder.COLOR_GOLD_BRIGHT)
	panel.add_child(label)

	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -300.0
	panel.offset_right = 300.0
	panel.offset_top = 100.0
	panel.offset_bottom = 160.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	PirateThemeBuilder.apply_mobile_control_scaling(panel)

	root_control.add_child(panel)

	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(panel.queue_free)

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
@onready var master_slider: HSlider = $Control/TabContainer/General/GridContainer/MasterSlider
@onready var music_slider: HSlider = $Control/TabContainer/General/GridContainer/MusicSlider
@onready var sfx_slider: HSlider = $Control/TabContainer/General/GridContainer/SFXSlider
@onready var fullscreen_check: CheckButton = $Control/TabContainer/General/GridContainer/FullscreenCheckButton
@onready var resolution_option: OptionButton = $Control/TabContainer/General/GridContainer/ResolutionOptionButton
@onready var vsync_check: CheckButton = $Control/TabContainer/General/GridContainer/VSyncCheckButton
@onready var back_button: Button = $Control/BackButton
@onready var replay_tutorial_button: Button = $Control/TabContainer/General/GridContainer/ReplayTutorialButton

@onready var controls_vbox: VBoxContainer = $Control/TabContainer/Controls/ScrollContainer/ControlsVBox
@onready var account_vbox: VBoxContainer = $Control/TabContainer/Account/ScrollContainer/AccountVBox

var _awaiting_rebind: String = ""

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

var _account_email_field: LineEdit
var _account_password_field: LineEdit
var _account_terms_check: CheckBox
var _account_sign_up_button: Button

func _ready() -> void:
	# M9 Requirement 3 (D70) — the only screen in scenes/ui/ that never applied
	# the theme, rendering as raw default Godot UI.
	root_control.theme = PirateThemeBuilder.build()

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

func _populate_controls() -> void:
	for child in controls_vbox.get_children():
		child.queue_free()
		
	_add_input_feel_controls()
	_add_graphics_quality_control()

	# Was a hardcoded copy of the action list, which had already drifted — it
	# predated M8 and so offered no way to rebind `special_broadside` or
	# `captain_ability`. SettingsManager.REBINDABLE_ACTIONS is the single source
	# of truth the save/load path already uses.
	for action in SettingsManager.REBINDABLE_ACTIONS:
		if InputMap.has_action(action):
			var hbox = HBoxContainer.new()
			var label = Label.new()
			label.text = tr(action.capitalize().replace("_", " "))
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
			controls_vbox.add_child(hbox)
			
	var reset_btn = Button.new()
	reset_btn.text = tr("Reset to Defaults")
	reset_btn.pressed.connect(func():
		InputManager.reset_to_defaults()
		_populate_controls()
	)
	controls_vbox.add_child(reset_btn)

func _add_input_feel_controls() -> void:
	## M2 Task 6.3 — adjustable sensitivity and dead zone. Persisted through
	## SettingsManager alongside every other setting; InputManager picks the new
	## values up from its `settings_changed` connection.
	_add_input_slider(tr("Sensitivity"), 0.1, 3.0, 0.05, settings_manager.input_sensitivity,
		func(v: float):
			settings_manager.input_sensitivity = v
			InputManager.set_sensitivity(v)
			settings_manager.save_settings())

	_add_input_slider(tr("Dead Zone"), 0.0, 0.9, 0.05, settings_manager.input_dead_zone,
		func(v: float):
			settings_manager.input_dead_zone = v
			InputManager.set_dead_zone(v)
			settings_manager.save_settings())

	controls_vbox.add_child(HSeparator.new())


func _add_graphics_quality_control() -> void:
	## M2 Task 12.1 — quality settings adaptation. Drives
	## OceanController.quality_level (currently the only quality-scaled
	## system) via SettingsManager.settings_changed, the same pattern
	## InputManager uses for sensitivity/dead zone.
	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = tr("Graphics Quality")
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

	controls_vbox.add_child(hbox)
	controls_vbox.add_child(HSeparator.new())


func _add_input_slider(label_text: String, min_v: float, max_v: float, step: float,
		value: float, on_changed: Callable) -> void:
	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
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

	var value_label := Label.new()
	value_label.text = "%.2f" % value
	value_label.custom_minimum_size.x = 50
	hbox.add_child(value_label)

	slider.value_changed.connect(func(v: float):
		value_label.text = "%.2f" % v
		on_changed.call(v))

	controls_vbox.add_child(hbox)


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

func _build_signed_out_account_ui() -> void:
	var email_label := Label.new()
	email_label.text = tr("Email")
	account_vbox.add_child(email_label)

	_account_email_field = LineEdit.new()
	_account_email_field.custom_minimum_size = Vector2(0, 44)
	account_vbox.add_child(_account_email_field)

	var password_label := Label.new()
	password_label.text = tr("Password")
	account_vbox.add_child(password_label)

	_account_password_field = LineEdit.new()
	_account_password_field.secret = true
	_account_password_field.custom_minimum_size = Vector2(0, 44)
	account_vbox.add_child(_account_password_field)

	account_vbox.add_child(HSeparator.new())

	var terms_hbox := HBoxContainer.new()
	_account_terms_check = CheckBox.new()
	_account_terms_check.toggled.connect(func(_pressed: bool): _update_sign_up_enabled())
	terms_hbox.add_child(_account_terms_check)

	var terms_label := Label.new()
	terms_label.text = tr("I agree to the ")
	terms_hbox.add_child(terms_label)

	var terms_link := LinkButton.new()
	terms_link.text = tr("Terms of Service")
	terms_link.pressed.connect(func(): OS.shell_open(TERMS_URL))
	terms_hbox.add_child(terms_link)

	var and_label := Label.new()
	and_label.text = tr(" and ")
	terms_hbox.add_child(and_label)

	var privacy_link := LinkButton.new()
	privacy_link.text = tr("Privacy Policy")
	privacy_link.pressed.connect(func(): OS.shell_open(PRIVACY_URL))
	terms_hbox.add_child(privacy_link)

	account_vbox.add_child(terms_hbox)

	_account_sign_up_button = Button.new()
	_account_sign_up_button.text = tr("Sign Up")
	_account_sign_up_button.custom_minimum_size = Vector2(0, 44)
	_account_sign_up_button.disabled = true
	_account_sign_up_button.pressed.connect(_on_sign_up_pressed)
	account_vbox.add_child(_account_sign_up_button)

	var sign_in_button := Button.new()
	sign_in_button.text = tr("Sign In")
	sign_in_button.custom_minimum_size = Vector2(0, 44)
	sign_in_button.pressed.connect(_on_sign_in_pressed)
	account_vbox.add_child(sign_in_button)

	var forgot_link := LinkButton.new()
	forgot_link.text = tr("Forgot password?")
	forgot_link.pressed.connect(_on_forgot_password_pressed)
	account_vbox.add_child(forgot_link)

func _update_sign_up_enabled() -> void:
	if _account_sign_up_button:
		_account_sign_up_button.disabled = not _account_terms_check.button_pressed

func _build_signed_in_account_ui() -> void:
	var status_label := Label.new()
	status_label.text = tr("Signed in")
	account_vbox.add_child(status_label)

	var sign_out_button := Button.new()
	sign_out_button.text = tr("Sign Out")
	sign_out_button.custom_minimum_size = Vector2(0, 44)
	sign_out_button.pressed.connect(_on_sign_out_pressed)
	account_vbox.add_child(sign_out_button)

	account_vbox.add_child(HSeparator.new())

	var delete_button := Button.new()
	delete_button.text = tr("Delete my account")
	delete_button.custom_minimum_size = Vector2(0, 44)
	delete_button.pressed.connect(_on_delete_account_pressed)
	account_vbox.add_child(delete_button)

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

	root_control.add_child(panel)

	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(panel.queue_free)

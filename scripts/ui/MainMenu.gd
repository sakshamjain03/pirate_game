class_name MainMenu extends CanvasLayer

## Purpose: Main menu screen for Pirate Empire.
## Responsibilities: Applies pirate theme, handles navigation to game/settings/credits.
## Dependencies: PirateThemeBuilder, SceneManager, SaveManager, ResourceManager autoloads
## Limitations: Continue/New Game both load the same World scene; no save-slot selection.
## TODOs: Add confirmation dialog before New Game overwrites an existing save.

@onready var root_control    : Control = $Control
@onready var button_panel    : PanelContainer = $Control/ButtonPanel
@onready var continue_button : Button = $Control/ButtonPanel/VBoxContainer/ContinueButton
@onready var new_game_button : Button = $Control/ButtonPanel/VBoxContainer/NewGameButton
@onready var settings_button : Button = $Control/ButtonPanel/VBoxContainer/SettingsButton
@onready var credits_button  : Button = $Control/ButtonPanel/VBoxContainer/CreditsButton
@onready var quit_button     : Button = $Control/ButtonPanel/VBoxContainer/QuitButton
@onready var title_label     : Label  = $Control/TitleContainer/TitleLabel
@onready var subtitle_label  : Label  = $Control/TitleContainer/SubtitleLabel
@onready var version_label   : Label  = $Control/VersionLabel

## M13 Task 16.5 follow-up (2026-09-19) — main menu buttons measured 240x44
## (≈16dp tall), one of the specifically flagged "game menu buttons too
## small" complaints. PC keeps the original size (already comfortable for a
## mouse); mobile gets real touch-sized buttons plus a wider/taller
## ButtonPanel so they fit without clipping.
const MOBILE_BUTTON_MIN_SIZE := Vector2(320, 64)

var _tween: Tween

func _ready() -> void:
	_apply_theme()
	_animate_title()
	_connect_buttons()
	_show_crash_report_notice()
	if AudioManager: AudioManager.play_music("main_menu")

func _apply_theme() -> void:
	var theme := PirateThemeBuilder.build()
	root_control.theme = theme
	PirateThemeBuilder.apply_button_juice(root_control)
	if not OS.has_feature("pc"):
		_apply_mobile_button_sizing()

func _apply_mobile_button_sizing() -> void:
	for btn in [continue_button, new_game_button, settings_button, credits_button, quit_button]:
		btn.custom_minimum_size = MOBILE_BUTTON_MIN_SIZE
	button_panel.offset_left   = -170.0
	button_panel.offset_right  = 170.0
	button_panel.offset_top    = -220.0
	button_panel.offset_bottom = 220.0

func _connect_buttons() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	if SaveManager.has_recoverable_save_data():
		continue_button.visible = true
		continue_button.grab_focus()
	else:
		continue_button.visible = false
		new_game_button.grab_focus()

func _animate_title() -> void:
	## Fade in and gentle float animation on the title
	if not title_label:
		return
	title_label.modulate.a = 0.0
	if subtitle_label:
		subtitle_label.modulate.a = 0.0

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(title_label,    "modulate:a", 1.0, 1.2).set_delay(0.2)
	_tween.tween_property(subtitle_label, "modulate:a", 1.0, 1.2).set_delay(0.5)

func _on_continue_pressed() -> void:
	SceneManager.change_scene_with_fade("res://scenes/world/World.tscn")

func _on_new_game_pressed() -> void:
	SaveManager.delete_save()
	AnalyticsManager.log_first_event("new_game_started")
	# Reset resources for fresh start since it's an autoload
	ResourceManager.current_resources = {
		"gold": 200, "wood": 50, "iron": 20, "rum": 10
	}
	TutorialManager.start_new_game_session()
	SceneManager.change_scene_with_fade("res://scenes/world/World.tscn")

func _on_settings_pressed() -> void:
	SceneManager.change_scene_with_fade("res://scenes/ui/SettingsMenu.tscn")

func _on_credits_pressed() -> void:
	SceneManager.change_scene_with_fade("res://scenes/ui/CreditsScreen.tscn")

func _on_quit_pressed() -> void:
	CrashReporter.mark_clean_shutdown()
	get_tree().quit()


func _show_crash_report_notice() -> void:
	if not CrashReporter.has_pending_report:
		return
	var notice := AcceptDialog.new()
	notice.title = tr("Previous Session Ended Unexpectedly")
	notice.dialog_text = tr("A local diagnostic report is ready for support. It contains no personal information and will not be sent automatically.")
	notice.confirmed.connect(CrashReporter.dismiss_pending_report)
	add_child(notice)
	notice.popup_centered()

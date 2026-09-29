class_name MainMenu extends CanvasLayer

## Purpose: Main menu screen for Pirate Empire.
## Responsibilities: Applies pirate theme, handles navigation to game/settings/credits.
## Dependencies: PirateThemeBuilder, SceneManager, SaveManager, ResourceManager autoloads
## Limitations: Continue/New Game both load the same World scene; no save-slot selection.
## TODOs: Add confirmation dialog before New Game overwrites an existing save.

@onready var root_control    : Control = $Control
@onready var button_panel    : PanelContainer = $Control/MainVBox/ButtonPanel
@onready var continue_button : Button = $Control/MainVBox/ButtonPanel/VBoxContainer/ContinueButton
@onready var new_game_button : Button = $Control/MainVBox/ButtonPanel/VBoxContainer/NewGameButton
@onready var gear_button     : Button = $Control/GearButton
@onready var store_button    : Button = $Control/MainVBox/ButtonPanel/VBoxContainer/StoreButton
@onready var credits_button  : Button = $Control/MainVBox/ButtonPanel/VBoxContainer/CreditsButton
@onready var quit_button     : Button = $Control/MainVBox/ButtonPanel/VBoxContainer/QuitButton
@onready var title_label     : Label  = $Control/MainVBox/TitlePlaque/TitleVBox/TitleLabel
@onready var subtitle_label  : Label  = $Control/MainVBox/TitlePlaque/TitleVBox/SubtitleLabel
@onready var version_label   : Label  = $Control/VersionLabel
## M17 Requirement 4.1 — the store's other required entry point.
@onready var store_screen    : StoreScreen = %StoreScreen

## M22 Phase 4.1 (design.md §7/§8a) — one Primary CTA (coral, glowing),
## brass secondaries, a round gear icon button for Settings. Sized generous
## and chunky on PC on purpose (the design brief's own "epic world, funny
## furniture" aesthetic), and always run through scaled_button_size() so
## the MOBILE_MIN_TOUCH_TARGET floor from apply_button_juice() is never
## silently undone afterward — the exact §8a root cause this replaces.
const _PRIMARY_SIZE := Vector2(340, 104)
const _SECONDARY_SIZE := Vector2(300, 92)
const _GEAR_SIZE := Vector2(96, 96)

var _tween: Tween
## Guards a second New Game press while the lessons prompt is already up.
var _new_game_prompt_open := false

func _ready() -> void:
	_apply_theme()
	_animate_title()
	_connect_buttons()
	_setup_maelstrom_button()
	_show_crash_report_notice()
	if AudioManager: AudioManager.play_music("main_menu")

func _apply_theme() -> void:
	var theme := PirateThemeBuilder.build()
	root_control.theme = theme
	PirateThemeBuilder.apply_button_juice(root_control)
	_apply_button_sizing()

func _apply_button_sizing() -> void:
	for btn in [continue_button, new_game_button, store_button, credits_button, quit_button]:
		btn.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_SECONDARY_SIZE)
	gear_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_GEAR_SIZE)
	# Whichever CTA is actually the primary action gets the bigger Primary
	# size + glow; done here (after the uniform secondary pass above) so it
	# isn't undone by it. _connect_buttons() decides which one that is.

func _connect_buttons() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	gear_button.pressed.connect(_on_settings_pressed)
	store_button.pressed.connect(store_screen.open)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# One Primary CTA per screen (design.md §7) — Continue when there's a
	# save to resume, New Game otherwise. The other stays a brass secondary
	# rather than hidden: a player with a save may still want to start over.
	var primary_btn: Button
	if SaveManager.has_recoverable_save_data():
		continue_button.visible = true
		primary_btn = continue_button
	else:
		continue_button.visible = false
		primary_btn = new_game_button
	primary_btn.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_PRIMARY_SIZE)
	PirateThemeBuilder.mark_primary(primary_btn)
	primary_btn.grab_focus()

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
	## M28 Requirement 3.1 — lessons are a New Game choice. The story, objectives
	## and rewards run either way; only the coach-card hints are skipped.
	if _new_game_prompt_open:
		return
	_new_game_prompt_open = true
	var returning: bool = TutorialManager.tutorial_completed
	var choice: int = await ChoiceDialog.new(
		tr("New Game"),
		tr("Short hints appear as each part of the game comes up. The story plays either way."),
		new_game_lesson_choices(returning)
	).ask(self)
	_new_game_prompt_open = false
	_start_new_game(wants_lessons_for(choice, returning))


## ChoiceDialog focuses its first button, so a returning player (onboarding
## already finished once on this install) gets "I know these waters" first.
static func new_game_lesson_choices(returning: bool) -> PackedStringArray:
	var teach := TranslationServer.translate("Teach me the ropes")
	var skip := TranslationServer.translate("I know these waters")
	return PackedStringArray([skip, teach]) if returning else PackedStringArray([teach, skip])


static func wants_lessons_for(choice: int, returning: bool) -> bool:
	return choice == 1 if returning else choice == 0


func _start_new_game(wants_lessons: bool) -> void:
	SaveManager.delete_save()
	AnalyticsManager.log_first_event("new_game_started")
	# Every campaign autoload back to its boot state, not just resources: a New
	# Game after playing in the same session used to keep chapter progress,
	# fleet, techs, heat and timers from the previous run.
	SaveManager.reset_to_new_game()
	TutorialManager.start_new_game_session()
	TutorialManager.start_new_game_lessons(wants_lessons)
	if not wants_lessons:
		# "I know these waters": every tab open from the start. Chapter 1's
		# dialogue, objectives and rewards still run (Requirement 3.2).
		TutorialManager.skip_tutorial()
	SceneManager.change_scene_with_fade("res://scenes/world/World.tscn")

## M26 Requirement 1.1/1.2 — the endless survival mode, available from a fresh
## install with no save. A run never touches the campaign save; see MaelstromRun.
func _setup_maelstrom_button() -> void:
	# On the main menu no run is active, whatever path led here (Requirement 1.4).
	SceneManager.game_mode = SceneManager.GameMode.CAMPAIGN
	var btn := get_node_or_null("Control/MainVBox/ButtonPanel/VBoxContainer/MaelstromButton") as Button
	if not btn:
		return
	btn.visible = true
	btn.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_SECONDARY_SIZE)
	btn.pressed.connect(_on_maelstrom_pressed)


func _on_maelstrom_pressed() -> void:
	SceneManager.game_mode = SceneManager.GameMode.MAELSTROM
	SceneManager.change_scene_with_fade(MaelstromRun.MAELSTROM_SCENE)


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
	# M22 Phase 4.4 — the same parchment ChoiceDialog modal as every other
	# prompt, not a stock AcceptDialog. The AcceptDialog this replaces was
	# never actually themed: a Window parented under this CanvasLayer can't
	# inherit root_control's theme (Godot's theme lookup stops at any
	# non-Control/non-Window parent), and once themed by hand its embedded title
	# bar still drew outside its border stylebox. Found by the M22 sweep's
	# first-ever capture of this notice.
	await ChoiceDialog.new(
		tr("Previous Session Ended Unexpectedly"),
		tr("A local diagnostic report is ready for support. It contains no personal information and will not be sent automatically."),
		PackedStringArray([tr("OK")])
	).ask(self)
	CrashReporter.dismiss_pending_report()

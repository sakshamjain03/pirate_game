class_name PauseMenu extends Control

## Purpose: Minimal in-game pause menu, opened with the `pause` action (Escape).
## Responsibilities: Pauses the game tree, offers Resume / Settings / Quit to Menu.
## Dependencies: PirateThemeBuilder, SceneManager

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel

## M22 Phase 4.2 (design.md §7) — Resume is the one Primary CTA per screen;
## Settings/Quit stay brass secondaries. Sized generous on purpose, same
## reasoning as MainMenu.gd's own _PRIMARY_SIZE/_SECONDARY_SIZE consts.
const _PRIMARY_SIZE := Vector2(280, 92)
const _SECONDARY_SIZE := Vector2(280, 80)

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	hide()

	# Keep processing input while get_tree().paused is true, so Resume/Escape
	# can actually close this menu again.
	process_mode = Node.PROCESS_MODE_ALWAYS

	theme = PirateThemeBuilder.build()
	PirateThemeBuilder.dress_modal_dim($ColorRect)  # M22 6c: v0.3 teal-black backdrop
	PirateThemeBuilder.apply_button_juice(self)
	resume_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_PRIMARY_SIZE)
	PirateThemeBuilder.mark_primary(resume_button)
	for btn in [settings_button, quit_button]:
		btn.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_SECONDARY_SIZE)
	if PirateThemeBuilder.is_mobile():
		panel.custom_minimum_size = PirateThemeBuilder.scaled_size(panel.custom_minimum_size)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

func open() -> void:
	show()
	UIMotion.modal_enter(panel, $ColorRect)
	get_tree().paused = true
	resume_button.grab_focus()

func close() -> void:
	hide()
	get_tree().paused = false

func _on_resume_pressed() -> void:
	close()

func _on_settings_pressed() -> void:
	# SettingsMenu is a full scene, not an overlay, and its own Back button
	# already returns to whatever pushed it via SceneManager.go_back() — since
	# World.tscn was pushed to history on the way in, this correctly resumes
	# gameplay rather than needing special-case return logic here.
	# M30 Requirement 1.4 — save before leaving World
	SaveManager.save_game()
	get_tree().paused = false
	SceneManager.change_scene_with_fade("res://scenes/ui/SettingsMenu.tscn")

func _on_quit_pressed() -> void:
	# M30 Requirement 1.4 — save before leaving World
	SaveManager.save_game()
	get_tree().paused = false
	SceneManager.change_scene_with_fade("res://scenes/ui/MainMenu.tscn")

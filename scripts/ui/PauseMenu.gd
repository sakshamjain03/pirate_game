class_name PauseMenu extends Control

## Purpose: Minimal in-game pause menu, opened with the `pause` action (Escape).
## Responsibilities: Pauses the game tree, offers Resume / Settings / Quit to Menu.
## Dependencies: PirateThemeBuilder, SceneManager

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	hide()

	# Keep processing input while get_tree().paused is true, so Resume/Escape
	# can actually close this menu again.
	process_mode = Node.PROCESS_MODE_ALWAYS

	theme = PirateThemeBuilder.build()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

func open() -> void:
	show()
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
	get_tree().paused = false
	SceneManager.change_scene_with_fade("res://scenes/ui/SettingsMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().paused = false
	SceneManager.change_scene_with_fade("res://scenes/ui/MainMenu.tscn")

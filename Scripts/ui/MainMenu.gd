# MainMenu.gd
extends CanvasLayer
class_name MainMenu

## Main menu screen for Pirate Empire.
## Handles navigation to game, settings, credits, and quitting the application.

@onready var play_button: Button = $Control/VBoxContainer/PlayButton
@onready var settings_button: Button = $Control/VBoxContainer/SettingsButton
@onready var credits_button: Button = $Control/VBoxContainer/CreditsButton
@onready var quit_button: Button = $Control/VBoxContainer/QuitButton

func _ready() -> void:
	play_button.grab_focus()
	
	play_button.pressed.connect(_on_play_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _on_play_button_pressed() -> void:
	SceneManager.change_scene_with_fade("res://scenes/ui/GameWorld.tscn")

func _on_settings_button_pressed() -> void:
	SceneManager.change_scene_with_fade("res://scenes/ui/SettingsMenu.tscn")

func _on_credits_button_pressed() -> void:
	SceneManager.change_scene_with_fade("res://scenes/ui/CreditsScreen.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

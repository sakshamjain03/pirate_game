extends Control

## Boot.gd
## Purpose: Handles initialization, asset loading, and transitioning to main menu.
## Responsibilities: Serves as the entry point when the game launches.
## Dependencies: SceneManager
## Limitations: Currently simple transition; will handle real pre-loading later.
## TODOs: Implement asset preloading.

func _ready() -> void:
	SettingsManager.load_settings()
	_transition_to_main_menu()

func _transition_to_main_menu() -> void:
	SceneManager.change_scene_with_fade("res://scenes/ui/MainMenu.tscn", 0.4)

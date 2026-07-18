extends Control

# Boot.gd
# Handles initialization, asset loading, and transitioning to main menu.

func _ready() -> void:
	print("Pirate Empire Boot Sequence Started.")
	_transition_to_main_menu()

func _transition_to_main_menu() -> void:
	print("Transitioning to Main Menu...")
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	# get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

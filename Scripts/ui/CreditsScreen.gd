extends CanvasLayer
class_name CreditsScreen

## CreditsScreen
## Displays the credits and allows the user to return to the main menu.

@onready var back_button: Button = $Control/BackButton

func _ready() -> void:
	back_button.grab_focus()
	back_button.pressed.connect(_on_back_button_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.go_back()

func _on_back_button_pressed() -> void:
	SceneManager.go_back()

extends CanvasLayer
class_name CreditsScreen

## Purpose: Credits screen listing project attribution.
## Responsibilities: Displays credits text; returns to the previous screen on Back or ui_cancel.
## Dependencies: SceneManager autoload
## Limitations: Credits text is static BBCode set in the scene, not data-driven.
## TODOs: Pull credits content from a Resource once contributor list stabilizes.

@onready var root_control: Control = $Control
@onready var back_button: Button = $Control/BackButton

func _ready() -> void:
	# M9 Requirement 3 (D70) — the only other screen in scenes/ui/ that never
	# applied the theme, rendering as raw default Godot UI.
	root_control.theme = PirateThemeBuilder.build()
	back_button.grab_focus()
	back_button.pressed.connect(_on_back_button_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.go_back()

func _on_back_button_pressed() -> void:
	SceneManager.go_back()

extends CanvasLayer
class_name CreditsScreen

## Purpose: Credits screen listing project attribution.
## Responsibilities: Displays credits text; returns to the previous screen on Back or ui_cancel.
## Dependencies: SceneManager autoload
## Limitations: Credits text is static BBCode set in the scene, not data-driven.
## TODOs: Pull credits content from a Resource once contributor list stabilizes.

@onready var root_control: Control = $Control
@onready var back_button: Button = $Control/BackButton
@onready var title_label: Label = %TitleLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer

func _ready() -> void:
	# M9 Requirement 3 (D70) — the only other screen in scenes/ui/ that never
	# applied the theme, rendering as raw default Godot UI.
	root_control.theme = PirateThemeBuilder.build()
	PirateThemeBuilder.apply_button_juice(root_control)
	back_button.grab_focus()
	back_button.pressed.connect(_on_back_button_pressed)

	if PirateThemeBuilder.is_mobile():
		_apply_mobile_sizing()

func _apply_mobile_sizing() -> void:
	title_label.offset_left = PirateThemeBuilder.scaled(title_label.offset_left)
	title_label.offset_right = PirateThemeBuilder.scaled(title_label.offset_right)
	scroll_container.offset_left = PirateThemeBuilder.scaled(scroll_container.offset_left)
	scroll_container.offset_right = PirateThemeBuilder.scaled(scroll_container.offset_right)
	scroll_container.offset_top = PirateThemeBuilder.scaled(scroll_container.offset_top)
	scroll_container.offset_bottom = PirateThemeBuilder.scaled(scroll_container.offset_bottom)
	back_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(back_button.custom_minimum_size)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.go_back()

func _on_back_button_pressed() -> void:
	SceneManager.go_back()

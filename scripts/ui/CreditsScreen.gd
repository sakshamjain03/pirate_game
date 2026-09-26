extends CanvasLayer
class_name CreditsScreen

## Purpose: Credits screen listing project attribution.
## Responsibilities: Displays credits text; returns to the previous screen on Back or ui_cancel.
## Dependencies: SceneManager autoload
## Limitations: Credits text is static BBCode set in the scene, not data-driven.
## TODOs: Pull credits content from a Resource once contributor list stabilizes.

@onready var root_control: Control = $Control
@onready var back_button: Button = %BackButton
@onready var title_label: Label = %TitleLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var parchment: PanelContainer = %Parchment

## M22 Phase 4.5 — a parchment scroll (ink text, Germania headings via the
## theme's RichTextLabel fonts) with Back below it, all in one CenterContainer
## VBox. Replaces a bare RichTextLabel floating on a black ColorRect, whose
## title, text box and Back button were three independently hardcoded
## pixel offsets (the drift-prone pattern CLAUDE.md's fragile-areas list
## warns about).
const _BACK_SIZE := Vector2(240, 80)

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
	parchment.custom_minimum_size = PirateThemeBuilder.scaled_button_size(parchment.custom_minimum_size)
	scroll_container.custom_minimum_size.y = PirateThemeBuilder.scaled(scroll_container.custom_minimum_size.y)
	back_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(_BACK_SIZE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneManager.go_back()

func _on_back_button_pressed() -> void:
	SceneManager.go_back()

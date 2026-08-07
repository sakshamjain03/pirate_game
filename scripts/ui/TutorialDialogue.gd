class_name TutorialDialogue extends Control

## Purpose: Onboarding guide-assistant dialogue box (Quartermaster Higgins).
## Responsibilities: Renders the current TutorialManager step and relays
##                   Next/Skip presses back to it. Purely reactive — holds no
##                   step logic of its own.
## Dependencies: TutorialManager, PirateThemeBuilder

@onready var name_label: Label = %MentorNameLabel
@onready var text_label: Label = %MentorTextLabel
@onready var next_button: Button = %NextButton
@onready var skip_button: Button = %SkipButton

func _ready() -> void:
	hide()
	# No pause is ever applied for this dialogue (several steps require the
	# player to act while it's visible), but PROCESS_MODE_ALWAYS keeps it
	# consistent with the rest of the modal UI in case that ever changes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()

	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

	TutorialManager.step_changed.connect(_on_step_changed)
	TutorialManager.step_condition_met.connect(_on_condition_met)
	TutorialManager.tutorial_finished.connect(_on_tutorial_finished)

	if TutorialManager.tutorial_active:
		var step := TutorialManager.get_current_step()
		if not step.is_empty():
			_on_step_changed(step)

func _on_step_changed(step: Dictionary) -> void:
	name_label.text = step.get("mentor", "Quartermaster Higgins")
	text_label.text = step.get("text", "")
	next_button.visible = not step.has("wait_for")
	show()

func _on_condition_met() -> void:
	next_button.visible = true

func _on_next_pressed() -> void:
	TutorialManager.advance_step()

func _on_skip_pressed() -> void:
	TutorialManager.skip_tutorial()

func _on_tutorial_finished() -> void:
	hide()

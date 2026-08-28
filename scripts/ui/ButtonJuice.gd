class_name ButtonJuice extends Node

## Purpose: reusable press/hover feedback for any Button, without a custom
## Button subclass (AGENTS.md: composition over inheritance — same precedent
## as ChoiceDialog.gd being a standalone script rather than a base class every
## screen must inherit).
## Usage: add as a plain child Node under any Button (in a .tscn, or via
## `button.add_child(ButtonJuice.new())` for buttons built in code).
## M15.5 Requirement 4.

@export var press_scale: float = 0.94
@export var hover_scale: float = 1.03
@export var duration: float = 0.12

var _button: Button
var _tween: Tween

func _ready() -> void:
	_button = get_parent() as Button
	if not _button:
		push_warning("ButtonJuice must be a child of a Button")
		return
	_button.pivot_offset = _button.size * 0.5
	_button.resized.connect(func(): _button.pivot_offset = _button.size * 0.5)
	_button.button_down.connect(func(): _tween_to(press_scale))
	_button.button_up.connect(func(): _tween_to(hover_scale if _button.is_hovered() else 1.0))
	_button.mouse_entered.connect(func(): _tween_to(hover_scale))
	_button.mouse_exited.connect(func(): _tween_to(1.0))

func _tween_to(target_scale: float) -> void:
	if not is_instance_valid(_button):
		return
	if _tween:
		_tween.kill()
	_tween = _button.create_tween()
	_tween.tween_property(_button, "scale", Vector2(target_scale, target_scale), duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

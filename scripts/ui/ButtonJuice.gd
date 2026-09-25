class_name ButtonJuice extends Node

## Purpose: reusable press feedback for any Button, without a custom Button
## subclass (AGENTS.md: composition over inheritance — same precedent as
## ChoiceDialog.gd being a standalone script rather than a base class every
## screen must inherit).
## Usage: add as a plain child Node under any Button (in a .tscn, or via
## `button.add_child(ButtonJuice.new())` for buttons built in code).
## M15.5 Requirement 4. M22 Phase 3.3 (design.md §7): the press feedback is
## now the kit's own baked lip-drop art doing the heavy lifting (the
## "pressed" StyleBoxTexture already shows the body 4 design px lower with a
## shorter lip) — this node only adds the `self_modulate` darken-on-press
## on top, replacing the old 0.94/1.03 *scale* tween (which fought visually
## with the button's own lip-press art growing/shrinking underneath it).

var _button: Button
var _tween: Tween

func _ready() -> void:
	_button = get_parent() as Button
	if not _button:
		push_warning("ButtonJuice must be a child of a Button")
		return
	# Bound methods, not inline lambdas — found while testing this exact
	# press/release path (tests/test_theme_variations.gd) that a lambda
	# Callable connected to button_down/button_up can silently fail to fire
	# on a manually emitted signal in this Godot 4.3 build, while a bound
	# method fires reliably every time. Manual emit_signal is exactly how
	# the GUT test (and any future one) exercises this without real input,
	# so this isn't just a test-only workaround.
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)

func _on_button_down() -> void:
	_tween_to(UITokens.PRESS_DARKEN_TO, UITokens.PRESS_IN_SEC, Tween.TRANS_LINEAR)

func _on_button_up() -> void:
	_tween_to(1.0, UITokens.PRESS_OUT_SEC, Tween.TRANS_BACK)

func _tween_to(target: float, duration: float, trans: Tween.TransitionType) -> void:
	if not is_instance_valid(_button):
		return
	if _tween:
		_tween.kill()
	_tween = _button.create_tween()
	_tween.tween_property(_button, "self_modulate", Color(target, target, target, 1.0), duration)\
		.set_trans(trans).set_ease(Tween.EASE_OUT)

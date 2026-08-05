extends Node

# SceneManager.gd
# Handles loading, unloading, and transitioning between scenes smoothly with fade effects
# and history navigation support.
#
# Responsibilities:
# - Load and change scenes using file paths
# - Provide fade transition effects between scenes
# - Maintain scene history stack for go_back() functionality
# - Emit signals when scene changes complete
#
# Dependencies:
# - Godot Engine (Node, ColorRect, Tween, ResourceLoader)
#
# Limitations:
# - Requires all scenes to be accessible via res:// paths
# - No support for scene loading progress indicators
# - No retry mechanism for failed scene changes
#
# TODOs:
# - Add scene loading progress callback support
# - Implement scene cache/preloading for faster transitions
# - Add transition presets (fade, slide, dissolve)

signal scene_changed(new_path: String)

var _is_transitioning: bool = false
var _scene_history: Array[String] = []
var _fade_overlay: ColorRect
var _canvas_layer: CanvasLayer

const FULL_RECT: Rect2 = Rect2(0, 0, 1, 1)

func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	add_child(_canvas_layer)
	
	_fade_overlay = ColorRect.new()
	_fade_overlay.anchor_left = FULL_RECT.position.x
	_fade_overlay.anchor_top = FULL_RECT.position.y
	_fade_overlay.anchor_right = FULL_RECT.size.x
	_fade_overlay.anchor_bottom = FULL_RECT.size.y
	_fade_overlay.color = Color(0, 0, 0, 1)
	_fade_overlay.visible = false
	_canvas_layer.add_child(_fade_overlay)

func change_scene(path: String, push_to_history: bool = true) -> void:
	if _is_transitioning:
		push_warning("SceneManager: Transition already in progress, ignoring request")
		return
	_execute_scene_swap(path, push_to_history)

func _execute_scene_swap(path: String, push_to_history: bool = true) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneManager: Scene path does not exist: %s" % path)
		return
	
	if push_to_history and (_scene_history.is_empty() or _scene_history.back() != path):
		_scene_history.append(path)
	
	get_tree().change_scene_to_file(path)

func change_scene_with_fade(path: String, duration: float = 0.4, push_to_history: bool = true) -> void:
	if _is_transitioning:
		push_warning("SceneManager: Transition already in progress, ignoring request")
		return
	
	if not ResourceLoader.exists(path):
		push_error("SceneManager: Scene path does not exist: %s" % path)
		return
	
	if duration <= 0.0:
		_execute_scene_swap(path, push_to_history)
		emit_signal("scene_changed", path)
		return
	
	_is_transitioning = true
	_fade_overlay.modulate.a = 0.0
	_fade_overlay.visible = true
	
	var fade_out_duration: float = duration * 0.5
	var fade_in_duration: float = duration * 0.5
	
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade_overlay, "modulate:a", 1.0, fade_out_duration)
	
	await tween.finished
	_execute_scene_swap(path, push_to_history)
	
	var tween_in := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_in.tween_property(_fade_overlay, "modulate:a", 0.0, fade_in_duration)
	
	await tween_in.finished
	_fade_overlay.visible = false
	_is_transitioning = false
	
	emit_signal("scene_changed", path)

func go_back() -> void:
	if _scene_history.size() <= 1:
		push_warning("SceneManager: History stack has no previous scene, cannot go back")
		return
	
	_scene_history.pop_back()
	
	var previous_path: String = _scene_history.back()
	change_scene_with_fade(previous_path, 0.4, false)

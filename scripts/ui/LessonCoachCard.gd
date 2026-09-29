class_name LessonCoachCard extends PanelContainer

## Purpose: the M28 lesson channel — a small parchment card that shows one
## `LessonData` at a time. `TutorialDialogue` is the modal channel (story); this
## is the other one (mechanics), and it must never pause the tree or steal
## input: a lesson that interrupts a fight teaches the player to dismiss lessons.
## Responsibilities: queue lessons from `CampaignManager.lesson_requested`, show
## the next one only while no dialogue is blocking, dismiss on tap or after the
## lesson's `display_seconds`, and breathe a highlight on the lesson's
## `highlight_group` node while it is up.
## Placement belongs to the parent container (WorldHUD puts this inside
## TopRightPanel), never a pixel offset of its own (CLAUDE.md fragile-area rule).
## Dependencies: CampaignManager, TutorialDialogue (via its "tutorial_dialogue"
## group), PirateThemeBuilder, UIMotion.

signal lesson_shown(lesson: LessonData)
signal lesson_dismissed(lesson: LessonData)

const GROUP := &"lesson_coach_card"

@onready var title_label: Label = %LessonTitle
@onready var body_label: Label = %LessonBody

var _queue: Array[LessonData] = []
var _current: LessonData = null
var _remaining: float = 0.0
var _highlight_node: CanvasItem = null
var _highlight_tween: Tween = null
var _dialogue: Node = null


func _ready() -> void:
	# CampaignManager only fires (and marks seen) a lesson while a card exists
	# to show it — see CampaignManager._fire_trigger().
	add_to_group(GROUP)
	hide()
	theme = PirateThemeBuilder.build()
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	if CampaignManager and not CampaignManager.lesson_requested.is_connected(enqueue):
		CampaignManager.lesson_requested.connect(enqueue)


func enqueue(lesson: LessonData) -> void:
	if lesson == null:
		return
	_queue.append(lesson)
	_try_show_next()


func get_current_lesson() -> LessonData:
	return _current


func get_queue_size() -> int:
	return _queue.size()


func dismiss() -> void:
	if _current == null:
		return
	var lesson := _current
	_current = null
	_stop_highlight()
	hide()
	lesson_dismissed.emit(lesson)
	_try_show_next()


func _process(delta: float) -> void:
	if _current == null:
		if not _queue.is_empty():
			_try_show_next()
		return
	# A story beat that opens while a lesson is up takes the screen: the lesson
	# goes back to the front of the queue and returns once the dialogue closes.
	if _dialogue_blocking():
		_queue.push_front(_current)
		_current = null
		_stop_highlight()
		hide()
		return
	_remaining -= delta
	if _remaining <= 0.0:
		dismiss()


func _try_show_next() -> void:
	if _current != null or _queue.is_empty() or _dialogue_blocking():
		return
	_current = _queue.pop_front()
	title_label.text = tr(_current.title)
	body_label.text = tr(_current.body)
	_remaining = maxf(_current.display_seconds, 0.5)
	show()
	UIMotion.pop_in(self)
	_start_highlight(_current.highlight_group)
	lesson_shown.emit(_current)


func _dialogue_blocking() -> bool:
	if _dialogue == null or not is_instance_valid(_dialogue):
		_dialogue = get_tree().get_first_node_in_group("tutorial_dialogue") if is_inside_tree() else null
	return _dialogue != null and _dialogue.has_method("is_blocking") and _dialogue.is_blocking()


func _start_highlight(group: StringName) -> void:
	_stop_highlight()
	if group == &"" or not is_inside_tree():
		return
	var node := get_tree().get_first_node_in_group(group) as CanvasItem
	if node == null or not node.is_visible_in_tree():
		return
	_highlight_node = node
	_highlight_tween = UIMotion.idle_glow(node)


func _stop_highlight() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = null
	if _highlight_node and is_instance_valid(_highlight_node):
		_highlight_node.self_modulate = Color.WHITE
	_highlight_node = null


func _on_gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped and _current != null:
		accept_event()
		dismiss()


func _exit_tree() -> void:
	_stop_highlight()

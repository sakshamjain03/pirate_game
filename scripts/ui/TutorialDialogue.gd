class_name TutorialDialogue extends Control

## Purpose: chapter dialogue box (Quartermaster Higgins and the rest of the
## named cast). Renders a `ChapterData`'s `opening_beats`/`closing_beats` queue
## as `CampaignManager` starts/completes chapters.
## Responsibilities: purely reactive — holds no story logic of its own, only
## queue position. Beats are narration (no wait-for-gameplay-condition concept
## in `DialogueBeatData`); a chapter's real pacing comes from its objectives,
## tracked separately by `CaptainsLog`/`WorldHUD`, not by holding this dialogue
## open.
## Dependencies: CampaignManager, PirateThemeBuilder

@onready var name_label: Label = %MentorNameLabel
@onready var text_label: Label = %MentorTextLabel
@onready var portrait_label: Label = %PortraitLabel
@onready var next_button: Button = %NextButton
@onready var skip_button: Button = %SkipButton

var _queue: Array[DialogueBeatData] = []
var _queue_index: int = -1


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	# M9 Requirement 5 — lets EncounterManager gate ambient encounters while
	# this dialogue has focus without a direct node reference, mirroring the
	# "hud" group WorldHUD already registers itself under for the same reason.
	add_to_group("tutorial_dialogue")

	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

	CampaignManager.chapter_started.connect(_on_chapter_started)
	CampaignManager.chapter_completed.connect(_on_chapter_completed)


func is_blocking() -> bool:
	return visible


func _on_chapter_started(chapter: ChapterData) -> void:
	_show_queue(chapter.opening_beats)


func _on_chapter_completed(chapter: ChapterData) -> void:
	_show_queue(chapter.closing_beats)


func _show_queue(beats: Array[DialogueBeatData]) -> void:
	if beats.is_empty():
		return
	_queue = beats
	_queue_index = 0
	_render_current_beat()
	show()


func _render_current_beat() -> void:
	if _queue_index < 0 or _queue_index >= _queue.size():
		hide()
		return
	var beat := _queue[_queue_index]
	name_label.text = beat.speaker_name if not beat.speaker_name.is_empty() else beat.speaker_id
	text_label.text = beat.text
	PortraitFallback.apply_to_label(portrait_label, beat.portrait_path, name_label.text)


func _on_next_pressed() -> void:
	_queue_index += 1
	if _queue_index >= _queue.size():
		hide()
	else:
		_render_current_beat()


func _on_skip_pressed() -> void:
	## Dismisses the current dialogue queue only — there is no "skip the whole
	## campaign" concept anymore; objectives are real gameplay, not a step list.
	_queue_index = _queue.size()
	hide()

class_name CaptainsLog extends Control

## Purpose: the Captain's Log panel (M7 §9.1) — completed chapters and the
## active chapter's objective progress. Reactive only, like `IslandMenu`'s
## dynamic list-building: no story logic lives here, all of it is
## `CampaignManager` state.
## Dependencies: CampaignManager

@onready var panel: Control = %Panel
@onready var content: VBoxContainer = %Content
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	close_button.pressed.connect(close)

	CampaignManager.objective_progressed.connect(func(_a, _b, _c): _refresh())
	CampaignManager.objective_completed.connect(func(_a): _refresh())
	CampaignManager.chapter_started.connect(func(_c): _refresh())
	CampaignManager.chapter_completed.connect(func(_c): _refresh())


func open() -> void:
	_refresh()
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _refresh() -> void:
	for child in content.get_children():
		child.queue_free()

	_add_header(tr("Completed Chapters"))
	if CampaignManager.completed_chapter_ids.is_empty():
		_add_body(tr("None yet."))
	else:
		for chapter in CampaignManager.chapters:
			if CampaignManager.completed_chapter_ids.has(chapter.chapter_id):
				_add_header(chapter.title)
				_add_body(chapter.log_summary)

	content.add_child(HSeparator.new())

	var current := CampaignManager._current_chapter()
	if not current:
		_add_header(tr("No Active Chapter"))
		return

	_add_header(current.title)
	var required: Array = []
	var optional: Array = []
	for objective in current.objectives:
		if objective.is_optional:
			optional.append(objective)
		else:
			required.append(objective)

	for objective in required:
		_add_objective_row(objective)

	if not optional.is_empty():
		content.add_child(HSeparator.new())
		_add_header(tr("Optional"))
		for objective in optional:
			_add_objective_row(objective)


func _add_objective_row(objective: ObjectiveData) -> void:
	var label := Label.new()
	var current: int = int(CampaignManager._objective_progress.get(objective.objective_id, 0))
	var done := CampaignManager._completed_objective_ids.has(objective.objective_id)
	var mark := "✓" if done else "%d/%d" % [current, objective.target_count]
	label.text = "%s — %s" % [objective.description, mark]
	if done:
		label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	content.add_child(label)


func _add_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	content.add_child(label)


func _add_body(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content.add_child(label)

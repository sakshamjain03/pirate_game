class_name CaptainsLog extends Control

## Purpose: the Captain's Log panel (M7 §9.1) — completed chapters and the
## active chapter's objective progress. Reactive only, like `IslandMenu`'s
## dynamic list-building: no story logic lives here, all of it is
## `CampaignManager` state.
## Dependencies: CampaignManager

@onready var panel: Control = %Panel
@onready var content: VBoxContainer = %Content
@onready var close_button: Button = %CloseButton
@onready var title_label: Label = %TitleLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var page: PanelContainer = %Page


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	# M22 6b: wood frame + parchment journal page (v0.3), ink text from the
	# page theme rather than per-label colours.
	PirateThemeBuilder.dress_parchment_page(page)
	PirateThemeBuilder.apply_button_juice(self)
	close_button.pressed.connect(close)

	if PirateThemeBuilder.is_mobile():
		panel.custom_minimum_size = MobileLayoutManager.mobile_dialog_size(panel.custom_minimum_size, get_viewport())
		scroll_container.custom_minimum_size = PirateThemeBuilder.scaled_size(scroll_container.custom_minimum_size)
		close_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(close_button.custom_minimum_size)

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

	_add_section(tr("Completed Chapters"))
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
		_add_section(tr("No Active Chapter"))
		PirateThemeBuilder.apply_mobile_control_scaling(content)
		return

	_add_section(current.title)
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
		_add_section(tr("Optional"))
		for objective in optional:
			_add_objective_row(objective)

	PirateThemeBuilder.apply_mobile_control_scaling(content)


func _add_objective_row(objective: ObjectiveData) -> void:
	var label := Label.new()
	var current: int = int(CampaignManager._objective_progress.get(objective.objective_id, 0))
	var done := CampaignManager._completed_objective_ids.has(objective.objective_id)
	var mark := "✓" if done else "%d/%d" % [current, objective.target_count]
	label.text = "%s — %s" % [objective.description, mark]
	label.theme_type_variation = &"InkBodyLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if done:
		label.add_theme_color_override("font_color", PirateThemeBuilder.ink_good_color())
	content.add_child(label)


## A page section heading (Completed Chapters / the active chapter / Optional).
func _add_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"InkTitleLabel"
	label.add_theme_font_size_override("font_size", UITokens.FONT_SECTION)
	content.add_child(label)


## An entry heading inside a section (a completed chapter's title).
func _add_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"InkTitleLabel"
	label.add_theme_font_size_override("font_size", UITokens.FONT_HUD_NUM)
	content.add_child(label)


func _add_body(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"InkBodyLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(1, 1, 1, 0.8)
	content.add_child(label)

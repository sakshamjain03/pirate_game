class_name WhatsNewScreen extends Control

## Purpose: M14 Requirement 5 — the "What's New" panel, following
## CaptainsLog's exact established pattern: reactive only, no logic of its
## own beyond rendering PatchNotesData, opened by a WorldHUD-owned button and
## (once, per Requirement 5.2) automatically after a content-adding update.
## Dependencies: PatchNotesData (resources/ui/PatchNotes.tres).

@export var patch_notes: PatchNotesData

@onready var content: VBoxContainer = %Content
@onready var close_button: Button = %CloseButton
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var page: PanelContainer = %Page


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	PirateThemeBuilder.dress_modal_dim($ColorRect)  # M22 6c: v0.3 teal-black backdrop
	PirateThemeBuilder.dress_parchment_page(page)  # M22 6b: same journal page as the Log
	PirateThemeBuilder.apply_button_juice(self)
	close_button.pressed.connect(close)
	if not patch_notes:
		patch_notes = load("res://resources/ui/PatchNotes.tres")

	if PirateThemeBuilder.is_mobile():
		panel.custom_minimum_size = MobileLayoutManager.mobile_dialog_size(panel.custom_minimum_size, get_viewport())
		scroll_container.custom_minimum_size = PirateThemeBuilder.scaled_size(scroll_container.custom_minimum_size)
		close_button.custom_minimum_size = PirateThemeBuilder.scaled_button_size(close_button.custom_minimum_size)


func open() -> void:
	_refresh()
	show()
	UIMotion.modal_enter(panel, $ColorRect)
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

	if not patch_notes or patch_notes.entries.is_empty():
		_add_body(tr("Nothing to report yet."))
		PirateThemeBuilder.apply_mobile_control_scaling(content)
		return

	# Newest first — the opposite of how they're authored (oldest-first,
	# append-only), since a returning player cares about "what changed since
	# I last played," not the full history in chronological order.
	var entries := patch_notes.entries.duplicate()
	entries.reverse()
	for entry in entries:
		_add_header("%s — %s" % [str(entry.get("version", "")), str(entry.get("date", ""))])
		_add_body(str(entry.get("notes", "")))
		content.add_child(HSeparator.new())

	PirateThemeBuilder.apply_mobile_control_scaling(content)


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
	content.add_child(label)

extends CanvasLayer
class_name CodexScreen

## Purpose: Lets players revisit only lore they have already encountered.
## Responsibilities: Renders completed chapter summaries, eligible captain biographies, and
## factions represented by the owned/eligible captain roster.
## Dependencies: CampaignManager, FleetManager, CaptainData, FactionData, PirateThemeBuilder.
## Limitations: Encounter history has no separate persistence record; eligibility intentionally
## mirrors the chapter gate already used by IslandMenu rather than creating duplicate tracking.
## TODOs: Add portrait art when the M11 portrait catalogue is complete.

var _panel: PanelContainer
var _entries: VBoxContainer


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func close() -> void:
	hide()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.theme = PirateThemeBuilder.build()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-390, -300)
	_panel.size = Vector2(780, 600)
	root.add_child(_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = tr("Codex")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = tr("Close")
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_entries = VBoxContainer.new()
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_entries)


func _refresh() -> void:
	if not _entries:
		return
	for child in _entries.get_children():
		child.queue_free()
	_add_section(tr("Completed Chapters"))
	var chapter_count := 0
	for chapter in CampaignManager.chapters:
		if CampaignManager.is_chapter_completed(chapter.chapter_id):
			_add_entry(tr("Chapter %d: %s") % [chapter.chapter_number, chapter.title], chapter.log_summary)
			chapter_count += 1
	if chapter_count == 0:
		_add_entry(tr("No completed chapters yet"), tr("Your campaign summaries will appear here."))
	_add_section(tr("Captains"))
	for captain in _load_captains():
		if _captain_is_encountered(captain):
			_add_entry(captain.captain_name, captain.background)
	_add_section(tr("Factions"))
	for faction in _load_encountered_factions():
		_add_entry(faction.faction_name, tr("Encountered through your crew and campaign progress."))


func _add_section(text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 22)
	_entries.add_child(label)
	_entries.add_child(HSeparator.new())


func _add_entry(title_text: String, body_text: String) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	_entries.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entries.add_child(body)
	_entries.add_child(HSeparator.new())


func _captain_is_encountered(captain: CaptainData) -> bool:
	return captain in FleetManager.owned_captains or captain.unlock_chapter_id.is_empty() \
		or CampaignManager.is_chapter_completed(captain.unlock_chapter_id)


func _load_captains() -> Array[CaptainData]:
	var result: Array[CaptainData] = []
	var dir := DirAccess.open("res://resources/captains/")
	if not dir:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var captain := load("res://resources/captains/" + file_name) as CaptainData
			if captain:
				result.append(captain)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return a.captain_name < b.captain_name)
	return result


func _load_encountered_factions() -> Array[FactionData]:
	var faction_ids := {}
	for captain in _load_captains():
		if _captain_is_encountered(captain) and not captain.allegiance_faction_id.is_empty():
			faction_ids[captain.allegiance_faction_id] = true
	var result: Array[FactionData] = []
	var dir := DirAccess.open("res://resources/factions/")
	if not dir:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var faction := load("res://resources/factions/" + file_name) as FactionData
			if faction and faction_ids.has(faction.faction_id):
				result.append(faction)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

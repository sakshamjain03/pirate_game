extends GutTest

# test_captains_log.gd
# M7 Task 22 — the Captain's Log panel. Purely reactive over CampaignManager
# state, so it's testable standalone without the rest of WorldHUD/World.

const CaptainsLogScene = preload("res://scenes/ui/CaptainsLog.tscn")

var _log
var _saved_index: int
var _saved_completed: Array
var _saved_progress: Dictionary
var _saved_completed_objectives: Array
var _saved_chapters: Array

func before_each():
	_saved_index = CampaignManager.current_chapter_index
	_saved_completed = CampaignManager.completed_chapter_ids.duplicate()
	_saved_progress = CampaignManager._objective_progress.duplicate()
	_saved_completed_objectives = CampaignManager._completed_objective_ids.duplicate()
	_saved_chapters = CampaignManager.chapters.duplicate()

	_log = CaptainsLogScene.instantiate()
	add_child_autoqfree(_log)

func after_each():
	CampaignManager.current_chapter_index = _saved_index
	CampaignManager.completed_chapter_ids = _saved_completed.duplicate()
	CampaignManager._objective_progress = _saved_progress.duplicate()
	CampaignManager._completed_objective_ids = _saved_completed_objectives.duplicate()
	CampaignManager.chapters = _saved_chapters.duplicate()


func _chapter(id: String, number: int, objectives: Array[ObjectiveData]) -> ChapterData:
	var c := ChapterData.new()
	c.chapter_id = id
	c.chapter_number = number
	c.title = "Chapter %d Title" % number
	c.log_summary = "Chapter %d summary." % number
	c.objectives = objectives
	return c

func _objective(id: String, desc: String, count: int = 1, optional: bool = false) -> ObjectiveData:
	var o := ObjectiveData.new()
	o.objective_id = id
	o.description = desc
	o.target_count = count
	o.is_optional = optional
	return o


func test_opening_shows_the_panel_and_pauses():
	var was_paused := get_tree().paused
	_log.open()
	assert_true(_log.visible)
	assert_true(get_tree().paused)
	_log.close()
	get_tree().paused = was_paused


func test_closing_hides_the_panel_and_unpauses():
	_log.open()
	_log.close()
	assert_false(_log.visible)
	assert_false(get_tree().paused)


func test_toggle_flips_visibility():
	assert_false(_log.visible)
	_log.toggle()
	assert_true(_log.visible)
	_log.toggle()
	assert_false(_log.visible)
	get_tree().paused = false


func test_lists_completed_chapters_with_their_log_summary():
	var ch1 := _chapter("ch1", 1, [])
	CampaignManager.chapters = [ch1]
	CampaignManager.completed_chapter_ids = ["ch1"]
	CampaignManager.current_chapter_index = 0

	_log._refresh()

	var text_blob := ""
	for child in _log.content.get_children():
		if child is Label:
			text_blob += child.text + "\n"
	assert_true(text_blob.contains("Chapter 1 Title"))
	assert_true(text_blob.contains("Chapter 1 summary."))
	_log.close()


func test_shows_current_chapter_objectives_with_progress():
	var req := _objective("1.1", "Required thing")
	var opt := _objective("1.2", "Optional thing", 1, true)
	var ch1 := _chapter("ch1", 1, [req, opt])
	CampaignManager.chapters = [ch1]
	CampaignManager.completed_chapter_ids = []
	CampaignManager.current_chapter_index = 0
	CampaignManager._completed_objective_ids = ["1.1"]

	_log._refresh()

	var text_blob := ""
	for child in _log.content.get_children():
		if child is Label:
			text_blob += child.text + "\n"
	assert_true(text_blob.contains("Required thing"))
	assert_true(text_blob.contains("✓"), "A completed objective must show as done")
	assert_true(text_blob.contains("Optional"), "Optional objectives must appear in a distinct section")
	assert_true(text_blob.contains("Optional thing"))
	_log.close()


func test_refreshes_automatically_when_campaign_manager_signals_fire():
	var ch1 := _chapter("ch1", 1, [_objective("1.1", "Thing", 3)])
	CampaignManager.chapters = [ch1]
	CampaignManager.completed_chapter_ids = []
	CampaignManager.current_chapter_index = 0
	_log._refresh()

	CampaignManager._objective_progress["1.1"] = 1
	CampaignManager.objective_progressed.emit("1.1", 1, 3)
	await wait_process_frames(1)

	var text_blob := ""
	for child in _log.content.get_children():
		if child is Label:
			text_blob += child.text + "\n"
	assert_true(text_blob.contains("1/3"), "The panel must react live to CampaignManager's own signals")
	_log.close()

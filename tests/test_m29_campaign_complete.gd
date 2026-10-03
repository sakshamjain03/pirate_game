extends GutTest

## M29 C.1/C.2 — the campaign ends exactly once, on the LAST chapter, then free
## roam. The first draft checked "is there a next chapter" after
## _advance_to_next_chapter() had already moved the index, so finishing the
## second-to-last chapter ended the whole campaign.

var _saved: Dictionary
var _saved_chapters: Array
var _saved_resources: Dictionary


func before_each() -> void:
	_saved = CampaignManager.get_save_data().duplicate(true)
	_saved_chapters = CampaignManager.chapters.duplicate()
	_saved_resources = ResourceManager.current_resources.duplicate()
	CampaignManager.current_chapter_index = -1
	CampaignManager.completed_chapter_ids.clear()
	CampaignManager._objective_progress.clear()
	CampaignManager._completed_objective_ids.clear()
	CampaignManager.campaign_completed = false


func after_each() -> void:
	CampaignManager.chapters = _saved_chapters.duplicate()
	CampaignManager.load_save_data(_saved)
	ResourceManager.current_resources = _saved_resources.duplicate()


func _chapter(id: String, n: int, prev := "") -> ChapterData:
	var c := ChapterData.new()
	c.chapter_id = id
	c.chapter_number = n
	c.title = id
	var o := ObjectiveData.new()
	o.objective_id = id + "_obj"
	o.description = "Do the %s thing" % id
	o.condition = 0
	o.target_count = 1
	c.objectives = [o] as Array[ObjectiveData]
	c.required_previous_chapter = prev
	return c


func _three_chapters() -> Array:
	var a := _chapter("ch_a", 1)
	var b := _chapter("ch_b", 2, "ch_a")
	var c := _chapter("ch_c", 3, "ch_b")
	CampaignManager.chapters = [a, b, c] as Array[ChapterData]
	CampaignManager._catch_up()
	return [a, b, c]


func test_second_to_last_chapter_does_not_end_the_campaign() -> void:
	var ch := _three_chapters()
	watch_signals(CampaignManager)
	CampaignManager._complete_chapter(ch[0])
	CampaignManager._complete_chapter(ch[1])
	assert_false(CampaignManager.campaign_completed, "two of three chapters is not the end")
	assert_signal_not_emitted(CampaignManager, "campaign_completed_signal")
	assert_eq(CampaignManager.current_chapter_index, 2, "the final chapter is now current")


func test_final_chapter_ends_the_campaign_exactly_once() -> void:
	var ch := _three_chapters()
	watch_signals(CampaignManager)
	for c in ch:
		CampaignManager._complete_chapter(c)
	assert_true(CampaignManager.campaign_completed)
	assert_signal_emit_count(CampaignManager, "campaign_completed_signal", 1)
	CampaignManager._complete_chapter(ch[2])  # a repeat completion is a no-op
	assert_signal_emit_count(CampaignManager, "campaign_completed_signal", 1)


func test_free_roam_display_and_no_current_chapter() -> void:
	var ch := _three_chapters()
	assert_eq(CampaignManager.get_display_objective(), "Do the ch_a thing",
		"mid-campaign shows the first unfinished required objective")
	for c in ch:
		CampaignManager._complete_chapter(c)
	assert_null(CampaignManager._current_chapter(), "free roam has no current chapter")
	assert_string_contains(CampaignManager.get_display_objective(), "empire")


func test_flag_round_trips_and_new_game_resets_it() -> void:
	CampaignManager.campaign_completed = true
	var data := JSON.parse_string(JSON.stringify(CampaignManager.get_save_data())) as Dictionary
	CampaignManager.campaign_completed = false
	CampaignManager.load_save_data(data)
	assert_true(CampaignManager.campaign_completed, "survives save/load")
	CampaignManager.load_save_data({})
	assert_false(CampaignManager.campaign_completed, "an empty (New Game) section resets it")


func test_real_final_chapter_carries_the_epilogue_in_order() -> void:
	var ch5 := load("res://resources/campaign/chapters/Ch5_TheSilverFleet.tres") as ChapterData
	var speakers: Array[String] = []
	for beat in ch5.closing_beats:
		speakers.append(beat.speaker_name)
	var tail := speakers.slice(speakers.size() - 3)
	assert_eq(tail, ["Quartermaster Higgins", "Marguerite", "Quartermaster Higgins"] as Array[String],
		"epilogue: Higgins, Marguerite's callback, Higgins on Vane's chart")
	assert_string_contains(ch5.closing_beats[-2].text, "something bigger to lose",
		"Marguerite calls back her Ch3 line")
	assert_string_contains(ch5.closing_beats[-1].text, "isn't finished", "the story-continues hook")

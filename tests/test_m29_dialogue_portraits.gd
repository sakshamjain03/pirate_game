extends GutTest

# Test C.5: every named Ch1-5 story speaker has a portrait path

const CHAPTERS_DIR := "res://resources/campaign/chapters/"

func test_every_speaker_has_portrait_path():
	# Load all enabled chapters up to Ch5
	var enabled_chapters = []
	for chapter in CampaignManager.chapters:
		if ResourceLookup.is_content_enabled(chapter) and chapter.chapter_number <= 5:
			enabled_chapters.append(chapter)

	assert_gt(enabled_chapters.size(), 0, "At least one enabled chapter exists")

	# Check all opening and closing beats
	for chapter in enabled_chapters:
		_check_beats(chapter.opening_beats, "Ch%d opening" % chapter.chapter_number)
		_check_beats(chapter.closing_beats, "Ch%d closing" % chapter.chapter_number)


func _check_beats(beats: Array, context: String) -> void:
	for beat in beats:
		if not beat or beat.speaker_name.is_empty():
			continue
		if beat.speaker_name == "Narrator" or beat.speaker_name == "":
			continue

		assert_ne(beat.portrait_path, "",
			"%s: %s has portrait_path" % [context, beat.speaker_name])
		assert_string_contains(beat.portrait_path, "res://assets/portraits/",
			"%s: %s portrait_path is in correct directory" % [context, beat.speaker_name])

extends GutTest
## M29 Checkpoint B (headful review, 2026-10-05): on a 19.5:9 phone (1560x720
## canvas) the Ch5 epilogue's long Higgins beat grew the dialogue card — anchored
## under the top HUD at y=212 — past the bottom of the screen, hiding its Next
## button. The text now scrolls inside a slot clamped to the room on screen.

const SCENE := preload("res://scenes/ui/TutorialDialogue.tscn")
const PHONE := Vector2i(1560, 720)

var _viewport: SubViewport


func before_each() -> void:
	# The card pops in with a scale tween; measure its settled layout.
	UIMotion.force_reduced_motion_for_test = true
	PirateThemeBuilder.force_mobile_scaling_for_test = true
	_viewport = SubViewport.new()
	_viewport.size = PHONE
	add_child_autofree(_viewport)


func after_each() -> void:
	UIMotion.force_reduced_motion_for_test = false
	PirateThemeBuilder.force_mobile_scaling_for_test = false


func _longest_authored_beat() -> DialogueBeatData:
	var longest: DialogueBeatData = null
	var dir := DirAccess.open("res://resources/campaign/chapters/")
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var chapter := load("res://resources/campaign/chapters/" + file_name) as ChapterData
		if not chapter:
			continue
		for beat in chapter.opening_beats + chapter.closing_beats:
			if longest == null or beat.text.length() > longest.text.length():
				longest = beat
	return longest


func test_longest_beat_stays_on_a_phone_screen() -> void:
	var dialogue: Control = SCENE.instantiate()
	_viewport.add_child(dialogue)
	await get_tree().process_frame
	var beat := _longest_authored_beat()
	assert_not_null(beat, "expected authored dialogue beats")
	var queue: Array[DialogueBeatData] = [beat]
	dialogue._show_queue(queue)
	dialogue.text_label.visible_ratio = 1.0
	# The fit converges over a few layout passes (the wrapped label only gets
	# its real width after the first one).
	for i in range(10):
		await get_tree().process_frame

	var next_button: Control = dialogue.get_node("Panel/HBox/VBox/ButtonRow/NextButton")
	assert_lte(next_button.get_global_rect().end.y, float(PHONE.y),
		"Next button (bottom %.0f) is below a %d px phone screen" % [next_button.get_global_rect().end.y, PHONE.y])
	assert_lte(dialogue.get_global_rect().end.y, float(PHONE.y) + 1.0,
		"dialogue runs off the bottom of the phone screen")
	var scroll := dialogue.get_node_or_null("Panel/HBox/VBox/TextScroll") as Control
	if scroll:
		assert_gte(scroll.size.y, 90.0,
			"text area collapsed to %.0f px — the beat text would be invisible" % scroll.size.y)

extends GutTest

## M11 Requirement 9 — portrait sourcing/integration. 20 captains get real
## (flat-color icon-bust, per Requirement 9.2's stylized-substitute allowance)
## portrait_path assets; PortraitFallback.apply_to_texture_rect() is the new
## contract that shows real art when present and keeps M9's monogram fallback
## otherwise, without callers needing a second decision path.

const CAPTAIN_IDS := [
	"Anne", "Barnaby", "Bartholomew", "Constance", "Cutlass", "Diego", "Ezra",
	"Fiona", "Grace", "Isabela", "Jack", "Marguerite", "Mary", "OldTom",
	"Ophelia", "Redbeard", "Rook", "Selene", "Whistler", "Yusuf",
]

func test_every_captain_has_a_real_portrait_path_that_resolves():
	for id in CAPTAIN_IDS:
		var cap: CaptainData = load("res://resources/captains/%s.tres" % id)
		assert_not_null(cap, "%s.tres should load" % id)
		assert_false(cap.portrait_path.is_empty(), "%s should have a portrait_path" % id)
		assert_true(ResourceLoader.exists(cap.portrait_path),
			"%s's portrait_path '%s' must resolve to a real file" % [id, cap.portrait_path])

func test_all_20_captains_covered():
	var dir = DirAccess.open("res://resources/captains/")
	assert_not_null(dir)
	var total = 0
	var with_portrait = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			total += 1
			var cap: CaptainData = load("res://resources/captains/" + file_name)
			if cap and not cap.portrait_path.is_empty():
				with_portrait += 1
		file_name = dir.get_next()
	assert_eq(total, 20, "Requirement 9.1 targets all 20 captains")
	assert_eq(with_portrait, 20, "All 20 captains should have real portrait_path assets, per this pass's scope")

func test_apply_to_texture_rect_shows_real_art_when_present():
	var rect = TextureRect.new()
	var fallback = Label.new()
	add_child_autoqfree(rect)
	add_child_autoqfree(fallback)

	PortraitFallback.apply_to_texture_rect(rect, fallback, "res://assets/portraits/Jack.svg", "\"Steady\" Jack")

	assert_true(rect.visible, "Real art should be shown")
	assert_not_null(rect.texture, "Real art texture should actually be loaded")
	assert_false(fallback.visible, "Fallback label should be hidden when real art exists")

func test_apply_to_texture_rect_falls_back_for_a_character_with_no_art():
	var rect = TextureRect.new()
	var fallback = Label.new()
	add_child_autoqfree(rect)
	add_child_autoqfree(fallback)

	PortraitFallback.apply_to_texture_rect(rect, fallback, "", "Quartermaster Higgins")

	assert_false(rect.visible, "No art on disk — the texture slot must stay hidden")
	assert_true(fallback.visible, "Fallback label should be shown instead")
	assert_eq(fallback.text, "Q", "Fallback should still be the existing monogram treatment")

func test_apply_to_texture_rect_falls_back_for_a_nonexistent_path():
	var rect = TextureRect.new()
	var fallback = Label.new()
	add_child_autoqfree(rect)
	add_child_autoqfree(fallback)

	PortraitFallback.apply_to_texture_rect(rect, fallback, "res://assets/portraits/DoesNotExist.svg", "Nobody")

	assert_false(rect.visible)
	assert_true(fallback.visible)

func test_apply_to_label_backward_compatibility_unchanged():
	## The original Label-only contract (still used by TutorialDialogue for
	## the 7 named cast, which have no portrait art in this pass) must keep
	## working exactly as M9 shipped it.
	var label = Label.new()
	add_child_autoqfree(label)
	PortraitFallback.apply_to_label(label, "", "Commander Hollis")
	assert_eq(label.text, "C")

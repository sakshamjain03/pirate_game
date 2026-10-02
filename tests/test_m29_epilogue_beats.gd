extends GutTest

# Test C.2: epilogue beats are authored

func test_ch5_epilogue_beats_exist():
	var ch5 = load("res://resources/campaign/chapters/Ch5_TheSilverFleet.tres")
	assert_not_null(ch5, "Ch5 chapter loads")

	# Should have 7 closing beats: 4 original + 3 epilogue
	assert_eq(ch5.closing_beats.size(), 7, "Ch5 has 7 closing beats (4 original + 3 epilogue)")

	# Check that the epilogue beats exist and have the right speakers
	var epilogue_1 = ch5.closing_beats[4]
	var epilogue_2 = ch5.closing_beats[5]
	var epilogue_3 = ch5.closing_beats[6]

	assert_not_null(epilogue_1, "Epilogue beat 1 exists")
	assert_not_null(epilogue_2, "Epilogue beat 2 exists")
	assert_not_null(epilogue_3, "Epilogue beat 3 exists")

	# Check speakers
	assert_eq(epilogue_1.speaker_id, "higgins", "Epilogue 1 is Higgins")
	assert_eq(epilogue_2.speaker_id, "marguerite", "Epilogue 2 is Marguerite")
	assert_eq(epilogue_3.speaker_id, "higgins", "Epilogue 3 is Higgins")

	# Check that text is not empty
	assert_ne(epilogue_1.text, "", "Epilogue 1 has text")
	assert_ne(epilogue_2.text, "", "Epilogue 2 has text")
	assert_ne(epilogue_3.text, "", "Epilogue 3 has text")

	# Check that Marguerite's beat references the earlier "building something bigger to lose" theme
	assert_string_contains(epilogue_2.text.to_lower(), "bigger", "Epilogue 2 references bigger")

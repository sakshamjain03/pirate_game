extends GutTest

# test_ui_tokens.gd
# M22 Phase 1.1/1.2/1.7 — UIPalette/UITokens are the single source of truth
# for every UI colour, font, and size token (design.md §1/§4/§5). This just
# proves the plumbing: the shipped resource loads, all swatches/rarity keys
# exist, both new font files load, and every size is design-px x2 per
# design.md §3.

func after_each():
	UITokens.clear_palette_cache_for_test()


func test_palette_loads_and_exposes_all_twelve_swatches():
	var pal := UITokens.palette()
	assert_not_null(pal)
	assert_true(pal is UIPalette)
	for prop in ["ocean_deep", "sunset_teal", "shallows", "horizon_gold", "driftwood",
			"wood_dark", "brass", "brass_light", "parchment", "ink", "coral", "coral_bloom"]:
		assert_true(prop in pal, "UIPalette is missing swatch '%s'" % prop)


func test_palette_exposes_rarity_ramp():
	var pal := UITokens.palette()
	for key in ["common", "uncommon", "rare", "epic", "legendary"]:
		assert_true(pal.rarity.has(key), "UIPalette.rarity is missing key '%s'" % key)


func test_palette_rarity_color_falls_back_to_common_on_an_unknown_key():
	var pal := UITokens.palette()
	assert_eq(pal.rarity_color("nonsense"), pal.rarity["common"])


func test_palette_swatches_match_the_v03_design_hex_values():
	var pal := UITokens.palette()
	assert_eq(pal.coral, Color("#F0602A"))
	assert_eq(pal.brass, Color("#C29444"))
	assert_eq(pal.parchment, Color("#ECD6A4"))
	assert_eq(pal.brick, Color("#A8392B"))


func test_palette_accessor_caches_the_same_instance():
	assert_eq(UITokens.palette(), UITokens.palette())


func test_fonts_load_as_real_fonts():
	var germania := ResourceLoader.load("res://assets/fonts/GermaniaOne-Regular.ttf")
	var baloo := ResourceLoader.load("res://assets/fonts/Baloo2-VariableFont_wght.ttf")
	assert_true(germania is Font, "Germania One must load as a Font resource")
	assert_true(baloo is Font, "Baloo 2 must load as a Font resource")


func test_type_scale_is_design_px_times_two():
	assert_eq(UITokens.FONT_DISPLAY, 44 * 2)
	assert_eq(UITokens.FONT_TITLE, 28 * 2)
	assert_eq(UITokens.FONT_HUD_NUM, 18 * 2)
	assert_eq(UITokens.FONT_BODY, 16 * 2)
	assert_eq(UITokens.FONT_CHIP, 12 * 2)


func test_radii_and_lip_are_design_px_times_two():
	assert_eq(UITokens.RADIUS_PRIMARY, 18 * 2)
	assert_eq(UITokens.RADIUS_SECONDARY, 14 * 2)
	assert_eq(UITokens.BORDER_WIDTH, 3 * 2)
	assert_eq(UITokens.LIP_IDLE, 6 * 2)
	assert_eq(UITokens.LIP_PRESSED, 2 * 2)
	assert_eq(UITokens.PRESS_OFFSET_Y, 4 * 2)


func test_build_uses_germania_for_the_button_font():
	var theme := PirateThemeBuilder.build()
	var button_font := theme.get_font("font", "Button")
	assert_not_null(button_font)
	# Germania One is a static font, loaded directly (not a FontVariation
	# wrapper like the Baloo 2 body font below).
	assert_true(button_font is FontFile, "Button font should be the Germania One FontFile directly")


func test_build_uses_baloo2_for_the_default_body_font_when_ui_font_is_default():
	var previous := SettingsManager.ui_font
	SettingsManager.ui_font = 0
	var theme := PirateThemeBuilder.build()
	var label_font := theme.get_font("font", "Label")
	assert_true(label_font is FontVariation, "Default body font should be a Baloo 2 FontVariation")
	SettingsManager.ui_font = previous

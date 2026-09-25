extends GutTest

# test_theme_variations.gd
# M22 Phase 3.2 — PirateThemeBuilder.build() now derives every panel/button/
# label from the generated kit + UITokens/UIPalette (design.md §5-§7) instead
# of flat StyleBoxFlat/consts. This proves the type-variation wiring itself
# (base type, stylebox kind, font sizes) — not pixel-perfect rendering,
# which the headful UIKitSheet sweep covers instead (GUT can't see layout,
# per CLAUDE.md/docs/07_AI_AGENT_WORKFLOW.md). ButtonJuice/PrimaryGlow (3.3)
# live in tests/test_button_juice_and_glow.gd, deliberately separate — that
# file's press-timing test is real-time-sensitive and doesn't want this
# file's before_each rebuilding the whole Theme (fonts + every kit SVG)
# ahead of every single test.

var _theme: Theme

func before_each():
	_theme = PirateThemeBuilder.build()


func test_panel_variations_exist_with_panelcontainer_base():
	for variation in ["ParchmentPanel", "WoodFramePanel", "PlaquePanel"]:
		assert_eq(_theme.get_type_variation_base(variation), &"PanelContainer",
			"%s should be a PanelContainer variation" % variation)
		var style := _theme.get_stylebox("panel", variation)
		assert_true(style is StyleBoxTexture, "%s's panel style should be a StyleBoxTexture" % variation)


func test_button_variations_exist_with_button_base():
	for variation in ["PrimaryButton", "WoodRoundButton"]:
		assert_eq(_theme.get_type_variation_base(variation), &"Button",
			"%s should be a Button variation" % variation)
		assert_true(_theme.get_stylebox("normal", variation) is StyleBoxTexture)
		assert_true(_theme.get_stylebox("pressed", variation) is StyleBoxTexture)
		assert_true(_theme.get_stylebox("disabled", variation) is StyleBoxTexture)


func test_default_button_is_brass_not_primary():
	# Default Button (no variation) uses the brass texture, distinct from
	# PrimaryButton's coral one (design.md §7: "Default Button = brass").
	var default_style := _theme.get_stylebox("normal", "Button") as StyleBoxTexture
	var primary_style := _theme.get_stylebox("normal", "PrimaryButton") as StyleBoxTexture
	assert_not_null(default_style)
	assert_not_null(primary_style)
	assert_ne(default_style.texture, primary_style.texture)


func test_label_type_scale_matches_ui_tokens():
	assert_eq(_theme.get_font_size("font_size", "DisplayLabel"), UITokens.FONT_DISPLAY)
	assert_eq(_theme.get_font_size("font_size", "TitleLabel"), UITokens.FONT_TITLE)
	assert_eq(_theme.get_font_size("font_size", "HudNumLabel"), UITokens.FONT_HUD_NUM)
	assert_eq(_theme.get_font_size("font_size", "BodyLabel"), UITokens.FONT_BODY)
	assert_eq(_theme.get_font_size("font_size", "ChipLabel"), UITokens.FONT_CHIP)
	assert_eq(_theme.get_font_size("font_size", "Label"), UITokens.FONT_BODY)


func test_display_and_title_labels_use_germania_with_shadow_and_outline():
	for variation in ["DisplayLabel", "TitleLabel"]:
		assert_true(_theme.get_font("font", variation) is FontFile,
			"%s should use the Germania One FontFile" % variation)
		assert_eq(_theme.get_constant("shadow_offset_y", variation), UITokens.TEXT_SHADOW_OFFSET)
		assert_eq(_theme.get_constant("outline_size", variation), UITokens.TEXT_OUTLINE_SIZE)


func test_hud_num_and_chip_labels_use_the_800_weight_baloo2_variation():
	for variation in ["HudNumLabel", "ChipLabel"]:
		var font := _theme.get_font("font", variation)
		assert_true(font is FontVariation, "%s should be a Baloo 2 FontVariation" % variation)
		if font is FontVariation:
			assert_eq((font as FontVariation).variation_opentype.get("wght"), 800)

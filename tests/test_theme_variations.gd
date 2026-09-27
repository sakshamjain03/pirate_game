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


# Slider and ScrollBar both size their track from the stylebox's own
# minimum size (its content margins), NOT the control's height or the
# texture's pixels. Zero margins render a valid-looking but zero-thickness,
# invisible control — shipped once for each (design.md §11a), caught only
# by looking at a capture. These guard that trap directly.
func test_slider_groove_and_fill_have_real_thickness():
	for slot in ["slider", "grabber_area"]:
		var style := _theme.get_stylebox(slot, "HSlider")
		assert_gt(style.get_minimum_size().y, 0.0,
			"HSlider '%s' must have non-zero thickness or the groove is invisible" % slot)


func test_scrollbars_have_real_thickness():
	for bar_type in ["VScrollBar", "HScrollBar"]:
		for slot in ["scroll", "grabber"]:
			var min_size := _theme.get_stylebox(slot, bar_type).get_minimum_size()
			var thickness := min_size.x if bar_type == "VScrollBar" else min_size.y
			assert_gt(thickness, 0.0,
				"%s '%s' must have non-zero thickness or the bar is 0px and undraggable" % [bar_type, slot])


func test_parchment_label_variations_use_ink_not_light_text():
	var pal := UITokens.palette()
	for variation in ["InkTitleLabel", "InkBodyLabel"]:
		assert_eq(_theme.get_type_variation_base(variation), &"Label")
		assert_eq(_theme.get_color("font_color", variation), pal.text_on_parchment,
			"%s sits on parchment and must use ink, not the default light text" % variation)


# Godot 4 CheckButton icons are "checked"/"unchecked" — the Godot 3 names
# "on"/"off" were set here once and silently ignored, so every toggle drew
# the engine's own tiny default pill. Also guards the kit toggle's size:
# it was generated at half the 62x30-design spec (canvas = design x2).
func test_check_button_uses_kit_toggle_at_spec_size():
	var owner := Control.new()
	owner.theme = _theme
	add_child_autofree(owner)
	var toggle := CheckButton.new()
	owner.add_child(toggle)
	for icon_name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		var icon := toggle.get_theme_icon(icon_name)
		assert_true(icon.resource_path.begins_with(PirateThemeBuilder.KIT),
			"CheckButton '%s' must be the kit toggle, not the engine default" % icon_name)
		assert_eq(icon.get_size(), Vector2(124, 60), "toggle must be 62x30 design px (x2 canvas)")


# Resolved through a real node, not Theme.get_font(): the theme entries were
# correct all along, but Theme.has_font() answers true for ANY type once a
# default_font is set, so a variation that didn't declare its own fonts got
# the default font for [b]/[i] (Credits rendered with no bold headings).
func test_rich_text_bbcode_fonts_resolve_through_variation():
	var owner := Control.new()
	owner.theme = _theme
	add_child_autofree(owner)
	for variation in [&"", &"InkRichTextLabel"]:
		var rtl := RichTextLabel.new()
		rtl.theme_type_variation = variation
		owner.add_child(rtl)
		assert_true(rtl.get_theme_font("bold_font") is FontFile,
			"[b] in '%s' must resolve to Germania, not the default body font" % variation)
		assert_ne(rtl.get_theme_font("italics_font"), rtl.get_theme_font("normal_font"),
			"[i] in '%s' must differ from normal text" % variation)


func test_hud_num_and_chip_labels_use_the_800_weight_baloo2_variation():
	for variation in ["HudNumLabel", "ChipLabel"]:
		var font := _theme.get_font("font", variation)
		assert_true(font is FontVariation, "%s should be a Baloo 2 FontVariation" % variation)
		if font is FontVariation:
			# M22 6.9: the key must be the integer OpenType tag — a String
			# "wght" key (what this test used to assert) is silently ignored
			# by Godot 4.3 and rendered every weight at 400.
			var wght_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
			assert_eq((font as FontVariation).variation_opentype.get(wght_tag), 800)
			# Behavioural, not just structural: the 800 face must actually
			# shape wider than the file's default 400 weight.
			var regular: Font = load(PirateThemeBuilder.FONT_BALOO2)
			var w_bold := font.get_string_size("20,860", HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
			var w_regular := regular.get_string_size("20,860", HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
			assert_gt(w_bold, w_regular, "%s must render heavier than Baloo 2's default 400 weight" % variation)

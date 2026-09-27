class_name PirateThemeBuilder extends RefCounted

## Purpose: Builds and returns the shared Pirate Empire UI Theme programmatically.
## Responsibilities: Loads fonts, sets button/label/panel styles for all pirate UI.
## Usage: call PirateThemeBuilder.build() from any script that needs the theme.
##
## M22 Phase 3 (design.md §1, §6, §7) — build() is rebuilt on the generated
## texture kit (assets/ui/kit/*.svg, tools/ui_kit/gen_kit.py) and UITokens'
## type scale / radii / motion timings; every colour reads through
## UITokens.palette() (design.md §4) instead of a local const (see this
## file's git history before this task for the old flat navy/gold consts).
## M15.5's sourced Kenney button-pack stylebox generator is fully superseded
## by the kit and removed here; the PNG files themselves
## (assets/ui_icons/buttons/*.png) are left on disk for Phase 9's explicit
## grep-verified unused-asset pass to retire (not this task's scope — this
## task only owns code, not the asset-retirement checkpoint).

const FONT_PIRATA    := "res://assets/fonts/PirataOne-Regular.ttf"
const FONT_CINZEL    := "res://assets/fonts/Cinzel-Regular.ttf"
const FONT_CINZEL_B  := "res://assets/fonts/Cinzel-Bold.ttf"
## M22 Phase 1.7 (design.md §5) — the v0.3 design system's own type faces:
## Germania One for headers/button/tab labels, Baloo 2 (variable, weight
## selected via FontVariation) for body/HUD-number text.
const FONT_GERMANIA  := "res://assets/fonts/GermaniaOne-Regular.ttf"
const FONT_BALOO2    := "res://assets/fonts/Baloo2-VariableFont_wght.ttf"

## M22 Phase 2's generated texture kit (tools/ui_kit/gen_kit.py) — the only
## source build() draws panels/buttons/controls from as of Phase 3.
const KIT := "res://assets/ui/kit/"
const TEX_PARCHMENT_PANEL := KIT + "parchment_panel.svg"
const TEX_WOOD_FRAME      := KIT + "wood_frame.svg"
const TEX_WOOD_PLAQUE     := KIT + "wood_plaque.svg"
const TEX_ROPE_PARCHMENT  := KIT + "rope_parchment.svg"
const TEX_TORN_PARCHMENT  := KIT + "torn_parchment.svg"
const TEX_BUTTON_PRIMARY_IDLE     := KIT + "button_primary_idle.svg"
const TEX_BUTTON_PRIMARY_PRESSED  := KIT + "button_primary_pressed.svg"
const TEX_BUTTON_PRIMARY_DISABLED := KIT + "button_primary_disabled.svg"
const TEX_BUTTON_BRASS_IDLE     := KIT + "button_brass_idle.svg"
const TEX_BUTTON_BRASS_PRESSED  := KIT + "button_brass_pressed.svg"
const TEX_BUTTON_BRASS_DISABLED := KIT + "button_brass_disabled.svg"
const TEX_BUTTON_WOOD_ROUND_IDLE     := KIT + "button_wood_round_idle.svg"
const TEX_BUTTON_WOOD_ROUND_PRESSED  := KIT + "button_wood_round_pressed.svg"
const TEX_BUTTON_WOOD_ROUND_DISABLED := KIT + "button_wood_round_disabled.svg"
const TEX_TOGGLE_ON  := KIT + "toggle_on.svg"
const TEX_TOGGLE_OFF := KIT + "toggle_off.svg"
const TEX_ROPE_SLIDER_TRACK := KIT + "rope_slider_track.svg"
const TEX_ROPE_SLIDER_FILL  := KIT + "rope_slider_fill.svg"
const TEX_ROPE_SLIDER_KNOB  := KIT + "rope_slider_knob.svg"
const TEX_TAB_IDLE   := KIT + "tab_idle.svg"
const TEX_TAB_ACTIVE := KIT + "tab_active.svg"
const TEX_DROPDOWN_SHEET    := KIT + "dropdown_sheet.svg"
const TEX_SCROLLBAR_TRACK   := KIT + "scrollbar_track.svg"
const TEX_DROPDOWN_ARROW   := KIT + "dropdown_arrow.svg"
const TEX_SCROLLBAR_GRABBER := KIT + "scrollbar_grabber.svg"
const TEX_RESOURCE_PILL     := KIT + "resource_pill.svg"
const TEX_COOLDOWN_DISC     := KIT + "cooldown_disc.svg"
## Canvas size of the wood-round button art (gen_kit.py: 58-design-px face +
## lip + a matching transparent band above so the face is canvas-centred).
## round_button_size() keeps any requested width at this aspect so the
## circle never stretches into an ellipse.
const ROUND_BUTTON_ART_SIZE := Vector2(128, 148)
## Content inset for WoodRoundButton, on every side: the circle's inscribed
## area. Icons use expand_icon inside it.
const _ROUND_CONTENT := 28.0

## design.md §6/§7's texture_margin numbers (canvas px — see gen_kit.py's
## per-asset docstrings for the source dpx() math). Button margins equal
## their own corner radius (UITokens.RADIUS_PRIMARY/SECONDARY), the standard
## rounded-rect 9-slice convention.
const MARGIN_PARCHMENT   := 56.0   ## M22 6c: v0.3 radius-12 page + its inset shadow
const MARGIN_WOOD_FRAME  := 56.0   ## radius 18 + 3px border + corner studs
const MARGIN_ROPE        := 56.0
const MARGIN_PLAQUE_END  := 64.0
const MARGIN_BTN_PRIMARY := 36.0
const MARGIN_BTN_BRASS   := 28.0

## Found via UIKitSheet's live-controls capture (Phase 3): a button's
## auto-computed minimum width gives its label EXACTLY the text's own
## measured width with zero slack, so real glyph-shaping/kerning at render
## time (which can differ very slightly from the width TextServer reports
## for auto-sizing) clips the final character. A real margin buffer beyond
## bare-minimum fit avoids that regardless of the exact shaping delta, and
## reads as chunkier "funny furniture" buttons anyway (design brief).
const _BTN_CONTENT_H  := 48.0
const _BTN_CONTENT_V  := 20.0
## The kit's rectangular button art keeps its lip as the bottom LIP_IDLE px
## of the texture (and so of every stretched Button rect), with the visible
## face above it. Content is centred on the FACE, not the whole rect, by
## reserving the lip in content_margin_bottom — otherwise every label sits
## LIP_IDLE/2 low and overlaps the lip (M22 Phase 4 sweep). Pressed: the face
## drops PRESS_OFFSET_Y and the label drops with it (top +8, bottom -8).
const _BTN_CONTENT_BOTTOM := _BTN_CONTENT_V + UITokens.LIP_IDLE
const _HOVER_BRIGHTEN := Color(1.15, 1.15, 1.15, 1.0)

## M13 Task 16.5 follow-up (2026-09-19) — real-device text was reported "even
## smaller" than the already-undersized touch targets. Every screen in the
## game already routes through this one build() call (see grep across
## scripts/ui/*.gd), so a mobile-only font-size multiplier here fixes text
## legibility project-wide in one place instead of touching N screens
## individually. PC keeps the original sizes — desktop viewing distance and
## mouse precision don't need this, and the user asked for platform-
## appropriate sizing, not one shared size.
##
## M22 (2026-09-25) — superseded, not removed: the multiplier above was
## compensating for a project base resolution (1920x1080) that didn't match
## phone dp (a 2340x1080 phone at ~2.77 density is ~845x390 dp). M22's base
## is 1688x780 (the v0.3 design doc's own 844x390 authoring size x2), so on a
## real phone canvas px already lands at its intended dp with NO multiplier
## (design.md §3). The API is unchanged so every call site stays valid; only
## these constants move, to ~identity.
const MOBILE_FONT_SCALE := 1.0

## Tablet tier — a tablet has more physical inches per logical pixel at a
## typical viewing distance than a phone, so text should grow further while
## touch targets should NOT grow proportionally (a finger isn't bigger on a
## bigger screen). See MobileLayoutManager.is_tablet() for device-class
## detection; control_scale()/font_scale()/_min_touch_target() below are the
## single place that picks phone vs. tablet, so every existing call site
## (scaled_size(), scaled_font_size(), apply_button_juice(), etc.) becomes
## tablet-aware automatically with no changes of its own.
const TABLET_CONTROL_SCALE := 1.0
const TABLET_FONT_SCALE := 1.1
const TABLET_MIN_TOUCH_TARGET := Vector2(96, 96)

static func control_scale() -> float:
	if not is_mobile():
		return 1.0
	return TABLET_CONTROL_SCALE if MobileLayoutManager.is_tablet() else MOBILE_CONTROL_SCALE

static func font_scale() -> float:
	if not is_mobile():
		return 1.0
	return TABLET_FONT_SCALE if MobileLayoutManager.is_tablet() else MOBILE_FONT_SCALE

static func _text_setting_scale() -> float:
	if SettingsManager and SettingsManager.has_method("text_scale"):
		return SettingsManager.text_scale()
	return 1.0

static func _min_touch_target() -> Vector2:
	return TABLET_MIN_TOUCH_TARGET if MobileLayoutManager.is_tablet() else MOBILE_MIN_TOUCH_TARGET

static func _font_scale() -> float:
	return font_scale()


## M13 Task 16.5 follow-up #2 (2026-09-20) — the single dynamic-scaling
## mechanism every screen calls for control geometry: one constant to retune
## instead of N screens' worth of magic numbers.
## M22: drops to identity for the same base-resolution/dp reason as
## MOBILE_FONT_SCALE above (design.md §3).
const MOBILE_CONTROL_SCALE := 1.0
## A 48dp touch-target floor, in canvas px. M22's base (1688x780, design px
## x2) makes canvas px already equal real dp x2, so 48dp is 96 canvas px
## directly — no scale-constant multiplication needed. This floor is applied
## to every Button through apply_button_juice(), including dynamically-
## created menu rows, so a new screen cannot accidentally ship undersized
## touch controls.
const MOBILE_MIN_TOUCH_TARGET := Vector2(96, 96)

static var force_mobile_scaling_for_test: bool = false

static func is_mobile() -> bool:
	return force_mobile_scaling_for_test or not OS.has_feature("pc")

static func scaled_size(pc_size: Vector2) -> Vector2:
	return pc_size if not is_mobile() else pc_size * control_scale()

## Same as scaled_size(), but also floors the result to MOBILE_MIN_TOUCH_TARGET
## — for BUTTON call sites specifically (a panel/scroll_container/portrait
## frame has no such floor; keep using scaled_size() directly for those).
static func scaled_button_size(pc_size: Vector2) -> Vector2:
	var result := scaled_size(pc_size)
	if not is_mobile():
		return result
	return result.max(MOBILE_MIN_TOUCH_TARGET)

static func scaled(value: float) -> float:
	return value if not is_mobile() else value * control_scale()

## Several dialog screens set an explicit theme_override_font_sizes/font_size
## per-Label/Button, which bypasses build()'s own MOBILE_FONT_SCALE entirely —
## those overrides need their own mobile scaling call, using the same
## already-device-verified font ratio (not MOBILE_CONTROL_SCALE) so dialog
## text scales the same amount project text already does.
static func scaled_font_size(pc_size: int) -> int:
	return pc_size if not is_mobile() else roundi(pc_size * font_scale())


## For screens that build their interactive content at runtime rather than
## laying it out once in a .tscn — walk a freshly-built subtree once and
## scale every explicit size/override found, instead of touching every call
## site individually. Safe to call once per rebuild, NOT safe to call twice
## on the same still-alive subtree.
static func apply_mobile_control_scaling(root: Node) -> void:
	if not is_mobile():
		return
	if root is Control:
		var ctrl := root as Control
		if ctrl.custom_minimum_size != Vector2.ZERO:
			ctrl.custom_minimum_size = scaled_size(ctrl.custom_minimum_size)
		if ctrl.has_theme_font_size_override("font_size"):
			ctrl.add_theme_font_size_override(
				"font_size", scaled_font_size(ctrl.get_theme_font_size("font_size")))
	for child in root.get_children():
		apply_mobile_control_scaling(child)


static func build() -> Theme:
	var theme := Theme.new()
	# Accessibility "Text size" scales every themed font (not control
	# geometry — buttons/rows already grow from their text).
	var scale := _font_scale() * _text_setting_scale()
	var pal := UITokens.palette()

	var display_font := _load_font(FONT_GERMANIA, 18)
	var body_font := _load_body_font()
	## Baloo 2 800 (Bold) — "all numbers" per the original design brief;
	## used for HudNumLabel/ChipLabel (design.md §5).
	var num_font := _load_baloo2_variation(800)

	theme.default_font      = body_font
	theme.default_font_size = roundi(UITokens.FONT_BODY * scale)

	# ======================================================================
	# Labels — type scale (design.md §5). Default Label = BodyLabel.
	# ======================================================================
	theme.set_type_variation("DisplayLabel", "Label")
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_type_variation("HudNumLabel", "Label")
	theme.set_type_variation("BodyLabel", "Label")
	theme.set_type_variation("ChipLabel", "Label")

	for label_type in ["Label", "BodyLabel"]:
		theme.set_font("font", label_type, body_font)
		theme.set_font_size("font_size", label_type, roundi(UITokens.FONT_BODY * scale))
		theme.set_color("font_color", label_type, pal.text_on_dark_soft)
		theme.set_color("font_shadow_color", label_type, pal.ink)
		theme.set_constant("shadow_offset_x", label_type, 1)
		theme.set_constant("shadow_offset_y", label_type, 1)

	theme.set_font("font", "ChipLabel", num_font)
	theme.set_font_size("font_size", "ChipLabel", roundi(UITokens.FONT_CHIP * scale))
	theme.set_color("font_color", "ChipLabel", pal.text_on_dark_soft)
	theme.set_color("font_shadow_color", "ChipLabel", pal.ink)
	theme.set_constant("shadow_offset_x", "ChipLabel", 1)
	theme.set_constant("shadow_offset_y", "ChipLabel", 1)
	theme.set_constant("line_spacing", "ChipLabel", roundi(UITokens.BODY_LINE_SPACING * scale))

	# PillNumLabel: the number inside a v0.3 resource pill (14 design px of
	# a 30px pill), a size down from the free-standing HudNum.
	theme.set_type_variation("PillNumLabel", "Label")
	theme.set_font("font", "PillNumLabel", num_font)
	theme.set_font_size("font_size", "PillNumLabel", roundi(UITokens.FONT_PILL_NUM * scale))
	theme.set_color("font_color", "PillNumLabel", pal.hud_number)
	theme.set_color("font_shadow_color", "PillNumLabel", Color(0, 0, 0, 0.5))
	theme.set_constant("shadow_offset_x", "PillNumLabel", 0)
	theme.set_constant("shadow_offset_y", "PillNumLabel", 2)
	theme.set_font("font", "HudNumLabel", num_font)
	theme.set_font_size("font_size", "HudNumLabel", roundi(UITokens.FONT_HUD_NUM * scale))
	theme.set_color("font_color", "HudNumLabel", pal.hud_number)
	theme.set_color("font_shadow_color", "HudNumLabel", pal.ink)
	theme.set_constant("shadow_offset_x", "HudNumLabel", 1)
	theme.set_constant("shadow_offset_y", "HudNumLabel", 1)

	# Display/Title always carry the heavier ink shadow + outline so they
	# survive busy art behind them (design.md §5).
	for label_type in ["DisplayLabel", "TitleLabel"]:
		var size := UITokens.FONT_DISPLAY if label_type == "DisplayLabel" else UITokens.FONT_TITLE
		theme.set_font("font", label_type, display_font)
		theme.set_font_size("font_size", label_type, roundi(size * scale))
		# v0.3: #fff1d0 with a hard 0 2px #1a0e06 drop and no outline; the
		# drop alone reads crisper on wood and over the sea.
		theme.set_color("font_color", label_type, pal.title_on_wood)
		theme.set_color("font_shadow_color", label_type, pal.title_shadow)
		theme.set_constant("shadow_offset_x", label_type, 0)
		theme.set_constant("shadow_offset_y", label_type, UITokens.TEXT_SHADOW_OFFSET)
		theme.set_color("font_outline_color", label_type, pal.title_shadow)
		theme.set_constant("outline_size", label_type, 0)

	# Ink-on-parchment variants — every label above is light-on-dark (wood,
	# ocean), which is unreadable on a ParchmentPanel. Modals that sit on
	# parchment use these instead of per-label colour overrides.
	theme.set_type_variation("InkTitleLabel", "Label")
	theme.set_font("font", "InkTitleLabel", display_font)
	theme.set_font_size("font_size", "InkTitleLabel", roundi(UITokens.FONT_TITLE * scale))
	theme.set_type_variation("InkBodyLabel", "Label")
	theme.set_font("font", "InkBodyLabel", body_font)
	theme.set_font_size("font_size", "InkBodyLabel", roundi(UITokens.FONT_BODY * scale))
	theme.set_constant("line_spacing", "InkBodyLabel", roundi(UITokens.BODY_LINE_SPACING * scale))
	# v0.3 settings-row caption ("High needs a recent device"): Baloo 500
	# at chip size in the soft brown ink.
	theme.set_type_variation("InkSubLabel", "Label")
	theme.set_font("font", "InkSubLabel", _load_baloo2_variation(500))
	theme.set_font_size("font_size", "InkSubLabel", roundi(UITokens.FONT_CHIP * scale))
	for label_type in ["InkTitleLabel", "InkBodyLabel", "InkSubLabel"]:
		theme.set_color("font_color", label_type, pal.ink_soft if label_type == "InkSubLabel" else pal.text_on_parchment)
		theme.set_color("font_shadow_color", label_type, Color(0, 0, 0, 0))
		theme.set_constant("shadow_offset_x", label_type, 0)
		theme.set_constant("shadow_offset_y", label_type, 0)
		theme.set_constant("outline_size", label_type, 0)

	# RichTextLabel — had no theme entry at all, so [b]/[i] BBCode fell back
	# to the engine default font and rendered as plain body text (Credits,
	# M22 Phase 4 sweep). [b] = Germania display (headings), [i] = a
	# synthetic-slant Baloo 2. InkRichTextLabel is the parchment variant.
	var italic_font := FontVariation.new()
	italic_font.base_font = body_font
	italic_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	# Set on BOTH types, not just the base: Theme.has_font()/has_font_size()
	# return true for ANY type once the theme has a default_font/size, so a
	# variation lookup stops at "InkRichTextLabel" and gets the default font
	# instead of falling through to RichTextLabel's (probed, not assumed).
	theme.set_type_variation("InkRichTextLabel", "RichTextLabel")
	for rtl_type in ["RichTextLabel", "InkRichTextLabel"]:
		theme.set_font("normal_font", rtl_type, body_font)
		theme.set_font("bold_font", rtl_type, display_font)
		theme.set_font("italics_font", rtl_type, italic_font)
		theme.set_font_size("normal_font_size", rtl_type, roundi(UITokens.FONT_BODY * scale))
		theme.set_font_size("bold_font_size", rtl_type, roundi(UITokens.FONT_TITLE * scale))
		theme.set_font_size("italics_font_size", rtl_type, roundi(UITokens.FONT_BODY * scale))
	theme.set_color("default_color", "RichTextLabel", pal.text_on_dark)
	theme.set_color("default_color", "InkRichTextLabel", pal.text_on_parchment)

	# ======================================================================
	# Panels (design.md §6) — parchment 9-slice, wood frame + rope + studs,
	# wood plaque 3-slice. Default Panel/PanelContainer = wood frame.
	# ======================================================================
	var parchment_style := _texture_stylebox(TEX_PARCHMENT_PANEL,
			MARGIN_PARCHMENT, MARGIN_PARCHMENT, MARGIN_PARCHMENT, MARGIN_PARCHMENT,
			40.0, 40.0, 40.0, 40.0)
	var wood_frame_style := _texture_stylebox(TEX_WOOD_FRAME,
			MARGIN_WOOD_FRAME, MARGIN_WOOD_FRAME, MARGIN_WOOD_FRAME, MARGIN_WOOD_FRAME,
			40.0, 40.0, 32.0, 36.0)
	# The texture centre is exactly two plank periods: tile it vertically so
	# a tall frame keeps v0.3 plank scale instead of stretching the planks.
	wood_frame_style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	# Content inset 48 clears the carved end caps' brass studs (drawn at
	# 32±8 px in each 64px end, gen_kit.py) — 24 let the HUD's speed text and
	# compass disc sit on top of them (M22 Phase 5 sweep).
	var plaque_style := _texture_stylebox(TEX_WOOD_PLAQUE,
			MARGIN_PLAQUE_END, MARGIN_PLAQUE_END, 0.0, 0.0,
			48.0, 48.0, 16.0, 16.0)

	theme.set_type_variation("ParchmentPanel", "PanelContainer")
	theme.set_stylebox("panel", "ParchmentPanel", parchment_style)
	theme.set_type_variation("WoodFramePanel", "PanelContainer")
	theme.set_stylebox("panel", "WoodFramePanel", wood_frame_style)
	theme.set_type_variation("PlaquePanel", "PanelContainer")
	theme.set_stylebox("panel", "PlaquePanel", plaque_style)
	# RopeParchmentPanel: the v0.3 tutorial-toast card (rope border, studs,
	# parchment with the warm burn). The rope stripes tile on both axes.
	var rope_style := _texture_stylebox(TEX_ROPE_PARCHMENT,
			MARGIN_ROPE, MARGIN_ROPE, MARGIN_ROPE, MARGIN_ROPE, 40.0, 40.0, 32.0, 28.0)
	rope_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	rope_style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	theme.set_type_variation("RopeParchmentPanel", "PanelContainer")
	theme.set_stylebox("panel", "RopeParchmentPanel", rope_style)
	# TornParchmentPanel: the v0.3 dossier sheet (world map / detail panels)
	# with torn top and bottom edges; the jag pattern tiles horizontally.
	var torn_style := _texture_stylebox(TEX_TORN_PARCHMENT,
			MARGIN_ROPE, MARGIN_ROPE, MARGIN_ROPE, MARGIN_ROPE, 36.0, 36.0, 40.0, 36.0)
	torn_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	theme.set_type_variation("TornParchmentPanel", "PanelContainer")
	theme.set_stylebox("panel", "TornParchmentPanel", torn_style)

	theme.set_stylebox("panel", "Panel", wood_frame_style)

	# A faint ink-tinted inset card for grouping rows ON parchment (Settings'
	# Controls/Account sections) — flat by design: a second textured frame
	# nested inside the parchment page reads as noise at row scale.
	var inset := StyleBoxFlat.new()
	inset.bg_color = Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.07)
	inset.set_border_width_all(2)
	inset.border_color = Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.28)
	inset.set_corner_radius_all(12)
	inset.content_margin_left = 14.0
	inset.content_margin_right = 14.0
	inset.content_margin_top = 10.0
	inset.content_margin_bottom = 10.0
	theme.set_type_variation("InkInsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InkInsetPanel", inset)
	# CostChip: v0.3's parchment cost pill ("4,200 gold") — a darker tan
	# rounded pill ON parchment, icon + ink amount (IslandMenu and friends).
	var cost_chip := StyleBoxFlat.new()
	cost_chip.bg_color = Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.12)
	cost_chip.set_corner_radius_all(22)
	cost_chip.content_margin_left = 10.0
	cost_chip.content_margin_right = 16.0
	cost_chip.content_margin_top = 4.0
	cost_chip.content_margin_bottom = 4.0
	theme.set_type_variation("CostChip", "PanelContainer")
	theme.set_stylebox("panel", "CostChip", cost_chip)
	# PortraitFrame: a brass-rimmed dark inset around a captain portrait
	# (v0.3 screen 03's roster card). Plain — no rarity (no data for it).
	var portrait_frame := StyleBoxFlat.new()
	portrait_frame.bg_color = pal.wood_dark
	portrait_frame.set_border_width_all(4)
	portrait_frame.border_color = pal.brass
	portrait_frame.set_corner_radius_all(14)
	portrait_frame.set_content_margin_all(4.0)
	# TextLinkButton: a secondary text-only action (v0.3 "Skip") — no face,
	# ink text, still a full-size touch target via its content margins.
	var link_style := StyleBoxEmpty.new()
	link_style.content_margin_left = 16.0
	link_style.content_margin_right = 16.0
	link_style.content_margin_top = 16.0
	link_style.content_margin_bottom = 16.0
	theme.set_type_variation("TextLinkButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "TextLinkButton", link_style)
	theme.set_font("font", "TextLinkButton", body_font)
	theme.set_font_size("font_size", "TextLinkButton", roundi(UITokens.FONT_BODY * scale))
	theme.set_color("font_color", "TextLinkButton", Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.75))
	theme.set_color("font_hover_color", "TextLinkButton", pal.ink)
	theme.set_color("font_pressed_color", "TextLinkButton", pal.ink)
	theme.set_color("font_focus_color", "TextLinkButton", pal.ink)
	# BoardTile: IslandMenu's selectable board tile (v0.3 screen 02) — a
	# tan card with a brass rim on parchment; the SELECTED tile (toggle
	# pressed) gets a heavy brass ring ("selected tile: brass ring").
	var tile_normal := StyleBoxFlat.new()
	tile_normal.bg_color = Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.08)
	tile_normal.set_border_width_all(2)
	tile_normal.border_color = Color(pal.brass.r, pal.brass.g, pal.brass.b, 0.7)
	tile_normal.set_corner_radius_all(16)
	tile_normal.set_content_margin_all(10.0)
	var tile_hover := tile_normal.duplicate() as StyleBoxFlat
	tile_hover.bg_color = Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.14)
	var tile_selected := tile_normal.duplicate() as StyleBoxFlat
	tile_selected.bg_color = Color(pal.brass_light.r, pal.brass_light.g, pal.brass_light.b, 0.45)
	tile_selected.set_border_width_all(5)
	tile_selected.border_color = pal.brass
	theme.set_type_variation("BoardTile", "Button")
	theme.set_stylebox("normal", "BoardTile", tile_normal)
	theme.set_stylebox("hover", "BoardTile", tile_hover)
	theme.set_stylebox("pressed", "BoardTile", tile_selected)
	theme.set_stylebox("hover_pressed", "BoardTile", tile_selected)
	theme.set_stylebox("disabled", "BoardTile", tile_normal)
	theme.set_stylebox("focus", "BoardTile", _make_focus_outline(pal.brass_light, 16))
	theme.set_font("font", "BoardTile", num_font)
	theme.set_font_size("font_size", "BoardTile", roundi(UITokens.FONT_CHIP * scale))
	theme.set_type_variation("PortraitFrame", "PanelContainer")
	theme.set_stylebox("panel", "PortraitFrame", portrait_frame)
	theme.set_stylebox("panel", "PanelContainer", wood_frame_style)

	# ======================================================================
	# Buttons (design.md §7) — PrimaryButton (coral), default/Button (brass),
	# WoodRoundButton. OptionButton reuses brass.
	# ======================================================================
	var primary_idle := _texture_stylebox(TEX_BUTTON_PRIMARY_IDLE,
			MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY,
			_BTN_CONTENT_H, _BTN_CONTENT_H, _BTN_CONTENT_V, _BTN_CONTENT_BOTTOM)
	var primary_pressed := _texture_stylebox(TEX_BUTTON_PRIMARY_PRESSED,
			MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY,
			_BTN_CONTENT_H, _BTN_CONTENT_H,
			_BTN_CONTENT_V + UITokens.PRESS_OFFSET_Y, _BTN_CONTENT_BOTTOM - UITokens.PRESS_OFFSET_Y)
	var primary_disabled := _texture_stylebox(TEX_BUTTON_PRIMARY_DISABLED,
			MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY,
			_BTN_CONTENT_H, _BTN_CONTENT_H, _BTN_CONTENT_V, _BTN_CONTENT_BOTTOM)
	var primary_hover := primary_idle.duplicate() as StyleBoxTexture
	primary_hover.modulate_color = _HOVER_BRIGHTEN

	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", primary_idle)
	theme.set_stylebox("hover", "PrimaryButton", primary_hover)
	theme.set_stylebox("pressed", "PrimaryButton", primary_pressed)
	theme.set_stylebox("disabled", "PrimaryButton", primary_disabled)
	theme.set_stylebox("focus", "PrimaryButton", _make_focus_outline(pal.brass_light, UITokens.RADIUS_PRIMARY))
	# v0.3 coral label: Germania #fff8ec, text-shadow 0 2px 0 #7a2a0a plus a
	# 1px #7a2a0a side edge (an outline here), a size up from brass labels.
	theme.set_font("font", "PrimaryButton", display_font)
	theme.set_font_size("font_size", "PrimaryButton", roundi(UITokens.FONT_HUD_NUM * scale))
	theme.set_color("font_color", "PrimaryButton", pal.coral_text)
	theme.set_color("font_hover_color", "PrimaryButton", pal.coral_text)
	theme.set_color("font_pressed_color", "PrimaryButton", pal.coral_text)
	theme.set_color("font_focus_color", "PrimaryButton", pal.coral_text)
	theme.set_color("font_disabled_color", "PrimaryButton",
			Color(pal.coral_text.r, pal.coral_text.g, pal.coral_text.b, 0.6))
	theme.set_color("font_outline_color", "PrimaryButton", pal.coral_text_shadow)
	theme.set_constant("outline_size", "PrimaryButton", 2)
	theme.set_constant("shadow_offset_x", "PrimaryButton", 0)
	theme.set_constant("shadow_offset_y", "PrimaryButton", UITokens.TEXT_SHADOW_OFFSET)
	theme.set_color("font_shadow_color", "PrimaryButton", pal.coral_text_shadow)

	var brass_idle := _texture_stylebox(TEX_BUTTON_BRASS_IDLE,
			MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS,
			_BTN_CONTENT_H, _BTN_CONTENT_H, _BTN_CONTENT_V, _BTN_CONTENT_BOTTOM)
	var brass_pressed := _texture_stylebox(TEX_BUTTON_BRASS_PRESSED,
			MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS,
			_BTN_CONTENT_H, _BTN_CONTENT_H,
			_BTN_CONTENT_V + UITokens.PRESS_OFFSET_Y, _BTN_CONTENT_BOTTOM - UITokens.PRESS_OFFSET_Y)
	var brass_disabled := _texture_stylebox(TEX_BUTTON_BRASS_DISABLED,
			MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS,
			_BTN_CONTENT_H, _BTN_CONTENT_H, _BTN_CONTENT_V, _BTN_CONTENT_BOTTOM)
	var brass_hover := brass_idle.duplicate() as StyleBoxTexture
	brass_hover.modulate_color = _HOVER_BRIGHTEN

	theme.set_stylebox("normal", "Button", brass_idle)
	theme.set_stylebox("hover", "Button", brass_hover)
	theme.set_stylebox("pressed", "Button", brass_pressed)
	theme.set_stylebox("disabled", "Button", brass_disabled)
	theme.set_stylebox("focus", "Button", _make_focus_outline(pal.brass_light, UITokens.RADIUS_SECONDARY))
	# v0.3 brass label: Baloo 2 800 in #3a2410. Germania is reserved for
	# titles and the coral CTA; on every brass button it read as shouting.
	theme.set_font("font", "Button", num_font)
	theme.set_font_size("font_size", "Button", roundi(UITokens.FONT_BODY * scale))
	theme.set_color("font_color", "Button", pal.brass_text)
	theme.set_color("font_hover_color", "Button", pal.brass_text)
	theme.set_color("font_pressed_color", "Button", pal.brass_text)
	theme.set_color("font_focus_color", "Button", pal.brass_text)
	theme.set_color("font_disabled_color", "Button", pal.text_on_dark_soft)

	# Symmetric margins centre content on the face (the art centres it on the
	# canvas, M22 Phase 5) at ANY button size — margins are rect px, not
	# texture px, so an asymmetric lip reservation could only be right at one.
	var rc := _ROUND_CONTENT
	var wood_idle := _texture_stylebox(TEX_BUTTON_WOOD_ROUND_IDLE, 0, 0, 0, 0, rc, rc, rc, rc)
	var wood_pressed := _texture_stylebox(TEX_BUTTON_WOOD_ROUND_PRESSED, 0, 0, 0, 0,
			rc, rc, rc + UITokens.PRESS_OFFSET_Y, rc - UITokens.PRESS_OFFSET_Y)
	var wood_disabled := _texture_stylebox(TEX_BUTTON_WOOD_ROUND_DISABLED, 0, 0, 0, 0, rc, rc, rc, rc)
	var wood_hover := wood_idle.duplicate() as StyleBoxTexture
	wood_hover.modulate_color = _HOVER_BRIGHTEN

	theme.set_type_variation("WoodRoundButton", "Button")
	theme.set_stylebox("normal", "WoodRoundButton", wood_idle)
	theme.set_stylebox("hover", "WoodRoundButton", wood_hover)
	theme.set_stylebox("pressed", "WoodRoundButton", wood_pressed)
	theme.set_stylebox("disabled", "WoodRoundButton", wood_disabled)
	theme.set_stylebox("focus", "WoodRoundButton", _make_focus_outline(pal.brass_light, UITokens.RADIUS_SECONDARY))
	theme.set_font("font", "WoodRoundButton", num_font)
	theme.set_font_size("font_size", "WoodRoundButton", roundi(UITokens.FONT_CHIP * scale))
	theme.set_color("font_color", "WoodRoundButton", pal.text_on_dark)
	theme.set_color("font_hover_color", "WoodRoundButton", pal.text_on_dark)
	theme.set_color("font_pressed_color", "WoodRoundButton", pal.text_on_dark)
	theme.set_color("font_disabled_color", "WoodRoundButton",
			Color(pal.text_on_dark.r, pal.text_on_dark.g, pal.text_on_dark.b, 0.55))

	# ======================================================================
	# HSlider (rope slider) — fixes the invisible-track defect (design.md §9)
	# ======================================================================
	# Slider draws "slider"/"grabber_area" at a height equal to their
	# stylebox's own content_margin_top + content_margin_bottom (Godot uses
	# that sum as the groove's THICKNESS, not literal child-content padding,
	# since Slider has no child content) — 0/0 rendered a zero-height,
	# invisible groove regardless of the texture's own pixel content; found
	# by checking UIKitSheet's live SettingsMenu capture, not assumed.
	# Track is 28 canvas px tall (design 14): caps = 14 each side, thickness
	# 14 + 14.
	var slider_groove := _texture_stylebox(TEX_ROPE_SLIDER_TRACK, 14.0, 14.0, 0.0, 0.0, 0, 0, 14.0, 14.0)
	var slider_fill := _texture_stylebox(TEX_ROPE_SLIDER_FILL, 14.0, 14.0, 0.0, 0.0, 0, 0, 14.0, 14.0)
	theme.set_stylebox("slider", "HSlider", slider_groove)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	var knob_tex := _load_texture(TEX_ROPE_SLIDER_KNOB)
	theme.set_icon("grabber", "HSlider", knob_tex)
	theme.set_icon("grabber_highlight", "HSlider", knob_tex)
	theme.set_icon("grabber_disabled", "HSlider", knob_tex)
	theme.set_constant("center_grabber", "HSlider", 1)

	# ======================================================================
	# CheckButton (on/off pill toggle) — kit toggle_on/off.svg
	# ======================================================================
	var toggle_on_tex := _load_texture(TEX_TOGGLE_ON)
	var toggle_off_tex := _load_texture(TEX_TOGGLE_OFF)
	# Godot 4 names — "on"/"off" (Godot 3's names, used here before) are
	# silently ignored, so every toggle drew the engine's own tiny grey pill
	# (M22 Phase 4 Settings sweep). The _mirrored set is what RTL layouts use.
	for suffix in ["", "_mirrored"]:
		theme.set_icon("checked" + suffix, "CheckButton", toggle_on_tex)
		theme.set_icon("checked_disabled" + suffix, "CheckButton", toggle_on_tex)
		theme.set_icon("unchecked" + suffix, "CheckButton", toggle_off_tex)
		theme.set_icon("unchecked_disabled" + suffix, "CheckButton", toggle_off_tex)
	theme.set_font("font", "CheckButton", num_font)
	theme.set_font_size("font_size", "CheckButton", roundi(UITokens.FONT_BODY * scale))
	theme.set_color("font_color", "CheckButton", pal.text_on_dark)
	theme.set_color("font_hover_color", "CheckButton", pal.brass_light)
	theme.set_color("font_pressed_color", "CheckButton", pal.brass_light)
	theme.set_color("font_focus_color", "CheckButton", pal.text_on_dark)
	theme.set_color("font_disabled_color", "CheckButton",
			Color(pal.text_on_dark.r, pal.text_on_dark.g, pal.text_on_dark.b, 0.55))
	var check_row_style := StyleBoxFlat.new()
	check_row_style.bg_color = Color(0, 0, 0, 0)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "CheckButton", check_row_style)

	# --- CheckBox (square check, used in Account's terms-agreement row) —
	# no kit asset; kept procedural, recoloured onto the palette. ---
	var chk_on  := _make_checkbox_icon(true, pal)
	var chk_off := _make_checkbox_icon(false, pal)
	theme.set_icon("checked",            "CheckBox", chk_on)
	theme.set_icon("unchecked",          "CheckBox", chk_off)
	theme.set_icon("checked_disabled",   "CheckBox", chk_on)
	theme.set_icon("unchecked_disabled", "CheckBox", chk_off)
	theme.set_font("font", "CheckBox", num_font)
	theme.set_font_size("font_size", "CheckBox", roundi(UITokens.FONT_BODY * scale))
	theme.set_color("font_color", "CheckBox", pal.text_on_dark)
	theme.set_color("font_hover_color", "CheckBox", pal.brass_light)
	theme.set_color("font_pressed_color", "CheckBox", pal.brass_light)
	theme.set_color("font_focus_color", "CheckBox", pal.text_on_dark)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "CheckBox", check_row_style)

	# ======================================================================
	# OptionButton (brass face) + PopupMenu (dropdown_sheet.svg)
	# ======================================================================
	theme.set_stylebox("normal", "OptionButton", brass_idle)
	theme.set_stylebox("hover", "OptionButton", brass_hover)
	theme.set_stylebox("pressed", "OptionButton", brass_pressed)
	theme.set_stylebox("disabled", "OptionButton", brass_disabled)
	theme.set_stylebox("focus", "OptionButton", _make_focus_outline(pal.brass_light, UITokens.RADIUS_SECONDARY))
	theme.set_font("font", "OptionButton", num_font)
	theme.set_font_size("font_size", "OptionButton", roundi(UITokens.FONT_BODY * scale))
	theme.set_color("font_color", "OptionButton", pal.ink)
	theme.set_color("font_hover_color", "OptionButton", pal.ink)
	theme.set_color("font_pressed_color", "OptionButton", pal.ink)
	theme.set_color("font_focus_color", "OptionButton", pal.ink)
	theme.set_color("font_disabled_color", "OptionButton", Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.55))
	# Engine default arrow is a tiny light-grey chevron — invisible on brass.
	theme.set_icon("arrow", "OptionButton", _load_texture(TEX_DROPDOWN_ARROW))
	theme.set_constant("arrow_margin", "OptionButton", roundi(_BTN_CONTENT_H * 0.5))

	var popup_panel_style := _texture_stylebox(TEX_DROPDOWN_SHEET, 12.0, 12.0, 12.0, 12.0, 16.0, 16.0, 10.0, 10.0)
	theme.set_stylebox("panel", "PopupMenu", popup_panel_style)
	theme.set_color("font_color", "PopupMenu", pal.text_on_parchment)
	theme.set_color("font_hover_color", "PopupMenu", pal.coral)
	theme.set_color("font_accelerator_color", "PopupMenu", pal.brass)
	var popup_hover_style := _make_panel_stylebox(Color(pal.coral.r, pal.coral.g, pal.coral.b, 0.16), pal.coral, 1.0, 6.0)
	theme.set_stylebox("hover", "PopupMenu", popup_hover_style)
	theme.set_font("font", "PopupMenu", body_font)
	theme.set_font_size("font_size", "PopupMenu", roundi(UITokens.FONT_CHIP * scale))

	# ======================================================================
	# TabContainer / TabBar — kit tab_idle/tab_active
	# ======================================================================
	var tab_unselected := _texture_stylebox(TEX_TAB_IDLE, 12.0, 12.0, 12.0, 12.0, 18.0, 18.0, 8.0, 8.0)
	var tab_selected := _texture_stylebox(TEX_TAB_ACTIVE, 12.0, 12.0, 12.0, 12.0, 18.0, 18.0, 8.0, 8.0)
	var tab_hovered := tab_unselected.duplicate() as StyleBoxTexture
	tab_hovered.modulate_color = _HOVER_BRIGHTEN
	var tab_panel_style := wood_frame_style.duplicate() as StyleBoxTexture

	theme.set_stylebox("tab_selected",   "TabContainer", tab_selected)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected)
	theme.set_stylebox("tab_hovered",    "TabContainer", tab_hovered)
	theme.set_stylebox("tab_selected",   "TabBar", tab_selected)
	theme.set_stylebox("tab_unselected", "TabBar", tab_unselected)
	theme.set_stylebox("tab_hovered",    "TabBar", tab_hovered)
	theme.set_stylebox("panel",          "TabContainer", tab_panel_style)
	theme.set_font("font",       "TabContainer", num_font)
	theme.set_font("font",       "TabBar", num_font)
	theme.set_font_size("font_size", "TabContainer", roundi(UITokens.FONT_BODY * scale))
	theme.set_font_size("font_size", "TabBar", roundi(UITokens.FONT_BODY * scale))
	# Selected tab bleeds into the parchment page (design.md); its label
	# reads best in the same ink/parchment pairing the page itself uses.
	theme.set_color("font_selected_color",   "TabContainer", pal.text_on_parchment)
	theme.set_color("font_unselected_color", "TabContainer", pal.text_on_dark_soft)
	theme.set_color("font_hovered_color",    "TabContainer", pal.brass_light)
	theme.set_color("font_selected_color",   "TabBar", pal.text_on_parchment)
	theme.set_color("font_unselected_color", "TabBar", pal.text_on_dark_soft)
	theme.set_color("font_hovered_color",    "TabBar", pal.brass_light)
	theme.set_constant("h_separation", "TabContainer", 8)
	theme.set_constant("h_separation", "TabBar", 8)
	# RailTab: a toggle Button drawn as the same tab rail, for screens whose
	# "tabs" are a button row feeding one page (Wardrobe's slots) rather
	# than a TabContainer — the pressed tab is the parchment one.
	theme.set_type_variation("RailTab", "Button")
	theme.set_stylebox("normal", "RailTab", tab_unselected)
	theme.set_stylebox("hover", "RailTab", tab_hovered)
	theme.set_stylebox("pressed", "RailTab", tab_selected)
	theme.set_stylebox("hover_pressed", "RailTab", tab_selected)
	theme.set_stylebox("disabled", "RailTab", tab_unselected)
	theme.set_stylebox("focus", "RailTab", _make_focus_outline(pal.brass_light, 12))
	theme.set_font("font", "RailTab", num_font)
	theme.set_font_size("font_size", "RailTab", roundi(UITokens.FONT_BODY * scale))
	theme.set_color("font_color", "RailTab", pal.text_on_dark_soft)
	theme.set_color("font_hover_color", "RailTab", pal.brass_light)
	theme.set_color("font_focus_color", "RailTab", pal.text_on_dark)
	theme.set_color("font_pressed_color", "RailTab", pal.text_on_parchment)
	theme.set_color("font_hover_pressed_color", "RailTab", pal.text_on_parchment)

	# ======================================================================
	# ProgressBar — no dedicated kit asset yet (Phase 5 owns the HUD hull bar
	# specifically); flat fallback recoloured onto the palette.
	# ======================================================================
	var pb_bg := _make_panel_stylebox(Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.55), pal.brass, 1.5, 12.0)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = pal.hp_good
	pb_fill.border_width_left = 1
	pb_fill.border_width_right = 1
	pb_fill.border_color = pal.brass
	pb_fill.set_corner_radius_all(10)
	pb_fill.anti_aliasing = true
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill",       "ProgressBar", pb_fill)
	theme.set_font("font",      "ProgressBar", body_font)
	theme.set_font_size("font_size", "ProgressBar", roundi(UITokens.FONT_CHIP * scale))
	theme.set_color("font_color", "ProgressBar", pal.text_on_dark)

	# ======================================================================
	# HUD (M22 Phase 5) — resource pills, bare layout panels, hull gauge.
	# ======================================================================
	# ResourcePill: the kit's dark ocean pill with a brass rim (v0.3 HUD).
	# 9-slice margins = half its 60px height so the ends stay round at any
	# width; the icon sits snug in the left cap.
	var pill := _texture_stylebox(TEX_RESOURCE_PILL, 30.0, 30.0, 30.0, 30.0, 8.0, 24.0, 6.0, 6.0)
	theme.set_type_variation("ResourcePill", "PanelContainer")
	theme.set_stylebox("panel", "ResourcePill", pill)
	# ClearPanel: a PanelContainer used purely for layout (e.g. the bar the
	# pills sit in) — v0.3's pills float over the world, not in a frame.
	# RoundBadge: the same pill art at a square size reads as a brass-rimmed
	# ocean disc (the compass; v0.3's round minimap). Symmetric insets, so
	# centred/rotating content stays centred.
	var badge := _texture_stylebox(TEX_RESOURCE_PILL, 30.0, 30.0, 30.0, 30.0, 8.0, 8.0, 8.0, 8.0)
	theme.set_type_variation("RoundBadge", "PanelContainer")
	theme.set_stylebox("panel", "RoundBadge", badge)
	# HudCard: v0.3 HUD info card (notoriety, captain chip, cannon readouts)
	# — translucent dark rgba(18,10,5,.7), 2px #8a6a3a border, radius 14.
	# Lighter than a wood frame so the sea still reads through the HUD.
	var hud_card := StyleBoxFlat.new()
	hud_card.bg_color = pal.hud_panel
	hud_card.set_border_width_all(4)
	hud_card.border_color = pal.hud_panel_border
	hud_card.set_corner_radius_all(28)
	hud_card.content_margin_left = 24.0
	hud_card.content_margin_right = 24.0
	hud_card.content_margin_top = 12.0
	hud_card.content_margin_bottom = 14.0
	hud_card.anti_aliasing = true
	theme.set_type_variation("HudCard", "PanelContainer")
	theme.set_stylebox("panel", "HudCard", hud_card)
	# BountyCard: the v0.3 HUD objective slip — parchment rgba(236,214,164,
	# .94), radius 10, inset rgba(110,70,25,.4) edge, 0 4px 10px drop.
	var bounty := StyleBoxFlat.new()
	bounty.bg_color = Color(pal.parchment.r, pal.parchment.g, pal.parchment.b, 0.94)
	bounty.set_corner_radius_all(20)
	bounty.set_border_width_all(3)
	bounty.border_color = Color(110.0 / 255.0, 70.0 / 255.0, 25.0 / 255.0, 0.4)
	bounty.shadow_color = Color(0, 0, 0, 0.4)
	bounty.shadow_size = 10
	bounty.shadow_offset = Vector2(0, 8)
	bounty.content_margin_left = 20.0
	bounty.content_margin_right = 20.0
	bounty.content_margin_top = 14.0
	bounty.content_margin_bottom = 14.0
	bounty.anti_aliasing = true
	theme.set_type_variation("BountyCard", "PanelContainer")
	theme.set_stylebox("panel", "BountyCard", bounty)
	# SegmentWell + SegmentButton: v0.3 segmented control ("Low | Medium |
	# High"): a dark #3a2616 well, the picked option a brass pill.
	var seg_well := StyleBoxFlat.new()
	seg_well.bg_color = Color("#3A2616")
	seg_well.set_corner_radius_all(24)
	seg_well.set_content_margin_all(6.0)
	seg_well.anti_aliasing = true
	theme.set_type_variation("SegmentWell", "PanelContainer")
	theme.set_stylebox("panel", "SegmentWell", seg_well)
	var seg_off := StyleBoxEmpty.new()
	seg_off.content_margin_left = 24.0
	seg_off.content_margin_right = 24.0
	seg_off.content_margin_top = 8.0
	seg_off.content_margin_bottom = 8.0
	var seg_on := StyleBoxFlat.new()
	seg_on.bg_color = Color("#DDB060")
	seg_on.border_width_top = 3
	seg_on.border_color = Color("#F7DE98")
	seg_on.set_corner_radius_all(18)
	seg_on.content_margin_left = 24.0
	seg_on.content_margin_right = 24.0
	seg_on.content_margin_top = 8.0
	seg_on.content_margin_bottom = 8.0
	seg_on.anti_aliasing = true
	theme.set_type_variation("SegmentButton", "Button")
	for st in ["normal", "hover", "disabled", "focus"]:
		theme.set_stylebox(st, "SegmentButton", seg_off)
	theme.set_stylebox("pressed", "SegmentButton", seg_on)
	theme.set_stylebox("hover_pressed", "SegmentButton", seg_on)
	theme.set_font("font", "SegmentButton", num_font)
	theme.set_font_size("font_size", "SegmentButton", roundi(UITokens.FONT_CHIP * scale) + 2)
	theme.set_color("font_color", "SegmentButton", Color("#D9C4A0"))
	theme.set_color("font_hover_color", "SegmentButton", pal.brass_light)
	theme.set_color("font_pressed_color", "SegmentButton", pal.brass_text)
	theme.set_color("font_hover_pressed_color", "SegmentButton", pal.brass_text)
	theme.set_color("font_focus_color", "SegmentButton", Color("#D9C4A0"))
	theme.set_type_variation("ClearPanel", "PanelContainer")
	theme.set_stylebox("panel", "ClearPanel", StyleBoxEmpty.new())
	# HullBar: the same dark pill as the track, a rounded hp-green fill with
	# a lighter top edge (gloss), readable ChipLabel text over it.
	var hull_bg := pill.duplicate() as StyleBoxTexture
	hull_bg.set_content_margin_all(4.0)
	var hull_fill := StyleBoxFlat.new()
	hull_fill.bg_color = pal.hp_good
	hull_fill.set_corner_radius_all(26)
	hull_fill.border_width_top = 4
	hull_fill.border_color = pal.hp_good.lightened(0.35)
	hull_fill.expand_margin_left = -4.0
	hull_fill.expand_margin_right = -4.0
	hull_fill.expand_margin_top = -4.0
	hull_fill.expand_margin_bottom = -4.0
	hull_fill.anti_aliasing = true
	theme.set_type_variation("HullBar", "ProgressBar")
	theme.set_stylebox("background", "HullBar", hull_bg)
	theme.set_stylebox("fill", "HullBar", hull_fill)
	theme.set_font("font", "HullBar", num_font)
	theme.set_font_size("font_size", "HullBar", roundi(UITokens.FONT_CHIP * scale))
	theme.set_color("font_color", "HullBar", pal.text_on_dark)
	# EnemyHullBar: the same pill, hp-low red fill — a foe's bar must never
	# read as the player's own green hull at a glance (M22 6.9).
	var enemy_fill := hull_fill.duplicate() as StyleBoxFlat
	enemy_fill.bg_color = pal.hp_low
	enemy_fill.border_color = pal.hp_low.lightened(0.35)
	theme.set_type_variation("EnemyHullBar", "ProgressBar")
	theme.set_stylebox("background", "EnemyHullBar", hull_bg)
	theme.set_stylebox("fill", "EnemyHullBar", enemy_fill)
	theme.set_font("font", "EnemyHullBar", num_font)
	theme.set_font_size("font_size", "EnemyHullBar", roundi(UITokens.FONT_CHIP * scale))
	theme.set_color("font_color", "EnemyHullBar", pal.text_on_dark)

	# ======================================================================
	# ScrollBar — thin brass (design.md §7)
	# ======================================================================
	# Same trap as Slider above: a ScrollBar's thickness IS its stylebox's
	# minimum size (content margins), not the texture's width. 0 margins made
	# every themed scrollbar 0px wide — visible=true but undrawn and
	# undraggable (found via the Phase 4 Credits capture, confirmed by a
	# measured size of (0, 100)). 4px each side = the kit's 8px track width,
	# and works for both HScrollBar and VScrollBar since both share these.
	var scroll_track := _texture_stylebox(TEX_SCROLLBAR_TRACK, 2.0, 2.0, 0.0, 0.0, 4.0, 4.0, 4.0, 4.0)
	var scroll_grabber := _texture_stylebox(TEX_SCROLLBAR_GRABBER, 2.0, 2.0, 0.0, 0.0, 4.0, 4.0, 4.0, 4.0)
	var scroll_grabber_hi := scroll_grabber.duplicate() as StyleBoxTexture
	scroll_grabber_hi.modulate_color = _HOVER_BRIGHTEN
	for scrollbar_type in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", scrollbar_type, scroll_track)
		theme.set_stylebox("grabber", scrollbar_type, scroll_grabber)
		theme.set_stylebox("grabber_highlight", scrollbar_type, scroll_grabber_hi)
		theme.set_stylebox("grabber_pressed", scrollbar_type, scroll_grabber_hi)

	# ======================================================================
	# LineEdit (Email/Password fields) — no kit asset; flat, palette-based.
	# ======================================================================
	var line_edit_style := _make_panel_stylebox(Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.85), pal.brass.darkened(0.15), 1.5, 8.0)
	var line_edit_focus := _make_panel_stylebox(Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.85), pal.brass_light, 2.0, 8.0)
	theme.set_stylebox("normal", "LineEdit", line_edit_style)
	theme.set_stylebox("focus",  "LineEdit", line_edit_focus)
	theme.set_stylebox("read_only", "LineEdit", line_edit_style)
	theme.set_font("font",      "LineEdit", body_font)
	theme.set_font_size("font_size", "LineEdit", roundi(UITokens.FONT_BODY * scale))
	theme.set_color("font_color", "LineEdit", pal.text_on_dark)
	theme.set_color("font_placeholder_color", "LineEdit", Color(pal.text_on_dark.r, pal.text_on_dark.g, pal.text_on_dark.b, 0.45))
	theme.set_color("font_selected_color", "LineEdit", pal.ink)
	theme.set_color("selection_color",     "LineEdit", Color(pal.brass.r, pal.brass.g, pal.brass.b, 0.55))
	theme.set_color("caret_color",         "LineEdit", pal.brass_light)

	# ======================================================================
	# Tooltip + AcceptDialog/ConfirmationDialog/Window — kills the unstyled
	# grey crash popup (design.md §6).
	# ======================================================================
	var tooltip_style := _make_panel_stylebox(Color(pal.wood_dark.r, pal.wood_dark.g, pal.wood_dark.b, 0.95), pal.brass, 1.5, 8.0)
	theme.set_stylebox("panel", "TooltipPanel", tooltip_style)
	theme.set_font("font", "TooltipLabel", body_font)
	theme.set_font_size("font_size", "TooltipLabel", roundi(UITokens.FONT_CHIP * scale))
	theme.set_color("font_color", "TooltipLabel", pal.text_on_dark)

	var dialog_panel := wood_frame_style.duplicate() as StyleBoxTexture
	theme.set_stylebox("panel", "AcceptDialog", dialog_panel)
	theme.set_constant("buttons_separation", "AcceptDialog", 16)
	theme.set_stylebox("embedded_border", "Window", dialog_panel)
	theme.set_font("title_font", "Window", display_font)
	theme.set_font_size("title_font_size", "Window", roundi(UITokens.FONT_TITLE * scale))
	theme.set_color("title_color", "Window", pal.text_on_dark)

	return theme


static func _load_font(path: String, _size: int) -> Font:
	var res = ResourceLoader.load(path)
	if res is Font:
		return res as Font
	push_warning("PirateThemeBuilder: Could not load font: " + path)
	return null


## Settings > Display > UI Font (SettingsManager.ui_font — 0: Default/Baloo 2
## [M22: previously Cinzel], 1: Pirate/PirataOne, 2: Times New Roman). The
## other two are opt-in for players who want the fully thematic blackletter
## look, or their own OS-installed serif. Times New Roman is never bundled as
## an asset (unlike Baloo 2/PirataOne) — SystemFont resolves it from the OS at
## runtime, with plain-serif fallbacks for platforms (most Android devices)
## that don't ship it, so an unavailable choice degrades gracefully instead
## of erroring.
static func _load_body_font() -> Font:
	match SettingsManager.ui_font:
		1:
			return _load_font(FONT_PIRATA, 14)
		2:
			var sys_font := SystemFont.new()
			sys_font.font_names = PackedStringArray(["Times New Roman", "Liberation Serif", "Noto Serif"])
			return sys_font
		_:
			return _load_baloo2_variation(600)


## Baloo 2 ExtraBold — v0.3's "all numbers" face, for text drawn outside a
## Theme (Label3D damage numbers). Same font build() gives HudNumLabel.
static func number_font() -> Font:
	return _load_baloo2_variation(800)


## Baloo 2 ships as a single variable font (wght axis) rather than separate
## Regular/Medium/SemiBold/Bold files — FontVariation picks the weight at
## runtime. 600 (SemiBold) is design.md §5's body_font weight; 800 (Bold) is
## num_font, used for HUD/chip numerals.
##
## The axis key MUST be the integer OpenType tag: Godot 4.3 silently ignores
## a String "wght" key here (probed, M22 6.9), so from Phase 1 until then
## every "600"/"800" Baloo in the theme actually rendered at the file's
## default 400 weight.
static func _load_baloo2_variation(weight: int) -> Font:
	var base_font := _load_font(FONT_BALOO2, 14)
	if base_font == null:
		return null
	var variation := FontVariation.new()
	variation.base_font = base_font
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return variation


static func _load_texture(path: String) -> Texture2D:
	var res = ResourceLoader.load(path)
	if res is Texture2D:
		return res as Texture2D
	push_warning("PirateThemeBuilder: could not load texture: " + path)
	return null


## M22 Phase 4.3 — a parchment page for a TabContainer (Settings), set as
## that TabContainer's own `theme` ON TOP of build()'s. Holds ONLY the items
## that differ on parchment (the page stylebox, ink text colours, no light-
## text drop shadow); Godot's per-owner theme lookup falls through to build()'s
## theme for everything it doesn't define, so fonts/sizes/button art are
## untouched. Deliberately no default_font here: Theme.has_font() answers
## true for every type once a default is set, which would shadow build()'s
## fonts entirely. Covers rows built at runtime (Controls/Account tabs) with
## no per-label colour overrides.
static func build_parchment_page_theme() -> Theme:
	var pal := UITokens.palette()
	var page := Theme.new()
	var page_style := _texture_stylebox(TEX_PARCHMENT_PANEL,
			MARGIN_PARCHMENT, MARGIN_PARCHMENT, MARGIN_PARCHMENT, MARGIN_PARCHMENT,
			40.0, 40.0, 32.0, 32.0)
	page.set_stylebox("panel", "TabContainer", page_style)
	page.set_color("font_color", "Label", pal.text_on_parchment)
	page.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	for toggle_type in ["CheckButton", "CheckBox"]:
		page.set_color("font_color", toggle_type, pal.text_on_parchment)
		page.set_color("font_focus_color", toggle_type, pal.text_on_parchment)
		page.set_color("font_hover_color", toggle_type, pal.driftwood)
		page.set_color("font_pressed_color", toggle_type, pal.driftwood)
	page.set_color("font_color", "LinkButton", pal.sunset_teal)
	page.set_color("font_hover_color", "LinkButton", pal.driftwood)
	page.set_color("font_focus_color", "LinkButton", pal.sunset_teal)
	page.set_color("default_color", "RichTextLabel", pal.text_on_parchment)
	# Row dividers on parchment are a faint ink rule, not build()'s light line.
	var rule := StyleBoxLine.new()
	rule.color = Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.22)
	rule.thickness = 2
	page.set_stylebox("separator", "HSeparator", rule)
	page.set_constant("separation", "HSeparator", 14)
	return page


## M22 Phase 6b — the shared "journal page" of the content modals (Captain's
## Log, Codex, What's New, …): the page panel inside a screen's wood frame
## becomes parchment, and every Label/RichTextLabel/HSeparator under it reads
## as ink via build_parchment_page_theme(), with no per-label colour
## overrides. One helper, so those screens can't drift into three looks.
static func dress_parchment_page(page: PanelContainer) -> void:
	page.theme_type_variation = &"ParchmentPanel"
	page.theme = build_parchment_page_theme()


## M22 — the one v0.3 board tile (IslandMenu's boards, Wardrobe): a toggle
## `BoardTile` Button holding an icon over a wrapped title and a coloured
## status line. Children ignore the mouse so the tile itself takes the tap.
## Callers add the ButtonGroup/pressed wiring and pass final (already
## device-scaled, if wanted) sizes.
static func make_board_tile(tile_size: Vector2, icon_tex: Texture2D, title_text: String,
		status_text: String, status_color: Color, icon_size := Vector2(48, 48)) -> Button:
	var tile := Button.new()
	tile.theme_type_variation = &"BoardTile"
	tile.toggle_mode = true
	tile.custom_minimum_size = tile_size
	tile.tooltip_text = title_text
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_top = 10
	v.offset_right = -10
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)
	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = &"ChipLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.custom_minimum_size.x = tile_size.x - 20.0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)
	var status_lbl := Label.new()
	status_lbl.text = status_text
	status_lbl.theme_type_variation = &"ChipLabel"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_color_override("font_color", status_color)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(status_lbl)
	tile.add_child(v)
	tile.toggled.connect(UIMotion.tile_lift.bind(tile))
	return tile


## The v0.3 modal backdrop: a teal-black wash (UIPalette.modal_dim) so the
## sea still reads behind a modal, instead of each scene's own flat grey.
static func dress_modal_dim(dim: ColorRect) -> void:
	if dim:
		dim.color = UITokens.palette().modal_dim


## Ink colour for "done / good" state text on parchment — build()'s hp_good
## green is tuned for dark wood and washes out on the page.
static func ink_good_color() -> Color:
	return UITokens.palette().hp_good.darkened(0.35)


## Wraps a kit SVG as a 9/3-slice StyleBoxTexture. `m*` are texture_margin
## (the unstretched corner/edge region — see design.md §6's per-asset
## values); `c*` are content_margin (child-content padding, independent of
## the texture's own pixel layout).
static func _texture_stylebox(path: String, ml: float, mr: float, mt: float, mb: float,
		cl: float, cr: float, ct: float, cb: float, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _load_texture(path)
	sb.texture_margin_left   = ml
	sb.texture_margin_right  = mr
	sb.texture_margin_top    = mt
	sb.texture_margin_bottom = mb
	sb.content_margin_left   = cl
	sb.content_margin_right  = cr
	sb.content_margin_top    = ct
	sb.content_margin_bottom = cb
	sb.modulate_color = modulate
	return sb


## A brass-light outline with a transparent fill — Godot draws a control's
## "focus" stylebox as an overlay on top of its current-state stylebox, so
## this only needs to add the ring, not repaint the button (design.md §7:
## "keyboard/gamepad only" — never shown from a touch press).
static func _make_focus_outline(color: Color, radius: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = color
	s.set_border_width_all(int(UITokens.FOCUS_OUTLINE_WIDTH))
	s.set_corner_radius_all(int(radius))
	s.anti_aliasing = true
	return s


## Enhanced StyleBoxFlat fallback for panels/bars/one-off dynamic elements
## with no matching kit texture — larger corner radius, a real soft shadow,
## and anti-aliasing.
static func _make_panel_stylebox(bg: Color, border: Color, border_w: float, radius: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                      = bg
	s.border_color                  = border
	s.border_width_left             = int(border_w)
	s.border_width_right            = int(border_w)
	s.border_width_top              = int(border_w)
	s.border_width_bottom           = int(border_w)
	s.corner_radius_top_left        = int(radius)
	s.corner_radius_top_right       = int(radius)
	s.corner_radius_bottom_left     = int(radius)
	s.corner_radius_bottom_right    = int(radius)
	s.shadow_color                  = Color(0, 0, 0, 0.45)
	s.shadow_size                   = 10
	s.anti_aliasing                 = true
	s.content_margin_left           = 12.0
	s.content_margin_right          = 12.0
	s.content_margin_top            = 6.0
	s.content_margin_bottom         = 6.0
	return s


## Recursively attaches ButtonJuice to every Button under root that doesn't
## already have one — M15.5 Requirement 4.2. Idempotent, so it's safe to
## call on a partially-juiced tree.
## A Button auto-sized to EXACTLY its computed minimum silently drops its
## own last character under this project's canvas_items stretch mode
## combined with font oversampling — a confirmed, already-fixed-upstream
## Godot 4.3 engine bug (godotengine/godot#97417, also #95509; fixed for
## 4.4 by PR #95511, not backported to our pinned 4.3.stable). Reproduced
## via UIKitSheet's live-controls capture: a button forced to a size far
## beyond its natural fit rendered its label correctly, while the same
## label at auto-computed size did not, regardless of how much
## content_margin the button's own StyleBoxTexture reserved — margin can't
## fix it because auto-sizing always matches width to margin+text exactly,
## so the button is still "as small as possible" no matter the margin's
## absolute value. The only real fix is genuine extra width beyond that
## exact fit.
const _BTN_TEXT_CLIP_BUG_BUFFER := 32.0

static func apply_button_juice(root: Node) -> void:
	if is_mobile() and root is BaseButton:
		var target := root as BaseButton
		var min_target := _min_touch_target()
		target.custom_minimum_size = Vector2(
			maxf(target.custom_minimum_size.x, min_target.x),
			maxf(target.custom_minimum_size.y, min_target.y))
	if root is Button:
		var btn := root as Button
		var already_juiced := false
		for child in btn.get_children():
			if child is ButtonJuice:
				already_juiced = true
				break
		if not already_juiced:
			# See _BTN_TEXT_CLIP_BUG_BUFFER's header — applied once (guarded
			# by the same already_juiced check as ButtonJuice itself) so
			# repeat calls on an already-juiced tree can't compound it.
			var natural := btn.get_minimum_size()
			btn.custom_minimum_size = Vector2(
				maxf(btn.custom_minimum_size.x, natural.x + _BTN_TEXT_CLIP_BUG_BUFFER),
				btn.custom_minimum_size.y)
			btn.add_child(ButtonJuice.new())
			# One short confirmation pulse per completed UI press. The feedback
			# manager itself is a mobile-only, player-toggleable no-op elsewhere.
			btn.pressed.connect(HapticFeedbackManager.tap)
	for child in root.get_children():
		apply_button_juice(child)


## PirateThemeBuilder.mark_primary(btn) — design.md §7. Sets the
## PrimaryButton variation and attaches exactly one PrimaryGlow child.
## Idempotent: calling it twice on the same button never adds a second glow.
## A GUT test (test_primary_button_rule, Phase 4+) sweeps each instantiated
## screen scene to confirm at most one visible PrimaryButton per screen.
## M22 Phase 5 — a button whose meaning changes at runtime (MobileControls'
## context action: Set Sail / Drop Anchor / Dock) is only the Primary CTA in
## some of its states. Reverts mark_primary(): brass again, glow removed.
static func unmark_primary(btn: Button) -> void:
	if not btn:
		return
	if btn.theme_type_variation == &"PrimaryButton":
		btn.theme_type_variation = &""
	for child in btn.get_children():
		if child is PrimaryGlow:
			# Detach first: mark_primary() skips adding a glow while one is still
			# a child, and a merely-queued one would still count this frame.
			btn.remove_child(child)
			child.queue_free()


## Size for a WoodRoundButton of the given width, at the art's own aspect.
static func round_button_size(width: float) -> Vector2:
	return Vector2(width, width * ROUND_BUTTON_ART_SIZE.y / ROUND_BUTTON_ART_SIZE.x)


static func mark_primary(btn: Button) -> void:
	if not btn:
		return
	btn.theme_type_variation = "PrimaryButton"
	for child in btn.get_children():
		if child is PrimaryGlow:
			return
	btn.add_child(PrimaryGlow.new())


## Generates a square checkbox icon (checked = brass fill + ink checkmark,
## unchecked = dark inset box with brass outline) for CheckBox — no kit
## asset exists for this control, so it stays procedural, recoloured onto
## the palette (was raw COLOR_* consts pre-Phase-3.5).
static func _make_checkbox_icon(is_checked: bool, pal: UIPalette) -> ImageTexture:
	var size := 26
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bg := pal.brass if is_checked else Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.85)
	var border := pal.brass_light if is_checked else pal.brass.darkened(0.2)
	for y in range(size):
		for x in range(size):
			var on_border := x < 2 or x >= size - 2 or y < 2 or y >= size - 2
			img.set_pixel(x, y, border if on_border else bg)
	if is_checked:
		# Checkmark as two thick line segments (short leg + long leg),
		# drawn by thresholding distance-to-segment rather than per-pixel
		# loops, so it stays a clean V shape regardless of `size`.
		var p1 := Vector2(size * 0.22, size * 0.52)
		var p2 := Vector2(size * 0.42, size * 0.72)
		var p3 := Vector2(size * 0.80, size * 0.28)
		var thickness := 2.6
		for y in range(size):
			for x in range(size):
				var p := Vector2(x + 0.5, y + 0.5)
				if _dist_to_segment(p, p1, p2) <= thickness or _dist_to_segment(p, p2, p3) <= thickness:
					img.set_pixel(x, y, pal.ink)
	return ImageTexture.create_from_image(img)


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Small rounded "chip" background for a resource/stat readout (icon + count),
## tinted per-resource — used by WorldHUD's resource chips (M15.5 Requirement 3.1).
static func make_chip_stylebox(tint: Color) -> StyleBoxFlat:
	var s := _make_panel_stylebox(Color(tint.r, tint.g, tint.b, 0.22), tint, 1.5, 14.0)
	s.shadow_size = 4
	s.content_margin_left   = 8.0
	s.content_margin_right  = 10.0
	s.content_margin_top    = 4.0
	s.content_margin_bottom = 4.0
	return s

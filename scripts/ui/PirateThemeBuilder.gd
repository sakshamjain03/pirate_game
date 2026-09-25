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
const TEX_SCROLLBAR_GRABBER := KIT + "scrollbar_grabber.svg"

## design.md §6/§7's texture_margin numbers (canvas px — see gen_kit.py's
## per-asset docstrings for the source dpx() math). Button margins equal
## their own corner radius (UITokens.RADIUS_PRIMARY/SECONDARY), the standard
## rounded-rect 9-slice convention.
const MARGIN_PARCHMENT   := 80.0
const MARGIN_WOOD_FRAME  := 24.0
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
	var scale := _font_scale()
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
		theme.set_color("font_color", label_type, pal.text_on_dark)
		theme.set_color("font_shadow_color", label_type, pal.ink)
		theme.set_constant("shadow_offset_x", label_type, 1)
		theme.set_constant("shadow_offset_y", label_type, 1)

	theme.set_font("font", "ChipLabel", num_font)
	theme.set_font_size("font_size", "ChipLabel", roundi(UITokens.FONT_CHIP * scale))
	theme.set_color("font_color", "ChipLabel", pal.text_on_dark)
	theme.set_color("font_shadow_color", "ChipLabel", pal.ink)
	theme.set_constant("shadow_offset_x", "ChipLabel", 1)
	theme.set_constant("shadow_offset_y", "ChipLabel", 1)

	theme.set_font("font", "HudNumLabel", num_font)
	theme.set_font_size("font_size", "HudNumLabel", roundi(UITokens.FONT_HUD_NUM * scale))
	theme.set_color("font_color", "HudNumLabel", pal.text_on_dark)
	theme.set_color("font_shadow_color", "HudNumLabel", pal.ink)
	theme.set_constant("shadow_offset_x", "HudNumLabel", 1)
	theme.set_constant("shadow_offset_y", "HudNumLabel", 1)

	# Display/Title always carry the heavier ink shadow + outline so they
	# survive busy art behind them (design.md §5).
	for label_type in ["DisplayLabel", "TitleLabel"]:
		var size := UITokens.FONT_DISPLAY if label_type == "DisplayLabel" else UITokens.FONT_TITLE
		theme.set_font("font", label_type, display_font)
		theme.set_font_size("font_size", label_type, roundi(size * scale))
		theme.set_color("font_color", label_type, pal.text_on_dark)
		theme.set_color("font_shadow_color", label_type, pal.ink)
		theme.set_constant("shadow_offset_x", label_type, 0)
		theme.set_constant("shadow_offset_y", label_type, UITokens.TEXT_SHADOW_OFFSET)
		theme.set_color("font_outline_color", label_type, pal.ink)
		theme.set_constant("outline_size", label_type, UITokens.TEXT_OUTLINE_SIZE)

	# ======================================================================
	# Panels (design.md §6) — parchment 9-slice, wood frame + rope + studs,
	# wood plaque 3-slice. Default Panel/PanelContainer = wood frame.
	# ======================================================================
	var parchment_style := _texture_stylebox(TEX_PARCHMENT_PANEL,
			MARGIN_PARCHMENT, MARGIN_PARCHMENT, MARGIN_PARCHMENT, MARGIN_PARCHMENT,
			40.0, 40.0, 40.0, 40.0)
	var wood_frame_style := _texture_stylebox(TEX_WOOD_FRAME,
			MARGIN_WOOD_FRAME, MARGIN_WOOD_FRAME, MARGIN_WOOD_FRAME, MARGIN_WOOD_FRAME,
			32.0, 32.0, 32.0, 32.0)
	var plaque_style := _texture_stylebox(TEX_WOOD_PLAQUE,
			MARGIN_PLAQUE_END, MARGIN_PLAQUE_END, 0.0, 0.0,
			24.0, 24.0, 16.0, 16.0)

	theme.set_type_variation("ParchmentPanel", "PanelContainer")
	theme.set_stylebox("panel", "ParchmentPanel", parchment_style)
	theme.set_type_variation("WoodFramePanel", "PanelContainer")
	theme.set_stylebox("panel", "WoodFramePanel", wood_frame_style)
	theme.set_type_variation("PlaquePanel", "PanelContainer")
	theme.set_stylebox("panel", "PlaquePanel", plaque_style)

	theme.set_stylebox("panel", "Panel", wood_frame_style)
	theme.set_stylebox("panel", "PanelContainer", wood_frame_style)

	# ======================================================================
	# Buttons (design.md §7) — PrimaryButton (coral), default/Button (brass),
	# WoodRoundButton. OptionButton reuses brass.
	# ======================================================================
	var primary_idle := _texture_stylebox(TEX_BUTTON_PRIMARY_IDLE,
			MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY,
			_BTN_CONTENT_H, _BTN_CONTENT_H, _BTN_CONTENT_V, _BTN_CONTENT_V)
	var primary_pressed := _texture_stylebox(TEX_BUTTON_PRIMARY_PRESSED,
			MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY,
			_BTN_CONTENT_H, _BTN_CONTENT_H,
			_BTN_CONTENT_V + UITokens.PRESS_OFFSET_Y, _BTN_CONTENT_V - UITokens.PRESS_OFFSET_Y)
	var primary_disabled := _texture_stylebox(TEX_BUTTON_PRIMARY_DISABLED,
			MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY, MARGIN_BTN_PRIMARY,
			_BTN_CONTENT_H, _BTN_CONTENT_H, _BTN_CONTENT_V, _BTN_CONTENT_V)
	var primary_hover := primary_idle.duplicate() as StyleBoxTexture
	primary_hover.modulate_color = _HOVER_BRIGHTEN

	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", primary_idle)
	theme.set_stylebox("hover", "PrimaryButton", primary_hover)
	theme.set_stylebox("pressed", "PrimaryButton", primary_pressed)
	theme.set_stylebox("disabled", "PrimaryButton", primary_disabled)
	theme.set_stylebox("focus", "PrimaryButton", _make_focus_outline(pal.brass_light, UITokens.RADIUS_PRIMARY))
	theme.set_font("font", "PrimaryButton", display_font)
	theme.set_font_size("font_size", "PrimaryButton", roundi(UITokens.FONT_BODY * scale))
	theme.set_color("font_color", "PrimaryButton", pal.text_on_dark)
	theme.set_color("font_hover_color", "PrimaryButton", pal.text_on_dark)
	theme.set_color("font_pressed_color", "PrimaryButton", pal.text_on_dark)
	theme.set_color("font_focus_color", "PrimaryButton", pal.text_on_dark)
	theme.set_color("font_disabled_color", "PrimaryButton",
			Color(pal.text_on_dark.r, pal.text_on_dark.g, pal.text_on_dark.b, 0.55))
	theme.set_color("font_outline_color", "PrimaryButton", pal.ink)
	theme.set_constant("outline_size", "PrimaryButton", UITokens.TEXT_OUTLINE_SIZE)
	theme.set_constant("shadow_offset_x", "PrimaryButton", 0)
	theme.set_constant("shadow_offset_y", "PrimaryButton", UITokens.TEXT_SHADOW_OFFSET)
	theme.set_color("font_shadow_color", "PrimaryButton", pal.ink)

	var brass_idle := _texture_stylebox(TEX_BUTTON_BRASS_IDLE,
			MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS,
			_BTN_CONTENT_H, _BTN_CONTENT_H, _BTN_CONTENT_V, _BTN_CONTENT_V)
	var brass_pressed := _texture_stylebox(TEX_BUTTON_BRASS_PRESSED,
			MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS,
			_BTN_CONTENT_H, _BTN_CONTENT_H,
			_BTN_CONTENT_V + UITokens.PRESS_OFFSET_Y, _BTN_CONTENT_V - UITokens.PRESS_OFFSET_Y)
	var brass_disabled := _texture_stylebox(TEX_BUTTON_BRASS_DISABLED,
			MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS, MARGIN_BTN_BRASS,
			_BTN_CONTENT_H, _BTN_CONTENT_H, _BTN_CONTENT_V, _BTN_CONTENT_V)
	var brass_hover := brass_idle.duplicate() as StyleBoxTexture
	brass_hover.modulate_color = _HOVER_BRIGHTEN

	theme.set_stylebox("normal", "Button", brass_idle)
	theme.set_stylebox("hover", "Button", brass_hover)
	theme.set_stylebox("pressed", "Button", brass_pressed)
	theme.set_stylebox("disabled", "Button", brass_disabled)
	theme.set_stylebox("focus", "Button", _make_focus_outline(pal.brass_light, UITokens.RADIUS_SECONDARY))
	theme.set_font("font", "Button", display_font)
	theme.set_font_size("font_size", "Button", roundi(UITokens.FONT_BODY * scale))
	# Brass face is a light metal gradient — ink reads best on it (unlike the
	# old dark-navy Kenney button art this replaces, which needed gold text).
	theme.set_color("font_color", "Button", pal.ink)
	theme.set_color("font_hover_color", "Button", pal.ink)
	theme.set_color("font_pressed_color", "Button", pal.ink)
	theme.set_color("font_focus_color", "Button", pal.ink)
	theme.set_color("font_disabled_color", "Button", Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.55))

	var wood_idle := _texture_stylebox(TEX_BUTTON_WOOD_ROUND_IDLE, 0, 0, 0, 0, 16.0, 16.0, 16.0, 16.0)
	var wood_pressed := _texture_stylebox(TEX_BUTTON_WOOD_ROUND_PRESSED, 0, 0, 0, 0,
			16.0, 16.0, 16.0 + UITokens.PRESS_OFFSET_Y, 16.0 - UITokens.PRESS_OFFSET_Y)
	var wood_disabled := _texture_stylebox(TEX_BUTTON_WOOD_ROUND_DISABLED, 0, 0, 0, 0, 16.0, 16.0, 16.0, 16.0)
	var wood_hover := wood_idle.duplicate() as StyleBoxTexture
	wood_hover.modulate_color = _HOVER_BRIGHTEN

	theme.set_type_variation("WoodRoundButton", "Button")
	theme.set_stylebox("normal", "WoodRoundButton", wood_idle)
	theme.set_stylebox("hover", "WoodRoundButton", wood_hover)
	theme.set_stylebox("pressed", "WoodRoundButton", wood_pressed)
	theme.set_stylebox("disabled", "WoodRoundButton", wood_disabled)
	theme.set_stylebox("focus", "WoodRoundButton", _make_focus_outline(pal.brass_light, UITokens.RADIUS_SECONDARY))
	theme.set_font("font", "WoodRoundButton", display_font)
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
	var slider_groove := _texture_stylebox(TEX_ROPE_SLIDER_TRACK, 7.0, 7.0, 0.0, 0.0, 0, 0, 7.0, 7.0)
	var slider_fill := _texture_stylebox(TEX_ROPE_SLIDER_FILL, 7.0, 7.0, 0.0, 0.0, 0, 0, 7.0, 7.0)
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
	theme.set_icon("on", "CheckButton", toggle_on_tex)
	theme.set_icon("on_disabled", "CheckButton", toggle_on_tex)
	theme.set_icon("off", "CheckButton", toggle_off_tex)
	theme.set_icon("off_disabled", "CheckButton", toggle_off_tex)
	theme.set_font("font", "CheckButton", display_font)
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
	theme.set_font("font", "CheckBox", display_font)
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
	theme.set_font("font", "OptionButton", display_font)
	theme.set_font_size("font_size", "OptionButton", roundi(UITokens.FONT_BODY * scale))
	theme.set_color("font_color", "OptionButton", pal.ink)
	theme.set_color("font_hover_color", "OptionButton", pal.ink)
	theme.set_color("font_pressed_color", "OptionButton", pal.ink)
	theme.set_color("font_focus_color", "OptionButton", pal.ink)
	theme.set_color("font_disabled_color", "OptionButton", Color(pal.ink.r, pal.ink.g, pal.ink.b, 0.55))

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
	theme.set_font("font",       "TabContainer", display_font)
	theme.set_font("font",       "TabBar", display_font)
	theme.set_font_size("font_size", "TabContainer", roundi(UITokens.FONT_BODY * scale))
	theme.set_font_size("font_size", "TabBar", roundi(UITokens.FONT_BODY * scale))
	# Selected tab bleeds into the parchment page (design.md); its label
	# reads best in the same ink/parchment pairing the page itself uses.
	theme.set_color("font_selected_color",   "TabContainer", pal.text_on_parchment)
	theme.set_color("font_unselected_color", "TabContainer", pal.text_on_dark)
	theme.set_color("font_hovered_color",    "TabContainer", pal.brass_light)
	theme.set_color("font_selected_color",   "TabBar", pal.text_on_parchment)
	theme.set_color("font_unselected_color", "TabBar", pal.text_on_dark)
	theme.set_color("font_hovered_color",    "TabBar", pal.brass_light)
	theme.set_constant("h_separation", "TabContainer", 8)
	theme.set_constant("h_separation", "TabBar", 8)

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
	# ScrollBar — thin brass (design.md §7)
	# ======================================================================
	var scroll_track := _texture_stylebox(TEX_SCROLLBAR_TRACK, 2.0, 2.0, 0.0, 0.0, 0, 0, 0, 0)
	var scroll_grabber := _texture_stylebox(TEX_SCROLLBAR_GRABBER, 2.0, 2.0, 0.0, 0.0, 0, 0, 0, 0)
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


## Baloo 2 ships as a single variable font (wght axis) rather than separate
## Regular/Medium/SemiBold/Bold files — FontVariation picks the weight at
## runtime. 600 (SemiBold) is design.md §5's body_font weight; 800 (Bold) is
## num_font, used for HUD/chip numerals.
static func _load_baloo2_variation(weight: int) -> Font:
	var base_font := _load_font(FONT_BALOO2, 14)
	if base_font == null:
		return null
	var variation := FontVariation.new()
	variation.base_font = base_font
	variation.variation_opentype = {"wght": weight}
	return variation


static func _load_texture(path: String) -> Texture2D:
	var res = ResourceLoader.load(path)
	if res is Texture2D:
		return res as Texture2D
	push_warning("PirateThemeBuilder: could not load texture: " + path)
	return null


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

class_name PirateThemeBuilder extends RefCounted

## Purpose: Builds and returns the shared Pirate Empire UI Theme programmatically.
## Responsibilities: Loads fonts, sets button/label/panel styles for all pirate UI.
## Usage: call PirateThemeBuilder.build() from any script that needs the theme.
## M15.5: Button styles now render from a sourced CC0 texture pack (see
## assets/ui_icons/LICENSE_ui-pack.txt) instead of flat StyleBoxFlat boxes —
## Godot's StyleBoxFlat has no gradient fill, and a StyleBoxTexture built from
## a real gradient-shaded PNG is the low-risk way to get a rounded, glossy
## "modern mobile game" button without a custom shader. Panels/bars/one-off
## dynamic elements keep the enhanced StyleBoxFlat fallback (_make_panel_stylebox)
## since the sourced pack had no matching background-panel or bar texture —
## see docs/05_CURRENT_SYSTEMS.md's M15.5 entry for the full rationale.

const FONT_PIRATA    := "res://assets/fonts/PirataOne-Regular.ttf"
const FONT_CINZEL    := "res://assets/fonts/Cinzel-Regular.ttf"
const FONT_CINZEL_B  := "res://assets/fonts/Cinzel-Bold.ttf"

const BUTTON_TEX_NORMAL   := "res://assets/ui_icons/buttons/button_normal.png"
const BUTTON_TEX_HOVER    := "res://assets/ui_icons/buttons/button_hover.png"
const BUTTON_TEX_PRESSED  := "res://assets/ui_icons/buttons/button_pressed.png"
const BUTTON_TEX_FOCUS    := "res://assets/ui_icons/buttons/button_focus.png"
const BUTTON_TEX_DISABLED := "res://assets/ui_icons/buttons/button_disabled.png"

# Color palette matching concept art
const COLOR_GOLD         := Color(0.831, 0.686, 0.216, 1.0)   # #D4AF37
const COLOR_GOLD_BRIGHT  := Color(1.0,   0.843, 0.35,  1.0)   # bright gold
const COLOR_DARK_NAVY    := Color(0.051, 0.071, 0.145, 0.88)   # semi-transparent dark
const COLOR_DARK_PANEL   := Color(0.071, 0.102, 0.18,  0.92)
const COLOR_SHADOW_DARK  := Color(0.02,  0.03,  0.07,  1.0)
const COLOR_TEXT_LIGHT   := Color(0.95,  0.92,  0.82,  1.0)   # warm cream
const COLOR_RED_HEALTH   := Color(0.78,  0.16,  0.16,  1.0)
const COLOR_GREEN_HEALTH := Color(0.22,  0.7,   0.27,  1.0)

## M13 Task 16.5 follow-up (2026-09-19) — real-device text was reported "even
## smaller" than the already-undersized touch targets. Every screen in the
## game already routes through this one build() call (see grep across
## scripts/ui/*.gd), so a mobile-only font-size multiplier here fixes text
## legibility project-wide in one place instead of touching N screens
## individually. PC keeps the original sizes — desktop viewing distance and
## mouse precision don't need this, and the user asked for platform-
## appropriate sizing, not one shared size.
const MOBILE_FONT_SCALE := 1.45

## Tablet tier — a tablet has more physical inches per logical pixel at a
## typical viewing distance than a phone, so text should grow further while
## touch targets should NOT grow proportionally (a finger isn't bigger on a
## bigger screen). See MobileLayoutManager.is_tablet() for device-class
## detection; control_scale()/font_scale()/_min_touch_target() below are the
## single place that picks phone vs. tablet, so every existing call site
## (scaled_size(), scaled_font_size(), apply_button_juice(), etc.) becomes
## tablet-aware automatically with no changes of its own.
const TABLET_CONTROL_SCALE := 1.15
const TABLET_FONT_SCALE := 1.6
const TABLET_MIN_TOUCH_TARGET := Vector2(56, 56)

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


## M13 Task 16.5 follow-up #2 (2026-09-20) — the first mobile-sizing pass only
## touched MobileControls/WorldHUD's button row/MainMenu; 14 other screens
## (PauseMenu, SettingsMenu, WorldMapScreen, WardrobeScreen, IslandMenu,
## CaptainsLog, DeathScreen, RaidReportScreen, TutorialDialogue,
## WhatsNewScreen, PurchaseSupportScreen, StoreScreen,
## CreditsScreen, FloatingDamage) still render at PC-tuned pixel sizes on
## phone. Rather than hand-tuning a bespoke PC/mobile Vector2 pair per screen
## (as WorldHUD.gd's HUD_BUTTON_SIZE_PC/MOBILE did — fine for 1-2 screens, not
## 14), this is the single dynamic-scaling mechanism every screen calls: one
## constant to retune from real-device screenshots instead of 14 files' worth
## of magic numbers. Separate knob from MOBILE_FONT_SCALE since text and
## control geometry don't need to move in lockstep.
const MOBILE_CONTROL_SCALE := 1.5
## A 48dp target becomes 72 canvas pixels at the mobile control scale. This
## floor is applied to every Button through apply_button_juice(), including
## dynamically-created menu rows, so a new screen cannot accidentally ship
## desktop-sized touch controls.
const MOBILE_MIN_TOUCH_TARGET := Vector2(72, 72)

static var force_mobile_scaling_for_test: bool = false

static func is_mobile() -> bool:
	return force_mobile_scaling_for_test or not OS.has_feature("pc")

static func scaled_size(pc_size: Vector2) -> Vector2:
	return pc_size if not is_mobile() else pc_size * control_scale()

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
## laying it out once in a .tscn (IslandMenu's building/ship/captain/fleet/
## research/trade rows in particular — dozens of Button.new()/Label.new()
## call sites, each with its own hardcoded PC custom_minimum_size/font_size
## override) — walk a freshly-built subtree once and scale every explicit
## size/override found, instead of touching every call site individually.
## Safe to call once per rebuild (each _refresh_*() frees its old children
## and creates new ones from the same PC-literal values, so there is no
## already-scaled value here to compound against) — NOT safe to call twice
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

	var cinzel_font  = _load_font(FONT_CINZEL,    14)
	var cinzel_bold  = _load_font(FONT_CINZEL_B,  18)

	# --- Body font (Label/ProgressBar/PopupMenu/LineEdit/default) ---
	# Cinzel is the default, not PirataOne — PirataOne's blackletter-style
	# swashes read fine as a large decorative flourish but are genuinely
	# illegible for dense numeric readouts (HUD hull/HP text) at small/mobile
	# sizes (player feedback, 2026-09-21). Player-selectable in Settings >
	# Display > UI Font (SettingsManager.ui_font) for anyone who prefers the
	# fully thematic look, or their own OS Times New Roman — see
	# _load_body_font()'s header for that mapping. Buttons/OptionButton/
	# CheckButton/TabContainer stay on Cinzel regardless of this choice; they
	# were never the legibility complaint this setting exists for.
	var body_font := _load_body_font(cinzel_font)
	theme.default_font      = body_font
	theme.default_font_size = roundi(15 * scale)

	# --- Labels ---
	theme.set_font("font",      "Label", body_font)
	theme.set_font_size("font_size", "Label", roundi(15 * scale))
	theme.set_color("font_color", "Label", COLOR_TEXT_LIGHT)
	theme.set_color("font_shadow_color", "Label", COLOR_SHADOW_DARK)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)

	# --- Buttons (textured — see header note) ---
	var btn_normal   := _make_texture_button_stylebox(BUTTON_TEX_NORMAL)
	var btn_hover    := _make_texture_button_stylebox(BUTTON_TEX_HOVER)
	var btn_pressed  := _make_texture_button_stylebox(BUTTON_TEX_PRESSED)
	var btn_focus    := _make_texture_button_stylebox(BUTTON_TEX_FOCUS)
	var btn_disabled := _make_texture_button_stylebox(BUTTON_TEX_DISABLED)

	theme.set_stylebox("normal",   "Button", btn_normal)
	theme.set_stylebox("hover",    "Button", btn_hover)
	theme.set_stylebox("pressed",  "Button", btn_pressed)
	theme.set_stylebox("focus",    "Button", btn_focus)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_font("font",      "Button", cinzel_font)
	theme.set_font_size("font_size", "Button", roundi(15 * scale))
	# Button face is dark navy (see button_normal.png etc.) — label text needs
	# to be light to read against it, not COLOR_SHADOW_DARK (that was tuned
	# for the old light/tan textured-button art and is near-invisible here).
	# Matches the button's own gold border art (COLOR_GOLD) rather than a
	# plain light neutral, per explicit direction — text should read as part
	# of the same gold accent as the border, not just "readable."
	theme.set_color("font_color",          "Button", COLOR_GOLD)
	theme.set_color("font_hover_color",    "Button", COLOR_GOLD_BRIGHT)
	theme.set_color("font_pressed_color",  "Button", COLOR_GOLD_BRIGHT)
	theme.set_color("font_focus_color",    "Button", COLOR_GOLD)
	theme.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.42, 0.8))

	# --- Panels (enhanced flat fallback — no matching texture asset sourced) ---
	var panel_style := _make_panel_stylebox(COLOR_DARK_NAVY, COLOR_GOLD, 2.0, 16.0)
	theme.set_stylebox("panel", "Panel",          panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# --- HSlider (M18 settings uplift — was fully unstyled, rendering as
	# stock Godot gray against the gold/navy card; low contrast and visually
	# inconsistent with the rest of the theme) ---
	var slider_groove := _make_panel_stylebox(COLOR_SHADOW_DARK, COLOR_GOLD.darkened(0.35), 1.5, 8.0)
	slider_groove.content_margin_left = 0.0
	slider_groove.content_margin_right = 0.0
	slider_groove.content_margin_top = 0.0
	slider_groove.content_margin_bottom = 0.0
	var slider_fill := _make_panel_stylebox(COLOR_GOLD, COLOR_GOLD_BRIGHT, 1.0, 8.0)
	slider_fill.content_margin_left = 0.0
	slider_fill.content_margin_right = 0.0
	slider_fill.content_margin_top = 0.0
	slider_fill.content_margin_bottom = 0.0
	theme.set_stylebox("slider",       "HSlider", slider_groove)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	var grabber_icon := _make_slider_grabber_icon(COLOR_GOLD_BRIGHT, COLOR_SHADOW_DARK)
	theme.set_icon("grabber",           "HSlider", grabber_icon)
	theme.set_icon("grabber_highlight", "HSlider", grabber_icon)
	theme.set_icon("grabber_disabled",  "HSlider", _make_slider_grabber_icon(Color(0.4, 0.4, 0.42, 0.8), COLOR_SHADOW_DARK))
	theme.set_constant("center_grabber", "HSlider", 1)

	# --- CheckButton (on/off pill toggle) ---
	var cb_on  := _make_toggle_icon(true)
	var cb_off := _make_toggle_icon(false)
	theme.set_icon("on",              "CheckButton", cb_on)
	theme.set_icon("on_disabled",     "CheckButton", cb_on)
	theme.set_icon("off",             "CheckButton", cb_off)
	theme.set_icon("off_disabled",    "CheckButton", cb_off)
	theme.set_font("font",            "CheckButton", cinzel_font)
	theme.set_font_size("font_size",  "CheckButton", roundi(15 * scale))
	theme.set_color("font_color",          "CheckButton", COLOR_TEXT_LIGHT)
	theme.set_color("font_hover_color",    "CheckButton", COLOR_GOLD_BRIGHT)
	theme.set_color("font_pressed_color",  "CheckButton", COLOR_GOLD_BRIGHT)
	theme.set_color("font_focus_color",    "CheckButton", COLOR_TEXT_LIGHT)
	theme.set_color("font_disabled_color", "CheckButton", Color(0.4, 0.4, 0.42, 0.8))
	var check_row_style := StyleBoxFlat.new()
	check_row_style.bg_color = Color(0, 0, 0, 0)
	theme.set_stylebox("normal",   "CheckButton", check_row_style)
	theme.set_stylebox("hover",    "CheckButton", check_row_style)
	theme.set_stylebox("pressed",  "CheckButton", check_row_style)
	theme.set_stylebox("disabled", "CheckButton", check_row_style)
	theme.set_stylebox("focus",    "CheckButton", check_row_style)

	# --- CheckBox (square check, used in Account's terms-agreement row) ---
	var chk_on  := _make_checkbox_icon(true)
	var chk_off := _make_checkbox_icon(false)
	theme.set_icon("checked",           "CheckBox", chk_on)
	theme.set_icon("unchecked",         "CheckBox", chk_off)
	theme.set_icon("checked_disabled",  "CheckBox", chk_on)
	theme.set_icon("unchecked_disabled","CheckBox", chk_off)
	theme.set_font("font",            "CheckBox", cinzel_font)
	theme.set_font_size("font_size",  "CheckBox", roundi(15 * scale))
	theme.set_color("font_color",          "CheckBox", COLOR_TEXT_LIGHT)
	theme.set_color("font_hover_color",    "CheckBox", COLOR_GOLD_BRIGHT)
	theme.set_color("font_pressed_color",  "CheckBox", COLOR_GOLD_BRIGHT)
	theme.set_color("font_focus_color",    "CheckBox", COLOR_TEXT_LIGHT)
	theme.set_stylebox("normal",   "CheckBox", check_row_style)
	theme.set_stylebox("hover",    "CheckBox", check_row_style)
	theme.set_stylebox("pressed",  "CheckBox", check_row_style)
	theme.set_stylebox("disabled", "CheckBox", check_row_style)
	theme.set_stylebox("focus",    "CheckBox", check_row_style)

	# --- OptionButton (dropdowns — Graphics Quality, Resolution) ---
	theme.set_stylebox("normal",   "OptionButton", btn_normal)
	theme.set_stylebox("hover",    "OptionButton", btn_hover)
	theme.set_stylebox("pressed",  "OptionButton", btn_pressed)
	theme.set_stylebox("focus",    "OptionButton", btn_focus)
	theme.set_stylebox("disabled", "OptionButton", btn_disabled)
	theme.set_font("font",      "OptionButton", cinzel_font)
	theme.set_font_size("font_size", "OptionButton", roundi(15 * scale))
	theme.set_color("font_color",          "OptionButton", COLOR_GOLD)
	theme.set_color("font_hover_color",    "OptionButton", COLOR_GOLD_BRIGHT)
	theme.set_color("font_pressed_color",  "OptionButton", COLOR_GOLD_BRIGHT)
	theme.set_color("font_focus_color",    "OptionButton", COLOR_GOLD)
	theme.set_color("font_disabled_color", "OptionButton", Color(0.4, 0.4, 0.42, 0.8))
	var popup_panel_style := _make_panel_stylebox(COLOR_DARK_PANEL, COLOR_GOLD, 2.0, 8.0)
	theme.set_stylebox("panel", "PopupMenu", popup_panel_style)
	theme.set_color("font_color",         "PopupMenu", COLOR_TEXT_LIGHT)
	theme.set_color("font_hover_color",   "PopupMenu", COLOR_GOLD_BRIGHT)
	theme.set_color("font_accelerator_color", "PopupMenu", COLOR_GOLD)
	var popup_hover_style := _make_panel_stylebox(Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.18), COLOR_GOLD, 1.0, 6.0)
	theme.set_stylebox("hover", "PopupMenu", popup_hover_style)
	theme.set_font("font", "PopupMenu", body_font)
	theme.set_font_size("font_size", "PopupMenu", roundi(14 * scale))

	# --- LineEdit (Email/Password fields) ---
	var line_edit_style := _make_panel_stylebox(COLOR_SHADOW_DARK, COLOR_GOLD.darkened(0.3), 1.5, 8.0)
	var line_edit_focus := _make_panel_stylebox(COLOR_SHADOW_DARK, COLOR_GOLD_BRIGHT, 2.0, 8.0)
	theme.set_stylebox("normal", "LineEdit", line_edit_style)
	theme.set_stylebox("focus",  "LineEdit", line_edit_focus)
	theme.set_stylebox("read_only", "LineEdit", line_edit_style)
	theme.set_font("font",      "LineEdit", body_font)
	theme.set_font_size("font_size", "LineEdit", roundi(15 * scale))
	theme.set_color("font_color",          "LineEdit", COLOR_TEXT_LIGHT)
	theme.set_color("font_placeholder_color", "LineEdit", Color(COLOR_TEXT_LIGHT.r, COLOR_TEXT_LIGHT.g, COLOR_TEXT_LIGHT.b, 0.45))
	theme.set_color("font_selected_color", "LineEdit", COLOR_SHADOW_DARK)
	theme.set_color("selection_color",     "LineEdit", Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.55))
	theme.set_color("caret_color",         "LineEdit", COLOR_GOLD_BRIGHT)

	# --- TabContainer / TabBar (gold pill for the active tab) ---
	var tab_unselected := _make_panel_stylebox(Color(COLOR_DARK_PANEL.r, COLOR_DARK_PANEL.g, COLOR_DARK_PANEL.b, 0.4), COLOR_GOLD.darkened(0.45), 1.0, 10.0)
	tab_unselected.content_margin_left = 18.0
	tab_unselected.content_margin_right = 18.0
	tab_unselected.content_margin_top = 8.0
	tab_unselected.content_margin_bottom = 8.0
	var tab_selected := _make_panel_stylebox(COLOR_GOLD, COLOR_GOLD_BRIGHT, 1.5, 10.0)
	tab_selected.content_margin_left = 18.0
	tab_selected.content_margin_right = 18.0
	tab_selected.content_margin_top = 8.0
	tab_selected.content_margin_bottom = 8.0
	var tab_hovered := _make_panel_stylebox(Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.25), COLOR_GOLD, 1.0, 10.0)
	tab_hovered.content_margin_left = 18.0
	tab_hovered.content_margin_right = 18.0
	tab_hovered.content_margin_top = 8.0
	tab_hovered.content_margin_bottom = 8.0
	var tab_panel_style := _make_panel_stylebox(Color(COLOR_DARK_PANEL.r, COLOR_DARK_PANEL.g, COLOR_DARK_PANEL.b, 0.55), COLOR_GOLD.darkened(0.3), 1.0, 12.0)
	theme.set_stylebox("tab_selected",   "TabContainer", tab_selected)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected)
	theme.set_stylebox("tab_hovered",    "TabContainer", tab_hovered)
	theme.set_stylebox("tab_selected",   "TabBar", tab_selected)
	theme.set_stylebox("tab_unselected", "TabBar", tab_unselected)
	theme.set_stylebox("tab_hovered",    "TabBar", tab_hovered)
	theme.set_stylebox("panel",          "TabContainer", tab_panel_style)
	theme.set_font("font",       "TabContainer", cinzel_font)
	theme.set_font("font",       "TabBar", cinzel_font)
	theme.set_font_size("font_size", "TabContainer", roundi(15 * scale))
	theme.set_font_size("font_size", "TabBar", roundi(15 * scale))
	# Selected tab has a solid gold pill background — its label reads best in
	# the same dark navy the buttons/panels already use, not gold-on-gold.
	theme.set_color("font_selected_color",   "TabContainer", COLOR_DARK_NAVY)
	theme.set_color("font_unselected_color", "TabContainer", COLOR_TEXT_LIGHT)
	theme.set_color("font_hovered_color",    "TabContainer", COLOR_GOLD_BRIGHT)
	theme.set_color("font_selected_color",   "TabBar", COLOR_DARK_NAVY)
	theme.set_color("font_unselected_color", "TabBar", COLOR_TEXT_LIGHT)
	theme.set_color("font_hovered_color",    "TabBar", COLOR_GOLD_BRIGHT)
	theme.set_constant("h_separation", "TabContainer", 8)
	theme.set_constant("h_separation", "TabBar", 8)

	# --- ProgressBar (enhanced flat fallback) ---
	var pb_bg  := _make_panel_stylebox(COLOR_SHADOW_DARK, COLOR_GOLD, 1.5, 12.0)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color               = COLOR_GREEN_HEALTH
	pb_fill.border_width_left      = 1
	pb_fill.border_width_right     = 1
	pb_fill.border_color           = COLOR_GOLD
	pb_fill.corner_radius_top_left    = 10
	pb_fill.corner_radius_top_right   = 10
	pb_fill.corner_radius_bottom_left = 10
	pb_fill.corner_radius_bottom_right = 10
	pb_fill.anti_aliasing = true
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill",       "ProgressBar", pb_fill)
	theme.set_font("font",      "ProgressBar", body_font)
	theme.set_font_size("font_size", "ProgressBar", roundi(12 * scale))
	theme.set_color("font_color", "ProgressBar", COLOR_TEXT_LIGHT)

	return theme


static func _load_font(path: String, _size: int) -> Font:
	var res = ResourceLoader.load(path)
	if res is Font:
		return res as Font
	push_warning("PirateThemeBuilder: Could not load font: " + path)
	return null


## Settings > Display > UI Font (SettingsManager.ui_font — 0: Default/Cinzel,
## 1: Pirate/PirataOne, 2: Times New Roman). Default stays `cinzel_font`
## (already loaded by the caller, passed in rather than reloaded here); the
## other two are opt-in for players who want the fully thematic blackletter
## look, or their own OS-installed serif. Times New Roman is never bundled as
## an asset (unlike Cinzel/PirataOne) — SystemFont resolves it from the OS at
## runtime, with plain-serif fallbacks for platforms (most Android devices)
## that don't ship it, so an unavailable choice degrades gracefully instead
## of erroring.
static func _load_body_font(cinzel_font: Font) -> Font:
	match SettingsManager.ui_font:
		1:
			return _load_font(FONT_PIRATA, 14)
		2:
			var sys_font := SystemFont.new()
			sys_font.font_names = PackedStringArray(["Times New Roman", "Liberation Serif", "Noto Serif"])
			return sys_font
		_:
			return cinzel_font


## Sourced 9-slice button art (192x64, see header note) wrapped as a
## StyleBoxTexture. texture_margin defines the corner region Godot keeps
## unstretched; content_margin keeps button label text clear of the bevel.
static func _make_texture_button_stylebox(texture_path: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var tex = ResourceLoader.load(texture_path)
	if tex is Texture2D:
		sb.texture = tex
	else:
		push_warning("PirateThemeBuilder: could not load button texture: " + texture_path)
	sb.texture_margin_left   = 18
	sb.texture_margin_right  = 18
	sb.texture_margin_top    = 18
	sb.texture_margin_bottom = 18
	# content_margin must clear texture_margin's unstretched corner region (the
	# decorative rivet dots), not just sit close to it — a content margin
	# smaller than the texture margin (16 vs. 18, previously) let wide text
	# render underneath the corner art. Never visible with PirataOne's
	# narrower glyphs; Cinzel's wider ones reached it on longer labels (e.g.
	# the rebind screen's "Unbound"), rendering the last letter fused into
	# the corner dot (2026-09-24 font-overflow audit).
	sb.content_margin_left   = 22.0
	sb.content_margin_right  = 22.0
	sb.content_margin_top    = 8.0
	sb.content_margin_bottom = 8.0
	return sb


## Enhanced StyleBoxFlat fallback for panels/bars/one-off dynamic elements
## with no matching sourced texture — larger corner radius, a real soft
## shadow, and anti-aliasing, replacing the old small-radius/hard-shadow box
## (see docs/05_CURRENT_SYSTEMS.md's M15.5 entry).
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
## already have one — M15.5 Requirement 4.2. A recursive sweep called once
## per screen (after that screen's buttons all exist) rather than a manual
## child node added to every individual Button in every .tscn: the same
## manual-per-node approach already produced one real miss in this milestone
## (a Starboard/Port pair where only one side was actually edited — see this
## spec's tasks.md "Checkpoint correction" entry), and a scene with N buttons
## is N chances to repeat it. Idempotent, so it's safe to call on a
## partially-juiced tree.
static func apply_button_juice(root: Node) -> void:
	if is_mobile() and root is BaseButton:
		var target := root as BaseButton
		var min_target := _min_touch_target()
		target.custom_minimum_size = Vector2(
			maxf(target.custom_minimum_size.x, min_target.x),
			maxf(target.custom_minimum_size.y, min_target.y))
	if root is Button:
		var already_juiced := false
		for child in root.get_children():
			if child is ButtonJuice:
				already_juiced = true
				break
		if not already_juiced:
			root.add_child(ButtonJuice.new())
			# One short confirmation pulse per completed UI press. The feedback
			# manager itself is a mobile-only, player-toggleable no-op elsewhere.
			root.pressed.connect(HapticFeedbackManager.tap)
	for child in root.get_children():
		apply_button_juice(child)


## Generates the HSlider grabber (a small filled gold circle with a dark
## outline) as an ImageTexture — no sourced art matches this shape, and a
## StyleBoxFlat can't be used as an "icon" theme slot.
static func _make_slider_grabber_icon(fill: Color, outline: Color) -> ImageTexture:
	var size := 22
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0 - 1.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= radius:
				img.set_pixel(x, y, fill if d <= radius - 2.0 else outline)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


## Generates a rounded on/off pill icon for CheckButton (a mobile-style
## toggle switch) — drawn once and reused across every CheckButton on the
## theme, matching the gold/navy palette instead of Godot's default switch art.
static func _make_toggle_icon(is_on: bool) -> ImageTexture:
	var w := 48
	var h := 26
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track_color := COLOR_GOLD if is_on else Color(0.25, 0.27, 0.32, 1.0)
	var knob_color := COLOR_DARK_NAVY if is_on else COLOR_TEXT_LIGHT
	var radius := h / 2.0
	for y in range(h):
		for x in range(w):
			var p := Vector2(x + 0.5, y + 0.5)
			var in_track := false
			if p.x < radius:
				in_track = p.distance_to(Vector2(radius, radius)) <= radius
			elif p.x > w - radius:
				in_track = p.distance_to(Vector2(w - radius, radius)) <= radius
			else:
				in_track = p.y >= 0.0 and p.y <= h
			img.set_pixel(x, y, track_color if in_track else Color(0, 0, 0, 0))
	var knob_center := Vector2(w - radius, radius) if is_on else Vector2(radius, radius)
	var knob_radius := radius - 3.0
	for y in range(h):
		for x in range(w):
			if Vector2(x + 0.5, y + 0.5).distance_to(knob_center) <= knob_radius:
				img.set_pixel(x, y, knob_color)
	return ImageTexture.create_from_image(img)


## Generates a square checkbox icon (checked = gold fill + dark checkmark,
## unchecked = dark inset box with gold outline) for CheckBox.
static func _make_checkbox_icon(is_checked: bool) -> ImageTexture:
	var size := 26
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bg := COLOR_GOLD if is_checked else COLOR_SHADOW_DARK
	var border := COLOR_GOLD_BRIGHT if is_checked else COLOR_GOLD.darkened(0.2)
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
					img.set_pixel(x, y, COLOR_DARK_NAVY)
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

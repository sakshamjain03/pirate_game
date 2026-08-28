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


static func build() -> Theme:
	var theme := Theme.new()

	var pirata_font  = _load_font(FONT_PIRATA,   14)
	var cinzel_font  = _load_font(FONT_CINZEL,    14)
	var cinzel_bold  = _load_font(FONT_CINZEL_B,  18)

	# --- Default font ---
	theme.default_font      = pirata_font
	theme.default_font_size = 15

	# --- Labels ---
	theme.set_font("font",      "Label", pirata_font)
	theme.set_font_size("font_size", "Label", 15)
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
	theme.set_font_size("font_size", "Button", 15)
	theme.set_color("font_color",          "Button", COLOR_SHADOW_DARK)
	theme.set_color("font_hover_color",    "Button", COLOR_SHADOW_DARK)
	theme.set_color("font_pressed_color",  "Button", COLOR_SHADOW_DARK)
	theme.set_color("font_focus_color",    "Button", COLOR_SHADOW_DARK)
	theme.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.42, 0.8))

	# --- Panels (enhanced flat fallback — no matching texture asset sourced) ---
	var panel_style := _make_panel_stylebox(COLOR_DARK_NAVY, COLOR_GOLD, 2.0, 16.0)
	theme.set_stylebox("panel", "Panel",          panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

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
	theme.set_font("font",      "ProgressBar", pirata_font)
	theme.set_font_size("font_size", "ProgressBar", 12)
	theme.set_color("font_color", "ProgressBar", COLOR_TEXT_LIGHT)

	return theme


static func _load_font(path: String, _size: int) -> Font:
	var res = ResourceLoader.load(path)
	if res is Font:
		return res as Font
	push_warning("PirateThemeBuilder: Could not load font: " + path)
	return null


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
	sb.content_margin_left   = 16.0
	sb.content_margin_right  = 16.0
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

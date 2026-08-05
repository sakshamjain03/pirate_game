class_name PirateThemeBuilder extends RefCounted

## Purpose: Builds and returns the shared Pirate Empire UI Theme programmatically.
## Responsibilities: Loads fonts, sets button/label/panel styles for all pirate UI.
## Usage: call PirateThemeBuilder.build() from any script that needs the theme.

const FONT_PIRATA    := "res://assets/fonts/PirataOne-Regular.ttf"
const FONT_CINZEL    := "res://assets/fonts/Cinzel-Regular.ttf"
const FONT_CINZEL_B  := "res://assets/fonts/Cinzel-Bold.ttf"

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

	# --- Buttons ---
	var btn_normal  := _make_panel_stylebox(COLOR_DARK_PANEL, COLOR_GOLD,        2.0, 6.0)
	var btn_hover   := _make_panel_stylebox(Color(0.1, 0.14, 0.25, 0.95), COLOR_GOLD_BRIGHT, 2.5, 6.0)
	var btn_pressed := _make_panel_stylebox(COLOR_SHADOW_DARK, COLOR_GOLD,       2.0, 6.0)
	var btn_focus   := _make_panel_stylebox(COLOR_DARK_PANEL, COLOR_GOLD_BRIGHT, 3.0, 6.0)

	theme.set_stylebox("normal",  "Button", btn_normal)
	theme.set_stylebox("hover",   "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("focus",   "Button", btn_focus)
	theme.set_font("font",      "Button", cinzel_font)
	theme.set_font_size("font_size", "Button", 15)
	theme.set_color("font_color",          "Button", COLOR_GOLD)
	theme.set_color("font_hover_color",    "Button", COLOR_GOLD_BRIGHT)
	theme.set_color("font_pressed_color",  "Button", COLOR_TEXT_LIGHT)
	theme.set_color("font_focus_color",    "Button", COLOR_GOLD_BRIGHT)

	# --- Panels ---
	var panel_style := _make_panel_stylebox(COLOR_DARK_NAVY, COLOR_GOLD, 1.5, 8.0)
	theme.set_stylebox("panel", "Panel",          panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# --- ProgressBar ---
	var pb_bg  := _make_panel_stylebox(COLOR_SHADOW_DARK, COLOR_GOLD, 1.0, 4.0)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color               = COLOR_GREEN_HEALTH
	pb_fill.border_width_left      = 1
	pb_fill.border_width_right     = 1
	pb_fill.border_color           = COLOR_GOLD
	pb_fill.corner_radius_top_left    = 4
	pb_fill.corner_radius_top_right   = 4
	pb_fill.corner_radius_bottom_left = 4
	pb_fill.corner_radius_bottom_right = 4
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
	s.shadow_color                  = Color(0, 0, 0, 0.4)
	s.shadow_size                   = 4
	s.content_margin_left           = 12.0
	s.content_margin_right          = 12.0
	s.content_margin_top            = 6.0
	s.content_margin_bottom         = 6.0
	return s

class_name UITokens extends RefCounted

## Purpose: single source of truth for M22's type scale, corner radii,
## button press/glow motion timings, and the palette accessor (design.md
## §3-§7). Every constant below is in CANVAS px — the unit GDScript/Theme
## actually consume — not "design px," the unit the v0.3 doc is authored in.
##
## design px vs canvas px (design.md §3): v0.3 is authored at 1x design px
## on an 844x390 phone; this project's canvas base is 1688x780, so
## canvas px = design px x2 everywhere. Each constant's comment gives its
## design-px source value for cross-referencing the v0.3 doc directly.

# --- Type scale (Label/Button font sizes) ---
const FONT_DISPLAY := 88   ## design 44 — headline moments ("Legendary Haul!")
const FONT_TITLE   := 56   ## design 28 — screen/panel titles ("Captain's Roster")
const FONT_HUD_NUM := 36   ## design 18 — HUD numeric readouts ("24,860 / 312")
const FONT_BODY    := 32   ## design 16 — body text; default Label/Button size
const FONT_CHIP    := 24   ## design 12 — small chip labels ("DMG 412")

# --- Corner radii (StyleBox corner_radius_*) ---
const RADIUS_PRIMARY   := 36  ## design 18 — Primary/Brass buttons
const RADIUS_SECONDARY := 28  ## design 14 — WoodRoundButton, smaller elements

# --- Button border / lip (design.md §7, requirements.md Requirement 5) ---
const BORDER_WIDTH   := 6   ## design 3 — dark-ink border around every button
const LIP_IDLE        := 12  ## design 6 — solid shadow slab under an idle button
const LIP_PRESSED      := 4   ## design 2 — remaining lip once pressed
const PRESS_OFFSET_Y  := 8   ## design 4 — button content drop on press

# --- Motion timings (unitless seconds/multipliers — no design/canvas split) ---
const PRESS_IN_SEC     := 0.06
const PRESS_OUT_SEC    := 0.12
const PRESS_DARKEN_TO  := 0.88   ## self_modulate multiplier while pressed
const GLOW_PERIOD_SEC  := 2.2    ## PrimaryGlow sine loop
const GLOW_OPACITY_MIN := 0.45
const GLOW_OPACITY_MAX := 1.0
const GLOW_SCALE_MIN   := 0.96
const GLOW_SCALE_MAX   := 1.07

# --- Display/Title/Button text legibility over busy art (design.md §5) ---
const TEXT_SHADOW_OFFSET := 4   ## design 2
const TEXT_OUTLINE_SIZE  := 4

const PALETTE_PATH := "res://resources/ui/palette_default.tres"

static var _palette_cache: UIPalette = null


## The only place a UI colour lives is read through here (design.md §4).
## Falls back to a fresh UIPalette's own script defaults (identical values)
## with a push_error if the shipped resource is ever missing, rather than
## crashing every screen that reads a colour.
static func palette() -> UIPalette:
	if _palette_cache == null:
		var res := ResourceLoader.load(PALETTE_PATH)
		if res is UIPalette:
			_palette_cache = res
		else:
			push_error("UITokens: could not load %s — falling back to UIPalette defaults" % PALETTE_PATH)
			_palette_cache = UIPalette.new()
	return _palette_cache


## Test-only: forces the next palette() call to reload from disk instead of
## reusing the cached instance — lets a GUT test swap in a different .tres
## (e.g. an M19 colourblind variant) without restarting the engine.
static func clear_palette_cache_for_test() -> void:
	_palette_cache = null

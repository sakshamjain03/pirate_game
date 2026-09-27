class_name UIPalette extends Resource

## Purpose: the ONLY place a UI colour token lives (M22 requirements.md
## Requirement 1.1/1.3, design.md §4). Every screen and PirateThemeBuilder
## reads colours through UITokens.palette(), never a Color(...) literal —
## a future M19 colourblind-safe variant becomes a second .tres loaded from
## the same accessor, not a code change at any call site.
##
## Values are the v0.3 design system's own swatches
## ("claude design outputs/Pirate Empire UI System v0.3.html" — Component
## Sheet > Colour tokens / Rarity gem ramp). Coral is reserved: the single
## Primary button per screen, and Legendary rarity, never anything else.

@export var ocean_deep := Color("#0A2C33")
@export var sunset_teal := Color("#1F6F76")
@export var shallows := Color("#3A9A97")
@export var horizon_gold := Color("#F4C96E")
@export var driftwood := Color("#6D452A")
@export var wood_dark := Color("#2E1A0C")
@export var brass := Color("#C29444")
@export var brass_light := Color("#F7DE98")
@export var parchment := Color("#ECD6A4")
@export var ink := Color("#3A2616")
@export var coral := Color("#F0602A")           # Primary CTA + Legendary ONLY
@export var coral_bloom := Color("#FFD6AE")
@export var brick := Color("#A8392B")           # destructive; never coral

@export var text_on_dark := Color("#F7DFA6")
@export var text_on_parchment := Color("#3A2616")

@export var hp_good := Color("#3FBF8F")
@export var hp_low := Color("#D6453A")

## M22 Phase 6c — the v0.3 doc's finer text/material swatches, lifted
## verbatim from its component CSS (design.md §13). The two text_on_* tokens
## above stay as the broad roles; these are the specific shades v0.3 uses.
@export var title_on_wood := Color("#FFF1D0")      # Germania titles on wood
@export var title_shadow := Color("#1A0E06")       # their 0 2px drop shadow
@export var text_on_dark_soft := Color("#E6D4B0")  # tab/body text on wood
@export var text_muted_dark := Color("#CDB690")    # captions under round buttons
@export var hud_number := Color("#FFF4D6")         # pill + HUD numbers
@export var ink_soft := Color("#8A6A3A")           # sub-labels on parchment
@export var ink_good := Color("#1D7A58")           # "2 / 3", done states on parchment
@export var brass_text := Color("#3A2410")         # brass-button label ink
@export var coral_text := Color("#FFF8EC")         # coral-button label
@export var coral_text_shadow := Color("#7A2A0A")
@export var wood_border := Color("#2E1A0C")
@export var teal_fill_top := Color("#8FE0D6")      # slider/progress teal gradient
@export var teal_fill := Color("#1F8A8C")
@export var teal_fill_bottom := Color("#17616A")
@export var notoriety_accent := Color("#FFB199")
@export var hud_panel := Color(18.0 / 255.0, 10.0 / 255.0, 5.0 / 255.0, 0.7)  # translucent dark HUD card
@export var hud_panel_border := Color("#8A6A3A")
## Modal backdrop: a teal-black wash so the sea still reads through, never
## a flat grey (v0.3: rgba(6,14,18,.62)).
@export var modal_dim := Color(6.0 / 255.0, 14.0 / 255.0, 18.0 / 255.0, 0.62)

## Rarity ramp — "not in the game yet" per v0.3's own component sheet
## (introduced there for captain acquisition/chest-loot quality). This is
## palette scaffolding only; M22 adds no rarity system (requirements.md Out
## of Scope) — a screen only uses rarity_color() where the data already
## carries a rarity (e.g. an existing CaptainData field), never a new one.
@export var rarity := {
	"common": Color("#EDE6D6"),
	"uncommon": Color("#3FBF8F"),
	"rare": Color("#2F6FD6"),
	"epic": Color("#7B3FC4"),
	"legendary": Color("#FF8A3D"),
}


func rarity_color(rarity_key: String) -> Color:
	if rarity.has(rarity_key):
		return rarity[rarity_key]
	push_warning("UIPalette: unknown rarity key '%s', falling back to common" % rarity_key)
	return rarity.get("common", Color.WHITE)

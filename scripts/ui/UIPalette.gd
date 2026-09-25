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

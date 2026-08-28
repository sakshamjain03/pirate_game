class_name PortraitFallback

## Purpose: shared "no portrait art yet" placeholder for any of the 27 named
## characters (20 captains + 7 named cast, docs/12_CHARACTER_BIBLE.md §7)
## until real portrait art lands in M11.
## Responsibilities: given a character's portrait_path and display name,
## render either the real portrait (once one exists on disk) or a themed
## monogram — the character's initial, styled with PirateThemeBuilder's
## palette — so each character still reads as a distinct, deliberate design
## choice rather than one generic icon standing in for all of them.
## Dependencies: PirateThemeBuilder.
## Limitations: M11 shipped portrait_path assets for the 20 captains (flat-color
## icon busts, per Requirement 9.2's stylized-substitute allowance); the 7 named
## cast still fall through to the monogram branch until art is authored for them.

static func apply_to_label(portrait_label: Label, portrait_path: String, display_name: String) -> void:
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		# Real art exists on disk — out of scope until M11 actually ships one;
		# callers using a Label-based portrait slot keep the fallback below
		# until they're upgraded to a TextureRect for real art.
		return
	var initial := "?"
	var trimmed := display_name.strip_edges()
	if not trimmed.is_empty():
		initial = trimmed.substr(0, 1).to_upper()
	portrait_label.text = initial
	portrait_label.add_theme_font_size_override("font_size", 36)
	portrait_label.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_GOLD_BRIGHT)

## M11 — the upgrade apply_to_label()'s own doc comment anticipated: a caller
## with both a TextureRect (for real art) and a Label sibling (for the
## monogram fallback) gets whichever one actually applies, with the other
## hidden — same portrait_path contract, no second decision path.
static func apply_to_texture_rect(texture_rect: TextureRect, fallback_label: Label, portrait_path: String, display_name: String) -> void:
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		texture_rect.texture = load(portrait_path)
		texture_rect.visible = true
		fallback_label.visible = false
		return
	texture_rect.visible = false
	fallback_label.visible = true
	apply_to_label(fallback_label, portrait_path, display_name)

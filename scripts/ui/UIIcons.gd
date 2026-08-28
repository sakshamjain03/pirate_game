class_name UIIcons

## Purpose: single lookup point for every UI icon texture this project uses,
## mirroring PirateThemeBuilder's role as the one place theme values live —
## no scene or script should hardcode an assets/ui_icons/ path directly.
## Source: Kenney "Board Game Icons" (CC0, assets/ui_icons/LICENSE_board-game-icons.txt),
## white/monochrome glyphs meant to be tinted per-resource in code (see
## WorldHUD.gd's existing per-resource font colors, reused as icon modulate).
## Two of the seven keys are thematic substitutes, not literal matches — no
## CC0 pack found had a pirate coin or a rum bottle specifically:
##   "gold" uses the pack's generic circular token/chip icon.
##   "rum" uses the pack's potion-flask icon.
## Both read clearly at the sizes this HUD uses and keep the same "circular
## currency" / "bottled drink" silhouette a player would expect.

const _PATHS := {
	"gold":         "res://assets/ui_icons/icons/gold.png",
	"wood":         "res://assets/ui_icons/icons/wood.png",
	"iron":         "res://assets/ui_icons/icons/iron.png",
	"rum":          "res://assets/ui_icons/icons/rum.png",
	"health":       "res://assets/ui_icons/icons/health.png",
	"notoriety":    "res://assets/ui_icons/icons/notoriety.png",
	"cannon_ready": "res://assets/ui_icons/icons/cannon_ready.png",
}

static func get_icon(key: String) -> Texture2D:
	if not _PATHS.has(key):
		push_warning("UIIcons: no icon registered for key '%s'" % key)
		return null
	var res = ResourceLoader.load(_PATHS[key])
	if res is Texture2D:
		return res as Texture2D
	push_warning("UIIcons: could not load icon texture: " + _PATHS[key])
	return null

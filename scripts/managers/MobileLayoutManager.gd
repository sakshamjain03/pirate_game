extends Node

## Purpose: one source of truth for phone/tablet safe areas and handed layouts.
## Responsibilities: keep touch UI out of display cutouts and gesture areas;
## expose the player's handedness without duplicating UI scenes.

signal layout_changed()

const MIN_TOUCH_TARGET := 48.0
const MIN_TOUCH_GAP := 8.0
const REFERENCE_LANDSCAPE := Vector2(2340, 1080)

func is_mobile() -> bool:
	return not OS.has_feature("pc")

func is_left_handed() -> bool:
	return SettingsManager.mobile_left_handed if is_mobile() else false

func safe_area(viewport: Viewport) -> Rect2:
	var full := viewport.get_visible_rect()
	if not is_mobile():
		return full
	var native_safe := Rect2(DisplayServer.get_display_safe_area())
	# Desktop/headless and a few Android builds return an empty rect. The full
	# viewport is the safe fallback; never collapse the controls to zero.
	if native_safe.size.x <= 0.0 or native_safe.size.y <= 0.0:
		return full
	return native_safe.intersection(full)

func mobile_scale(viewport: Viewport) -> float:
	var safe := safe_area(viewport)
	return minf(safe.size.x / REFERENCE_LANDSCAPE.x, safe.size.y / REFERENCE_LANDSCAPE.y)

func notify_layout_changed() -> void:
	layout_changed.emit()

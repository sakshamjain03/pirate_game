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

## Android's own "smallest width" convention (sw600dp) for phone/tablet
## classification — a tablet has more physical inches per logical pixel at a
## typical viewing distance, so it needs bigger text but not proportionally
## bigger touch targets (a real finger isn't bigger on a bigger screen).
## Memoized: a device's screen class cannot change mid-session.
const TABLET_MIN_SMALLEST_WIDTH_DP := 600.0
static var force_tablet_for_test: bool = false
var _is_tablet_cache: int = -1

func is_tablet() -> bool:
	if force_tablet_for_test:
		return true
	if not is_mobile():
		return false
	if _is_tablet_cache == -1:
		var dpi := DisplayServer.screen_get_dpi()
		var size := DisplayServer.screen_get_size()
		_is_tablet_cache = 0
		# Desktop/headless and some Android builds report an unreliable
		# dpi/size (0). Assume phone in that case — undersizing a real
		# tablet's touch targets is far less harmful than the reverse.
		if dpi > 0 and size.x > 0 and size.y > 0:
			var smallest_width_dp := minf(size.x, size.y) / (dpi / 160.0)
			_is_tablet_cache = 1 if smallest_width_dp >= TABLET_MIN_SMALLEST_WIDTH_DP else 0
	return _is_tablet_cache == 1

func notify_layout_changed() -> void:
	layout_changed.emit()

## Applies a player's saved drag/resize customization (SettingsManager.
## mobile_control_overrides) on top of a HUD element's already-computed
## default position/scale. The override's stored position is a delta in
## reference-scale units (divided by mobile_scale() when it was captured),
## so it stays valid across resolution/orientation changes; the result is
## clamped back onto the viewport so a customization saved on one device
## can never place a control fully off-screen on another. Shared by
## WorldHUD and MobileControls so neither duplicates this lookup/clamp.
func apply_control_override(control_id: String, base_position: Vector2, base_scale: float,
		viewport: Viewport, control_size: Vector2) -> Dictionary:
	var o = SettingsManager.mobile_control_overrides.get(control_id, null)
	if o == null or typeof(o) != TYPE_DICTIONARY:
		return {"position": base_position, "scale": base_scale}
	var scale := mobile_scale(viewport)
	var final_scale: float = base_scale * clampf(float(o.get("scale_mult", 1.0)), 0.75, 1.5)
	var final_position: Vector2 = base_position + Vector2(o.get("position", Vector2.ZERO)) * scale
	var full := viewport.get_visible_rect()
	var rect_size := control_size * final_scale
	final_position.x = clampf(final_position.x, full.position.x, full.end.x - rect_size.x)
	final_position.y = clampf(final_position.y, full.position.y, full.end.y - rect_size.y)
	return {"position": final_position, "scale": final_scale}

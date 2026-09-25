class_name SafeAreaMargin extends MarginContainer

## Purpose: keeps a full-screen UI's interactive content inside BOTH a flat
## 48dp side margin (M22 requirements.md Requirement 3.2) AND the device's
## real display safe area (notches, gesture bars), whichever is larger.
## Wrap a screen's whole content in one of these rather than hand-tuning a
## per-screen edge inset — MobileLayoutManager.safe_area() is the single
## source of truth this reads from; this node does not reimplement it.

## 48 design px = 96 canvas px at M22's base (design px x2 — design.md §3).
const SIDE_MARGIN_CANVAS_PX := 96


func _ready() -> void:
	resized.connect(_update_margins)
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_update_margins)
	_update_margins()


func _update_margins() -> void:
	var vp := get_viewport()
	if not vp:
		return
	var safe := MobileLayoutManager.safe_area(vp)
	var full := vp.get_visible_rect()
	var left := maxf(SIDE_MARGIN_CANVAS_PX, safe.position.x - full.position.x)
	var right := maxf(SIDE_MARGIN_CANVAS_PX, full.end.x - safe.end.x)
	var top := maxf(SIDE_MARGIN_CANVAS_PX, safe.position.y - full.position.y)
	var bottom := maxf(SIDE_MARGIN_CANVAS_PX, full.end.y - safe.end.y)
	add_theme_constant_override("margin_left", roundi(left))
	add_theme_constant_override("margin_right", roundi(right))
	add_theme_constant_override("margin_top", roundi(top))
	add_theme_constant_override("margin_bottom", roundi(bottom))

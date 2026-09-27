class_name UIMotion extends RefCounted

## Purpose: the M22 motion vocabulary (design.md §10, v0.3 motion spec) as
## static helpers — pop-in, shine, number tick, stamp, float-up, typewriter.
## Each returns the Tween it started, bound to the animated node (so it dies
## with it and pauses with it), letting callers chain `.finished` or kill it.
## Responsibilities: timings live in UITokens; nothing here touches gameplay.
## Reduced motion: every helper asks reduced_motion() — the ONE query point
## M19's accessibility toggle wires later (Requirement 9.4) — and, when on,
## jumps straight to the final state with a zero-length Tween instead of
## animating. Nothing here flashes: the only brightness change (shine) is a
## single 400 ms pulse, far below the 3 Hz photosensitivity limit.
## Dependencies: UITokens; SettingsManager (optional `reduce_motion`).

## Test hook — forces reduced_motion() on without a SettingsManager field.
static var force_reduced_motion_for_test := false


## True when motion should collapse to instant state changes. Reads
## `SettingsManager.reduce_motion` only if that property exists (it does not
## yet — M19 adds it), so wiring the toggle later needs no call-site change.
static func reduced_motion() -> bool:
	if force_reduced_motion_for_test:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var settings := tree.root.get_node_or_null("SettingsManager")
	if settings and "reduce_motion" in settings:
		return bool(settings.get("reduce_motion"))
	return false


## Duration `sec`, or 0 under reduced motion.
static func duration(sec: float) -> float:
	return 0.0 if reduced_motion() else sec


## Modal/panel entrance: scale .6 -> 1.06 -> 1 around the centre, fading in.
## The pivot is re-centred every step (see _scale_about_centre): a panel
## shown this frame often gets its real size only after the next container
## sort, and a pivot taken now would pop it from a corner.
static func pop_in(c: Control) -> Tween:
	var t := c.create_tween()
	if reduced_motion():
		c.scale = Vector2.ONE
		c.modulate.a = 1.0
		t.tween_interval(0.0)
		return t
	_scale_about_centre(c, UITokens.POP_IN_FROM)
	c.modulate.a = 0.0
	var d := UITokens.POP_IN_SEC
	t.set_parallel(true)
	t.tween_property(c, "modulate:a", 1.0, d * 0.4)
	t.tween_method(func(k: float) -> void: _scale_about_centre(c, k),
			UITokens.POP_IN_FROM, UITokens.POP_IN_OVERSHOOT, d * 0.6) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_method(func(k: float) -> void: _scale_about_centre(c, k),
			UITokens.POP_IN_OVERSHOOT, 1.0, d * 0.4) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t


static func _scale_about_centre(c: Control, k: float) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * k


## The one modal entrance (M22 6c): the dim fades in (DIM_FADE_SEC) while
## the panel pops (pop_in). Every modal open() calls this, so all screens
## arrive the same way. Returns the panel's pop Tween.
static func modal_enter(panel: Control, dim: CanvasItem = null) -> Tween:
	if dim:
		dim.modulate.a = 0.0 if not reduced_motion() else 1.0
		if not reduced_motion():
			dim.create_tween().tween_property(dim, "modulate:a", 1.0, UITokens.DIM_FADE_SEC)
	return pop_in(panel)


## v0.3 "current tier node glows + flickers": a slow, looping brightness
## breath on `c` (self_modulate 1 -> IDLE_GLOW_PEAK). 1.6 s a cycle, so it
## never approaches the 3 Hz flash limit. Reduced motion: a still glow.
static func idle_glow(c: CanvasItem) -> Tween:
	var t := c.create_tween()
	var peak := Color(UITokens.IDLE_GLOW_PEAK, UITokens.IDLE_GLOW_PEAK, UITokens.IDLE_GLOW_PEAK, 1.0)
	if reduced_motion():
		c.self_modulate = peak
		t.tween_interval(0.0)
		return t
	t.set_loops()
	var half := UITokens.IDLE_GLOW_SEC * 0.5
	t.tween_property(c, "self_modulate", peak, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(c, "self_modulate", Color.WHITE, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t


## v0.3 "selected tile: brass ring + lift" — connect a toggle Button's
## `toggled` to `tile_lift.bind(tile)`. Scales about the centre (a tile in a
## flow container can't be moved, only scaled).
static func tile_lift(pressed: bool, c: Control) -> void:
	if not is_instance_valid(c):
		return
	var target := UITokens.TILE_LIFT_SCALE if pressed else 1.0
	if reduced_motion() or not c.is_inside_tree():
		_scale_about_centre(c, target)
		return
	c.create_tween().tween_method(func(k: float) -> void: _scale_about_centre(c, k),
			c.scale.x, target, UITokens.TILE_LIFT_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fades the newly shown page of a TabContainer in, instead of a hard cut.
static func fade_tabs(tabs: TabContainer) -> void:
	if not tabs.tab_changed.is_connected(_on_tab_changed.bind(tabs)):
		tabs.tab_changed.connect(_on_tab_changed.bind(tabs))


static func _on_tab_changed(_tab: int, tabs: TabContainer) -> void:
	var page := tabs.get_current_tab_control()
	if page == null or reduced_motion():
		return
	page.modulate.a = 0.0
	page.create_tween().tween_property(page, "modulate:a", 1.0, UITokens.TAB_FADE_SEC)


## One brightness pulse (a resource pill whose value just changed). Uses
## self_modulate so a pill's own children (icon, number) stay untouched.
static func shine(c: CanvasItem) -> Tween:
	var t := c.create_tween()
	if reduced_motion():
		c.self_modulate = Color.WHITE
		t.tween_interval(0.0)
		return t
	var half := UITokens.SHINE_SEC * 0.5
	var peak := Color(UITokens.SHINE_PEAK, UITokens.SHINE_PEAK, UITokens.SHINE_PEAK, 1.0)
	t.tween_property(c, "self_modulate", peak, half).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "self_modulate", Color.WHITE, half).set_ease(Tween.EASE_IN)
	return t


## Counts a Label from `from` to `to`. `format` receives one int; pass a
## `formatter` Callable(int) -> String instead for e.g. digit grouping.
static func tick_number(label: Label, from: int, to: int, format := "%d",
		formatter := Callable()) -> Tween:
	var fmt := func(v: int) -> String: return formatter.call(v) if formatter.is_valid() else format % v
	var t := label.create_tween()
	if reduced_motion() or from == to:
		label.text = fmt.call(to)
		t.tween_interval(0.0)
		return t
	t.tween_method(func(v: float) -> void: label.text = fmt.call(roundi(v)),
			float(from), float(to), UITokens.TICK_SEC) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return t


## "24860" -> "24,860" (v0.3 HUD pills).
static func group_digits(n: int) -> String:
	var neg := n < 0
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if neg else "") + digits + out


## "SUNK!"-style stamp: slams in from 2.2x, tilted -8 deg, settling at 1x.
static func stamp(c: Control) -> Tween:
	c.rotation = deg_to_rad(UITokens.STAMP_ROTATION_DEG)
	var t := c.create_tween()
	if reduced_motion():
		_scale_about_centre(c, 1.0)
		c.modulate.a = 1.0
		t.tween_interval(0.0)
		return t
	_scale_about_centre(c, UITokens.STAMP_FROM)
	c.modulate.a = 0.0
	var d := UITokens.STAMP_SEC
	t.set_parallel(true)
	t.tween_property(c, "modulate:a", 1.0, d * 0.25)
	t.tween_method(func(k: float) -> void: _scale_about_centre(c, k),
			UITokens.STAMP_FROM, UITokens.STAMP_UNDERSHOOT, d * 0.5) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_method(func(k: float) -> void: _scale_about_centre(c, k),
			UITokens.STAMP_UNDERSHOOT, 1.0, d * 0.5) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Rises and fades out (loot "+50 gold"). Does not free the node — callers
## chain `.finished.connect(node.queue_free)` if it is one-shot.
static func float_up(c: CanvasItem, distance := float(UITokens.FLOAT_UP_PX)) -> Tween:
	var t := c.create_tween()
	if reduced_motion():
		c.modulate.a = 0.0
		t.tween_interval(0.0)
		return t
	var d := UITokens.FLOAT_UP_SEC
	t.set_parallel(true)
	t.tween_property(c, "position:y", -distance, d).as_relative() \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 0.0, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	return t


## Reveals a Label's current text at `cps` characters per second.
static func typewrite(label: Label, cps := UITokens.TYPEWRITER_CPS) -> Tween:
	var t := label.create_tween()
	var chars := label.get_total_character_count()
	if reduced_motion() or chars == 0 or cps <= 0.0:
		label.visible_ratio = 1.0
		t.tween_interval(0.0)
		return t
	label.visible_ratio = 0.0
	t.tween_property(label, "visible_ratio", 1.0, chars / cps)
	return t

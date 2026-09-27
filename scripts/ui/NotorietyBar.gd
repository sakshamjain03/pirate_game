class_name NotorietyBar extends Control

## Purpose: the v0.3 HUD notoriety meter (screen 04) — a dark rounded track,
## a teal→gold→coral→blood gradient fill, a tick + number at every region
## activation threshold, and a skull marker riding the current value that
## shakes as the next escalation nears ("skull shakes near next threshold").
## Presentation only: WorldHUD feeds it from EmpireManager.notoriety_changed.
## Dependencies: UITokens, UIIcons, UIMotion (reduced motion: no shake, the
## value jumps instead of easing).

## v0.3: linear-gradient(90deg,#3fbf8f 0%,#f2c66d 30%,#f06a3a 60%,#d8322a
## 80%,#7a1010 100%), sized to the whole bar (background-size) so a colour
## always means the same notoriety.
const FILL_STOPS := [[0.0, "#3FBF8F"], [0.3, "#F2C66D"], [0.6, "#F06A3A"], [0.8, "#D8322A"], [1.0, "#7A1010"]]
const TRACK_H := 28.0           ## design 14
const TRACK_BORDER := 4.0       ## design 2, #5a3e22
const SKULL_SIZE := 60.0        ## design 30
## Within this fraction of the gap to the next threshold the skull shakes.
const NEAR_FRACTION := 0.15
const EASE_SEC := 0.6

var max_value := 100.0
var marks: Array[float] = []
var next_threshold := -1.0
var _shown := 0.0
var _target := 0.0
var _gradient := Gradient.new()
var _skull: TextureRect
var _shake: Tween
var _ease: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = maxf(custom_minimum_size.y, SKULL_SIZE + 32.0)
	_gradient.offsets = PackedFloat32Array(FILL_STOPS.map(func(s): return s[0]))
	_gradient.colors = PackedColorArray(FILL_STOPS.map(func(s): return Color(s[1])))
	_skull = TextureRect.new()
	_skull.texture = UIIcons.get_icon("skull")
	_skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skull.size = Vector2(SKULL_SIZE, SKULL_SIZE)
	_skull.pivot_offset = _skull.size * 0.5
	_skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skull)
	resized.connect(_place_skull)


## `value` notoriety now; `thresholds` every region activation point;
## `next_at` the next unreached one (or -1 once all are active).
func set_state(value: float, thresholds: Array[float], next_at: float) -> void:
	marks = thresholds.duplicate()
	marks.sort()
	next_threshold = next_at
	var top: float = marks.back() if not marks.is_empty() else 100.0
	max_value = maxf(top * 1.2, maxf(value, 1.0))
	_target = value
	if _ease:
		_ease.kill()
	if UIMotion.reduced_motion() or not is_inside_tree():
		_set_shown(value)
	else:
		_ease = create_tween()
		_ease.tween_method(_set_shown, _shown, value, EASE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_update_shake()
	queue_redraw()


func _set_shown(v: float) -> void:
	_shown = v
	_place_skull()
	queue_redraw()


func _track_rect() -> Rect2:
	return Rect2(SKULL_SIZE * 0.5, (SKULL_SIZE - TRACK_H) * 0.5, size.x - SKULL_SIZE, TRACK_H)


func _x_for(v: float) -> float:
	var r := _track_rect()
	return r.position.x + r.size.x * clampf(v / maxf(max_value, 0.001), 0.0, 1.0)


func _place_skull() -> void:
	if not _skull:
		return
	_skull.position = Vector2(_x_for(_shown) - SKULL_SIZE * 0.5, 0.0)


func _update_shake() -> void:
	var near := false
	if next_threshold > 0.0:
		var prev := 0.0
		for m in marks:
			if m < next_threshold and m <= _target:
				prev = maxf(prev, m)
		var gap := maxf(next_threshold - prev, 0.001)
		near = (next_threshold - _target) <= gap * NEAR_FRACTION
	if near and not UIMotion.reduced_motion():
		if not _shake or not _shake.is_valid():
			# A small, slow wobble (2 swings a second, far below 3 Hz flashing).
			_shake = _skull.create_tween().set_loops()
			_shake.tween_property(_skull, "rotation", deg_to_rad(9.0), 0.12)
			_shake.tween_property(_skull, "rotation", deg_to_rad(-9.0), 0.24)
			_shake.tween_property(_skull, "rotation", 0.0, 0.12)
			_shake.tween_interval(0.5)
	elif _shake:
		_shake.kill()
		_shake = null
		_skull.rotation = 0.0


func is_shaking() -> bool:
	return _shake != null and _shake.is_valid()


func _draw() -> void:
	var r := _track_rect()
	var radius := TRACK_H * 0.5
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#1A0F07")
	track.border_color = Color("#5A3E22")
	track.set_border_width_all(int(TRACK_BORDER))
	track.set_corner_radius_all(int(radius))
	track.anti_aliasing = true
	draw_style_box(track, r)
	# Fill: per-column quads coloured from the whole-bar gradient.
	var inner := r.grow(-TRACK_BORDER)
	var fill_w := _x_for(_shown) - inner.position.x
	if fill_w > 1.0:
		var cols := 32
		for i in cols:
			var x0 := inner.position.x + fill_w * float(i) / cols
			var x1 := inner.position.x + fill_w * float(i + 1) / cols
			var c0 := _gradient.sample((x0 - inner.position.x) / inner.size.x)
			var c1 := _gradient.sample((x1 - inner.position.x) / inner.size.x)
			draw_polygon(PackedVector2Array([Vector2(x0, inner.position.y), Vector2(x1, inner.position.y),
					Vector2(x1, inner.end.y), Vector2(x0, inner.end.y)]),
					PackedColorArray([c0, c1, c1, c0]))
		# soft top gloss
		draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y * 0.35)), Color(1, 1, 1, 0.18))
	# Threshold ticks + numbers under the bar.
	var font := get_theme_font("font", "ChipLabel")
	var fsize := get_theme_font_size("font_size", "ChipLabel")
	for m in marks:
		var x := _x_for(m)
		var passed := _target >= m
		var col := Color("#F06A3A") if passed else Color("#D9C4A0")
		draw_rect(Rect2(x - 2.0, r.position.y - 10.0, 4.0, r.size.y + 20.0), col)
		if font:
			var txt := str(roundi(m))
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
			draw_string(font, Vector2(x - w * 0.5, r.end.y + 12.0 + fsize), txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

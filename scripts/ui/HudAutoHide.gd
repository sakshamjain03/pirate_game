class_name HudAutoHide extends Node

## Purpose: M22 Phase 6e — keeps the sailing screen quiet. Each registered
## HUD widget is shown only while it is relevant and fades out otherwise:
## the caller (WorldHUD) states *whether* a widget is wanted each tick
## (combat panels only near an enemy, the notoriety meter for a few seconds
## after it changes, …); this node only owns the *how* — a soft fade, never a
## hard pop — and the "Always show" override from SettingsManager.hud_detail.
## Fading uses modulate alpha plus mouse passthrough, not `visible`, so
## container layout (and the layout tests that measure it) never shifts.
## Dependencies: SettingsManager (optional `hud_detail`), UIMotion, UITokens.

const FADE_SEC := 0.25
## SettingsManager.hud_detail values.
const DETAIL_AUTO := 0
const DETAIL_ALWAYS := 1

var _wanted: Dictionary = {}   # Control -> bool
var _tweens: Dictionary = {}   # Control -> Tween
var _wake_until: Dictionary = {}  # Control -> ticks msec


## True when the player chose "Always show" (or there is no setting).
static func always_show() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null("SettingsManager") if tree else null
	if settings and "hud_detail" in settings:
		return int(settings.get("hud_detail")) == DETAIL_ALWAYS
	return false


## Show `c` for at least `seconds` from now, whatever set_wanted says.
func wake(c: Control, seconds: float) -> void:
	if not is_instance_valid(c):
		return
	_wake_until[c] = Time.get_ticks_msec() + int(seconds * 1000.0)
	set_wanted(c, _wanted.get(c, false))


func is_awake(c: Control) -> bool:
	return Time.get_ticks_msec() < int(_wake_until.get(c, 0))


## Call as often as you like; only a change in the effective state fades.
func set_wanted(c: Control, wanted: bool) -> void:
	if not is_instance_valid(c):
		return
	var show := wanted or always_show() or is_awake(c)
	var was = _wanted.get(c, null)
	_wanted[c] = wanted
	var target := 1.0 if show else 0.0
	if was != null and is_equal_approx(c.modulate.a, target):
		return
	if _tweens.has(c) and _tweens[c].is_valid():
		_tweens[c].kill()
	_set_mouse(c, show)
	_set_children_mouse(c, show)
	if UIMotion.reduced_motion() or not c.is_inside_tree():
		c.modulate.a = target
		return
	_tweens[c] = c.create_tween()
	_tweens[c].tween_property(c, "modulate:a", target, FADE_SEC)


func is_shown(c: Control) -> bool:
	return is_instance_valid(c) and (bool(_wanted.get(c, false)) or always_show() or is_awake(c))


func _set_mouse(c: Control, show: bool) -> void:
	if not show:
		if not c.has_meta("_hud_mouse"):
			c.set_meta("_hud_mouse", c.mouse_filter)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif c.has_meta("_hud_mouse"):
		c.mouse_filter = c.get_meta("_hud_mouse")
		c.remove_meta("_hud_mouse")


func _set_children_mouse(c: Control, show: bool) -> void:
	# A faded-out widget must not eat taps meant for the sea / controls
	# under it. Buttons get their original filter back when shown.
	for child in c.find_children("*", "BaseButton", true, false):
		var b := child as BaseButton
		if not show:
			if not b.has_meta("_hud_mouse"):
				b.set_meta("_hud_mouse", b.mouse_filter)
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif b.has_meta("_hud_mouse"):
			b.mouse_filter = b.get_meta("_hud_mouse")
			b.remove_meta("_hud_mouse")

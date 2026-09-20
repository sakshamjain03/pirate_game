extends Control
class_name HudCustomizeOverlay

## Purpose: lets the player drag-reposition and resize the mobile HUD's
## customizable controls (Settings > Customize HUD Layout), persisting the
## result through SettingsManager.mobile_control_overrides (see
## MobileLayoutManager.apply_control_override()). Built entirely in code
## rather than as a companion .tscn, matching this HUD's own existing pattern
## for dynamic runtime UI (see WorldHUD._create_mobile_utility_menu()).
##
## Live preview: every drag step writes straight into the in-memory override
## dict and calls MobileLayoutManager.notify_layout_changed(), which the real
## Movement/Combat/Actions/TopBar/TopRightPanel controls already listen for —
## the player sees the actual HUD move, not a decoupled proxy. Nothing
## reaches disk until "Done" calls SettingsManager.save_settings(); "Cancel"
## restores whatever was in effect before this overlay opened.

const CUSTOMIZABLE_CONTROLS := {
	"movement":        {"label": "Movement",   "path": "MobileControls/Movement"},
	"combat":          {"label": "Combat",     "path": "MobileControls/Combat"},
	"actions":         {"label": "Actions",    "path": "MobileControls/Actions"},
	"top_bar":         {"label": "Speed/Sail", "path": "%TopBar"},
	"top_right_panel": {"label": "Resources",  "path": "%TopRightPanel"},
}
const _RESIZE_GRIP_SIZE := Vector2(32, 32)

var _hud: Node
var _overrides_before_open: Dictionary
var _handles: Dictionary = {}


func open(hud: Node) -> void:
	_hud = hud
	_overrides_before_open = SettingsManager.mobile_control_overrides.duplicate(true)
	name = "HudCustomizeOverlay"
	# Settings is reached mid-game while get_tree().paused == true (same
	# pause-gate fix this HUD already applies to every button that must keep
	# working while paused — see WorldHUD._create_captains_log_button()).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = PirateThemeBuilder.build()
	for id in CUSTOMIZABLE_CONTROLS:
		var info: Dictionary = CUSTOMIZABLE_CONTROLS[id]
		var target: Control = hud.get_node_or_null(info.path)
		if target:
			_handles[id] = _create_handle(id, tr(info.label), target)
	_create_toolbar()


## A cluster's own .size can be a stale authored container rect unrelated to
## its actual visible content (see MobileControls._measured_bottom()'s own
## comment on this) — computing the bounding box of visible children directly
## works uniformly for both that case and a normal Container (TopBar/
## TopRightPanel), whose children's positions already bound it correctly too.
func _visible_content_size(target: Control) -> Vector2:
	var max_w := 0.0
	var max_h := 0.0
	for child in target.get_children():
		if child is Control and child.visible:
			max_w = maxf(max_w, child.position.x + child.size.x)
			max_h = maxf(max_h, child.position.y + child.size.y)
	if max_w <= 0.0 or max_h <= 0.0:
		return target.size
	return Vector2(max_w, max_h)


func _create_handle(control_id: String, label_text: String, target: Control) -> Control:
	var handle := Panel.new()
	handle.name = "Handle_%s" % control_id
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.85, 0.35, 0.28)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.85, 0.35, 0.9)
	handle.add_theme_stylebox_override("panel", style)
	# target's parent is a CanvasLayer (MobileControls, or WorldHUD itself),
	# which has no global_position of its own to add manually — get_global_rect()
	# already walks the full CanvasItem ancestor chain correctly and is what
	# this HUD's own tests already rely on for the same controls. Its .size
	# is NOT scaled by ancestor .scale though (only .position is), which is
	# why size still comes from _visible_content_size() * target.scale below.
	handle.position = target.get_global_rect().position
	handle.size = _visible_content_size(target) * target.scale
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(handle)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.add_child(label)

	var grip := Panel.new()
	grip.name = "ResizeGrip"
	var grip_style := StyleBoxFlat.new()
	grip_style.bg_color = Color(1.0, 0.85, 0.35, 0.95)
	grip.add_theme_stylebox_override("panel", grip_style)
	grip.position = handle.size - _RESIZE_GRIP_SIZE
	grip.size = _RESIZE_GRIP_SIZE
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.process_mode = Node.PROCESS_MODE_ALWAYS
	handle.add_child(grip)

	var move_state := {"dragging": false}
	handle.gui_input.connect(_on_move_input.bind(control_id, handle, move_state))
	var resize_state := {"dragging": false}
	grip.gui_input.connect(_on_resize_input.bind(control_id, handle, grip, resize_state))

	return handle


func _is_primary_press(event: InputEvent) -> Variant:
	## Returns true/false for a press/release of the primary pointer (finger
	## or left mouse button), or null if this event isn't a press/release at
	## all — real touch device and desktop/editor testing both need to work.
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return event.pressed
	return null


func _drag_delta(event: InputEvent) -> Variant:
	if event is InputEventScreenDrag:
		return event.relative
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		return event.relative
	return null


func _on_move_input(event: InputEvent, control_id: String, handle: Control, state: Dictionary) -> void:
	var press = _is_primary_press(event)
	if press != null:
		state.dragging = press
		return
	if not state.dragging:
		return
	var delta = _drag_delta(event)
	if delta == null:
		return
	handle.position += delta
	_update_override_position(control_id, delta)


func _on_resize_input(event: InputEvent, control_id: String, handle: Control, grip: Control, state: Dictionary) -> void:
	var press = _is_primary_press(event)
	if press != null:
		state.dragging = press
		return
	if not state.dragging:
		return
	var delta = _drag_delta(event)
	if delta == null:
		return
	# Grow/shrink by the drag's average axis movement, as a fraction of the
	# handle's current size, so one drag gesture scales both dimensions
	# together rather than distorting the control's aspect ratio.
	var avg_size := (handle.size.x + handle.size.y) * 0.5
	if avg_size <= 0.0:
		return
	var delta_fraction: float = (delta.x + delta.y) * 0.5 / avg_size
	handle.size = (handle.size + delta).max(_RESIZE_GRIP_SIZE * 2.0)
	grip.position = handle.size - _RESIZE_GRIP_SIZE
	_update_override_scale(control_id, delta_fraction)


func _override_entry(control_id: String) -> Dictionary:
	var existing = SettingsManager.mobile_control_overrides.get(control_id, {})
	var entry: Dictionary = existing.duplicate() if typeof(existing) == TYPE_DICTIONARY else {}
	if not entry.has("position"):
		entry["position"] = Vector2.ZERO
	if not entry.has("scale_mult"):
		entry["scale_mult"] = 1.0
	return entry


func _update_override_position(control_id: String, screen_delta: Vector2) -> void:
	var scale := MobileLayoutManager.mobile_scale(get_viewport())
	if scale <= 0.0:
		return
	var entry := _override_entry(control_id)
	entry["position"] = Vector2(entry["position"]) + screen_delta / scale
	SettingsManager.mobile_control_overrides[control_id] = entry
	MobileLayoutManager.notify_layout_changed()


func _update_override_scale(control_id: String, delta_fraction: float) -> void:
	var entry := _override_entry(control_id)
	entry["scale_mult"] = clampf(float(entry["scale_mult"]) + delta_fraction, 0.75, 1.5)
	SettingsManager.mobile_control_overrides[control_id] = entry
	MobileLayoutManager.notify_layout_changed()


func _create_toolbar() -> void:
	var bar := PanelContainer.new()
	bar.name = "Toolbar"
	bar.process_mode = Node.PROCESS_MODE_ALWAYS
	bar.mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)

	var reset_btn := Button.new()
	reset_btn.text = tr("Reset All")
	reset_btn.pressed.connect(_on_reset_pressed)
	row.add_child(reset_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = tr("Cancel")
	cancel_btn.pressed.connect(_on_cancel_pressed)
	row.add_child(cancel_btn)

	var done_btn := Button.new()
	done_btn.text = tr("Done")
	done_btn.pressed.connect(_on_done_pressed)
	row.add_child(done_btn)

	PirateThemeBuilder.apply_button_juice(bar)
	add_child(bar)
	# PRESET_CENTER-style anchoring computes a zero-size rect before the
	# HBoxContainer's children have been laid out (the same "zero-width rect"
	# caveat WorldHUD.announce_event() already documents), so the bar is
	# positioned explicitly once its real size is known instead.
	call_deferred("_center_toolbar", bar)


func _center_toolbar(bar: Control) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	bar.position = Vector2((vp_size.x - bar.size.x) * 0.5, vp_size.y - bar.size.y - 24.0)


func _refresh_handles() -> void:
	for id in _handles:
		var info: Dictionary = CUSTOMIZABLE_CONTROLS[id]
		var target: Control = _hud.get_node_or_null(info.path)
		var handle: Control = _handles[id]
		if not target:
			continue
		handle.position = target.get_global_rect().position
		handle.size = _visible_content_size(target) * target.scale
		var grip: Control = handle.get_node("ResizeGrip")
		grip.position = handle.size - _RESIZE_GRIP_SIZE


func _on_reset_pressed() -> void:
	SettingsManager.mobile_control_overrides = {}
	MobileLayoutManager.notify_layout_changed()
	call_deferred("_refresh_handles")


func _on_cancel_pressed() -> void:
	SettingsManager.mobile_control_overrides = _overrides_before_open
	MobileLayoutManager.notify_layout_changed()
	queue_free()


func _on_done_pressed() -> void:
	SettingsManager.save_settings()
	queue_free()

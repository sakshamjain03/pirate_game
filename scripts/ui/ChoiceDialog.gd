extends CanvasLayer
class_name ChoiceDialog

## M15 — small reusable themed modal for a blocking player choice: Wave 3's cloud-save
## conflict prompt ("keep local" / "keep cloud") and Wave 5's delete-account confirmation.
##
## M22 Phase 4.4 (design.md §6) — on the kit's parchment modal (ParchmentPanel) rather
## than a hand-rolled dark-navy StyleBoxFlat; text reads in ink-on-parchment, not the
## light-on-dark colours the rest of the theme uses. No button is marked Primary by
## default: this dialog is also used for a destructive confirm (delete-account), and a
## glowing coral CTA on a destructive option would be actively the wrong affordance
## (UIPalette's own "coral — Primary CTA + Legendary ONLY" / "brick — destructive; never
## coral" split exists for exactly this reason). A future caller that genuinely wants one
## button marked Primary can still call PirateThemeBuilder.mark_primary() on the returned
## dialog's button_row child directly.
##
## Usage: var choice: int = await ChoiceDialog.new("Title", "Body", ["Keep Local", "Keep Cloud"]).ask(self)
## `index` matches the position in `button_labels`.

signal choice_selected(index: int)

var _panel: PanelContainer

func _init(title_text: String, body_text: String, button_labels: PackedStringArray) -> void:
	layer = 100 # Above WorldHUD and every other CanvasLayer.

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Centred by a full-rect CenterContainer, not set_anchors_and_offsets_preset():
	# that call ran here in _init(), before the panel had any size, so KEEP_SIZE
	# kept a zero size — the panel's top-left sat at screen centre and it grew
	# down-right, rendering off-centre (found by the M22 sweep's first capture).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = PirateThemeBuilder.build()
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ParchmentPanel"
	panel.custom_minimum_size = Vector2(520, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	if not title_text.is_empty():
		var title_label := Label.new()
		title_label.text = title_text
		title_label.theme_type_variation = &"InkTitleLabel"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body_text
	body_label.theme_type_variation = &"InkBodyLabel"
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)

	for i in range(button_labels.size()):
		var btn := Button.new()
		btn.text = button_labels[i]
		btn.custom_minimum_size = PirateThemeBuilder.scaled_button_size(Vector2(200, 80))
		var idx := i
		btn.pressed.connect(func(): _on_choice(idx))
		button_row.add_child(btn)

	center.add_child(panel)
	_panel = panel

## Juiced once in the tree, not in _init(): apply_button_juice() measures each
## button's real themed minimum size for its text-clip buffer, which only
## resolves this dialog's theme once it's actually parented (design.md §11a).
func _ready() -> void:
	PirateThemeBuilder.apply_button_juice(_panel)
	# Pull keyboard/gamepad focus into the modal — otherwise it stays on the
	# screen behind it, where Enter would activate a button the dim overlay
	# is visually covering. The first button, never a later one: callers put
	# the safe choice first (delete-account passes ["Cancel", "Delete Account"]).
	for child in _panel.find_children("*", "Button", true, false):
		(child as Button).grab_focus()
		break

## Adds this dialog under `parent` and returns the chosen index once a button is pressed.
func ask(parent: Node) -> int:
	parent.add_child(self)
	return await choice_selected

func _on_choice(index: int) -> void:
	choice_selected.emit(index)
	queue_free()

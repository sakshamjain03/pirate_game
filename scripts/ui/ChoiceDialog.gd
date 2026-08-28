extends CanvasLayer
class_name ChoiceDialog

## M15 — small reusable themed modal for a blocking player choice: Wave 3's cloud-save
## conflict prompt ("keep local" / "keep cloud") and Wave 5's delete-account confirmation.
## Built entirely in code, matching WorldHUD.announce_event()'s StyleBoxFlat/PirateThemeBuilder
## visual recipe (dark-navy panel, gold border) — this project has no prior confirm/cancel
## dialog to reuse; MainMenu's crash notice is a single-button AcceptDialog, not a themed
## multi-choice one.
##
## Usage: var choice: int = await ChoiceDialog.new("Title", "Body", ["Keep Local", "Keep Cloud"]).ask(self)
## `index` matches the position in `button_labels`.

signal choice_selected(index: int)

func _init(title_text: String, body_text: String, button_labels: PackedStringArray) -> void:
	layer = 100 # Above WorldHUD and every other CanvasLayer.

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.theme = PirateThemeBuilder.build()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.97)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = PirateThemeBuilder.COLOR_GOLD
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(440, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	if not title_text.is_empty():
		var title_label := Label.new()
		title_label.text = title_text
		title_label.add_theme_font_size_override("font_size", 28)
		title_label.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_GOLD_BRIGHT)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body_text
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_color_override("font_color", PirateThemeBuilder.COLOR_TEXT_LIGHT)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)

	for i in range(button_labels.size()):
		var btn := Button.new()
		btn.text = button_labels[i]
		btn.custom_minimum_size = Vector2(44, 44)
		var idx := i
		btn.pressed.connect(func(): _on_choice(idx))
		button_row.add_child(btn)

	add_child(panel)

## Adds this dialog under `parent` and returns the chosen index once a button is pressed.
func ask(parent: Node) -> int:
	parent.add_child(self)
	return await choice_selected

func _on_choice(index: int) -> void:
	choice_selected.emit(index)
	queue_free()

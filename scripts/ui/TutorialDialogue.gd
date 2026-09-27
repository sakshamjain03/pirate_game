class_name TutorialDialogue extends Control

## Purpose: chapter dialogue box (Quartermaster Higgins and the rest of the
## named cast). Renders a `ChapterData`'s `opening_beats`/`closing_beats` queue
## as `CampaignManager` starts/completes chapters.
## Responsibilities: purely reactive — holds no story logic of its own, only
## queue position. Beats are narration (no wait-for-gameplay-condition concept
## in `DialogueBeatData`); a chapter's real pacing comes from its objectives,
## tracked separately by `CaptainsLog`/`WorldHUD`, not by holding this dialogue
## open.
## Dependencies: CampaignManager, PirateThemeBuilder

@onready var name_label: Label = %MentorNameLabel
@onready var text_label: Label = %MentorTextLabel
@onready var portrait_label: Label = %PortraitLabel
## M22 Phase 6.4 — real portrait art (27 Higgins beats author
## portrait_path = Higgins.svg). The Label-only PortraitFallback contract this
## used returns early whenever art EXISTS, leaving the placeholder "?" — so
## the authored portrait had never once been shown. TextureRect + fallback
## Label is the contract PortraitFallback's own doc comment anticipated.
@onready var portrait_art: TextureRect = %PortraitArt
@onready var beat_counter_label: Label = %BeatCounterLabel
@onready var dots: HBoxContainer = %Dots
@onready var next_button: Button = %NextButton
@onready var skip_button: Button = %SkipButton
@onready var portrait_panel: PanelContainer = $Panel/HBox/PortraitPanel

## v0.3 screen 06 toast: parchment card, grows UP from its own content (the
## old fixed 150px box overflowed below the screen once text wrapped). Phone:
## anchored under the top HUD clusters instead — at the bottom it covered the
## steering arrows and the right-thumb action cluster.
const _BOTTOM_GAP := 24.0
const _MOBILE_TOP := 212.0
const _DOT_SIZE := 14.0
## Phone only: the horizontal band (canvas px) between the left and right
## thumb clusters, measured by WorldHUD from MobileControls' real button
## rects; the card fits inside it so it never covers a steering/action
## button in either handedness. Empty = use the scene's centred width.
var _mobile_band := Vector2.ZERO

func set_mobile_band(left: float, right: float) -> void:
	_mobile_band = Vector2(left, right)
	_fit_to_content()

var _queue: Array[DialogueBeatData] = []
var _queue_index: int = -1


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = PirateThemeBuilder.build()
	PirateThemeBuilder.apply_button_juice(self)
	# M9 Requirement 5 — lets EncounterManager gate ambient encounters while
	# this dialogue has focus without a direct node reference, mirroring the
	# "hud" group WorldHUD already registers itself under for the same reason.
	add_to_group("tutorial_dialogue")

	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

	CampaignManager.chapter_started.connect(_on_chapter_started)
	CampaignManager.chapter_completed.connect(_on_chapter_completed)

	name_label.add_theme_font_size_override("font_size", UITokens.FONT_HUD_NUM)
	resized.connect(_fit_to_content)
	# Also refit when the card's own minimum changes: a wrapped Label reports
	# its height for whatever width it has *now*, and on the first layout
	# after show() that can be ~0 — one character per line, a 4,558px-tall
	# card (M22 6b, CombatCaptureHarness). Nothing else re-ran the fit once
	# the label got its real width, so the card stayed tall forever.
	$Panel.minimum_size_changed.connect(_fit_to_content)


## Height follows the wrapped text; position follows the platform (see
## _BOTTOM_GAP/_MOBILE_TOP). Width stays the scene's 840 canvas px.
func _fit_to_content() -> void:
	var panel_node: Control = $Panel
	var h: float = panel_node.get_combined_minimum_size().y
	if PirateThemeBuilder.is_mobile():
		anchor_top = 0.0
		anchor_bottom = 0.0
		if _mobile_band.y > _mobile_band.x:
			anchor_left = 0.0
			anchor_right = 0.0
			offset_left = _mobile_band.x
			offset_right = _mobile_band.y
			h = panel_node.get_combined_minimum_size().y
		offset_top = _MOBILE_TOP
		offset_bottom = _MOBILE_TOP + h
	else:
		anchor_top = 1.0
		anchor_bottom = 1.0
		offset_bottom = -_BOTTOM_GAP
		offset_top = -_BOTTOM_GAP - h


func is_blocking() -> bool:
	return visible


func _on_chapter_started(chapter: ChapterData) -> void:
	_show_queue(chapter.opening_beats)


func _on_chapter_completed(chapter: ChapterData) -> void:
	_show_queue(chapter.closing_beats)


func _show_queue(beats: Array[DialogueBeatData]) -> void:
	if beats.is_empty():
		return
	_queue = beats
	_queue_index = 0
	_render_current_beat()
	show()


func _render_current_beat() -> void:
	if _queue_index < 0 or _queue_index >= _queue.size():
		hide()
		return
	var beat := _queue[_queue_index]
	name_label.text = beat.speaker_name if not beat.speaker_name.is_empty() else beat.speaker_id
	text_label.text = beat.text
	PortraitFallback.apply_to_texture_rect(portrait_art, portrait_label, beat.portrait_path, name_label.text)
	beat_counter_label.text = tr("%d of %d") % [_queue_index + 1, _queue.size()]
	_render_dots()
	_fit_to_content.call_deferred()


func _render_dots() -> void:
	for child in dots.get_children():
		child.queue_free()
	var ink := UITokens.palette().ink
	for i in _queue.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(_DOT_SIZE, _DOT_SIZE)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(_DOT_SIZE))
		style.set_border_width_all(2)
		style.border_color = ink
		style.bg_color = ink if i <= _queue_index else Color(ink.r, ink.g, ink.b, 0.0)
		dot.add_theme_stylebox_override("panel", style)
		dots.add_child(dot)


func _on_next_pressed() -> void:
	_queue_index += 1
	if _queue_index >= _queue.size():
		hide()
	else:
		_render_current_beat()


func _on_skip_pressed() -> void:
	## Dismisses the current dialogue queue only — there is no "skip the whole
	## campaign" concept anymore; objectives are real gameplay, not a step list.
	_queue_index = _queue.size()
	hide()

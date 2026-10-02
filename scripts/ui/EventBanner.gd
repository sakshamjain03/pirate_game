## M29 D.1 — Non-modal event announcement banner.
## Purpose: Displays a single world event as a transient banner (icon + text), then
## auto-dismisses. Emits dismissed when it's gone so the queue can show the next one.

extends PanelContainer

signal dismissed

var _icon: TextureRect
var _label: Label

func _ready() -> void:
	# The scene structure is set up in EventBanner.tscn
	_icon = %EventIcon
	_label = %EventTitle

func set_announcement(title_text: String, icon_texture: Texture2D = null) -> void:
	## Set the banner's content: title (passed through tr() already) and optional icon.
	if _label:
		_label.text = title_text
	if _icon:
		if icon_texture:
			_icon.texture = icon_texture
		else:
			_icon.hide()

func show_and_dismiss(duration: float = 3.0) -> void:
	## Fade in, hold, fade out, then dismiss.
	modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duration)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		dismissed.emit()
		queue_free()
	)

class_name RibbonStack extends VBoxContainer

## Purpose: the short-lived "you did something good" ribbons of the M30 feedback
## pack (W1-2.3, task 1.11) — Rake!, Sunk!, Perfect Brace! — stacked in one
## container so their spacing is layout, not hand-placed offsets.
## Responsibilities: own one Label child per live ribbon, retire each after
##   `config.ribbon_lifetime`, never hold more than `config.max_ribbons` (a new
##   ribbon frees the oldest), and fold a repeat of a live ribbon into an "xN"
##   count instead of taking a second slot (a raking broadside is several
##   cannonballs, not several achievements).
## Dependencies: CombatFeedbackData, UIMotion (pop-in, which honours reduced
##   motion). Fed by CombatFeedback; instanced in WorldHUD.tscn.

const CONFIG_PATH := "res://resources/ui/CombatFeedback.tres"

@export var config: CombatFeedbackData

## key -> {"label": Label, "count": int, "remaining": float}, oldest first.
var _live: Array = []


func _ready() -> void:
	if not config:
		config = load(CONFIG_PATH) as CombatFeedbackData
	if not config:
		push_error("RibbonStack: missing %s" % CONFIG_PATH)
		config = CombatFeedbackData.new()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN


func _process(delta: float) -> void:
	tick(delta)


## Adds (or refreshes) the ribbon `key`, showing `text`. Returns its Label.
func add_ribbon(key: String, text: String = "") -> Label:
	if text.is_empty():
		text = key
	for entry in _live:
		if entry["key"] == key and is_instance_valid(entry["label"]):
			entry["count"] = int(entry["count"]) + 1
			entry["remaining"] = config.ribbon_lifetime
			entry["label"].text = "%s x%d" % [entry["text"], entry["count"]]
			return entry["label"]
	while _live.size() >= maxi(config.max_ribbons, 1):
		_retire(0)
	var label := Label.new()
	label.name = "Ribbon"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", PirateThemeBuilder.scaled_font_size(30))
	label.add_theme_color_override("font_color", config.rake_color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	UIMotion.pop_in(label)
	_live.append({"key": key, "text": text, "label": label, "count": 1,
		"remaining": config.ribbon_lifetime})
	return label


func tick(delta: float) -> void:
	var i := 0
	while i < _live.size():
		var entry: Dictionary = _live[i]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0 or not is_instance_valid(entry["label"]):
			_retire(i)
		else:
			i += 1


func clear() -> void:
	while not _live.is_empty():
		_retire(0)


func get_ribbon_count() -> int:
	return _live.size()


func get_ribbon_labels() -> Array:
	var out: Array = []
	for entry in _live:
		if is_instance_valid(entry["label"]):
			out.append(entry["label"])
	return out


func _retire(index: int) -> void:
	var entry: Dictionary = _live[index]
	_live.remove_at(index)
	var label = entry["label"]
	if is_instance_valid(label):
		# Freed now, not queued: the layout and the child count drop this frame
		# and no detached Label lingers as an orphan until the frame ends.
		label.free()

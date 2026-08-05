extends Label3D

## Purpose: Floating text used for damage numbers.
## Responsibilities: Displays a number, floats up, fades out, and destroys itself.
## Dependencies: None

@export var damage_amount: float = 0
@export var float_duration: float = 1.0
@export var float_distance: float = 3.0

func _ready() -> void:
	# Format text
	text = "-" + str(int(damage_amount))
	
	# Initial setup: Billboard and red color
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	modulate = Color(1.0, 0.2, 0.2, 1.0) # Red
	outline_modulate = Color(0.0, 0.0, 0.0, 1.0) # Black outline
	outline_size = 4
	font_size = 64
	
	# Start tween animation
	var tween = create_tween().set_parallel(true)
	
	# Float up
	var target_pos = global_position + Vector3(0, float_distance, 0)
	tween.tween_property(self, "global_position", target_pos, float_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Fade out alpha
	tween.tween_property(self, "modulate:a", 0.0, float_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# Delete after duration
	tween.chain().tween_callback(queue_free)

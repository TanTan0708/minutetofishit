class_name FloatingText
extends Label

## Bouncing number / text that floats up and fades out.

func pop_off(at: Vector2, message: String, color: Color, font_size: int = 40) -> void:
	text = message
	add_theme_color_override("font_color", color)
	add_theme_font_size_override("font_size", font_size)
	pivot_offset = size * 0.5
	global_position = at - size * 0.5
	scale = Vector2(0.4, 0.4)
	modulate.a = 1.0

	var t: Tween = create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "global_position:y", global_position.y - 82.0, 1.05) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)

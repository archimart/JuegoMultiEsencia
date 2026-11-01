extends Node2D

func setup(amount: int, color: Color = Color.WHITE) -> void:
	var lbl: Label = $Label
	lbl.text = str(amount)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)
	var target_y := position.y - 20.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", target_y, 0.75).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.3)
	await tw.finished
	queue_free()

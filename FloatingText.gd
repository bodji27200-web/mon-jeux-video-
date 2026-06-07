extends Label

# Texte de combat flottant : monte légèrement puis disparaît en fondu.
# Réglé AVANT add_child : text, color_value, font_size_value, duration.

var color_value: Color = Color.WHITE
var font_size_value: int = 20
var duration: float = 1.0


func _ready() -> void:
	z_index = 100
	add_theme_color_override("font_color", color_value)
	add_theme_font_size_override("font_size", font_size_value)
	# Flotte vers le haut + disparition progressive, puis se supprime.
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector2(0.0, -38.0), duration)
	tw.parallel().tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(queue_free)

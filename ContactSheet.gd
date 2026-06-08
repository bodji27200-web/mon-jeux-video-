extends Node2D

# Dev only : planche-contact des 21 lignes du pack Eldiran, frame idle (col 0),
# agrandie + numéro de ligne, pour mapper chaque ligne à une classe.

const SHEET := preload("res://assets/rpgchars_tmp.png")
const FS := 32

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()
	await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://shot.png")
	get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 832, 704), Color(0.1, 0.1, 0.13))
	var font := ThemeDB.fallback_font
	var rows := SHEET.get_height() / FS
	var cols_per_line := 11
	for r in rows:
		var col := r % cols_per_line
		var line := r / cols_per_line
		var x := 14.0 + col * 72.0
		var y := 60.0 + line * 150.0
		# Frame idle (col 0) agrandie x2 + numéro de ligne
		draw_texture_rect_region(SHEET, Rect2(x, y, 64, 64), Rect2(0, r * FS, FS, FS))
		draw_string(font, Vector2(x + 22, y + 86), str(r), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 0.4))

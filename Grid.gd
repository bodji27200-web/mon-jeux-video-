extends Node2D

# Étape 1 : affichage de la grille tactique.
# Dessine une grille de cases via _draw(). Rien d'autre pour l'instant
# (pas d'unités ni de déplacement : ce sont les étapes suivantes).

# --- Configuration de la grille ---
const COLUMNS := 12
const ROWS := 10
const CELL_SIZE := 64

# --- Couleurs (ambiance dark fantasy) ---
const COLOR_CELL := Color(0.13, 0.13, 0.18)   # remplissage des cases
const COLOR_LINE := Color(0.30, 0.30, 0.40)   # lignes du quadrillage


func _draw() -> void:
	var grid_width := COLUMNS * CELL_SIZE
	var grid_height := ROWS * CELL_SIZE

	# Remplissage de chaque case
	for col in COLUMNS:
		for row in ROWS:
			var rect := Rect2(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			draw_rect(rect, COLOR_CELL)

	# Lignes verticales
	for col in COLUMNS + 1:
		var x := col * CELL_SIZE
		draw_line(Vector2(x, 0), Vector2(x, grid_height), COLOR_LINE, 1.0)

	# Lignes horizontales
	for row in ROWS + 1:
		var y := row * CELL_SIZE
		draw_line(Vector2(0, y), Vector2(grid_width, y), COLOR_LINE, 1.0)

extends Node2D

# Une unité du jeu (pion). Pour l'instant : un simple cercle coloré, statique.
# Le déplacement viendra à l'étape suivante.
# Données configurables depuis l'éditeur (approche data-driven).

@export var unit_name: String = "Unité"
@export var color: Color = Color.WHITE
@export var grid_position: Vector2i = Vector2i.ZERO

const RADIUS := 24.0

var _active := false  # true quand c'est le tour de cette unité


func _ready() -> void:
	add_to_group("units")
	# Se place au centre de sa case (la grille est le parent).
	var grid := get_parent()
	if grid and grid.has_method("cell_to_local"):
		position = grid.cell_to_local(grid_position)
	queue_redraw()


func set_active(active: bool) -> void:
	_active = active
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, color)
	# Anneau jaune autour de l'unité dont c'est le tour.
	if _active:
		draw_arc(Vector2.ZERO, RADIUS + 4.0, 0.0, TAU, 32, Color(1, 1, 0.4), 3.0)

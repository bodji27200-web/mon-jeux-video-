extends Node2D

# Grille tactique : affichage + utilitaires de coordonnées.

const COLUMNS := 12
const ROWS := 10
const CELL_SIZE := 64

const COLOR_CELL := Color(0.13, 0.13, 0.18)
const COLOR_LINE := Color(0.30, 0.30, 0.40)
const COLOR_MOVE := Color(0.30, 0.55, 0.95, 0.35)    # cases de déplacement
const COLOR_TARGET := Color(0.90, 0.25, 0.25, 0.40)  # cibles attaquables
const COLOR_HEAL := Color(0.30, 0.85, 0.40, 0.40)    # alliés soignables
const COLOR_SKILL := Color(0.75, 0.35, 0.95, 0.45)   # cibles de compétence

var move_cells: Array = []
var target_cells: Array = []
var heal_cells: Array = []
var skill_cells: Array = []


func _draw() -> void:
	var w := COLUMNS * CELL_SIZE
	var h := ROWS * CELL_SIZE
	for col in COLUMNS:
		for row in ROWS:
			draw_rect(_cell_rect(Vector2i(col, row)), COLOR_CELL)
	for cell in move_cells:
		draw_rect(_cell_rect(cell), COLOR_MOVE)
	for cell in target_cells:
		draw_rect(_cell_rect(cell), COLOR_TARGET)
	for cell in heal_cells:
		draw_rect(_cell_rect(cell), COLOR_HEAL)
	for cell in skill_cells:
		draw_rect(_cell_rect(cell), COLOR_SKILL)
	for col in COLUMNS + 1:
		draw_line(Vector2(col * CELL_SIZE, 0), Vector2(col * CELL_SIZE, h), COLOR_LINE, 1.0)
	for row in ROWS + 1:
		draw_line(Vector2(0, row * CELL_SIZE), Vector2(w, row * CELL_SIZE), COLOR_LINE, 1.0)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * CELL_SIZE, cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)


# Centre d'une case, en coordonnées locales à la grille (pour placer les unités).
func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2.0, cell.y * CELL_SIZE + CELL_SIZE / 2.0)


func local_to_cell(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / CELL_SIZE), floori(local_pos.y / CELL_SIZE))


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


# BFS 4-directionnel : cases atteignables sans traverser une case occupée.
func get_reachable_cells(start: Vector2i, move_range: int, occupied: Dictionary) -> Array:
	var result: Array = []
	var visited := {start: 0}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var dist: int = visited[current]
		if dist >= move_range:
			continue
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = current + dir
			if not is_inside(nxt) or visited.has(nxt) or occupied.has(nxt):
				continue
			visited[nxt] = dist + 1
			result.append(nxt)
			queue.append(nxt)
	return result

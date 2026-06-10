extends Node2D

# Grille tactique : affichage + utilitaires de coordonnées.

const COLUMNS := 12
const ROWS := 10
const CELL_SIZE := 64  # conservé pour les rayons d'effets visuels (SkillFX)

# --- Projection isométrique « diorama » (type Sword of Convallaria) ---
# Une case = un BLOC : losange-sommet (TILE_W × TILE_H, ratio 2:1) + faces
# latérales visibles sur les bords de la carte et les dénivelés, comme une
# maquette flottante. Le gameplay reste sur des coordonnées de grille entières ;
# seule la conversion case <-> écran change (cell_to_local / local_to_cell).
const TILE_W := 72.0
const TILE_H := 36.0
# Décalage d'origine : pousse la grille pour que tout reste en coordonnées >= 0
# (le nœud Grid est lui-même à (60,130) dans Main.tscn : bord droit = 60+320+432 = 812 ≤ 832).
const ISO_ORIGIN := Vector2(320.0, 40.0)
# Relief : remontée visuelle (px) par niveau de hauteur (plateau surélevé).
const HEIGHT_RISE := 18.0
# Épaisseur du socle du diorama (faces sous les bords de la carte).
const EDGE_DEPTH := 26.0

# Damier de sol (deux tons proches, comme SoC) + faces latérales en terre/pierre.
const COLOR_TOP_A := Color(0.190, 0.190, 0.265)
const COLOR_TOP_B := Color(0.150, 0.150, 0.215)
const COLOR_WALL_L := Color(0.105, 0.095, 0.135)     # face avant-gauche (ombre)
const COLOR_WALL_R := Color(0.150, 0.135, 0.185)     # face avant-droite
const COLOR_LINE := Color(0.42, 0.44, 0.56)          # contour des cases (plus lisible)
const COLOR_MOVE := Color(0.30, 0.55, 0.95, 0.35)    # cases de déplacement
const COLOR_TARGET := Color(0.90, 0.25, 0.25, 0.40)  # cibles attaquables
const COLOR_HEAL := Color(0.30, 0.85, 0.40, 0.40)    # alliés soignables
const COLOR_SKILL := Color(0.75, 0.35, 0.95, 0.45)   # cibles de compétence
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 0.85)      # case survolée par la souris

var move_cells: Array = []
var target_cells: Array = []
var heal_cells: Array = []
var skill_cells: Array = []
var hover_cell := Vector2i(-1, -1)  # case sous la souris (surbrillance), -1 = aucune
var terrain: Dictionary = {}  # Vector2i -> String (clé dans GameData.TERRAIN)
var heights: Dictionary = {}  # Vector2i -> int (niveau de hauteur, 0 = sol)


func _draw() -> void:
	# Sol : un BLOC par case (du fond vers l'avant pour un recouvrement propre) :
	# faces latérales (bords de carte + dénivelés) puis sommet en damier.
	for row in ROWS:
		for col in COLUMNS:
			var cell := Vector2i(col, row)
			_draw_block_sides(cell)
			_fill_cell(cell, _top_color(cell))
			_outline_cell(cell, COLOR_LINE, 1.0)
	# Terrain tactique : losange teinté (zone d'effet) + décor vectoriel debout.
	for cell in terrain:
		var tid: String = terrain[cell]
		if not GameData.TERRAIN.has(tid):
			continue
		_fill_cell(cell, GameData.TERRAIN[tid].color)
		_draw_terrain_feature(cell, tid)
	# Highlights navigation (remplissage + contour net pour bien lire les cases).
	for cell in move_cells:
		_fill_cell(cell, COLOR_MOVE)
		_outline_cell(cell, Color(0.45, 0.70, 1.0, 0.9), 2.0)
	for cell in target_cells:
		_fill_cell(cell, COLOR_TARGET)
		_outline_cell(cell, Color(1.0, 0.40, 0.40, 0.9), 2.0)
	for cell in heal_cells:
		_fill_cell(cell, COLOR_HEAL)
		_outline_cell(cell, Color(0.40, 0.95, 0.55, 0.9), 2.0)
	for cell in skill_cells:
		_fill_cell(cell, COLOR_SKILL)
		_outline_cell(cell, Color(0.85, 0.50, 1.0, 0.95), 2.0)
	# Surbrillance de la case survolée (par-dessus tout, pour viser facilement).
	if is_inside(hover_cell):
		_fill_cell(hover_cell, Color(1.0, 1.0, 1.0, 0.10))
		_outline_cell(hover_cell, COLOR_HOVER, 2.0)


# Les 4 sommets du losange d'une case (haut, droite, bas, gauche), au sommet du
# plateau si la case est en hauteur (les clics et highlights suivent ce sommet).
func _diamond_points(cell: Vector2i) -> PackedVector2Array:
	var c := cell_to_local_raised(cell)
	return PackedVector2Array([
		c + Vector2(0.0, -TILE_H / 2.0),
		c + Vector2(TILE_W / 2.0, 0.0),
		c + Vector2(0.0, TILE_H / 2.0),
		c + Vector2(-TILE_W / 2.0, 0.0)])


# Damier du sol : deux tons alternés (lecture des cases sans grosse grille).
# Les sommets des plateaux sont éclaircis : la hauteur se repère d'un coup d'œil.
func _top_color(cell: Vector2i) -> Color:
	var c := COLOR_TOP_A if (cell.x + cell.y) % 2 == 0 else COLOR_TOP_B
	if height_at(cell) > 0:
		c = c.lightened(0.16)
	return c


# Faces latérales du bloc d'une case (style diorama) : une face est visible
# quand le voisin de devant (avant-gauche = row+1, avant-droite = col+1) est
# hors carte (socle du diorama) ou plus bas (dénivelé d'un plateau).
func _draw_block_sides(cell: Vector2i) -> void:
	var top := cell_to_local_raised(cell)
	var L := top + Vector2(-TILE_W / 2.0, 0.0)
	var B := top + Vector2(0.0, TILE_H / 2.0)
	var R := top + Vector2(TILE_W / 2.0, 0.0)
	var h := height_at(cell)
	var d_left := _wall_depth(h, cell + Vector2i(0, 1))   # face avant-gauche
	if d_left > 0.0:
		var v := Vector2(0.0, d_left)
		draw_colored_polygon(PackedVector2Array([L, B, B + v, L + v]), COLOR_WALL_L)
		draw_line(L + v, B + v, Color(0.0, 0.0, 0.0, 0.55), 1.5)
	var d_right := _wall_depth(h, cell + Vector2i(1, 0))  # face avant-droite
	if d_right > 0.0:
		var v := Vector2(0.0, d_right)
		draw_colored_polygon(PackedVector2Array([B, R, R + v, B + v]), COLOR_WALL_R)
		draw_line(B + v, R + v, Color(0.0, 0.0, 0.0, 0.55), 1.5)
	if d_left > 0.0 or d_right > 0.0:
		# Arête verticale avant (jonction des deux faces), pour marquer le bloc.
		draw_line(B, B + Vector2(0.0, max(d_left, d_right)), Color(0.0, 0.0, 0.0, 0.40), 1.0)


# Profondeur (px) de la face vers le voisin donné : socle complet hors carte,
# dénivelé si le voisin est plus bas, rien sinon (face cachée).
func _wall_depth(h: int, neighbor: Vector2i) -> float:
	if not is_inside(neighbor):
		return h * HEIGHT_RISE + EDGE_DEPTH
	return max(0.0, float(h - height_at(neighbor)) * HEIGHT_RISE)


func _fill_cell(cell: Vector2i, color: Color) -> void:
	draw_colored_polygon(_diamond_points(cell), color)


func _outline_cell(cell: Vector2i, color: Color, width: float) -> void:
	var pts := _diamond_points(cell)
	pts.append(pts[0])
	draw_polyline(pts, color, width)


# --- Décors de terrain (100 % vectoriel, aucun asset) ---
# Dessine un obstacle reconnaissable au centre de la case selon son type.
func _draw_terrain_feature(cell: Vector2i, tid: String) -> void:
	var base := cell_to_local_raised(cell)  # centre de la case (sommet du plateau)
	# Décor "planté" sur la case : ombre de contact au sol + élément remonté pour
	# qu'il tienne au centre du losange (cohérent avec les unités).
	match tid:
		"foret":
			_fill_ellipse(base + Vector2(0, 6), 15.0, 6.0, Color(0, 0, 0, 0.22))
			_draw_tree(base + Vector2(0, -7))
		"ruines":
			_fill_ellipse(base + Vector2(0, 6), 16.0, 7.0, Color(0, 0, 0, 0.22))
			_draw_ruins(base + Vector2(0, -6))
		"marecage":
			_draw_swamp(base + Vector2(0, -2))


# Sapin : tronc + trois étages de feuillage (relief clair/foncé).
func _draw_tree(c: Vector2) -> void:
	var trunk := Color(0.36, 0.24, 0.12)
	draw_rect(Rect2(c.x - 3, c.y + 7, 6, 11), trunk)
	var dark := Color(0.10, 0.40, 0.16)
	var light := Color(0.20, 0.58, 0.24)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 16, c.y + 10), Vector2(c.x + 16, c.y + 10), Vector2(c.x, c.y - 4)]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 13, c.y + 2), Vector2(c.x + 13, c.y + 2), Vector2(c.x, c.y - 13)]), light)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 9, c.y - 6), Vector2(c.x + 9, c.y - 6), Vector2(c.x, c.y - 22)]), dark)


# Ruines : socle + colonne brisée (sommet irrégulier) + blocs épars.
func _draw_ruins(c: Vector2) -> void:
	var stone := Color(0.60, 0.58, 0.52)
	var stone_d := Color(0.38, 0.36, 0.32)
	draw_rect(Rect2(c.x - 14, c.y + 9, 28, 8), stone_d)
	var col := PackedVector2Array([
		Vector2(c.x - 8, c.y + 9), Vector2(c.x - 8, c.y - 14),
		Vector2(c.x - 2, c.y - 18), Vector2(c.x + 3, c.y - 10),
		Vector2(c.x + 8, c.y - 16), Vector2(c.x + 8, c.y + 9)])
	draw_colored_polygon(col, stone)
	draw_polyline(col, stone_d, 1.5)
	draw_rect(Rect2(c.x + 8, c.y + 2, 9, 7), stone)
	draw_rect(Rect2(c.x - 18, c.y + 1, 8, 8), stone)


# Marécage : flaque (ellipse) + reflet + bulles + roseaux.
func _draw_swamp(c: Vector2) -> void:
	_fill_ellipse(c + Vector2(0, 7), 20, 11, Color(0.16, 0.30, 0.13))
	_fill_ellipse(c + Vector2(-4, 5), 9, 4, Color(0.30, 0.46, 0.20))
	draw_circle(c + Vector2(6, 7), 2.6, Color(0.55, 0.70, 0.40, 0.85))
	draw_circle(c + Vector2(-8, 10), 1.8, Color(0.55, 0.70, 0.40, 0.7))
	draw_line(c + Vector2(11, 9), c + Vector2(13, -9), Color(0.52, 0.56, 0.20), 2.0)
	draw_line(c + Vector2(14, 10), c + Vector2(16, -3), Color(0.46, 0.50, 0.18), 2.0)


# Ellipse pleine (pas de primitive native).
func _fill_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


# Centre du losange d'une case, en coordonnées locales à la grille (projection iso).
func cell_to_local(cell: Vector2i) -> Vector2:
	return ISO_ORIGIN + Vector2(
		(cell.x - cell.y) * (TILE_W / 2.0),
		(cell.x + cell.y) * (TILE_H / 2.0))


# Centre du SOMMET de la case (remonté selon sa hauteur). Utilisé pour poser les
# unités, les décors et les highlights de façon cohérente avec le plateau.
func cell_to_local_raised(cell: Vector2i) -> Vector2:
	return cell_to_local(cell) - Vector2(0.0, height_at(cell) * HEIGHT_RISE)


func height_at(cell: Vector2i) -> int:
	return int(heights.get(cell, 0))


# Inverse de la projection : retrouve la case sous un point local (clic souris).
# Tient compte du relief : on teste d'abord les cases en hauteur (dont le sommet
# est visuellement décalé), puis on retombe sur la projection plate.
func local_to_cell(local_pos: Vector2) -> Vector2i:
	# Cases surélevées : on prend la frontmost (la plus en avant / la plus haute)
	# dont le losange-sommet contient le point.
	var best := Vector2i(-99, -99)
	var best_rank := -1
	for cell in heights:
		if int(heights[cell]) <= 0 or not is_inside(cell):
			continue
		if _point_in_top(local_pos, cell):
			var rank: int = int(heights[cell]) * 1000 + cell.x + cell.y
			if rank > best_rank:
				best_rank = rank
				best = cell
	if best_rank >= 0:
		return best
	# Sinon : projection plate classique.
	var p := local_pos - ISO_ORIGIN
	var fx := p.x / (TILE_W / 2.0)   # = (cell.x - cell.y)
	var fy := p.y / (TILE_H / 2.0)   # = (cell.x + cell.y)
	return Vector2i(roundi((fx + fy) / 2.0), roundi((fy - fx) / 2.0))


# Le point est-il dans le losange-sommet (relevé) de la case ?
func _point_in_top(p: Vector2, cell: Vector2i) -> bool:
	var c := cell_to_local_raised(cell)
	var d := p - c
	return abs(d.x) / (TILE_W / 2.0) + abs(d.y) / (TILE_H / 2.0) <= 1.0


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


# Terrain à une case donnée (dict GameData.TERRAIN ou {} si aucun).
func terrain_at(cell: Vector2i) -> Dictionary:
	var tid: String = terrain.get(cell, "")
	if tid == "":
		return {}
	return GameData.TERRAIN.get(tid, {})


func terrain_move_penalty_at(cell: Vector2i) -> int:
	return int(terrain_at(cell).get("move_penalty", 0))


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

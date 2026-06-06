class_name TacticalAI

# Cerveau de l'IA. Décide, pour une unité, où se déplacer et qui cibler.
# Règles claires (pas de triche) :
#  - finir les cibles faibles ;
#  - se positionner selon le comportement (mêlée = avancer, kite = frapper de
#    loin, heal = soigner l'allié le plus faible en restant à l'abri).
# Affiné à l'étape 10 (difficultés, protection, etc.).


static func decide(unit: Node, grid: Node, units: Array) -> Dictionary:
	var enemies: Array = []
	var allies: Array = []
	for u in units:
		if not u.is_alive():
			continue
		if u.team == unit.team:
			if u != unit:
				allies.append(u)
		else:
			enemies.append(u)

	var is_healer := unit.data.behavior == "heal"

	# Liste des cibles potentielles selon le rôle.
	var pool: Array = []
	if is_healer:
		for a in allies:
			if a.hp < int(a.data.max_hp):
				pool.append(a)
	else:
		pool = enemies

	var occupied := {}
	for u in units:
		if u != unit and u.is_alive():
			occupied[u.grid_position] = true
	var candidates: Array = grid.get_reachable_cells(unit.grid_position, unit.data.move_range, occupied)
	candidates.append(unit.grid_position)

	# Aucune cible : se replier le plus loin possible des ennemis.
	if pool.is_empty():
		return {"move": _safest_cell(candidates, enemies, grid), "target": null}

	var target: Node = _weakest(pool)
	var rng := int(unit.data.attack_range)
	var kite := is_healer or unit.data.behavior == "kite"

	var best: Vector2i = unit.grid_position
	var best_score := -INF
	for cell in candidates:
		var in_range := grid.manhattan(cell, target.grid_position) <= rng
		var score := 1000.0 if in_range else 0.0
		if kite:
			score += _nearest(cell, enemies, grid) * 3.0      # rester à distance
		else:
			score -= grid.manhattan(cell, target.grid_position)  # se rapprocher
		if score > best_score:
			best_score = score
			best = cell

	var tgt: Node = target if grid.manhattan(best, target.grid_position) <= rng else null
	return {"move": best, "target": tgt}


static func _weakest(arr: Array) -> Node:
	var w: Node = arr[0]
	for e in arr:
		if e.hp < w.hp:
			w = e
	return w


static func _nearest(cell: Vector2i, enemies: Array, grid: Node) -> int:
	if enemies.is_empty():
		return 999
	var d := 9999
	for e in enemies:
		d = min(d, grid.manhattan(cell, e.grid_position))
	return d


static func _safest_cell(candidates: Array, enemies: Array, grid: Node) -> Vector2i:
	var best: Vector2i = candidates[0]
	var best_d := -INF
	for cell in candidates:
		var d := _nearest(cell, enemies, grid)
		if d > best_d:
			best_d = d
			best = cell
	return best

class_name TacticalAI

# Cerveau de l'IA. Décide, pour une unité, où se déplacer et qui attaquer.
# Règles claires (pas de triche) : finir les cibles faibles, se positionner
# selon son comportement (mêlée = avancer, kite = frapper en restant à distance).
# Affiné à l'étape 10 (difficultés, protection, etc.).


static func decide(unit: Node, grid: Node, units: Array) -> Dictionary:
	var enemies: Array = []
	for u in units:
		if u.is_alive() and u.team != unit.team:
			enemies.append(u)
	if enemies.is_empty():
		return {"move": unit.grid_position, "target": null}

	var target: Node = _pick_target(enemies)

	var occupied := {}
	for u in units:
		if u != unit and u.is_alive():
			occupied[u.grid_position] = true

	var candidates: Array = grid.get_reachable_cells(unit.grid_position, unit.data.move_range, occupied)
	candidates.append(unit.grid_position)

	var best: Vector2i = unit.grid_position
	var best_score := -INF
	for cell in candidates:
		var s := _score(unit, cell, target, enemies, grid)
		if s > best_score:
			best_score = s
			best = cell

	var tgt: Node = null
	if grid.manhattan(best, target.grid_position) <= int(unit.data.attack_range):
		tgt = target
	return {"move": best, "target": tgt}


# Cible prioritaire : l'ennemi le plus faible (on finit les blessés).
static func _pick_target(enemies: Array) -> Node:
	var target: Node = enemies[0]
	for e in enemies:
		if e.hp < target.hp:
			target = e
	return target


static func _score(unit: Node, cell: Vector2i, target: Node, enemies: Array, grid: Node) -> float:
	var rng := int(unit.data.attack_range)
	var can_attack := grid.manhattan(cell, target.grid_position) <= rng
	var nearest := 9999
	for e in enemies:
		nearest = min(nearest, grid.manhattan(cell, e.grid_position))

	if unit.data.behavior == "kite":
		# Frapper tout en restant le plus loin possible des ennemis.
		return (1000.0 if can_attack else 0.0) + nearest * 3.0
	# Mêlée : pouvoir frapper, sinon se rapprocher de la cible.
	return (1000.0 if can_attack else 0.0) - grid.manhattan(cell, target.grid_position)

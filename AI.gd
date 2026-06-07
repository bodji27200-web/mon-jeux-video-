class_name TacticalAI

# Cerveau de l'IA (sans triche). Pour chaque unité, choisit un déplacement et
# une cible selon des règles lisibles :
#  - achever les cibles à portée de mort, viser en priorité soigneurs/tireurs ;
#  - kite : frapper en restant loin, ne jamais finir collé à un ennemi ;
#  - mêlée : foncer sur la cible et se placer près des alliés blessés (protéger) ;
#  - soigneur : soigner l'allié le plus bas en restant à l'abri ;
#  - selon la difficulté, commettre parfois une erreur volontaire.


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

	var is_healer: bool = unit.data.behavior == "heal"

	# Cibles potentielles : alliés blessés (soigneur) ou ennemis.
	var pool: Array = []
	if is_healer:
		# Le soigneur peut aussi se soigner lui-même.
		if unit.hp < int(unit.data.max_hp):
			pool.append(unit)
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

	# Rien à faire : se replier loin des ennemis.
	if pool.is_empty():
		return {"move": _safest_cell(candidates, enemies, grid), "target": null}

	var target: Node = _pick_ally(pool) if is_healer else _pick_enemy(unit, pool)
	var rng: int = unit.action_range()
	var kite: bool = is_healer or unit.data.behavior == "kite"

	# Erreur volontaire selon la difficulté.
	var mistake := randf() < float(GameData.DIFFICULTIES[GameData.difficulty].ai_mistake_chance)

	var best: Vector2i = unit.grid_position
	if mistake:
		best = candidates[randi() % candidates.size()]
	else:
		var best_score := -INF
		for cell in candidates:
			var s := _cell_score(unit, cell, target, enemies, allies, grid, kite, rng)
			if s > best_score:
				best_score = s
				best = cell

	var tgt: Node = target if (target == unit or grid.manhattan(best, target.grid_position) <= rng) else null
	return {"move": best, "target": tgt}


# Dégâts estimés (pour repérer les cibles que l'on peut achever).
static func _est_damage(unit: Node) -> float:
	var diff: Dictionary = GameData.DIFFICULTIES[GameData.difficulty]
	var side: float = diff.player_damage_mult if unit.is_player() else diff.ai_damage_mult
	return float(unit.data.attack) * unit.damage_dealt_mult() * side


static func _pick_enemy(unit: Node, enemies: Array) -> Node:
	var est := _est_damage(unit)
	var best: Node = enemies[0]
	var best_score := -INF
	for e in enemies:
		var s := -float(e.hp)             # privilégier les plus faibles
		if float(e.hp) <= est:
			s += 500.0                    # achevable ce tour-ci
		if e.data.behavior == "heal":
			s += 60.0                     # tuer le soigneur en priorité
		elif e.data.behavior == "kite":
			s += 30.0                     # puis les tireurs
		if s > best_score:
			best_score = s
			best = e
	return best


static func _pick_ally(allies: Array) -> Node:
	var best: Node = allies[0]
	var best_ratio := INF
	for a in allies:
		var ratio := float(a.hp) / float(a.data.max_hp)
		if ratio < best_ratio:
			best_ratio = ratio
			best = a
	return best


static func _cell_score(unit: Node, cell: Vector2i, target: Node, enemies: Array, allies: Array, grid: Node, kite: bool, rng: int) -> float:
	# Le soigneur peut toujours se cibler lui-même, où qu'il se déplace.
	var in_range: bool = target == unit or grid.manhattan(cell, target.grid_position) <= rng
	var score := 1000.0 if in_range else 0.0
	var near := _nearest(cell, enemies, grid)
	if kite:
		score += near * 4.0           # rester loin
		if near <= 1:
			score -= 200.0            # ne pas finir collé
	else:
		score -= grid.manhattan(cell, target.grid_position) * 4.0  # se rapprocher
		for a in allies:              # protéger un allié blessé adjacent
			if a.hp < int(a.data.max_hp) and grid.manhattan(cell, a.grid_position) == 1:
				score += 25.0
				break
	return score


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

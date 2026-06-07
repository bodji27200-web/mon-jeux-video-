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
	var candidates: Array = grid.get_reachable_cells(unit.grid_position, unit.move_range(), occupied)
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

	# Compétence active : décider si (et où) l'utiliser ce tour-ci.
	var skill_cell = null
	if not mistake and unit.skill_ready():
		var sk: Dictionary = unit.data.active
		if sk.type == "teleport_strike":
			# La téléportation remplace le déplacement normal.
			skill_cell = _plan_skill(unit, enemies, allies, grid, unit.grid_position)
			if skill_cell != null:
				best = unit.grid_position
		else:
			skill_cell = _plan_skill(unit, enemies, allies, grid, best)

	var tgt: Node = target if (target == unit or grid.manhattan(best, target.grid_position) <= rng) else null
	return {"move": best, "target": tgt, "skill_cell": skill_cell}


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


# --- Composition de l'équipe IA ---
# Plus la difficulté est haute, plus la composition est cohérente (ligne de
# front / dégâts / soin) et adaptée à l'équipe du joueur. Data-driven : lit le
# champ "role" des classes, donc une nouvelle classe est prise en compte seule.

static func compose_team(size: int, difficulty: String, player_team: Array) -> Array:
	if size <= 0:
		return []
	if difficulty == "facile":
		return _random_team(size)  # choix presque aléatoire
	var imperfection := 0.35 if difficulty == "normal" else 0.0
	var counter: bool = difficulty == "hardcore"  # adapte au joueur
	var groups := _classes_by_role()
	var team: Array = []
	for role in _role_slots(size):
		var cid: String = _random_team(1)[0] if randf() < imperfection \
				else _pick_for_role(role, groups, player_team, counter)
		if cid != "":
			team.append(cid)
	while team.size() < size:  # filet de sécurité si un rôle était vide
		team.append(_random_team(1)[0])
	return team


static func _random_team(size: int) -> Array:
	var ids: Array = GameData.CLASSES.keys()
	var t: Array = []
	for i in size:
		t.append(ids[randi() % ids.size()])
	return t


static func _classes_by_role() -> Dictionary:
	var g := {"tank": [], "melee": [], "ranged": [], "healer": []}
	for cid in GameData.CLASSES:
		var r: String = GameData.CLASSES[cid].get("role", "melee")
		if g.has(r):
			g[r].append(cid)
	return g


# Roles voulus selon la taille : 1 front, des dégâts, un soin dès 3 unités.
static func _role_slots(size: int) -> Array:
	if size == 1:
		return ["damage"]
	if size == 2:
		return ["tank", "damage"]
	var slots: Array = ["tank", "damage", "healer"]
	var extra := ["damage", "tank", "damage", "healer"]
	var i := 0
	while slots.size() < size:
		slots.append(extra[i % extra.size()])
		i += 1
	return slots


static func _pick_for_role(role: String, groups: Dictionary, player_team: Array, counter: bool) -> String:
	match role:
		"tank":
			return _rand_from(groups.tank if not groups.tank.is_empty() else groups.melee)
		"healer":
			return _rand_from(groups.healer if not groups.healer.is_empty() else groups.ranged)
		_:  # "damage"
			var pool: Array = _counter_damage_pool(groups, player_team) if counter \
					else groups.melee + groups.ranged
			return _rand_from(pool)


# Choix des unités de dégâts adapté à la composition du joueur (hardcore).
static func _counter_damage_pool(groups: Dictionary, player_team: Array) -> Array:
	var melee_cnt := 0
	var ranged_cnt := 0
	var has_healer := false
	for cid in player_team:
		var r: String = GameData.CLASSES[cid].get("role", "melee")
		if r == "ranged":
			ranged_cnt += 1
		elif r == "healer":
			has_healer = true
		else:
			melee_cnt += 1
	if has_healer and not groups.melee.is_empty():
		return groups.melee   # burst pour percer les soins
	if melee_cnt > ranged_cnt and not groups.ranged.is_empty():
		return groups.ranged  # joueur corps à corps -> on kite
	if ranged_cnt > melee_cnt and not groups.melee.is_empty():
		return groups.melee   # joueur à distance -> on fonce
	return groups.melee + groups.ranged


static func _rand_from(pool: Array) -> String:
	return pool[randi() % pool.size()] if not pool.is_empty() else ""


# --- Décision d'usage des compétences actives ---
# Renvoie la case à cibler si la compétence vaut le coup depuis `from`, sinon null.

static func _plan_skill(unit: Node, enemies: Array, allies: Array, grid: Node, from: Vector2i):
	var sk: Dictionary = unit.data.active
	var rng: int = int(sk.range)
	match sk.type:
		"shield_ally":
			# Protéger l'allié le plus menacé à portée (et pas déjà protégé).
			var best_a: Node = null
			var best_ratio := 0.6  # seulement si vraiment blessé
			for a in allies:
				if grid.manhattan(from, a.grid_position) > rng or _has_buff(a, "bouclier"):
					continue
				var ratio := float(a.hp) / float(a.data.max_hp)
				if ratio < best_ratio:
					best_ratio = ratio
					best_a = a
			return best_a.grid_position if best_a != null else null
		"teleport_strike":
			# Foncer sur la meilleure cible à portée qui n'est pas déjà au contact.
			var best_e: Node = null
			var best_score := -INF
			for e in enemies:
				var d: int = grid.manhattan(from, e.grid_position)
				if d > rng or d <= 1:
					continue
				var s := -float(e.hp)
				if e.data.behavior == "heal":
					s += 60.0
				elif e.data.behavior == "kite":
					s += 30.0
				if s > best_score:
					best_score = s
					best_e = e
			return best_e.grid_position if best_e != null else null
		"frost_nova":
			# Viser le point qui gèle le plus d'ennemis (au moins 2).
			var radius: int = int(sk.get("radius", 1))
			var best_cell = null
			var best_cnt := 1
			for e in enemies:
				if grid.manhattan(from, e.grid_position) > rng:
					continue
				var cnt := 0
				for o in enemies:
					if grid.manhattan(o.grid_position, e.grid_position) <= radius:
						cnt += 1
				if cnt > best_cnt:
					best_cnt = cnt
					best_cell = e.grid_position
			return best_cell
	return null


static func _has_buff(u: Node, id: String) -> bool:
	for b in u.buffs:
		if b.get("id", "") == id:
			return true
	return false

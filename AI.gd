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
	var terrain_pen: int = grid.terrain_move_penalty_at(unit.grid_position)
	var eff_range: int = max(0, unit.move_range() - terrain_pen)
	var candidates: Array = grid.get_reachable_cells(unit.grid_position, eff_range, occupied)
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

	# Compétences actives : on prend la PREMIÈRE compétence prête qui vaut le coup
	# (les actives sont rangées par priorité dans GameData). L'IA ne lance jamais
	# une compétence à vide : chaque _plan_skill renvoie null si ce n'est pas utile.
	var skill_cell = null
	var skill_index := -1
	if not mistake:
		var acts: Array = unit.get_actives()
		for i in acts.size():
			if not unit.skill_ready(i):
				continue
			var sk: Dictionary = acts[i]
			# La téléportation remplace le déplacement : on l'évalue depuis la position actuelle.
			var from_cell: Vector2i = unit.grid_position if sk.type == "teleport_strike" else best
			var cell = _plan_skill(sk, unit, enemies, allies, grid, from_cell)
			if cell != null:
				skill_cell = cell
				skill_index = i
				if sk.type == "teleport_strike":
					best = unit.grid_position
				break

	var tgt: Node = target if (target == unit or grid.manhattan(best, target.grid_position) <= rng) else null
	return {"move": best, "target": tgt, "skill_cell": skill_cell, "skill_index": skill_index}


# Dégâts estimés (pour repérer les cibles que l'on peut achever).
static func _est_damage(unit: Node) -> float:
	var diff: Dictionary = GameData.DIFFICULTIES[GameData.difficulty]
	var side: float = diff.player_damage_mult if unit.is_player() else diff.ai_damage_mult
	return float(unit.data.attack) * unit.damage_dealt_mult() * side


static func _pick_enemy(unit: Node, enemies: Array) -> Node:
	var est := _est_damage(unit)
	var best: Node = enemies[0]
	var best_score := -INF
	var hard: bool = GameData.difficulty in ["difficile", "hardcore"]
	for e in enemies:
		var s := -float(e.hp)
		if float(e.hp) <= est:
			s += 500.0                    # achevable ce tour-ci
		if _has_buff(e, "parade"):
			s -= 180.0                    # cible en parade : la prochaine attaque sera bloquée
		if e.data.behavior == "heal":
			s += 60.0                     # tuer le soigneur en priorité
		elif e.data.behavior == "kite":
			s += 30.0                     # puis les tireurs
		# Hardcore/Difficile : tenir compte de la dangerosité de l'ennemi
		if hard:
			var threat_bonus := float(e.data.attack) * 1.5
			if e.get("summoner") == null and not e.get("is_summon"):
				s += threat_bonus * 0.5   # éviter les cibles invoquées pour focus les vraies
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
	# IA avancée : éviter les cases dangereuses, d'autant plus si l'unité est
	# fragile ou déjà blessée (les unités se replient au lieu de se sacrifier).
	var fragility := 1.0 - float(unit.hp) / float(unit.data.max_hp)
	score -= _threat(cell, enemies, grid) * (3.0 + fragility * 12.0)
	return score


static func _nearest(cell: Vector2i, enemies: Array, grid: Node) -> int:
	if enemies.is_empty():
		return 999
	var d := 9999
	for e in enemies:
		d = min(d, grid.manhattan(cell, e.grid_position))
	return d


# Nombre d'ennemis pouvant atteindre (déplacement + portée) cette case au tour suivant.
static func _threat(cell: Vector2i, enemies: Array, grid: Node) -> int:
	var t := 0
	for e in enemies:
		var reach: int = int(e.data.move_range) + e.action_range()
		if grid.manhattan(cell, e.grid_position) <= reach:
			t += 1
	return t


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
	var ids: Array = []
	for cid in GameData.CLASSES:
		if not GameData.CLASSES[cid].get("hidden", false):
			ids.append(cid)
	var t: Array = []
	for i in size:
		t.append(ids[randi() % ids.size()])
	return t


static func _classes_by_role() -> Dictionary:
	var g := {"tank": [], "melee": [], "ranged": [], "healer": []}
	for cid in GameData.CLASSES:
		if GameData.CLASSES[cid].get("hidden", false):
			continue
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


# --- Draft : l'IA choisit UNE classe dans le pool partagé restant ---
# S'adapte à son équipe en cours (rôle manquant) et, en difficile/hardcore, à
# l'équipe adverse (counter). Facile = quasi aléatoire ; normal = imparfait.
static func draft_pick(available: Array, ai_team: Array, player_team: Array, difficulty: String) -> String:
	if available.is_empty():
		return ""
	# Règle : une seule classe unique par équipe. Si l'IA en a déjà une, on retire
	# les uniques du pool de choix (elles restent draftables par le joueur).
	var ai_has_unique := false
	for c in ai_team:
		if GameData.CLASSES[c].get("unique", false):
			ai_has_unique = true
			break
	if ai_has_unique:
		var filtered: Array = []
		for cid in available:
			if not GameData.CLASSES[cid].get("unique", false):
				filtered.append(cid)
		available = filtered
		if available.is_empty():
			return ""
	if difficulty == "facile":
		return available[randi() % available.size()]
	# Classes disponibles regroupées par rôle (uniquement dans le pool restant).
	var avail_roles := {"tank": [], "melee": [], "ranged": [], "healer": []}
	for cid in available:
		var r: String = GameData.CLASSES[cid].get("role", "melee")
		if avail_roles.has(r):
			avail_roles[r].append(cid)
	# Rôle visé pour le pick courant (tank -> dégâts -> soin).
	var slots: Array = _role_slots(3)
	var slot: String = slots[min(ai_team.size(), slots.size() - 1)]
	var counter: bool = difficulty == "hardcore"
	var pick: String = _pick_for_role(slot, avail_roles, player_team, counter)
	# Normal : parfois un choix imparfait (aléatoire dans le pool).
	if difficulty == "normal" and randf() < 0.35:
		pick = available[randi() % available.size()]
	if pick == "":
		pick = available[randi() % available.size()]
	return pick


# --- Décision d'usage des compétences actives ---
# Renvoie la case à cibler si la compétence vaut le coup depuis `from`, sinon null.

static func _plan_skill(sk: Dictionary, unit: Node, enemies: Array, allies: Array, grid: Node, from: Vector2i):
	var rng: int = int(sk.get("range", 1))
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
		"purify":
			# Nettoyer l'allié (ou soi) le plus chargé d'effets négatifs.
			var pool: Array = allies.duplicate()
			pool.append(unit)
			var best_c = null
			var best_cnt := 0
			for a in pool:
				var d: int = 0 if a == unit else grid.manhattan(from, a.grid_position)
				if d > rng:
					continue
				var cnt := _removable_count(a)
				if cnt > best_cnt:
					best_cnt = cnt
					best_c = a.grid_position
			return best_c
		"frost_nova":
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
		"roots":
			# Immobiliser l'ennemi le plus mobile à portée, non déjà immobilisé.
			var best_e: Node = null
			var best_mv := -1
			for e in enemies:
				if grid.manhattan(from, e.grid_position) > rng or _has_buff(e, "racines"):
					continue
				var mv: int = e.move_range()
				if mv > best_mv:
					best_mv = mv
					best_e = e
			return best_e.grid_position if best_e != null else null
		"double_dot":
			# Cibler l'ennemi sans DoT ou avec le moins de DoTs actifs.
			var best_e: Node = null
			var best_score := -INF
			for e in enemies:
				if grid.manhattan(from, e.grid_position) > rng:
					continue
				var dot_count := 0
				for b in e.buffs:
					if b.has("dmg_per_turn"):
						dot_count += 1
				if dot_count >= 2:
					continue  # déjà saturé
				var score := -float(e.hp) + (15.0 if dot_count == 0 else 0.0)
				if score > best_score:
					best_score = score
					best_e = e
			return best_e.grid_position if best_e != null else null
		"war_heal":
			# Soigner l'allié (ou soi-même) vraiment en danger (pas de gaspillage).
			var pool: Array = allies.duplicate()
			pool.append(unit)
			var best_a: Node = null
			var best_ratio := 0.5
			for a in pool:
				var d: int = 0 if a == unit else grid.manhattan(from, a.grid_position)
				if d > rng:
					continue
				var ratio := float(a.hp) / float(a.data.max_hp)
				if ratio < best_ratio:
					best_ratio = ratio
					best_a = a
			return best_a.grid_position if best_a != null else null
		"empower_ally":
			# Booster l'allié à plus fort potentiel offensif non encore boosté.
			var best_a: Node = null
			var best_atk := -1
			for a in allies:
				if grid.manhattan(from, a.grid_position) > rng or _has_buff(a, "force"):
					continue
				var atk: int = int(a.data.attack)
				if atk > best_atk:
					best_atk = atk
					best_a = a
			return best_a.grid_position if best_a != null else null
		"mark_shot":
			# Marquer l'ennemi le plus dangereux non encore marqué.
			var best_e: Node = null
			var best_score := -INF
			for e in enemies:
				if grid.manhattan(from, e.grid_position) > rng or _has_buff(e, "marque"):
					continue
				var score := float(e.data.attack) * 2.0 - float(e.hp) * 0.05
				if score > best_score:
					best_score = score
					best_e = e
			return best_e.grid_position if best_e != null else null
		"drain_strike":
			# Frapper la cible la plus faible (le drain en fait un finisher).
			var best_e: Node = null
			var best_score := -INF
			for e in enemies:
				if grid.manhattan(from, e.grid_position) > rng:
					continue
				var score := -float(e.hp)
				if float(e.hp) <= _est_damage(unit) * 1.3:
					score += 300.0
				if score > best_score:
					best_score = score
					best_e = e
			return best_e.grid_position if best_e != null else null
		"piercing_shot":
			# Direction avec le plus d'ennemis alignés : utile à partir de 2 cibles
			# (sur une seule cible, autant faire une attaque normale).
			var best_dir := Vector2i.ZERO
			var best_cnt := 1
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var cnt := 0
				for i in range(1, rng + 1):
					var c: Vector2i = from + dir * i
					if not grid.is_inside(c):
						break
					for e in enemies:
						if e.grid_position == c:
							cnt += 1
				if cnt > best_cnt:
					best_cnt = cnt
					best_dir = dir
			if best_dir != Vector2i.ZERO:
				return from + best_dir
			return null
		"invoke":
			# Invoquer si une case adjacente est libre (vérifié dans _use_skill).
			return from
		"heavy_strike":
			# Gros coup gardé pour achever une cible ou frapper une cible prioritaire
			# (soigneur/tireur) — sinon on économise le cooldown.
			var best_e: Node = null
			var best_score := -INF
			for e in enemies:
				if grid.manhattan(from, e.grid_position) > rng:
					continue
				var score := -float(e.hp)
				if e.data.behavior == "heal":
					score += 50.0
				elif e.data.behavior == "kite":
					score += 25.0
				if score > best_score:
					best_score = score
					best_e = e
			if best_e == null:
				return null
			var killable: bool = float(best_e.hp) <= _est_damage(unit) * float(sk.get("dmg_mult", 1.8))
			if killable or best_e.data.behavior in ["heal", "kite"]:
				return best_e.grid_position
			return null
		"cleave":
			# Fauche : seulement si au moins 2 ennemis seraient touchés.
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
		"self_buff":
			# Buff personnel : offensif si on va frapper, défensif si menacé/blessé.
			if _has_buff(unit, str(sk.buff)):
				return null
			var binfo: Dictionary = GameData.BUFFS.get(str(sk.buff), {})
			var offensive: bool = binfo.has("dmg_dealt_mult") and float(binfo.dmg_dealt_mult) > 1.0
			var counter: bool = binfo.get("riposte", false) or binfo.get("block_next", false)
			var defensive: bool = (binfo.has("dmg_taken_mult") and float(binfo.dmg_taken_mult) < 1.0) or binfo.has("heal_per_turn")
			if offensive:
				for e in enemies:
					if grid.manhattan(from, e.grid_position) <= unit.action_range():
						return from
				return null
			if counter:
				# Riposte / parade : utile quand un ennemi est au contact (ou sur le point de l'être).
				for e in enemies:
					if grid.manhattan(from, e.grid_position) <= unit.action_range() + 1:
						return from
				return null
			if defensive:
				var ratio := float(unit.hp) / float(unit.data.max_hp)
				if ratio < 0.6 or _threat(from, enemies, grid) >= 2:
					return from
				return null
			return from
		"buff_ally":
			# Renforcer le meilleur allié à portée qui n'a pas déjà ce buff.
			var binfo2: Dictionary = GameData.BUFFS.get(str(sk.buff), {})
			var offensive2: bool = binfo2.has("dmg_dealt_mult") and float(binfo2.dmg_dealt_mult) > 1.0
			var pool: Array = allies.duplicate()
			if sk.get("can_self", false):
				pool.append(unit)
			var best_a: Node = null
			var best_v := -INF
			for a in pool:
				var d: int = 0 if a == unit else grid.manhattan(from, a.grid_position)
				if d > rng or _has_buff(a, str(sk.buff)):
					continue
				var v: float = float(a.data.attack) if offensive2 else (1.0 - float(a.hp) / float(a.data.max_hp))
				if v > best_v:
					best_v = v
					best_a = a
			return best_a.grid_position if best_a != null else null
		"apply_debuff":
			# Handicaper l'ennemi le plus dangereux à portée non encore affecté.
			var best_d: Node = null
			var best_sc := -INF
			for e in enemies:
				if grid.manhattan(from, e.grid_position) > rng or _has_buff(e, str(sk.buff)):
					continue
				var score := float(e.data.attack) * 1.5 - float(e.hp) * 0.05
				if e.data.behavior == "heal":
					score += 40.0
				if score > best_sc:
					best_sc = score
					best_d = e
			return best_d.grid_position if best_d != null else null
		"team_buff":
			# Barde : chanter quand le combat est engagé et que le buff n'est pas déjà actif.
			if _has_buff(unit, str(sk.buff)):
				return null
			for e in enemies:
				if grid.manhattan(from, e.grid_position) <= 7:
					return from
			return null
		"team_debuff":
			# Barde : affaiblir tous les ennemis dès qu'ils sont engagés (au moins un non affecté).
			for e in enemies:
				if grid.manhattan(from, e.grid_position) <= 7 and not _has_buff(e, str(sk.buff)):
					return from
			return null
		"retreat_shot":
			# Archère : tirer sur la meilleure cible à portée, surtout si un ennemi approche.
			var best_rs: Node = null
			var best_rs_score := -INF
			var threatened: bool = _nearest(from, enemies, grid) <= 2
			for e in enemies:
				if grid.manhattan(from, e.grid_position) > rng:
					continue
				var s := -float(e.hp)
				if e.data.behavior == "heal":
					s += 40.0
				if threatened:
					s += 30.0
				if s > best_rs_score:
					best_rs_score = s
					best_rs = e
			return best_rs.grid_position if best_rs != null else null
	return null


static func _has_buff(u: Node, id: String) -> bool:
	for b in u.buffs:
		if b.get("id", "") == id:
			return true
	return false


static func _removable_count(u: Node) -> int:
	# Compte les effets négatifs purifiables (aligné sur Unit.purge_debuffs) :
	# DoT, ralentissement, immobilisation, affaiblissement, vulnérabilité.
	var n := 0
	for b in u.buffs:
		if b.has("dmg_per_turn") or b.has("move_penalty") \
				or b.get("immobilized", false) \
				or (b.has("dmg_dealt_mult") and float(b.dmg_dealt_mult) < 1.0) \
				or (b.has("dmg_taken_mult") and float(b.dmg_taken_mult) > 1.0):
			n += 1
	return n

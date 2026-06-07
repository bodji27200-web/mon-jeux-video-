extends Node2D

# Orchestrateur du combat : relie tours, entrées du joueur et actions.

@onready var grid: Node2D = $Grid
@onready var turn_manager: Node = $TurnManager
@onready var end_label: Label = $UI/EndLabel
@onready var replay_button: Button = $UI/RejouerButton
@onready var skill_hint: Label = $UI/SkillHint

const UNIT_SCENE := preload("res://Unit.tscn")
const SKILL_FX := preload("res://SkillFX.gd")

# Barre de compétences : 3 carrés en bas à droite, un par compétence active de
# la classe (jusqu'à 3). Les carrés sans compétence restent vides/désactivés.
# Icône courte par type de compétence.
const SKILL_SLOTS := 3
const SKILL_ICONS := {
	"invoke": "Inv", "roots": "Rac", "war_heal": "Soin", "double_dot": "DoT",
	"drain_strike": "Drain", "mark_shot": "Marq", "empower_ally": "Force",
	"shield_ally": "Bouc", "purify": "Pur", "frost_nova": "Gel",
	"teleport_strike": "Saut", "piercing_shot": "Perce", "traps": "Piège",
	"heavy_strike": "Charge", "cleave": "Fauche", "self_buff": "Buff",
	"apply_debuff": "Malus", "buff_ally": "Aura",
	"team_buff": "Hymne", "team_debuff": "Discord", "retreat_shot": "Recul",
}

var active_unit: Node = null
var phase := "idle"  # "move", "attack" puis éventuellement "skill" (joueur)
var _finished := false
var skill_slots: Array = []  # boutons de la barre de compétences
var selected_skill := -1  # index de la compétence sélectionnée (phase "skill")


func _ready() -> void:
	_build_skill_bar()
	_generate_terrain()
	_spawn_units()
	replay_button.pressed.connect(_on_replay)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.start()


# Construit la barre de 3 carrés (UI souris uniquement, pas de raccourci clavier).
func _build_skill_bar() -> void:
	var s := 52
	var gap := 6
	var total := SKILL_SLOTS * s + (SKILL_SLOTS - 1) * gap
	var x0 := 832 - total - 12
	var y := 704 - s - 10
	for i in SKILL_SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(s, s)
		b.size = Vector2(s, s)
		b.position = Vector2(x0 + i * (s + gap), y)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = true
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_on_skill_slot.bind(i))
		$UI.add_child(b)
		skill_slots.append(b)
	_refresh_skill_bar()


func _on_replay() -> void:
	# Relance une partie depuis l'écran de sélection (équipe + difficulté).
	get_tree().change_scene_to_file("res://TeamSelect.tscn")


# Crée les unités à partir des équipes choisies (GameData).
func _spawn_units() -> void:
	_spawn_team(GameData.player_team, GameData.Team.PLAYER, 1)
	_spawn_team(GameData.ai_team, GameData.Team.AI, grid.COLUMNS - 2)


func _spawn_team(classes: Array, team: int, col: int) -> void:
	var start_row := int((grid.ROWS - classes.size()) / 2.0)
	for i in classes.size():
		var u := UNIT_SCENE.instantiate()
		u.class_id = classes[i]
		u.team = team
		u.grid_position = Vector2i(col, start_row + i)
		grid.add_child(u)


func _on_turn_started(unit: Node) -> void:
	active_unit = unit
	# Effets de début de tour (poison, régénération...).
	unit.tick_buffs()
	if not unit.is_alive():
		await get_tree().process_frame
		if not _check_end():
			turn_manager.next_turn()
		return
	if unit.is_player():
		phase = "move"
		_show_moves(unit)
	else:
		_ai_take_turn(unit)


func _show_moves(unit: Node) -> void:
	var terrain_pen: int = grid.terrain_move_penalty_at(unit.grid_position)
	var eff_range: int = max(0, unit.move_range() - terrain_pen)
	grid.move_cells = grid.get_reachable_cells(unit.grid_position, eff_range, _occupied(unit))
	grid.target_cells = []
	grid.heal_cells = []
	grid.skill_cells = []
	_refresh_skill_bar()
	grid.queue_redraw()


func _enter_action_phase() -> void:
	phase = "attack"
	selected_skill = -1
	grid.move_cells = []
	grid.skill_cells = []
	if _is_healer(active_unit):
		grid.heal_cells = _action_targets(active_unit)
		grid.target_cells = []
	else:
		grid.target_cells = _action_targets(active_unit)
		grid.heal_cells = []
	_refresh_skill_bar()
	grid.queue_redraw()


# Met à jour la barre de 3 carrés selon l'unité active et la phase. Chaque carré
# correspond à une compétence active de la classe (jusqu'à 3) ; les carrés sans
# compétence restent vides et désactivés.
func _refresh_skill_bar() -> void:
	var show_bar: bool = active_unit != null and active_unit.is_player() \
			and phase in ["move", "attack", "skill"]
	for b in skill_slots:
		b.visible = show_bar
	if not show_bar:
		skill_hint.visible = false
		return
	var acts: Array = active_unit.get_actives()
	for i in SKILL_SLOTS:
		var b: Button = skill_slots[i]
		if i < acts.size():
			var sk: Dictionary = acts[i]
			b.text = str(SKILL_ICONS.get(sk.type, "Comp"))
			b.tooltip_text = str(sk.name) + "\n" + str(sk.get("desc", ""))
			var usable: bool = phase in ["attack", "skill"] and active_unit.skill_ready(i)
			b.disabled = not usable
			b.modulate = Color(1.0, 1.0, 0.4) if (phase == "skill" and selected_skill == i) else Color(1, 1, 1)
		else:
			b.text = ""
			b.disabled = true
			b.modulate = Color(0.45, 0.45, 0.5)
	# Indication textuelle quand une compétence est sélectionnée.
	if phase == "skill" and selected_skill >= 0 and selected_skill < acts.size():
		skill_hint.text = "Compétence : %s — clique une cible (ou reclique le carré pour annuler)" % str(acts[selected_skill].name)
		skill_hint.visible = true
	else:
		skill_hint.visible = false


func _ai_take_turn(unit: Node) -> void:
	await get_tree().create_timer(0.35).timeout
	var plan := TacticalAI.decide(unit, grid, get_tree().get_nodes_in_group("units"))
	if plan.move != unit.grid_position:
		unit.move_to(plan.move)
		await get_tree().create_timer(0.35).timeout
	# L'IA utilise la compétence qu'elle a jugée utile, sinon attaque normale.
	var si: int = int(plan.get("skill_index", -1))
	if plan.get("skill_cell") != null and si >= 0 and unit.skill_ready(si):
		_use_skill(unit, plan.skill_cell, si)
	elif plan.target != null and plan.target.is_alive() \
			and grid.manhattan(unit.grid_position, plan.target.grid_position) <= unit.action_range():
		_perform_action(unit, plan.target)
	await get_tree().create_timer(0.2).timeout
	_end_turn()


# Clic sur un carré : sélectionne la compétence correspondante (si elle existe).
# Recliquer le carré déjà sélectionné annule (retour à l'attaque normale).
func _on_skill_slot(index: int) -> void:
	if active_unit == null or not active_unit.is_player():
		return
	if index >= active_unit.get_actives().size():
		return  # carré vide
	if phase == "attack":
		selected_skill = index
		_enter_skill_phase()
	elif phase == "skill":
		if selected_skill == index:
			_enter_action_phase()  # reclic -> annule
		else:
			selected_skill = index  # changer de compétence sélectionnée
			_enter_skill_phase()


func _enter_skill_phase() -> void:
	phase = "skill"
	grid.target_cells = []
	grid.heal_cells = []
	grid.skill_cells = _skill_targets(active_unit, selected_skill)
	_refresh_skill_bar()
	grid.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _finished or active_unit == null or not active_unit.is_player():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(grid.local_to_cell(grid.to_local(get_global_mouse_position())))
	elif event.is_action_pressed("ui_accept"):
		if phase == "move":
			_enter_action_phase()  # passer le déplacement
		else:
			_end_turn()


func _handle_click(cell: Vector2i) -> void:
	if phase == "move" and cell in grid.move_cells:
		active_unit.move_to(cell)
		_enter_action_phase()
	elif phase == "attack" and (cell in grid.target_cells or cell in grid.heal_cells):
		var target := _unit_at(cell)
		if target:
			_perform_action(active_unit, target)
			_end_turn()
	elif phase == "skill" and cell in grid.skill_cells:
		_use_skill(active_unit, cell, selected_skill)
		_end_turn()


# Soin si soigneur, sinon attaque (avec coup critique éventuel).
func _perform_action(unit: Node, target: Node) -> void:
	if _is_healer(unit):
		target.heal(int(unit.data.heal))
		_fx("buff", target.grid_position, target.grid_position, Color(0.30, 0.90, 0.40))
	else:
		_attack(unit, target)
	unit.has_acted = true


# Attaque de base : dégâts, critique, terrain, marque, drain, debuff.
# `mult` permet aux compétences de frapper plus fort (Charge, Fauche...).
# `is_counter` = true quand c'est une riposte (évite qu'une riposte en déclenche une autre).
func _attack(unit: Node, target: Node, mult := 1.0, is_counter := false) -> void:
	# Animation : projectile si l'attaque est à distance, coup de lame sinon.
	var atk_kind: String = "projectile" if int(unit.data.attack_range) > 1 else "slash"
	_fx(atk_kind, unit.grid_position, target.grid_position, unit.data.color)
	# Parade : la cible bloque entièrement la prochaine attaque reçue (le buff est consommé).
	if _consume_parade(target):
		_show_blocked_text(target)
		return
	var dmg: float = float(unit.data.attack) * mult
	var is_crit: bool = randf() < unit.data.crit_chance
	if is_crit:
		dmg *= 2.0
	dmg *= unit.damage_dealt_mult() * target.damage_taken_mult()
	# Chasseur : bonus si la cible est marquée
	if unit.data.has("mark_bonus_mult") and _target_has_buff(target, "marque"):
		dmg *= float(unit.data.mark_bonus_mult)
	# Terrain : forêt réduit les dégâts à distance ; ruines protègent
	var tt: Dictionary = grid.terrain_at(target.grid_position)
	if not tt.is_empty():
		if tt.has("dmg_taken_mult"):
			dmg *= float(tt.dmg_taken_mult)
		if tt.has("ranged_dmg_mult") and int(unit.data.attack_range) > 1:
			dmg *= float(tt.ranged_dmg_mult)
	dmg *= _difficulty_damage_mult(unit)
	target.take_damage(int(round(dmg)), is_crit)
	if unit.data.has("on_hit") and target.is_alive():
		target.add_buff(unit.data.on_hit)
	# Chevalier noir : drain passif (25% des dégâts récupérés en PV)
	if unit.data.has("drain_pct"):
		unit.heal(int(round(dmg * float(unit.data.drain_pct))))
	# Duelliste : riposte automatique si la cible est en posture et l'attaquant à sa portée de mêlée.
	if not is_counter and target.is_alive() and unit.is_alive() \
			and _has_buff(target, "riposte") \
			and grid.manhattan(unit.grid_position, target.grid_position) <= target.action_range():
		_attack(target, unit, 1.0, true)


# Consomme le buff "parade" de l'unité (bloque la prochaine attaque). True si présent.
func _consume_parade(target: Node) -> bool:
	for i in target.buffs.size():
		if target.buffs[i].get("block_next", false):
			target.buffs.remove_at(i)
			target.queue_redraw()
			return true
	return false


func _has_buff(u: Node, id: String) -> bool:
	for b in u.buffs:
		if b.get("id", "") == id:
			return true
	return false


# Instancie un effet visuel de compétence/attaque (cosmétique, auto-libéré).
func _fx(kind: String, from_cell: Vector2i, to_cell: Vector2i, color: Color, rad_px := 32.0) -> void:
	var fx := SKILL_FX.new()
	fx.setup(kind, grid.cell_to_local(from_cell), grid.cell_to_local(to_cell), color, rad_px)
	grid.add_child(fx)


# Texte flottant "Paré !" au-dessus de l'unité qui a paré.
func _show_blocked_text(target: Node) -> void:
	var ft := preload("res://FloatingText.tscn").instantiate()
	ft.text = "Paré !"
	ft.color_value = Color(0.6, 0.85, 1.0)
	ft.font_size_value = 22
	ft.duration = 1.0
	ft.position = target.position + Vector2(-14.0, -46.0)
	grid.add_child(ft)


func _end_turn() -> void:
	grid.move_cells = []
	grid.target_cells = []
	grid.heal_cells = []
	grid.skill_cells = []
	phase = "idle"
	_refresh_skill_bar()
	grid.queue_redraw()
	if _check_end():
		return
	turn_manager.next_turn()


func _check_end() -> bool:
	var p := false
	var a := false
	for u in turn_manager.units:
		if u.is_alive():
			if u.is_player():
				p = true
			else:
				a = true
	if not p or not a:
		_finished = true
		if turn_manager.turn_label:
			turn_manager.turn_label.text = ""
		end_label.text = "VICTOIRE !" if p else "DÉFAITE..."
		end_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3) if p else Color(0.9, 0.2, 0.2))
		end_label.add_theme_font_size_override("font_size", 64)
		end_label.visible = true
		replay_button.visible = true
		return true
	return false


# --- Compétences actives ---

# Cases ciblables par la compétence d'index donné (alliés, ennemis, soi, ligne).
func _skill_targets(unit: Node, index: int) -> Array:
	var cells: Array = []
	if not unit.skill_ready(index):
		return cells
	var sk: Dictionary = unit.get_actives()[index]
	# Compétence sur soi-même (buff personnel) : une seule case, la sienne.
	if sk.get("target", "") == "self":
		cells.append(unit.grid_position)
		return cells
	# Tir perforant : cases dans les 4 directions jusqu'à portée max
	if sk.get("target", "") == "line":
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for i in range(1, int(sk.range) + 1):
				var c: Vector2i = unit.grid_position + dir * i
				if not grid.is_inside(c):
					break
				cells.append(c)
		return cells
	# Invocation : cases adjacentes libres
	if sk.get("type", "") == "invoke":
		var occ := _occupied()
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = unit.grid_position + dir
			if grid.is_inside(c) and not occ.has(c):
				cells.append(c)
		return cells
	if sk.get("target", "") == "ally" and sk.get("can_self", false):
		cells.append(unit.grid_position)
	for u in get_tree().get_nodes_in_group("units"):
		if not u.is_alive() or u == unit:
			continue
		if grid.manhattan(unit.grid_position, u.grid_position) > int(sk.range):
			continue
		if sk.get("target", "") == "ally" and u.team == unit.team:
			cells.append(u.grid_position)
		elif sk.get("target", "") == "enemy" and u.team != unit.team:
			cells.append(u.grid_position)
	return cells


# Applique l'effet de la compétence d'index donné (data-driven, extensible).
func _use_skill(caster: Node, cell: Vector2i, index: int) -> void:
	var sk: Dictionary = caster.get_actives()[index]
	var success := true
	match sk.type:
		"shield_ally":
			var ally := _unit_at(cell)
			if ally:
				ally.add_buff("bouclier")
				_fx("buff", cell, cell, Color(0.45, 0.65, 1.0))
		"empower_ally":
			var ally := _unit_at(cell)
			if ally:
				ally.add_buff("force")
				_fx("buff", cell, cell, Color(1.0, 0.55, 0.20))
		"purify":
			var ally := _unit_at(cell)
			if ally:
				ally.purge_debuffs()
				_fx("buff", cell, cell, Color(0.85, 0.95, 1.0))
		"war_heal":
			var ally := _unit_at(cell)
			if ally:
				ally.heal(int(sk.get("heal_amount", 12)))
				_fx("buff", cell, cell, Color(0.30, 0.90, 0.40))
		"roots":
			var enemy := _unit_at(cell)
			if enemy:
				enemy.add_buff("racines")
				_fx("debuff", cell, cell, Color(0.25, 0.75, 0.25))
		"double_dot":
			var enemy := _unit_at(cell)
			if enemy:
				enemy.add_buff("poison")
				enemy.add_buff("brulure")
				_fx("debuff", cell, cell, Color(0.55, 0.80, 0.20))
		"mark_shot":
			var enemy := _unit_at(cell)
			if enemy:
				_fx("projectile", caster.grid_position, cell, caster.data.color)
				enemy.add_buff("marque")
				_fx("debuff", cell, cell, Color(0.95, 0.80, 0.10))
		"drain_strike":
			var enemy := _unit_at(cell)
			if enemy:
				_attack(caster, enemy)
				# Drain supplémentaire : soigne 60% de l'attaque de base en PV
				caster.heal(int(round(float(caster.data.attack) * 0.60)))
				_fx("beam", cell, caster.grid_position, Color(0.55, 0.10, 0.20))
		"heavy_strike":
			# Gros coup unique : attaque multipliée sur une cible.
			var enemy := _unit_at(cell)
			if enemy:
				_attack(caster, enemy, float(sk.get("dmg_mult", 1.8)))
		"cleave":
			# Frappe la cible et tous les ennemis adjacents (mêlée de zone).
			var radius: int = int(sk.get("radius", 1))
			_fx("explosion", cell, cell, caster.data.color, (radius + 0.5) * grid.CELL_SIZE)
			for u in get_tree().get_nodes_in_group("units"):
				if u.is_alive() and u.team != caster.team \
						and grid.manhattan(u.grid_position, cell) <= radius:
					_attack(caster, u, float(sk.get("dmg_mult", 1.0)))
		"self_buff":
			# Buff personnel (rage, garde, régén...).
			caster.add_buff(str(sk.buff))
			_fx("buff", caster.grid_position, caster.grid_position, Color(1.0, 0.85, 0.30))
		"buff_ally":
			# Applique un buff nommé à un allié (ou soi si can_self).
			var ally := _unit_at(cell)
			if ally:
				ally.add_buff(str(sk.buff))
				_fx("buff", cell, cell, Color(1.0, 0.85, 0.30))
		"team_buff":
			# Barde : applique un buff à TOUTE l'équipe (lui-même inclus).
			for u in get_tree().get_nodes_in_group("units"):
				if u.is_alive() and u.team == caster.team:
					u.add_buff(str(sk.buff))
					_fx("buff", u.grid_position, u.grid_position, Color(1.0, 0.85, 0.30))
		"team_debuff":
			# Barde : applique un debuff à TOUS les ennemis.
			for u in get_tree().get_nodes_in_group("units"):
				if u.is_alive() and u.team != caster.team:
					u.add_buff(str(sk.buff))
					_fx("debuff", u.grid_position, u.grid_position, Color(0.75, 0.25, 0.85))
		"retreat_shot":
			# Archère : tire sur la cible puis recule de N cases hors de portée.
			var enemy_rs := _unit_at(cell)
			if enemy_rs:
				_attack(caster, enemy_rs)
				_retreat(caster, enemy_rs.grid_position, int(sk.get("retreat", 2)))
		"apply_debuff":
			# Tir handicapant : attaque + applique un debuff nommé.
			var enemy := _unit_at(cell)
			if enemy:
				_attack(caster, enemy, float(sk.get("dmg_mult", 1.0)))
				if enemy.is_alive():
					enemy.add_buff(str(sk.buff))
					_fx("debuff", cell, cell, Color(0.75, 0.25, 0.85))
		"teleport_strike":
			var enemy := _unit_at(cell)
			if enemy:
				var dest = _free_adjacent(cell, caster)
				if dest != null:
					_fx("teleport", caster.grid_position, dest, caster.data.color)
					caster.move_to(dest)
				_attack(caster, enemy)
		"frost_nova":
			var radius: int = int(sk.get("radius", 1))
			_fx("nova", cell, cell, Color(0.55, 0.85, 1.0), (radius + 0.5) * grid.CELL_SIZE)
			for u in get_tree().get_nodes_in_group("units"):
				if u.is_alive() and u.team != caster.team \
						and grid.manhattan(u.grid_position, cell) <= radius:
					u.add_buff("gel")
		"piercing_shot":
			var diff: Vector2i = cell - caster.grid_position
			var dir: Vector2i
			if abs(diff.x) >= abs(diff.y):
				dir = Vector2i(sign(diff.x), 0)
			else:
				dir = Vector2i(0, sign(diff.y))
			var end_cell: Vector2i = caster.grid_position + dir * int(sk.range)
			_fx("beam", caster.grid_position, end_cell, caster.data.color)
			for i in range(1, int(sk.range) + 1):
				var c: Vector2i = caster.grid_position + dir * i
				if not grid.is_inside(c):
					break
				var enemy := _unit_at(c)
				if enemy and enemy.team != caster.team and enemy.is_alive():
					_attack(caster, enemy)
		"invoke":
			var dest = _free_adjacent(caster.grid_position, caster)
			if dest == null:
				success = false  # pas de place -> pas de CD
			else:
				var classes: Array = sk.get("summon_classes", [str(sk.get("summon_class", "squelette_guerrier"))])
				var summon := UNIT_SCENE.instantiate()
				summon.set("class_id", _next_summon_class(caster, classes))
				summon.set("team", caster.team)
				summon.set("grid_position", dest)
				summon.set("is_summon", true)
				summon.set("summoner", caster)
				grid.add_child(summon)
				turn_manager.add_unit(summon)
				_fx("teleport", dest, dest, caster.data.color)
	if success:
		caster.start_skill_cooldown(index)
	caster.has_acted = true


# Choisit la prochaine créature à invoquer : celle dont l'invocateur a le moins
# d'exemplaires vivants (donne de la variété entre les rôles, ex. guerrier puis archer).
func _next_summon_class(caster: Node, classes: Array) -> String:
	var counts := {}
	for c in classes:
		counts[c] = 0
	for u in get_tree().get_nodes_in_group("units"):
		if u.is_alive() and u.get("is_summon") and u.get("summoner") == caster:
			if counts.has(u.class_id):
				counts[u.class_id] += 1
	var best: String = classes[0]
	var best_n := 999999
	for c in classes:
		if int(counts[c]) < best_n:
			best_n = int(counts[c])
			best = c
	return best


# Recule le lanceur de `steps` cases dans la direction opposée à `from_cell`
# (sur l'axe dominant), en s'arrêtant à la dernière case libre rencontrée.
func _retreat(unit: Node, from_cell: Vector2i, steps: int) -> void:
	var diff: Vector2i = unit.grid_position - from_cell
	var dir: Vector2i
	if abs(diff.x) >= abs(diff.y):
		dir = Vector2i(sign(diff.x), 0)
	else:
		dir = Vector2i(0, sign(diff.y))
	if dir == Vector2i.ZERO:
		dir = Vector2i(-1, 0)
	var occ := _occupied(unit)
	var dest: Vector2i = unit.grid_position
	for i in range(1, steps + 1):
		var c: Vector2i = unit.grid_position + dir * i
		if not grid.is_inside(c) or occ.has(c):
			break
		dest = c
	if dest != unit.grid_position:
		unit.move_to(dest)


# Première case libre adjacente à une cible (pour la téléportation).
func _free_adjacent(cell: Vector2i, caster: Node):
	var occ := _occupied(caster)
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = cell + dir
		if grid.is_inside(c) and not occ.has(c):
			return c
	return null


# Génère le terrain tactique au centre de la grille (évite les zones de spawn).
func _generate_terrain() -> void:
	var types: Array = GameData.TERRAIN.keys()
	var placed := 0
	var attempts := 0
	while placed < 12 and attempts < 80:
		attempts += 1
		var col: int = 2 + randi() % 8  # colonnes 2-9 (zones de spawn : 1 et 10)
		var row: int = randi() % grid.ROWS
		var cell := Vector2i(col, row)
		if not grid.terrain.has(cell):
			grid.terrain[cell] = types[randi() % types.size()]
			placed += 1
	grid.queue_redraw()


func _target_has_buff(unit: Node, id: String) -> bool:
	for b in unit.buffs:
		if b.get("id", "") == id:
			return true
	return false


# --- Utilitaires ---

func _is_healer(unit: Node) -> bool:
	return unit.data.behavior == "heal"


# Multiplicateur de dégâts selon la difficulté et le camp de l'attaquant.
func _difficulty_damage_mult(unit: Node) -> float:
	var d: Dictionary = GameData.DIFFICULTIES[GameData.difficulty]
	return float(d.player_damage_mult if unit.is_player() else d.ai_damage_mult)


# Cases des cibles valides : alliés blessés (soigneur) ou ennemis (autres).
func _action_targets(unit: Node) -> Array:
	var cells: Array = []
	for u in get_tree().get_nodes_in_group("units"):
		if not u.is_alive():
			continue
		if grid.manhattan(unit.grid_position, u.grid_position) > unit.action_range():
			continue
		if _is_healer(unit):
			if u.team == unit.team and u.hp < int(u.data.max_hp):
				cells.append(u.grid_position)
		elif u.team != unit.team:
			cells.append(u.grid_position)
	return cells


func _unit_at(cell: Vector2i) -> Node:
	for u in get_tree().get_nodes_in_group("units"):
		if u.is_alive() and u.grid_position == cell:
			return u
	return null


func _occupied(except: Node = null) -> Dictionary:
	var occ := {}
	for u in get_tree().get_nodes_in_group("units"):
		if u != except and u.is_alive():
			occ[u.grid_position] = u
	return occ

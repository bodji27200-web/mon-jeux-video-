extends Node2D

# Orchestrateur du combat : relie tours, entrées du joueur et actions.

@onready var grid: Node2D = $Grid
@onready var turn_manager: Node = $TurnManager
@onready var end_label: Label = $UI/EndLabel
@onready var replay_button: Button = $UI/RejouerButton
@onready var skill_hint: Label = $UI/SkillHint

const UNIT_SCENE := preload("res://Unit.tscn")

# Barre de compétences : 3 carrés en bas à droite. Le carré 0 = compétence
# active de la classe ; les carrés 1 et 2 sont des emplacements vides réservés
# pour de futures compétences. Icône courte par type de compétence.
const SKILL_SLOTS := 3
const SKILL_ICONS := {
	"invoke": "Inv", "roots": "Rac", "war_heal": "Soin", "double_dot": "DoT",
	"drain_strike": "Drain", "mark_shot": "Marq", "empower_ally": "Force",
	"shield_ally": "Bouc", "purify": "Pur", "frost_nova": "Gel",
	"teleport_strike": "Saut", "piercing_shot": "Perce", "traps": "Piège",
	"summon_pick": "Inv2",
}

var active_unit: Node = null
var phase := "idle"  # "move", "attack" puis éventuellement "skill" (joueur)
var _finished := false
var skill_slots: Array = []  # boutons de la barre de compétences


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


# Met à jour la barre de 3 carrés selon l'unité active et la phase.
# Carré 0 = compétence de la classe (cliquable si prête en phase d'action) ;
# carrés 1 et 2 = emplacements vides (réservés pour de futures compétences).
func _refresh_skill_bar() -> void:
	var show_bar: bool = active_unit != null and active_unit.is_player() \
			and phase in ["move", "attack", "skill"]
	for b in skill_slots:
		b.visible = show_bar
	if not show_bar:
		skill_hint.visible = false
		return
	var s0: Button = skill_slots[0]
	if active_unit.has_active():
		var sk: Dictionary = active_unit.data.active
		s0.text = str(SKILL_ICONS.get(sk.type, "Comp"))
		s0.tooltip_text = str(sk.name) + "\n" + str(sk.get("desc", ""))
		var usable: bool = phase in ["attack", "skill"] and active_unit.skill_ready()
		s0.disabled = not usable
		s0.modulate = Color(1.0, 1.0, 0.4) if phase == "skill" else Color(1, 1, 1)
	else:
		s0.text = "—"
		s0.disabled = true
		s0.modulate = Color(1, 1, 1)
	# Emplacements vides (futures compétences).
	for i in range(1, SKILL_SLOTS):
		skill_slots[i].text = ""
		skill_slots[i].disabled = true
		skill_slots[i].modulate = Color(0.45, 0.45, 0.5)
	# Indication textuelle quand une compétence est sélectionnée.
	if phase == "skill" and active_unit.has_active():
		skill_hint.text = "Compétence : %s — clique une cible (ou reclique le carré pour annuler)" % str(active_unit.data.active.name)
		skill_hint.visible = true
	else:
		skill_hint.visible = false


func _ai_take_turn(unit: Node) -> void:
	await get_tree().create_timer(0.35).timeout
	var plan := TacticalAI.decide(unit, grid, get_tree().get_nodes_in_group("units"))
	if plan.move != unit.grid_position:
		unit.move_to(plan.move)
		await get_tree().create_timer(0.35).timeout
	# L'IA utilise sa compétence si elle l'a jugée utile, sinon attaque normale.
	if plan.get("skill_cell") != null and unit.skill_ready():
		_use_skill(unit, plan.skill_cell)
	elif plan.target != null and plan.target.is_alive() \
			and grid.manhattan(unit.grid_position, plan.target.grid_position) <= unit.action_range():
		_perform_action(unit, plan.target)
	await get_tree().create_timer(0.2).timeout
	_end_turn()


# Clic sur un carré de compétence : le carré 0 (dé)sélectionne la compétence.
# Recliquer le carré déjà sélectionné annule (retour à l'attaque normale).
func _on_skill_slot(index: int) -> void:
	if index != 0:  # carrés 1 et 2 vides pour l'instant
		return
	if active_unit == null or not active_unit.is_player():
		return
	if phase == "attack":
		_enter_skill_phase()
	elif phase == "skill":
		_enter_action_phase()  # annuler -> retour à l'attaque


func _enter_skill_phase() -> void:
	phase = "skill"
	grid.target_cells = []
	grid.heal_cells = []
	grid.skill_cells = _skill_targets(active_unit)
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
		_use_skill(active_unit, cell)
		_end_turn()


# Soin si soigneur, sinon attaque (avec coup critique éventuel).
func _perform_action(unit: Node, target: Node) -> void:
	if _is_healer(unit):
		target.heal(int(unit.data.heal))
	else:
		_attack(unit, target)
	unit.has_acted = true


# Attaque de base : dégâts, critique, terrain, marque, drain, debuff.
func _attack(unit: Node, target: Node) -> void:
	var dmg: float = unit.data.attack
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

# Cases ciblables par la compétence de l'unité (alliés, ennemis ou ligne).
func _skill_targets(unit: Node) -> Array:
	var cells: Array = []
	if not unit.skill_ready():
		return cells
	var sk: Dictionary = unit.data.active
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


# Applique l'effet de la compétence selon son type (data-driven, extensible).
func _use_skill(caster: Node, cell: Vector2i) -> void:
	var sk: Dictionary = caster.data.active
	var success := true
	match sk.type:
		"shield_ally":
			var ally := _unit_at(cell)
			if ally:
				ally.add_buff("bouclier")
		"empower_ally":
			var ally := _unit_at(cell)
			if ally:
				ally.add_buff("force")
		"purify":
			var ally := _unit_at(cell)
			if ally:
				ally.purge_debuffs()
		"war_heal":
			var ally := _unit_at(cell)
			if ally:
				ally.heal(int(sk.get("heal_amount", 12)))
		"roots":
			var enemy := _unit_at(cell)
			if enemy:
				enemy.add_buff("racines")
		"double_dot":
			var enemy := _unit_at(cell)
			if enemy:
				enemy.add_buff("poison")
				enemy.add_buff("brulure")
		"mark_shot":
			var enemy := _unit_at(cell)
			if enemy:
				enemy.add_buff("marque")
		"drain_strike":
			var enemy := _unit_at(cell)
			if enemy:
				_attack(caster, enemy)
				# Drain supplémentaire : soigne 60% de l'attaque de base en PV
				caster.heal(int(round(float(caster.data.attack) * 0.60)))
		"teleport_strike":
			var enemy := _unit_at(cell)
			if enemy:
				var dest = _free_adjacent(cell, caster)
				if dest != null:
					caster.move_to(dest)
				_attack(caster, enemy)
		"frost_nova":
			var radius: int = int(sk.get("radius", 1))
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
	if success:
		caster.start_skill_cooldown()
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

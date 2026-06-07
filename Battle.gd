extends Node2D

# Orchestrateur du combat : relie tours, entrées du joueur et actions.

@onready var grid: Node2D = $Grid
@onready var turn_manager: Node = $TurnManager
@onready var end_label: Label = $UI/EndLabel
@onready var replay_button: Button = $UI/RejouerButton

const UNIT_SCENE := preload("res://Unit.tscn")

var active_unit: Node = null
var phase := "idle"  # "move" puis "attack" pendant le tour du joueur
var _finished := false


func _ready() -> void:
	_spawn_units()
	replay_button.pressed.connect(_on_replay)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.start()


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
	grid.move_cells = grid.get_reachable_cells(unit.grid_position, unit.data.move_range, _occupied(unit))
	grid.target_cells = []
	grid.heal_cells = []
	grid.queue_redraw()


func _enter_action_phase() -> void:
	phase = "attack"
	grid.move_cells = []
	if _is_healer(active_unit):
		grid.heal_cells = _action_targets(active_unit)
		grid.target_cells = []
	else:
		grid.target_cells = _action_targets(active_unit)
		grid.heal_cells = []
	grid.queue_redraw()


func _ai_take_turn(unit: Node) -> void:
	await get_tree().create_timer(0.35).timeout
	var plan := TacticalAI.decide(unit, grid, get_tree().get_nodes_in_group("units"))
	if plan.move != unit.grid_position:
		unit.move_to(plan.move)
		await get_tree().create_timer(0.35).timeout
	if plan.target != null and plan.target.is_alive() \
			and grid.manhattan(unit.grid_position, plan.target.grid_position) <= int(unit.data.attack_range):
		_perform_action(unit, plan.target)
	await get_tree().create_timer(0.2).timeout
	_end_turn()


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


# Soin si soigneur, sinon attaque (avec coup critique éventuel).
func _perform_action(unit: Node, target: Node) -> void:
	if _is_healer(unit):
		target.heal(int(unit.data.heal))
	else:
		var dmg: float = unit.data.attack
		if randf() < unit.data.crit_chance:
			dmg *= 2.0
		dmg *= unit.damage_dealt_mult() * target.damage_taken_mult()
		dmg *= _difficulty_damage_mult(unit)
		target.take_damage(int(round(dmg)))
		# Certaines classes infligent un debuff au contact.
		if unit.data.has("on_hit") and target.is_alive():
			target.add_buff(unit.data.on_hit)
	unit.has_acted = true


func _end_turn() -> void:
	grid.move_cells = []
	grid.target_cells = []
	grid.heal_cells = []
	grid.queue_redraw()
	phase = "idle"
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
		if grid.manhattan(unit.grid_position, u.grid_position) > int(unit.data.attack_range):
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

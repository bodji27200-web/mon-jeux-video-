extends Node2D

# Orchestrateur du combat : relie tours, entrées du joueur et actions.

@onready var grid: Node2D = $Grid
@onready var turn_manager: Node = $TurnManager

var active_unit: Node = null
var phase := "idle"  # "move" : en attente d'un clic de déplacement


func _ready() -> void:
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.start()


func _on_turn_started(unit: Node) -> void:
	active_unit = unit
	if unit.is_player():
		_show_moves(unit)
	else:
		_ai_take_turn(unit)


func _show_moves(unit: Node) -> void:
	grid.move_cells = grid.get_reachable_cells(unit.grid_position, unit.data.move_range, _occupied(unit))
	grid.queue_redraw()
	phase = "move"


func _ai_take_turn(_unit: Node) -> void:
	# Étape 3 : l'IA passe son tour (vraie IA à l'étape 5).
	await get_tree().create_timer(0.4).timeout
	_end_turn()


func _unhandled_input(event: InputEvent) -> void:
	if active_unit == null or not active_unit.is_player():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(grid.local_to_cell(grid.to_local(get_global_mouse_position())))
	elif event.is_action_pressed("ui_accept"):
		_end_turn()


func _handle_click(cell: Vector2i) -> void:
	if phase == "move" and cell in grid.move_cells:
		active_unit.move_to(cell)
		_end_turn()


func _end_turn() -> void:
	grid.move_cells = []
	grid.target_cells = []
	grid.queue_redraw()
	phase = "idle"
	turn_manager.next_turn()


# Dictionnaire {case: unité} des cases occupées par une unité vivante.
func _occupied(except: Node = null) -> Dictionary:
	var occ := {}
	for u in get_tree().get_nodes_in_group("units"):
		if u != except and u.is_alive():
			occ[u.grid_position] = u
	return occ

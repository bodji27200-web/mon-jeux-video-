extends Node2D

# Une unité de combat. Toutes ses caractéristiques viennent de GameData.CLASSES
# (data-driven : aucune stat codée en dur ici).

@export var class_id := "tank"
@export var team: int = 0  # 0 = Joueur, 1 = IA
@export var grid_position := Vector2i.ZERO

const RADIUS := 22.0

var data: Dictionary = {}
var hp := 0
var has_moved := false
var has_acted := false
var buffs: Array = []  # buffs/debuffs actifs (étape 8)
var _active := false


func _ready() -> void:
	add_to_group("units")
	data = GameData.CLASSES[class_id]
	hp = data.max_hp
	_refresh_position()


func _refresh_position() -> void:
	var grid := get_parent()
	if grid and grid.has_method("cell_to_local"):
		position = grid.cell_to_local(grid_position)


func is_player() -> bool:
	return team == GameData.Team.PLAYER


func is_alive() -> bool:
	return hp > 0


func move_to(cell: Vector2i) -> void:
	grid_position = cell
	_refresh_position()
	has_moved = true


func set_active(active: bool) -> void:
	_active = active
	queue_redraw()


func reset_turn() -> void:
	has_moved = false
	has_acted = false


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, data.color)
	# Symbole de la classe
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-6, 6), str(data.symbol), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.BLACK)
	# Barre de vie
	var ratio := clampf(float(hp) / float(data.max_hp), 0.0, 1.0)
	var bar_y := -RADIUS - 10.0
	draw_rect(Rect2(-RADIUS, bar_y, RADIUS * 2.0, 5), Color(0.15, 0.0, 0.0))
	draw_rect(Rect2(-RADIUS, bar_y, RADIUS * 2.0 * ratio, 5), Color(0.20, 0.85, 0.25))
	if _active:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 32, Color(1, 1, 0.4), 3.0)

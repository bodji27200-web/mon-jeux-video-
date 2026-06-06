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


func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	queue_redraw()
	if hp == 0:
		visible = false


func heal(amount: int) -> void:
	hp = min(int(data.max_hp), hp + amount)
	queue_redraw()


# --- Buffs / debuffs ---

func add_buff(id: String) -> void:
	if not GameData.BUFFS.has(id):
		return
	var b: Dictionary = GameData.BUFFS[id].duplicate()
	b["id"] = id
	buffs.append(b)
	queue_redraw()


# Appliqué au début du tour de l'unité : dégâts/soins périodiques + expiration.
func tick_buffs() -> void:
	var remaining: Array = []
	for b in buffs:
		if b.has("dmg_per_turn"):
			take_damage(int(b.dmg_per_turn))
		if b.has("heal_per_turn"):
			heal(int(b.heal_per_turn))
		b.duration -= 1
		if b.duration > 0 and is_alive():
			remaining.append(b)
	buffs = remaining
	queue_redraw()


func damage_taken_mult() -> float:
	var m := 1.0
	for b in buffs:
		if b.has("dmg_taken_mult"):
			m *= float(b.dmg_taken_mult)
	return m


func damage_dealt_mult() -> float:
	var m := 1.0
	for b in buffs:
		if b.has("dmg_dealt_mult"):
			m *= float(b.dmg_dealt_mult)
	return m


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
	# Pastilles des buffs/debuffs actifs.
	var bx := -RADIUS
	for b in buffs:
		var c := Color(0.7, 0.7, 0.7)
		if b.has("dmg_per_turn"):
			c = Color(0.85, 0.20, 0.20)
		elif b.has("heal_per_turn"):
			c = Color(0.20, 0.85, 0.30)
		elif b.has("dmg_taken_mult"):
			c = Color(0.30, 0.50, 1.00)
		elif b.has("dmg_dealt_mult"):
			c = Color(0.95, 0.60, 0.20)
		draw_circle(Vector2(bx + 4.0, RADIUS + 12.0), 4.0, c)
		bx += 11.0

extends Node2D

# Une unité de combat. Toutes ses caractéristiques viennent de GameData.CLASSES
# (data-driven : aucune stat codée en dur ici).

@export var class_id := "tank"
@export var team: int = 0  # 0 = Joueur, 1 = IA
@export var grid_position := Vector2i.ZERO

const RADIUS := 22.0
const FLOATING_TEXT := preload("res://FloatingText.tscn")

var data: Dictionary = {}
var hp := 0
var has_moved := false
var has_acted := false
var skill_cds: Array = []  # cooldown restant par compétence (aligné sur get_actives())
var buffs: Array = []
var is_summon := false   # true = invoqué par un nécromancien
var summoner: Node = null
var _active := false


func _ready() -> void:
	add_to_group("units")
	data = GameData.CLASSES[class_id]
	hp = data.max_hp
	skill_cds.resize(get_actives().size())
	skill_cds.fill(0)
	_refresh_position()


func _refresh_position() -> void:
	var grid := get_parent()
	if grid and grid.has_method("cell_to_local"):
		position = grid.cell_to_local(grid_position)


func is_player() -> bool:
	return team == GameData.Team.PLAYER


func is_alive() -> bool:
	return hp > 0


# Portée d'action effective : portée de soin pour un soigneur, sinon d'attaque.
func action_range() -> int:
	if data.behavior == "heal":
		return int(data.get("heal_range", data.attack_range))
	return int(data.attack_range)


# Déplacement effectif : 0 si immobilisé (racines), sinon réduit par gel, min 1.
func move_range() -> int:
	for b in buffs:
		if b.get("immobilized", false):
			return 0
	var m := int(data.move_range)
	for b in buffs:
		if b.has("move_penalty"):
			m -= int(b.move_penalty)
	return max(1, m)


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
	# Chaque compétence recharge indépendamment au fil des tours de l'unité.
	for i in skill_cds.size():
		if skill_cds[i] > 0:
			skill_cds[i] -= 1


# --- Compétences actives (jusqu'à 3 par classe, via "actives") ---
# Compatibilité : si une classe utilise encore l'ancien champ "active" (dict
# unique), il est renvoyé comme une liste d'un élément.

func get_actives() -> Array:
	if data.has("actives"):
		return data.actives
	if data.has("active"):
		return [data.active]
	return []


func skill_count() -> int:
	return get_actives().size()


func has_active() -> bool:
	return skill_count() > 0


# Une compétence précise (par index) est-elle utilisable ce tour-ci ?
func skill_ready(index := 0) -> bool:
	var acts: Array = get_actives()
	if index < 0 or index >= acts.size():
		return false
	if index < skill_cds.size() and skill_cds[index] > 0:
		return false
	var sk: Dictionary = acts[index]
	if sk.has("max_summons"):
		return _count_summons() < int(sk.max_summons)
	return true


# Au moins une compétence est-elle prête ? (pour l'affichage / l'IA)
func any_skill_ready() -> bool:
	for i in get_actives().size():
		if skill_ready(i):
			return true
	return false


func start_skill_cooldown(index := 0) -> void:
	var acts: Array = get_actives()
	if index < 0 or index >= acts.size():
		return
	if skill_cds.size() < acts.size():
		skill_cds.resize(acts.size())
	skill_cds[index] = int(acts[index].cooldown)


func _count_summons() -> int:
	var n := 0
	for u in get_tree().get_nodes_in_group("units"):
		if u != self and u.is_alive() and u.get("is_summon") and u.get("summoner") == self:
			n += 1
	return n


func take_damage(amount: int, is_crit := false) -> void:
	hp = max(0, hp - amount)
	if amount > 0:
		_show_damage_text(amount, is_crit)
	queue_redraw()
	if hp == 0:
		visible = false


# Affiche un texte flottant de dégâts au-dessus de l'unité (rouge si critique).
func _show_damage_text(amount: int, is_crit: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ft := FLOATING_TEXT.instantiate()
	if is_crit:
		ft.text = "CRITIQUE !\n-%d" % amount
		ft.color_value = Color(1.0, 0.25, 0.20)
		ft.font_size_value = 26
		ft.duration = 1.4
	else:
		ft.text = "-%d" % amount
		ft.color_value = Color(1.0, 0.95, 0.60)
		ft.font_size_value = 20
		ft.duration = 1.0
	ft.position = position + Vector2(-14.0, -46.0)
	parent.add_child(ft)


func heal(amount: int) -> void:
	hp = min(int(data.max_hp), hp + amount)
	if hp > 0:
		visible = true  # une unité avec des PV doit rester visible (filet de sécurité)
	queue_redraw()


# --- Buffs / debuffs ---

func add_buff(id: String) -> void:
	if not GameData.BUFFS.has(id):
		return
	# Re-appliquer un effet déjà présent rafraîchit sa durée (pas d'empilement).
	for b in buffs:
		if b.get("id", "") == id:
			b.duration = int(GameData.BUFFS[id].duration)
			queue_redraw()
			return
	var nb: Dictionary = GameData.BUFFS[id].duplicate()
	nb["id"] = id
	buffs.append(nb)
	queue_redraw()


# Retire les effets négatifs (DoT, gel, racines, affaiblissement, vulnérabilité).
func purge_debuffs() -> void:
	var kept: Array = []
	for b in buffs:
		if b.has("dmg_per_turn") or b.has("move_penalty") \
				or b.get("immobilized", false) \
				or (b.has("dmg_dealt_mult") and float(b.dmg_dealt_mult) < 1.0) \
				or (b.has("dmg_taken_mult") and float(b.dmg_taken_mult) > 1.0):
			continue
		kept.append(b)
	buffs = kept
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
			c = Color(0.30, 0.50, 1.00) if float(b.dmg_taken_mult) < 1.0 else Color(0.80, 0.15, 0.15)
		elif b.has("dmg_dealt_mult"):
			c = Color(0.95, 0.60, 0.20) if float(b.dmg_dealt_mult) >= 1.0 else Color(0.70, 0.20, 0.70)
		elif b.has("move_penalty"):
			c = Color(0.55, 0.85, 1.00)
		elif b.get("immobilized", false):
			c = Color(0.20, 0.82, 0.20)
		elif b.get("marked", false):
			c = Color(0.95, 0.80, 0.10)
		elif b.get("riposte", false):
			c = Color(0.95, 0.45, 0.20)
		elif b.get("block_next", false):
			c = Color(0.45, 0.85, 1.00)
		draw_circle(Vector2(bx + 4.0, RADIUS + 12.0), 4.0, c)
		bx += 11.0

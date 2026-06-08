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
	var col: Color = data.color
	var dark: Color = col.darkened(0.5)
	var team_tint := Color(0.35, 0.6, 1.0) if is_player() else Color(1.0, 0.4, 0.35)

	# --- Anneau de sol : couleur du camp (doré quand c'est son tour) ---
	var ring_col: Color = Color(1.0, 0.9, 0.35) if _active else team_tint
	_draw_ellipse(Vector2(0, 17), 16.0, 6.0, Color(ring_col, 0.20))
	_draw_ellipse_outline(Vector2(0, 17), 17.0, 7.0, Color(ring_col, 0.95), 3.0 if _active else 2.0)
	# Ombre portée
	_draw_ellipse(Vector2(0, 18), 12.0, 4.5, Color(0, 0, 0, 0.28))

	# --- Personnage : corps (robe) + tête avec des yeux ---
	var robe := PackedVector2Array([Vector2(-9, -5), Vector2(9, -5), Vector2(13, 17), Vector2(-13, 17)])
	draw_colored_polygon(robe, col)
	# Bas de robe assombri (profondeur)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, 12), Vector2(13, 12), Vector2(13, 17), Vector2(-13, 17)]), dark)
	var robe_outline := PackedVector2Array(robe)
	robe_outline.append(robe[0])
	draw_polyline(robe_outline, dark, 1.5)
	# Tête
	var head_col: Color = col.lightened(0.4)
	draw_circle(Vector2(0, -13), 8.0, head_col)
	draw_arc(Vector2(0, -13), 8.0, 0.0, TAU, 20, dark, 1.5)
	draw_circle(Vector2(-3, -14), 1.4, Color(0.10, 0.10, 0.12))
	draw_circle(Vector2(3, -14), 1.4, Color(0.10, 0.10, 0.12))

	# --- Arme selon le profil de la classe ---
	_draw_weapon(_weapon_kind(), col, dark)

	# --- Symbole de classe sur le torse (identification précise) ---
	var font := ThemeDB.fallback_font
	var lum: float = col.r * 0.299 + col.g * 0.587 + col.b * 0.114
	var sym_col: Color = Color.BLACK if lum > 0.55 else Color(1, 1, 1, 0.92)
	draw_string(font, Vector2(-4.5, 8.0), str(data.symbol), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sym_col)

	# --- Barre de vie (verte / jaune / rouge selon les PV) ---
	var ratio := clampf(float(hp) / float(data.max_hp), 0.0, 1.0)
	var bar_y := -RADIUS - 10.0
	draw_rect(Rect2(-RADIUS, bar_y, RADIUS * 2.0, 5), Color(0.15, 0.0, 0.0))
	var hp_col := Color(0.20, 0.85, 0.25)
	if ratio < 0.3:
		hp_col = Color(0.90, 0.25, 0.20)
	elif ratio < 0.6:
		hp_col = Color(0.92, 0.75, 0.20)
	draw_rect(Rect2(-RADIUS, bar_y, RADIUS * 2.0 * ratio, 5), hp_col)

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


# Type d'arme dessinée, déduit du rôle / profil de la classe (data-driven).
func _weapon_kind() -> String:
	match str(data.get("role", "melee")):
		"tank":
			return "shield"
		"healer":
			return "staff"
		"ranged":
			if class_id in ["archer", "archere", "chasseur", "squelette_archer"]:
				return "bow"
			return "staff"
		_:
			return "spear" if int(data.attack_range) >= 2 else "sword"


# Dessine l'arme tenue par le personnage (cosmétique, à droite sauf le bouclier).
func _draw_weapon(kind: String, col: Color, dark: Color) -> void:
	var steel := Color(0.78, 0.80, 0.86)
	var steel_d := Color(0.45, 0.47, 0.54)
	var wood := Color(0.45, 0.30, 0.16)
	match kind:
		"sword":
			draw_line(Vector2(15, 8), Vector2(15, -15), steel, 3.0)
			draw_line(Vector2(15, 8), Vector2(15, -15), Color(1, 1, 1, 0.5), 1.0)
			draw_line(Vector2(9, -2), Vector2(21, -2), steel_d, 3.0)   # garde
			draw_circle(Vector2(15, 10), 2.4, Color(0.85, 0.70, 0.25))  # pommeau
		"spear":
			draw_line(Vector2(16, 15), Vector2(16, -18), wood, 2.5)
			draw_colored_polygon(PackedVector2Array([
				Vector2(16, -25), Vector2(12, -16), Vector2(20, -16)]), steel)
		"shield":
			var sh := PackedVector2Array([
				Vector2(-21, -9), Vector2(-8, -9), Vector2(-8, 3),
				Vector2(-14, 12), Vector2(-21, 3)])
			draw_colored_polygon(sh, steel)
			var sh_o := PackedVector2Array(sh)
			sh_o.append(sh[0])
			draw_polyline(sh_o, steel_d, 1.5)
			draw_circle(Vector2(-14, -2), 3.0, col)  # emblème (couleur de classe)
		"bow":
			draw_arc(Vector2(13, 0), 15.0, -1.15, 1.15, 16, wood, 2.5)
			var top := Vector2(13, 0) + Vector2(cos(-1.15), sin(-1.15)) * 15.0
			var bot := Vector2(13, 0) + Vector2(cos(1.15), sin(1.15)) * 15.0
			draw_line(top, bot, Color(0.85, 0.85, 0.80, 0.85), 1.0)  # corde
			draw_line(Vector2(2, 0), Vector2(21, 0), steel_d, 1.5)   # flèche
		"staff":
			draw_line(Vector2(16, 16), Vector2(16, -14), wood, 2.5)
			draw_circle(Vector2(16, -16), 5.0, Color(col, 0.45))      # halo
			draw_circle(Vector2(16, -16), 3.0, col.lightened(0.3))    # orbe


# Dessine une ellipse pleine (pas de primitive native).
func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 22:
		var a := TAU * i / 22.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


# Dessine le contour d'une ellipse.
func _draw_ellipse_outline(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 23:
		var a := TAU * i / 22.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, color, width)

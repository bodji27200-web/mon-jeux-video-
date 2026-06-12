extends Node2D

# Une unité de combat. Toutes ses caractéristiques viennent de GameData.CLASSES
# (data-driven : aucune stat codée en dur ici).

@export var class_id := "tank"
@export var team: int = 0  # 0 = Joueur, 1 = IA
@export var grid_position := Vector2i.ZERO

const RADIUS := 22.0
const FLOATING_TEXT := preload("res://FloatingText.tscn")

# Sprites de personnages (pack CC0 "DungeonTileset II" de 0x72, voir assets/CREDITS.md).
# Chaque entrée = rect de la 1re frame idle [x, y, largeur, hauteur] dans la sheet ;
# l'animation idle compte 4 frames disposées horizontalement (frame i à x + i*largeur).
const TILESET := preload("res://assets/dungeon_tileset.png")
const SPRITE_FRAMES := 4
const SPRITE_ANIM_SPEED := 0.18  # secondes par frame
const SPRITES := {
	"tank":            Rect2(128, 106, 16, 22),  # knight_m
	"paladin":         Rect2(128, 74, 16, 22),   # knight_f
	"archer":          Rect2(128, 42, 16, 22),   # elf_m
	"archere":         Rect2(128, 16, 16, 16),   # elf_f
	"mage":            Rect2(128, 170, 16, 22),  # wizzard_m
	"soigneur":        Rect2(128, 132, 16, 28),  # wizzard_f
	"assassin":        Rect2(432, 240, 16, 13),  # créature sombre (tight bounds)
	"duelliste":       Rect2(128, 205, 16, 19),  # lizard_f
	"berserker":       Rect2(368, 204, 16, 20),  # orc_warrior
	"lancier":         Rect2(368, 172, 16, 20),  # masked_orc
	"chevaliernoir":   Rect2(368, 328, 16, 24),  # chort
	"mage_glace":      Rect2(368, 236, 16, 20),  # orc_shaman
	"necromancien":    Rect2(366, 270, 16, 20),  # necromancer
	"envouteur":       Rect2(368, 48, 16, 16),   # imp
	"druide":          Rect2(128, 448, 16, 13),  # hero_12 recadré (tight bounds)
	"alchimiste":      Rect2(128, 271, 16, 28),  # hero_9 recadré (tight bounds)
	"chasseur":        Rect2(128, 325, 16, 26),  # guerrier vert = rôle chasseur/rôdeur
	"pretreguerrier":  Rect2(128, 237, 16, 19),  # lizard_m
	"invocateur":      Rect2(16, 364, 32, 36),   # big_demon
	# barde : pas de sprite — cette zone de la sheet n'est pas une vraie strip
	# idle 4-frames (frames incohérentes → figurine "coupée"). Repli vectoriel
	# (figurine dorée en robe + bâton), cohérent avec son rôle de soutien.
	"squelette_guerrier": Rect2(368, 80, 16, 16),  # skelet
	"squelette_archer":   Rect2(368, 80, 16, 16),  # skelet
	"golem_pierre":    Rect2(16, 320, 32, 32),   # ogre
	"loup_spectral":   Rect2(432, 144, 16, 16),  # ice_zombie
}

var data: Dictionary = {}
var display_name := ""  # nom affiché (héros de campagne) ; vide = nom de classe
var has_katana := false  # Katana d'améthyste équipé (Duelliste) : aura violette
var hp := 0
var has_moved := false
var has_acted := false
var skill_cds: Array = []  # cooldown restant par compétence (aligné sur get_actives())
var buffs: Array = []
var is_summon := false   # true = invoqué par un nécromancien
var summoner: Node = null
var _active := false
var _frame := 0          # frame d'animation idle courante
var _anim_t := 0.0
var _anim_phase := 0.0   # phase continue (figures de campagne, animation fluide)
var _move_tween: Tween   # glissement de déplacement en cours (cosmétique)


func _ready() -> void:
	add_to_group("units")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art net (pas de flou)
	data = GameData.CLASSES[class_id]
	hp = data.max_hp
	_frame = randi() % SPRITE_FRAMES  # désynchronise l'animation entre unités
	_anim_phase = randf() * TAU
	skill_cds.resize(get_actives().size())
	skill_cds.fill(0)
	_refresh_position()


# Animation idle : frames du sprite, ou phase continue pour les figures dessinées.
func _process(delta: float) -> void:
	if not is_alive():
		return
	if data.has("figure") or data.has("figure_npc") or has_katana:
		# Figures de campagne : animation continue mais redessin à 15 i/s
		# seulement (60 redraws/s de vecteurs = trop pour le navigateur Xbox).
		_anim_phase += delta
		_anim_t += delta
		if _anim_t >= 1.0 / 15.0:
			_anim_t = 0.0
			queue_redraw()
		return
	if not SPRITES.has(class_id):
		return
	_anim_t += delta
	if _anim_t >= SPRITE_ANIM_SPEED:
		_anim_t = 0.0
		_frame = (_frame + 1) % SPRITE_FRAMES
		queue_redraw()


# Position écran d'une case, en tenant compte du relief (sommet du plateau).
func _cell_pos(cell: Vector2i) -> Vector2:
	var grid := get_parent()
	if grid and grid.has_method("cell_to_local_raised"):
		return grid.cell_to_local_raised(cell)
	if grid and grid.has_method("cell_to_local"):
		return grid.cell_to_local(cell)
	return position


func _refresh_position() -> void:
	var grid := get_parent()
	if grid and grid.has_method("cell_to_local"):
		position = _cell_pos(grid_position)


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
	grid_position = cell  # logique : la position de grille change tout de suite
	has_moved = true
	var grid := get_parent()
	if grid == null or not grid.has_method("cell_to_local"):
		return
	var target: Vector2 = _cell_pos(cell)
	# En headless (sim de test) : pas d'animation, on saute directement.
	if DisplayServer.get_name() == "headless":
		position = target
		return
	# Sinon : glissement fluide vers la case (effet de marche).
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	var dur: float = clampf(position.distance_to(target) / 340.0, 0.08, 0.30)
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target, dur).set_trans(Tween.TRANS_SINE)


# Petit élan vers une case (coup porté). Cosmétique, ignoré en headless.
func lunge(toward_cell: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var grid := get_parent()
	if grid == null or not grid.has_method("cell_to_local"):
		return
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	var home: Vector2 = _cell_pos(grid_position)
	var tgt: Vector2 = _cell_pos(toward_cell)
	var dir: Vector2 = (tgt - home).normalized() if tgt != home else Vector2.ZERO
	position = home
	var tw := create_tween()
	tw.tween_property(self, "position", home + dir * 12.0, 0.08)
	tw.tween_property(self, "position", home, 0.12)


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

# Campagne : applique la progression du membre (niveaux/arbre). Les stats sont
# boostées et les compétences = UNIQUEMENT celles choisies dans l'arbre.
# `data` est dupliqué pour ne jamais toucher au dictionnaire partagé CLASSES.
func apply_growth(p: Dictionary) -> void:
	data = data.duplicate()
	data.max_hp = int(round(float(data.max_hp) * (1.0 + float(p.get("hp_pct", 0.0)))))
	data.attack = int(data.attack) + int(p.get("atk", 0))
	data.crit_chance = float(data.crit_chance) + float(p.get("crit", 0.0))
	hp = data.max_hp
	data.actives = p.get("skills", [])
	data.erase("active")
	skill_cds.resize(get_actives().size())
	skill_cds.fill(0)


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
	# Centré sur le losange de la case (l'unité "tient" sur sa case).
	# Les boss de campagne ont un anneau élargi (présence).
	var ring_col: Color = Color(1.0, 0.9, 0.35) if _active else team_tint
	var ring_s := 1.3 if data.get("boss", false) else 1.0
	_draw_ellipse(Vector2(0, 4), 25.0 * ring_s, 12.0 * ring_s, Color(ring_col, 0.20))
	_draw_ellipse_outline(Vector2(0, 4), 26.0 * ring_s, 12.5 * ring_s, Color(ring_col, 0.95), 3.0 if _active else 2.0)
	# Ombre de contact sous les pieds.
	_draw_ellipse(Vector2(0, 6), 16.0 * ring_s, 6.0 * ring_s, Color(0, 0, 0, 0.30))

	# --- Personnage : figure de campagne dessinée, sprite, ou figurine repli ---
	if data.has("figure"):
		_draw_figure(str(data.figure))
	elif data.has("figure_npc"):
		# Compagnons de campagne : même figure que dans le monde (Sera, Garin).
		draw_set_transform(Vector2(0, 6))
		Overworld.draw_npc_figure(self, str(data.figure_npc), sin(_anim_phase * 2.0) * 0.8)
		draw_set_transform(Vector2.ZERO)
	elif SPRITES.has(class_id):
		_draw_sprite()
	else:
		draw_set_transform(Vector2(0, -11))  # cale les pieds de la figurine sur l'anneau
		_draw_vector_body(col, dark)
		draw_set_transform(Vector2.ZERO)

	# --- Barre de vie (verte / jaune / rouge selon les PV) ---
	# Les boss n'ont pas de petite barre : la leur trône en haut de l'écran
	# avec leur nom (Battle._build_boss_bar, style Clair Obscur).
	var show_hp_bar: bool = not data.get("boss", false)
	if show_hp_bar:
		var ratio := clampf(float(hp) / float(data.max_hp), 0.0, 1.0)
		var bar_y := -46.0
		draw_rect(Rect2(-RADIUS, bar_y, RADIUS * 2.0, 5), Color(0.15, 0.0, 0.0))
		var hp_col := Color(0.20, 0.85, 0.25)
		if ratio < 0.3:
			hp_col = Color(0.90, 0.25, 0.20)
		elif ratio < 0.6:
			hp_col = Color(0.92, 0.75, 0.20)
		draw_rect(Rect2(-RADIUS, bar_y, RADIUS * 2.0 * ratio, 5), hp_col)

	# Pastilles des buffs/debuffs actifs (icône + couleur codée).
	var bx := -RADIUS
	for b in buffs:
		var c := Color(0.7, 0.7, 0.7)
		var icon := "•"
		if b.has("dmg_per_turn"):
			c = Color(0.85, 0.20, 0.20);    icon = "☠"
		elif b.has("heal_per_turn"):
			c = Color(0.20, 0.85, 0.30);    icon = "♥"
		elif b.has("dmg_taken_mult"):
			if float(b.dmg_taken_mult) < 1.0:
				c = Color(0.30, 0.50, 1.00); icon = "⊕"
			else:
				c = Color(0.80, 0.15, 0.15); icon = "△"
		elif b.has("dmg_dealt_mult"):
			if float(b.dmg_dealt_mult) >= 1.0:
				c = Color(0.95, 0.60, 0.20); icon = "▲"
			else:
				c = Color(0.70, 0.20, 0.70); icon = "▼"
		elif b.has("move_penalty"):
			c = Color(0.55, 0.85, 1.00);    icon = "❄"
		elif b.get("immobilized", false):
			c = Color(0.20, 0.82, 0.20);    icon = "✦"
		elif b.get("marked", false):
			c = Color(0.95, 0.80, 0.10);    icon = "★"
		elif b.get("riposte", false):
			c = Color(0.95, 0.45, 0.20);    icon = "↺"
		elif b.get("block_next", false):
			c = Color(0.45, 0.85, 1.00);    icon = "◈"
		var dot_pos := Vector2(bx + 5.0, 20.0)
		draw_circle(dot_pos, 6.5, c)
		var dfont := ThemeDB.fallback_font
		draw_string(dfont, dot_pos + Vector2(-5.0, 4.5), icon,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.92))
		bx += 16.0


# Dessine le sprite du personnage (frame idle courante), mis à l'échelle pour
# tenir dans la case et posé sur l'anneau de sol. Pixel art net (filtre nearest).
func _draw_sprite() -> void:
	var f0: Rect2 = SPRITES[class_id]
	var src := Rect2(f0.position.x + _frame * f0.size.x, f0.position.y, f0.size.x, f0.size.y)
	var target_h := 42.0                       # hauteur visée à l'écran
	var scale: float = target_h / f0.size.y
	var w: float = f0.size.x * scale
	var h: float = f0.size.y * scale
	# Centré horizontalement, pieds calés sur l'anneau de sol (centre de la case).
	var dest := Rect2(-w / 2.0, 6.0 - h, w, h)
	draw_texture_rect_region(TILESET, dest, src)


# Repli vectoriel (figurine dessinée) pour toute classe sans sprite mappé.
func _draw_vector_body(col: Color, dark: Color) -> void:
	var robe := PackedVector2Array([Vector2(-9, -5), Vector2(9, -5), Vector2(13, 17), Vector2(-13, 17)])
	draw_colored_polygon(robe, col)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, 12), Vector2(13, 12), Vector2(13, 17), Vector2(-13, 17)]), dark)
	var robe_outline := PackedVector2Array(robe)
	robe_outline.append(robe[0])
	draw_polyline(robe_outline, dark, 1.5)
	var head_col: Color = col.lightened(0.4)
	draw_circle(Vector2(0, -13), 8.0, head_col)
	draw_arc(Vector2(0, -13), 8.0, 0.0, TAU, 20, dark, 1.5)
	draw_circle(Vector2(-3, -14), 1.4, Color(0.10, 0.10, 0.12))
	draw_circle(Vector2(3, -14), 1.4, Color(0.10, 0.10, 0.12))
	if has_katana:
		_draw_katana()
	else:
		_draw_weapon(_weapon_kind(), col, dark)
	var font := ThemeDB.fallback_font
	var lum: float = col.r * 0.299 + col.g * 0.587 + col.b * 0.114
	var sym_col: Color = Color.BLACK if lum > 0.55 else Color(1, 1, 1, 0.92)
	draw_string(font, Vector2(-4.5, 8.0), str(data.symbol), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sym_col)


# LE Katana d'améthyste : longue lame courbe violette, halo pulsant,
# particules d'aura qui remontent le fil. Le petit kiff du jeu.
func _draw_katana() -> void:
	var t := _anim_phase
	var glow := Color(0.72, 0.40, 1.0)
	var pulse := 0.30 + 0.20 * sin(t * 3.2)
	# Lame courbe : trois segments (halo large dessous, cœur clair dessus).
	var pts := PackedVector2Array([
		Vector2(14.0, 9.0), Vector2(19.0, -5.0), Vector2(25.0, -19.0)])
	draw_polyline(pts, Color(glow, pulse), 6.0)
	draw_polyline(pts, Color(glow, pulse + 0.25), 3.2)
	draw_polyline(pts, Color(0.94, 0.86, 1.0), 1.4)
	# Tsuba dorée + poignée sombre tressée.
	draw_circle(Vector2(14.0, 9.0), 2.4, Color(0.85, 0.70, 0.30))
	draw_line(Vector2(14.0, 9.0), Vector2(12.0, 15.0), Color(0.16, 0.10, 0.22), 3.0)
	# Particules d'aura : elles remontent le fil de la lame en boucle.
	for i in 3:
		var k := fposmod(t * 0.7 + float(i) / 3.0, 1.0)
		var p := pts[0].lerp(pts[2], k) + Vector2(sin(t * 4.0 + float(i)) * 1.6, 0.0)
		draw_circle(p, 2.0, Color(glow, (1.0 - k) * 0.5))
		draw_circle(p, 0.9, Color(0.95, 0.85, 1.0, (1.0 - k) * 0.9))
	# Halo d'aura au sol (la lame déteint sur sa porteuse).
	_draw_ellipse(Vector2(0, 15), 16.0, 6.0, Color(glow, pulse * 0.30))


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


# --- Figures de campagne : ennemis dessinés à la main par code (aucun sprite).
# Animées en continu via _anim_phase. Pieds calés sur l'anneau de sol (y = 6).

func _draw_figure(kind: String) -> void:
	match kind:
		"loup":
			_draw_figure_loup()
		"rodeur":
			_draw_figure_rodeur()
		"veilleur":
			_draw_figure_veilleur()
		"traqueur":
			_draw_figure_traqueur()
		"totem":
			_draw_figure_totem()
		"roi":
			_draw_figure_roi()


# BOSS SECRET — Le Traqueur-Roi : grand chasseur à couronne de lames, arc
# d'os, sigil de marque flottant. Tout l'inverse du Veilleur : précis, mobile.
func _draw_figure_roi() -> void:
	var t := _anim_phase
	var breathe := sin(t * 1.8) * 1.5
	var cloak := Color(0.30, 0.10, 0.18)
	var cloak_d := cloak.darkened(0.35)
	var blood := Color(0.95, 0.25, 0.22)
	# Manteau haut et étroit (stature de chasseur, pas de masse).
	var top_y := -46.0 + breathe
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10.0, 5.0), Vector2(10.0, 5.0),
		Vector2(7.0, top_y + 10.0), Vector2(0.0, top_y + 4.0),
		Vector2(-7.0, top_y + 10.0)]), cloak)
	_draw_ellipse(Vector2(0, -20 + breathe * 0.5), 7.0, 12.0, cloak_d)
	# Tête masquée + yeux rouges perçants.
	var hc := Vector2(0, top_y - 2.0)
	draw_circle(hc, 7.0, Color(0.12, 0.06, 0.10))
	for sgn in [-1.0, 1.0]:
		var fs: float = sgn
		draw_circle(hc + Vector2(2.8 * fs, -0.5), 2.0, Color(blood, 0.4))
		draw_circle(hc + Vector2(2.8 * fs, -0.5), 0.9, blood)
	# Couronne de lames (acier froid).
	var steel := Color(0.82, 0.84, 0.92)
	for kx in [-5.0, 0.0, 5.0]:
		var fx: float = kx
		draw_colored_polygon(PackedVector2Array([
			hc + Vector2(fx - 1.6, -5.5), hc + Vector2(fx, -13.0),
			hc + Vector2(fx + 1.6, -5.5)]), steel)
	# Arc d'os tendu (il frappe de loin).
	var bone := Color(0.80, 0.75, 0.65)
	draw_arc(Vector2(-13, -22 + breathe * 0.5), 11.0, PI * 0.65, PI * 1.35, 12, bone, 2.4)
	draw_line(Vector2(-13 - 8, -30 + breathe * 0.5), Vector2(-13 - 8, -14 + breathe * 0.5),
			Color(0.9, 0.9, 0.85, 0.7), 1.0)
	# Sigil de MARQUE flottant (sa mécanique signature, lisible en combat).
	var sa := 0.5 + 0.4 * sin(t * 3.0)
	var sc := Vector2(14.0, -34.0 + sin(t * 2.2) * 2.0)
	draw_arc(sc, 4.0, 0.0, TAU, 12, Color(blood, sa), 1.6)
	draw_circle(sc, 1.4, Color(1.0, 0.6, 0.55, sa))


# Traqueur des ombres : silhouette élancée penchée en avant, double dague,
# volutes d'ombre aux pieds. Rapide et inquiétant.
func _draw_figure_traqueur() -> void:
	var sway := sin(_anim_phase * 3.2) * 1.2
	var dark := Color(0.16, 0.10, 0.20)
	var mid := Color(0.28, 0.18, 0.36)
	# Volutes d'ombre au sol.
	_draw_ellipse(Vector2(0, 4), 14.0 + sin(_anim_phase * 2.2) * 2.0, 5.0,
			Color(0.25, 0.12, 0.35, 0.30))
	# Corps fin penché vers l'avant (prêt à bondir).
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0 + sway * 0.4, -22.0), Vector2(3.0 + sway * 0.4, -24.0),
		Vector2(6.0, -6.0), Vector2(2.0, 5.0), Vector2(-4.0, 4.0)]), mid)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0 + sway * 0.4, -22.0), Vector2(0.0 + sway * 0.4, -23.0),
		Vector2(0.0, 4.0), Vector2(-4.0, 4.0)]), dark)
	# Tête basse encapuchonnée + yeux fendus violets.
	draw_circle(Vector2(-4.0 + sway, -26.0), 5.0, dark)
	draw_circle(Vector2(-6.2 + sway, -25.5), 1.0, Color(0.85, 0.55, 1.0))
	draw_circle(Vector2(-3.0 + sway, -26.2), 1.0, Color(0.85, 0.55, 1.0))
	# Doubles dagues (reflets froids).
	draw_line(Vector2(7.0, -12.0), Vector2(13.0, -4.0), Color(0.80, 0.82, 0.90), 2.2)
	draw_line(Vector2(-8.0, -10.0), Vector2(-13.0, -2.0), Color(0.80, 0.82, 0.90), 2.2)


# Totem de ronces : pierre dressée gravée de runes, enserrée de ronces,
# lueur verte qui pulse. Immobile — c'est le bois qui frappe.
func _draw_figure_totem() -> void:
	var pulse := 0.5 + 0.4 * sin(_anim_phase * 2.0)
	var stone := Color(0.38, 0.40, 0.36)
	var stone_d := stone.darkened(0.35)
	# Pierre dressée (monolithe irrégulier).
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9.0, 4.0), Vector2(-7.0, -28.0), Vector2(-2.0, -34.0),
		Vector2(6.0, -30.0), Vector2(9.0, -2.0), Vector2(5.0, 5.0)]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9.0, 4.0), Vector2(-7.0, -28.0), Vector2(-3.0, -31.0),
		Vector2(-3.0, 4.0)]), stone_d)
	# Ronces enroulées (lianes sombres + épines).
	var vine := Color(0.16, 0.30, 0.14)
	draw_line(Vector2(-9.0, -4.0), Vector2(8.0, -12.0), vine, 2.4)
	draw_line(Vector2(-7.0, -20.0), Vector2(8.0, -24.0), vine, 2.2)
	for tx in [-5.0, 1.0, 6.0]:
		var t2: float = tx
		draw_line(Vector2(t2, -12.0 + t2 * -0.45), Vector2(t2 + 1.5, -16.0 + t2 * -0.45),
				vine, 1.4)
	# Rune gravée qui pulse (le cœur du totem).
	var glow := Color(0.45, 0.95, 0.40, pulse)
	draw_circle(Vector2(0.0, -18.0), 4.0, Color(glow, pulse * 0.35))
	draw_line(Vector2(0.0, -22.0), Vector2(0.0, -14.0), glow, 1.8)
	draw_line(Vector2(-3.0, -19.0), Vector2(3.0, -17.0), glow, 1.8)


# Loup des Murmures : prédateur gris-bleu de profil, respiration, œil luisant.
func _draw_figure_loup() -> void:
	var bob := sin(_anim_phase * 2.8) * 1.2
	var fur := Color(0.36, 0.40, 0.48)
	var fur_d := fur.darkened(0.45)
	# Pattes (légèrement écartées vers l'extérieur).
	for lx in [-11.0, -6.0, 7.0, 12.0]:
		var fx: float = lx
		draw_line(Vector2(fx, -8.0), Vector2(fx + (1.2 if fx > 0.0 else -1.2), 5.0), fur_d, 3.0)
	# Queue relevée.
	draw_line(Vector2(14, -13 + bob * 0.3), Vector2(22, -20 + bob), fur_d, 3.5)
	# Corps + poitrail clair.
	_draw_ellipse(Vector2(1, -11 + bob * 0.5), 15.0, 7.5, fur)
	_draw_ellipse(Vector2(-8, -12 + bob * 0.5), 8.0, 7.0, fur.lightened(0.08))
	# Tête + museau (tournés vers la gauche, face au joueur).
	var hy := -19.0 + bob
	draw_circle(Vector2(-14, hy), 6.0, fur.lightened(0.10))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, hy - 2.5), Vector2(-26, hy + 1.0), Vector2(-17, hy + 3.5)]), fur)
	draw_circle(Vector2(-25.0, hy + 0.6), 1.3, Color(0.08, 0.08, 0.10))  # truffe
	# Oreilles dressées.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, hy - 5), Vector2(-13, hy - 12), Vector2(-10, hy - 5)]), fur_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, hy - 5), Vector2(-7, hy - 11), Vector2(-5, hy - 4)]), fur)
	# Œil luisant (halo + cœur).
	draw_circle(Vector2(-16, hy - 1), 2.2, Color(1.0, 0.75, 0.25, 0.45))
	draw_circle(Vector2(-16, hy - 1), 1.1, Color(1.0, 0.85, 0.40))


# Rôdeur masqué : silhouette voûtée en haillons, masque d'os, dague au poing.
func _draw_figure_rodeur() -> void:
	var sway := sin(_anim_phase * 2.2) * 1.0
	var cloth := Color(0.30, 0.26, 0.22)
	var cloth_d := cloth.darkened(0.40)
	# Cape en haillons (ourlet déchiqueté, épaules qui respirent).
	var pts := PackedVector2Array([
		Vector2(-8 + sway, -26), Vector2(8 + sway, -26),
		Vector2(13, 6), Vector2(8, 2), Vector2(4, 6), Vector2(0, 2),
		Vector2(-4, 6), Vector2(-8, 2), Vector2(-13, 6)])
	draw_colored_polygon(pts, cloth)
	# Ceinture de corde.
	draw_line(Vector2(-9 + sway * 0.6, -10), Vector2(9 + sway * 0.6, -10),
			Color(0.52, 0.42, 0.26), 2.0)
	# Capuche (penchée en avant) + masque d'os pâle, fentes sombres.
	var hx := sway * 0.8
	draw_circle(Vector2(hx, -29), 7.5, cloth_d)
	_draw_ellipse(Vector2(hx - 1.0, -27.5), 4.0, 5.0, Color(0.86, 0.82, 0.70))
	draw_line(Vector2(hx - 3.0, -29), Vector2(hx - 1.5, -28), Color(0.10, 0.08, 0.08), 1.8)
	draw_line(Vector2(hx + 1.0, -29), Vector2(hx + 2.5, -28), Color(0.10, 0.08, 0.08), 1.8)
	draw_line(Vector2(hx - 1.0, -25.5), Vector2(hx - 1.0, -23.5), Color(0.10, 0.08, 0.08), 1.4)
	# Dague (lame + reflet).
	draw_line(Vector2(11, -8), Vector2(18, -1), Color(0.78, 0.80, 0.86), 2.6)
	draw_line(Vector2(11, -8), Vector2(18, -1), Color(1, 1, 1, 0.45), 1.0)


# BOSS — Le Veilleur des Murmures : grand spectre cornu, voile d'ombre ondulant,
# yeux et rune luisants, braises violettes en orbite. Volontairement imposant.
func _draw_figure_veilleur() -> void:
	var t := _anim_phase
	var breathe := sin(t * 1.6) * 1.8
	var robe := Color(0.16, 0.10, 0.24)
	var robe_d := robe.darkened(0.35)
	var glow := Color(0.72, 0.45, 1.0)
	# Brume au sol (pulse lente).
	_draw_ellipse(Vector2(0, 4), 26.0 + sin(t * 2.0) * 2.0, 9.0, Color(0.30, 0.16, 0.45, 0.25))
	# Braises arrière (derrière le corps).
	_draw_veilleur_embers(t, false)
	# Voile d'ombre : épaules hautes, ourlet qui ondule en continu.
	var top_y := -52.0 + breathe
	var pts := PackedVector2Array([
		Vector2(-14, top_y + 10), Vector2(0, top_y + 4), Vector2(14, top_y + 10),
		Vector2(20, -16)])
	for i in 9:
		var ox := 20.0 - 40.0 * float(i) / 8.0
		pts.append(Vector2(ox, 5.0 + sin(t * 3.0 + float(i) * 1.3) * 2.2))
	pts.append(Vector2(-20, -16))
	draw_colored_polygon(pts, robe)
	# Pan d'ombre intérieur (profondeur).
	_draw_ellipse(Vector2(0, -22 + breathe * 0.5), 11.0, 16.0, robe_d)
	# Rune de poitrine : losange luisant qui pulse.
	var rc := Vector2(0, -26 + breathe * 0.5)
	var ra := 0.55 + 0.35 * sin(t * 2.4)
	draw_colored_polygon(PackedVector2Array([
		rc + Vector2(0, -5), rc + Vector2(4, 0), rc + Vector2(0, 5), rc + Vector2(-4, 0)]),
		Color(glow, ra))
	# Tête : orbe d'ombre + yeux luisants (halo puis cœur).
	var hc := Vector2(0, top_y - 2.0)
	draw_circle(hc, 8.5, Color(0.10, 0.06, 0.16))
	for s in [-1.0, 1.0]:
		var e: Vector2 = hc + Vector2(3.4 * s, -0.5)
		draw_circle(e, 2.6, Color(glow, 0.45))
		draw_circle(e, 1.2, glow.lightened(0.30))
	# Ramure : bois noueux symétriques (branches + fourches).
	var bone := Color(0.76, 0.70, 0.60)
	for s in [-1.0, 1.0]:
		var a: Vector2 = hc + Vector2(5.0 * s, -6.0)
		var m: Vector2 = a + Vector2(5.0 * s, -7.0)
		var top: Vector2 = a + Vector2(7.0 * s, -15.0)
		draw_polyline(PackedVector2Array([a, m, top]), bone, 2.6)
		draw_line(m, m + Vector2(6.0 * s, -2.0), bone, 2.0)
		draw_line(top, top + Vector2(3.0 * s, -5.0), bone, 1.8)
		draw_line(top, top + Vector2(-2.0 * s, -4.0), bone, 1.6)
	# Braises avant (devant le corps).
	_draw_veilleur_embers(t, true)


# Braises en orbite autour du Veilleur ; `front` = moitié avant (sin > 0).
func _draw_veilleur_embers(t: float, front: bool) -> void:
	var glow := Color(0.72, 0.45, 1.0)
	for i in 4:
		var ph := t * 1.4 + TAU * float(i) / 4.0
		if (sin(ph) > 0.0) != front:
			continue
		var p := Vector2(cos(ph) * 24.0, -24.0 + sin(ph) * 7.0)
		var ea := 0.45 + 0.30 * sin(t * 3.0 + float(i) * 1.7)
		draw_circle(p, 2.6, Color(glow, ea * 0.5))
		draw_circle(p, 1.2, Color(0.95, 0.85, 1.0, ea))

extends Node2D

# Mode histoire — phase 1 : exploration libre de la région 1 (Vallée de Bruyère)
# en vue diorama isométrique. Déplacement CONTINU au clavier (ZQSD / WASD /
# flèches) : aucune case surlignée, le tour par tour reste réservé au combat.
# Des ennemis rôdent dans leur zone (le Bois des Murmures, à l'est) : plus on
# s'enfonce, plus ils sont forts. Le contact aspire le joueur dans la
# « dimension de combat » (scène de combat existante, inchangée), puis on
# revient ici. Position + ennemis vaincus persistés via GameData ([campaign]).
# Visuels 100 % vectoriels, distincts de ceux du combat (silhouettes animées).

const TILE_W := 72.0
const TILE_H := 36.0
const HALF_W := TILE_W / 2.0
const HALF_H := TILE_H / 2.0
const EDGE_DEPTH := 30.0  # socle du diorama (parois sous les bords de la carte)

const MAP_W := 44
const MAP_H := 34
const WORLD_SEED := 20260610  # monde déterministe : identique à chaque visite

const FOREST_X := 26  # à l'est de cette colonne : zone des ennemis
const SPAWN := Vector2(8.5, 9.5)

const PLAYER_SPEED := 3.4  # en tuiles/s (plus rapide que les ennemis : fuite possible)
const WANDER_SPEED := 1.1
const CHASE_SPEED := 2.6
const AGGRO_RANGE := 4.0
const DEAGGRO_RANGE := 7.0
const CONTACT_RANGE := 0.65
const BODY_RADIUS := 0.22  # rayon de collision des personnages (en tuiles)

# Équipe du joueur en campagne (trio de départ ; choix libre dans une phase future).
const PLAYER_TEAM := ["tank", "archer", "soigneur"]

# Ennemis qui rôdent dans le bois, posés le long du sentier (px = colonne,
# dy = écart au sentier). Plus px est grand, plus on est profond, plus c'est fort.
const FOES := [
	{"id": "loup_solitaire", "name": "Loup des Murmures", "px": 28.0, "dy": -1.2, "tier": 1,
	 "team": ["loup_murmures"], "hue": Color(0.40, 0.44, 0.52)},
	{"id": "rodeurs_bois", "name": "Rôdeurs du bois", "px": 34.0, "dy": 1.4, "tier": 2,
	 "team": ["rodeur_sombre", "loup_murmures"], "hue": Color(0.46, 0.34, 0.24)},
	# Le boss est SEUL dans son combat : UN Veilleur, pas une équipe.
	{"id": "veilleur", "name": "Le Veilleur des Murmures", "px": 41.0, "dy": 0.0, "tier": 3,
	 "team": ["veilleur_murmures"], "hue": Color(0.45, 0.28, 0.66)},
]

# Damier de sol 2 tons par type de terrain (style diorama du jeu).
const GROUND_COLORS := {
	"herbe":   [Color(0.318, 0.420, 0.235), Color(0.270, 0.368, 0.200)],
	"bois":    [Color(0.196, 0.286, 0.170), Color(0.160, 0.244, 0.142)],
	"chemin":  [Color(0.478, 0.398, 0.262), Color(0.430, 0.356, 0.232)],
	"village": [Color(0.420, 0.366, 0.270), Color(0.376, 0.326, 0.238)],
	"eau":     [Color(0.180, 0.300, 0.420), Color(0.150, 0.265, 0.385)],
}
const COLOR_WALL_L := Color(0.184, 0.130, 0.092)
const COLOR_WALL_R := Color(0.262, 0.188, 0.130)
const COLOR_SEAM := Color(0.0, 0.0, 0.0, 0.14)

var _ground := {}   # Vector2i -> type de sol (clé de GROUND_COLORS)
var _blocked := {}  # Vector2i -> true (obstacle : arbre, maison, eau, bord...)
var _foe_spawns: Array = []  # construits par _build_world (positions calculées)
var _rng := RandomNumberGenerator.new()

var _entities: Node2D
var _camera: Camera2D
var _player: Walker
var _foes: Array = []
var _fade: ColorRect
var _zone_label: Label
var _zone_current := ""
var _locked := false  # vrai pendant la transition vers le combat
var _grace := 1.5     # délai sans contact au retour de combat (anti re-déclenchement)


func _ready() -> void:
	_build_world()
	_build_nodes()
	_build_ui()
	Audio.play_music("menu")
	queue_redraw()
	# Fondu d'arrivée dans le monde.
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.7)


# --- Génération du monde (déterministe : le même à chaque visite) ---

# Le sentier qui serpente du hameau vers l'est du bois.
func _path_y(x: float) -> float:
	return 9.0 + (x - 11.0) * 0.52 + sin(x * 0.55) * 1.6


func _build_world() -> void:
	_rng.seed = WORLD_SEED
	# Sol de base : prairie à l'ouest, bois sombre à l'est.
	for y in MAP_H:
		for x in MAP_W:
			_ground[Vector2i(x, y)] = "bois" if x >= FOREST_X else "herbe"
	# Place de terre battue du hameau.
	for y in range(4, 14):
		for x in range(4, 14):
			_ground[Vector2i(x, y)] = "village"
	# Sentier (2 tuiles de large).
	for x in range(11, MAP_W - 1):
		var yf := _path_y(float(x))
		for dy in [0, 1]:
			var c := Vector2i(x, int(floor(yf)) + dy)
			if c.y >= 1 and c.y < MAP_H - 1:
				_ground[c] = "chemin"
	# Étang (infranchissable).
	for y in MAP_H:
		for x in MAP_W:
			var dx := (float(x) - 17.0) / 3.4
			var dyy := (float(y) - 22.0) / 2.2
			if dx * dx + dyy * dyy <= 1.0:
				var c := Vector2i(x, y)
				_ground[c] = "eau"
				_blocked[c] = true
	# Bord de la maquette : infranchissable (le monde « flotte »).
	for y in MAP_H:
		for x in MAP_W:
			if x == 0 or y == 0 or x == MAP_W - 1 or y == MAP_H - 1:
				_blocked[Vector2i(x, y)] = true
	# Maisons du hameau (2×2 tuiles bloquées chacune).
	for h in [Vector2i(5, 5), Vector2i(10, 5), Vector2i(5, 10)]:
		for dy in 2:
			for dx in 2:
				_blocked[h + Vector2i(dx, dy)] = true
	# Positions des ennemis (le long du sentier, dans le bois).
	_foe_spawns.clear()
	for f in FOES:
		var pos := Vector2(f.px + 0.5, _path_y(f.px) + f.dy)
		_foe_spawns.append({"id": f.id, "name": f.name, "tier": f.tier,
				"team": f.team, "hue": f.hue, "pos": pos})
	# Sapins du bois (clairières autour des ennemis + couloir du sentier préservés).
	for i in 150:
		var x := _rng.randi_range(FOREST_X, MAP_W - 2)
		var y := _rng.randi_range(1, MAP_H - 2)
		var c := Vector2i(x, y)
		if _blocked.has(c) or _ground[c] == "chemin":
			continue
		if absf(float(y) + 0.5 - _path_y(float(x))) < 2.4:
			continue
		var near_foe := false
		for fs in _foe_spawns:
			if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(fs.pos) < 3.0:
				near_foe = true
				break
		if near_foe:
			continue
		_blocked[c] = true
		_decor_at("fir", c)
	# Chênes de la prairie (jamais sur le chemin, le hameau, l'eau).
	for i in 48:
		var x := _rng.randi_range(2, FOREST_X - 1)
		var y := _rng.randi_range(2, MAP_H - 3)
		var c := Vector2i(x, y)
		if _blocked.has(c) or _ground[c] != "herbe":
			continue
		if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(SPAWN) < 3.0:
			continue
		_blocked[c] = true
		_decor_at("tree", c)
	# Quelques rochers.
	for i in 14:
		var x := _rng.randi_range(2, MAP_W - 3)
		var y := _rng.randi_range(2, MAP_H - 3)
		var c := Vector2i(x, y)
		if _blocked.has(c) or _ground[c] != "herbe" and _ground[c] != "bois":
			continue
		_blocked[c] = true
		_decor_at("rock", c)
	# Roseaux au bord de l'étang (décoratifs, traversables).
	for y in MAP_H:
		for x in MAP_W:
			var c := Vector2i(x, y)
			if _ground[c] == "eau":
				continue
			var shore := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _ground.get(c + d, "") == "eau":
					shore = true
					break
			if shore and _rng.randf() < 0.35 and not _blocked.has(c):
				_decor_at("reed", c)


# Les décors sont mémorisés ici puis instanciés dans _build_nodes (tri en Y).
var _decor_list: Array = []
func _decor_at(kind: String, cell: Vector2i) -> void:
	_decor_list.append({"kind": kind, "pos": Vector2(cell) + Vector2(0.5, 0.62),
			"seed": _rng.randf(), "scale": _rng.randf_range(0.88, 1.14)})


func _build_nodes() -> void:
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)
	# Décors (chacun trié en profondeur avec les personnages).
	for d in _decor_list:
		var n := Decor.new()
		n.kind = d.kind
		n.seed_v = d.seed
		n.scale = Vector2(d.scale, d.scale)
		n.position = map_to_world(d.pos)
		_entities.add_child(n)
	# Maisons (décor dessiné, posé au coin sud du bloc 2×2).
	for h in [Vector2i(5, 5), Vector2i(10, 5), Vector2i(5, 10)]:
		var n := Decor.new()
		n.kind = "house"
		n.seed_v = float(h.x) * 0.17
		n.position = map_to_world(Vector2(h) + Vector2(1.0, 1.9))
		_entities.add_child(n)
	# Joueur (reprend la position sauvegardée si elle est valide).
	_player = Walker.new()
	_player.kind = "player"
	var start := SPAWN
	var saved: Vector2 = GameData.campaign_pos
	if saved.x >= 0.0 and _free(saved):
		start = saved
	_player.mpos = start
	_entities.add_child(_player)
	# Ennemis encore en vie (les vaincus ont disparu du monde, définitivement).
	for fs in _foe_spawns:
		if GameData.campaign_defeated.has(fs.id):
			continue
		var w := Walker.new()
		w.kind = "foe"
		w.foe_id = fs.id
		w.label = fs.name
		w.tier = fs.tier
		w.team = fs.team
		w.hue = fs.hue
		w.mpos = fs.pos
		w.home = fs.pos
		w.wander_target = fs.pos
		_entities.add_child(w)
		_foes.append(w)
	# Caméra qui suit le joueur, bornée à la maquette.
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.limit_left = int(map_to_world(Vector2(0, MAP_H)).x) - 60
	_camera.limit_right = int(map_to_world(Vector2(MAP_W, 0)).x) + 60
	_camera.limit_top = int(map_to_world(Vector2(0, 0)).y) - 120
	_camera.limit_bottom = int(map_to_world(Vector2(MAP_W, MAP_H)).y + EDGE_DEPTH) + 80
	_camera.position = map_to_world(_player.mpos)
	_camera.reset_smoothing()
	add_child(_camera)
	_camera.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_zone_label = Label.new()
	_zone_label.position = Vector2(0, 16)
	_zone_label.custom_minimum_size = Vector2(832, 34)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.add_theme_font_size_override("font_size", 26)
	_zone_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_zone_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_zone_label)
	var hint := Label.new()
	hint.text = "ZQSD / flèches : se déplacer   ·   Échap : menu"
	hint.position = Vector2(12, 704 - 30)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.8))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 4)
	layer.add_child(hint)
	_fade = ColorRect.new()
	_fade.position = Vector2.ZERO
	_fade.size = Vector2(832, 704)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


# --- Boucle : entrées, ennemis, caméra ---

func _process(delta: float) -> void:
	if _grace > 0.0:
		_grace -= delta
	if not _locked:
		_move_player(delta)
		_update_foes(delta)
	_player.position = map_to_world(_player.mpos)
	for f in _foes:
		f.position = map_to_world(f.mpos)
	_camera.position = _player.position - Vector2(0.0, 14.0)
	_update_zone()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not _locked:
		GameData.campaign_pos = _player.mpos
		GameData.save_settings()
		get_tree().change_scene_to_file("res://Title.tscn")


# Déplacement libre : touches physiques WASD (= ZQSD sur clavier français) + flèches.
func _move_player(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if dir == Vector2.ZERO:
		_player.moving = false
		return
	if dir.x != 0.0:
		_player.face = 1.0 if dir.x > 0.0 else -1.0
	_try_move(_player, _screen_to_map(dir) * PLAYER_SPEED * delta)
	_player.moving = true


func _update_foes(delta: float) -> void:
	for f in _foes:
		var dist: float = f.mpos.distance_to(_player.mpos)
		if f.chasing:
			if dist > DEAGGRO_RANGE:
				f.chasing = false
				f.wander_target = f.home
			else:
				_walk_to(f, _player.mpos, CHASE_SPEED, delta)
		else:
			if dist < AGGRO_RANGE:
				f.chasing = true
				Audio.play_sfx("click")
			elif f.wait > 0.0:
				f.wait -= delta
				f.moving = false
			elif f.mpos.distance_to(f.wander_target) < 0.25:
				f.wait = randf_range(0.8, 2.4)
				var cand: Vector2 = f.home + Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5))
				if _free(cand):
					f.wander_target = cand
			else:
				_walk_to(f, f.wander_target, WANDER_SPEED, delta)
		f.show_label = dist < 5.0
		if dist < CONTACT_RANGE and _grace <= 0.0 and not _locked:
			_start_battle(f)
			return


func _walk_to(w: Walker, target: Vector2, speed: float, delta: float) -> void:
	var d := target - w.mpos
	if d.length() < 0.05:
		w.moving = false
		return
	var wx := map_to_world(target).x - map_to_world(w.mpos).x
	if absf(wx) > 0.5:
		w.face = 1.0 if wx > 0.0 else -1.0
	_try_move(w, d.normalized() * speed * delta)
	w.moving = true


# Déplacement continu avec glissement le long des obstacles (axe par axe).
func _try_move(w: Walker, step: Vector2) -> void:
	var p: Vector2 = w.mpos
	var nx := Vector2(p.x + step.x, p.y)
	if _free(nx):
		p.x = nx.x
	var ny := Vector2(p.x, p.y + step.y)
	if _free(ny):
		p.y = ny.y
	w.mpos = p


func _free(p: Vector2) -> bool:
	for off in [Vector2(BODY_RADIUS, 0), Vector2(-BODY_RADIUS, 0),
			Vector2(0, BODY_RADIUS), Vector2(0, -BODY_RADIUS)]:
		var t := Vector2i(int(floor(p.x + off.x)), int(floor(p.y + off.y)))
		if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
			return false
		if _blocked.has(t):
			return false
	return true


# --- Bascule vers la « dimension de combat » (scène de combat existante) ---

func _start_battle(foe: Walker) -> void:
	_locked = true
	_player.moving = false
	# Position de reprise : un peu en retrait de l'ennemi (évite un re-contact).
	var away: Vector2 = (_player.mpos - foe.mpos).normalized()
	var back: Vector2 = _player.mpos + away * 1.8
	GameData.campaign_pos = back if _free(back) else _player.mpos
	GameData.campaign_battle = true
	GameData.campaign_enemy_id = foe.foe_id
	GameData.player_team = PLAYER_TEAM.duplicate()
	GameData.ai_team = foe.team.duplicate()
	GameData.difficulty = GameData.campaign_difficulty
	GameData.save_settings()
	Audio.play_sfx("skill")
	_fade.color = Color(0.45, 0.25, 0.75, 0.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.55)
	tw.parallel().tween_property(_camera, "zoom", Vector2(1.18, 1.18), 0.55)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://Main.tscn"))


# --- Zones (nom affiché en haut au changement de lieu) ---

func _zone_name(p: Vector2) -> String:
	if p.x >= FOREST_X:
		return "Bois des Murmures"
	if p.x >= 4.0 and p.x <= 14.0 and p.y >= 4.0 and p.y <= 14.0:
		return "Hameau de Bruyère"
	return "Prairie de Bruyère"


func _update_zone() -> void:
	var z := _zone_name(_player.mpos)
	if z == _zone_current:
		return
	_zone_current = z
	_zone_label.text = z
	var danger := z == "Bois des Murmures"
	_zone_label.add_theme_color_override("font_color",
			Color(0.95, 0.55, 0.45) if danger else Color(0.92, 0.88, 0.76))
	_zone_label.modulate.a = 0.0
	create_tween().tween_property(_zone_label, "modulate:a", 1.0, 0.8)


# --- Rendu du sol (diorama : socle, damier, joints) ---

func map_to_world(m: Vector2) -> Vector2:
	return Vector2((m.x - m.y) * HALF_W, (m.x + m.y) * HALF_H)


func _screen_to_map(d: Vector2) -> Vector2:
	var m := Vector2(d.x / HALF_W + d.y / HALF_H, d.y / HALF_H - d.x / HALF_W)
	return m.normalized() if m.length() > 0.001 else Vector2.ZERO


func _tile_points(cell: Vector2i) -> PackedVector2Array:
	var c := map_to_world(Vector2(cell) + Vector2(0.5, 0.5))
	return PackedVector2Array([
		c + Vector2(0.0, -HALF_H), c + Vector2(HALF_W, 0.0),
		c + Vector2(0.0, HALF_H), c + Vector2(-HALF_W, 0.0)])


func _draw() -> void:
	_draw_drop_shadow()
	_draw_edge_walls()
	for y in MAP_H:
		for x in MAP_W:
			var cell := Vector2i(x, y)
			var pts := _tile_points(cell)
			draw_colored_polygon(pts, _tile_color(cell))
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, COLOR_SEAM, 1.0)


func _tile_color(cell: Vector2i) -> Color:
	var duo: Array = GROUND_COLORS[_ground[cell]]
	var c: Color = duo[(cell.x + cell.y) % 2]
	# Micro-variation déterministe par case (rend le sol vivant, style SoC).
	var h := fposmod(sin(float(cell.x) * 12.9898 + float(cell.y) * 78.233) * 43758.5453, 1.0)
	var j := (h - 0.5) * 0.045
	return Color(c.r + j, c.g + j, c.b + j)


func _draw_drop_shadow() -> void:
	var n := map_to_world(Vector2(0, 0))
	var e := map_to_world(Vector2(MAP_W, 0))
	var s := map_to_world(Vector2(MAP_W, MAP_H))
	var w := map_to_world(Vector2(0, MAP_H))
	var off := Vector2(0.0, EDGE_DEPTH + 16.0)
	var center := (n + e + s + w) / 4.0 + off
	for i in [[1.08, 0.07], [1.04, 0.12], [1.0, 0.2]]:
		var pts := PackedVector2Array()
		for p in [n, e, s, w]:
			pts.append(center + (p + off - center) * i[0])
		draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, i[1]))


func _draw_edge_walls() -> void:
	var down := Vector2(0.0, EDGE_DEPTH)
	for x in MAP_W:
		var pts := _tile_points(Vector2i(x, MAP_H - 1))
		draw_colored_polygon(PackedVector2Array([
			pts[3], pts[2], pts[2] + down, pts[3] + down]), COLOR_WALL_L)
	for y in MAP_H:
		var pts := _tile_points(Vector2i(MAP_W - 1, y))
		draw_colored_polygon(PackedVector2Array([
			pts[2], pts[1], pts[1] + down, pts[2] + down]), COLOR_WALL_R)


# =====================================================================
# Personnages d'exploration (joueur + ennemis), 100 % vectoriels et animés.
# Visuels volontairement distincts de ceux du combat : petites silhouettes
# de voyage (cape, marche balancée) et rôdeurs encapuchonnés aux yeux luisants.
class Walker extends Node2D:
	var kind := "player"  # "player" | "foe"
	var mpos := Vector2.ZERO  # position dans la carte (en tuiles, continue)
	var phase := 0.0
	var moving := false
	var face := 1.0  # 1 = regarde vers la droite de l'écran
	var hue := Color(0.5, 0.3, 0.2)
	var tier := 1
	var team: Array = []
	var foe_id := ""
	var label := ""
	var show_label := false
	var chasing := false
	var home := Vector2.ZERO
	var wander_target := Vector2.ZERO
	var wait := 0.0

	func _process(delta: float) -> void:
		phase += delta * (9.0 if moving else 2.2)
		queue_redraw()

	func _draw() -> void:
		# Ombre de contact (hors miroir, elle est symétrique).
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 9.0 if kind == "player" else 8.0 + 2.0 * tier,
				Color(0.0, 0.0, 0.0, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1.0))
		if kind == "player":
			_draw_player()
		else:
			_draw_foe()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_overhead()

	func _draw_player() -> void:
		var b := sin(phase) * (1.4 if moving else 0.5)  # rebond de marche
		var sw := sin(phase) * 3.5 if moving else 0.0   # balancement des jambes
		var leg := Color(0.16, 0.14, 0.18)
		draw_line(Vector2(-2.0, -7.0 + b * 0.5), Vector2(-2.0 - sw, 0.0), leg, 3.0)
		draw_line(Vector2(2.0, -7.0 + b * 0.5), Vector2(2.0 + sw, 0.0), leg, 3.0)
		# Cape de voyage (dans le dos, ondule en marchant).
		var sway := sin(phase * 0.9) * (1.6 if moving else 0.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-3.0, -16.0 + b), Vector2(-6.5, -14.0 + b),
			Vector2(-8.5 - sway, -2.0), Vector2(-3.5, -4.0)]),
			Color(0.50, 0.14, 0.16))
		# Tunique (bleu du camp joueur) + ceinture.
		draw_colored_polygon(PackedVector2Array([
			Vector2(-5.0, -17.0 + b), Vector2(5.0, -17.0 + b),
			Vector2(6.0, -7.0 + b), Vector2(-6.0, -7.0 + b)]),
			Color(0.25, 0.42, 0.62))
		draw_rect(Rect2(-6.0, -9.5 + b, 12.0, 2.2), Color(0.24, 0.18, 0.10))
		# Bras (balancement opposé aux jambes).
		var arm := Color(0.22, 0.36, 0.54)
		draw_line(Vector2(-4.5, -15.0 + b), Vector2(-5.5 + sw * 0.6, -8.5 + b), arm, 2.5)
		draw_line(Vector2(4.5, -15.0 + b), Vector2(5.5 - sw * 0.6, -8.5 + b), arm, 2.5)
		# Tête + cheveux.
		draw_circle(Vector2(0.0, -21.5 + b), 4.6, Color(0.94, 0.80, 0.62))
		draw_circle(Vector2(-0.8, -23.3 + b), 3.6, Color(0.32, 0.22, 0.14))
		# Œil (donne le sens de la marche).
		draw_circle(Vector2(2.0, -21.3 + b), 0.9, Color(0.12, 0.10, 0.12))

	func _draw_foe() -> void:
		var s := 0.85 + 0.18 * float(tier)  # plus fort = plus imposant
		var b := sin(phase) * (1.2 if moving else 0.6)
		var sway := sin(phase * 0.7) * 1.5
		var dark := Color(hue.r * 0.55, hue.g * 0.55, hue.b * 0.55)
		# Silhouette encapuchonnée.
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7.0 * s, 0.0), Vector2(7.0 * s, 0.0),
			Vector2(6.0 * s, (-14.0 + b) * s), Vector2((0.0 + sway) * s, (-24.0 + b) * s),
			Vector2(-6.0 * s, (-14.0 + b) * s)]), dark)
		# Liseré de la cape (lisibilité sur sol sombre).
		draw_line(Vector2(-7.0 * s, 0.0), Vector2(-6.0 * s, (-14.0 + b) * s),
				Color(hue.r, hue.g, hue.b, 0.9), 1.5)
		draw_line(Vector2(7.0 * s, 0.0), Vector2(6.0 * s, (-14.0 + b) * s),
				Color(hue.r, hue.g, hue.b, 0.9), 1.5)
		# Cornes du chef (tier 3).
		if tier >= 3:
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4.5 * s, (-21.0 + b) * s), Vector2(-8.5 * s, (-27.0 + b) * s),
				Vector2(-2.5 * s, (-22.5 + b) * s)]), dark)
			draw_colored_polygon(PackedVector2Array([
				Vector2(4.5 * s, (-21.0 + b) * s), Vector2(8.5 * s, (-27.0 + b) * s),
				Vector2(2.5 * s, (-22.5 + b) * s)]), dark)
		# Yeux luisants (rouges en poursuite).
		var eye := Color(1.0, 0.35, 0.2) if chasing else Color(0.95, 0.85, 0.45)
		draw_circle(Vector2(-2.2 * s, (-16.5 + b) * s), 2.6 * s, Color(eye.r, eye.g, eye.b, 0.18))
		draw_circle(Vector2(2.2 * s, (-16.5 + b) * s), 2.6 * s, Color(eye.r, eye.g, eye.b, 0.18))
		draw_circle(Vector2(-2.2 * s, (-16.5 + b) * s), 1.1 * s, eye)
		draw_circle(Vector2(2.2 * s, (-16.5 + b) * s), 1.1 * s, eye)

	# Textes au-dessus de la tête (hors miroir pour ne pas écrire à l'envers).
	func _draw_overhead() -> void:
		if kind != "foe":
			return
		var font := ThemeDB.fallback_font
		var s := 0.85 + 0.18 * float(tier)
		if chasing:
			draw_string(font, Vector2(-4.0, -30.0 * s - 6.0), "!",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.8, 0.25))
		elif show_label:
			draw_string(font, Vector2(-60.0, -30.0 * s - 4.0), label,
					HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.0, 0.0, 0.0, 0.7))
			draw_string(font, Vector2(-61.0, -30.0 * s - 5.0), label,
					HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(1.0, 0.92, 0.8))


# Décors du monde (arbres, sapins, rochers, maisons, roseaux), base au point (0,0)
# pour que le tri en Y donne une occlusion correcte avec les personnages.
class Decor extends Node2D:
	var kind := "tree"
	var seed_v := 0.0

	func _draw() -> void:
		match kind:
			"tree":
				_shadow(11.0)
				draw_rect(Rect2(-2.5, -13.0, 5.0, 13.0), Color(0.30, 0.21, 0.13))
				var g := Color(0.24 + seed_v * 0.06, 0.42 + seed_v * 0.06, 0.20)
				draw_circle(Vector2(-7.0, -15.0), 7.5, g.darkened(0.12))
				draw_circle(Vector2(7.0, -15.0), 7.5, g.darkened(0.06))
				draw_circle(Vector2(0.0, -21.0), 10.0, g)
				draw_circle(Vector2(-3.0, -23.5), 4.0, g.lightened(0.15))
			"fir":
				_shadow(10.0)
				draw_rect(Rect2(-2.0, -7.0, 4.0, 7.0), Color(0.22, 0.15, 0.10))
				var c := Color(0.10 + seed_v * 0.04, 0.23 + seed_v * 0.05, 0.13)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-12.0, -7.0), Vector2(12.0, -7.0), Vector2(0.0, -25.0)]), c)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-9.5, -17.0), Vector2(9.5, -17.0), Vector2(0.0, -33.0)]), c.lightened(0.07))
				draw_colored_polygon(PackedVector2Array([
					Vector2(-7.0, -26.0), Vector2(7.0, -26.0), Vector2(0.0, -41.0)]), c.lightened(0.13))
			"rock":
				_shadow(10.0)
				var g := Color(0.44 + seed_v * 0.06, 0.44 + seed_v * 0.05, 0.49)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-10.0, 0.0), Vector2(-7.0, -8.0), Vector2(0.0, -11.0),
					Vector2(8.0, -7.0), Vector2(11.0, 0.0)]), g)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-5.0, -7.5), Vector2(0.0, -10.0), Vector2(4.0, -7.0),
					Vector2(-1.0, -5.5)]), g.lightened(0.18))
			"house":
				_shadow(30.0)
				var wall_l := Color(0.62, 0.55, 0.44)
				var wall_r := Color(0.72, 0.64, 0.51)
				var a := 34.0
				var bb := 17.0
				var h := 26.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(-a, -bb), Vector2(0, 0), Vector2(0, -h), Vector2(-a, -bb - h)]), wall_l)
				draw_colored_polygon(PackedVector2Array([
					Vector2(0, 0), Vector2(a, -bb), Vector2(a, -bb - h), Vector2(0, -h)]), wall_r)
				var roof_l := Color(0.48, 0.22, 0.16)
				var roof_r := Color(0.58, 0.28, 0.19)
				var apex := Vector2(0, -bb - h - 22.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-a - 4.0, -bb - h + 2.0), Vector2(0, -h + 2.0), apex]), roof_l)
				draw_colored_polygon(PackedVector2Array([
					Vector2(0, -h + 2.0), Vector2(a + 4.0, -bb - h + 2.0), apex]), roof_r)
				# Porte (face droite) + fenêtre (face gauche).
				draw_colored_polygon(PackedVector2Array([
					Vector2(7.0, -3.5), Vector2(15.0, -7.5),
					Vector2(15.0, -24.0), Vector2(7.0, -20.0)]), Color(0.26, 0.17, 0.10))
				draw_colored_polygon(PackedVector2Array([
					Vector2(-22.0, -13.0), Vector2(-14.0, -9.0),
					Vector2(-14.0, -19.0), Vector2(-22.0, -23.0)]), Color(0.92, 0.82, 0.50))
			"reed":
				var c := Color(0.16, 0.30, 0.16)
				draw_line(Vector2(0.0, 0.0), Vector2(-2.0, -12.0), c, 1.6)
				draw_line(Vector2(2.0, 0.0), Vector2(4.0, -14.0), c, 1.6)
				draw_line(Vector2(-3.0, 0.0), Vector2(-6.0, -9.0), c, 1.6)
				draw_circle(Vector2(4.0, -14.0), 2.0, Color(0.38, 0.24, 0.12))

	func _shadow(r: float) -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, r, Color(0.0, 0.0, 0.0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

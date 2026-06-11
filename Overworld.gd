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

# L'équipe de campagne = TON héros (créé dans CharacterCreate), seul au départ.
# Les compagnons recrutés l'agrandiront (phase suivante).

# Ennemis qui rôdent dans le bois, posés le long du sentier (px = colonne,
# dy = écart au sentier). Plus px est grand, plus on est profond, plus c'est fort.
# Équilibré pour un héros SOLO : combats 1v1 à l'orée ; le boss, lui, attend
# une équipe (y aller seul = courir à sa perte, et c'est voulu).
const FOES := [
	{"id": "loup_solitaire", "name": "Loup des Murmures", "px": 28.0, "dy": -1.2, "tier": 1,
	 "team": ["loup_murmures"], "hue": Color(0.40, 0.44, 0.52)},
	{"id": "rodeurs_bois", "name": "Rôdeur du bois", "px": 34.0, "dy": 1.4, "tier": 2,
	 "team": ["rodeur_sombre"], "hue": Color(0.46, 0.34, 0.24)},
	# Le boss est SEUL dans son combat : UN Veilleur, pas une équipe.
	{"id": "veilleur", "name": "Le Veilleur des Murmures", "px": 41.0, "dy": 0.0, "tier": 3,
	 "team": ["veilleur_murmures"], "hue": Color(0.45, 0.28, 0.66)},
]

# --- PNJ du hameau (data-driven : un PNJ = des données, zéro code dédié) ---
# Chaque PNJ choisit son dialogue d'entrée : première règle satisfaite, sinon
# "fallback". Une règle = un drapeau requis (+ option "foes_down" : ennemis
# vaincus requis). "hide_flag" : si ce drapeau est posé, le PNJ a quitté le monde.
const NPCS := [
	{"id": "maud", "name": "Maud, l'herboriste", "pos": Vector2(7.6, 6.6), "figure": "herboriste",
	 "rules": [
		{"flag": "maud_vexee", "dialogue": "maud_froide"},
		{"flag": "maud_amie", "dialogue": "maud_revoit"},
	 ], "fallback": "maud_intro"},
	{"id": "garin", "name": "Garin, le bûcheron", "pos": Vector2(12.6, 11.6), "figure": "bucheron",
	 "party_flag": "garin_party",
	 "rules": [
		{"flag": "garin_recompense", "dialogue": "garin_fin"},
		{"flag": "garin_accepte", "foes_down": ["loup_solitaire", "rodeurs_bois"],
		 "dialogue": "garin_reward"},
		{"flag": "garin_accepte", "dialogue": "garin_attente"},
		{"flag": "garin_refuse", "dialogue": "garin_retente"},
	 ], "fallback": "garin_intro"},
	{"id": "sera", "name": "Sera, l'étrangère", "pos": Vector2(6.4, 13.0), "figure": "etrangere",
	 "hide_flag": "sera_denoncee", "party_flag": "sera_party",
	 "rules": [
		{"flag": "sera_proche", "dialogue": "sera_revoit"},
	 ], "fallback": "sera_intro"},
]

# Dialogues : texte + choix. Un choix peut poser des drapeaux ("set"), débloquer
# une classe ("unlock") et enchaîner sur un autre dialogue ("next", sinon fermer).
const DIALOGUES := {
	# — Maud : écouter ou mépriser ; elle s'en souviendra. —
	"maud_intro": {
		"speaker": "Maud, l'herboriste",
		"text": "Encore un qui lorgne vers l'est... Le bois murmure, petit. Ceux qui n'écoutent pas finissent dans la vase. Tu veux le conseil d'une vieille femme ?",
		"choices": [
			{"label": "« Je vous écoute. »", "set": {"maud_amie": true}, "next": "maud_conseil"},
			{"label": "« Gardez vos radotages, la vieille. »", "set": {"maud_vexee": true}, "next": "maud_vexe"},
		]},
	"maud_conseil": {
		"speaker": "Maud, l'herboriste",
		"text": "Le maître du bois ne se laisse pas fuir : quand on l'affronte, c'est jusqu'au bout. Ses ronces fauchent tout ce qui se serre — n'avance pas en rang d'oignons, écarte tes gens.",
		"choices": [{"label": "« Merci, Maud. »"}]},
	"maud_revoit": {
		"speaker": "Maud, l'herboriste",
		"text": "Toujours vivant, petit ? Les murmures parlent de toi. Souviens-toi : écartés face aux ronces, et garde celui qui soigne loin des crocs.",
		"choices": [{"label": "« À bientôt. »"}]},
	"maud_vexe": {
		"speaker": "Maud, l'herboriste",
		"text": "... Comme tu veux. Le bois t'apprendra mieux que moi.",
		"choices": [{"label": "(Partir)"}]},
	"maud_froide": {
		"speaker": "Maud, l'herboriste",
		"text": "J'ai rien pour les malpolis. Va donc écouter le bois, puisqu'il te tarde.",
		"choices": [{"label": "(Partir)"}]},
	# — Garin : un marché ; le tenir récompense (déblocage de classe). —
	"garin_intro": {
		"speaker": "Garin, le bûcheron",
		"text": "J'peux plus couper une bûche : un loup et un rôdeur masqué squattent ma clairière. Nettoie-moi le bois — le loup ET le rôdeur — et j'te montre c'que j'sais du métier des armes. Marché conclu ?",
		"choices": [
			{"label": "« Marché conclu. »", "set": {"garin_accepte": true, "garin_refuse": false}, "next": "garin_topla"},
			{"label": "« Débrouille-toi. »", "set": {"garin_refuse": true}, "next": "garin_decu"},
		]},
	"garin_topla": {
		"speaker": "Garin, le bûcheron",
		"text": "Topez là ! Le loup rôde à l'orée, le rôdeur plus au fond. Reviens me voir quand c'est fait.",
		"choices": [{"label": "(Partir)"}]},
	"garin_decu": {
		"speaker": "Garin, le bûcheron",
		"text": "Ouais... comme tout le monde ici. Si tu changes d'avis, tu sais où me trouver.",
		"choices": [{"label": "(Partir)"}]},
	"garin_retente": {
		"speaker": "Garin, le bûcheron",
		"text": "T'as changé d'avis ? Le marché tient toujours : le loup et le rôdeur hors de ma clairière, et j'te montre le métier des armes.",
		"choices": [
			{"label": "« C'est d'accord. »", "set": {"garin_accepte": true, "garin_refuse": false}, "next": "garin_topla"},
			{"label": "« Non, toujours pas. »"},
		]},
	"garin_attente": {
		"speaker": "Garin, le bûcheron",
		"text": "Alors, ce bois ? J'entends encore ces sales bêtes d'ici... Le loup de l'orée et le rôdeur du fond, et on est quittes.",
		"choices": [{"label": "« J'y travaille. »"}]},
	"garin_reward": {
		"speaker": "Garin, le bûcheron",
		"text": "Par ma hache, t'as vraiment nettoyé la clairière ! Un marché est un marché : viens là, j'te montre la garde du lancier — c'est comme tenir un grand merlin, regarde...",
		"choices": [{"label": "« Montre-moi. »", "set": {"garin_recompense": true}, "unlock": "lancier"}]},
	"garin_fin": {
		"speaker": "Garin, le bûcheron",
		"text": "Alors, cette garde de lancier, ça rentre ? Ma clairière te dit merci. Si t'as besoin d'un bras de plus contre c'qui gronde au fond du bois... ma lance s'ennuie.",
		"choices": [
			{"label": "« Viens avec moi, Garin. »", "set": {"garin_party": true},
			 "recruit": "garin", "next": "garin_join"},
			{"label": "« Bon bois, Garin. »"},
		]},
	"garin_join": {
		"speaker": "Garin, le bûcheron",
		"text": "Ha ! J'range la hache, j'prends la lance. Devant moi personne passe — montre le chemin, compagnon.",
		"choices": [{"label": "(En route)"}]},
	# — Sera : un secret ; le garder ou la dénoncer change le monde. —
	"sera_intro": {
		"speaker": "Sera, l'étrangère",
		"text": "Toi non plus, t'es pas d'ici, pas vrai ?... Bon. Je me cache : les rôdeurs du bois étaient mes frères de route, avant que je déserte. Si le hameau l'apprend, on me chassera. Tu vas leur dire ?",
		"choices": [
			{"label": "« Ton secret est en sécurité. »", "set": {"sera_proche": true}, "next": "sera_confiance"},
			{"label": "« Ces gens méritent la vérité. »", "set": {"sera_denoncee": true}, "next": "sera_chassee"},
			{"label": "(Ne rien promettre et partir)"},
		]},
	"sera_confiance": {
		"speaker": "Sera, l'étrangère",
		"text": "Alors tiens, un conseil de déserteuse : les rôdeurs paniquent quand leur meneur tombe en premier. Et... merci. Je ne l'oublierai pas.",
		"choices": [{"label": "(Partir)"}]},
	"sera_chassee": {
		"speaker": "Sera, l'étrangère",
		"text": "...Je vois. J'aurai quitté le hameau avant la nuit. J'espère que tu sauras vivre avec ce choix — le bois, lui, s'en souviendra.",
		"choices": [{"label": "(La regarder partir)"}]},
	"sera_revoit": {
		"speaker": "Sera, l'étrangère",
		"text": "Toujours muette, ma langue. Toi, tâche de rester vivant : le meneur d'abord, souviens-toi. ...À moins que tu cherches une lame de plus ?",
		"choices": [
			{"label": "« Voyage avec moi, Sera. »", "set": {"sera_party": true},
			 "recruit": "sera", "next": "sera_join"},
			{"label": "« Compris. »"},
		]},
	"sera_join": {
		"speaker": "Sera, l'étrangère",
		"text": "Alors c'est dit. Je connais ce bois mieux que ses loups — je couvre tes arrières, toi ouvre la route. Et au fond du bois... tu verras pourquoi j'ai déserté.",
		"choices": [{"label": "(En route)"}]},
}

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
var _npcs: Array = []
var _party: Array = []  # Walkers des compagnons (suivent le héros en file)
var _fade: ColorRect
var _zone_label: Label
var _zone_current := ""
var _locked := false  # vrai pendant la transition vers le combat
var _grace := 1.5     # délai sans contact au retour de combat (anti re-déclenchement)
# Dialogue en cours (le monde est en pause pendant qu'on parle).
const TALK_RANGE := 1.6
var _talking := false
var _dlg_npc: Walker = null
var _dlg_panel: PanelContainer
var _dlg_speaker: Label
var _dlg_text: Label
var _dlg_choices: VBoxContainer


func _ready() -> void:
	# Sauvegarde d'avant la création de personnage : on crée le héros d'abord.
	if GameData.campaign_hero.is_empty():
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().change_scene_to_file.call_deferred("res://CharacterCreate.tscn")
		return
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
	# Compagnons recrutés : ils marchent derrière le héros (file de voyage).
	var fi := 1
	for comp_id in GameData.campaign_party:
		_spawn_follower(str(comp_id), _player.mpos + Vector2(-0.7, 0.5) * float(fi))
		fi += 1
	# PNJ du hameau (sauf ceux partis ou recrutés suite à un choix).
	for n in NPCS:
		if n.has("hide_flag") and GameData.get_flag(n.hide_flag):
			continue
		if n.has("party_flag") and GameData.get_flag(n.party_flag):
			continue
		var w := Walker.new()
		w.kind = "npc"
		w.npc_id = n.id
		w.figure = n.figure
		w.label = n.name
		w.mpos = n.pos
		w.position = map_to_world(n.pos)
		_entities.add_child(w)
		_npcs.append(w)
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
	hint.text = "ZQSD / flèches : se déplacer   ·   E : parler   ·   Échap : menu"
	hint.position = Vector2(12, 704 - 30)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.8))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 4)
	layer.add_child(hint)
	# Boîte de dialogue (cachée par défaut) : nom du PNJ, texte, choix cliquables.
	_dlg_panel = PanelContainer.new()
	_dlg_panel.position = Vector2(56, 440)
	_dlg_panel.custom_minimum_size = Vector2(720, 0)
	_dlg_panel.visible = false
	layer.add_child(_dlg_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_dlg_panel.add_child(vb)
	_dlg_speaker = Label.new()
	_dlg_speaker.add_theme_font_size_override("font_size", 20)
	_dlg_speaker.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	vb.add_child(_dlg_speaker)
	_dlg_text = Label.new()
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(700, 0)
	_dlg_text.add_theme_font_size_override("font_size", 17)
	_dlg_text.add_theme_color_override("font_color", Color(0.92, 0.90, 0.84))
	vb.add_child(_dlg_text)
	_dlg_choices = VBoxContainer.new()
	_dlg_choices.add_theme_constant_override("separation", 4)
	vb.add_child(_dlg_choices)

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
	if not _locked and not _talking:
		_move_player(delta)
		_update_foes(delta)
		_update_npcs()
		_update_party(delta)
	_player.position = map_to_world(_player.mpos)
	for f in _foes:
		f.position = map_to_world(f.mpos)
	for w in _party:
		w.position = map_to_world(w.mpos)
	_camera.position = _player.position - Vector2(0.0, 14.0)
	_update_zone()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or _locked:
		return
	if event.keycode == KEY_ESCAPE:
		if _talking:
			_close_dialogue()
			return
		GameData.campaign_pos = _player.mpos
		GameData.save_campaign()
		get_tree().change_scene_to_file("res://Title.tscn")
	# E : parler au PNJ à portée (les choix se font à la souris).
	if event.physical_keycode == KEY_E and not _talking:
		var npc := _nearest_npc()
		if npc:
			_open_dialogue(npc)


# PNJ : immobiles, mais se tournent vers le joueur proche (et affichent l'invite).
func _update_npcs() -> void:
	for n in _npcs:
		var dist: float = n.mpos.distance_to(_player.mpos)
		n.show_label = dist < 4.0
		n.prompt = dist < TALK_RANGE
		if dist < 4.0:
			var wx := map_to_world(_player.mpos).x - map_to_world(n.mpos).x
			if absf(wx) > 4.0:
				n.face = 1.0 if wx > 0.0 else -1.0


# Compagnons : marche en file derrière le héros (chacun suit le précédent).
func _update_party(delta: float) -> void:
	var prev: Vector2 = _player.mpos
	for w in _party:
		var d: float = w.mpos.distance_to(prev)
		if d > 0.95:
			var step: float = minf(PLAYER_SPEED * 1.08 * delta, d - 0.85)
			w.mpos += (prev - w.mpos).normalized() * step
			w.moving = true
			var wx := map_to_world(prev).x - map_to_world(w.mpos).x
			if absf(wx) > 0.5:
				w.face = 1.0 if wx > 0.0 else -1.0
		else:
			w.moving = false
		prev = w.mpos


func _spawn_follower(comp_id: String, pos: Vector2) -> void:
	var c: Dictionary = GameData.COMPANIONS.get(comp_id, {})
	if c.is_empty():
		return
	var w := Walker.new()
	w.kind = "ally"
	w.figure = str(c.figure)
	w.label = str(c.name)
	w.mpos = pos
	w.position = map_to_world(pos)
	_entities.add_child(w)
	_party.append(w)


func _nearest_npc() -> Walker:
	var best: Walker = null
	var best_d := TALK_RANGE
	for n in _npcs:
		var d: float = n.mpos.distance_to(_player.mpos)
		if d < best_d:
			best_d = d
			best = n
	return best


# --- Dialogues à choix (data-driven : NPCS + DIALOGUES) ---

# Choisit le dialogue d'entrée d'un PNJ : première règle satisfaite, sinon fallback.
func _npc_entry_dialogue(npc_id: String) -> String:
	for n in NPCS:
		if n.id != npc_id:
			continue
		for r in n.get("rules", []):
			if not GameData.get_flag(r.flag):
				continue
			var ok := true
			for foe_id in r.get("foes_down", []):
				if not GameData.campaign_defeated.has(foe_id):
					ok = false
					break
			if ok:
				return r.dialogue
		return n.fallback
	return ""


func _open_dialogue(npc: Walker) -> void:
	var did := _npc_entry_dialogue(npc.npc_id)
	if did == "" or not DIALOGUES.has(did):
		return
	_talking = true
	_dlg_npc = npc
	_player.moving = false
	Audio.play_sfx("click")
	_show_dialogue(did)


func _show_dialogue(did: String) -> void:
	var d: Dictionary = DIALOGUES[did]
	_dlg_speaker.text = str(d.speaker)
	_dlg_text.text = str(d.text)
	for c in _dlg_choices.get_children():
		c.queue_free()
	for choice in d.choices:
		var b := Button.new()
		b.text = str(choice.label)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 34)
		var ch: Dictionary = choice
		b.pressed.connect(func(): _on_choice(ch))
		_dlg_choices.add_child(b)
	_dlg_panel.visible = true


func _on_choice(choice: Dictionary) -> void:
	Audio.play_sfx("click")
	var changed := false
	for key in choice.get("set", {}):
		GameData.set_flag(key, bool(choice.set[key]))
		changed = true
	# Récompense : déblocage d'une classe par l'exploration (vision du jeu).
	var cid: String = str(choice.get("unlock", ""))
	if cid != "" and not GameData.is_unlocked(cid):
		GameData.unlocked.append(cid)
		changed = true
		_announce("⚔ Classe débloquée : %s !" % str(GameData.CLASSES[cid].name))
	# Recrutement : le PNJ rejoint l'équipe (il suivra le héros dans le monde).
	var rid: String = str(choice.get("recruit", ""))
	if rid != "" and not GameData.campaign_party.has(rid):
		GameData.campaign_party.append(rid)
		changed = true
		_announce("🤝 %s rejoint l'équipe !" % str(GameData.COMPANIONS[rid].name))
	if changed:
		GameData.campaign_pos = _player.mpos
		GameData.save_campaign()
	if choice.has("next"):
		_show_dialogue(str(choice.next))
	else:
		_close_dialogue()


func _close_dialogue() -> void:
	_dlg_panel.visible = false
	_talking = false
	# Un choix peut chasser le PNJ du monde (Sera dénoncée) ou le recruter
	# (il devient un compagnon qui suit le héros).
	if _dlg_npc:
		for n in NPCS:
			if n.id != _dlg_npc.npc_id:
				continue
			if n.has("party_flag") and GameData.get_flag(n.party_flag):
				_npcs.erase(_dlg_npc)
				_spawn_follower(str(_dlg_npc.npc_id), _dlg_npc.mpos)
				_dlg_npc.queue_free()
			elif n.has("hide_flag") and GameData.get_flag(n.hide_flag):
				_npcs.erase(_dlg_npc)
				var leaving: Walker = _dlg_npc
				var tw := create_tween()
				tw.tween_property(leaving, "modulate:a", 0.0, 1.2)
				tw.tween_callback(leaving.queue_free)
	_dlg_npc = null


# Annonce dorée au centre (réutilise le label de zone, rendu à la zone après 3 s).
var _announce_t := 0.0
func _announce(msg: String) -> void:
	_announce_t = 3.0
	_zone_current = ""  # forcera le retour au nom de zone après l'annonce
	_zone_label.text = msg
	_zone_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	_zone_label.modulate.a = 1.0


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
	# Équipe = le héros + ses compagnons recrutés (noms affichés en combat).
	var team: Array = [str(GameData.campaign_hero.get("class", "tank"))]
	var names: Array = [str(GameData.campaign_hero.get("name", "Héros"))]
	for comp_id in GameData.campaign_party:
		var c: Dictionary = GameData.COMPANIONS.get(comp_id, {})
		if c.is_empty():
			continue
		team.append(str(c["class"]))
		names.append(str(c.name))
	GameData.player_team = team
	GameData.campaign_battle_names = names
	GameData.ai_team = foe.team.duplicate()
	GameData.difficulty = GameData.campaign_difficulty
	GameData.save_campaign()
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
	if _announce_t > 0.0:
		_announce_t -= get_process_delta_time()
		return
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
	if _ground.is_empty():  # redirection vers la création de perso : rien à dessiner
		return
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
	var kind := "player"  # "player" | "foe" | "npc"
	var mpos := Vector2.ZERO  # position dans la carte (en tuiles, continue)
	var phase := 0.0
	var moving := false
	var face := 1.0  # 1 = regarde vers la droite de l'écran
	var hue := Color(0.5, 0.3, 0.2)
	var tier := 1
	var team: Array = []
	var foe_id := ""
	var npc_id := ""
	var figure := ""        # visuel du PNJ ("herboriste", "bucheron", "etrangere")
	var prompt := false     # à portée de parole : affiche « E — Parler »
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
		draw_circle(Vector2.ZERO, 9.0 if kind != "foe" else 8.0 + 2.0 * tier,
				Color(0.0, 0.0, 0.0, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1.0))
		match kind:
			"player":
				_draw_player()
			"npc", "ally":
				_draw_npc()
			_:
				_draw_foe()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_overhead()

	# PNJ du hameau : trois habitants dessinés à la main, respiration lente.
	func _draw_npc() -> void:
		var b := sin(phase) * 0.5  # respiration (les PNJ ne marchent pas, v1)
		match figure:
			"herboriste":
				# Vieille femme : robe vert-gris, châle, chignon blanc, canne.
				draw_colored_polygon(PackedVector2Array([
					Vector2(-4.5, -16.0 + b), Vector2(4.5, -16.0 + b),
					Vector2(6.5, 0.0), Vector2(-6.5, 0.0)]), Color(0.36, 0.42, 0.32))
				draw_colored_polygon(PackedVector2Array([
					Vector2(-5.5, -16.5 + b), Vector2(5.5, -16.5 + b),
					Vector2(6.5, -10.0 + b), Vector2(-6.5, -10.0 + b)]),
					Color(0.55, 0.46, 0.36))  # châle
				# Tête penchée (dos voûté) + chignon blanc.
				draw_circle(Vector2(1.5, -19.5 + b), 4.2, Color(0.90, 0.76, 0.62))
				draw_circle(Vector2(-0.5, -22.0 + b), 2.8, Color(0.88, 0.88, 0.86))
				draw_circle(Vector2(3.0, -19.2 + b), 0.8, Color(0.12, 0.10, 0.12))
				# Canne tenue devant.
				draw_line(Vector2(6.5, -12.0 + b), Vector2(8.0, 0.0), Color(0.38, 0.26, 0.14), 2.0)
			"bucheron":
				# Costaud : tunique brune, ceinture, barbe, hache sur l'épaule.
				draw_colored_polygon(PackedVector2Array([
					Vector2(-6.5, -17.0 + b), Vector2(6.5, -17.0 + b),
					Vector2(7.5, 0.0), Vector2(-7.5, 0.0)]), Color(0.46, 0.32, 0.20))
				draw_rect(Rect2(-7.0, -9.0 + b, 14.0, 2.4), Color(0.22, 0.16, 0.10))
				# Tête + barbe fournie.
				draw_circle(Vector2(0.0, -21.0 + b), 4.8, Color(0.92, 0.76, 0.58))
				draw_colored_polygon(PackedVector2Array([
					Vector2(-4.0, -20.0 + b), Vector2(4.0, -20.0 + b),
					Vector2(0.0, -13.5 + b)]), Color(0.42, 0.28, 0.16))
				draw_circle(Vector2(2.0, -21.8 + b), 0.9, Color(0.12, 0.10, 0.12))
				# Hache posée sur l'épaule (manche + fer).
				draw_line(Vector2(-3.0, -16.0 + b), Vector2(-10.0, -26.0 + b), Color(0.40, 0.28, 0.15), 2.4)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-10.0, -29.0 + b), Vector2(-6.0, -27.0 + b),
					Vector2(-10.0, -23.5 + b), Vector2(-13.0, -26.0 + b)]),
					Color(0.72, 0.74, 0.80))
			"etrangere":
				# Voyageuse : cape bleu nuit, capuche, visage dans l'ombre, yeux pâles.
				draw_colored_polygon(PackedVector2Array([
					Vector2(-5.5, -17.0 + b), Vector2(5.5, -17.0 + b),
					Vector2(7.0, 0.0), Vector2(-7.0, 0.0)]), Color(0.20, 0.24, 0.38))
				draw_circle(Vector2(0.0, -20.0 + b), 5.2, Color(0.16, 0.20, 0.32))
				_npc_ellipse(Vector2(0.5, -19.5 + b), 3.4, 2.8, Color(0.08, 0.08, 0.12))
				draw_circle(Vector2(-0.8, -19.8 + b), 0.8, Color(0.75, 0.85, 0.95))
				draw_circle(Vector2(2.0, -19.8 + b), 0.8, Color(0.75, 0.85, 0.95))
				# Écharpe qui dépasse de la cape.
				draw_line(Vector2(-4.0, -15.0 + b), Vector2(-7.5, -8.0 + b), Color(0.55, 0.30, 0.30), 2.2)

	func _npc_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
		var pts := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14.0
			pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, color)

	# Le héros tel que créé par le joueur (sexe, design, couleur de classe).
	func _draw_player() -> void:
		var h: Dictionary = GameData.campaign_hero
		var tint: Color = GameData.CLASSES.get(str(h.get("class", "tank")),
				{}).get("color", Color(0.25, 0.42, 0.62))
		HeroFigure.draw_hero(self, str(h.get("gender", "m")),
				int(h.get("design", 0)), tint, phase, moving)

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
		var font := ThemeDB.fallback_font
		if kind == "npc":
			if prompt:
				draw_string(font, Vector2(-60.0, -36.0), "E — Parler",
						HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.0, 0.0, 0.0, 0.7))
				draw_string(font, Vector2(-61.0, -37.0), "E — Parler",
						HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1.0, 0.88, 0.45))
			elif show_label:
				draw_string(font, Vector2(-60.0, -34.0), label,
						HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.0, 0.0, 0.0, 0.7))
				draw_string(font, Vector2(-61.0, -35.0), label,
						HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.80, 0.95, 0.85))
			return
		if kind != "foe":
			return
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

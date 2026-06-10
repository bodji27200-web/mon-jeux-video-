extends Control

# Écran de préparation : choix de la difficulté puis DRAFT alterné.
# Le joueur choisit une classe, puis l'IA, puis le joueur... jusqu'à 3 chacun.
# Une classe choisie (par l'un ou l'autre) quitte le pool commun.

const TEAM_SIZE := 3

# Sprites des classes (réutilise le dico de Unit.gd et la spritesheet CC0).
const UnitScript := preload("res://Unit.gd")
const TILESET := preload("res://assets/dungeon_tileset.png")

var _player: Array = []
var _ai: Array = []
var _difficulty := "normal"
var _team_label: Label
var _ai_label: Label
var _turn_label: Label
var _start_btn: Button
var _info_label: Label
var _info_sprite: TextureRect
var _info_name: Label
var _diff_buttons := {}
var _class_buttons := {}  # cid -> Button (pour les désactiver quand pris)
var _taken := {}          # cid -> true : classes déjà draftées (pool partagé)


func _ready() -> void:
	# Toute l'UI dans un ScrollContainer : le bouton COMBAT reste toujours
	# atteignable même si le contenu dépasse la hauteur de l'écran.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var title := Label.new()
	title.text = "RPG Tactique — Draft d'équipe"
	root.add_child(title)

	root.add_child(_section("Difficulté :"))
	var diff_box := HBoxContainer.new()
	root.add_child(diff_box)
	for d in GameData.DIFFICULTIES:
		var b := Button.new()
		b.text = GameData.DIFFICULTIES[d].name
		b.pressed.connect(_on_difficulty.bind(d))
		diff_box.add_child(b)
		_diff_buttons[d] = b

	root.add_child(_section("Draft (toi, puis l'IA, en alternance — %d chacun). ★ = UNIQUE (1 max). Clique une classe pour voir sa fiche :" % TEAM_SIZE))

	# Zone centrale : grille de cartes (gauche) + fiche détaillée (droite).
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 16)
	root.add_child(middle)

	# Grille de cartes (visuel + nom) — une par classe visible.
	var class_box := GridContainer.new()
	class_box.columns = 5
	middle.add_child(class_box)
	for cid in GameData.CLASSES:
		if GameData.CLASSES[cid].get("hidden", false):
			continue
		var card := _make_class_card(cid)
		class_box.add_child(card)
		_class_buttons[cid] = card

	# Fiche détaillée : visuel agrandi + nom + stats + compétences.
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(320, 0)
	detail.add_theme_constant_override("separation", 4)
	middle.add_child(detail)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	detail.add_child(header)
	_info_sprite = TextureRect.new()
	_info_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_info_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_info_sprite.custom_minimum_size = Vector2(72, 72)
	header.add_child(_info_sprite)
	_info_name = Label.new()
	_info_name.add_theme_font_size_override("font_size", 22)
	_info_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_info_name)
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(320, 0)
	_info_label.add_theme_font_size_override("font_size", 11)
	detail.add_child(_info_label)

	_turn_label = Label.new()
	root.add_child(_turn_label)
	_team_label = Label.new()
	root.add_child(_team_label)
	_ai_label = Label.new()
	root.add_child(_ai_label)

	var menu_btn := Button.new()
	menu_btn.text = "← Menu principal"
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://Title.tscn"))
	root.add_child(menu_btn)

	var reset := Button.new()
	reset.text = "Réinitialiser le draft"
	reset.pressed.connect(_on_reset)
	root.add_child(reset)

	_start_btn = Button.new()
	_start_btn.text = "⚔  COMBAT"
	_start_btn.pressed.connect(_on_start)
	root.add_child(_start_btn)

	_on_difficulty("normal")
	_refresh()
	_show_class_info(_first_visible())
	Audio.play_music("menu")


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = "\n" + text
	return l


# Carte cliquable d'une classe : sprite au-dessus, nom en dessous (★ si unique).
func _make_class_card(cid: String) -> Button:
	var c: Dictionary = GameData.CLASSES[cid]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(88, 72)
	btn.focus_mode = Control.FOCUS_NONE
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 1)
	btn.add_child(vb)
	var tr := TextureRect.new()
	tr.texture = _class_texture(cid)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tr)
	var lbl := Label.new()
	lbl.text = ("★ " if c.get("unique", false) else "") + str(c.name)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 11)
	if c.get("unique", false):
		lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lbl)
	btn.pressed.connect(_on_pick_class.bind(cid))
	btn.mouse_entered.connect(_show_class_info.bind(cid))
	return btn


# Texture du sprite (1re frame idle) d'une classe, depuis la spritesheet.
func _class_texture(cid: String) -> Texture2D:
	if not UnitScript.SPRITES.has(cid):
		return null
	var at := AtlasTexture.new()
	at.atlas = TILESET
	at.region = UnitScript.SPRITES[cid]
	return at


func _role_label(r: String) -> String:
	match r:
		"tank":
			return "Tank (ligne de front)"
		"ranged":
			return "Distance"
		"healer":
			return "Soutien / Soin"
		_:
			return "Corps à corps"


func _first_visible() -> String:
	for cid in GameData.CLASSES:
		if not GameData.CLASSES[cid].get("hidden", false):
			return cid
	return GameData.CLASSES.keys()[0]


func _on_difficulty(d: String) -> void:
	# La difficulté se verrouille dès que le draft a commencé.
	if not _player.is_empty() or not _ai.is_empty():
		return
	_difficulty = d
	for key in _diff_buttons:
		_diff_buttons[key].disabled = (key == d)


# Le joueur choisit une classe : elle quitte le pool, puis l'IA réplique.
# Reclic sur une de SES classes = on la retire (déselection).
func _on_pick_class(cid: String) -> void:
	_show_class_info(cid)
	# Déjà draftée par le joueur → on la retire (et la réponse IA du même tour).
	var idx: int = _player.find(cid)
	if idx != -1:
		_undraft(idx)
		return
	if _player.size() >= TEAM_SIZE:
		return
	if not _class_buttons.has(cid) or _taken.has(cid):
		return
	# Règle : une seule classe unique par équipe.
	if GameData.CLASSES[cid].get("unique", false) and _player_has_unique():
		return
	_player.append(cid)
	_taken[cid] = true
	_lock_difficulty()
	# Réponse de l'IA (si elle n'a pas encore son équipe complète).
	if _ai.size() < TEAM_SIZE:
		var ai_cid: String = TacticalAI.draft_pick(_available(), _ai, _player, _difficulty)
		if ai_cid != "":
			_ai.append(ai_cid)
			_taken[ai_cid] = true
	_update_buttons()
	_refresh()


# Retire la classe joueur à l'index donné + la réponse IA du même tour.
# (Draft alterné : _player[i] et _ai[i] sont le même tour, picks en lockstep.)
func _undraft(idx: int) -> void:
	var pcid: String = _player[idx]
	_player.remove_at(idx)
	_taken.erase(pcid)
	if idx < _ai.size():
		var acid: String = _ai[idx]
		_ai.remove_at(idx)
		_taken.erase(acid)
	# Draft revenu à vide → on redéverrouille la difficulté.
	if _player.is_empty() and _ai.is_empty():
		for key in _diff_buttons:
			_diff_buttons[key].disabled = (key == _difficulty)
	_update_buttons()
	_refresh()


# Le joueur possède-t-il déjà une classe unique ?
func _player_has_unique() -> bool:
	for c in _player:
		if GameData.CLASSES[c].get("unique", false):
			return true
	return false


# Met à jour l'état des boutons. Tes propres classes restent CLIQUABLES (pour
# pouvoir les retirer) et teintées en vert ; les classes prises par l'IA ou
# verrouillées (unique) sont grisées et désactivées.
func _update_buttons() -> void:
	var locked: bool = _player_has_unique() or _player.size() >= TEAM_SIZE
	for cid in _class_buttons:
		var mine: bool = cid in _player
		var taken: bool = _taken.has(cid) and not mine
		var unique_locked: bool = locked and GameData.CLASSES[cid].get("unique", false) and not mine
		var dis: bool = taken or unique_locked
		_class_buttons[cid].disabled = dis
		if mine:
			# Sélectionnée par toi : verte, cliquable pour la retirer.
			_class_buttons[cid].modulate = Color(0.55, 1.0, 0.55)
		else:
			_class_buttons[cid].modulate = Color(0.45, 0.45, 0.5) if dis else Color(1, 1, 1)


func _available() -> Array:
	var pool: Array = []
	for cid in _class_buttons:
		if not _taken.has(cid):
			pool.append(cid)
	return pool


func _lock_difficulty() -> void:
	for key in _diff_buttons:
		_diff_buttons[key].disabled = true


func _on_reset() -> void:
	_player.clear()
	_ai.clear()
	_taken.clear()
	_update_buttons()
	# Déverrouille la difficulté (draft vide).
	for key in _diff_buttons:
		_diff_buttons[key].disabled = (key == _difficulty)
	_refresh()


func _refresh() -> void:
	_team_label.text = "Ton équipe : " + _team_names(_player)
	_ai_label.text = "Équipe IA : " + _team_names(_ai)
	if _player.size() < TEAM_SIZE:
		_turn_label.text = "À toi de choisir (%d/%d)" % [_player.size(), TEAM_SIZE]
	else:
		_turn_label.text = "Draft terminé — prêt au combat !"
	_start_btn.disabled = _player.size() < TEAM_SIZE


func _team_names(team: Array) -> String:
	if team.is_empty():
		return "(vide)"
	var names: Array = []
	for cid in team:
		names.append(GameData.CLASSES[cid].name)
	return ", ".join(names)


# Construit et affiche la fiche complète d'une classe (stats + compétences).
func _show_class_info(cid: String) -> void:
	if _info_label == null:
		return
	var c: Dictionary = GameData.CLASSES[cid]
	# En-tête : visuel agrandi + nom (doré si unique).
	if _info_sprite:
		_info_sprite.texture = _class_texture(cid)
	if _info_name:
		_info_name.text = ("★ " if c.get("unique", false) else "") + str(c.name)
		_info_name.add_theme_color_override("font_color",
				Color(1.0, 0.84, 0.30) if c.get("unique", false) else Color(1, 1, 1))
	var t := ""
	if c.get("unique", false):
		t += "CLASSE UNIQUE — 1 seule par équipe\n"
	t += "%s\n\n" % c.get("description", "")
	t += "Rôle : %s\n" % _role_label(str(c.get("role", "melee")))
	t += "PV %d    Dégâts %d    Portée %d    Déplacement %d\n" % [c.max_hp, c.attack, c.attack_range, c.move_range]
	t += "Coups critiques : %d%%" % int(c.crit_chance * 100)
	if c.has("on_hit"):
		t += "    Sur chaque attaque : %s" % str(GameData.BUFFS.get(c.on_hit, {}).get("name", c.on_hit))
	# Compétences actives (jusqu'à 3 ; les emplacements suivants sont à venir).
	var acts: Array = c.get("actives", [c.active] if c.has("active") else [])
	t += "\n\nCompétences :\n"
	for i in 3:
		if i < acts.size():
			var s: Dictionary = acts[i]
			t += "• %s — %s\n" % [str(s["name"]), str(s.get("desc", ""))]
		else:
			t += "• (emplacement libre — à venir)\n"
	_info_label.text = t


func _on_start() -> void:
	if _player.size() < TEAM_SIZE or _ai.size() < TEAM_SIZE:
		return
	GameData.difficulty = _difficulty
	GameData.player_team = _player.duplicate()
	GameData.ai_team = _ai.duplicate()
	get_tree().change_scene_to_file("res://Main.tscn")

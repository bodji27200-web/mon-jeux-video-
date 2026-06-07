extends Control

# Écran de préparation : choix de la difficulté puis DRAFT alterné.
# Le joueur choisit une classe, puis l'IA, puis le joueur... jusqu'à 3 chacun.
# Une classe choisie (par l'un ou l'autre) quitte le pool commun.

const TEAM_SIZE := 3

var _player: Array = []
var _ai: Array = []
var _difficulty := "normal"
var _team_label: Label
var _ai_label: Label
var _turn_label: Label
var _start_btn: Button
var _info_label: Label
var _diff_buttons := {}
var _class_buttons := {}  # cid -> Button (pour les désactiver quand pris)


func _ready() -> void:
	var root := VBoxContainer.new()
	root.position = Vector2(40, 30)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

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

	root.add_child(_section("Draft (toi, puis l'IA, en alternance — %d chacun) :" % TEAM_SIZE))
	# Grille pour éviter que la rangée de classes déborde de la fenêtre.
	var class_box := GridContainer.new()
	class_box.columns = 5
	root.add_child(class_box)
	for cid in GameData.CLASSES:
		if GameData.CLASSES[cid].get("hidden", false):
			continue
		var b := Button.new()
		b.text = GameData.CLASSES[cid].name
		b.pressed.connect(_on_pick_class.bind(cid))
		b.mouse_entered.connect(_show_class_info.bind(cid))
		b.focus_entered.connect(_show_class_info.bind(cid))
		class_box.add_child(b)
		_class_buttons[cid] = b

	# Fiche détaillée de la classe survolée / cliquée (pour comparer avant de choisir).
	root.add_child(_section("Fiche de la classe (survole un bouton) :"))
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(560, 180)
	root.add_child(_info_label)

	_turn_label = Label.new()
	root.add_child(_turn_label)
	_team_label = Label.new()
	root.add_child(_team_label)
	_ai_label = Label.new()
	root.add_child(_ai_label)

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


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = "\n" + text
	return l


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
func _on_pick_class(cid: String) -> void:
	_show_class_info(cid)
	if _player.size() >= TEAM_SIZE:
		return
	if not _class_buttons.has(cid) or _class_buttons[cid].disabled:
		return
	_player.append(cid)
	_class_buttons[cid].disabled = true
	_lock_difficulty()
	# Réponse de l'IA (si elle n'a pas encore son équipe complète).
	if _ai.size() < TEAM_SIZE:
		var ai_cid: String = TacticalAI.draft_pick(_available(), _ai, _player, _difficulty)
		if ai_cid != "":
			_ai.append(ai_cid)
			if _class_buttons.has(ai_cid):
				_class_buttons[ai_cid].disabled = true
	_refresh()


func _available() -> Array:
	var pool: Array = []
	for cid in _class_buttons:
		if not _class_buttons[cid].disabled:
			pool.append(cid)
	return pool


func _lock_difficulty() -> void:
	for key in _diff_buttons:
		_diff_buttons[key].disabled = true


func _on_reset() -> void:
	_player.clear()
	_ai.clear()
	for cid in _class_buttons:
		_class_buttons[cid].disabled = false
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
	var t := "%s\n%s\n\n" % [c.name, c.get("description", "")]
	t += "PV : %d    Dégâts : %d    Portée d'attaque : %d    Déplacement : %d\n" % [c.max_hp, c.attack, c.attack_range, c.move_range]
	t += "Coups critiques : %d%%\n\nCompétences :\n" % int(c.crit_chance * 100)
	for s in c.get("skills", []):
		var line := "• " + str(s["name"]) + " — " + str(s["description"])
		var extras: Array = []
		if s.has("damage"):
			extras.append("Dégâts %d" % int(s["damage"]))
		if s.has("range"):
			extras.append("Portée %d" % int(s["range"]))
		if not extras.is_empty():
			line += " (" + ", ".join(extras) + ")"
		t += line + "\n    Effet : " + str(s["effect"]) + "\n"
	_info_label.text = t


func _on_start() -> void:
	if _player.size() < TEAM_SIZE:
		return
	GameData.difficulty = _difficulty
	GameData.player_team = _player.duplicate()
	GameData.ai_team = _ai.duplicate()
	get_tree().change_scene_to_file("res://Main.tscn")

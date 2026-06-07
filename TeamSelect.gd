extends Control

# Écran de préparation : choix de la difficulté et de l'équipe du joueur.
# L'IA compose son équipe automatiquement, puis on lance le combat.

const MAX_TEAM := 3

var _player: Array = []
var _difficulty := "normal"
var _team_label: Label
var _start_btn: Button
var _info_label: Label
var _diff_buttons := {}


func _ready() -> void:
	var root := VBoxContainer.new()
	root.position = Vector2(40, 30)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	title.text = "RPG Tactique — Préparation du combat"
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

	root.add_child(_section("Choisis ton équipe (max %d) :" % MAX_TEAM))
	var class_box := HBoxContainer.new()
	root.add_child(class_box)
	for cid in GameData.CLASSES:
		var b := Button.new()
		b.text = GameData.CLASSES[cid].name
		b.pressed.connect(_on_add_class.bind(cid))
		b.mouse_entered.connect(_show_class_info.bind(cid))
		b.focus_entered.connect(_show_class_info.bind(cid))
		class_box.add_child(b)

	# Fiche détaillée de la classe survolée / cliquée (pour comparer avant de choisir).
	root.add_child(_section("Fiche de la classe (survole un bouton) :"))
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(560, 200)
	root.add_child(_info_label)

	_team_label = Label.new()
	root.add_child(_team_label)

	var reset := Button.new()
	reset.text = "Réinitialiser l'équipe"
	reset.pressed.connect(_on_reset)
	root.add_child(reset)

	_start_btn = Button.new()
	_start_btn.text = "⚔  COMBAT"
	_start_btn.pressed.connect(_on_start)
	root.add_child(_start_btn)

	_on_difficulty("normal")
	_refresh()
	_show_class_info(GameData.CLASSES.keys()[0])


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = "\n" + text
	return l


func _on_difficulty(d: String) -> void:
	_difficulty = d
	for key in _diff_buttons:
		_diff_buttons[key].disabled = (key == d)


func _on_add_class(cid: String) -> void:
	_show_class_info(cid)
	if _player.size() < MAX_TEAM:
		_player.append(cid)
		_refresh()


func _on_reset() -> void:
	_player.clear()
	_refresh()


func _refresh() -> void:
	var names: Array = []
	for cid in _player:
		names.append(GameData.CLASSES[cid].name)
	_team_label.text = "Équipe : " + (", ".join(names) if names.size() > 0 else "(vide)")
	_start_btn.disabled = _player.is_empty()


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
	GameData.difficulty = _difficulty
	GameData.player_team = _player.duplicate()
	GameData.ai_team = _make_ai_team(_player.size())
	get_tree().change_scene_to_file("res://Main.tscn")


# L'IA prend autant d'unités que le joueur, choisies aléatoirement.
func _make_ai_team(count: int) -> Array:
	var ids: Array = GameData.CLASSES.keys()
	var team: Array = []
	for i in count:
		team.append(ids[randi() % ids.size()])
	return team

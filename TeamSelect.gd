extends Control

# Écran de préparation : choix de la difficulté et de l'équipe du joueur.
# L'IA compose son équipe automatiquement, puis on lance le combat.

const MAX_TEAM := 3

var _player: Array = []
var _difficulty := "normal"
var _team_label: Label
var _start_btn: Button
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
		class_box.add_child(b)

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


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = "\n" + text
	return l


func _on_difficulty(d: String) -> void:
	_difficulty = d
	for key in _diff_buttons:
		_diff_buttons[key].disabled = (key == d)


func _on_add_class(cid: String) -> void:
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

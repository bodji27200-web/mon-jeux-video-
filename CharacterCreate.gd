extends Control

# Création de personnage (début de campagne, façon BG3) : nom, sexe, apparence
# (3 designs par sexe, dessinés à la main via HeroFigure), classe parmi les
# classes débloquées. Le héros démarre SEUL dans la vallée ; les compagnons
# viendront agrandir l'équipe (phase suivante). Tout est construit en code.

var _gender := "f"
var _design := 0
var _class_id := "tank"

var _preview: Control
var _name_edit: LineEdit
var _design_label: Label
var _gender_buttons := {}
var _class_buttons := {}
var _desc_label: Label
var _phase := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_select_class("tank")
	Audio.play_music("menu")


var _preview_t := 0.0
func _process(delta: float) -> void:
	# Aperçu animé à 15 i/s (règle perf : jamais de redraw vectoriel à 60 i/s).
	_phase += delta * 2.2
	_preview_t += delta
	if _preview_t >= 1.0 / 15.0:
		_preview_t = 0.0
		_preview.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.08))
	draw_rect(Rect2(0, size.y - 4, size.x, 4), Color(0.45, 0.12, 0.12, 0.6))


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Création de personnage"
	title.position = Vector2(0, 14)
	title.custom_minimum_size = Vector2(832, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	add_child(title)

	# --- Colonne gauche : aperçu animé + sexe + design ---
	var left := VBoxContainer.new()
	left.position = Vector2(36, 70)
	left.custom_minimum_size = Vector2(220, 0)
	left.add_theme_constant_override("separation", 10)
	add_child(left)

	var pv_panel := PanelContainer.new()
	pv_panel.custom_minimum_size = Vector2(220, 220)
	left.add_child(pv_panel)
	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(220, 220)
	_preview.draw.connect(_draw_preview)
	pv_panel.add_child(_preview)

	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 8)
	left.add_child(grow)
	for g in [["f", "♀ Fille"], ["m", "♂ Garçon"]]:
		var b := Button.new()
		b.text = g[1]
		b.custom_minimum_size = Vector2(104, 40)
		b.focus_mode = Control.FOCUS_NONE
		var gid: String = g[0]
		b.pressed.connect(func():
			Audio.play_sfx("click")
			_gender = gid
			_refresh_gender())
		grow.add_child(b)
		_gender_buttons[gid] = b

	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	left.add_child(drow)
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(40, 36)
	prev.focus_mode = Control.FOCUS_NONE
	prev.pressed.connect(func():
		Audio.play_sfx("click")
		_design = (_design + HeroFigure.DESIGN_COUNT - 1) % HeroFigure.DESIGN_COUNT
		_refresh_design())
	drow.add_child(prev)
	_design_label = Label.new()
	_design_label.custom_minimum_size = Vector2(124, 36)
	_design_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_design_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_design_label.add_theme_font_size_override("font_size", 16)
	drow.add_child(_design_label)
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(40, 36)
	next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(func():
		Audio.play_sfx("click")
		_design = (_design + 1) % HeroFigure.DESIGN_COUNT
		_refresh_design())
	drow.add_child(next)

	var name_lbl := Label.new()
	name_lbl.text = "Nom du héros :"
	name_lbl.add_theme_font_size_override("font_size", 16)
	left.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Entre ton nom..."
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(220, 38)
	_name_edit.text_changed.connect(func(_t): _name_edit.modulate = Color.WHITE)
	left.add_child(_name_edit)

	# --- Colonne droite : choix de classe + description ---
	var right := VBoxContainer.new()
	right.position = Vector2(286, 70)
	right.custom_minimum_size = Vector2(510, 0)
	right.add_theme_constant_override("separation", 8)
	add_child(right)

	var cl := Label.new()
	cl.text = "Classe (débloquées par tes victoires et l'exploration) :"
	cl.add_theme_font_size_override("font_size", 16)
	right.add_child(cl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(510, 300)
	right.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for cid in GameData.CLASSES:
		var data: Dictionary = GameData.CLASSES[cid]
		if data.get("hidden", false):
			continue
		var b := Button.new()
		var unlocked: bool = GameData.is_unlocked(cid)
		b.text = str(data.name) if unlocked else "🔒 %s" % str(data.name)
		b.custom_minimum_size = Vector2(164, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not unlocked
		var c := str(cid)
		b.pressed.connect(func():
			Audio.play_sfx("click")
			_select_class(c))
		grid.add_child(b)
		_class_buttons[cid] = b

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(510, 130)
	_desc_label.add_theme_font_size_override("font_size", 15)
	_desc_label.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	right.add_child(_desc_label)

	# --- Bas : retour / commencer ---
	var back := Button.new()
	back.text = "← Retour"
	back.position = Vector2(36, 704 - 58)
	back.custom_minimum_size = Vector2(140, 44)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func():
		Audio.play_sfx("click")
		get_tree().change_scene_to_file("res://Title.tscn"))
	add_child(back)
	var start := Button.new()
	start.text = "⚔  Commencer l'aventure"
	start.position = Vector2(832 - 296, 704 - 58)
	start.custom_minimum_size = Vector2(260, 44)
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(_on_start)
	add_child(start)

	_refresh_gender()


func _draw_preview() -> void:
	var c: Control = _preview
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.09, 0.09, 0.13))
	# Sol + héros agrandi ×4, posé au bas du cadre.
	var base := Vector2(c.size.x / 2.0, c.size.y - 40.0)
	c.draw_set_transform(base, 0.0, Vector2(1.0, 0.5))
	c.draw_circle(Vector2.ZERO, 36.0, Color(0.0, 0.0, 0.0, 0.30))
	c.draw_set_transform(base, 0.0, Vector2(4.0, 4.0))
	var tint: Color = GameData.CLASSES[_class_id].color
	HeroFigure.draw_hero(c, _gender, _design, tint, _phase, false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _refresh_gender() -> void:
	for gid in _gender_buttons:
		var b: Button = _gender_buttons[gid]
		b.modulate = Color(1.0, 0.9, 0.5) if gid == _gender else Color(1, 1, 1)
	_refresh_design()


func _refresh_design() -> void:
	_design_label.text = "Apparence %d / %d" % [_design + 1, HeroFigure.DESIGN_COUNT]


func _select_class(cid: String) -> void:
	_class_id = cid
	for k in _class_buttons:
		_class_buttons[k].modulate = Color(1.0, 0.9, 0.5) if k == cid else Color(1, 1, 1)
	var d: Dictionary = GameData.CLASSES[cid]
	var skills := ""
	for a in d.get("actives", []):
		skills += "\n• %s" % str(a.name)
	_desc_label.text = "%s — %s\nPV %d · ATK %d · Portée %d · Déplacement %d%s" % [
			str(d.name), str(d.description), int(d.max_hp), int(d.attack),
			int(d.attack_range), int(d.move_range), skills]


func _on_start() -> void:
	var hero_name := _name_edit.text.strip_edges()
	if hero_name == "":
		# Nom obligatoire : on refuse le départ et on signale le champ.
		Audio.play_sfx("click")
		_name_edit.placeholder_text = "⚠  Entre un nom !"
		_name_edit.modulate = Color(1.0, 0.5, 0.5)
		_name_edit.grab_focus()
		return
	Audio.play_sfx("click")
	GameData.campaign_hero = {
		"name": hero_name, "gender": _gender,
		"design": _design, "class": _class_id,
	}
	GameData.campaign_pos = Vector2(-1, -1)  # départ au hameau
	GameData.save_campaign()
	get_tree().change_scene_to_file("res://Overworld.tscn")

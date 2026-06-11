extends Control

# Écran-titre : titre stylisé, boutons Jouer / Réglages / Quitter, et un panneau
# de réglages (volumes Master / Musique / Effets) en superposition. Tout est
# construit en code (aucun asset externe), cohérent avec le reste du projet.

const BUS_LABELS := {"Master": "Volume général", "Music": "Musique", "SFX": "Effets"}

var _settings_panel: PanelContainer
var _difficulty_panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	_build_settings()
	_build_difficulty()
	Audio.play_music("menu")


# --- Fond dessiné (dégradé sombre + quelques runes) ---
func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.05, 0.08))
	# Halo central froid.
	for i in range(8, 0, -1):
		var r := float(i) / 8.0
		draw_circle(s * Vector2(0.5, 0.40), 320.0 * r,
				Color(0.12, 0.14, 0.22, 0.06))
	# Liseré bas.
	draw_rect(Rect2(0, s.y - 4, s.x, 4), Color(0.45, 0.12, 0.12, 0.6))


func _build_menu() -> void:
	# Ancres centrées (et non une position absolue calculée sur `size`, qui n'est
	# pas fiable au _ready quand la fenêtre démarre maximisée) : le moteur de
	# layout recentre automatiquement, quelle que soit la résolution.
	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.22
	center.anchor_bottom = 0.22
	center.offset_left = -160.0
	center.offset_right = 160.0
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 14)
	add_child(center)

	var title := Label.new()
	title.text = "RPG TACTIQUE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	center.add_child(title)

	var sub := Label.new()
	sub.text = "— Dark Fantasy —"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.70, 0.25, 0.25))
	center.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	center.add_child(spacer)

	center.add_child(_menu_button("⚜  Campagne", _on_campaign))
	center.add_child(_menu_button("⚔  Partie rapide", _on_play))
	center.add_child(_menu_button("⚙  Réglages", _on_settings))
	center.add_child(_menu_button("✕  Quitter", _on_quit))


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func():
		Audio.play_sfx("click")
		cb.call())
	return b


# --- Panneau de réglages (superposition, caché par défaut) ---
func _build_settings() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.anchor_left = 0.5
	_settings_panel.anchor_right = 0.5
	_settings_panel.anchor_top = 0.5
	_settings_panel.anchor_bottom = 0.5
	_settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settings_panel.custom_minimum_size = Vector2(420, 0)
	_settings_panel.visible = false
	add_child(_settings_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(vb)

	var head := Label.new()
	head.text = "Réglages — Audio"
	head.add_theme_font_size_override("font_size", 26)
	vb.add_child(head)

	for bus in ["Master", "Music", "SFX"]:
		vb.add_child(_volume_row(bus))

	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0, 42)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func():
		GameData.save_settings()
		_settings_panel.visible = false)
	vb.add_child(back)


# Une ligne : libellé + slider 0..100 % piloté en direct.
func _volume_row(bus: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = str(BUS_LABELS[bus])
	lbl.custom_minimum_size = Vector2(150, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(GameData.volumes.get(bus, 1.0))
	slider.custom_minimum_size = Vector2(200, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var pct := Label.new()
	pct.custom_minimum_size = Vector2(50, 0)
	pct.add_theme_font_size_override("font_size", 18)
	pct.text = "%d%%" % int(slider.value * 100)

	slider.value_changed.connect(func(v):
		GameData.apply_volume(bus, v)
		pct.text = "%d%%" % int(v * 100))
	row.add_child(slider)
	row.add_child(pct)
	return row


func _on_campaign() -> void:
	# Campagne déjà commencée → on reprend directement ; sinon, choix de la
	# difficulté d'abord (Hardcore = mort de l'équipe → campagne effacée).
	if GameData.campaign_pos.x >= 0.0 or GameData.campaign_defeated.size() > 0:
		get_tree().change_scene_to_file("res://Overworld.tscn")
		return
	_difficulty_panel.visible = true


# --- Panneau « Nouvelle campagne » : choix de la difficulté ---
func _build_difficulty() -> void:
	_difficulty_panel = PanelContainer.new()
	_difficulty_panel.anchor_left = 0.5
	_difficulty_panel.anchor_right = 0.5
	_difficulty_panel.anchor_top = 0.5
	_difficulty_panel.anchor_bottom = 0.5
	_difficulty_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_difficulty_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_difficulty_panel.custom_minimum_size = Vector2(440, 0)
	_difficulty_panel.visible = false
	add_child(_difficulty_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_difficulty_panel.add_child(vb)

	var head := Label.new()
	head.text = "Nouvelle campagne — Difficulté"
	head.add_theme_font_size_override("font_size", 24)
	vb.add_child(head)

	var descs := {
		"facile": "IA indulgente, idéal pour découvrir.",
		"normal": "L'expérience équilibrée recommandée.",
		"difficile": "IA affûtée, les erreurs coûtent cher.",
		"hardcore": "☠ Mort de l'équipe = campagne PERDUE (progression effacée).",
	}
	for diff_id in ["facile", "normal", "difficile", "hardcore"]:
		var b := Button.new()
		b.text = "%s — %s" % [GameData.DIFFICULTIES[diff_id].name, descs[diff_id]]
		b.custom_minimum_size = Vector2(0, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var d: String = diff_id  # capture
		b.pressed.connect(func():
			Audio.play_sfx("click")
			_start_campaign(d))
		vb.add_child(b)

	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0, 40)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func():
		Audio.play_sfx("click")
		_difficulty_panel.visible = false)
	vb.add_child(back)


func _start_campaign(diff: String) -> void:
	GameData.campaign_difficulty = diff
	GameData.save_settings()
	get_tree().change_scene_to_file("res://Overworld.tscn")


func _on_play() -> void:
	get_tree().change_scene_to_file("res://TeamSelect.tscn")


func _on_settings() -> void:
	_settings_panel.visible = true


func _on_quit() -> void:
	get_tree().quit()

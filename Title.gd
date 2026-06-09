extends Control

# Écran-titre : titre stylisé, boutons Jouer / Réglages / Quitter, et un panneau
# de réglages (volumes Master / Musique / Effets) en superposition. Tout est
# construit en code (aucun asset externe), cohérent avec le reste du projet.

const BUS_LABELS := {"Master": "Volume général", "Music": "Musique", "SFX": "Effets"}

var _settings_panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_menu()
	_build_settings()
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
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 14)
	center.position = Vector2(size.x * 0.5 - 150, size.y * 0.28)
	center.custom_minimum_size = Vector2(300, 0)
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

	center.add_child(_menu_button("⚔  Jouer", _on_play))
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
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.custom_minimum_size = Vector2(420, 0)
	_settings_panel.position = Vector2(size.x * 0.5 - 210, size.y * 0.30)
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


func _on_play() -> void:
	get_tree().change_scene_to_file("res://TeamSelect.tscn")


func _on_settings() -> void:
	_settings_panel.visible = true


func _on_quit() -> void:
	get_tree().quit()

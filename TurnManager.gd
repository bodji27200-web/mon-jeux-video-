extends Node

# Gère le système de tours : qui joue, et le passage au tour suivant.
# Étape 2 : on alterne simplement entre les unités avec la touche Espace.

@export var turn_label: Label

var units: Array = []
var current_index := 0


func _ready() -> void:
	# Récupère toutes les unités présentes sur la grille.
	units = get_tree().get_nodes_in_group("units")
	if units.is_empty():
		return
	_update_turn()


func _unhandled_input(event: InputEvent) -> void:
	# Espace (ou Entrée) = passer au tour suivant.
	if event.is_action_pressed("ui_accept"):
		next_turn()


func next_turn() -> void:
	if units.is_empty():
		return
	current_index = (current_index + 1) % units.size()
	_update_turn()


func _update_turn() -> void:
	# Met en surbrillance l'unité active et met à jour le texte.
	for i in units.size():
		units[i].set_active(i == current_index)
	if turn_label:
		turn_label.text = "Tour de : %s" % units[current_index].unit_name

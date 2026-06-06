extends Node

# Système de tours : ordre de jeu et passage d'une unité à la suivante.

signal turn_started(unit)

@export var turn_label: Label

var units: Array = []
var current_index := -1


func start() -> void:
	units = get_tree().get_nodes_in_group("units")
	if units.is_empty():
		return
	_begin(0)


func current_unit() -> Node:
	return units[current_index] if current_index >= 0 else null


func next_turn() -> void:
	var n := units.size()
	for i in range(1, n + 1):
		var cand := (current_index + i) % n
		if units[cand].is_alive():
			_begin(cand)
			return


func _begin(index: int) -> void:
	current_index = index
	var unit: Node = units[index]
	for u in units:
		u.set_active(u == unit)
	unit.reset_turn()
	if turn_label:
		var camp := "Joueur" if unit.is_player() else "IA"
		turn_label.text = "Tour de : %s (%s)" % [unit.data.name, camp]
	turn_started.emit(unit)

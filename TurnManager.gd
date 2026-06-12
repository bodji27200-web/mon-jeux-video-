extends Node

# Système de tours : ordre de jeu et passage d'une unité à la suivante.

signal turn_started(unit)

@export var turn_label: NodePath  # chemin vers le Label d'affichage du tour
var label: Label                  # Label résolu (depuis turn_label)

var units: Array = []
var current_index := -1


func _ready() -> void:
	label = get_node_or_null(turn_label) as Label


func start() -> void:
	units = get_tree().get_nodes_in_group("units")
	if units.is_empty():
		return
	# Ordre des tours façon Sword of Convallaria : les plus AGILES d'abord
	# (champ "agility" de la classe, sinon son déplacement). Tri stable.
	units.sort_custom(func(a, b):
		return _agility(a) > _agility(b))
	_begin(0)


static func _agility(u: Node) -> int:
	return int(u.data.get("agility", u.data.move_range))


func current_unit() -> Node:
	return units[current_index] if current_index >= 0 else null


func next_turn() -> void:
	var n := units.size()
	for i in range(1, n + 1):
		var cand := (current_index + i) % n
		if units[cand].is_alive():
			_begin(cand)
			return
	turn_started.emit(null)  # sécurité : toutes les unités mortes, Battle._check_end gère


# Ajoute une unité invoquée en cours de partie (ex : squelette du nécromancien).
func add_unit(unit: Node) -> void:
	units.append(unit)


func _begin(index: int) -> void:
	current_index = index
	var unit: Node = units[index]
	for u in units:
		u.set_active(u == unit)
	unit.reset_turn()
	if label:
		var camp := "Joueur" if unit.is_player() else "IA"
		var nm: String = unit.display_name if unit.display_name != "" else str(unit.data.name)
		label.text = "Tour de : %s (%s)" % [nm, camp]
	turn_started.emit(unit)

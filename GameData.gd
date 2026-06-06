extends Node

# Données centrales du jeu (architecture data-driven).
# Ajouter une classe = ajouter une entrée dans CLASSES. Aucune logique en dur.

enum Team { PLAYER, AI }

const CLASSES := {
	"tank": {
		"name": "Tank", "color": Color(0.30, 0.50, 1.00), "symbol": "T",
		"max_hp": 42, "move_range": 3, "attack": 8, "attack_range": 1,
		"crit_chance": 0.05, "behavior": "melee",
	},
	"archer": {
		"name": "Archer", "color": Color(0.30, 0.85, 0.40), "symbol": "A",
		"max_hp": 22, "move_range": 4, "attack": 10, "attack_range": 4,
		"crit_chance": 0.20, "behavior": "kite",
	},
}

# Sélections courantes (définies à l'écran de préparation, étape 6).
var difficulty := "normal"
var player_team: Array = ["tank"]
var ai_team: Array = ["archer"]

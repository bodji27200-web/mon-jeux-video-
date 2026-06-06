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

# Difficultés (les effets sont appliqués à l'étape 9 dans l'IA et les dégâts).
const DIFFICULTIES := {
	"facile":    {"name": "Facile",    "ai_mistake_chance": 0.35, "ai_damage_mult": 0.85, "player_damage_mult": 1.15},
	"normal":    {"name": "Normal",    "ai_mistake_chance": 0.10, "ai_damage_mult": 1.00, "player_damage_mult": 1.00},
	"difficile": {"name": "Difficile", "ai_mistake_chance": 0.0,  "ai_damage_mult": 1.10, "player_damage_mult": 1.00},
	"hardcore":  {"name": "Hardcore",  "ai_mistake_chance": 0.0,  "ai_damage_mult": 1.25, "player_damage_mult": 0.90},
}

# Sélections courantes (définies à l'écran de préparation, étape 6).
var difficulty := "normal"
var player_team: Array = ["tank"]
var ai_team: Array = ["archer"]

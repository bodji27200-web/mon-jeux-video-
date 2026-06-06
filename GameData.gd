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
		"crit_chance": 0.20, "behavior": "kite", "on_hit": "poison",
	},
	"assassin": {
		"name": "Assassin", "color": Color(0.60, 0.30, 0.80), "symbol": "S",
		"max_hp": 18, "move_range": 5, "attack": 14, "attack_range": 1,
		"crit_chance": 0.35, "behavior": "melee",
	},
	"mage": {
		"name": "Mage", "color": Color(0.85, 0.25, 0.25), "symbol": "M",
		"max_hp": 20, "move_range": 3, "attack": 13, "attack_range": 3,
		"crit_chance": 0.10, "behavior": "kite", "on_hit": "brulure",
	},
	"soigneur": {
		"name": "Soigneur", "color": Color(0.95, 0.95, 0.95), "symbol": "+",
		"max_hp": 24, "move_range": 3, "attack": 4, "attack_range": 1,
		"crit_chance": 0.0, "behavior": "heal", "heal": 12,
	},
	"paladin": {
		"name": "Paladin", "color": Color(0.90, 0.80, 0.30), "symbol": "P",
		"max_hp": 38, "move_range": 3, "attack": 9, "attack_range": 1,
		"crit_chance": 0.05, "behavior": "melee",
	},
	"berserker": {
		"name": "Berserker", "color": Color(0.95, 0.50, 0.20), "symbol": "B",
		"max_hp": 30, "move_range": 4, "attack": 12, "attack_range": 1,
		"crit_chance": 0.15, "behavior": "melee",
	},
}

# Difficultés (les effets sont appliqués à l'étape 9 dans l'IA et les dégâts).
const DIFFICULTIES := {
	"facile":    {"name": "Facile",    "ai_mistake_chance": 0.35, "ai_damage_mult": 0.85, "player_damage_mult": 1.15},
	"normal":    {"name": "Normal",    "ai_mistake_chance": 0.10, "ai_damage_mult": 1.00, "player_damage_mult": 1.00},
	"difficile": {"name": "Difficile", "ai_mistake_chance": 0.0,  "ai_damage_mult": 1.10, "player_damage_mult": 1.00},
	"hardcore":  {"name": "Hardcore",  "ai_mistake_chance": 0.0,  "ai_damage_mult": 1.25, "player_damage_mult": 0.90},
}

# Buffs / debuffs génériques. Un effet = quelques champs optionnels :
#  dmg_per_turn / heal_per_turn (à chaque tour), dmg_taken_mult / dmg_dealt_mult.
const BUFFS := {
	"poison":   {"name": "Poison",       "duration": 3, "dmg_per_turn": 3},
	"brulure":  {"name": "Brûlure",      "duration": 2, "dmg_per_turn": 5},
	"regen":    {"name": "Régénération", "duration": 3, "heal_per_turn": 5},
	"bouclier": {"name": "Bouclier",     "duration": 2, "dmg_taken_mult": 0.5},
	"force":    {"name": "Force",        "duration": 2, "dmg_dealt_mult": 1.5},
}

# Sélections courantes (définies à l'écran de préparation, étape 6).
var difficulty := "normal"
var player_team: Array = ["tank"]
var ai_team: Array = ["archer"]

extends Node

# Données centrales du jeu (architecture data-driven).
# Ajouter une classe = ajouter une entrée dans CLASSES. Aucune logique en dur.

enum Team { PLAYER, AI }

const CLASSES := {
	"tank": {
		"name": "Tank", "color": Color(0.30, 0.50, 1.00), "symbol": "T",
		"description": "Mur défensif. Beaucoup de PV, encaisse les coups en première ligne.",
		"max_hp": 42, "move_range": 3, "attack": 8, "attack_range": 1,
		"crit_chance": 0.05, "behavior": "melee", "role": "tank",
		"active": {"name": "Protection", "type": "shield_ally", "target": "ally", "range": 2, "cooldown": 3,
			"desc": "Donne un bouclier (dégâts réduits de moitié) à un allié à 2 cases."},
		"skills": [
			{"name": "Frappe", "description": "Attaque de mêlée de base.", "effect": "Inflige des dégâts au corps à corps.", "damage": 8, "range": 1},
			{"name": "Robustesse", "description": "PV très élevés (passif).", "effect": "Encaisse les dégâts pour protéger l'équipe."},
			{"name": "Protection (compétence)", "description": "Bouclier sur un allié.", "effect": "Réduit de moitié les dégâts subis par un allié pendant 2 tours. Recharge : 3 tours."},
		],
	},
	"archer": {
		"name": "Archer", "color": Color(0.30, 0.85, 0.40), "symbol": "A",
		"description": "Tireur agile. Harcèle de loin et empoisonne ses cibles.",
		"max_hp": 22, "move_range": 4, "attack": 10, "attack_range": 4,
		"crit_chance": 0.20, "behavior": "kite", "on_hit": "poison", "role": "ranged",
		"skills": [
			{"name": "Tir", "description": "Attaque à distance.", "effect": "Inflige des dégâts à distance.", "damage": 10, "range": 4},
			{"name": "Flèche empoisonnée", "description": "Chaque tir empoisonne la cible.", "effect": "Applique Poison : 3 dégâts/tour pendant 3 tours.", "range": 4},
		],
	},
	"assassin": {
		"name": "Assassin", "color": Color(0.60, 0.30, 0.80), "symbol": "S",
		"description": "Tueur mobile. Très grande mobilité et coups critiques dévastateurs.",
		"max_hp": 18, "move_range": 5, "attack": 14, "attack_range": 1,
		"crit_chance": 0.35, "behavior": "melee", "role": "melee",
		"active": {"name": "Frappe de l'ombre", "type": "teleport_strike", "target": "enemy", "range": 5, "cooldown": 3,
			"desc": "Se téléporte au contact d'un ennemi (jusqu'à 5 cases) et le frappe."},
		"skills": [
			{"name": "Lame rapide", "description": "Attaque de mêlée puissante.", "effect": "Inflige de gros dégâts au corps à corps.", "damage": 14, "range": 1},
			{"name": "Coups critiques", "description": "35% de chances de coup critique.", "effect": "Double les dégâts de l'attaque."},
			{"name": "Frappe de l'ombre (compétence)", "description": "Téléportation offensive.", "effect": "Se téléporte au contact d'un ennemi à 5 cases puis l'attaque. Recharge : 3 tours."},
		],
	},
	"mage": {
		"name": "Mage", "color": Color(0.85, 0.25, 0.25), "symbol": "M",
		"description": "Lanceur de sorts. Dégâts à distance et brûlures.",
		"max_hp": 20, "move_range": 3, "attack": 13, "attack_range": 3,
		"crit_chance": 0.10, "behavior": "kite", "on_hit": "brulure", "role": "ranged",
		"skills": [
			{"name": "Éclair", "description": "Attaque magique à distance.", "effect": "Inflige des dégâts à distance.", "damage": 13, "range": 3},
			{"name": "Brûlure", "description": "Enflamme la cible à chaque coup.", "effect": "Applique Brûlure : 5 dégâts/tour pendant 2 tours.", "range": 3},
		],
	},
	"soigneur": {
		"name": "Soigneur", "color": Color(0.95, 0.95, 0.95), "symbol": "+",
		"description": "Soutien. Soigne ses alliés (et lui-même) mais frappe faiblement.",
		"max_hp": 24, "move_range": 3, "attack": 4, "attack_range": 1,
		"crit_chance": 0.0, "behavior": "heal", "heal": 12, "heal_range": 3, "role": "healer",
		"active": {"name": "Purification", "type": "purify", "target": "ally", "range": 3, "cooldown": 3, "can_self": true,
			"desc": "Retire tous les effets négatifs (poison, brûlure, gel) d'un allié ou de soi."},
		"skills": [
			{"name": "Soin", "description": "Restaure les PV d'un allié ou de soi-même.", "effect": "Rend 12 PV à la cible.", "range": 3},
			{"name": "Bâton", "description": "Faible attaque de mêlée.", "effect": "Inflige peu de dégâts au corps à corps.", "damage": 4, "range": 1},
			{"name": "Purification (compétence)", "description": "Nettoie les debuffs.", "effect": "Retire poison/brûlure/gel d'un allié ou de soi. Recharge : 3 tours."},
		],
	},
	"paladin": {
		"name": "Paladin", "color": Color(0.90, 0.80, 0.30), "symbol": "P",
		"description": "Tank polyvalent. Résistant et frappe correctement au corps à corps.",
		"max_hp": 38, "move_range": 3, "attack": 9, "attack_range": 1,
		"crit_chance": 0.05, "behavior": "melee", "role": "tank",
		"skills": [
			{"name": "Frappe sacrée", "description": "Attaque de mêlée.", "effect": "Inflige des dégâts au corps à corps.", "damage": 9, "range": 1},
			{"name": "Endurance", "description": "PV élevés (passif).", "effect": "Tient la ligne de front."},
		],
	},
	"berserker": {
		"name": "Berserker", "color": Color(0.95, 0.50, 0.20), "symbol": "B",
		"description": "Combattant agressif. Gros dégâts de mêlée et bonne mobilité.",
		"max_hp": 30, "move_range": 4, "attack": 12, "attack_range": 1,
		"crit_chance": 0.15, "behavior": "melee", "role": "melee",
		"skills": [
			{"name": "Entaille", "description": "Attaque de mêlée puissante.", "effect": "Inflige de gros dégâts au corps à corps.", "damage": 12, "range": 1},
			{"name": "Agressivité", "description": "Se déplace loin pour atteindre ses cibles.", "effect": "Grande portée de déplacement (passif)."},
		],
	},
	"mage_glace": {
		"name": "Mage de glace", "color": Color(0.55, 0.80, 1.00), "symbol": "G",
		"description": "Contrôle. Ralentit ses cibles à distance pour les empêcher de fuir ou d'approcher.",
		"max_hp": 21, "move_range": 3, "attack": 9, "attack_range": 3,
		"crit_chance": 0.10, "behavior": "kite", "on_hit": "gel", "role": "ranged",
		"active": {"name": "Nova de givre", "type": "frost_nova", "target": "enemy", "range": 3, "radius": 1, "cooldown": 4,
			"desc": "Gèle tous les ennemis autour d'une cible (jusqu'à 3 cases)."},
		"skills": [
			{"name": "Éclat de givre", "description": "Attaque de glace à distance.", "effect": "Inflige des dégâts à distance.", "damage": 9, "range": 3},
			{"name": "Gel", "description": "Chaque tir ralentit la cible.", "effect": "Applique Gel : -2 déplacement pendant 2 tours.", "range": 3},
			{"name": "Nova de givre (compétence)", "description": "Gel de zone.", "effect": "Ralentit tous les ennemis autour d'une cible. Recharge : 4 tours."},
		],
	},
	"lancier": {
		"name": "Lancier", "color": Color(0.60, 0.65, 0.70), "symbol": "L",
		"description": "Combattant d'allonge. Frappe à 2 cases : tient la ligne sans se coller à l'ennemi.",
		"max_hp": 32, "move_range": 3, "attack": 11, "attack_range": 2,
		"crit_chance": 0.10, "behavior": "melee", "role": "melee",
		"skills": [
			{"name": "Coup de lance", "description": "Attaque d'allonge.", "effect": "Frappe une cible jusqu'à 2 cases.", "damage": 11, "range": 2},
			{"name": "Allonge", "description": "Frappe sans contact direct (passif).", "effect": "Peut attaquer à 2 cases de distance."},
		],
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
	"gel":      {"name": "Gel",          "duration": 2, "move_penalty": 2},
}

# Sélections courantes (définies à l'écran de préparation, étape 6).
var difficulty := "normal"
var player_team: Array = ["tank"]
var ai_team: Array = ["archer"]

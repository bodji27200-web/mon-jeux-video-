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
		"description": "Tireur agile. Harcèle de loin, empoisonne et peut traverser une ligne d'ennemis.",
		"max_hp": 22, "move_range": 4, "attack": 10, "attack_range": 4,
		"crit_chance": 0.20, "behavior": "kite", "on_hit": "poison", "role": "ranged",
		"active": {"name": "Tir perforant", "type": "piercing_shot", "target": "line", "range": 4, "cooldown": 3,
			"desc": "Frappe TOUS les ennemis alignés dans une direction. Recharge : 3 tours."},
		"skills": [
			{"name": "Tir", "description": "Attaque à distance.", "effect": "Inflige des dégâts à distance.", "damage": 10, "range": 4},
			{"name": "Flèche empoisonnée", "description": "Chaque tir empoisonne la cible.", "effect": "Applique Poison : 3 dégâts/tour pendant 3 tours.", "range": 4},
			{"name": "Tir perforant (compétence)", "description": "Traverse la ligne.", "effect": "Touche tous les ennemis alignés jusqu'à 4 cases. Recharge : 3 tours."},
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
		"max_hp": 30, "move_range": 4, "attack": 10, "attack_range": 1,
		"crit_chance": 0.10, "behavior": "melee", "role": "melee",
		"skills": [
			{"name": "Entaille", "description": "Attaque de mêlée puissante.", "effect": "Inflige de gros dégâts au corps à corps.", "damage": 10, "range": 1},
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
		"max_hp": 32, "move_range": 3, "attack": 9, "attack_range": 2,
		"crit_chance": 0.10, "behavior": "melee", "role": "melee",
		"skills": [
			{"name": "Coup de lance", "description": "Attaque d'allonge.", "effect": "Frappe une cible jusqu'à 2 cases.", "damage": 9, "range": 2},
			{"name": "Allonge", "description": "Frappe sans contact direct (passif).", "effect": "Peut attaquer à 2 cases de distance."},
		],
	},
	"necromancien": {
		"name": "Nécromancien", "color": Color(0.50, 0.15, 0.65), "symbol": "N",
		"description": "Invocateur. Faible seul, redoutable avec ses squelettes (max 2 simultanés).",
		"max_hp": 18, "move_range": 3, "attack": 6, "attack_range": 3,
		"crit_chance": 0.05, "behavior": "kite", "role": "ranged",
		"active": {"name": "Invoquer mort-vivant", "type": "invoke",
			"summon_classes": ["squelette_guerrier", "squelette_archer"],
			"max_summons": 2, "range": 1, "cooldown": 3,
			"desc": "Invoque un mort-vivant adjacent (Guerrier puis Archer, max 2). Permanent. Recharge : 3 tours."},
		"skills": [
			{"name": "Rayon d'ombre", "description": "Attaque magique faible.", "effect": "Inflige des dégâts à distance.", "damage": 6, "range": 3},
			{"name": "Invoquer mort-vivant (compétence)", "description": "Invocation permanente à rôles distincts.", "effect": "Alterne Squelette guerrier (tient la ligne) et Squelette archer (harcèle à distance). Max 2 simultanés. Recharge : 3 tours."},
		],
	},
	"squelette_guerrier": {
		"name": "Squelette guerrier", "color": Color(0.78, 0.78, 0.72), "symbol": "x",
		"description": "Mort-vivant de mêlée. Faible mais tient la ligne de front du Nécromancien.",
		"max_hp": 10, "move_range": 3, "attack": 4, "attack_range": 1,
		"crit_chance": 0.05, "behavior": "melee", "role": "melee",
		"hidden": true,
		"skills": [],
	},
	"squelette_archer": {
		"name": "Squelette archer", "color": Color(0.70, 0.74, 0.62), "symbol": "y",
		"description": "Mort-vivant à distance. Très fragile, harcèle les cibles à 3 cases.",
		"max_hp": 7, "move_range": 3, "attack": 3, "attack_range": 3,
		"crit_chance": 0.05, "behavior": "kite", "role": "ranged",
		"hidden": true,
		"skills": [],
	},
	"druide": {
		"name": "Druide", "color": Color(0.25, 0.65, 0.25), "symbol": "D",
		"description": "Contrôle et soutien. Immobilise les ennemis et attaque à distance.",
		"max_hp": 25, "move_range": 3, "attack": 8, "attack_range": 2,
		"crit_chance": 0.08, "behavior": "kite", "role": "ranged",
		"active": {"name": "Racines", "type": "roots", "target": "enemy", "range": 3, "cooldown": 3,
			"desc": "Immobilise un ennemi : il ne peut pas se déplacer pendant 1 tour. Recharge : 3 tours."},
		"skills": [
			{"name": "Toucher de nature", "description": "Attaque à distance.", "effect": "Frappe jusqu'à 2 cases.", "damage": 8, "range": 2},
			{"name": "Racines (compétence)", "description": "Immobilisation.", "effect": "Empêche un ennemi de bouger pendant 1 tour. Synérgie : associer aux tireurs. Recharge : 3 tours."},
		],
	},
	"pretreguerrier": {
		"name": "Prêtre de guerre", "color": Color(0.92, 0.88, 0.50), "symbol": "W",
		"description": "Support offensif. Attaque à distance ET peut soigner ses alliés.",
		"max_hp": 28, "move_range": 3, "attack": 10, "attack_range": 3,
		"crit_chance": 0.08, "behavior": "kite", "role": "ranged",
		"active": {"name": "Soin de guerre", "type": "war_heal", "target": "ally", "range": 2,
			"heal_amount": 14, "cooldown": 3, "can_self": true,
			"desc": "Soigne un allié (ou soi-même) de 14 PV. Recharge : 3 tours."},
		"skills": [
			{"name": "Frappe divine", "description": "Attaque à distance.", "effect": "Inflige des dégâts à distance.", "damage": 10, "range": 3},
			{"name": "Soin de guerre (compétence)", "description": "Soin à distance.", "effect": "Restaure 14 PV à un allié à 2 cases (ou soi). Recharge : 3 tours."},
		],
	},
	"alchimiste": {
		"name": "Alchimiste", "color": Color(0.72, 0.55, 0.18), "symbol": "Q",
		"description": "Empoisonneur. Empile les DoTs : chaque attaque empoisonne, sa compétence ajoute la brûlure.",
		"max_hp": 20, "move_range": 3, "attack": 9, "attack_range": 3,
		"crit_chance": 0.08, "behavior": "kite", "on_hit": "poison", "role": "ranged",
		"active": {"name": "Cocktail acide", "type": "double_dot", "target": "enemy", "range": 3, "cooldown": 3,
			"desc": "Applique simultanément Poison ET Brûlure sur une cible. Recharge : 3 tours."},
		"skills": [
			{"name": "Fiole empoisonnée", "description": "Attaque toxique.", "effect": "Inflige des dégâts et applique Poison (3/tour, 3 tours).", "damage": 9, "range": 3},
			{"name": "Cocktail acide (compétence)", "description": "Double DoT.", "effect": "Applique Poison + Brûlure simultanément. Dégâts sur la durée massifs. Recharge : 3 tours."},
		],
	},
	"chevaliernoir": {
		"name": "Chevalier noir", "color": Color(0.22, 0.12, 0.38), "symbol": "K",
		"description": "Tank agressif. Se soigne en attaquant (drain 20%). Résistant, mais plus fragile seul qu'en equipe.",
		"max_hp": 30, "move_range": 3, "attack": 9, "attack_range": 1,
		"crit_chance": 0.10, "behavior": "melee", "drain_pct": 0.20, "role": "tank",
		"active": {"name": "Drain de vie", "type": "drain_strike", "target": "enemy", "range": 1, "cooldown": 4,
			"desc": "Attaque puissante + soin du Chevalier (60% des dégâts en PV récupérés). Recharge : 4 tours."},
		"skills": [
			{"name": "Épée maudite", "description": "Frappe drainante.", "effect": "Inflige des dégâts et récupère 20% en PV.", "damage": 9, "range": 1},
			{"name": "Drain de vie (compétence)", "description": "Drain massif.", "effect": "Frappe + soin pour 60% des dégâts. Recharge : 4 tours."},
		],
	},
	"chasseur": {
		"name": "Chasseur", "color": Color(0.50, 0.78, 0.32), "symbol": "C",
		"description": "Marqueur. Chaque tir marque la cible (+50% de dégâts du Chasseur sur les cibles marquées).",
		"max_hp": 22, "move_range": 4, "attack": 9, "attack_range": 3,
		"crit_chance": 0.15, "behavior": "kite", "on_hit": "marque",
		"mark_bonus_mult": 1.5, "role": "ranged",
		"active": {"name": "Tir ciblé", "type": "mark_shot", "target": "enemy", "range": 4, "cooldown": 3,
			"desc": "Marque une cible à longue portée (4 cases). Recharge : 3 tours."},
		"skills": [
			{"name": "Flèche traçante", "description": "Marque la cible.", "effect": "Inflige des dégâts et applique Marque (+50% de dégâts du Chasseur).", "damage": 9, "range": 3},
			{"name": "Tir ciblé (compétence)", "description": "Marque à longue portée.", "effect": "Applique Marque à 4 cases. Recharge : 3 tours."},
		],
	},
	"envouteur": {
		"name": "Envoûteur", "color": Color(0.78, 0.32, 0.72), "symbol": "V",
		"description": "Manipulateur. Affaiblit les ennemis (-30% dégâts) et renforce les alliés (+50% dégâts).",
		"max_hp": 20, "move_range": 3, "attack": 7, "attack_range": 3,
		"crit_chance": 0.08, "behavior": "kite", "on_hit": "affaiblissement", "role": "ranged",
		"active": {"name": "Renforcement", "type": "empower_ally", "target": "ally", "range": 3, "cooldown": 3,
			"desc": "Donne Force (+50% dégâts) à un allié pendant 2 tours. Recharge : 3 tours."},
		"skills": [
			{"name": "Malédiction", "description": "Attaque affaiblissante.", "effect": "Inflige des dégâts et réduit les dégâts de la cible de 30% (2 tours).", "damage": 7, "range": 3},
			{"name": "Renforcement (compétence)", "description": "Buff offensif.", "effect": "Donne Force à un allié (+50% dégâts, 2 tours). Recharge : 3 tours."},
		],
	},
	"invocateur": {
		"name": "Invocateur", "color": Color(0.30, 0.62, 0.72), "symbol": "I",
		"description": "Maître des créatures. Faible seul, invoque un Golem (tank) et un Loup spectral (rapide). Permanent.",
		"max_hp": 19, "move_range": 3, "attack": 6, "attack_range": 3,
		"crit_chance": 0.05, "behavior": "kite", "role": "ranged",
		"active": {"name": "Invoquer créature", "type": "invoke",
			"summon_classes": ["golem_pierre", "loup_spectral"],
			"max_summons": 2, "range": 1, "cooldown": 3,
			"desc": "Invoque une créature adjacente (Golem puis Loup, max 2). Permanent. Recharge : 3 tours."},
		"skills": [
			{"name": "Éclat élémentaire", "description": "Attaque magique faible.", "effect": "Inflige des dégâts à distance.", "damage": 6, "range": 3},
			{"name": "Invoquer créature (compétence)", "description": "Invocation permanente à rôles distincts.", "effect": "Alterne Golem de pierre (mur résistant) et Loup spectral (rapide, fonce sur les fragiles). Max 2. Recharge : 3 tours."},
		],
	},
	"golem_pierre": {
		"name": "Golem de pierre", "color": Color(0.45, 0.42, 0.40), "symbol": "g",
		"description": "Créature de l'Invocateur. Lente mais résistante, bloque le passage.",
		"max_hp": 18, "move_range": 2, "attack": 4, "attack_range": 1,
		"crit_chance": 0.0, "behavior": "melee", "role": "tank",
		"hidden": true,
		"skills": [],
	},
	"loup_spectral": {
		"name": "Loup spectral", "color": Color(0.40, 0.55, 0.62), "symbol": "w",
		"description": "Créature de l'Invocateur. Très rapide, fond sur les cibles fragiles.",
		"max_hp": 9, "move_range": 4, "attack": 6, "attack_range": 1,
		"crit_chance": 0.10, "behavior": "melee", "role": "melee",
		"hidden": true,
		"skills": [],
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
	"gel":           {"name": "Gel",             "duration": 2, "move_penalty": 2},
	"racines":       {"name": "Racines",         "duration": 2, "immobilized": true},
	"marque":        {"name": "Marque",          "duration": 2, "marked": true},
	"affaiblissement": {"name": "Affaiblissement", "duration": 2, "dmg_dealt_mult": 0.70},
}

# Terrain tactique (data-driven). Chaque type modifie dégâts ou déplacement.
const TERRAIN := {
	"foret":    {"name": "Forêt",    "color": Color(0.05, 0.30, 0.05, 0.52), "symbol": "F",
	             "ranged_dmg_mult": 0.65},
	"ruines":   {"name": "Ruines",   "color": Color(0.40, 0.38, 0.28, 0.48), "symbol": "R",
	             "dmg_taken_mult": 0.80},
	"marecage": {"name": "Marécage", "color": Color(0.18, 0.32, 0.12, 0.52), "symbol": "M",
	             "move_penalty": 2},
}

# Sélections courantes (définies à l'écran de préparation, étape 6).
var difficulty := "normal"
var player_team: Array = ["tank"]
var ai_team: Array = ["archer"]

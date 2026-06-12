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
		"actives": [
			{"name": "Protection", "type": "shield_ally", "target": "ally", "range": 2, "cooldown": 3,
				"desc": "Bouclier (dégâts subis -50%) sur un allié à 2 cases, 2 tours. Recharge : 3 tours."},
			{"name": "Garde", "type": "self_buff", "target": "self", "buff": "garde", "cooldown": 3,
				"desc": "Se met en garde : dégâts subis -60% pendant 2 tours. Recharge : 3 tours."},
			{"name": "Brise-armure", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 1, "cooldown": 3,
				"desc": "Frappe et expose la cible : elle subit +35% de dégâts (2 tours). Recharge : 3 tours."},
		],
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
		"actives": [
			{"name": "Tir perforant", "type": "piercing_shot", "target": "line", "range": 4, "cooldown": 3,
				"desc": "Frappe TOUS les ennemis alignés dans une direction. Recharge : 3 tours."},
			{"name": "Tir visé", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.7, "range": 4, "cooldown": 3,
				"desc": "Tir surpuissant (×1.7) sur une cible. Idéal pour achever. Recharge : 3 tours."},
			{"name": "Flèche entravante", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 4, "cooldown": 3,
				"desc": "Cloue une cible sur place (immobilisée 1 tour). Kite parfait. Recharge : 3 tours."},
		],
		"skills": [
			{"name": "Tir", "description": "Attaque à distance.", "effect": "Inflige des dégâts à distance.", "damage": 10, "range": 4},
			{"name": "Flèche empoisonnée", "description": "Chaque tir empoisonne la cible.", "effect": "Applique Poison : 3 dégâts/tour pendant 3 tours.", "range": 4},
			{"name": "Tir perforant (compétence)", "description": "Traverse la ligne.", "effect": "Touche tous les ennemis alignés jusqu'à 4 cases. Recharge : 3 tours."},
		],
	},
	"assassin": {
		"name": "Assassin", "color": Color(0.60, 0.30, 0.80), "symbol": "S",
		"description": "Tueur mobile (UNIQUE). Mobilité extrême et coups critiques dévastateurs : un seul unique par équipe.",
		"max_hp": 26, "move_range": 5, "attack": 17, "attack_range": 1,
		"crit_chance": 0.45, "behavior": "melee", "role": "melee", "unique": true,
		"actives": [
			{"name": "Frappe de l'ombre", "type": "teleport_strike", "target": "enemy", "range": 5, "cooldown": 3,
				"desc": "Se téléporte au contact d'un ennemi (jusqu'à 5 cases) et le frappe. Recharge : 3 tours."},
			{"name": "Exécution", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 1, "cooldown": 3,
				"desc": "Coup fatal (×1.8) au corps à corps. Achève les cibles affaiblies. Recharge : 3 tours."},
			{"name": "Affûtage", "type": "self_buff", "target": "self", "buff": "force", "cooldown": 4,
				"desc": "Aiguise ses lames : +50% de dégâts pendant 2 tours. Recharge : 4 tours."},
		],
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
		"actives": [
			{"name": "Déflagration", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 3, "cooldown": 3,
				"desc": "Explosion : touche la cible ET tous les ennemis adjacents. Recharge : 3 tours."},
			{"name": "Boule de feu", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.7, "range": 3, "cooldown": 3,
				"desc": "Sort surpuissant (×1.7) sur une cible. Recharge : 3 tours."},
			{"name": "Fragilisation", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 3, "cooldown": 3,
				"desc": "Frappe et fragilise : la cible subit +35% de dégâts (2 tours). Recharge : 3 tours."},
		],
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
		"actives": [
			{"name": "Purification", "type": "purify", "target": "ally", "range": 3, "cooldown": 3, "can_self": true,
				"desc": "Retire tous les effets négatifs (poison, brûlure, gel, racines...) d'un allié ou de soi. Recharge : 3 tours."},
			{"name": "Bénédiction", "type": "buff_ally", "target": "ally", "buff": "regen", "range": 3, "cooldown": 3, "can_self": true,
				"desc": "Régénération : soigne un allié 5 PV/tour pendant 3 tours. Recharge : 3 tours."},
			{"name": "Protection sacrée", "type": "buff_ally", "target": "ally", "buff": "bouclier", "range": 3, "cooldown": 3, "can_self": true,
				"desc": "Bouclier (dégâts subis -50%, 2 tours) sur un allié. Recharge : 3 tours."},
		],
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
		"actives": [
			{"name": "Bouclier de foi", "type": "buff_ally", "target": "ally", "buff": "bouclier", "range": 2, "cooldown": 3,
				"desc": "Bouclier (dégâts subis -50%, 2 tours) sur un allié à 2 cases. Recharge : 3 tours."},
			{"name": "Garde sacrée", "type": "self_buff", "target": "self", "buff": "garde", "cooldown": 3,
				"desc": "Se met en garde : dégâts subis -60% pendant 2 tours. Recharge : 3 tours."},
			{"name": "Châtiment", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.6, "range": 1, "cooldown": 3,
				"desc": "Frappe sacrée surpuissante (×1.6) au corps à corps. Recharge : 3 tours."},
		],
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
		"actives": [
			{"name": "Tourbillon", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 1, "cooldown": 3,
				"desc": "Fauche la cible et tous les ennemis adjacents. Recharge : 3 tours."},
			{"name": "Décapitation", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 1, "cooldown": 3,
				"desc": "Coup dévastateur (×1.8). Achève les cibles entamées. Recharge : 3 tours."},
			{"name": "Rage sanguinaire", "type": "self_buff", "target": "self", "buff": "rage", "cooldown": 4,
				"desc": "Entre en rage : +50% de dégâts MAIS +25% de dégâts subis (2 tours). Recharge : 4 tours."},
		],
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
		"actives": [
			{"name": "Nova de givre", "type": "frost_nova", "target": "enemy", "range": 3, "radius": 1, "cooldown": 4,
				"desc": "Gèle tous les ennemis autour d'une cible (jusqu'à 3 cases). Recharge : 4 tours."},
			{"name": "Emprise de glace", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 3, "cooldown": 3,
				"desc": "Emprisonne une cible dans la glace : immobilisée 1 tour. Recharge : 3 tours."},
			{"name": "Givre fragilisant", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 3, "cooldown": 3,
				"desc": "Le froid fragilise la cible : +35% de dégâts subis (2 tours). Recharge : 3 tours."},
		],
		"skills": [
			{"name": "Éclat de givre", "description": "Attaque de glace à distance.", "effect": "Inflige des dégâts à distance.", "damage": 9, "range": 3},
			{"name": "Gel", "description": "Chaque tir ralentit la cible.", "effect": "Applique Gel : -2 déplacement pendant 2 tours.", "range": 3},
			{"name": "Nova de givre (compétence)", "description": "Gel de zone.", "effect": "Ralentit tous les ennemis autour d'une cible. Recharge : 4 tours."},
		],
	},
	"lancier": {
		"name": "Lancier", "color": Color(0.60, 0.65, 0.70), "symbol": "L",
		"description": "Combattant d'allonge. Frappe à 2 cases : tient la ligne sans se coller à l'ennemi.",
		"max_hp": 32, "move_range": 3, "attack": 8, "attack_range": 2,
		"crit_chance": 0.10, "behavior": "melee", "role": "melee",
		"actives": [
			{"name": "Percée", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.5, "range": 2, "cooldown": 3,
				"desc": "Coup d'estoc surpuissant (×1.5) jusqu'à 2 cases. Recharge : 3 tours."},
			{"name": "Coup au genou", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 2, "cooldown": 4,
				"desc": "Entaille les jambes : la cible est immobilisée 1 tour. Recharge : 3 tours."},
			{"name": "Position défensive", "type": "self_buff", "target": "self", "buff": "garde", "cooldown": 4,
				"desc": "Plante sa lance : dégâts subis -60% pendant 2 tours. Recharge : 4 tours."},
		],
		"skills": [
			{"name": "Coup de lance", "description": "Attaque d'allonge.", "effect": "Frappe une cible jusqu'à 2 cases.", "damage": 9, "range": 2},
			{"name": "Allonge", "description": "Frappe sans contact direct (passif).", "effect": "Peut attaquer à 2 cases de distance."},
		],
	},
	"necromancien": {
		"name": "Nécromancien", "color": Color(0.50, 0.15, 0.65), "symbol": "N",
		"description": "Invocateur (UNIQUE). Faible seul, redoutable avec ses squelettes (max 2 simultanés) : un seul unique par équipe.",
		"max_hp": 20, "move_range": 3, "attack": 6, "attack_range": 3,
		"crit_chance": 0.05, "behavior": "kite", "role": "ranged", "unique": true,
		"actives": [
			{"name": "Invoquer mort-vivant", "type": "invoke",
				"summon_classes": ["squelette_guerrier", "squelette_archer"],
				"max_summons": 2, "range": 1, "cooldown": 3,
				"desc": "Invoque un mort-vivant adjacent (Guerrier puis Archer, max 2). Permanent. Recharge : 3 tours."},
			{"name": "Frénésie morbide", "type": "buff_ally", "target": "ally", "buff": "force", "range": 3, "cooldown": 3, "can_self": true,
				"desc": "Galvanise un mort-vivant (ou un allié) : +50% de dégâts, 2 tours. Recharge : 3 tours."},
			{"name": "Malédiction", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 3, "cooldown": 3,
				"desc": "Maudit une cible : +35% de dégâts subis (2 tours). À combiner avec les squelettes. Recharge : 3 tours."},
		],
		"skills": [
			{"name": "Rayon d'ombre", "description": "Attaque magique faible.", "effect": "Inflige des dégâts à distance.", "damage": 6, "range": 3},
			{"name": "Invoquer mort-vivant (compétence)", "description": "Invocation permanente à rôles distincts.", "effect": "Alterne Squelette guerrier (tient la ligne) et Squelette archer (harcèle à distance). Max 2 simultanés. Recharge : 3 tours."},
		],
	},
	"squelette_guerrier": {
		"name": "Squelette guerrier", "color": Color(0.78, 0.78, 0.72), "symbol": "x",
		"description": "Mort-vivant de mêlée. Faible mais tient la ligne de front du Nécromancien.",
		"max_hp": 18, "move_range": 3, "attack": 7, "attack_range": 1,
		"crit_chance": 0.05, "behavior": "melee", "role": "melee",
		"hidden": true,
		"skills": [],
	},
	"squelette_archer": {
		"name": "Squelette archer", "color": Color(0.70, 0.74, 0.62), "symbol": "y",
		"description": "Mort-vivant à distance. Très fragile, harcèle les cibles à 3 cases.",
		"max_hp": 13, "move_range": 3, "attack": 6, "attack_range": 3,
		"crit_chance": 0.05, "behavior": "kite", "role": "ranged",
		"hidden": true,
		"skills": [],
	},
	"druide": {
		"name": "Druide", "color": Color(0.25, 0.65, 0.25), "symbol": "D",
		"description": "Contrôle et soutien. Immobilise les ennemis et attaque à distance.",
		"max_hp": 25, "move_range": 3, "attack": 8, "attack_range": 2,
		"crit_chance": 0.08, "behavior": "kite", "role": "ranged",
		"actives": [
			{"name": "Racines", "type": "roots", "target": "enemy", "range": 3, "cooldown": 3,
				"desc": "Contrôle : immobilise un ennemi 1 tour. Synergie avec les tireurs. Recharge : 3 tours."},
			{"name": "Soin de la nature", "type": "buff_ally", "target": "ally", "buff": "regen", "range": 3, "cooldown": 3, "can_self": true,
				"desc": "Soutien : régénère un allié de 5 PV/tour pendant 3 tours. Recharge : 3 tours."},
			{"name": "Ronces vénéneuses", "type": "apply_debuff", "target": "enemy", "buff": "poison", "range": 2, "cooldown": 3,
				"desc": "Nature : empoisonne une cible (3 dégâts/tour, 3 tours). Recharge : 3 tours."},
		],
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
		"actives": [
			{"name": "Soin de guerre", "type": "war_heal", "target": "ally", "range": 2,
				"heal_amount": 14, "cooldown": 3, "can_self": true,
				"desc": "Soigne un allié (ou soi-même) de 14 PV. Recharge : 3 tours."},
			{"name": "Hymne de guerre", "type": "buff_ally", "target": "ally", "buff": "force", "range": 3, "cooldown": 3, "can_self": true,
				"desc": "Galvanise un allié : +50% de dégâts pendant 2 tours. Recharge : 3 tours."},
			{"name": "Jugement", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 3, "cooldown": 3,
				"desc": "Frappe et condamne une cible : +35% de dégâts subis (2 tours). Recharge : 3 tours."},
		],
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
		"actives": [
			{"name": "Cocktail acide", "type": "double_dot", "target": "enemy", "range": 3, "cooldown": 3,
				"desc": "Applique simultanément Poison ET Brûlure sur une cible. Recharge : 3 tours."},
			{"name": "Solvant corrosif", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 3, "cooldown": 3,
				"desc": "Ronge les défenses : +35% de dégâts subis (2 tours). Amplifie les DoT. Recharge : 3 tours."},
			{"name": "Glu visqueuse", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 3, "cooldown": 4,
				"desc": "Immobilise une cible 1 tour : elle reste dans le nuage toxique. Recharge : 4 tours."},
		],
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
		"actives": [
			{"name": "Drain de vie", "type": "drain_strike", "target": "enemy", "range": 1, "cooldown": 4,
				"desc": "Frappe + soin (60% de l'attaque en PV récupérés). Recharge : 4 tours."},
			{"name": "Fendoir maudit", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.6, "range": 1, "cooldown": 3,
				"desc": "Coup lourd (×1.6) au corps à corps. Recharge : 3 tours."},
			{"name": "Soif de sang", "type": "self_buff", "target": "self", "buff": "rage", "cooldown": 4,
				"desc": "Se déchaîne : +50% de dégâts mais +25% de dégâts subis (2 tours). Recharge : 4 tours."},
		],
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
		"actives": [
			{"name": "Tir de précision", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 4, "cooldown": 3,
				"desc": "Tir surpuissant (×1.8). Dévastateur sur une cible marquée. Recharge : 3 tours."},
			{"name": "Piège à mâchoires", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 3, "cooldown": 3,
				"desc": "Immobilise une cible 1 tour : punit ceux qui s'approchent. Recharge : 3 tours."},
			{"name": "Tir ciblé", "type": "mark_shot", "target": "enemy", "range": 4, "cooldown": 3,
				"desc": "Marque une cible à longue portée (4 cases) : +50% de dégâts du Chasseur. Recharge : 3 tours."},
		],
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
		"actives": [
			{"name": "Renforcement", "type": "empower_ally", "target": "ally", "range": 3, "cooldown": 3,
				"desc": "Donne Force (+50% dégâts) à un allié pendant 2 tours. Recharge : 3 tours."},
			{"name": "Hex de fragilité", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 3, "cooldown": 3,
				"desc": "Maudit une cible : +35% de dégâts subis (2 tours). Recharge : 3 tours."},
			{"name": "Protection occulte", "type": "buff_ally", "target": "ally", "buff": "bouclier", "range": 3, "cooldown": 3, "can_self": true,
				"desc": "Bouclier (dégâts subis -50%, 2 tours) sur un allié ou soi. Recharge : 3 tours."},
		],
		"skills": [
			{"name": "Malédiction", "description": "Attaque affaiblissante.", "effect": "Inflige des dégâts et réduit les dégâts de la cible de 30% (2 tours).", "damage": 7, "range": 3},
			{"name": "Renforcement (compétence)", "description": "Buff offensif.", "effect": "Donne Force à un allié (+50% dégâts, 2 tours). Recharge : 3 tours."},
		],
	},
	"invocateur": {
		"name": "Invocateur", "color": Color(0.30, 0.62, 0.72), "symbol": "I",
		"description": "Maître des créatures (UNIQUE). Invoque un Golem (tank) et un Loup spectral (rapide), permanents : un seul unique par équipe.",
		"max_hp": 21, "move_range": 3, "attack": 6, "attack_range": 3,
		"crit_chance": 0.05, "behavior": "kite", "role": "ranged", "unique": true,
		"actives": [
			{"name": "Invoquer créature", "type": "invoke",
				"summon_classes": ["golem_pierre", "loup_spectral"],
				"max_summons": 2, "range": 1, "cooldown": 3,
				"desc": "Invoque une créature adjacente (Golem puis Loup, max 2). Permanent. Recharge : 3 tours."},
			{"name": "Carapace de pierre", "type": "buff_ally", "target": "ally", "buff": "bouclier", "range": 3, "cooldown": 3, "can_self": true,
				"desc": "Renforce une créature (ou un allié) : dégâts subis -50%, 2 tours. Recharge : 3 tours."},
			{"name": "Toile élémentaire", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 3, "cooldown": 4,
				"desc": "Immobilise une proie 1 tour pour que les créatures la rattrapent. Recharge : 4 tours."},
		],
		"skills": [
			{"name": "Éclat élémentaire", "description": "Attaque magique faible.", "effect": "Inflige des dégâts à distance.", "damage": 6, "range": 3},
			{"name": "Invoquer créature (compétence)", "description": "Invocation permanente à rôles distincts.", "effect": "Alterne Golem de pierre (mur résistant) et Loup spectral (rapide, fonce sur les fragiles). Max 2. Recharge : 3 tours."},
		],
	},
	"golem_pierre": {
		"name": "Golem de pierre", "color": Color(0.45, 0.42, 0.40), "symbol": "g",
		"description": "Créature de l'Invocateur. Lente mais résistante, bloque le passage.",
		"max_hp": 28, "move_range": 2, "attack": 5, "attack_range": 1,
		"crit_chance": 0.0, "behavior": "melee", "role": "tank",
		"hidden": true,
		"skills": [],
	},
	"loup_spectral": {
		"name": "Loup spectral", "color": Color(0.40, 0.55, 0.62), "symbol": "w",
		"description": "Créature de l'Invocateur. Très rapide, fond sur les cibles fragiles.",
		"max_hp": 12, "move_range": 4, "attack": 9, "attack_range": 1,
		"crit_chance": 0.10, "behavior": "melee", "role": "melee",
		"hidden": true,
		"skills": [],
	},
	"archere": {
		"name": "Archère", "color": Color(0.15, 0.72, 0.58), "symbol": "Å",
		"description": "Tireuse d'élite (UNIQUE). Reine de la distance : frappe très fort de loin et se repositionne hors de portée. Un seul unique par équipe.",
		"max_hp": 24, "move_range": 4, "attack": 11, "attack_range": 5,
		"crit_chance": 0.35, "behavior": "kite", "role": "ranged", "unique": true,
		"actives": [
			{"name": "Tir fatal", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.9, "range": 5, "cooldown": 3,
				"desc": "Tir d'élite surpuissant (×1.9) à très longue portée. Recharge : 3 tours."},
			{"name": "Pluie de flèches", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 5, "cooldown": 3,
				"desc": "Salve qui s'abat sur une zone : touche la cible et tous les ennemis adjacents. Recharge : 3 tours."},
			{"name": "Tir en retraite", "type": "retreat_shot", "target": "enemy", "range": 5, "retreat": 2, "cooldown": 3,
				"desc": "Tire puis bondit de 2 cases en arrière : injouable au corps à corps. Recharge : 3 tours."},
		],
		"skills": [],
	},
	"barde": {
		"name": "Barde", "color": Color(0.95, 0.75, 0.30), "symbol": "♪",
		"description": "Soutien d'équipe (UNIQUE). Ses chants affectent TOUTE l'équipe (ou tous les ennemis) à la fois. Un seul unique par équipe.",
		"max_hp": 24, "move_range": 3, "attack": 6, "attack_range": 3,
		"crit_chance": 0.05, "behavior": "kite", "role": "healer", "unique": true,
		"actives": [
			{"name": "Chant de bravoure", "type": "team_buff", "target": "self", "buff": "force", "cooldown": 4,
				"desc": "Galvanise TOUTE ton équipe : +50% de dégâts pendant 2 tours. Recharge : 4 tours."},
			{"name": "Chant de garde", "type": "team_buff", "target": "self", "buff": "bouclier", "cooldown": 4,
				"desc": "Protège TOUTE ton équipe : dégâts subis -50% pendant 2 tours. Recharge : 4 tours."},
			{"name": "Note discordante", "type": "team_debuff", "target": "self", "buff": "affaiblissement", "cooldown": 4,
				"desc": "Affaiblit TOUS les ennemis : -30% de dégâts pendant 2 tours. Recharge : 4 tours."},
		],
		"skills": [],
	},
	"duelliste": {
		"name": "Duelliste", "color": Color(0.85, 0.18, 0.32), "symbol": "Đ",
		"description": "Bretteur (UNIQUE). Contre automatiquement quiconque le frappe au corps à corps, et peut parer. Un seul unique par équipe.",
		"max_hp": 32, "move_range": 4, "attack": 10, "attack_range": 1,
		"crit_chance": 0.15, "behavior": "melee", "role": "melee", "unique": true,
		"actives": [
			{"name": "Posture de riposte", "type": "self_buff", "target": "self", "buff": "riposte", "cooldown": 3,
				"desc": "Pendant 2 tours, contre-attaque automatiquement tout ennemi qui le frappe au corps à corps. Recharge : 3 tours."},
			{"name": "Parade", "type": "self_buff", "target": "self", "buff": "parade", "cooldown": 3,
				"desc": "Pare totalement la prochaine attaque reçue. Recharge : 3 tours."},
			{"name": "Estocade", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 1, "cooldown": 3,
				"desc": "Botte secrète : coup d'estoc dévastateur (×1.8) au corps à corps. Recharge : 3 tours."},
		],
		"skills": [],
	},
	# --- Ennemis de CAMPAGNE (hidden : jamais dans le draft ni la Partie rapide).
	# Pas des « classes » : de vraies créatures, dessinées 100 % à la main par code
	# (Unit._draw_figure_*, champ "figure"). "boss": true = présenté seul, en grand.
	"loup_murmures": {
		"name": "Loup des Murmures", "color": Color(0.40, 0.44, 0.52), "symbol": "w",
		"description": "Prédateur du bois. Rapide, frappe au contact et chasse les isolés.",
		"max_hp": 20, "move_range": 5, "attack": 8, "attack_range": 1,
		"crit_chance": 0.15, "behavior": "melee", "role": "melee",
		"hidden": true, "figure": "loup",
		"skills": [],
	},
	"rodeur_sombre": {
		"name": "Rôdeur masqué", "color": Color(0.46, 0.38, 0.28), "symbol": "r",
		"description": "Brigand au masque d'os. Harcèle à distance, flèches empoisonnées.",
		"max_hp": 18, "move_range": 4, "attack": 9, "attack_range": 3,
		"crit_chance": 0.15, "behavior": "kite", "on_hit": "poison", "role": "ranged",
		"hidden": true, "figure": "rodeur",
		"skills": [],
	},
	# Compagnons de CAMPAGNE (hidden : classes propres au mode histoire,
	# dessinées via leur figure d'exploration — le JcJ est un mode à part).
	"sera_pisteuse": {
		"name": "Sera la pisteuse", "color": Color(0.30, 0.42, 0.62), "symbol": "s",
		"description": "Déserteuse des rôdeurs. Frappe de loin et connaît leurs faiblesses.",
		"max_hp": 24, "move_range": 4, "attack": 9, "attack_range": 4,
		"crit_chance": 0.20, "behavior": "kite", "role": "ranged",
		"hidden": true, "figure_npc": "etrangere",
		"skills": [],
	},
	"garin_bucheron": {
		"name": "Garin le bûcheron", "color": Color(0.55, 0.38, 0.22), "symbol": "g",
		"description": "Bûcheron à l'allonge de lancier. Solide, tient la ligne de front.",
		"max_hp": 34, "move_range": 3, "attack": 9, "attack_range": 2,
		"crit_chance": 0.10, "behavior": "melee", "role": "tank",
		"hidden": true, "figure_npc": "bucheron",
		"skills": [],
	},
	"traqueur_ombres": {
		"name": "Traqueur des ombres", "color": Color(0.35, 0.20, 0.45), "symbol": "t",
		"description": "Tueur furtif du bois. Fragile mais létal : il fond sur les isolés.",
		"max_hp": 18, "move_range": 5, "attack": 13, "attack_range": 1,
		"crit_chance": 0.30, "behavior": "melee", "role": "melee",
		"hidden": true, "figure": "traqueur",
		"skills": [],
	},
	"totem_ronces": {
		"name": "Totem de ronces", "color": Color(0.30, 0.45, 0.22), "symbol": "o",
		"description": "Pierre dressée animée par le bois. Immobile, il cloue les intrus sur place.",
		"max_hp": 35, "move_range": 0, "attack": 7, "attack_range": 3,
		"crit_chance": 0.0, "behavior": "kite", "role": "ranged",
		"hidden": true, "figure": "totem",
		"actives": [
			{"name": "Racines", "type": "roots", "target": "enemy", "range": 3, "cooldown": 2,
				"desc": "Immobilise un intrus 1 tour."},
		],
		"skills": [],
	},
	# --- CLASSES DE CAMPAGNE DU HÉROS (création de personnage) ---
	# Propres au mode histoire (hidden = jamais dans le JcJ). Aucune compétence
	# de départ : tout se construit via l'ARBRE DE CLASSE (CLASS_TREES).
	"lame_errante": {
		"name": "Lame errante", "color": Color(0.78, 0.30, 0.26), "symbol": "L",
		"description": "Bretteur vagabond. Équilibré, à l'aise partout : la lame répond à tout.",
		"max_hp": 30, "move_range": 4, "attack": 10, "attack_range": 1,
		"crit_chance": 0.15, "behavior": "melee", "role": "melee",
		"hidden": true, "skills": [],
	},
	"rempart": {
		"name": "Rempart", "color": Color(0.32, 0.50, 0.85), "symbol": "R",
		"description": "Bouclier vivant. Encaisse pour les autres et tient la ligne, quoi qu'il arrive.",
		"max_hp": 42, "move_range": 3, "attack": 7, "attack_range": 1,
		"crit_chance": 0.05, "behavior": "melee", "role": "tank",
		"hidden": true, "skills": [],
	},
	"oeil_lynx": {
		"name": "Œil-de-lynx", "color": Color(0.30, 0.72, 0.42), "symbol": "Œ",
		"description": "Tireur d'élite des chemins. Voit loin, frappe juste, ne se laisse pas approcher.",
		"max_hp": 22, "move_range": 4, "attack": 10, "attack_range": 4,
		"crit_chance": 0.20, "behavior": "kite", "role": "ranged",
		"hidden": true, "skills": [],
	},
	"mire_errant": {
		"name": "Mire errant", "color": Color(0.92, 0.90, 0.80), "symbol": "M",
		"description": "Guérisseur des routes. Recoud, protège, et garde tout le monde debout.",
		"max_hp": 24, "move_range": 3, "attack": 5, "attack_range": 1,
		"crit_chance": 0.0, "behavior": "heal", "heal": 12, "heal_range": 3,
		"role": "healer", "hidden": true, "skills": [],
	},
	"flamme_egaree": {
		"name": "Flamme égarée", "color": Color(0.95, 0.45, 0.15), "symbol": "F",
		"description": "Mage au feu instable. Brûle tout ce qu'il touche — y compris ses ennuis.",
		"max_hp": 20, "move_range": 3, "attack": 12, "attack_range": 3,
		"crit_chance": 0.10, "behavior": "kite", "on_hit": "brulure", "role": "ranged",
		"hidden": true, "skills": [],
	},
	"ombre_passante": {
		"name": "Ombre passante", "color": Color(0.55, 0.32, 0.72), "symbol": "O",
		"description": "Tueur discret. Fragile mais foudroyant : frappe le premier, frappe le dernier.",
		"max_hp": 24, "move_range": 5, "attack": 13, "attack_range": 1,
		"crit_chance": 0.30, "behavior": "melee", "role": "melee",
		"hidden": true, "skills": [],
	},
	"duelliste_campagne": {
		"name": "Duelliste", "color": Color(0.68, 0.36, 0.92), "symbol": "D",
		"description": "Bretteuse de salle d'armes jetée sur les routes. Riposte, parade, sentence — et le Katana d'améthyste n'attend qu'elle.",
		"max_hp": 27, "move_range": 4, "attack": 11, "attack_range": 1,
		"crit_chance": 0.25, "behavior": "melee", "role": "melee", "agility": 6,
		"hidden": true, "skills": [],
	},
	# Luna : compagnonne archère rencontrée à la taverne (émotions à règles).
	"luna_archere": {
		"name": "Luna", "color": Color(0.88, 0.74, 0.35), "symbol": "✦",
		"description": "Archère blonde au rire facile et à l'œil dur. Cherche son frère, parti dans le bois.",
		"max_hp": 23, "move_range": 4, "attack": 10, "attack_range": 4,
		"crit_chance": 0.25, "behavior": "kite", "role": "ranged",
		"hidden": true, "figure_npc": "luna", "skills": [],
	},
	"joran_mire": {
		"name": "Joran le mire", "color": Color(0.72, 0.68, 0.50), "symbol": "j",
		"description": "Médecin de guerre déserteur. Recoud l'équipe sous les flèches.",
		"max_hp": 26, "move_range": 3, "attack": 5, "attack_range": 1,
		"crit_chance": 0.0, "behavior": "heal", "heal": 11, "heal_range": 3,
		"role": "healer", "hidden": true, "figure_npc": "mire",
		"skills": [],
	},
	# BOSS SECRET de la zone 1 : le chasseur de déserteurs qui traque Sera.
	# L'OPPOSÉ du Veilleur : tireur mobile qui marque ses proies puis les exécute.
	"traqueur_roi": {
		"name": "Le Traqueur-Roi", "color": Color(0.62, 0.18, 0.34), "symbol": "R",
		"description": "BOSS SECRET. Le maître des rôdeurs. Il ne pardonne pas la désertion.",
		"max_hp": 90, "move_range": 4, "attack": 11, "attack_range": 3,
		"crit_chance": 0.20, "behavior": "kite", "role": "ranged", "agility": 6,
		"hidden": true, "figure": "roi", "boss": true,
		"on_hit": "marque", "mark_bonus_mult": 1.6,
		"phases": [
			{"at": 0.6, "announce": "« Mes limiers ! À la curée ! »",
			 "summon": ["rodeur_sombre", "rodeur_sombre"]},
			{"at": 0.3, "announce": "« LA CHASSE EST OUVERTE ! »",
			 "buff": "force", "attack_mult": 1.25},
		],
		"actives": [
			{"name": "Mise à mort", "type": "heavy_strike", "target": "enemy",
				"dmg_mult": 1.6, "range": 3, "cooldown": 3,
				"desc": "Exécute une proie (×1.6) — dévastateur sur une cible marquée."},
			{"name": "Pas du chasseur", "type": "teleport_strike", "target": "enemy",
				"range": 5, "cooldown": 3,
				"desc": "Surgit au contact d'une proie lointaine et frappe."},
			{"name": "Volte", "type": "retreat_shot", "target": "enemy",
				"range": 3, "retreat": 2, "cooldown": 3,
				"desc": "Tire puis se dérobe de 2 cases."},
		],
		"skills": [],
	},
	"sera_traquee": {
		"name": "Sera, la traquée", "color": Color(0.30, 0.42, 0.62), "symbol": "S",
		"description": "Dénoncée, chassée du hameau, elle a rejoint le bois. Elle n'a pas oublié.",
		"max_hp": 26, "move_range": 4, "attack": 10, "attack_range": 4,
		"crit_chance": 0.25, "behavior": "kite", "role": "ranged",
		"hidden": true, "figure_npc": "etrangere",
		"skills": [],
	},
	"veilleur_murmures": {
		"name": "Le Veilleur des Murmures", "color": Color(0.45, 0.28, 0.66), "symbol": "Ω",
		"description": "BOSS. L'esprit cornu qui règne sur le Bois des Murmures. Il combat seul — et ça suffit.",
		"max_hp": 115, "move_range": 4, "attack": 15, "attack_range": 1, "agility": 2,
		"crit_chance": 0.15, "behavior": "melee", "role": "melee",
		"hidden": true, "figure": "veilleur", "boss": true,
		# Boss à MÉCANIQUES : phases déclenchées par ses PV (Battle._process).
		"phases": [
			{"at": 0.55, "announce": "Le bois répond à son maître !",
			 "summon": ["loup_murmures", "loup_murmures"]},
			{"at": 0.25, "announce": "FURIE DU VEILLEUR !",
			 "buff": "rage", "attack_mult": 1.3},
		],
		"actives": [
			{"name": "Étreinte des ronces", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 1, "cooldown": 3,
				"desc": "Fauche la cible et tous ses voisins de ronces acérées. Recharge : 3 tours."},
			{"name": "Bond d'ombre", "type": "teleport_strike", "target": "enemy", "range": 4, "cooldown": 3,
				"desc": "Fond sur une proie jusqu'à 4 cases et la frappe. Recharge : 3 tours."},
			{"name": "Furie du bois", "type": "self_buff", "target": "self", "buff": "rage", "cooldown": 4,
				"desc": "Le bois s'éveille : +50% de dégâts mais +25% subis (2 tours). Recharge : 4 tours."},
		],
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
	"rage":          {"name": "Rage",            "duration": 2, "dmg_dealt_mult": 1.5, "dmg_taken_mult": 1.25},
	"garde":         {"name": "Garde",           "duration": 2, "dmg_taken_mult": 0.4},
	"vulnerabilite": {"name": "Vulnérabilité",   "duration": 2, "dmg_taken_mult": 1.35},
	# Duelliste : riposte = contre-attaque auto au corps à corps ; parade = bloque la prochaine attaque.
	"riposte":       {"name": "Riposte",         "duration": 2, "riposte": true},
	"parade":        {"name": "Parade",          "duration": 2, "block_next": true},
}

# Terrain tactique (data-driven). Chaque type modifie dégâts ou déplacement.
const TERRAIN := {
	"foret":    {"name": "Forêt",    "color": Color(0.05, 0.30, 0.05, 0.52), "symbol": "F",
	             "ranged_dmg_mult": 0.65},
	"ruines":   {"name": "Ruines",   "color": Color(0.40, 0.38, 0.28, 0.48), "symbol": "R",
	             "dmg_taken_mult": 0.80},
	"marecage": {"name": "Marécage", "color": Color(0.20, 0.48, 0.14, 0.72), "symbol": "M",
	             "move_penalty": 2},
}

# --- Cartes / champs de bataille ---
# Chaque carte = un biome avec sa propre dominante de terrain (weights),
# sa densité d'obstacles (terrain), son nombre de plateaux surélevés (heights)
# et sa palette de sol (palette : damier top_a/top_b + parois wall_l/wall_r).
# Tirée au hasard au début du combat (current_map). Gameplay 100 % data-driven.
const MAPS := [
	{"name": "Plaine ouverte", "weights": {"foret": 1, "ruines": 1, "marecage": 1},
	 "terrain": 6,  "heights": 3,
	 "palette": {"top_a": Color(0.318, 0.420, 0.235), "top_b": Color(0.270, 0.368, 0.200),
	             "wall_l": Color(0.184, 0.130, 0.092), "wall_r": Color(0.262, 0.188, 0.130)}},
	{"name": "Forêt ancienne", "weights": {"foret": 5, "ruines": 1, "marecage": 1},
	 "terrain": 14, "heights": 2,
	 "palette": {"top_a": Color(0.196, 0.310, 0.176), "top_b": Color(0.160, 0.265, 0.148),
	             "wall_l": Color(0.130, 0.105, 0.078), "wall_r": Color(0.190, 0.150, 0.108)}},
	{"name": "Ruines maudites", "weights": {"foret": 1, "ruines": 5, "marecage": 1},
	 "terrain": 13, "heights": 4,
	 "palette": {"top_a": Color(0.412, 0.376, 0.298), "top_b": Color(0.354, 0.320, 0.250),
	             "wall_l": Color(0.220, 0.190, 0.150), "wall_r": Color(0.300, 0.258, 0.204)}},
	{"name": "Marais brumeux", "weights": {"foret": 2, "ruines": 1, "marecage": 6},
	 "terrain": 15, "heights": 1,
	 "palette": {"top_a": Color(0.240, 0.296, 0.196), "top_b": Color(0.198, 0.252, 0.165),
	             "wall_l": Color(0.140, 0.130, 0.090), "wall_r": Color(0.196, 0.180, 0.120)}},
	{"name": "Hauts plateaux", "weights": {"foret": 1, "ruines": 2, "marecage": 1},
	 "terrain": 8,  "heights": 7,
	 "palette": {"top_a": Color(0.302, 0.320, 0.380), "top_b": Color(0.252, 0.270, 0.330),
	             "wall_l": Color(0.150, 0.150, 0.190), "wall_r": Color(0.210, 0.212, 0.262)}},
]
var current_map := 0

# Sélections courantes (définies à l'écran de préparation, étape 6).
var difficulty := "normal"
var player_team: Array = ["tank"]
var ai_team: Array = ["archer"]

# --- Réglages audio (persistés dans user://settings.cfg) ---
# Volumes 0.0 → 1.0 par bus, convertis en dB et appliqués à l'AudioServer.
const SETTINGS_PATH := "user://settings.cfg"
var volumes := {"Master": 0.9, "Music": 0.7, "SFX": 1.0}

# --- Progression : classes débloquées au fil des victoires ---
# Un noyau jouable d'emblée (tous les rôles couverts) ; chaque victoire débloque
# la classe suivante de UNLOCK_ORDER (basiques → avancées → uniques en récompense).
# Persisté dans user://settings.cfg (section [progress]).
const STARTER_CLASSES := ["tank", "archer", "mage", "soigneur", "berserker", "paladin"]
const UNLOCK_ORDER := [
	"lancier", "mage_glace", "druide", "chasseur", "alchimiste", "envouteur",
	"pretreguerrier", "chevaliernoir", "assassin", "duelliste", "archere",
	"necromancien", "invocateur", "barde",
]
var unlocked: Array = STARTER_CLASSES.duplicate()
var wins := 0

# --- Campagne (mode histoire) : état persistant de l'exploration ---
# Persisté dans user://settings.cfg (section [campaign]).
var campaign_battle := false         # le combat en cours vient de la campagne
var campaign_enemy_id := ""          # ennemi d'overworld affronté
var campaign_pos := Vector2(-1, -1)  # position du joueur (en tuiles), -1 = départ
var campaign_defeated: Array = []    # ids des ennemis d'overworld vaincus
var campaign_difficulty := "normal"  # choisie au début de la campagne ;
                                     # hardcore = mort de l'équipe → campagne effacée
var campaign_saved_at := ""          # horodatage de la dernière sauvegarde (affiché au menu)
var campaign_flags := {}             # mémoire des choix (PNJ, quêtes) : clé -> bool
var campaign_hero := {}              # héros créé : name, gender ("f"/"m"), design, class

# Compagnons recrutables en campagne (id -> nom, classe de combat, figure
# d'exploration). Recrutés via les dialogues ; ils marchent derrière le héros.
# Leurs classes sont PROPRES à la campagne (le JcJ est un mode à part).
const COMPANIONS := {
	"sera":  {"name": "Sera",  "class": "sera_pisteuse",  "figure": "etrangere"},
	"garin": {"name": "Garin", "class": "garin_bucheron", "figure": "bucheron"},
	"joran": {"name": "Joran", "class": "joran_mire",     "figure": "mire"},
	"luna":  {"name": "Luna",  "class": "luna_archere",   "figure": "luna"},
}
var campaign_party: Array = []         # ids des compagnons recrutés (ordre de marche)
var campaign_relations := {}           # id compagnon -> affinité (int, défaut 0)


func relation(cid: String) -> int:
	return int(campaign_relations.get(cid, 0))


func add_relation(cid: String, n: int) -> void:
	campaign_relations[cid] = relation(cid) + n


# Libellé d'affinité (affiché dans la fiche d'équipe).
func relation_label(cid: String) -> String:
	var r := relation(cid)
	if r <= -2: return "Hostile"
	if r < 0:   return "Méfiant"
	if r == 0:  return "Neutre"
	if r < 3:   return "Amical"
	return "Loyal"
var campaign_battle_names: Array = []  # noms des unités joueur au combat (transitoire)
var campaign_battle_ids: Array = []    # ids de progression ("hero", "sera"...) alignés

# --- Niveaux & arbres de compétences (campagne uniquement) ---
# Victoire = +1 niveau pour chaque membre présent (+2 contre un boss), max 12.
# Chaque niveau : choix d'un bonus ; chaque niveau PAIR : choix d'1 compétence
# parmi 2 dans l'arbre du RÔLE (rangée = niveau/2). En campagne, on démarre
# SANS compétence : le build se construit en jouant.
const MAX_LEVEL := 12
const LEVEL_BONUSES := [
	{"id": "pv",   "label": "+6% PV max",   "hp_pct": 0.06},
	{"id": "atk",  "label": "+1 Attaque",   "atk": 1},
	{"id": "crit", "label": "+3% Critique", "crit": 0.03},
]
# Arbres par rôle : 6 rangées de 2 choix (types 100 % déjà gérés par le moteur).
const TREE := {
	"tank": [
		[{"name": "Protection", "type": "shield_ally", "target": "ally", "range": 2, "cooldown": 3, "desc": "Bouclier (-50% dégâts subis, 2 tours) sur un allié à 2 cases."},
		 {"name": "Garde", "type": "self_buff", "target": "self", "buff": "garde", "cooldown": 3, "desc": "-60% de dégâts subis pendant 2 tours."}],
		[{"name": "Coup de bouclier", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.5, "range": 1, "cooldown": 3, "desc": "Frappe lourde (×1.5) au corps à corps."},
		 {"name": "Brise-armure", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 1, "cooldown": 3, "desc": "Frappe et expose la cible (+35% dégâts subis, 2 tours)."}],
		[{"name": "Rempart", "type": "buff_ally", "target": "ally", "buff": "bouclier", "range": 2, "cooldown": 3, "desc": "Bouclier (-50% dégâts subis, 2 tours) sur un allié."},
		 {"name": "Secousse", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 1, "cooldown": 3, "desc": "Frappe la cible et tous ses voisins."}],
		[{"name": "Représailles", "type": "self_buff", "target": "self", "buff": "riposte", "cooldown": 3, "desc": "Contre-attaque automatique au corps à corps (2 tours)."},
		 {"name": "Cri de guerre", "type": "team_buff", "target": "self", "buff": "force", "cooldown": 4, "desc": "TOUTE l'équipe gagne +50% de dégâts (2 tours)."}],
		[{"name": "Châtiment", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.7, "range": 1, "cooldown": 3, "desc": "Coup dévastateur (×1.7)."},
		 {"name": "Entrave", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 1, "cooldown": 4, "desc": "Frappe et immobilise la cible 1 tour."}],
		[{"name": "Forteresse", "type": "team_buff", "target": "self", "buff": "bouclier", "cooldown": 4, "desc": "TOUTE l'équipe subit -50% de dégâts (2 tours)."},
		 {"name": "Exécution", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.9, "range": 1, "cooldown": 3, "desc": "Coup fatal (×1.9)."}],
	],
	"melee": [
		[{"name": "Frappe lourde", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.5, "range": 1, "cooldown": 3, "desc": "Coup puissant (×1.5) au corps à corps."},
		 {"name": "Affûtage", "type": "self_buff", "target": "self", "buff": "force", "cooldown": 4, "desc": "+50% de dégâts pendant 2 tours."}],
		[{"name": "Fauchage", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 1, "cooldown": 3, "desc": "Frappe la cible et tous ses voisins."},
		 {"name": "Entaille exposante", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 1, "cooldown": 3, "desc": "Frappe et expose la cible (+35% dégâts subis, 2 tours)."}],
		[{"name": "Pas de l'ombre", "type": "teleport_strike", "target": "enemy", "range": 4, "cooldown": 3, "desc": "Se téléporte au contact d'un ennemi (4 cases) et frappe."},
		 {"name": "Rage", "type": "self_buff", "target": "self", "buff": "rage", "cooldown": 4, "desc": "+50% de dégâts mais +25% subis (2 tours)."}],
		[{"name": "Lame drainante", "type": "drain_strike", "target": "enemy", "range": 1, "cooldown": 4, "desc": "Frappe et récupère 60% des dégâts en PV."},
		 {"name": "Coup au genou", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 1, "cooldown": 4, "desc": "Frappe et immobilise la cible 1 tour."}],
		[{"name": "Décapitation", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 1, "cooldown": 3, "desc": "Coup dévastateur (×1.8). Idéal pour achever."},
		 {"name": "Posture du duel", "type": "self_buff", "target": "self", "buff": "riposte", "cooldown": 3, "desc": "Contre-attaque automatique au corps à corps (2 tours)."}],
		[{"name": "Tourbillon", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.3, "range": 1, "cooldown": 3, "desc": "Fauche tout autour (×1.3)."},
		 {"name": "Coup fatal", "type": "heavy_strike", "target": "enemy", "dmg_mult": 2.0, "range": 1, "cooldown": 3, "desc": "Le coup ultime (×2.0)."}],
	],
	"ranged": [
		[{"name": "Tir visé", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.5, "range": 4, "cooldown": 3, "desc": "Tir puissant (×1.5) jusqu'à 4 cases."},
		 {"name": "Flèche vénéneuse", "type": "apply_debuff", "target": "enemy", "buff": "poison", "range": 4, "cooldown": 3, "desc": "Tir + poison (3 dégâts/tour, 3 tours)."}],
		[{"name": "Tir perforant", "type": "piercing_shot", "target": "line", "range": 4, "cooldown": 3, "desc": "Touche TOUS les ennemis alignés dans une direction."},
		 {"name": "Flèche entravante", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 4, "cooldown": 3, "desc": "Tir + immobilisation 1 tour."}],
		[{"name": "Tir en retraite", "type": "retreat_shot", "target": "enemy", "range": 4, "retreat": 2, "cooldown": 3, "desc": "Tire puis recule de 2 cases."},
		 {"name": "Tir fragilisant", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 4, "cooldown": 3, "desc": "Tir + vulnérabilité (+35% dégâts subis, 2 tours)."}],
		[{"name": "Pluie de flèches", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 4, "cooldown": 3, "desc": "Salve sur la cible et tous ses voisins."},
		 {"name": "Tir glacé", "type": "apply_debuff", "target": "enemy", "buff": "gel", "range": 4, "cooldown": 3, "desc": "Tir + gel (-2 déplacement, 2 tours)."}],
		[{"name": "Tir d'élite", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 5, "cooldown": 3, "desc": "Tir surpuissant (×1.8) à très longue portée."},
		 {"name": "Flèche toxique", "type": "double_dot", "target": "enemy", "range": 4, "cooldown": 3, "desc": "Applique Poison ET Brûlure simultanément."}],
		[{"name": "Tir fatal", "type": "heavy_strike", "target": "enemy", "dmg_mult": 2.0, "range": 5, "cooldown": 3, "desc": "Le tir ultime (×2.0)."},
		 {"name": "Volée suppressive", "type": "team_debuff", "target": "self", "buff": "affaiblissement", "cooldown": 4, "desc": "TOUS les ennemis perdent 30% de dégâts (2 tours)."}],
	],
	"healer": [
		[{"name": "Soin", "type": "war_heal", "target": "ally", "heal_amount": 14, "range": 3, "can_self": true, "cooldown": 3, "desc": "Rend 14 PV à un allié (ou soi)."},
		 {"name": "Régénération", "type": "buff_ally", "target": "ally", "buff": "regen", "range": 3, "can_self": true, "cooldown": 3, "desc": "Soigne 5 PV/tour pendant 3 tours."}],
		[{"name": "Purification", "type": "purify", "target": "ally", "range": 3, "can_self": true, "cooldown": 3, "desc": "Retire tous les effets négatifs d'un allié (ou de soi)."},
		 {"name": "Protection sacrée", "type": "buff_ally", "target": "ally", "buff": "bouclier", "range": 3, "can_self": true, "cooldown": 3, "desc": "Bouclier (-50% dégâts subis, 2 tours)."}],
		[{"name": "Renforcement", "type": "empower_ally", "target": "ally", "range": 3, "cooldown": 3, "desc": "Un allié gagne +50% de dégâts (2 tours)."},
		 {"name": "Semonce", "type": "apply_debuff", "target": "enemy", "buff": "affaiblissement", "range": 3, "cooldown": 3, "desc": "Frappe et affaiblit la cible (-30% dégâts, 2 tours)."}],
		[{"name": "Grand soin", "type": "war_heal", "target": "ally", "heal_amount": 20, "range": 3, "can_self": true, "cooldown": 3, "desc": "Rend 20 PV à un allié (ou soi)."},
		 {"name": "Garde collective", "type": "team_buff", "target": "self", "buff": "bouclier", "cooldown": 5, "desc": "TOUTE l'équipe subit -50% de dégâts (2 tours)."}],
		[{"name": "Jugement", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 3, "cooldown": 3, "desc": "Frappe et condamne (+35% dégâts subis, 2 tours)."},
		 {"name": "Garde du bretteur", "type": "buff_ally", "target": "ally", "buff": "riposte", "range": 3, "can_self": true, "cooldown": 4, "desc": "Un allié contre-attaque au corps à corps (2 tours)."}],
		[{"name": "Hymne héroïque", "type": "team_buff", "target": "self", "buff": "force", "cooldown": 4, "desc": "TOUTE l'équipe gagne +50% de dégâts (2 tours)."},
		 {"name": "Miracle", "type": "war_heal", "target": "ally", "heal_amount": 32, "range": 3, "can_self": true, "cooldown": 4, "desc": "Rend 32 PV à un allié (ou soi)."}],
	],
}

# ARBRES PAR CLASSE (héros de campagne, façon Sword of Convallaria) : chaque
# classe a SON arbre identitaire (6 rangées × 2 choix de build). Les compagnons
# et les anciennes sauvegardes retombent sur l'arbre de RÔLE (TREE) via tree_rows.
const CLASS_TREES := {
	"lame_errante": [
		[{"name": "Frappe du voyageur", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.5, "range": 1, "cooldown": 3, "desc": "Coup net et sans bavure (×1.5)."},
		 {"name": "Garde souple", "type": "self_buff", "target": "self", "buff": "garde", "cooldown": 4, "desc": "Esquive en lame : -60% de dégâts subis (2 tours)."}],
		[{"name": "Croc-en-lame", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 1, "cooldown": 4, "desc": "Frappe les jambes : immobilise 1 tour."},
		 {"name": "Entaille ouverte", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 1, "cooldown": 3, "desc": "Ouvre la garde : +35% de dégâts subis (2 tours)."}],
		[{"name": "Pas du duelliste", "type": "self_buff", "target": "self", "buff": "riposte", "cooldown": 3, "desc": "Contre-attaque automatique au corps à corps (2 tours)."},
		 {"name": "Lame tournoyante", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 1, "cooldown": 3, "desc": "Fauche la cible et ses voisins."}],
		[{"name": "Percée éclair", "type": "teleport_strike", "target": "enemy", "range": 4, "cooldown": 3, "desc": "Fond sur un ennemi distant et frappe."},
		 {"name": "Affûtage de route", "type": "self_buff", "target": "self", "buff": "force", "cooldown": 4, "desc": "+50% de dégâts (2 tours)."}],
		[{"name": "Botte secrète", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 1, "cooldown": 3, "desc": "L'estocade qu'on n'apprend qu'une fois (×1.8)."},
		 {"name": "Parade parfaite", "type": "self_buff", "target": "self", "buff": "parade", "cooldown": 3, "desc": "Bloque ENTIÈREMENT la prochaine attaque reçue."}],
		[{"name": "Lame errante", "type": "heavy_strike", "target": "enemy", "dmg_mult": 2.0, "range": 1, "cooldown": 3, "desc": "Le coup qui porte ton nom (×2.0)."},
		 {"name": "Tourbillon final", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.3, "range": 1, "cooldown": 3, "desc": "Fauche tout autour (×1.3)."}],
	],
	"rempart": [
		[{"name": "Protection", "type": "shield_ally", "target": "ally", "range": 2, "cooldown": 3, "desc": "Bouclier (-50% dégâts, 2 tours) sur un allié."},
		 {"name": "Posture de fer", "type": "self_buff", "target": "self", "buff": "garde", "cooldown": 3, "desc": "-60% de dégâts subis (2 tours)."}],
		[{"name": "Coup de bouclier", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.5, "range": 1, "cooldown": 3, "desc": "Assomme du plat du bouclier (×1.5)."},
		 {"name": "Brise-armure", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 1, "cooldown": 3, "desc": "Fend la défense : +35% de dégâts subis (2 tours)."}],
		[{"name": "Rempart mobile", "type": "buff_ally", "target": "ally", "buff": "bouclier", "range": 2, "cooldown": 3, "desc": "Couvre un allié (-50% dégâts, 2 tours)."},
		 {"name": "Secousse", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 1, "cooldown": 3, "desc": "Onde de choc sur la cible et ses voisins."}],
		[{"name": "Représailles", "type": "self_buff", "target": "self", "buff": "riposte", "cooldown": 3, "desc": "Contre-attaque automatique au corps à corps (2 tours)."},
		 {"name": "Entrave", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 1, "cooldown": 4, "desc": "Cloue un ennemi sur place 1 tour."}],
		[{"name": "Cri de ralliement", "type": "team_buff", "target": "self", "buff": "force", "cooldown": 4, "desc": "TOUTE l'équipe : +50% de dégâts (2 tours)."},
		 {"name": "Châtiment", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.7, "range": 1, "cooldown": 3, "desc": "Coup lourd (×1.7)."}],
		[{"name": "Forteresse", "type": "team_buff", "target": "self", "buff": "bouclier", "cooldown": 4, "desc": "TOUTE l'équipe : -50% de dégâts subis (2 tours)."},
		 {"name": "Jugement du mur", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.9, "range": 1, "cooldown": 3, "desc": "Le mur rend ses verdicts (×1.9)."}],
	],
	"oeil_lynx": [
		[{"name": "Tir visé", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.5, "range": 4, "cooldown": 3, "desc": "Tir précis (×1.5) à 4 cases."},
		 {"name": "Flèche vénéneuse", "type": "apply_debuff", "target": "enemy", "buff": "poison", "range": 4, "cooldown": 3, "desc": "Tir + poison (3 dégâts/tour, 3 tours)."}],
		[{"name": "Flèche entravante", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 4, "cooldown": 3, "desc": "Cloue la proie sur place 1 tour."},
		 {"name": "Tir fragilisant", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 4, "cooldown": 3, "desc": "+35% de dégâts subis (2 tours)."}],
		[{"name": "Tir perforant", "type": "piercing_shot", "target": "line", "range": 4, "cooldown": 3, "desc": "Transperce TOUS les ennemis alignés."},
		 {"name": "Pluie de flèches", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 4, "cooldown": 3, "desc": "Salve sur la cible et ses voisins."}],
		[{"name": "Tir en retraite", "type": "retreat_shot", "target": "enemy", "range": 4, "retreat": 2, "cooldown": 3, "desc": "Tire puis recule de 2 cases."},
		 {"name": "Tir glacé", "type": "apply_debuff", "target": "enemy", "buff": "gel", "range": 4, "cooldown": 3, "desc": "Gèle la cible (-2 déplacement, 2 tours)."}],
		[{"name": "Tir d'élite", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 5, "cooldown": 3, "desc": "Tir surpuissant à très longue portée (×1.8)."},
		 {"name": "Flèche toxique", "type": "double_dot", "target": "enemy", "range": 4, "cooldown": 3, "desc": "Poison ET brûlure simultanés."}],
		[{"name": "Œil du lynx", "type": "heavy_strike", "target": "enemy", "dmg_mult": 2.0, "range": 5, "cooldown": 3, "desc": "On ne rate jamais deux fois (×2.0)."},
		 {"name": "Volée suppressive", "type": "team_debuff", "target": "self", "buff": "affaiblissement", "cooldown": 4, "desc": "TOUS les ennemis : -30% de dégâts (2 tours)."}],
	],
	"mire_errant": [
		[{"name": "Suture", "type": "war_heal", "target": "ally", "heal_amount": 14, "range": 3, "can_self": true, "cooldown": 3, "desc": "Rend 14 PV à un allié (ou soi)."},
		 {"name": "Cataplasme", "type": "buff_ally", "target": "ally", "buff": "regen", "range": 3, "can_self": true, "cooldown": 3, "desc": "Régénère 5 PV/tour (3 tours)."}],
		[{"name": "Purge", "type": "purify", "target": "ally", "range": 3, "can_self": true, "cooldown": 3, "desc": "Retire TOUS les effets négatifs d'un allié."},
		 {"name": "Bandage blindé", "type": "buff_ally", "target": "ally", "buff": "bouclier", "range": 3, "can_self": true, "cooldown": 3, "desc": "Bouclier (-50% dégâts, 2 tours)."}],
		[{"name": "Tonique de guerre", "type": "empower_ally", "target": "ally", "range": 3, "cooldown": 3, "desc": "Un allié gagne +50% de dégâts (2 tours)."},
		 {"name": "Anesthésiant", "type": "apply_debuff", "target": "enemy", "buff": "affaiblissement", "range": 3, "cooldown": 3, "desc": "L'ennemi perd 30% de dégâts (2 tours)."}],
		[{"name": "Grand soin", "type": "war_heal", "target": "ally", "heal_amount": 20, "range": 3, "can_self": true, "cooldown": 3, "desc": "Rend 20 PV à un allié (ou soi)."},
		 {"name": "Sédatif", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 3, "cooldown": 4, "desc": "Endort les jambes : immobilise 1 tour."}],
		[{"name": "Triage", "type": "team_buff", "target": "self", "buff": "bouclier", "cooldown": 5, "desc": "TOUTE l'équipe : -50% de dégâts subis (2 tours)."},
		 {"name": "Scalpel", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 3, "cooldown": 3, "desc": "Sait où ça fait mal : +35% de dégâts subis (2 tours)."}],
		[{"name": "Miracle de route", "type": "war_heal", "target": "ally", "heal_amount": 32, "range": 3, "can_self": true, "cooldown": 4, "desc": "Rend 32 PV — le mire ne perd personne."},
		 {"name": "Hymne du convoi", "type": "team_buff", "target": "self", "buff": "force", "cooldown": 4, "desc": "TOUTE l'équipe : +50% de dégâts (2 tours)."}],
	],
	"flamme_egaree": [
		[{"name": "Boule de feu", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.5, "range": 3, "cooldown": 3, "desc": "Projectile ardent (×1.5)."},
		 {"name": "Cendres aveuglantes", "type": "apply_debuff", "target": "enemy", "buff": "affaiblissement", "range": 3, "cooldown": 3, "desc": "L'ennemi perd 30% de dégâts (2 tours)."}],
		[{"name": "Déflagration", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.0, "range": 3, "cooldown": 3, "desc": "Explosion : la cible et tous ses voisins."},
		 {"name": "Fournaise", "type": "double_dot", "target": "enemy", "range": 3, "cooldown": 3, "desc": "Poison ET brûlure simultanés."}],
		[{"name": "Mur de flammes", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 3, "cooldown": 4, "desc": "Encercle de feu : immobilise 1 tour."},
		 {"name": "Fragilisation", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 3, "cooldown": 3, "desc": "La chaleur fend l'armure : +35% de dégâts subis."}],
		[{"name": "Brasier intérieur", "type": "self_buff", "target": "self", "buff": "force", "cooldown": 4, "desc": "+50% de dégâts (2 tours)."},
		 {"name": "Voile de fumée", "type": "self_buff", "target": "self", "buff": "garde", "cooldown": 4, "desc": "-60% de dégâts subis (2 tours)."}],
		[{"name": "Comète", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 3, "cooldown": 3, "desc": "Le ciel tombe (×1.8)."},
		 {"name": "Nova ardente", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.2, "range": 3, "cooldown": 3, "desc": "Explosion renforcée (×1.2 de zone)."}],
		[{"name": "Flamme égarée", "type": "heavy_strike", "target": "enemy", "dmg_mult": 2.0, "range": 4, "cooldown": 3, "desc": "Tout brûle, à la fin (×2.0, 4 cases)."},
		 {"name": "Écran de braises", "type": "team_debuff", "target": "self", "buff": "affaiblissement", "cooldown": 4, "desc": "TOUS les ennemis : -30% de dégâts (2 tours)."}],
	],
	"ombre_passante": [
		[{"name": "Lame sournoise", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.5, "range": 1, "cooldown": 3, "desc": "Frappe là où ça fait mal (×1.5)."},
		 {"name": "Poison de lame", "type": "apply_debuff", "target": "enemy", "buff": "poison", "range": 1, "cooldown": 3, "desc": "Entaille empoisonnée (3 dégâts/tour, 3 tours)."}],
		[{"name": "Pas de l'ombre", "type": "teleport_strike", "target": "enemy", "range": 4, "cooldown": 3, "desc": "Surgit au contact d'une proie distante."},
		 {"name": "Tendons tranchés", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 1, "cooldown": 4, "desc": "Immobilise la cible 1 tour."}],
		[{"name": "Exposition", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 1, "cooldown": 3, "desc": "Ouvre une faille : +35% de dégâts subis (2 tours)."},
		 {"name": "Affûtage", "type": "self_buff", "target": "self", "buff": "force", "cooldown": 4, "desc": "+50% de dégâts (2 tours)."}],
		[{"name": "Lame drainante", "type": "drain_strike", "target": "enemy", "range": 1, "cooldown": 4, "desc": "Frappe et récupère 60% des dégâts en PV."},
		 {"name": "Voile d'ombre", "type": "self_buff", "target": "self", "buff": "garde", "cooldown": 4, "desc": "-60% de dégâts subis (2 tours)."}],
		[{"name": "Exécution", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 1, "cooldown": 3, "desc": "Achève les blessés (×1.8)."},
		 {"name": "Danse des lames", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.1, "range": 1, "cooldown": 3, "desc": "Tourbillon de dagues (×1.1 de zone)."}],
		[{"name": "Ombre passante", "type": "heavy_strike", "target": "enemy", "dmg_mult": 2.0, "range": 1, "cooldown": 3, "desc": "On ne la voit qu'une fois (×2.0)."},
		 {"name": "Parade fantôme", "type": "self_buff", "target": "self", "buff": "parade", "cooldown": 3, "desc": "Bloque ENTIÈREMENT la prochaine attaque."}],
	],
	"duelliste_campagne": [
		[{"name": "Estocade", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.5, "range": 1, "cooldown": 3, "desc": "Coup d'escrime précis (×1.5)."},
		 {"name": "Posture de riposte", "type": "self_buff", "target": "self", "buff": "riposte", "cooldown": 3, "desc": "Contre-attaque automatique au corps à corps (2 tours)."}],
		[{"name": "Parade", "type": "self_buff", "target": "self", "buff": "parade", "cooldown": 3, "desc": "Bloque ENTIÈREMENT la prochaine attaque reçue."},
		 {"name": "Entaille exposante", "type": "apply_debuff", "target": "enemy", "buff": "vulnerabilite", "range": 1, "cooldown": 3, "desc": "Ouvre la garde : +35% de dégâts subis (2 tours)."}],
		[{"name": "Pas de velours", "type": "teleport_strike", "target": "enemy", "range": 4, "cooldown": 3, "desc": "Glisse au contact d'une cible distante et frappe."},
		 {"name": "Affûtage", "type": "self_buff", "target": "self", "buff": "force", "cooldown": 4, "desc": "+50% de dégâts (2 tours)."}],
		[{"name": "Croc-jambe", "type": "apply_debuff", "target": "enemy", "buff": "racines", "range": 1, "cooldown": 4, "desc": "Fauche l'appui : immobilise 1 tour."},
		 {"name": "Garde haute", "type": "self_buff", "target": "self", "buff": "garde", "cooldown": 4, "desc": "-60% de dégâts subis (2 tours)."}],
		[{"name": "Estocade parfaite", "type": "heavy_strike", "target": "enemy", "dmg_mult": 1.8, "range": 1, "cooldown": 3, "desc": "Le geste répété mille fois (×1.8)."},
		 {"name": "Lame dansante", "type": "cleave", "target": "enemy", "radius": 1, "dmg_mult": 1.1, "range": 1, "cooldown": 3, "desc": "Valse d'acier sur la cible et ses voisins (×1.1)."}],
		[{"name": "Sentence", "type": "heavy_strike", "target": "enemy", "dmg_mult": 2.0, "range": 1, "cooldown": 3, "desc": "Le duel ne se gagne qu'une fois (×2.0)."},
		 {"name": "Démonstration", "type": "team_debuff", "target": "self", "buff": "affaiblissement", "cooldown": 4, "desc": "Son aisance glace TOUS les ennemis : -30% de dégâts (2 tours)."}],
	],
}


# Arbre d'un personnage : son arbre de CLASSE s'il existe, sinon celui du RÔLE
# (compagnons, anciennes sauvegardes avec classes JcJ).
func tree_rows(cid: String) -> Array:
	if CLASS_TREES.has(cid):
		return CLASS_TREES[cid]
	return TREE.get(str(CLASSES.get(cid, {}).get("role", "melee")), TREE.melee)


# Progression par membre ("hero", "sera"...) : niveau, XP, choix en attente,
# bonus cumulés et compétences choisies (dicts complets, persistés tels quels).
# XP : gagnée à la victoire (= PV max totaux des ennemis, ×2 contre un boss),
# le MVP du combat gagne +10%. Donne droit aux montées de niveau (max 12).
var campaign_levels := {}
var campaign_items: Array = []  # sacoche (objets de quête)


func member_progress(mid: String) -> Dictionary:
	if not campaign_levels.has(mid):
		campaign_levels[mid] = {"level": 0, "pending": 0, "xp": 0,
				"hp_pct": 0.0, "atk": 0, "crit": 0.0, "skills": []}
	if not campaign_levels[mid].has("xp"):  # migration des vieilles sauvegardes
		campaign_levels[mid]["xp"] = 0
	return campaign_levels[mid]


# XP nécessaire pour passer du niveau donné au suivant (courbe croissante).
func xp_to_next(level: int) -> int:
	return 80 + level * 40


# Crédite de l'XP à un membre et convertit en montées de niveau « en attente »
# (les choix de bonus/compétences se font au retour dans le monde).
func grant_xp(mid: String, amount: int) -> void:
	var p := member_progress(mid)
	var target: int = int(p.level) + int(p.pending)
	if target >= MAX_LEVEL:
		return
	p.xp = int(p.xp) + amount
	while target < MAX_LEVEL and int(p.xp) >= xp_to_next(target):
		p.xp = int(p.xp) - xp_to_next(target)
		p.pending = int(p.pending) + 1
		target += 1


# Pose un drapeau de campagne (choix mémorisé) sans sauvegarder (l'appelant
# regroupe ses set_flag puis appelle save_campaign une seule fois).
func set_flag(key: String, value := true) -> void:
	campaign_flags[key] = value


func get_flag(key: String) -> bool:
	return bool(campaign_flags.get(key, false))


# Sauvegarde la campagne en l'horodatant (date/heure affichées au menu Campagne).
func save_campaign() -> void:
	campaign_saved_at = Time.get_datetime_string_from_system(false, true)
	save_settings()


# Efface la campagne (« Recommencer » au menu, ou mort permanente en Hardcore).
func clear_campaign() -> void:
	campaign_pos = Vector2(-1, -1)
	campaign_defeated = []
	campaign_flags = {}
	campaign_hero = {}
	campaign_party = []
	campaign_relations = {}
	campaign_levels = {}
	campaign_items = []
	campaign_saved_at = ""
	save_settings()


# Une campagne est-elle en cours (sauvegarde existante) ?
func has_campaign() -> bool:
	return campaign_pos.x >= 0.0 or campaign_defeated.size() > 0 \
			or campaign_flags.size() > 0 or campaign_hero.size() > 0


func _ready() -> void:
	# Web (Xbox/TV) : 30 i/s suffisent largement pour un tactique et divisent
	# par deux la charge GPU/CPU du navigateur (stabilité avant tout).
	if OS.has_feature("web"):
		Engine.max_fps = 30
	load_settings()
	for bus in volumes:
		apply_volume(bus, float(volumes[bus]))


# La classe est-elle débloquée (jouable / draftable) ?
func is_unlocked(cid: String) -> bool:
	return unlocked.has(cid)


# Enregistre une victoire : débloque la prochaine classe de la file, si elle existe.
# Renvoie le nom affichable de la classe nouvellement débloquée, ou "" si aucune.
func register_win() -> String:
	wins += 1
	for cid in UNLOCK_ORDER:
		if not unlocked.has(cid):
			unlocked.append(cid)
			save_settings()
			return str(CLASSES.get(cid, {}).get("name", cid))
	save_settings()
	return ""


# Applique un volume linéaire (0..1) au bus nommé (mute total si <= 0).
func apply_volume(bus_name: String, v: float) -> void:
	volumes[bus_name] = v
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.0001, 1.0)))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in volumes:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "wins", wins)
	cfg.set_value("campaign", "pos", campaign_pos)
	cfg.set_value("campaign", "defeated", campaign_defeated)
	cfg.set_value("campaign", "difficulty", campaign_difficulty)
	cfg.set_value("campaign", "saved_at", campaign_saved_at)
	cfg.set_value("campaign", "flags", campaign_flags)
	cfg.set_value("campaign", "hero", campaign_hero)
	cfg.set_value("campaign", "party", campaign_party)
	cfg.set_value("campaign", "relations", campaign_relations)
	cfg.set_value("campaign", "levels", campaign_levels)
	cfg.set_value("campaign", "items", campaign_items)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in volumes:
		volumes[bus] = float(cfg.get_value("audio", bus, volumes[bus]))
	# Progression : on repart toujours du noyau de départ, complété par la sauvegarde.
	unlocked = STARTER_CLASSES.duplicate()
	for cid in cfg.get_value("progress", "unlocked", []):
		if not unlocked.has(cid):
			unlocked.append(cid)
	wins = int(cfg.get_value("progress", "wins", 0))
	campaign_pos = cfg.get_value("campaign", "pos", Vector2(-1, -1))
	campaign_defeated = cfg.get_value("campaign", "defeated", [])
	campaign_difficulty = str(cfg.get_value("campaign", "difficulty", "normal"))
	campaign_saved_at = str(cfg.get_value("campaign", "saved_at", ""))
	campaign_flags = cfg.get_value("campaign", "flags", {})
	campaign_hero = cfg.get_value("campaign", "hero", {})
	campaign_party = cfg.get_value("campaign", "party", [])
	campaign_relations = cfg.get_value("campaign", "relations", {})
	campaign_levels = cfg.get_value("campaign", "levels", {})
	campaign_items = cfg.get_value("campaign", "items", [])

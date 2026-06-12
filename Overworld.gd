class_name Overworld
extends Node2D

# Mode histoire — phase 1 : exploration libre de la région 1 (Vallée de Bruyère)
# en vue diorama isométrique. Déplacement CONTINU au clavier (ZQSD / WASD /
# flèches) : aucune case surlignée, le tour par tour reste réservé au combat.
# Des ennemis rôdent dans leur zone (le Bois des Murmures, à l'est) : plus on
# s'enfonce, plus ils sont forts. Le contact aspire le joueur dans la
# « dimension de combat » (scène de combat existante, inchangée), puis on
# revient ici. Position + ennemis vaincus persistés via GameData ([campaign]).
# Visuels 100 % vectoriels, distincts de ceux du combat (silhouettes animées).

const TILE_W := 72.0
const TILE_H := 36.0
const HALF_W := TILE_W / 2.0
const HALF_H := TILE_H / 2.0
const EDGE_DEPTH := 30.0  # socle du diorama (parois sous les bords de la carte)

# Culling : on ne dessine que les cases/décors proches de la caméra. Sinon
# ~1500 cases + ~200 décors sont rendus à CHAQUE image → le GPU du navigateur
# sature et lâche (« WebGL context lost »). Demi-fenêtre + marge (caméra zoom 1).
const VIEW_HALF := Vector2(485.0, 435.0)
# Sol découpé en blocs STATIQUES de CHUNK×CHUNK tuiles : chaque bloc est dessiné
# UNE fois puis rejoué depuis le cache GPU (zéro géométrie recalculée par image).
const CHUNK := 8

const MAP_W := 44
const MAP_H := 34
const WORLD_SEED := 20260610  # monde déterministe : identique à chaque visite

const FOREST_X := 26  # à l'est de cette colonne : zone des ennemis
const SPAWN := Vector2(8.5, 9.5)

const PLAYER_SPEED := 3.4  # en tuiles/s (plus rapide que les ennemis : fuite possible)
const WANDER_SPEED := 1.1
const CHASE_SPEED := 2.6
const AGGRO_RANGE := 4.0
const DEAGGRO_RANGE := 7.0
const CONTACT_RANGE := 0.65
const BODY_RADIUS := 0.22  # rayon de collision des personnages (en tuiles)

# L'équipe de campagne = TON héros (créé dans CharacterCreate), seul au départ.
# Les compagnons recrutés l'agrandiront (phase suivante).

# Ennemis qui rôdent dans le bois, posés le long du sentier (px = colonne,
# dy = écart au sentier). Plus px est grand, plus on est profond, plus c'est fort.
# Équilibré pour un héros SOLO : combats 1v1 à l'orée ; le boss, lui, attend
# une équipe (y aller seul = courir à sa perte, et c'est voulu).
const FOES := [
	{"id": "loup_solitaire", "name": "Loup des Murmures", "px": 28.0, "dy": -1.2, "tier": 1,
	 "team": ["loup_murmures"], "hue": Color(0.40, 0.44, 0.52), "wkind": "loup"},
	{"id": "meute_murmures", "name": "Meute des Murmures", "px": 31.0, "dy": -3.2, "tier": 2,
	 "team": ["loup_murmures", "loup_murmures", "loup_murmures"], "hue": Color(0.34, 0.38, 0.46), "wkind": "loup"},
	{"id": "rodeurs_bois", "name": "Rôdeur du bois", "px": 34.0, "dy": 1.4, "tier": 2,
	 "team": ["rodeur_sombre"], "hue": Color(0.46, 0.34, 0.24), "wkind": "rodeur"},
	# Sera revient en ennemie SI on l'a dénoncée (conséquence du choix).
	{"id": "sera_traquee", "name": "Sera, la traquée", "px": 33.0, "dy": 3.4, "tier": 2,
	 "team": ["sera_traquee"], "hue": Color(0.30, 0.42, 0.62), "need_flag": "sera_denoncee", "wkind": "sera"},
	{"id": "traqueur", "name": "Traqueur des ombres", "px": 36.5, "dy": -1.8, "tier": 2,
	 "team": ["traqueur_ombres"], "hue": Color(0.30, 0.18, 0.40), "wkind": "traqueur"},
	{"id": "totem", "name": "Totem de ronces", "px": 38.5, "dy": 2.2, "tier": 2,
	 "team": ["totem_ronces", "loup_murmures"], "hue": Color(0.28, 0.40, 0.22), "fixed": true,
	 "wkind": "totem"},
	# Le boss est SEUL dans son combat : UN Veilleur, pas une équipe.
	{"id": "veilleur", "name": "Le Veilleur des Murmures", "px": 41.0, "dy": 0.0, "tier": 3,
	 "team": ["veilleur_murmures"], "hue": Color(0.45, 0.28, 0.66), "boss": true,
	 "wkind": "veilleur"},
	# BOSS SECRET : le Traqueur-Roi, débloqué en protégeant Sera (il la chasse).
	# Tapi au nord du bois, près de la clairière où elle se cachait.
	{"id": "traqueur_roi", "name": "Le Traqueur-Roi", "px": 31.0, "dy": -13.0, "tier": 3,
	 "team": ["traqueur_roi"], "hue": Color(0.62, 0.18, 0.34), "boss": true,
	 "need_flag": "roi_actif", "wkind": "roi"},
]

# --- PNJ du hameau (data-driven : un PNJ = des données, zéro code dédié) ---
# Chaque PNJ choisit son dialogue d'entrée : première règle satisfaite, sinon
# "fallback". Une règle = un drapeau requis (+ option "foes_down" : ennemis
# vaincus requis). "hide_flag" : si ce drapeau est posé, le PNJ a quitté le monde.
const NPCS := [
	{"id": "maud", "name": "Maud, l'herboriste", "pos": Vector2(7.6, 6.6), "figure": "herboriste",
	 "rules": [
		{"flag": "maud_vexee", "dialogue": "maud_froide"},
		# Conséquences : Maud sait ce qui se passe dans le bois (Sera, le boss).
		{"flag": "sera_denoncee", "foes_down": ["sera_traquee"],
		 "not_flag": "maud_sera_dit", "dialogue": "maud_sera_morte"},
		{"flag": "herbes_rendues", "foes_down": ["veilleur"],
		 "not_flag": "maud_boss_dit", "dialogue": "maud_apres_boss"},
		{"flag": "herbes_rendues", "dialogue": "maud_fin"},
		{"flag": "herbes_prises", "dialogue": "maud_rendre"},
		{"flag": "maud_quete", "dialogue": "maud_attente"},
		{"flag": "maud_amie", "dialogue": "maud_quete_offre"},
	 ], "fallback": "maud_intro"},
	# Le sachet perdu de Maud (objet au bord de l'étang, visible si quête prise).
	{"id": "sachet", "name": "Sachet d'herbes", "pos": Vector2(13.6, 20.2), "figure": "sachet",
	 "need_flag": "maud_quete", "hide_flag": "herbes_prises",
	 "prompt": "E — Ramasser",
	 "rules": [], "fallback": "sachet_trouve"},
	{"id": "garin", "name": "Garin, le bûcheron", "pos": Vector2(12.6, 11.6), "figure": "bucheron",
	 "party_flag": "garin_party",
	 "rules": [
		{"flag": "garin_recompense", "dialogue": "garin_fin"},
		{"flag": "garin_accepte", "foes_down": ["loup_solitaire", "rodeurs_bois"],
		 "dialogue": "garin_reward"},
		{"flag": "garin_accepte", "dialogue": "garin_attente"},
		{"flag": "garin_refuse", "dialogue": "garin_retente"},
		# Conséquence : Garin a entendu parler de la dénonciation de Sera.
		{"flag": "sera_denoncee", "dialogue": "garin_sera"},
	 ], "fallback": "garin_intro"},
	{"id": "sera", "name": "Sera, l'étrangère", "pos": Vector2(29.5, 3.5), "figure": "etrangere",
	 "hide_flag": "sera_denoncee", "party_flag": "sera_party",
	 "rules": [
		{"flag": "sera_proche", "dialogue": "sera_revoit"},
	 ], "fallback": "sera_intro"},
	# Joran, le mire déserteur : campé au sud de l'étang. On le RENCONTRE, on
	# gagne (ou perd) sa confiance sur PLUSIEURS conversations, et il ne rejoint
	# l'équipe QUE si la relation est assez bonne (relation_min).
	{"id": "joran", "name": "Joran, le mire", "pos": Vector2(18.6, 26.6), "figure": "mire",
	 "party_flag": "joran_party",
	 "rules": [
		{"flag": "joran_2_fait", "relation_min": {"joran": 2}, "dialogue": "joran_offre"},
		{"flag": "joran_2_fait", "not_flag": "joran_bond", "dialogue": "joran_bond_dlg"},
		{"flag": "joran_2_fait", "dialogue": "joran_mefiant"},
		{"flag": "joran_1_fait", "dialogue": "joran_2"},
	 ], "fallback": "joran_intro"},
	# Feux de camp : repos = sauvegarde + les créatures (hors boss) reviennent.
	{"id": "feu1", "name": "Feu de camp", "pos": Vector2(10.5, 14.8), "figure": "feu",
	 "prompt": "E — Se reposer", "rules": [], "fallback": "feu_repos"},
	{"id": "feu2", "name": "Feu de camp", "pos": Vector2(33.5, 17.0), "figure": "feu",
	 "prompt": "E — Se reposer", "rules": [], "fallback": "feu_repos"},
]

# Dialogues : texte + choix. Un choix peut poser des drapeaux ("set"), débloquer
# une classe ("unlock") et enchaîner sur un autre dialogue ("next", sinon fermer).
const DIALOGUES := {
	# — Maud : écouter ou mépriser ; elle s'en souviendra. —
	"maud_intro": {
		"speaker": "Maud, l'herboriste",
		"text": "Encore un qui lorgne vers l'est... Le bois murmure, petit. Ceux qui n'écoutent pas finissent dans la vase. Tu veux le conseil d'une vieille femme ?",
		"choices": [
			{"label": "« Je vous écoute. »", "set": {"maud_amie": true}, "next": "maud_conseil"},
			{"label": "« Gardez vos radotages, la vieille. »", "set": {"maud_vexee": true}, "next": "maud_vexe"},
		]},
	"maud_conseil": {
		"speaker": "Maud, l'herboriste",
		"text": "Le maître du bois ne se laisse pas fuir : quand on l'affronte, c'est jusqu'au bout. Ses ronces fauchent tout ce qui se serre — n'avance pas en rang d'oignons, écarte tes gens.",
		"choices": [{"label": "« Merci, Maud. »"}]},
	"maud_quete_offre": {
		"speaker": "Maud, l'herboriste",
		"text": "Toujours vivant, petit ? Tant mieux... J'ai perdu mon sachet d'herbes lunaires au bord de l'étang, mes vieilles jambes n'iront pas le chercher. Tu me le rapportes ? Je saurai te le rendre — j'en sais long sur ce bois.",
		"choices": [
			{"label": "« J'irai vous le chercher. »", "set": {"maud_quete": true}, "next": "maud_quete_merci"},
			{"label": "« Une autre fois, Maud. »"},
		]},
	"maud_quete_merci": {
		"speaker": "Maud, l'herboriste",
		"text": "Brave petit. Au bord de l'étang, côté prairie. Fais attention à la vase.",
		"choices": [{"label": "(Partir)"}]},
	"maud_attente": {
		"speaker": "Maud, l'herboriste",
		"text": "Alors, mon sachet ? Au bord de l'étang, côté prairie. Mes tisanes n'attendront pas cent ans.",
		"choices": [{"label": "« J'y vais. »"}]},
	"maud_rendre": {
		"speaker": "Maud, l'herboriste",
		"text": "Mon sachet ! Intact, en plus. Tiens, approche : je vais t'apprendre à lire le bois — où frapper, où ne pas mettre les pieds. Ça vaut toutes les pièces du monde.",
		"choices": [{"label": "« Merci, Maud. »", "set": {"herbes_rendues": true},
			"remove_item": "🌿 Sachet d'herbes", "xp_team": 60}]},
	"maud_fin": {
		"speaker": "Maud, l'herboriste",
		"text": "Mes tisanes embaument à nouveau, grâce à toi. File, le bois t'attend — et souviens-toi : écartés face aux ronces.",
		"choices": [{"label": "« À bientôt. »"}]},
	# — Conséquences croisées : le hameau réagit à tes actes. —
	"garin_sera": {
		"speaker": "Garin, le bûcheron",
		"text": "T'as su, pour l'étrangère ? Une rôdeuse, qu'ils disent. C'est toi qui l'as balancée, pas vrai ?... J'dis pas que t'as eu tort. J'dis que le bois, lui, oublie rien. Bref — un loup et un rôdeur squattent ma clairière. Tu me les chasses, j'te montre le métier des armes. Marché conclu ?",
		"choices": [
			{"label": "« Marché conclu. »", "set": {"garin_accepte": true, "garin_refuse": false}, "next": "garin_topla"},
			{"label": "« Débrouille-toi. »", "set": {"garin_refuse": true}, "next": "garin_decu"},
		]},
	"maud_sera_morte": {
		"speaker": "Maud, l'herboriste",
		"text": "Une silhouette est tombée dans le bois, cette nuit. Celle que tu as dénoncée... Le hameau dort mieux, paraît-il. Et toi, petit — tu dormiras bien ?",
		"choices": [
			{"label": "« Elle l'avait mérité. »", "set": {"maud_sera_dit": true}},
			{"label": "« ...Je devais le faire. »", "set": {"maud_sera_dit": true}},
			{"label": "(Baisser les yeux)", "set": {"maud_sera_dit": true}},
		]},
	"maud_apres_boss": {
		"speaker": "Maud, l'herboriste",
		"text": "Le bois s'est tu. Plus de murmures, plus de griffes la nuit... C'est toi qui as fait taire le Veilleur, pas vrai ? Alors écoute la vieille Maud : ce qui régnait ici n'était qu'un veilleur. Ce qu'il VEILLAIT est toujours quelque part. Tiens — pour la route.",
		"choices": [
			{"label": "« Merci, Maud. »", "set": {"maud_boss_dit": true}, "xp_team": 40},
		]},
	"sachet_trouve": {
		"speaker": "Sachet d'herbes",
		"text": "Un petit sachet de toile, à moitié enfoui dans la vase. L'odeur des herbes lunaires de Maud ne trompe pas.",
		"choices": [
			{"label": "(Ramasser le sachet)", "set": {"herbes_prises": true},
			 "item": "🌿 Sachet d'herbes"},
			{"label": "(Laisser là)"},
		]},
	"maud_vexe": {
		"speaker": "Maud, l'herboriste",
		"text": "... Comme tu veux. Le bois t'apprendra mieux que moi.",
		"choices": [{"label": "(Partir)"}]},
	"maud_froide": {
		"speaker": "Maud, l'herboriste",
		"text": "J'ai rien pour les malpolis. Va donc écouter le bois, puisqu'il te tarde.",
		"choices": [{"label": "(Partir)"}]},
	# — Garin : un marché ; le tenir récompense (déblocage de classe). —
	"garin_intro": {
		"speaker": "Garin, le bûcheron",
		"text": "J'peux plus couper une bûche : un loup et un rôdeur masqué squattent ma clairière. Nettoie-moi le bois — le loup ET le rôdeur — et j'te montre c'que j'sais du métier des armes. Marché conclu ?",
		"choices": [
			{"label": "« Marché conclu. »", "set": {"garin_accepte": true, "garin_refuse": false}, "next": "garin_topla"},
			{"label": "« Débrouille-toi. »", "set": {"garin_refuse": true}, "next": "garin_decu"},
		]},
	"garin_topla": {
		"speaker": "Garin, le bûcheron",
		"text": "Topez là ! Le loup rôde à l'orée, le rôdeur plus au fond. Reviens me voir quand c'est fait.",
		"choices": [{"label": "(Partir)"}]},
	"garin_decu": {
		"speaker": "Garin, le bûcheron",
		"text": "Ouais... comme tout le monde ici. Si tu changes d'avis, tu sais où me trouver.",
		"choices": [{"label": "(Partir)"}]},
	"garin_retente": {
		"speaker": "Garin, le bûcheron",
		"text": "T'as changé d'avis ? Le marché tient toujours : le loup et le rôdeur hors de ma clairière, et j'te montre le métier des armes.",
		"choices": [
			{"label": "« C'est d'accord. »", "set": {"garin_accepte": true, "garin_refuse": false}, "next": "garin_topla"},
			{"label": "« Non, toujours pas. »"},
		]},
	"garin_attente": {
		"speaker": "Garin, le bûcheron",
		"text": "Alors, ce bois ? J'entends encore ces sales bêtes d'ici... Le loup de l'orée et le rôdeur du fond, et on est quittes.",
		"choices": [{"label": "« J'y travaille. »"}]},
	"garin_reward": {
		"speaker": "Garin, le bûcheron",
		"text": "Par ma hache, t'as vraiment nettoyé la clairière ! Un marché est un marché : viens là, j'te montre la garde du lancier — c'est comme tenir un grand merlin, regarde...",
		"choices": [{"label": "« Montre-moi. »", "set": {"garin_recompense": true}, "unlock": "lancier"}]},
	"garin_fin": {
		"speaker": "Garin, le bûcheron",
		"text": "Alors, cette garde de lancier, ça rentre ? Ma clairière te dit merci. Si t'as besoin d'un bras de plus contre c'qui gronde au fond du bois... ma lance s'ennuie.",
		"choices": [
			{"label": "« Viens avec moi, Garin. »", "set": {"garin_party": true},
			 "recruit": "garin", "next": "garin_join"},
			{"label": "« Bon bois, Garin. »"},
		]},
	"garin_join": {
		"speaker": "Garin, le bûcheron",
		"text": "Ha ! J'range la hache, j'prends la lance. Devant moi personne passe — montre le chemin, compagnon.",
		"choices": [{"label": "(En route)"}]},
	# — Sera : un secret ; le garder ou la dénoncer change le monde. —
	"sera_intro": {
		"speaker": "Sera, l'étrangère",
		"text": "Toi non plus, t'es pas d'ici, pas vrai ?... Bon. Je me cache : les rôdeurs du bois étaient mes frères de route, avant que je déserte. Si le hameau l'apprend, on me chassera. Tu vas leur dire ?",
		"choices": [
			{"label": "« Ton secret est en sécurité. »", "set": {"sera_proche": true}, "next": "sera_confiance"},
			{"label": "« Ces gens méritent la vérité. »", "set": {"sera_denoncee": true}, "next": "sera_chassee"},
			{"label": "(Ne rien promettre et partir)"},
		]},
	"sera_confiance": {
		"speaker": "Sera, l'étrangère",
		"text": "Alors tiens, un conseil de déserteuse : les rôdeurs paniquent quand leur meneur tombe en premier. Et... merci. Je ne l'oublierai pas.",
		"choices": [{"label": "(Partir)"}]},
	"sera_chassee": {
		"speaker": "Sera, l'étrangère",
		"text": "...Je vois. J'aurai quitté le hameau avant la nuit. J'espère que tu sauras vivre avec ce choix — le bois, lui, s'en souviendra.",
		"choices": [{"label": "(La regarder partir)"}]},
	"sera_revoit": {
		"speaker": "Sera, l'étrangère",
		"text": "Toujours muette, ma langue. Toi, tâche de rester vivant : le meneur d'abord, souviens-toi. ...À moins que tu cherches une lame de plus ?",
		"choices": [
			{"label": "« Voyage avec moi, Sera. »", "set": {"sera_party": true},
			 "recruit": "sera", "next": "sera_join"},
			{"label": "« Compris. »"},
		]},
	"sera_join": {
		"speaker": "Sera, l'étrangère",
		"text": "Alors c'est dit. Je connais ce bois mieux que ses loups — je couvre tes arrières, toi ouvre la route. Et au fond du bois... tu verras pourquoi j'ai déserté.",
		"choices": [{"label": "(En route)"}]},

	# === Dialogues de COMPAGNONS (voyage) — relations à conséquences ===
	# Sera : pragmatique, loyale si on la respecte.
	"sera_talk_intro": {
		"speaker": "Sera",
		"text": "Marcher à découvert, encore ? Tu as de la chance que je veille. ...Pourquoi tu m'as fait confiance, au juste, alors que tout le hameau me croyait dangereuse ?",
		"choices": [
			{"label": "« Je juge les gens sur leurs actes. »", "set": {"met_sera": true}, "relation": {"sera": 1}},
			{"label": "« J'avais besoin d'une lame de plus. »", "set": {"met_sera": true}},
			{"label": "« Tais-toi et avance. »", "set": {"met_sera": true}, "relation": {"sera": -1}},
		]},
	"sera_talk_idle": {
		"speaker": "Sera",
		"text": "Le meneur d'abord, toujours. Coupe la tête, la meute panique. C'est comme ça qu'on survit, dans le bois.",
		"choices": [
			{"label": "« Bon conseil. »", "relation": {"sera": 1}},
			{"label": "(Hocher la tête et repartir)"},
		]},
	"sera_talk_loyal": {
		"speaker": "Sera",
		"text": "Tu sais quoi ? Je ne regrette pas d'avoir déserté. Pas si c'était pour finir à tes côtés. Où qu'on aille après ce bois — j'y suis.",
		"choices": [{"label": "« Côte à côte. »"}]},
	# Le SECRET de la zone 1 : protéger Sera réveille son chasseur (boss secret).
	"sera_roi_alerte": {
		"speaker": "Sera",
		"text": "...Il faut que je te dise. Les loups que nous avons abattus — c'étaient ses éclaireurs. Le Traqueur-Roi. Le maître des rôdeurs. C'est lui que je fuis depuis le début. Il m'a retrouvée, je le SENS. Si on ne le chasse pas d'abord, il nous chassera, toi et moi.",
		"choices": [
			{"label": "« Alors chassons le chasseur. »",
			 "set": {"roi_actif": true}, "relation": {"sera": 1}, "next": "sera_roi_go"},
			{"label": "« On n'est pas prêts. Pas encore. »", "set": {"roi_repousse": true}},
		]},
	"sera_roi_go": {
		"speaker": "Sera",
		"text": "Au nord du bois, là où je me cachais. Il y plantera son camp pour me débusquer. Prépare l'équipe — lui, il ne pardonne RIEN.",
		"choices": [{"label": "(En route)"}]},
	"sera_about_garin": {
		"speaker": "Sera",
		"text": "Ton bûcheron me regarde comme si j'allais l'égorger dans son sommeil. Il n'a pas tort de se méfier... mais dis-lui que s'il me cherche, il me trouvera. Ou pas — à toi de voir.",
		"choices": [
			{"label": "« Laissez-vous une chance, tous les deux. »",
			 "set": {"sera_garin_ok": true}, "relation": {"sera": 1}},
			{"label": "« Reste sur tes gardes, c'est tout. »", "set": {"sera_garin_ok": true}},
		]},
	# Garin : honorable, méfiant de l'ex-rôdeuse, mais juste.
	"garin_talk_intro": {
		"speaker": "Garin",
		"text": "Ha ! Ça fait du bien de cogner autre chose que du bois mort. Tu mènes, je suis. Mais dis-moi — on va jusqu'où, dans ce fichu bois ?",
		"choices": [
			{"label": "« Jusqu'à faire taire le Veilleur. »", "set": {"met_garin": true}, "relation": {"garin": 1}},
			{"label": "« Aussi loin qu'il faudra. »", "set": {"met_garin": true}},
		]},
	"garin_talk_idle": {
		"speaker": "Garin",
		"text": "Devant moi, personne passe. Tu places les fragiles derrière ma lance, et on rentrera tous entiers. Marché ?",
		"choices": [
			{"label": "« Marché. »", "relation": {"garin": 1}},
			{"label": "(Repartir)"},
		]},
	"garin_talk_loyal": {
		"speaker": "Garin",
		"text": "J'ai bûcheronné vingt ans sans rien voir du monde. Avec toi, j'ai enfin l'impression de servir à quelque chose de plus grand qu'une pile de rondins.",
		"choices": [{"label": "« Tu sers, Garin. Crois-moi. »"}]},
	# === Joran, le mire déserteur : la confiance se GAGNE (relation_min). ===
	"joran_intro": {
		"speaker": "Joran, le mire",
		"text": "Pas un pas de plus. ...Tu n'es pas de la garde, toi. Tant mieux. J'étais leur mire — je recousais leurs soldats. J'ai déserté le jour où on m'a ordonné de laisser mourir les blessés « inutiles ». Alors ? Tu me dénonces, ou tu passes ton chemin ?",
		"choices": [
			{"label": "« Soigner, ce n'est jamais déserter. »",
			 "set": {"joran_1_fait": true}, "relation": {"joran": 1}},
			{"label": "« Tes histoires ne me regardent pas. »", "set": {"joran_1_fait": true}},
			{"label": "« Un déserteur reste un lâche. »",
			 "set": {"joran_1_fait": true}, "relation": {"joran": -1}},
		]},
	"joran_2": {
		"speaker": "Joran, le mire",
		"text": "Encore toi. ...J'ai vu tes traces : tu te bats dans le bois, hein ? Montre-moi tes mains. Tu serres trop ton arme — tu finiras par te blesser bêtement. Pourquoi tu te bats, au juste ?",
		"choices": [
			{"label": "« Pour protéger ceux du hameau. »",
			 "set": {"joran_2_fait": true}, "relation": {"joran": 1}},
			{"label": "« Parce qu'il le faut bien. »", "set": {"joran_2_fait": true}},
			{"label": "« Pour le butin. Ça te pose un souci ? »",
			 "set": {"joran_2_fait": true}, "relation": {"joran": -1}},
		]},
	"joran_bond_dlg": {
		"speaker": "Joran, le mire",
		"text": "Tu reviens toujours... Bon. Une gorgée de tisane ? C'est la recette de ma compagnie. Les soirs de bataille, on la buvait en silence, en comptant ceux qui manquaient.",
		"choices": [
			{"label": "« À ceux qui manquent. » (boire avec lui)",
			 "set": {"joran_bond": true}, "relation": {"joran": 1}},
			{"label": "« Pas le temps pour ça. »", "set": {"joran_bond": true}},
		]},
	"joran_mefiant": {
		"speaker": "Joran, le mire",
		"text": "Je vois clair dans ton regard — le même que mes anciens capitaines. Je ne marcherai pas avec quelqu'un comme toi. Va-t'en.",
		"choices": [{"label": "(Partir)"}]},
	"joran_offre": {
		"speaker": "Joran, le mire",
		"text": "Tu sais... je n'ai plus recousu personne depuis des mois. Mes mains tremblent moins quand tu parles. Si tu retournes dans ce bois — emmène-moi. Un mire, ça se rend utile.",
		"choices": [
			{"label": "« Voyage avec nous, Joran. »",
			 "set": {"joran_party": true}, "recruit": "joran", "next": "joran_join"},
			{"label": "« Pas encore. Bientôt. »"},
		]},
	"joran_join": {
		"speaker": "Joran, le mire",
		"text": "Alors c'est reparti. Une dernière chose : je recouds TOUT LE MONDE. Même ceux que tu n'aimes pas. C'est ma seule règle.",
		"choices": [{"label": "(En route)"}]},
	# === Feu de camp : repos, sauvegarde, le bois se repeuple (hors boss). ===
	"feu_repos": {
		"speaker": "Feu de camp",
		"text": "Le feu crépite doucement. Un vrai repos effacerait la fatigue... mais le bois, lui, ne dort jamais : ses créatures reviendront.",
		"choices": [
			{"label": "🔥 Se reposer (sauvegarde — les créatures reviennent)", "campfire": true},
			{"label": "(Repartir)"},
		]},
	"garin_about_sera": {
		"speaker": "Garin",
		"text": "Cette Sera... une rôdeuse, hier encore. Et tu la laisses marcher dans notre dos avec un arc ? J'aime pas ça du tout.",
		"choices": [
			{"label": "« Elle s'est rangée. Donne-lui sa chance. »",
			 "set": {"garin_sera_ok": true}, "relation": {"garin": 1, "sera": 1}},
			{"label": "« Surveille-la si tu veux. »", "set": {"garin_sera_ok": true}},
			{"label": "« Je n'ai pas à me justifier. »",
			 "set": {"garin_sera_ok": true}, "relation": {"garin": -1}},
		]},
}

# Damier de sol 2 tons par type de terrain (style diorama du jeu).
const GROUND_COLORS := {
	"herbe":   [Color(0.318, 0.420, 0.235), Color(0.270, 0.368, 0.200)],
	"bois":    [Color(0.196, 0.286, 0.170), Color(0.160, 0.244, 0.142)],
	"chemin":  [Color(0.478, 0.398, 0.262), Color(0.430, 0.356, 0.232)],
	"village": [Color(0.420, 0.366, 0.270), Color(0.376, 0.326, 0.238)],
	"eau":     [Color(0.180, 0.300, 0.420), Color(0.150, 0.265, 0.385)],
}
const COLOR_WALL_L := Color(0.184, 0.130, 0.092)
const COLOR_WALL_R := Color(0.262, 0.188, 0.130)
const COLOR_SEAM := Color(0.0, 0.0, 0.0, 0.14)

var _ground := {}   # Vector2i -> type de sol (clé de GROUND_COLORS)
var _blocked := {}  # Vector2i -> true (obstacle : arbre, maison, eau, bord...)
var _foe_spawns: Array = []  # construits par _build_world (positions calculées)
var _rng := RandomNumberGenerator.new()

var _entities: Node2D
var _camera: Camera2D
var _player: Walker
var _foes: Array = []
var _npcs: Array = []
var _party: Array = []  # Walkers des compagnons (suivent le héros en file)
var _decor_nodes: Array = []  # tous les décors (pour le culling à l'écran)
var _chunks: Array = []       # blocs de sol statiques (culling par visibilité)
var _cull_t := 0.0            # prochain rafraîchissement du culling (périodique)
var _fade: ColorRect
var _zone_label: Label
var _zone_current := ""
var _locked := false  # vrai pendant la transition vers le combat
var _grace := 1.5     # délai sans contact au retour de combat (anti re-déclenchement)
# Dialogue en cours (le monde est en pause pendant qu'on parle).
const TALK_RANGE := 1.6
var _talking := false
var _dlg_npc: Walker = null
var _dlg_panel: PanelContainer
var _dlg_speaker: Label
var _dlg_text: Label
var _dlg_choices: VBoxContainer
# Fiche de personnage (touche C) : panneau construit une fois, rempli à
# l'ouverture seulement (règle perf : rien par image quand c'est fermé).
var _sheet_open := false
var _sheet_panel: PanelContainer
var _sheet_box: HBoxContainer  # colonnes côte à côte (façon BG3 : 1 par perso)
var _sheet_quests: Label       # journal des quêtes en cours (bas de la fiche)
# Montées de niveau (après victoire) : file de choix bonus/compétence par membre.
var _leveling := false
var _lvl_queue: Array = []
var _lvl_panel: PanelContainer
var _lvl_title: Label
var _lvl_sub: Label
var _lvl_choices: VBoxContainer


func _ready() -> void:
	# Sauvegarde d'avant la création de personnage : on crée le héros d'abord.
	if GameData.campaign_hero.is_empty():
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().change_scene_to_file.call_deferred("res://CharacterCreate.tscn")
		return
	_build_world()
	_build_nodes()
	_build_ui()
	Audio.play_music("menu")
	queue_redraw()
	# Fondu d'arrivée dans le monde.
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.7)
	# Montées de niveau gagnées au dernier combat : on choisit maintenant.
	_check_levelups()


# --- Génération du monde (déterministe : le même à chaque visite) ---

# Le sentier qui serpente du hameau vers l'est du bois.
func _path_y(x: float) -> float:
	return 9.0 + (x - 11.0) * 0.52 + sin(x * 0.55) * 1.6


func _build_world() -> void:
	_rng.seed = WORLD_SEED
	# Sol de base : prairie à l'ouest, bois sombre à l'est.
	for y in MAP_H:
		for x in MAP_W:
			_ground[Vector2i(x, y)] = "bois" if x >= FOREST_X else "herbe"
	# Place de terre battue du hameau.
	for y in range(4, 14):
		for x in range(4, 14):
			_ground[Vector2i(x, y)] = "village"
	# Sentier (2 tuiles de large).
	for x in range(11, MAP_W - 1):
		var yf := _path_y(float(x))
		for dy in [0, 1]:
			var c := Vector2i(x, int(floor(yf)) + dy)
			if c.y >= 1 and c.y < MAP_H - 1:
				_ground[c] = "chemin"
	# Étang (infranchissable).
	for y in MAP_H:
		for x in MAP_W:
			var dx := (float(x) - 17.0) / 3.4
			var dyy := (float(y) - 22.0) / 2.2
			if dx * dx + dyy * dyy <= 1.0:
				var c := Vector2i(x, y)
				_ground[c] = "eau"
				_blocked[c] = true
	# Bord de la maquette : infranchissable (le monde « flotte »).
	for y in MAP_H:
		for x in MAP_W:
			if x == 0 or y == 0 or x == MAP_W - 1 or y == MAP_H - 1:
				_blocked[Vector2i(x, y)] = true
	# Maisons du hameau (2×2 tuiles bloquées chacune).
	for h in [Vector2i(5, 5), Vector2i(10, 5), Vector2i(5, 10)]:
		for dy in 2:
			for dx in 2:
				_blocked[h + Vector2i(dx, dy)] = true
	# Positions des ennemis (le long du sentier, dans le bois). On garde TOUTES
	# les définitions (le filtre need_flag/vaincu se fait au spawn : permet de
	# faire apparaître un ennemi conditionnel EN COURS de partie, ex. boss secret).
	_foe_spawns.clear()
	for f in FOES:
		var pos := Vector2(f.px + 0.5, _path_y(f.px) + f.dy)
		_foe_spawns.append({"id": f.id, "name": f.name, "tier": f.tier,
				"team": f.team, "hue": f.hue, "pos": pos,
				"fixed": f.get("fixed", false), "boss": f.get("boss", false),
				"wkind": f.get("wkind", ""), "need_flag": f.get("need_flag", "")})
	# Sapins du bois (clairières autour des ennemis/PNJ + couloir du sentier).
	# 90 essais (et pas plus) : le bois reste dense mais le navigateur respire.
	for i in 90:
		var x := _rng.randi_range(FOREST_X, MAP_W - 2)
		var y := _rng.randi_range(1, MAP_H - 2)
		var c := Vector2i(x, y)
		if _blocked.has(c) or _ground[c] == "chemin":
			continue
		if absf(float(y) + 0.5 - _path_y(float(x))) < 2.4:
			continue
		var near_foe := false
		for fs in _foe_spawns:
			if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(fs.pos) < 3.0:
				near_foe = true
				break
		if near_foe or _near_npc(float(x) + 0.5, float(y) + 0.5):
			continue
		_blocked[c] = true
		_decor_at("fir", c)
	# Chênes de la prairie (jamais sur le chemin, le hameau, l'eau, les PNJ).
	for i in 48:
		var x := _rng.randi_range(2, FOREST_X - 1)
		var y := _rng.randi_range(2, MAP_H - 3)
		var c := Vector2i(x, y)
		if _blocked.has(c) or _ground[c] != "herbe":
			continue
		if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(SPAWN) < 3.0:
			continue
		if _near_npc(float(x) + 0.5, float(y) + 0.5):
			continue
		_blocked[c] = true
		_decor_at("tree", c)
	# Quelques rochers.
	for i in 14:
		var x := _rng.randi_range(2, MAP_W - 3)
		var y := _rng.randi_range(2, MAP_H - 3)
		var c := Vector2i(x, y)
		if _blocked.has(c) or _ground[c] != "herbe" and _ground[c] != "bois":
			continue
		_blocked[c] = true
		_decor_at("rock", c)
	# Roseaux au bord de l'étang (décoratifs, traversables).
	for y in MAP_H:
		for x in MAP_W:
			var c := Vector2i(x, y)
			if _ground[c] == "eau":
				continue
			var shore := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _ground.get(c + d, "") == "eau":
					shore = true
					break
			if shore and _rng.randf() < 0.35 and not _blocked.has(c):
				_decor_at("reed", c)


# Les décors sont mémorisés ici puis instanciés dans _build_nodes (tri en Y).
var _decor_list: Array = []
func _decor_at(kind: String, cell: Vector2i) -> void:
	_decor_list.append({"kind": kind, "pos": Vector2(cell) + Vector2(0.5, 0.62),
			"seed": _rng.randf(), "scale": _rng.randf_range(0.88, 1.14)})


func _build_nodes() -> void:
	# Sol : blocs statiques (dessinés une fois, cache GPU). Ajoutés AVANT les
	# entités pour rester sous les personnages et décors.
	for cy in range(0, MAP_H, CHUNK):
		for cx in range(0, MAP_W, CHUNK):
			var ch := GroundChunk.new()
			ch.ow = self
			ch.x0 = cx
			ch.y0 = cy
			ch.x1 = mini(cx + CHUNK, MAP_W)
			ch.y1 = mini(cy + CHUNK, MAP_H)
			var left: float = map_to_world(Vector2(ch.x0 + 0.5, ch.y1 - 0.5)).x - HALF_W
			var right: float = map_to_world(Vector2(ch.x1 - 0.5, ch.y0 + 0.5)).x + HALF_W
			var top: float = map_to_world(Vector2(ch.x0 + 0.5, ch.y0 + 0.5)).y - HALF_H
			var bottom: float = map_to_world(Vector2(ch.x1 - 0.5, ch.y1 - 0.5)).y + HALF_H
			ch.rect = Rect2(left, top, right - left, bottom - top)
			add_child(ch)
			_chunks.append(ch)
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)
	# Décors (chacun trié en profondeur avec les personnages).
	for d in _decor_list:
		var n := Decor.new()
		n.kind = d.kind
		n.seed_v = d.seed
		n.scale = Vector2(d.scale, d.scale)
		n.position = map_to_world(d.pos)
		_entities.add_child(n)
		_decor_nodes.append(n)
	# Maisons (décor dessiné, posé au coin sud du bloc 2×2).
	for h in [Vector2i(5, 5), Vector2i(10, 5), Vector2i(5, 10)]:
		var n := Decor.new()
		n.kind = "house"
		n.seed_v = float(h.x) * 0.17
		n.position = map_to_world(Vector2(h) + Vector2(1.0, 1.9))
		_entities.add_child(n)
		_decor_nodes.append(n)
	# Joueur (reprend la position sauvegardée si elle est valide).
	_player = Walker.new()
	_player.kind = "player"
	var start := SPAWN
	var saved: Vector2 = GameData.campaign_pos
	if saved.x >= 0.0 and _free(saved):
		start = saved
	_player.mpos = start
	_entities.add_child(_player)
	# Ennemis encore en vie (les vaincus ont disparu — sauf retour par feu de camp).
	for fs in _foe_spawns:
		if GameData.campaign_defeated.has(fs.id):
			continue
		if str(fs.need_flag) != "" and not GameData.get_flag(str(fs.need_flag)):
			continue
		_spawn_foe(fs)
	# Compagnons recrutés : ils marchent derrière le héros (file de voyage).
	var fi := 1
	for comp_id in GameData.campaign_party:
		_spawn_follower(str(comp_id), _player.mpos + Vector2(-0.7, 0.5) * float(fi))
		fi += 1
	# PNJ du hameau (sauf ceux partis ou recrutés suite à un choix).
	for n in NPCS:
		if n.has("hide_flag") and GameData.get_flag(n.hide_flag):
			continue
		if n.has("party_flag") and GameData.get_flag(n.party_flag):
			continue
		if n.has("need_flag") and not GameData.get_flag(n.need_flag):
			continue
		_spawn_npc(n)
	# Caméra qui suit le joueur, bornée à la maquette.
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.limit_left = int(map_to_world(Vector2(0, MAP_H)).x) - 60
	_camera.limit_right = int(map_to_world(Vector2(MAP_W, 0)).x) + 60
	_camera.limit_top = int(map_to_world(Vector2(0, 0)).y) - 120
	_camera.limit_bottom = int(map_to_world(Vector2(MAP_W, MAP_H)).y + EDGE_DEPTH) + 80
	_camera.position = map_to_world(_player.mpos)
	_camera.reset_smoothing()
	add_child(_camera)
	_camera.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_zone_label = Label.new()
	_zone_label.position = Vector2(0, 16)
	_zone_label.custom_minimum_size = Vector2(832, 34)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.add_theme_font_size_override("font_size", 26)
	_zone_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_zone_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_zone_label)
	var hint := Label.new()
	hint.text = "ZQSD : se déplacer   ·   E : parler   ·   C : équipe   ·   Échap : menu"
	hint.position = Vector2(12, 704 - 30)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.8))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 4)
	layer.add_child(hint)
	# Boîte de dialogue (cachée par défaut) : nom du PNJ, texte, choix cliquables.
	_dlg_panel = PanelContainer.new()
	_dlg_panel.position = Vector2(56, 440)
	_dlg_panel.custom_minimum_size = Vector2(720, 0)
	_dlg_panel.visible = false
	layer.add_child(_dlg_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_dlg_panel.add_child(vb)
	_dlg_speaker = Label.new()
	_dlg_speaker.add_theme_font_size_override("font_size", 20)
	_dlg_speaker.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	vb.add_child(_dlg_speaker)
	_dlg_text = Label.new()
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(700, 0)
	_dlg_text.add_theme_font_size_override("font_size", 17)
	_dlg_text.add_theme_color_override("font_color", Color(0.92, 0.90, 0.84))
	vb.add_child(_dlg_text)
	_dlg_choices = VBoxContainer.new()
	_dlg_choices.add_theme_constant_override("separation", 4)
	vb.add_child(_dlg_choices)

	# Fiche d'équipe façon BG3 (cachée, remplie à l'ouverture) : une colonne par
	# personnage — portrait dessiné, stats, compétences et sacoche.
	_sheet_panel = PanelContainer.new()
	_sheet_panel.position = Vector2(8, 64)
	_sheet_panel.custom_minimum_size = Vector2(816, 0)
	_sheet_panel.visible = false
	layer.add_child(_sheet_panel)
	var sheet_root := VBoxContainer.new()
	sheet_root.add_theme_constant_override("separation", 8)
	_sheet_panel.add_child(sheet_root)
	var sheet_title := Label.new()
	sheet_title.text = "⚔  ÉQUIPE        (C ou Échap pour fermer)"
	sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet_title.add_theme_font_size_override("font_size", 19)
	sheet_title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.66))
	sheet_root.add_child(sheet_title)
	_sheet_box = HBoxContainer.new()
	_sheet_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_sheet_box.add_theme_constant_override("separation", 10)
	sheet_root.add_child(_sheet_box)
	_sheet_quests = Label.new()
	_sheet_quests.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet_quests.add_theme_font_size_override("font_size", 13)
	_sheet_quests.add_theme_color_override("font_color", Color(0.82, 0.76, 0.58))
	sheet_root.add_child(_sheet_quests)

	# Panneau de montée de niveau (après victoire) : un choix à la fois.
	_lvl_panel = PanelContainer.new()
	_lvl_panel.position = Vector2(166, 180)
	_lvl_panel.custom_minimum_size = Vector2(500, 0)
	_lvl_panel.visible = false
	layer.add_child(_lvl_panel)
	var lvl_box := VBoxContainer.new()
	lvl_box.add_theme_constant_override("separation", 8)
	_lvl_panel.add_child(lvl_box)
	_lvl_title = Label.new()
	_lvl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lvl_title.add_theme_font_size_override("font_size", 22)
	_lvl_title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.40))
	lvl_box.add_child(_lvl_title)
	_lvl_sub = Label.new()
	_lvl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lvl_sub.add_theme_font_size_override("font_size", 15)
	_lvl_sub.add_theme_color_override("font_color", Color(0.82, 0.80, 0.74))
	lvl_box.add_child(_lvl_sub)
	_lvl_choices = VBoxContainer.new()
	_lvl_choices.add_theme_constant_override("separation", 6)
	lvl_box.add_child(_lvl_choices)

	_fade = ColorRect.new()
	_fade.position = Vector2.ZERO
	_fade.size = Vector2(832, 704)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


# --- Boucle : entrées, ennemis, caméra ---

func _process(delta: float) -> void:
	if _grace > 0.0:
		_grace -= delta
	if not _locked and not _talking and not _sheet_open and not _leveling:
		_move_player(delta)
		_update_foes(delta)
		_update_npcs()
		_update_party(delta)
	_place(_player)
	for f in _foes:
		_place(f)
	for w in _party:
		_place(w)
	_camera.position = _player.position - Vector2(0.0, 14.0)
	_update_zone()
	# Culling périodique (8×/s suffit largement avec la marge de VIEW_HALF) :
	# blocs de sol, décors et personnages hors écran sont masqués.
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.12
		_refresh_culling()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or _locked:
		return
	if event.keycode == KEY_ESCAPE:
		if _talking:
			_close_dialogue()
			return
		if _sheet_open:
			_close_sheet()
			return
		GameData.campaign_pos = _player.mpos
		GameData.save_campaign()
		get_tree().change_scene_to_file("res://Title.tscn")
	# E : parler au PNJ OU compagnon à portée (les choix se font à la souris).
	if event.physical_keycode == KEY_E and not _talking and not _sheet_open and not _leveling:
		var npc := _nearest_talkable()
		if npc:
			_open_dialogue(npc)
	# C : fiche d'équipe (héros + compagnons), monde en pause pendant la lecture.
	if event.physical_keycode == KEY_C and not _talking and not _leveling:
		if _sheet_open:
			_close_sheet()
		else:
			_open_sheet()


# PNJ : immobiles, mais se tournent vers le joueur proche (et affichent l'invite).
func _update_npcs() -> void:
	for n in _npcs:
		var dist: float = n.mpos.distance_to(_player.mpos)
		n.show_label = dist < 4.0
		n.prompt = dist < TALK_RANGE
		if dist < 4.0:
			var wx := map_to_world(_player.mpos).x - map_to_world(n.mpos).x
			if absf(wx) > 4.0:
				n.face = 1.0 if wx > 0.0 else -1.0


# Compagnons : marche en file derrière le héros (chacun suit le précédent).
func _update_party(delta: float) -> void:
	var prev: Vector2 = _player.mpos
	for w in _party:
		var d: float = w.mpos.distance_to(prev)
		if d > 0.95:
			var step: float = minf(PLAYER_SPEED * 1.08 * delta, d - 0.85)
			w.mpos += (prev - w.mpos).normalized() * step
			w.moving = true
			var wx := map_to_world(prev).x - map_to_world(w.mpos).x
			if absf(wx) > 0.5:
				w.face = 1.0 if wx > 0.0 else -1.0
		else:
			w.moving = false
		# Invite « parler » sur le compagnon proche, seulement quand on est arrêté.
		w.prompt = (not _player.moving) and w.mpos.distance_to(_player.mpos) < TALK_RANGE + 0.4
		prev = w.mpos


func _spawn_follower(comp_id: String, pos: Vector2) -> void:
	var c: Dictionary = GameData.COMPANIONS.get(comp_id, {})
	if c.is_empty():
		return
	var w := Walker.new()
	w.kind = "ally"
	w.npc_id = comp_id  # permet de leur parler (E) et de retrouver leur relation
	w.figure = str(c.figure)
	w.label = str(c.name)
	w.mpos = pos
	w.position = map_to_world(pos)
	_entities.add_child(w)
	_party.append(w)


# Cherche le PNJ OU le compagnon le plus proche à portée de parole.
func _nearest_talkable() -> Walker:
	var best: Walker = null
	var best_d := TALK_RANGE
	for n in _npcs:
		var d: float = n.mpos.distance_to(_player.mpos)
		if d < best_d:
			best_d = d
			best = n
	for w in _party:
		var d: float = w.mpos.distance_to(_player.mpos)
		if d < best_d:
			best_d = d
			best = w
	return best


func _nearest_npc() -> Walker:
	var best: Walker = null
	var best_d := TALK_RANGE
	for n in _npcs:
		var d: float = n.mpos.distance_to(_player.mpos)
		if d < best_d:
			best_d = d
			best = n
	return best


# --- Dialogues à choix (data-driven : NPCS + DIALOGUES) ---

# Choisit le dialogue d'entrée d'un PNJ : première règle satisfaite, sinon fallback.
# Règle = drapeau requis ("flag"), drapeau interdit ("not_flag") et/ou ennemis
# vaincus requis ("foes_down") — tous optionnels, combinables.
func _npc_entry_dialogue(npc_id: String) -> String:
	for n in NPCS:
		if n.id != npc_id:
			continue
		for r in n.get("rules", []):
			if r.has("flag") and not GameData.get_flag(r.flag):
				continue
			if r.has("not_flag") and GameData.get_flag(r.not_flag):
				continue
			var ok := true
			for foe_id in r.get("foes_down", []):
				if not GameData.campaign_defeated.has(foe_id):
					ok = false
					break
			# Seuil de relation ("relation_min") : un compagnon ne s'ouvre (ou ne
			# rejoint) que si l'affinité construite en discutant est suffisante.
			for rel_id in r.get("relation_min", {}):
				if GameData.relation(str(rel_id)) < int(r.relation_min[rel_id]):
					ok = false
					break
			if ok:
				return r.dialogue
		return n.fallback
	return ""


func _open_dialogue(npc: Walker) -> void:
	# Compagnon (suiveur) : dialogue de voyage selon sa relation. PNJ : règles.
	var did := _companion_dialogue(npc.npc_id) if npc.kind == "ally" \
			else _npc_entry_dialogue(npc.npc_id)
	if did == "" or not DIALOGUES.has(did):
		return
	_talking = true
	_dlg_npc = npc
	_player.moving = false
	Audio.play_sfx("click")
	_show_dialogue(did)


# Dialogue de voyage d'un compagnon : le SECRET d'abord (Sera révèle son
# chasseur), puis un mot croisé sur l'autre membre (relations), puis selon
# l'affinité, sinon l'intro (vu une fois).
func _companion_dialogue(cid: String) -> String:
	# Secret de la zone 1 : la meute abattue = les éclaireurs du Traqueur-Roi.
	if cid == "sera" and not GameData.get_flag("roi_actif") \
			and GameData.campaign_defeated.has("meute_murmures") \
			and not GameData.campaign_defeated.has("traqueur_roi"):
		return "sera_roi_alerte"
	# Garin se méfie de Sera (ex-rôdeuse) tant qu'elle ne s'est pas prouvée.
	if cid == "garin" and GameData.campaign_party.has("sera") \
			and not GameData.get_flag("garin_sera_ok"):
		return "garin_about_sera"
	if cid == "sera" and GameData.campaign_party.has("garin") \
			and not GameData.get_flag("sera_garin_ok"):
		return "sera_about_garin"
	if not GameData.get_flag("met_" + cid):
		return cid + "_talk_intro"
	if GameData.relation(cid) >= 3:
		return cid + "_talk_loyal"
	return cid + "_talk_idle"


func _show_dialogue(did: String) -> void:
	var d: Dictionary = DIALOGUES[did]
	_dlg_speaker.text = str(d.speaker)
	_dlg_text.text = str(d.text)
	for c in _dlg_choices.get_children():
		c.queue_free()
	for choice in d.choices:
		var b := Button.new()
		b.text = str(choice.label)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 34)
		var ch: Dictionary = choice
		b.pressed.connect(func(): _on_choice(ch))
		_dlg_choices.add_child(b)
	_dlg_panel.visible = true


func _on_choice(choice: Dictionary) -> void:
	Audio.play_sfx("click")
	var changed := false
	for key in choice.get("set", {}):
		GameData.set_flag(key, bool(choice.set[key]))
		changed = true
	# Récompense : déblocage d'une classe par l'exploration (vision du jeu).
	var cid: String = str(choice.get("unlock", ""))
	if cid != "" and not GameData.is_unlocked(cid):
		GameData.unlocked.append(cid)
		changed = true
		_announce("⚔ Classe débloquée : %s !" % str(GameData.CLASSES[cid].name))
	# Recrutement : le PNJ rejoint l'équipe (il suivra le héros dans le monde).
	var rid: String = str(choice.get("recruit", ""))
	if rid != "" and not GameData.campaign_party.has(rid):
		GameData.campaign_party.append(rid)
		# Affinité de départ : Sera reconnaissante (couverte), Garin loyal (quête).
		GameData.add_relation(rid, 2)
		changed = true
		_announce("🤝 %s rejoint l'équipe !" % str(GameData.COMPANIONS[rid].name))
	# Relations : un choix peut plaire ou déplaire à un compagnon.
	for rel_id in choice.get("relation", {}):
		GameData.add_relation(str(rel_id), int(choice.relation[rel_id]))
		changed = true
	# Objet de quête : entre dans la sacoche (ou en sort si on le rend).
	var item: String = str(choice.get("item", ""))
	if item != "" and not GameData.campaign_items.has(item):
		GameData.campaign_items.append(item)
		changed = true
		_announce("Objet récupéré : %s" % item)
	var rem: String = str(choice.get("remove_item", ""))
	if rem != "":
		GameData.campaign_items.erase(rem)
		changed = true
	# Feu de camp : repos -> sauvegarde, les créatures (hors boss) reviennent.
	if choice.get("campfire", false):
		var keep: Array = []
		for fid in GameData.campaign_defeated:
			if _foe_is_boss(str(fid)):
				keep.append(fid)
		GameData.campaign_defeated = keep
		GameData.campaign_pos = _player.mpos
		GameData.save_campaign()
		Audio.play_sfx("heal")
		# Recharge le monde : les rôdeurs réapparaissent pendant le repos.
		get_tree().change_scene_to_file.call_deferred("res://Overworld.tscn")
		return
	# Récompense d'XP pour toute l'équipe (quêtes de PNJ).
	var xp: int = int(choice.get("xp_team", 0))
	if xp > 0:
		GameData.grant_xp("hero", xp)
		for comp_id in GameData.campaign_party:
			GameData.grant_xp(str(comp_id), xp)
		changed = true
		_announce("★ +%d XP pour l'équipe !" % xp)
	if changed:
		GameData.campaign_pos = _player.mpos
		GameData.save_campaign()
	if choice.has("next"):
		_show_dialogue(str(choice.next))
	else:
		_close_dialogue()


func _close_dialogue() -> void:
	_dlg_panel.visible = false
	_talking = false
	# Un choix peut chasser le PNJ du monde (Sera dénoncée) ou le recruter
	# (il devient un compagnon qui suit le héros).
	if _dlg_npc:
		for n in NPCS:
			if n.id != _dlg_npc.npc_id:
				continue
			if n.has("party_flag") and GameData.get_flag(n.party_flag):
				_npcs.erase(_dlg_npc)
				_spawn_follower(str(_dlg_npc.npc_id), _dlg_npc.mpos)
				_dlg_npc.queue_free()
			elif n.has("hide_flag") and GameData.get_flag(n.hide_flag):
				_npcs.erase(_dlg_npc)
				var leaving: Walker = _dlg_npc
				var tw := create_tween()
				tw.tween_property(leaving, "modulate:a", 0.0, 1.2)
				tw.tween_callback(leaving.queue_free)
	_dlg_npc = null
	# BUG corrigé : un PNJ-objet conditionnel (sachet...) doit apparaître DÈS que
	# son drapeau est posé, pas au prochain chargement du monde.
	for n in NPCS:
		if not n.has("need_flag") or not GameData.get_flag(n.need_flag):
			continue
		if n.has("hide_flag") and GameData.get_flag(n.hide_flag):
			continue
		var already := false
		for w in _npcs:
			if w.npc_id == n.id:
				already = true
				break
		if not already:
			_spawn_npc(n)
	# Idem pour les ENNEMIS conditionnels (boss secret réveillé par un dialogue).
	for fs in _foe_spawns:
		if str(fs.need_flag) == "" or not GameData.get_flag(str(fs.need_flag)):
			continue
		if GameData.campaign_defeated.has(fs.id):
			continue
		var present := false
		for f in _foes:
			if f.foe_id == fs.id:
				present = true
				break
		if not present:
			_spawn_foe(fs)
			if fs.get("boss", false):
				_announce("☠ Une présence terrible rôde au nord du bois...")
	# Une récompense de quête peut donner des niveaux : on choisit maintenant.
	if not _leveling:
		_check_levelups()


# Instancie un ennemi d'overworld (au chargement OU en cours de partie).
func _spawn_foe(fs: Dictionary) -> void:
	var w := Walker.new()
	w.kind = "foe"
	w.foe_id = fs.id
	w.label = fs.name
	w.tier = fs.tier
	w.team = fs.team
	w.hue = fs.hue
	w.fixed = bool(fs.get("fixed", false))
	w.boss = bool(fs.get("boss", false))
	w.wkind = str(fs.get("wkind", ""))
	w.mpos = fs.pos
	w.position = map_to_world(fs.pos)
	w.home = fs.pos
	w.wander_target = fs.pos
	_entities.add_child(w)
	_foes.append(w)


# Une clairière est gardée autour de chaque PNJ (lisibilité + accès garanti).
func _near_npc(x: float, y: float) -> bool:
	for n in NPCS:
		if Vector2(x, y).distance_to(n.pos) < 2.4:
			return true
	return false


# Un ennemi d'overworld est-il un boss (jamais réinitialisé par les feux de camp) ?
func _foe_is_boss(fid: String) -> bool:
	for f in FOES:
		if f.id == fid:
			return f.get("boss", false)
	return false


# Instancie un PNJ depuis sa définition (utilisé au chargement ET en cours de jeu).
func _spawn_npc(n: Dictionary) -> void:
	var w := Walker.new()
	w.kind = "npc"
	w.npc_id = n.id
	if n.has("prompt"):
		w.prompt_text = str(n.prompt)
	w.figure = n.figure
	w.label = n.name
	w.mpos = n.pos
	w.position = map_to_world(n.pos)
	_entities.add_child(w)
	_npcs.append(w)


# --- Fiche d'équipe (touche C) : héros + compagnons, stats et compétences ---

const ROLE_NAMES := {"tank": "Tank", "melee": "Mêlée", "ranged": "Tireur", "healer": "Soutien"}

func _open_sheet() -> void:
	_sheet_open = true
	_player.moving = false
	Audio.play_sfx("click")
	for c in _sheet_box.get_children():
		c.queue_free()
	_add_sheet_column("hero", str(GameData.campaign_hero.get("name", "Héros")),
			str(GameData.campaign_hero.get("class", "tank")), true, "")
	for comp_id in GameData.campaign_party:
		var c: Dictionary = GameData.COMPANIONS.get(comp_id, {})
		if not c.is_empty():
			_add_sheet_column(str(comp_id), str(c.name), str(c["class"]), false, str(c.figure))
	# Journal des quêtes en cours (drapeaux -> lignes lisibles).
	var quests: Array = []
	if GameData.get_flag("garin_accepte") and not GameData.get_flag("garin_recompense"):
		quests.append("🪓 Garin : chasser le loup et le rôdeur du bois")
	if GameData.get_flag("maud_quete") and not GameData.get_flag("herbes_prises"):
		quests.append("🌿 Maud : retrouver son sachet au bord de l'étang")
	elif GameData.get_flag("herbes_prises") and not GameData.get_flag("herbes_rendues"):
		quests.append("🌿 Rapporter le sachet d'herbes à Maud")
	_sheet_quests.text = "— Quêtes —\n" + "\n".join(quests) if not quests.is_empty() else ""
	_sheet_panel.visible = true


func _close_sheet() -> void:
	_sheet_open = false
	_sheet_panel.visible = false


# --- Montées de niveau (après victoire) ---
# File d'étapes : chaque niveau = un bonus à choisir ; niveau PAIR = en plus,
# 1 compétence parmi 2 dans l'arbre du rôle. Monde en pause pendant les choix.

func _member_display(mid: String) -> String:
	if mid == "hero":
		return str(GameData.campaign_hero.get("name", "Héros"))
	return str(GameData.COMPANIONS.get(mid, {}).get("name", mid))


func _member_role(mid: String) -> String:
	var cid := str(GameData.campaign_hero.get("class", "tank")) if mid == "hero" \
			else str(GameData.COMPANIONS.get(mid, {}).get("class", "tank"))
	return str(GameData.CLASSES.get(cid, {}).get("role", "melee"))


func _check_levelups() -> void:
	_lvl_queue.clear()
	var members: Array = ["hero"]
	for comp_id in GameData.campaign_party:
		members.append(str(comp_id))
	for mid in members:
		var p: Dictionary = GameData.member_progress(str(mid))
		var lvl: int = int(p.level)
		var pend: int = int(p.pending)
		while pend > 0 and lvl < GameData.MAX_LEVEL:
			lvl += 1
			pend -= 1
			_lvl_queue.append({"id": mid, "kind": "bonus", "level": lvl})
			if lvl % 2 == 0:
				_lvl_queue.append({"id": mid, "kind": "skill", "level": lvl,
						"row": lvl / 2 - 1})
	if not _lvl_queue.is_empty():
		_leveling = true
		_show_levelup_step()


func _show_levelup_step() -> void:
	if _lvl_queue.is_empty():
		_leveling = false
		_lvl_panel.visible = false
		GameData.campaign_pos = _player.mpos
		GameData.save_campaign()
		return
	var step: Dictionary = _lvl_queue[0]
	var mid := str(step.id)
	_lvl_title.text = "★  %s passe niveau %d !" % [_member_display(mid), int(step.level)]
	for c in _lvl_choices.get_children():
		c.queue_free()
	if str(step.kind) == "bonus":
		_lvl_sub.text = "Choisis un bonus permanent :"
		for b in GameData.LEVEL_BONUSES:
			var bonus: Dictionary = b
			_lvl_choices.add_child(_lvl_button(str(bonus.label), "", func():
				_apply_bonus_choice(step, bonus)))
	else:
		_lvl_sub.text = "Choisis une NOUVELLE compétence (définitif) :"
		var row: Array = GameData.TREE[_member_role(mid)][int(step.row)]
		for opt in row:
			var skill: Dictionary = opt
			_lvl_choices.add_child(_lvl_button(str(skill.name), str(skill.desc), func():
				_apply_skill_choice(step, skill)))
	_lvl_panel.visible = true


func _lvl_button(title: String, desc: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = title if desc == "" else "%s\n%s" % [title, desc]
	b.custom_minimum_size = Vector2(0, 44 if desc == "" else 58)
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(func():
		Audio.play_sfx("click")
		cb.call())
	return b


func _apply_bonus_choice(step: Dictionary, bonus: Dictionary) -> void:
	var p: Dictionary = GameData.member_progress(str(step.id))
	p.level = int(step.level)
	p.pending = maxi(0, int(p.pending) - 1)
	p.hp_pct = float(p.hp_pct) + float(bonus.get("hp_pct", 0.0))
	p.atk = int(p.atk) + int(bonus.get("atk", 0))
	p.crit = float(p.crit) + float(bonus.get("crit", 0.0))
	GameData.save_campaign()
	_lvl_queue.pop_front()
	_show_levelup_step()


func _apply_skill_choice(step: Dictionary, skill: Dictionary) -> void:
	var p: Dictionary = GameData.member_progress(str(step.id))
	p.skills.append(skill.duplicate())
	GameData.save_campaign()
	_lvl_queue.pop_front()
	_show_levelup_step()


# Une colonne de personnage (façon BG3) : portrait dessiné en grand, identité,
# stats, compétences, et la sacoche (structure de l'inventaire à venir).
func _add_sheet_column(mid: String, member_name: String, cid: String, is_hero: bool, fig: String) -> void:
	var d: Dictionary = GameData.CLASSES.get(cid, {})
	if d.is_empty():
		return
	var p: Dictionary = GameData.member_progress(mid)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(258, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	panel.add_child(col)
	# Portrait : figurine du perso dessinée en grand (statique = zéro coût/image).
	var pb := PortraitBox.new()
	pb.hero = is_hero
	pb.figure = fig
	pb.custom_minimum_size = Vector2(244, 150)
	col.add_child(pb)
	var head := Label.new()
	head.text = "%s%s" % ["★ " if is_hero else "", member_name]
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color",
			Color(0.95, 0.82, 0.45) if is_hero else Color(0.75, 0.88, 0.80))
	col.add_child(head)
	# Affinité du compagnon (relation à conséquences).
	if not is_hero:
		var rel := Label.new()
		rel.text = "♥ %s" % GameData.relation_label(mid)
		rel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rel.add_theme_font_size_override("font_size", 12)
		rel.add_theme_color_override("font_color", Color(0.92, 0.55, 0.62))
		col.add_child(rel)
	var sub := Label.new()
	sub.text = "%s · %s · niveau %d / %d" % [str(d.name),
			str(ROLE_NAMES.get(str(d.get("role", "")), "")),
			int(p.level), GameData.MAX_LEVEL]
	# Barre d'XP vers le prochain niveau (hors combat, comme demandé).
	var xp_bar := ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(200, 12)
	xp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	xp_bar.show_percentage = false
	xp_bar.max_value = GameData.xp_to_next(int(p.level) + int(p.pending))
	xp_bar.value = int(p.xp)
	var xp_lbl := Label.new()
	xp_lbl.text = "XP %d / %d" % [int(p.xp), int(xp_bar.max_value)]
	if int(p.level) + int(p.pending) >= GameData.MAX_LEVEL:
		xp_bar.value = xp_bar.max_value
		xp_lbl.text = "★ NIVEAU MAXIMUM ★"
	else:
		# Affiche clairement quand tombe la prochaine COMPÉTENCE (niveaux pairs).
		var nxt: int = int(p.level) + 2 - (int(p.level) % 2)
		xp_lbl.text += "   ·   ✦ compétence au niv. %d" % nxt
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_lbl.add_theme_font_size_override("font_size", 11)
	xp_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.70, 0.72, 0.68))
	col.add_child(sub)
	col.add_child(xp_bar)
	col.add_child(xp_lbl)
	var stats := Label.new()
	stats.text = "PV %d  ·  ATK %d  ·  Crit %d%%\nPortée %d  ·  Déplacement %d" % [
			int(round(float(d.max_hp) * (1.0 + float(p.hp_pct)))),
			int(d.attack) + int(p.atk),
			int((float(d.crit_chance) + float(p.crit)) * 100.0),
			int(d.attack_range), int(d.move_range)]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78))
	col.add_child(stats)
	var sk_head := Label.new()
	sk_head.text = "— Compétences —"
	sk_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sk_head.add_theme_font_size_override("font_size", 13)
	sk_head.add_theme_color_override("font_color", Color(0.80, 0.65, 0.85))
	col.add_child(sk_head)
	# En campagne, les compétences viennent de l'ARBRE (choisies en montant
	# de niveau) — pas du kit JcJ de la classe.
	if p.skills.is_empty():
		var none := Label.new()
		none.text = "(aucune — gagne des niveaux !)"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50))
		col.add_child(none)
	for a in p.skills:
		var sk := Label.new()
		sk.text = "• " + str(a.name)
		sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sk.add_theme_font_size_override("font_size", 12)
		sk.add_theme_color_override("font_color", Color(0.72, 0.74, 0.70))
		col.add_child(sk)
	# Sacoche : la structure de l'inventaire (les objets viendront plus tard).
	var inv_head := Label.new()
	inv_head.text = "— Sacoche —"
	inv_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_head.add_theme_font_size_override("font_size", 13)
	inv_head.add_theme_color_override("font_color", Color(0.75, 0.70, 0.55))
	col.add_child(inv_head)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 6)
	for i in 4:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(38, 38)
		var dash := Label.new()
		# Les objets de quête (sacoche commune) s'affichent chez le héros.
		dash.text = "·"
		if is_hero and i < GameData.campaign_items.size():
			dash.text = str(GameData.campaign_items[i]).left(2)
			dash.tooltip_text = str(GameData.campaign_items[i])
		dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dash.add_theme_color_override("font_color", Color(0.85, 0.82, 0.70)
				if is_hero and i < GameData.campaign_items.size() else Color(0.45, 0.44, 0.40))
		slot.add_child(dash)
		slots.add_child(slot)
	col.add_child(slots)
	_sheet_box.add_child(panel)


# Portrait d'un personnage (fiche d'équipe) : figurine dessinée en grand, pose
# figée — dessiné UNE fois à l'ouverture, zéro coût par image (règle perf).
class PortraitBox extends Control:
	var hero := false
	var figure := ""

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.09, 0.14))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.32, 0.26), false, 1.5)
		var base := Vector2(size.x / 2.0, size.y - 18.0)
		draw_set_transform(base, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 34.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_set_transform(base, 0.0, Vector2(4.2, 4.2))
		if hero:
			var h: Dictionary = GameData.campaign_hero
			var tint: Color = GameData.CLASSES.get(str(h.get("class", "tank")),
					{}).get("color", Color(0.25, 0.42, 0.62))
			HeroFigure.draw_hero(self, str(h.get("gender", "m")),
					int(h.get("design", 0)), tint, 0.0, false)
		else:
			Overworld.draw_npc_figure(self, figure, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Annonce dorée au centre (réutilise le label de zone, rendu à la zone après 3 s).
var _announce_t := 0.0
func _announce(msg: String) -> void:
	_announce_t = 3.0
	_zone_current = ""  # forcera le retour au nom de zone après l'annonce
	_zone_label.text = msg
	_zone_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	_zone_label.modulate.a = 1.0


# Déplacement libre : touches physiques WASD (= ZQSD sur clavier français) + flèches.
func _move_player(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if dir == Vector2.ZERO:
		_player.moving = false
		return
	if dir.x != 0.0:
		_player.face = 1.0 if dir.x > 0.0 else -1.0
	_try_move(_player, _screen_to_map(dir) * PLAYER_SPEED * delta)
	_player.moving = true


func _update_foes(delta: float) -> void:
	for f in _foes:
		var dist: float = f.mpos.distance_to(_player.mpos)
		# Ennemi loin : aucune logique ni animation (règle perf — rien ne se
		# passe à l'écran, rien ne doit tourner).
		if dist > 14.0 and not f.chasing:
			f.moving = false
			continue
		# Ennemi fixe (totem...) : ne bouge jamais, le contact seul le déclenche.
		if f.fixed:
			f.moving = false
			f.show_label = dist < 5.0
			if dist < CONTACT_RANGE and _grace <= 0.0 and not _locked:
				_start_battle(f)
				return
			continue
		if f.chasing:
			if dist > DEAGGRO_RANGE:
				f.chasing = false
				f.wander_target = f.home
			else:
				_walk_to(f, _player.mpos, CHASE_SPEED, delta)
		else:
			if dist < AGGRO_RANGE:
				f.chasing = true
				Audio.play_sfx("click")
			elif f.wait > 0.0:
				f.wait -= delta
				f.moving = false
			elif f.mpos.distance_to(f.wander_target) < 0.25:
				f.wait = randf_range(0.8, 2.4)
				var cand: Vector2 = f.home + Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5))
				if _free(cand):
					f.wander_target = cand
			else:
				_walk_to(f, f.wander_target, WANDER_SPEED, delta)
		f.show_label = dist < 5.0
		if dist < CONTACT_RANGE and _grace <= 0.0 and not _locked:
			_start_battle(f)
			return


func _walk_to(w: Walker, target: Vector2, speed: float, delta: float) -> void:
	var d := target - w.mpos
	if d.length() < 0.05:
		w.moving = false
		return
	var wx := map_to_world(target).x - map_to_world(w.mpos).x
	if absf(wx) > 0.5:
		w.face = 1.0 if wx > 0.0 else -1.0
	_try_move(w, d.normalized() * speed * delta)
	w.moving = true


# Déplacement continu avec glissement le long des obstacles (axe par axe).
func _try_move(w: Walker, step: Vector2) -> void:
	var p: Vector2 = w.mpos
	var nx := Vector2(p.x + step.x, p.y)
	if _free(nx):
		p.x = nx.x
	var ny := Vector2(p.x, p.y + step.y)
	if _free(ny):
		p.y = ny.y
	w.mpos = p


func _free(p: Vector2) -> bool:
	for off in [Vector2(BODY_RADIUS, 0), Vector2(-BODY_RADIUS, 0),
			Vector2(0, BODY_RADIUS), Vector2(0, -BODY_RADIUS)]:
		var t := Vector2i(int(floor(p.x + off.x)), int(floor(p.y + off.y)))
		if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
			return false
		if _blocked.has(t):
			return false
	return true


# --- Bascule vers la « dimension de combat » (scène de combat existante) ---

func _start_battle(foe: Walker) -> void:
	_locked = true
	_player.moving = false
	# Position de reprise : un peu en retrait de l'ennemi (évite un re-contact).
	var away: Vector2 = (_player.mpos - foe.mpos).normalized()
	var back: Vector2 = _player.mpos + away * 1.8
	GameData.campaign_pos = back if _free(back) else _player.mpos
	GameData.campaign_battle = true
	GameData.campaign_enemy_id = foe.foe_id
	# Équipe = le héros + ses compagnons recrutés (noms affichés en combat).
	var team: Array = [str(GameData.campaign_hero.get("class", "tank"))]
	var names: Array = [str(GameData.campaign_hero.get("name", "Héros"))]
	var ids: Array = ["hero"]
	for comp_id in GameData.campaign_party:
		var c: Dictionary = GameData.COMPANIONS.get(comp_id, {})
		if c.is_empty():
			continue
		team.append(str(c["class"]))
		names.append(str(c.name))
		ids.append(str(comp_id))
	GameData.player_team = team
	GameData.campaign_battle_names = names
	GameData.campaign_battle_ids = ids
	GameData.ai_team = foe.team.duplicate()
	GameData.difficulty = GameData.campaign_difficulty
	GameData.save_campaign()
	Audio.play_sfx("skill")
	_fade.color = Color(0.45, 0.25, 0.75, 0.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.55)
	tw.parallel().tween_property(_camera, "zoom", Vector2(1.18, 1.18), 0.55)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://Main.tscn"))


# --- Zones (nom affiché en haut au changement de lieu) ---

func _zone_name(p: Vector2) -> String:
	if p.x >= FOREST_X:
		return "Bois des Murmures"
	if p.x >= 4.0 and p.x <= 14.0 and p.y >= 4.0 and p.y <= 14.0:
		return "Hameau de Bruyère"
	return "Prairie de Bruyère"


func _update_zone() -> void:
	if _announce_t > 0.0:
		_announce_t -= get_process_delta_time()
		return
	var z := _zone_name(_player.mpos)
	if z == _zone_current:
		return
	_zone_current = z
	var danger := z == "Bois des Murmures"
	_zone_label.text = z + ("  ☠☠☠" if danger else "")
	_zone_label.add_theme_color_override("font_color",
			Color(0.95, 0.55, 0.45) if danger else Color(0.92, 0.88, 0.76))
	_zone_label.modulate.a = 0.0
	create_tween().tween_property(_zone_label, "modulate:a", 1.0, 0.8)


# --- Rendu du sol (diorama : socle, damier, joints) ---

func map_to_world(m: Vector2) -> Vector2:
	return Vector2((m.x - m.y) * HALF_W, (m.x + m.y) * HALF_H)


func _screen_to_map(d: Vector2) -> Vector2:
	var m := Vector2(d.x / HALF_W + d.y / HALF_H, d.y / HALF_H - d.x / HALF_W)
	return m.normalized() if m.length() > 0.001 else Vector2.ZERO


func _tile_points(cell: Vector2i) -> PackedVector2Array:
	var c := map_to_world(Vector2(cell) + Vector2(0.5, 0.5))
	return PackedVector2Array([
		c + Vector2(0.0, -HALF_H), c + Vector2(HALF_W, 0.0),
		c + Vector2(0.0, HALF_H), c + Vector2(-HALF_W, 0.0)])


# Ne touche au transform que si la position a vraiment changé (perf : pas de
# canvas dirty pour les personnages immobiles).
func _place(w: Walker) -> void:
	var target := map_to_world(w.mpos)
	if w.position != target:
		w.position = target


# Rectangle monde visible par la caméra (+ marge), pour le culling.
func _visible_rect() -> Rect2:
	var c: Vector2 = _camera.position if _camera else map_to_world(_player.mpos)
	return Rect2(c - VIEW_HALF, VIEW_HALF * 2.0)


# Masque tout ce qui est hors écran. Les blocs/décors/personnages cachés ne
# coûtent plus rien ; ceux visibles sont rejoués depuis le cache (pas de redraw).
func _refresh_culling() -> void:
	var vr := _visible_rect()
	for c in _chunks:
		c.visible = vr.intersects(c.rect)
	for n in _decor_nodes:
		n.visible = vr.has_point(n.position)
	for f in _foes:
		f.visible = vr.has_point(f.position)
	for n in _npcs:
		n.visible = vr.has_point(n.position)


# Le nœud racine ne dessine plus que le statique pur (ombre + socle), UNE fois.
func _draw() -> void:
	if _ground.is_empty():  # redirection vers la création de perso : rien à dessiner
		return
	# Web : pas d'ombre portée (3 polygones translucides de la taille de la
	# carte — du remplissage GPU pur pour un détail cosmétique).
	if not OS.has_feature("web"):
		_draw_drop_shadow()
	_draw_edge_walls()


func _tile_color(cell: Vector2i) -> Color:
	var duo: Array = GROUND_COLORS[_ground[cell]]
	var c: Color = duo[(cell.x + cell.y) % 2]
	# Micro-variation déterministe par case (rend le sol vivant, style SoC).
	var h := fposmod(sin(float(cell.x) * 12.9898 + float(cell.y) * 78.233) * 43758.5453, 1.0)
	var j := (h - 0.5) * 0.045
	return Color(c.r + j, c.g + j, c.b + j)


func _draw_drop_shadow() -> void:
	var n := map_to_world(Vector2(0, 0))
	var e := map_to_world(Vector2(MAP_W, 0))
	var s := map_to_world(Vector2(MAP_W, MAP_H))
	var w := map_to_world(Vector2(0, MAP_H))
	var off := Vector2(0.0, EDGE_DEPTH + 16.0)
	var center := (n + e + s + w) / 4.0 + off
	for i in [[1.08, 0.07], [1.04, 0.12], [1.0, 0.2]]:
		var pts := PackedVector2Array()
		for p in [n, e, s, w]:
			pts.append(center + (p + off - center) * i[0])
		draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, i[1]))


func _draw_edge_walls() -> void:
	var down := Vector2(0.0, EDGE_DEPTH)
	for x in MAP_W:
		var pts := _tile_points(Vector2i(x, MAP_H - 1))
		draw_colored_polygon(PackedVector2Array([
			pts[3], pts[2], pts[2] + down, pts[3] + down]), COLOR_WALL_L)
	for y in MAP_H:
		var pts := _tile_points(Vector2i(MAP_W - 1, y))
		draw_colored_polygon(PackedVector2Array([
			pts[2], pts[1], pts[1] + down, pts[2] + down]), COLOR_WALL_R)


# Bloc de sol statique (CHUNK×CHUNK tuiles) : dessiné UNE seule fois, le GPU
# rejoue ensuite le cache. La visibilité est pilotée par _refresh_culling.
class GroundChunk extends Node2D:
	var ow: Node2D
	var x0 := 0
	var y0 := 0
	var x1 := 0
	var y1 := 0
	var rect := Rect2()

	func _draw() -> void:
		# Web : pas de joints entre cases (divise par 2 les primitives du sol).
		var seams: bool = not OS.has_feature("web")
		for y in range(y0, y1):
			for x in range(x0, x1):
				var cell := Vector2i(x, y)
				var pts: PackedVector2Array = ow._tile_points(cell)
				draw_colored_polygon(pts, ow._tile_color(cell))
				if seams:
					var closed := pts.duplicate()
					closed.append(pts[0])
					draw_polyline(closed, ow.COLOR_SEAM, 1.0)


# Dessin des figures de PNJ/compagnons (statique, partagé : monde + portraits
# de la fiche d'équipe). b = respiration (0.0 = pose figée pour un portrait).
static func draw_npc_figure(ci: CanvasItem, figure: String, b: float) -> void:
	match figure:
		"herboriste":
			# Vieille femme : robe vert-gris, châle, chignon blanc, canne.
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-4.5, -16.0 + b), Vector2(4.5, -16.0 + b),
				Vector2(6.5, 0.0), Vector2(-6.5, 0.0)]), Color(0.36, 0.42, 0.32))
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-5.5, -16.5 + b), Vector2(5.5, -16.5 + b),
				Vector2(6.5, -10.0 + b), Vector2(-6.5, -10.0 + b)]),
				Color(0.55, 0.46, 0.36))  # châle
			# Tête penchée (dos voûté) + chignon blanc.
			ci.draw_circle(Vector2(1.5, -19.5 + b), 4.2, Color(0.90, 0.76, 0.62))
			ci.draw_circle(Vector2(-0.5, -22.0 + b), 2.8, Color(0.88, 0.88, 0.86))
			ci.draw_circle(Vector2(3.0, -19.2 + b), 0.8, Color(0.12, 0.10, 0.12))
			# Canne tenue devant.
			ci.draw_line(Vector2(6.5, -12.0 + b), Vector2(8.0, 0.0), Color(0.38, 0.26, 0.14), 2.0)
		"bucheron":
			# Costaud : tunique brune, ceinture, barbe, hache sur l'épaule.
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-6.5, -17.0 + b), Vector2(6.5, -17.0 + b),
				Vector2(7.5, 0.0), Vector2(-7.5, 0.0)]), Color(0.46, 0.32, 0.20))
			ci.draw_rect(Rect2(-7.0, -9.0 + b, 14.0, 2.4), Color(0.22, 0.16, 0.10))
			# Tête + barbe fournie.
			ci.draw_circle(Vector2(0.0, -21.0 + b), 4.8, Color(0.92, 0.76, 0.58))
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-4.0, -20.0 + b), Vector2(4.0, -20.0 + b),
				Vector2(0.0, -13.5 + b)]), Color(0.42, 0.28, 0.16))
			ci.draw_circle(Vector2(2.0, -21.8 + b), 0.9, Color(0.12, 0.10, 0.12))
			# Hache posée sur l'épaule (manche + fer).
			ci.draw_line(Vector2(-3.0, -16.0 + b), Vector2(-10.0, -26.0 + b), Color(0.40, 0.28, 0.15), 2.4)
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-10.0, -29.0 + b), Vector2(-6.0, -27.0 + b),
				Vector2(-10.0, -23.5 + b), Vector2(-13.0, -26.0 + b)]),
				Color(0.72, 0.74, 0.80))
		"sachet":
			# Petit sachet de toile à moitié enfoui (objet de quête de Maud).
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-5.0, 0.0), Vector2(-4.0, -7.0 + b), Vector2(0.0, -9.0 + b),
				Vector2(4.0, -7.0 + b), Vector2(5.0, 0.0)]), Color(0.62, 0.50, 0.34))
			ci.draw_line(Vector2(-3.0, -7.0 + b), Vector2(3.0, -7.0 + b),
					Color(0.38, 0.28, 0.16), 1.8)
			ci.draw_line(Vector2(0.0, -9.0 + b), Vector2(-2.0, -13.0 + b),
					Color(0.30, 0.55, 0.28), 1.6)
			ci.draw_line(Vector2(0.0, -9.0 + b), Vector2(2.0, -12.0 + b),
					Color(0.36, 0.62, 0.30), 1.6)
		"mire":
			# Joran : manteau de campagne usé, barbe grise, sacoche à croix.
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-5.5, -16.5 + b), Vector2(5.5, -16.5 + b),
				Vector2(7.0, 0.0), Vector2(-7.0, 0.0)]), Color(0.40, 0.38, 0.30))
			ci.draw_rect(Rect2(-6.0, -9.0 + b, 12.0, 2.2), Color(0.24, 0.20, 0.12))
			# Sacoche de mire (croix pâle).
			ci.draw_rect(Rect2(3.0, -8.0 + b, 5.5, 5.0), Color(0.52, 0.40, 0.26))
			ci.draw_line(Vector2(5.7, -7.2 + b), Vector2(5.7, -4.2 + b), Color(0.90, 0.88, 0.80), 1.4)
			ci.draw_line(Vector2(4.3, -5.7 + b), Vector2(7.1, -5.7 + b), Color(0.90, 0.88, 0.80), 1.4)
			# Tête fatiguée + barbe grise.
			ci.draw_circle(Vector2(0.0, -20.5 + b), 4.6, Color(0.88, 0.72, 0.56))
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-3.6, -19.0 + b), Vector2(3.6, -19.0 + b),
				Vector2(0.0, -13.0 + b)]), Color(0.62, 0.62, 0.60))
			ci.draw_circle(Vector2(1.8, -21.0 + b), 0.9, Color(0.12, 0.10, 0.12))
		"feu":
			# Feu de camp : bûches croisées + flamme qui danse + braises.
			ci.draw_line(Vector2(-7.0, -1.0), Vector2(7.0, -4.0), Color(0.36, 0.24, 0.14), 3.0)
			ci.draw_line(Vector2(-7.0, -4.0), Vector2(7.0, -1.0), Color(0.42, 0.28, 0.16), 3.0)
			var fl := 1.0 + b * 0.8  # la « respiration » du PNJ devient le tremblement du feu
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-4.5, -3.0), Vector2(4.5, -3.0),
				Vector2(0.0 + b * 2.0, -14.0 * fl)]), Color(0.95, 0.45, 0.10, 0.9))
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-2.5, -3.5), Vector2(2.5, -3.5),
				Vector2(0.0 + b * 1.4, -9.5 * fl)]), Color(1.0, 0.80, 0.25))
			ci.draw_circle(Vector2(-5.0 + b, -8.0 - b * 2.0), 0.9, Color(1.0, 0.6, 0.2, 0.7))
			ci.draw_circle(Vector2(4.0 - b, -11.0 + b), 0.7, Color(1.0, 0.7, 0.3, 0.6))
		"etrangere":
			# Voyageuse : cape bleu nuit, capuche, visage dans l'ombre, yeux pâles.
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(-5.5, -17.0 + b), Vector2(5.5, -17.0 + b),
				Vector2(7.0, 0.0), Vector2(-7.0, 0.0)]), Color(0.20, 0.24, 0.38))
			ci.draw_circle(Vector2(0.0, -20.0 + b), 5.2, Color(0.16, 0.20, 0.32))
			_ellipse_on(ci, Vector2(0.5, -19.5 + b), 3.4, 2.8, Color(0.08, 0.08, 0.12))
			ci.draw_circle(Vector2(-0.8, -19.8 + b), 0.8, Color(0.75, 0.85, 0.95))
			ci.draw_circle(Vector2(2.0, -19.8 + b), 0.8, Color(0.75, 0.85, 0.95))
			# Écharpe qui dépasse de la cape.
			ci.draw_line(Vector2(-4.0, -15.0 + b), Vector2(-7.5, -8.0 + b), Color(0.55, 0.30, 0.30), 2.2)


static func _ellipse_on(ci: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, color)


# =====================================================================
# Personnages d'exploration (joueur + ennemis), 100 % vectoriels et animés.
# Visuels volontairement distincts de ceux du combat : petites silhouettes
# de voyage (cape, marche balancée) et rôdeurs encapuchonnés aux yeux luisants.
class Walker extends Node2D:
	var kind := "player"  # "player" | "foe" | "npc"
	var mpos := Vector2.ZERO  # position dans la carte (en tuiles, continue)
	var phase := 0.0
	var moving := false
	var face := 1.0  # 1 = regarde vers la droite de l'écran
	var hue := Color(0.5, 0.3, 0.2)
	var tier := 1
	var team: Array = []
	var foe_id := ""
	var npc_id := ""
	var figure := ""        # visuel du PNJ ("herboriste", "bucheron", "etrangere")
	var prompt := false     # à portée de parole : affiche l'invite E
	var prompt_text := "E — Parler"
	var fixed := false      # ennemi immobile (totem) : contact seul
	var boss := false       # boss : nom affiché en ROUGE (pas de ☠ anonymes)
	var wkind := ""         # silhouette d'overworld ("loup", "totem", "roi"...)
	var label := ""
	var show_label := false
	var chasing := false
	var home := Vector2.ZERO
	var wander_target := Vector2.ZERO
	var wait := 0.0

	# Animation à ~15 i/s (suffisant pour de petites figurines, 4× moins de
	# redraws que 60 i/s — crucial pour le navigateur). Rien si hors écran.
	const REDRAW_DT := 1.0 / 15.0
	var _redraw_t := 0.0

	func _process(delta: float) -> void:
		phase += delta * (9.0 if moving else 2.2)
		if not visible:
			return
		_redraw_t += delta
		if _redraw_t >= REDRAW_DT:
			_redraw_t = 0.0
			queue_redraw()

	func _draw() -> void:
		# Ombre de contact (hors miroir, elle est symétrique).
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 9.0 if kind != "foe" else 8.0 + 2.0 * tier,
				Color(0.0, 0.0, 0.0, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1.0))
		match kind:
			"player":
				_draw_player()
			"npc", "ally":
				_draw_npc()
			_:
				_draw_foe()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_overhead()

	# PNJ du hameau / compagnons : figures partagées avec la fiche d'équipe.
	func _draw_npc() -> void:
		Overworld.draw_npc_figure(self, figure, sin(phase) * 0.5)


	func _draw_player() -> void:
		var h: Dictionary = GameData.campaign_hero
		var tint: Color = GameData.CLASSES.get(str(h.get("class", "tank")),
				{}).get("color", Color(0.25, 0.42, 0.62))
		HeroFigure.draw_hero(self, str(h.get("gender", "m")),
				int(h.get("design", 0)), tint, phase, moving)

	# Chaque type d'ennemi a SA silhouette d'overworld (fini les clones).
	func _draw_foe() -> void:
		var s := 0.85 + 0.18 * float(tier)  # plus fort = plus imposant
		var b := sin(phase) * (1.2 if moving else 0.6)
		var sway := sin(phase * 0.7) * 1.5
		var dark := Color(hue.r * 0.55, hue.g * 0.55, hue.b * 0.55)
		match wkind:
			"loup":
				_draw_foe_wolf(s, b)
				return
			"totem":
				_draw_foe_totem()
				return
			"traqueur":
				_draw_foe_traqueur(s, b, sway)
				return
			"sera":
				Overworld.draw_npc_figure(self, "etrangere", b * 0.5)
				return
			"roi":
				_draw_foe_roi(b, sway)
				return
		# Par défaut (rôdeur, veilleur) : silhouette encapuchonnée.
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7.0 * s, 0.0), Vector2(7.0 * s, 0.0),
			Vector2(6.0 * s, (-14.0 + b) * s), Vector2((0.0 + sway) * s, (-24.0 + b) * s),
			Vector2(-6.0 * s, (-14.0 + b) * s)]), dark)
		# Liseré de la cape (lisibilité sur sol sombre).
		draw_line(Vector2(-7.0 * s, 0.0), Vector2(-6.0 * s, (-14.0 + b) * s),
				Color(hue.r, hue.g, hue.b, 0.9), 1.5)
		draw_line(Vector2(7.0 * s, 0.0), Vector2(6.0 * s, (-14.0 + b) * s),
				Color(hue.r, hue.g, hue.b, 0.9), 1.5)
		# Cornes du chef (tier 3).
		if tier >= 3:
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4.5 * s, (-21.0 + b) * s), Vector2(-8.5 * s, (-27.0 + b) * s),
				Vector2(-2.5 * s, (-22.5 + b) * s)]), dark)
			draw_colored_polygon(PackedVector2Array([
				Vector2(4.5 * s, (-21.0 + b) * s), Vector2(8.5 * s, (-27.0 + b) * s),
				Vector2(2.5 * s, (-22.5 + b) * s)]), dark)
		# Yeux luisants (rouges en poursuite).
		var eye := Color(1.0, 0.35, 0.2) if chasing else Color(0.95, 0.85, 0.45)
		draw_circle(Vector2(-2.2 * s, (-16.5 + b) * s), 2.6 * s, Color(eye.r, eye.g, eye.b, 0.18))
		draw_circle(Vector2(2.2 * s, (-16.5 + b) * s), 2.6 * s, Color(eye.r, eye.g, eye.b, 0.18))
		draw_circle(Vector2(-2.2 * s, (-16.5 + b) * s), 1.1 * s, eye)
		draw_circle(Vector2(2.2 * s, (-16.5 + b) * s), 1.1 * s, eye)

	# Loup : quadrupède bas, oreilles dressées, œil qui s'allume en chasse.
	func _draw_foe_wolf(s: float, b: float) -> void:
		var fur := Color(hue.r * 0.72, hue.g * 0.72, hue.b * 0.72)
		var dk := fur.darkened(0.4)
		for lx in [-6.5, -2.5, 4.0, 7.0]:
			var fx: float = lx
			draw_line(Vector2(fx * s, -4.0 * s), Vector2(fx * s, 0.0), dk, 2.0)
		_ell(Vector2(0.5 * s, -6.5 * s + b * 0.4), 9.0 * s, 4.2 * s, fur)
		draw_line(Vector2(8.5 * s, -8.0 * s), Vector2(13.0 * s, -11.0 * s + b), dk, 2.4)
		draw_circle(Vector2(-8.5 * s, -9.5 * s + b * 0.5), 3.4 * s, fur)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-10.4 * s, -12.0 * s), Vector2(-9.2 * s, -15.5 * s + b),
			Vector2(-7.8 * s, -12.0 * s)]), dk)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-10.8 * s, -10.0 * s), Vector2(-14.8 * s, -8.4 * s),
			Vector2(-10.0 * s, -7.6 * s)]), fur)
		var eye := Color(1.0, 0.32, 0.2) if chasing else Color(0.95, 0.82, 0.4)
		draw_circle(Vector2(-9.4 * s, -10.0 * s + b * 0.5), 1.0 * s, eye)

	# Totem : monolithe immobile aux runes vertes (aucun retournement).
	func _draw_foe_totem() -> void:
		var stone := Color(0.36, 0.38, 0.34)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-6.5, 0.0), Vector2(-5.0, -20.0), Vector2(-1.0, -24.0),
			Vector2(4.5, -21.0), Vector2(6.5, 0.0)]), stone)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-6.5, 0.0), Vector2(-5.0, -20.0), Vector2(-2.5, -22.0),
			Vector2(-2.5, 0.0)]), stone.darkened(0.3))
		var pulse := 0.5 + 0.4 * sin(phase * 1.4)
		var rune := Color(0.45, 0.95, 0.40, pulse)
		draw_line(Vector2(0.0, -16.0), Vector2(0.0, -10.0), rune, 1.8)
		draw_line(Vector2(-2.2, -13.5), Vector2(2.2, -12.0), rune, 1.6)
		draw_line(Vector2(-5.5, -3.0), Vector2(5.0, -8.0), Color(0.16, 0.30, 0.14), 2.0)

	# Traqueur : silhouette fine penchée, deux éclats de dague, yeux violets.
	func _draw_foe_traqueur(s: float, b: float, sway: float) -> void:
		var dk := Color(hue.r * 0.5, hue.g * 0.5, hue.b * 0.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-3.5 * s, 0.0), Vector2(3.5 * s, 0.0),
			Vector2(4.5 * s, (-13.0 + b) * s),
			Vector2((-2.0 + sway) * s, (-22.0 + b) * s),
			Vector2(-4.5 * s, (-12.0 + b) * s)]), dk)
		draw_circle(Vector2((-2.0 + sway) * s, (-23.0 + b) * s), 3.2 * s, dk)
		var eye := Color(1.0, 0.3, 0.2) if chasing else Color(0.80, 0.50, 1.0)
		draw_circle(Vector2((-3.2 + sway) * s, (-23.2 + b) * s), 0.9 * s, eye)
		draw_circle(Vector2((-0.8 + sway) * s, (-23.4 + b) * s), 0.9 * s, eye)
		var steel := Color(0.80, 0.82, 0.90)
		draw_line(Vector2(5.0 * s, (-8.0 + b) * s), Vector2(9.0 * s, (-3.0 + b) * s), steel, 1.8)
		draw_line(Vector2(-5.0 * s, (-7.0 + b) * s), Vector2(-8.5 * s, (-2.0 + b) * s), steel, 1.8)

	# Traqueur-Roi : haute stature, couronne de lames, prestance de boss secret.
	func _draw_foe_roi(b: float, sway: float) -> void:
		var dk := Color(hue.r * 0.5, hue.g * 0.5, hue.b * 0.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-8.0, 0.0), Vector2(8.0, 0.0),
			Vector2(6.5, -18.0 + b), Vector2(0.0 + sway, -30.0 + b),
			Vector2(-6.5, -18.0 + b)]), dk)
		draw_line(Vector2(-8.0, 0.0), Vector2(-6.5, -18.0 + b),
				Color(0.85, 0.30, 0.40, 0.9), 1.6)
		draw_line(Vector2(8.0, 0.0), Vector2(6.5, -18.0 + b),
				Color(0.85, 0.30, 0.40, 0.9), 1.6)
		# Couronne de lames (3 pointes d'acier).
		var steel := Color(0.82, 0.84, 0.92)
		for kx in [-4.0, 0.0, 4.0]:
			var fx: float = kx
			draw_colored_polygon(PackedVector2Array([
				Vector2(fx - 1.4 + sway, -29.0 + b), Vector2(fx + sway, -36.0 + b),
				Vector2(fx + 1.4 + sway, -29.0 + b)]), steel)
		var eye := Color(1.0, 0.25, 0.2) if chasing else Color(1.0, 0.45, 0.35)
		draw_circle(Vector2(-2.2 + sway, -24.0 + b), 1.2, eye)
		draw_circle(Vector2(2.2 + sway, -24.0 + b), 1.2, eye)

	# Ellipse pleine (pas de primitive native).
	func _ell(center: Vector2, rx: float, ry: float, color: Color) -> void:
		var pts := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14.0
			pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, color)

	# Textes au-dessus de la tête (hors miroir pour ne pas écrire à l'envers).
	func _draw_overhead() -> void:
		var font := ThemeDB.fallback_font
		if kind == "ally":
			if prompt:
				draw_string(font, Vector2(-60.0, -36.0), "E — Parler",
						HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.0, 0.0, 0.0, 0.7))
				draw_string(font, Vector2(-61.0, -37.0), "E — Parler",
						HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.70, 0.90, 1.0))
			return
		if kind == "npc":
			if prompt:
				draw_string(font, Vector2(-60.0, -36.0), prompt_text,
						HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.0, 0.0, 0.0, 0.7))
				draw_string(font, Vector2(-61.0, -37.0), prompt_text,
						HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1.0, 0.88, 0.45))
			elif show_label:
				draw_string(font, Vector2(-60.0, -34.0), label,
						HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.0, 0.0, 0.0, 0.7))
				draw_string(font, Vector2(-61.0, -35.0), label,
						HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(0.80, 0.95, 0.85))
			return
		if kind != "foe":
			return
		var s := 0.85 + 0.18 * float(tier)
		# BOSS : leur vrai nom s'affiche en ROUGE — eux sont inoubliables.
		if boss:
			if chasing or show_label:
				draw_string(font, Vector2(-80.0, -36.0 * s - 6.0), label,
						HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(0.0, 0.0, 0.0, 0.85))
				draw_string(font, Vector2(-81.0, -37.0 * s - 7.0), label,
						HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(0.95, 0.20, 0.18))
			return
		# Ennemis : anonymes — juste leur danger en crânes (☠ par palier).
		if chasing:
			draw_string(font, Vector2(-4.0, -30.0 * s - 6.0), "!",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.8, 0.25))
		elif show_label:
			var skulls := "☠".repeat(maxi(1, tier))
			draw_string(font, Vector2(-60.0, -30.0 * s - 4.0), skulls,
					HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.0, 0.0, 0.0, 0.7))
			draw_string(font, Vector2(-61.0, -30.0 * s - 5.0), skulls,
					HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1.0, 0.85, 0.75))


# Décors du monde (arbres, sapins, rochers, maisons, roseaux), base au point (0,0)
# pour que le tri en Y donne une occlusion correcte avec les personnages.
class Decor extends Node2D:
	var kind := "tree"
	var seed_v := 0.0

	func _draw() -> void:
		match kind:
			"tree":
				_shadow(11.0)
				draw_rect(Rect2(-2.5, -13.0, 5.0, 13.0), Color(0.30, 0.21, 0.13))
				var g := Color(0.24 + seed_v * 0.06, 0.42 + seed_v * 0.06, 0.20)
				draw_circle(Vector2(-7.0, -15.0), 7.5, g.darkened(0.12))
				draw_circle(Vector2(7.0, -15.0), 7.5, g.darkened(0.06))
				draw_circle(Vector2(0.0, -21.0), 10.0, g)
				draw_circle(Vector2(-3.0, -23.5), 4.0, g.lightened(0.15))
			"fir":
				_shadow(10.0)
				draw_rect(Rect2(-2.0, -7.0, 4.0, 7.0), Color(0.22, 0.15, 0.10))
				var c := Color(0.10 + seed_v * 0.04, 0.23 + seed_v * 0.05, 0.13)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-12.0, -7.0), Vector2(12.0, -7.0), Vector2(0.0, -25.0)]), c)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-9.5, -17.0), Vector2(9.5, -17.0), Vector2(0.0, -33.0)]), c.lightened(0.07))
				draw_colored_polygon(PackedVector2Array([
					Vector2(-7.0, -26.0), Vector2(7.0, -26.0), Vector2(0.0, -41.0)]), c.lightened(0.13))
			"rock":
				_shadow(10.0)
				var g := Color(0.44 + seed_v * 0.06, 0.44 + seed_v * 0.05, 0.49)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-10.0, 0.0), Vector2(-7.0, -8.0), Vector2(0.0, -11.0),
					Vector2(8.0, -7.0), Vector2(11.0, 0.0)]), g)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-5.0, -7.5), Vector2(0.0, -10.0), Vector2(4.0, -7.0),
					Vector2(-1.0, -5.5)]), g.lightened(0.18))
			"house":
				_shadow(30.0)
				var wall_l := Color(0.62, 0.55, 0.44)
				var wall_r := Color(0.72, 0.64, 0.51)
				var a := 34.0
				var bb := 17.0
				var h := 26.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(-a, -bb), Vector2(0, 0), Vector2(0, -h), Vector2(-a, -bb - h)]), wall_l)
				draw_colored_polygon(PackedVector2Array([
					Vector2(0, 0), Vector2(a, -bb), Vector2(a, -bb - h), Vector2(0, -h)]), wall_r)
				var roof_l := Color(0.48, 0.22, 0.16)
				var roof_r := Color(0.58, 0.28, 0.19)
				var apex := Vector2(0, -bb - h - 22.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-a - 4.0, -bb - h + 2.0), Vector2(0, -h + 2.0), apex]), roof_l)
				draw_colored_polygon(PackedVector2Array([
					Vector2(0, -h + 2.0), Vector2(a + 4.0, -bb - h + 2.0), apex]), roof_r)
				# Porte (face droite) + fenêtre (face gauche).
				draw_colored_polygon(PackedVector2Array([
					Vector2(7.0, -3.5), Vector2(15.0, -7.5),
					Vector2(15.0, -24.0), Vector2(7.0, -20.0)]), Color(0.26, 0.17, 0.10))
				draw_colored_polygon(PackedVector2Array([
					Vector2(-22.0, -13.0), Vector2(-14.0, -9.0),
					Vector2(-14.0, -19.0), Vector2(-22.0, -23.0)]), Color(0.92, 0.82, 0.50))
			"reed":
				var c := Color(0.16, 0.30, 0.16)
				draw_line(Vector2(0.0, 0.0), Vector2(-2.0, -12.0), c, 1.6)
				draw_line(Vector2(2.0, 0.0), Vector2(4.0, -14.0), c, 1.6)
				draw_line(Vector2(-3.0, 0.0), Vector2(-6.0, -9.0), c, 1.6)
				draw_circle(Vector2(4.0, -14.0), 2.0, Color(0.38, 0.24, 0.12))

	func _shadow(r: float) -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, r, Color(0.0, 0.0, 0.0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

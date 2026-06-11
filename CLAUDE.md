# CLAUDE.md

> Mémoire permanente du projet. Claude DOIT relire ce fichier à chaque session
> et respecter ces règles à la lettre.

## Préférences de communication

- **Langue : réponds TOUJOURS en français.** Toutes les réponses, explications et
  messages adressés à l'utilisateur sont en français.
- L'utilisateur déteste : le gaspillage de tokens, les réponses interminables,
  et surtout le **refactoring non demandé**. Va à l'essentiel.

---

## Règles de travail (GARDE-FOU — non négociable)

À chaque tâche, AVANT de coder :
1. **Expliquer le plan** : ce qui sera modifié, pourquoi, quels fichiers, quels risques.
2. **Modifier le minimum de fichiers possible.** Une seule fonctionnalité à la fois.
3. **Attendre la validation** de l'utilisateur avant de passer à l'étape suivante.

Interdictions strictes :
- ❌ **Pas de refactoring non demandé** (ne jamais refactoriser juste pour « faire joli »).
- ❌ Pas d'optimisation prématurée.
- ❌ Pas de système « prévu pour plus tard » qu'on code maintenant inutilement.
- ❌ Pas de modification de plusieurs systèmes en même temps.
- ❌ Ne jamais casser une fonctionnalité existante pour en ajouter une nouvelle.

Avant toute modification :
- Identifier le rôle du système, ses dépendances, ses effets secondaires, l'impact attendu.
- Préserver l'existant : étendre plutôt que réécrire.

En cas d'ambiguïté : **ne pas deviner**. Signaler l'ambiguïté, proposer plusieurs
options, demander validation.

Principe directeur : la solution **la plus simple, la plus maintenable, la moins
risquée, la plus facile à étendre**. Éviter la sur-ingénierie.

> Note d'équilibre : « architecture data-driven » (dictionnaires, données
> configurables) ≠ sur-ingénierie. On structure les données simplement dès le
> départ, MAIS on ne code pas de systèmes entiers (buffs, 20 classes…) tant
> qu'ils ne sont pas à l'ordre du jour.

### Git / livraison (demande permanente de l'utilisateur)
- Après chaque fonctionnalité terminée : pousser la branche de travail PUIS
  **fusionner aussitôt dans `main` et pousser `main`**, sans redemander.
  Raison : le jeu est récupéré par `git pull` sur `main` sur plusieurs PC
  (dont celui d'Eline) — si `main` n'est pas à jour, rien n'apparaît.

---

## Le projet : RPG Tactique Dark Fantasy

**Genre** : RPG tactique tour par tour, vue top-down 2D, sur grille de cases.
**Moteur** : Godot 2D.
**Cœur du jeu** : stratégie, positionnement, composition d'équipe et surtout **IA**.
Les graphismes ne sont PAS prioritaires.

Le joueur affronte **uniquement une IA**.

### Boucle de jeu (cible)
1. Choix de la difficulté → 2. Sélection équipe joueur → 3. Sélection équipe IA →
4. Déploiement → 5. Combat tactique → 6. Écran de résultat.
La partie se termine quand une équipe est entièrement éliminée.

### Combat
- Déplacement case par case, **pas de diagonale**.
- Corps à corps ou distance selon la classe.
- Coups critiques possibles.
- Compétences spéciales par classe.
- Buffs/debuffs **prévus plus tard** (ne pas coder maintenant).

### Classes (cible : 20 à terme)
Tank, Archer, Assassin, Mage, Soigneur, Paladin, Berserker, Nécromancien,
Druide, Mage de glace… (+10 plus tard). Chaque classe : rôle, stats, compétences,
forces, faiblesses. **Aucune classe ne doit être dominante seule** — la
composition d'équipe prime sur la puissance brute d'une unité.

### IA — PRIORITÉ ABSOLUE du projet
- **Ne triche jamais.** Basée sur des règles intelligentes qui donnent
  l'impression qu'elle réfléchit vraiment.
- Comportements visés : finir les cibles faibles, se mettre à distance si besoin,
  protéger les unités importantes, utiliser les compétences au bon moment,
  exploiter les erreurs de placement, jouer différemment selon son rôle.
- Difficultés : **Facile** (moins agressive, erreurs volontaires, léger avantage
  joueur), **Normal** (équilibré), **Difficile** (meilleures décisions),
  **Hardcore** (optimisée, peu d'erreurs, légers bonus IA / malus joueur).

### Visuel (début)
Formes simples, couleur + symbole par rôle. Lisibilité tactique avant tout.
Ex : Tank = bleu + bouclier · Archer = vert + arc · Assassin = violet + dague ·
Mage = rouge + bâton · Soigneur = blanc + croix.

---

## État actuel & ordre de développement

**Prototype jouable livré (étapes 1 → 10 faites).** Combat joueur vs IA
fonctionnel sur grille 12×10, avec écran de préparation.

Ordre de priorité (✅ = fait) :
1. ✅ Grille fonctionnelle
2. ✅ Système de tours
3. ✅ Déplacement (clic)
4. ✅ Attaque (corps à corps / distance, coups critiques)
5. ✅ IA de base
6. ✅ Sélection d'équipe + difficulté avant combat
7. ✅ Classes data-driven (Tank, Archer, Assassin, Mage, Soigneur, Paladin,
   Berserker, **Mage de glace**, **Lancier**) — 9 classes
8. ✅ Buffs/debuffs génériques (poison, brûlure, régén, bouclier, force, **gel**)
9. ✅ Difficultés (Facile/Normal/Difficile/Hardcore)
10. ✅ IA avancée (ciblage prioritaire, kite, protection des alliés)
11. ✅ Soigneur équilibré (portée de soin dédiée `heal_range`)
12. ✅ Composition d'équipe IA cohérente selon la difficulté (rôles + counter)
13. ✅ Compétences actives data-driven avec cooldown (Protection, Frappe de
    l'ombre/téléportation, Nova de givre, Purification) — joueur **et** IA
14. ✅ IA avancée : positionnement conscient de la menace (repli des fragiles)
15. ✅ Équilibrage 1v1 validé par simulation headless
16. ✅ 7 nouvelles classes (16 visibles + squelette invoqué) : **Nécromancien**
    (invocation permanente, max 1 squelette), **Druide** (Racines = immobilisation),
    **Prêtre de guerre** (soin actif), **Alchimiste** (double DoT), **Chevalier
    noir** (drain de vie), **Chasseur** (marque + bonus dégâts), **Envoûteur**
    (affaiblit/renforce)
17. ✅ Compétences actives data-driven supplémentaires : Tir perforant (Archer,
    ligne), Invocation, Racines, Cocktail acide, Drain de vie, Tir ciblé,
    Renforcement — joueur **et** IA (`_plan_skill` couvre tous les types)
18. ✅ Terrain tactique léger (Forêt = -dégâts à distance, Ruines = -dégâts subis,
    Marécage = -déplacement), généré aléatoirement, effets data-driven (`TERRAIN`)
19. ✅ Synergies tactiques émergentes (Racines + tireurs, Marque + burst, Gel +
    mêlée) — via décisions joueur, sans système dédié
20. ✅ Ré-équilibrage 16 classes par simulation headless (aucun outlier > 65 % en
    1v1, supports volontairement bas seuls car pensés pour l'équipe)
21. ✅ **Draft alterné** : joueur pioche 1, IA pioche 1, en alternance jusqu'à 3
    chacun ; pool partagé (classe prise = retirée pour tous) ; l'IA adapte ses
    choix (rôle manquant + counter en difficile/hardcore) — `TacticalAI.draft_pick`
22. ✅ **Barre de compétences souris** : 3 carrés en bas à droite quand une unité
    joueur est sélectionnée. Carré 0 = compétence de la classe (clic = sélection,
    reclic = annulation, puis clic sur la cible) ; carrés 1-2 réservés (vides).
    Aucun raccourci clavier. (`Battle._build_skill_bar` / `_refresh_skill_bar`)
23. ✅ **Nécromancien à 2 invocations à rôles distincts** : Squelette guerrier
    (mêlée, tient la ligne) + Squelette archer (distance, harcèle). Permanents,
    réinvocables 3 tours après leur mort (cooldown). `summon_classes` (liste).
24. ✅ **Invocateur** (nouvelle classe) : invoque Golem de pierre (tank lent) +
    Loup spectral (rapide, fonce sur les fragiles). Mêmes règles permanentes.
25. ✅ Alchimiste légèrement renforcé (atk 8→9, Cocktail acide CD 4→3)
26. ✅ **3 compétences actives par classe** (carrés 1-2-3 tous fonctionnels) :
    moteur multi-compétences avec **cooldown indépendant par compétence**
    (`Unit.skill_cds[]`, `get_actives()`, `skill_ready(index)`). La barre souris
    sélectionne le carré 0/1/2 ; chaque carré = une compétence (reclic = annule).
27. ✅ **5 nouveaux types de compétences génériques** (data-driven, joueur + IA) :
    `heavy_strike` (gros coup ×mult, gardé pour achever/cibles prioritaires),
    `cleave` (mêlée de zone, ≥2 cibles), `self_buff` (buff personnel),
    `buff_ally` (buff nommé sur allié, `can_self`), `apply_debuff` (attaque +
    debuff nommé).
28. ✅ **Nouveaux buffs** : `rage` (+50% dégâts / +25% subis), `garde` (-60%
    dégâts subis), `vulnerabilite` (+35% dégâts subis, purifiable).
29. ✅ Toutes les classes existantes ont reçu une compétence 2 et 3 renforçant
    leur identité (Tank : Garde + Brise-armure ; Berserker : Tourbillon +
    Décapitation + Rage ; Druide : boîte à outils contrôle/soutien/nature ;
    Chasseur : Tir de précision + Piège à mâchoires ; etc.).
30. ✅ **IA contextuelle multi-compétences** : évalue chaque compétence prête et
    prend la première pertinente (actives rangées par priorité ; `_plan_skill`
    renvoie null si inutile → jamais de cast à vide).
31. ✅ Ré-équilibrage roster complet (aucun outlier > 65 % en 1v1)
32. ✅ **Classes UNIQUES** (`unique: true`) : classes « boss » volontairement
    fortes (peuvent dépasser 65 %). **Max 1 unique par équipe** (joueur ET IA),
    badge ★ + libellé doré dans le draft (`TeamSelect`), filtre dans
    `TacticalAI.draft_pick`. Uniques : Nécromancien (~80 %), Invocateur (~80 %),
    Assassin (~80 %), **Archère** (~60 %), **Barde**, **Duelliste**.
33. ✅ **3 nouvelles classes** : **Archère** (sniper, portée 5, `retreat_shot`),
    **Barde** (soutien, `team_buff`/`team_debuff` = chants sur TOUTE l'équipe ou
    tous les ennemis), **Duelliste** (`riposte` + `parade`).
34. ✅ **3 nouvelles mécaniques de combat** :
    - `riposte` (buff) : contre-attaque auto au corps à corps (géré dans
      `Battle._attack` / `SimTest._act`, paramètre `is_counter` anti-récursion).
    - `parade` (buff `block_next`) : annule entièrement la prochaine attaque reçue
      (consommé à l'usage, `_consume_parade`).
    - `retreat_shot` (type) : tire puis recule de N cases (`Battle._retreat`).
35. ✅ **Animations de compétences** (`SkillFX.gd`, instancié par `Battle._fx`) :
    projectile qui traverse l'écran (tirs), coup de lame (mêlée), faisceau (tir
    perforant / drain), nova/explosion (zone), halo (buff/debuff), téléportation.
    100 % cosmétique (tween, auto-libéré), n'altère jamais l'état du combat.
36. ✅ **Correctifs riposte** : un lanceur tué par la riposte du Duelliste ne
    continue plus d'agir (cleave/piercing s'arrêtent, drain ne ressuscite plus,
    retreat_shot ne recule plus un mort). `Unit.heal()` restaure la visibilité.
37. ✅ **Vrais personnages** (`Unit._draw()`, 100 % vectoriel, 1 seul fichier) :
    figurine (robe + tête + yeux) colorée par classe, **arme selon le profil**
    (bouclier/épée/lance/arc/bâton via `_weapon_kind()`), **anneau de sol coloré
    par camp** (bleu joueur / rouge IA, doré = tour actif), barre de vie
    verte/jaune/rouge, lettre de classe sur le torse. Aucun asset externe.
38. ✅ **Fix label de tour** : `TurnManager.turn_label` (export typé `Label`) ne
    se résolvait pas depuis le `NodePath` du `.tscn` → le nom de l'unité ne
    s'affichait jamais. Passé en `@export NodePath` résolu dans `_ready()`
    (champ `label`).
39. ✅ **Vrais sprites pixel-art** (pack CC0 « DungeonTileset II » de 0x72,
    `assets/dungeon_tileset.png` + `assets/CREDITS.md`) : chaque classe (+ les
    4 invocations) est mappée à une figurine de la spritesheet via le dico
    `Unit.SPRITES` (rect de la frame idle). Rendu dans `_draw()` avec
    `draw_texture_rect_region` (filtre `nearest`, mis à l'échelle ~42 px, posé
    sur l'anneau de sol), **animation idle 4 frames** (`_process`). Conserve
    anneau de camp / barre de vie / pastilles. Repli vectoriel
    (`_draw_vector_body`) pour toute classe non mappée.
40. ✅ **Animations de mouvement** : glissement fluide vers la case (`Unit.move_to`
    via tween) + petit élan d'attaque (`Unit.lunge`, appelé dans `Battle._attack`).
    Bypass en headless (`DisplayServer.get_name() == "headless"`).
41. ✅ **Confort & UI** : bouton **Fin de tour** visible (bas gauche), **cooldown
    affiché** sur les carrés de compétence (`CD n` / `Max`), **cliquer sa propre
    case** valide la position et passe à l'action, **durée restante** affichée sur
    les pastilles de buff (`Unit._draw`), **effet du terrain au survol**
    (`Battle._update_terrain_hint` + `TerrainLabel`), **écran de fin avec stats**
    (tours joués, ennemis vaincus, alliés perdus, plus gros coup —
    `Battle._show_stats` + `StatsLabel`).
44. ✅ **Vue ISOMÉTRIQUE** (type Into the Breach / XCOM) : la grille passe en
    losanges (projection iso 2:1 dans `Grid.cell_to_local` / `local_to_cell`,
    constantes `TILE_W`/`TILE_H`/`ISO_ORIGIN`). Sol dessiné en losanges
    (`_diamond_points`/`_fill_cell`/`_outline_cell`), **tri en profondeur** des
    unités via `y_sort_enabled` sur le nœud Grid (les FX et textes flottants
    restent au-dessus grâce à `z_index`). **Gameplay 100 % inchangé** (coords de
    grille entières, BFS, portées, IA identiques). `CELL_SIZE` conservé pour les
    rayons d'effets. Limite connue (étape suivante) : pas encore d'occlusion des
    décors hauts ni de relief/hauteur — c'est la base avant d'ajouter toits,
    élévation et bonus de hauteur.
43. ✅ **Décors de terrain vectoriels** (`Grid._draw_terrain_feature`) : la lettre
    (F/R/M) est remplacée par un vrai obstacle dessiné — **sapin** (Forêt),
    **colonne brisée + blocs** (Ruines), **flaque + bulles + roseaux** (Marécage).
    Fond teinté conservé sous le décor (lisibilité de la zone d'effet). 100 %
    vectoriel, aucun asset.
42. ✅ **Correctifs IA** : `_removable_count` compte désormais TOUS les debuffs
    purifiables (racines, affaiblissement, vulnérabilité — avant : seulement DoT
    et ralentissement) → le Soigneur/Druide IA purifient correctement ; l'IA
    **déprioritise une cible en parade** (`block_next`) pour ne pas gâcher son
    attaque (`AI._pick_enemy`).
45. ✅ **Lot 🅰 — bugs bloquants de confort** :
    - **Plein écran** (`project.godot`) : fenêtre démarrée maximisée
      (`window/size/mode=2`) + mise à l'échelle (`stretch/mode=canvas_items`,
      `aspect=keep`) → fini le mini-cadre, le jeu remplit l'écran en gardant ses
      proportions (base 832×704 conservée, donc UI du combat non décalée).
    - **Bouton COMBAT toujours atteignable** (`TeamSelect.gd`) : tout l'écran de
      draft est dans un `ScrollContainer` (défilement vertical) → plus besoin de
      « contourner » pour cliquer COMBAT.
    - **Compétence sans bouger d'abord** (`Battle.gd`) : la barre de compétences
      est active dès la phase « déplacement ». Sélection depuis `move` mémorisée
      dans `_skill_return_phase` ; annuler (reclic) ramène à la phase d'avant
      (déplacement ou attaque).
46. ✅ **Lot 🅱 — lisibilité tactique** :
    - **Perso centrés sur leur case** (`Unit._draw`) : anneau de sol + pieds
      remontés au centre du losange (avant : ~18 px sous le centre → impression de
      décalage). Sprite calé à `y=6`, figurine vectorielle via `draw_set_transform`,
      barre de vie/pastilles repositionnées. Anneau de camp agrandi (échelle 2:1).
    - **Cases plus lisibles** (`Grid.gd`) : contour des cases éclairci/épaissi,
      **contour net** sur les cases de déplacement/cible/soin/compétence (en plus
      du remplissage), et **surbrillance blanche de la case survolée**
      (`hover_cell`, mis à jour dans `Battle._unhandled_input` sur mouvement souris).
    - **Obstacles cadrés** (`Grid._draw_terrain_feature`) : décor « planté » sur la
      case (ombre de contact au sol + élément remonté vers le centre du losange).
47. ✅ **Lot 🅲 — barre de compétences améliorée** (`Battle.gd`) :
    - **Icônes Unicode** par compétence (épée ⚔, arc 🏹, baguette ✨, bouclier 🛡,
      cœur ❤, éclair ⚡, etc.) remplacent les abréviations texte.
    - **Couleur de fond par catégorie** (`SKILL_CATEGORY_COLOR`) : orange = attaque,
      bleu = contrôle, violet = magie, vert = soin, gris = buff.
    - **Panneau d'info instantané** (`_skill_info_panel`) : survol d'un carré →
      nom + description apparaissent immédiatement (sans délai tooltip).
    - **Indicateur de cooldown coloré** : rouge si en recharge, blanc si prêt.
48. ✅ **Lot 🅳 — sprites collant aux rôles** (`Unit.SPRITES`) :
    - Scan pixel du tileset 0x72 (Python/PIL) → découverte de 4 sprites inutilisés.
    - **druide** → hero_12 (blonde en vert, y=434) — rôle nature.
    - **alchimiste** → hero_9 (gnome gris, y=264) — rôle inventeur.
    - **assassin** → hero_11 (cape sombre, y=360) — rôle furtif.
    - **barde** → x=368/y=360 (silhouette blonde/bleu distincte).
    - **chasseur** : supprimé du dict (goblin inadapté) → fallback vectoriel avec arc.
49. ✅ **Écran-titre + réglages audio** (`Title.gd/.tscn`, scène de démarrage) :
    titre stylisé, boutons Jouer / Réglages / Quitter (fond dessiné). Panneau
    Réglages = 3 sliders de volume (Master/Musique/Effets) pilotés en direct via
    l'`AudioServer`, persistés dans `user://settings.cfg` (GameData
    `apply_volume`/`save_settings`/`load_settings`). Bus `default_bus_layout.tres`
    (Master/Music/SFX). Flux : Title → TeamSelect → Combat. TeamSelect a un
    bouton « ← Menu principal ».
50. ✅ **Son** (`Audio.gd` autoload, `assets/audio/*.wav`) : audio **100 % généré**
    par script procédural (sinus + bruit, CC0, aucun asset externe). 9 bruitages
    (clic, coup mêlée/distance, critique, compétence, soin, mort, victoire,
    défaite) + 2 musiques en boucle (menu, combat). `play_sfx`/`play_music`/
    `stop_music` ; pool de voix SFX, musique en boucle (`LOOP_FORWARD`). Câblé
    dans Title/TeamSelect/Battle.
51. ✅ **Relief / hauteur tactique** (`Grid.heights`, `Grid.HEIGHT_RISE`) : des
    plateaux surélevés (générés par `Battle._generate_heights`, 5/carte) dessinés
    avec parois latérales + sommet relevé. **+25 % de dégâts en attaquant depuis
    une case plus haute** (`Battle.HIGH_GROUND_MULT`, dans `_attack`). Unités
    posées sur le sommet (`Unit._cell_pos` → `cell_to_local_raised`). `local_to_cell`
    réécrit pour rester précis sur les hauteurs (test du losange-sommet, occlusion
    correcte des cases derrière un plateau). IA recherche les hauteurs
    (`AI._cell_score`, bonus accru pour les tireurs). Survol = info hauteur.
    Limite v1 : déplacement non pénalisé pour grimper (climb gratuit), 1 niveau.
52. ✅ **Plusieurs cartes** (`GameData.MAPS`, `current_map`) : 5 biomes tirés au
    hasard au début du combat (Plaine ouverte, Forêt ancienne, Ruines maudites,
    Marais brumeux, Hauts plateaux). Chaque carte a sa **dominante de terrain**
    (poids), sa **densité d'obstacles** et son **nombre de plateaux**.
    `Battle._generate_terrain` tire la carte, construit un sac pondéré
    (`_weighted_terrain_bag`) et applique densité + relief ; le nom s'affiche au
    début (réutilise `terrain_label`). 100 % data-driven, aucun nouveau nœud.
53. ✅ **Déblocage de classes** (`GameData.STARTER_CLASSES`, `UNLOCK_ORDER`,
    `unlocked`, `wins`) : 6 classes jouables d'emblée (tous rôles couverts) ;
    **chaque victoire débloque la classe suivante** (basiques → avancées →
    uniques en récompense). Persisté dans `user://settings.cfg` (section
    `[progress]`). `is_unlocked()` filtre le draft (`TeamSelect` : cartes
    verrouillées grisées + 🔒, non sélectionnables par le joueur **ni l'IA** —
    pool partagé). `register_win()` appelé à la victoire (`Battle._check_end`),
    classe débloquée annoncée sur l'écran de fin (`_show_stats`).
54. ✅ **Vue diorama type Sword of Convallaria** (`Grid.gd`, rendu seul) : chaque
    case est un **bloc 3D** — faces latérales dessinées sur les bords de la carte
    (socle `EDGE_DEPTH`) et les dénivelés (`_draw_block_sides`/`_wall_depth`) →
    la carte ressemble à une maquette flottante. **Damier** 2 tons (`_top_color`),
    sommets de plateaux éclaircis (lecture de la hauteur). Cases agrandies
    (`TILE_W` 64→72, `HEIGHT_RISE` 16→18, `ISO_ORIGIN` recalée : bord droit
    60+320+432 = 812 ≤ 832). Gameplay et clics inchangés (mêmes formules).
55. ✅ **Style SoC poussé** (`Grid.gd` + `GameData.MAPS.palette`) : **palette de
    sol par biome** (herbe/Plaine, mousse/Forêt, pierre sable/Ruines, vase/Marais,
    roche bleutée/Hauts plateaux — damier `top_a`/`top_b`, parois terre
    `wall_l`/`wall_r`, repli sur les constantes si absente), **ombre portée**
    sous la maquette (3 losanges, `_draw_drop_shadow`), **liseré de lumière**
    sur les rebords avant (`_draw_top_rim`, après le fill sinon recouvert),
    **bande d'occlusion** sous les arêtes, **joints discrets** (`COLOR_SEAM`
    remplace la grille bleue), **micro-variation de teinte par case**
    (déterministe, `_top_color`). Palette chargée à chaque `_draw`
    (`_load_palette`). Rendu seul, gameplay/clics inchangés.
56. ✅ **Mode histoire — phase 1 : exploration libre** (`Overworld.gd/.tscn`) :
    bouton **Campagne** au menu titre (la Partie rapide reste intacte). Région 1
    « Vallée de Bruyère » en diorama iso : déplacement **continu** ZQSD/WASD/flèches
    (aucune case hors combat), hameau + prairie + étang + **Bois des Murmures**
    (zone des ennemis à l'est : plus on s'enfonce, plus c'est fort — 3 rôdeurs).
    Visuels d'exploration **dédiés** (vectoriels animés : marche, cape, yeux
    luisants, « ! » de poursuite), distincts du combat. Contact ennemi =
    transition « dimension de combat » (fondu violet + zoom) vers la scène de
    combat **inchangée** ; victoire → retour au monde, ennemi disparu à jamais ;
    défaite → menu. Équipe campagne v1 fixe (tank/archer/soigneur). Position +
    vaincus persistés (`GameData.campaign_*`, section `[campaign]`). Hooks
    minimaux : `Battle._campaign_won` (fin de combat) + `Title._on_campaign`.
    Phases suivantes prévues (une à la fois, sur demande) : dialogues à
    conséquences, compagnons, réputation, boss à mécaniques, autres mondes.
57. ✅ **Difficulté de campagne + mort permanente Hardcore** : nouvelle campagne →
    panneau de choix de difficulté (`Title._build_difficulty`, persisté
    `GameData.campaign_difficulty`, appliqué aux combats dans
    `Overworld._start_battle`). En **Hardcore uniquement** (façon BG3) : défaite
    totale = campagne effacée (position + vaincus, `Battle._check_end`).
58. ✅ **Vrais ennemis de campagne dessinés à la main** (demande forte : plus
    AUCUNE classe/sprite du JcJ dans les combats de campagne) : 3 créatures
    `hidden` dans `CLASSES` avec champ `figure` → dessin vectoriel dédié animé
    en continu (`Unit._draw_figure_*`, `_anim_phase`) : **Loup des Murmures**
    (mêlée rapide), **Rôdeur masqué** (distance + poison, masque d'os),
    **Le Veilleur des Murmures** (BOSS, `boss: true` = anneau élargi + barre de
    vie remontée) : spectre cornu animé (voile ondulant, ramure, yeux/rune
    luisants, braises en orbite), 115 PV, Étreinte des ronces (cleave) +
    Bond d'ombre (teleport_strike) + Furie du bois (rage). Règle posée : **un
    boss combat SEUL** (équipe de 1) — jamais accompagné. `Overworld.FOES`
    mis à jour (loup seul / meute / boss).
59. ✅ **Fuite + gestion de la sauvegarde de campagne** :
    - **Fuir** (`Battle._build_flee_button`/`_on_flee`) : bouton à côté de « Fin
      de tour », **uniquement en combat de campagne et jamais contre un boss**
      (`boss: true` filtré). Fuir = retour dans le monde, ennemi toujours vivant.
    - **Menu Campagne** : si une campagne existe (`GameData.has_campaign()`),
      panneau « Campagne en cours » (`Title._build_campaign_panel`) : difficulté,
      **date/heure de dernière sauvegarde** (`GameData.campaign_saved_at`, posé
      par `save_campaign()`), ennemis vaincus + boutons **Continuer** /
      **Recommencer** (double-clic de confirmation → efface via
      `clear_campaign()` et rouvre le choix de difficulté).
60. ✅ **Mode histoire — phase 2 : PNJ vivants + dialogues à conséquences**
    (`Overworld.NPCS`/`DIALOGUES`, data-driven : un PNJ/dialogue = des données).
    3 PNJ dessinés à la main dans le hameau (figures `Walker._draw_npc`) :
    **Maud l'herboriste** (vexée à jamais si on la rembarre, conseils sur le
    boss sinon), **Garin le bûcheron** (quête : nettoyer le bois → récompense =
    **déblocage du Lancier par l'exploration** ; refus possible puis retentable),
    **Sera l'étrangère** (secret : la couvrir → conseil tactique ; la dénoncer →
    `hide_flag`, **elle quitte le monde pour toujours** — prévu : retour en
    ennemie). Touche **E** à proximité (invite « E — Parler »), boîte de dialogue
    à choix cliquables, monde en pause pendant la discussion. Choix mémorisés
    dans `GameData.campaign_flags` (persistés `[campaign] flags`, effacés par
    `clear_campaign`). Règles d'entrée par PNJ : drapeaux + `foes_down`
    (ennemis vaincus). `_announce()` = bandeau doré (déblocage de classe).
61. ✅ **Barre de PV de boss façon Clair Obscur** (`Battle._build_boss_bar`) :
    nom du boss centré tout en haut + grande barre rouge (mise à jour dans
    `Battle._process`, masquée à sa mort). La petite barre au-dessus de sa tête
    est supprimée (`Unit._draw`, `show_hp_bar`). Décisions actées : **aucun
    objet utilisable en combat** (jamais) ; l'inventaire (exploration seule)
    attendra d'avoir des objets de quête/équipement. Prochaines phases validées,
    dans l'ordre : **création de personnage** (nom, sexe, apparence, classe —
    départ SEUL façon BG3, rééquilibrage des premiers combats), **compagnons**,
    **fiche de personnage**, **arbres de compétences** (2 choix par rangée),
    inventaire. Le déblocage par l'exploration (Garin → Lancier) alimentera la
    création de perso + compagnons.
62. ✅ **Création de personnage façon BG3** (`CharacterCreate.gd/.tscn` +
    `HeroFigure.gd`) : nouvelle campagne → après le choix de difficulté, écran
    de création : **nom** (LineEdit), **sexe** (♀/♂), **apparence** (3 designs
    par sexe — peau/coiffure, aperçu animé ×4 dessiné via `HeroFigure.draw_hero`,
    partagé avec l'exploration), **classe** parmi les débloquées (🔒 sinon ; les
    déblocages JcJ + exploration comptent). Héros persisté
    (`GameData.campaign_hero`, `[campaign] hero`). La campagne se joue avec
    **SON héros, SEUL au départ** (plus de trio fixe) : `Overworld._start_battle`
    envoie `[classe du héros]`, le Walker joueur est dessiné selon le perso créé
    (tunique teintée classe), l'unité porte son **nom en combat**
    (`Unit.display_name`, lu par `TurnManager`). Combats de l'orée rééquilibrés
    solo (loup seul, rôdeur seul) ; le boss exige une équipe (compagnons à
    venir). Vieille sauvegarde sans héros → redirection auto vers la création
    (`Overworld._ready`, garde `_draw`/`_ground`). Panneau « Campagne en cours »
    affiche le héros.
63. ✅ **Compagnons** (`GameData.COMPANIONS`, `campaign_party` persisté
    `[campaign] party`) : **Sera** (chasseuse — si on a couvert son secret) et
    **Garin** (lancier — après sa quête) se recrutent par dialogue (choix
    `recruit` + `party_flag` : le PNJ disparaît du hameau et devient suiveur).
    Dans le monde, les compagnons **marchent en file derrière le héros**
    (`_update_party` : chacun suit le précédent, kind "ally", figures PNJ
    réutilisées). En combat : équipe = héros + compagnons
    (`Overworld._start_battle` construit `player_team` + `campaign_battle_names`,
    noms affichés par unité). Le boss devient atteignable en équipe — dur,
    comme voulu.
64. ✅ **Export Web automatique** (`.github/workflows/web.yml`,
    `export_presets.cfg`, rendu `gl_compatibility` requis pour le Web) : chaque
    push sur `main` construit le jeu en HTML5 (Godot 4.3 headless, preset Web
    **sans threads** → aucun en-tête COOP/COEP requis) et le déploie sur
    **GitHub Pages** (`https://bodji27200-web.github.io/mon-jeux-video-/`) +
    artefact zip `jeu-web-itchio` (plan B itch.io privé). ⚠ Pages ne
    fonctionne que si le dépôt est **public** (le job deploy est en
    `continue-on-error` tant que c'est privé). Jouable Xbox/téléphone via
    navigateur (clavier+souris sur Xbox Edge).
65. ✅ **Fix « WebGL context lost » (campagne) + culling Overworld** : la carte
    rendait ~1500 cases + ~158 décors À CHAQUE image → le GPU du navigateur
    (Xbox Edge) saturait et lâchait. Ajout d'un **culling caméra**
    (`Overworld._visible_rect`, `VIEW_HALF`) : seules les cases/décors proches de
    la caméra sont dessinés (≈469 cases / 25 décors), `queue_redraw()` par image
    pour suivre le joueur, décors masqués via `visible`. Gameplay 100 % inchangé
    (coords, collisions, IA). Déployé sur GitHub Pages (public) :
    https://bodji27200-web.github.io/mon-jeux-video-/

### Compétences : plusieurs par classe
- Une classe a un tableau `actives` (0 à 3 compétences). L'ancien champ `active`
  (dict unique) reste supporté via `Unit.get_actives()`.
- Cooldown indépendant par compétence : `Unit.skill_cds[]` (aligné sur
  `get_actives()`), `skill_ready(index)`, `start_skill_cooldown(index)`.
- Ordre des `actives` = priorité IA (la première pertinente est jouée). Mettre
  la compétence « signature » / la plus situationnelle en premier.
- Ajouter une compétence : une entrée dans `actives` + (si type inédit) un `case`
  dans `Battle._use_skill`, `AI._plan_skill` ET `SimTest._use_skill`.

### Mécaniques data-driven additionnelles
- `on_hit` (classe) : applique un buff/debuff à chaque attaque (poison, gel,
  marque, affaiblissement).
- `mark_bonus_mult` (classe) : multiplie les dégâts contre une cible marquée.
- `drain_pct` (classe) : soigne l'attaquant d'un % des dégâts infligés.
- `max_summons` (active invoke) + `is_summon`/`summoner` (Unit) : invocations
  permanentes, comptées vivantes, ajoutées au TurnManager (`add_unit`).
- `summon_classes` (active invoke) : liste d'invocations à rôles distincts ;
  `Battle._next_summon_class` invoque celle dont l'invocateur a le moins
  d'exemplaires vivants (variété). `summon_class` (single) reste supporté.
- `immobilized` (buff) : `move_range()` renvoie 0 (Racines, durée 2 = 1 vrai tour).
- `hidden: true` (classe) : exclue de la sélection joueur et de la compo IA
  (ex : squelette).
- `unique: true` (classe) : classe « boss » ; max 1 par équipe (badge ★ dans le
  draft, filtrée dans `draft_pick`).
- `riposte` (buff) : contre-attaque auto au corps à corps ; `parade`
  (`block_next`) : bloque la prochaine attaque (consommé).
- `team_buff` / `team_debuff` (types) : applique un buff à toute l'équipe / un
  debuff à tous les ennemis (Barde). `retreat_shot` : tire puis recule.

### Fichiers clés
- `GameData.gd` (autoload) : dictionnaires CLASSES (stats + `role` + `active`),
  DIFFICULTIES, BUFFS, **TERRAIN** + sélections courantes
- `Grid.gd` : grille + utilitaires (coordonnées, BFS, **terrain** + ses effets)
- `Unit.gd` / `Unit.tscn` : unité data-driven (stats, PV, buffs, cooldown de
  compétence ; `action_range()`/`move_range()` effectifs)
- `TurnManager.gd` : ordre des tours
- `Battle.gd` (racine de `Main.tscn`) : orchestration, entrées joueur, victoire,
  exécution des compétences (`_use_skill`)
- `AI.gd` (`TacticalAI`) : décisions de l'IA + composition d'équipe
  (`compose_team`) + draft (`draft_pick`, respecte « 1 unique max ») + usage des
  compétences (`_plan_skill`)
- `TeamSelect.gd/.tscn` : écran de préparation (draft alterné, badge ★ uniques)
- `SkillFX.gd` : effet visuel d'attaque/compétence (cosmétique, auto-libéré)

### Ajouter du contenu (data-driven)
- **Nouvelle classe** : une entrée dans `CLASSES` (avec `role` pour la compo IA,
  `active` optionnel pour une compétence). Elle apparaît seule dans l'écran de
  sélection et la composition IA.
- **Nouvelle compétence** : un `active` dans la classe + un `case` dans
  `Battle._use_skill` (effet) et `AI._plan_skill` (quand l'IA l'utilise).
- **Nouveau buff/debuff** : une entrée dans `BUFFS` (champs `dmg_per_turn`,
  `heal_per_turn`, `dmg_taken_mult`, `dmg_dealt_mult`, `move_penalty`).

### Tester le jeu (validation par Claude, sans interface)
Godot n'est pas préinstallé, mais peut être téléchargé (v4.3, linux x86_64) pour
valider le code en mode headless — utile pour attraper les erreurs avant le test
humain :
- Erreurs de compilation : `godot --headless --editor --path . --quit`
- Erreurs d'exécution : lancer une scène, ex. `godot --headless --path . res://Main.tscn`
Ça ne remplace PAS le test visuel / jouabilité, qui reste fait par l'utilisateur.

### Objectif de distribution (à faire quand le jeu est prêt)
**Export HTML5 + itch.io privé** : jouer avec Eline (copine) depuis n'importe quel
appareil (iPhone, Xbox Series S via Edge, PC) sans poster le jeu publiquement.
- Godot exporte en HTML5/WebAssembly (File > Export > Web)
- Hébergement sur itch.io en mode "privé, lien seulement" → seuls ceux qui ont le
  lien peuvent y accéder
- Pas de multi réseau à coder : chacun joue sa session solo, ou on joue en local
  (partage d'écran). Le vrai multi en ligne (synchronisation réseau temps réel)
  serait une très grosse fonctionnalité — ne pas coder sans décision explicite.

### Reste à faire (idées futures, NE PAS coder sans demande)
Compléter les 20 classes, compétences actives dédiées, animations, vrais sprites,
équilibrage fin. Toujours data-driven, une étape à la fois, avec validation.

> Priorités globales (ne jamais sacrifier une priorité haute pour une basse) :
> 1. Gameplay tactique · 2. IA crédible · 3. Architecture robuste ·
> 4. Équilibrage · 5. Graphismes.

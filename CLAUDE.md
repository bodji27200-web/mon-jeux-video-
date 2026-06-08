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

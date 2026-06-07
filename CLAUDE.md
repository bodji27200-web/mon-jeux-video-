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

### Fichiers clés
- `GameData.gd` (autoload) : dictionnaires CLASSES (stats + `role` + `active`),
  DIFFICULTIES, BUFFS + sélections courantes
- `Grid.gd` : grille + utilitaires (coordonnées, BFS de déplacement)
- `Unit.gd` / `Unit.tscn` : unité data-driven (stats, PV, buffs, cooldown de
  compétence ; `action_range()`/`move_range()` effectifs)
- `TurnManager.gd` : ordre des tours
- `Battle.gd` (racine de `Main.tscn`) : orchestration, entrées joueur, victoire,
  exécution des compétences (`_use_skill`)
- `AI.gd` (`TacticalAI`) : décisions de l'IA + composition d'équipe
  (`compose_team`) + usage des compétences (`_plan_skill`)
- `TeamSelect.gd/.tscn` : écran de préparation (scène de démarrage)

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

### Reste à faire (idées futures, NE PAS coder sans demande)
Compléter les 20 classes, compétences actives dédiées, animations, vrais sprites,
équilibrage fin. Toujours data-driven, une étape à la fois, avec validation.

> Priorités globales (ne jamais sacrifier une priorité haute pour une basse) :
> 1. Gameplay tactique · 2. IA crédible · 3. Architecture robuste ·
> 4. Équilibrage · 5. Graphismes.

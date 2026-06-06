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

**Objectif immédiat : un prototype JOUABLE le plus vite possible.**
Premier combat fonctionnel : **1 Tank (joueur) vs 1 Archer (IA)**.

Ordre de priorité :
1. Grille fonctionnelle
2. Système de tours
3. Déplacement (Tank joueur)
4. Attaque (Archer IA)
5. IA de base
6. Sélection d'équipe avant combat
7. Ajout progressif des classes
8. Buffs/debuffs
9. Difficultés
10. Amélioration continue de l'IA

> Priorités globales (ne jamais sacrifier une priorité haute pour une basse) :
> 1. Gameplay tactique · 2. IA crédible · 3. Architecture robuste ·
> 4. Équilibrage · 5. Graphismes.

# Crédits assets

## Sprites de personnages
- **Pack** : "16x16 DungeonTileset II" par **0x72**
- **Licence** : CC0 (domaine public, aucune attribution requise)
- **Source** : https://0x72.itch.io/dungeontileset-ii
- Fichier : `dungeon_tileset.png` (spritesheet 512×512)

Les régions de chaque personnage sont définies dans `Unit.gd` (dictionnaire `SPRITES`).

## Audio (`assets/audio/*.wav`)
- **Générés intégralement** par script procédural (sinusoïdes + bruit), aucun
  asset externe. Domaine public.
- Bruitages : clic, coup mêlée/distance, critique, compétence, soin, mort,
  victoire, défaite. Musiques en boucle : `music_menu`, `music_battle`.
- Lus via l'autoload `Audio` (`Audio.gd`) sur les bus `SFX` / `Music`.

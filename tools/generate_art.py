#!/usr/bin/env python3
"""Génère toutes les images du jeu (pixel art 32 x 32) dans le dossier assets/.

Usage (depuis la racine du projet) :
    python3 tools/generate_art.py

Il faut Python 3, Pillow et numpy (pip install pillow numpy).

Tous les dessins sont dans tools/art32.py :
  - les TUILES (terre, or, roche, sols, salles) : bruit lissé + détails ;
  - les PERSONNAGES : assemblés avec des pièces ombrées (fonctions draw_...) ;
  - les OBJETS et ICÔNES (fonctions prop_... et icon_...).
Change un dessin dans art32.py, relance ce script, et Godot recharge l'image.
Tu peux aussi remplacer n'importe quel PNG de assets/ par ton propre dessin
(32 x 32 pixels) : mais relancer ce script l'écraserait.

(L'ancienne version en 16 x 16 reste disponible dans l'historique Git.)
"""

import art32

if __name__ == "__main__":
    art32.make_all()
    print("Images générées dans", art32.ASSETS)

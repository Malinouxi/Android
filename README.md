# Seigneur des Profondeurs

Prototype d'un jeu Android de **gestion de donjon** (vue de dessus, 2D), fait avec **Godot 4**.
Tu es le maître d'un donjon souterrain : tu fais creuser la roche, tu récoltes de l'or et,
plus tard, tu attireras des créatures pour défendre ton cœur contre des héros envahisseurs.

## Ce qui marche déjà

**Étape 1 — Creuser**
- Une carte générée au hasard : terre, roche indestructible, filons d'or, cœur du donjon.
- Outil **Creuser** : toucher une case de terre ou d'or la marque « à creuser » (cadre jaune). Toucher à nouveau enlève la marque.
- Les **ouvriers** (ronds verts) trouvent tout seuls la case marquée la plus proche, y vont (pathfinding A*) et la creusent.
- Bouton **« Invoquer un ouvrier »** : dépense de l'or pour avoir un ouvrier de plus.
- Caméra : **glisser un doigt** pour se déplacer, **pincer** pour zoomer (molette sur PC).

**Étape 2 — Salles**
- Barre d'outils à droite : choisis une salle, puis touche des cases de **sol creusé** pour la construire (prix par case).
- **Trésor** (25 or/case) : chaque case range 400 or. L'or des filons n'arrive plus tout seul : les ouvriers le
  mettent dans leurs poches (petit sac doré, 120 or max) et doivent **le porter au trésor**. Sans place au trésor,
  les ouvriers aux poches pleines ne creusent plus que la terre, et un message te prévient.
- **Champignonnière** (60 or/case) : des champignons y poussent tout seuls (nourriture des futures créatures).
- **Repaire** (40 or/case) : les lits où dormiront les créatures (étape 3).
- **Démolir** : retire une salle (pas de remboursement). L'or d'un trésor démoli va dans les autres trésors s'il y a de la place.
- L'or de départ (200) est gardé dans le cœur : on peut le dépenser, mais pas le remplir.

**Étape 3 — Créatures**
- Un **portail violet** se trouve quelque part sur la carte. Creuse un couloir pour le relier à ton donjon :
  dès qu'il est relié, une créature peut arriver toutes les 20 secondes.
- Chaque case de **Repaire est un lit** : jamais plus de créatures que de lits.
- Chaque créature vient seulement si ton donjon a assez de salles :

  | Créature | Il faut au moins | Salaire |
  |----------|------------------|---------|
  | Kobold   | 1 Repaire        | 15 or   |
  | Orque    | 4 Repaire + 4 Champignonnière | 40 or |
  | Sorcier  | 6 Repaire + 9 Trésor | 70 or |

- Leurs **besoins** : l'énergie baisse (elles vont dormir dans leur lit), la faim monte (elles vont manger un
  champignon), et toutes les 90 secondes c'est le **jour de paie** (prélevé automatiquement sur ton or).
- La **barre d'humeur** au-dessus de leur tête baisse si elles ont faim, sont épuisées, n'ont pas de lit ou ne sont
  pas payées. À zéro, la créature repart par le portail (« ! » rouge).
- Avec l'outil **Creuser**, touche une créature pour voir sa vie, son humeur, sa faim, son énergie et son salaire.

**Étape 4 — Héros et combat**
- Une **entrée grise** (porte de pierre) est placée loin du cœur et du portail. Les héros arrivent par là.
- Première **vague** au bout de 3 minutes, puis une toutes les 2 minutes (compte à rebours en haut).
  Vague 1 : 2 héros, puis un de plus à chaque vague (8 maximum).
- Les héros marchent vers ton cœur. S'il n'y a pas de couloir, **ils creusent eux-mêmes** (lentement),
  en préférant les couloirs existants. Ils ont un contour bleu foncé.

  | Héros | Vie | Particularité | Rançon | Dès la vague |
  |-------|-----|---------------|--------|--------------|
  | Aventurier | 90 | équilibré | 40 or | 1 |
  | Voleuse | 50 | rapide, frappe vite | 30 or | 2 |
  | Chevalier | 220 | très résistant | 80 or | 4 |

- Tes **créatures** attaquent les héros proches (les endormies ne se réveillent que si un héros est tout près).
  Le **Sorcier** attaque à distance (3 cases). Les **ouvriers** ne se battent pas : protège-les !
- Les créatures regagnent de la vie en dormant. Une barre rouge s'affiche sur toute unité blessée.
- Un héros vaincu rapporte une **rançon**, rangée au Trésor s'il y a de la place.
- Le **cœur** a 1000 points de vie. S'il tombe à 0, la partie est perdue : bouton « Rejouer ».

**Étape 5 — La main du maître**
- Outil **Main** : touche une créature ou un ouvrier pour le **ramasser** (8 au maximum).
  Touche ensuite une case de sol reliée au donjon pour **déposer** le dernier ramassé.
- Pratique pour envoyer tes créatures droit sur les héros, ou des ouvriers creuser loin du cœur.
- Une unité dans la main est figée : elle ne perd ni énergie ni humeur, et les héros ne la voient pas.
  Elle reçoit quand même son salaire. Une créature qui s'en va, furieuse, ne peut pas être retenue.

**Étape 6 — Graphismes**
- Tout est en **pixel art original** 16 × 16, affiché en 32 × 32 : tuiles (avec plusieurs variantes de terre,
  de roche et de sol), salles, cœur, portail, entrée, tas d'or, lits, champignons et les 7 personnages.
- Les personnages ont une petite **animation de marche** et se retournent selon leur direction.
  Les héros ont une **ombre bleue**, tes unités une ombre noire.

**Étape 7 — Pièges et portes**
- Trois défenses à poser sur le **sol des couloirs** (pas dans les salles), avec les nouveaux boutons :

  | Défense | Prix | Effet |
  |---------|------|-------|
  | Pointes | 80 or | 30 dégâts au héros qui marche dessus, se réarment en 2,5 s, à l'infini |
  | Rune | 120 or | Explose au passage d'un héros : 90 dégâts autour d'elle (près de 2 cases), puis disparaît |
  | Porte | 100 or | Bloque les héros, qui doivent la casser (300 PV). Tes unités passent librement |

- Les héros préfèrent **contourner** une porte s'il existe un autre chemin.
- Les pièges ne touchent que les héros. **Démolir** retire aussi une défense (sans remboursement).

**Étape 8 — Menu et sauvegarde**
- Le jeu s'ouvre sur un **menu principal** : *Continuer* (avec la vague et l'or de la sauvegarde),
  *Nouvelle partie*, *Quitter*.
- Bouton **Pause** en haut : *Reprendre*, *Sauvegarder*, *Sauvegarder et quitter* (retour au menu).
- **Sauvegarde automatique** toutes les minutes, et quand tu quittes l'appli, passes à une autre appli
  ou appuies sur « retour » sous Android.
- Quand le cœur est détruit, la sauvegarde est effacée : *Rejouer* ou *Menu principal*.
- Tout est enregistré : la carte creusée, les salles, l'or, les pièges et portes, les ouvriers,
  les créatures (vie, faim, énergie, humeur), les héros présents, les compteurs de paie et de vagues, la caméra.
  Les unités tenues dans la main sont reposées là où elles avaient été ramassées.
- Le fichier est `user://savegame.json` (un dossier privé du jeu). C'est du texte lisible : tu peux l'ouvrir
  pour voir comment la partie est enregistrée.

## Modifier les graphismes

Les images sont dans `assets/` (`tiles/`, `props/`, `units/`). Deux façons de les changer :

1. **Dessiner toi-même** : ouvre un PNG dans une appli de pixel art (Pixel Studio, LibreSprite, Aseprite…),
   garde la taille 16 × 16 et enregistre par-dessus. Godot recharge l'image tout seul.
2. **Modifier le script** `tools/generate_art.py` : chaque personnage y est dessiné avec des lettres
   (une lettre = une couleur), puis lance `python3 tools/generate_art.py` (il faut Pillow : `pip install pillow`).
   Attention : relancer le script écrase les PNG de `assets/`.

La liste des images utilisées par le jeu est dans `scripts/art.gd`.

## Démarrer

1. Télécharge **Godot 4.3** (ou plus récent, version « Standard », pas .NET) sur https://godotengine.org/download
2. Lance Godot, clique **Importer**, choisis le fichier `project.godot` de ce dossier.
3. Appuie sur **F5** (ou le bouton ▶) pour jouer sur ton ordinateur : la souris fait office de doigt.

## Tester sur un téléphone Android

1. Dans Godot : **Éditeur > Gérer les modèles d'exportation** et télécharge-les.
2. Installe **OpenJDK 17** et le **SDK Android** (le plus simple est de passer par Android Studio), puis
   indique leurs chemins dans **Éditeur > Paramètres de l'éditeur > Export > Android**.
3. Sur le téléphone : active les **options pour les développeurs** et le **débogage USB**, puis branche-le.
4. Dans Godot : **Projet > Exporter… > Ajouter… > Android**. Un bouton Android apparaît alors en haut à
   droite de l'éditeur pour lancer le jeu directement sur le téléphone.

Le fichier `export_presets.cfg` créé par Godot peut être ajouté à Git. **Ne mets jamais** tes clés de
signature (`.keystore`) ni leurs mots de passe sur Git.

## Organisation du code

```
project.godot              Configuration (rendu Compatibilité/OpenGL, paysage, souris = doigt)
scenes/menu.tscn           Le menu principal (première scène lancée), script : scripts/menu.gd
scenes/main.tscn           La scène de jeu : assemble les morceaux ci-dessous
scripts/main.gd            Chef d'orchestre : relie tout, outils, portail, paie, vagues, fin de partie
scripts/dungeon_map.gd     La grille : données, salles, or, dessin, pathfinding, creusage
scripts/unit.gd            Base commune de tout ce qui marche (héritage) : chemins, vie, combat
scripts/worker.gd          Un ouvrier (extends Unit) : IA à états (attente / marche / creuse / range l'or)
scripts/creature.gd        Une créature (extends Unit) : énergie, faim, humeur, sommeil, repas, départ
scripts/creatures.gd       Catalogue des créatures : nom, couleur, vitesse, salaire, salles exigées, combat
scripts/hero.gd            Un héros (extends Unit) : combat, sinon marche (et creuse) vers le cœur
scripts/heroes.gd          Catalogue des héros : vie, dégâts, vitesse, rançon, première vague
scripts/rooms.gd           Catalogue des salles : nom, prix, couleur, réglages
scripts/defenses.gd        Catalogue des pièges et portes : nom, prix, dégâts, points de vie
scripts/art.gd             Toutes les images du jeu (chargées depuis assets/)
scripts/save_game.gd       Lecture et écriture de la sauvegarde (JSON)
scripts/camera_controller.gd  Contrôles tactiles : glisser, pincer, toucher
scripts/hud.gd             Interface : or, ouvriers, barre d'outils, messages
assets/                    Les images PNG (pixel art 16 x 16)
tools/generate_art.py      Le script Python qui dessine toutes les images
```

Les scripts se parlent par **signaux** (`gold_changed`, `tapped`, `summon_pressed`, `tool_selected`, `left_dungeon`, `died`, `heart_destroyed`) : chaque morceau
reste simple et peut être modifié sans casser les autres.

**Pour expérimenter**, change les constantes en haut des fichiers : `WIDTH`/`HEIGHT` (taille de la carte),
`DIG_HITS` (difficulté à creuser), `GOLD_PER_HIT`, `SPEED` et `CARRY_CAPACITY` des ouvriers, `WORKER_COST`,
les prix et réglages des salles dans `scripts/rooms.gd`, les créatures dans `scripts/creatures.gd`,
les besoins dans `scripts/creature.gd`, les héros dans `scripts/heroes.gd`, la paie, les arrivées
et le rythme des vagues (`FIRST_WAVE_DELAY`, `WAVE_INTERVAL`) dans `scripts/main.gd`…

## Feuille de route

Avancer par petites étapes, chacune jouable :

1. ✅ **Creuser** : grille, marquage, ouvriers, or.
2. ✅ **Construire des salles** : *Trésor* (l'or doit y être porté), *Repaire*, *Champignonnière*.
3. ✅ **Créatures** : un portail en attire selon les salles construites ; elles ont des besoins
   (salaire, faim, sommeil) et partent si elles sont mécontentes.
4. ✅ **Héros** : des vagues d'aventuriers entrent par la surface et veulent détruire le cœur.
5. ✅ **Combat** : points de vie, attaques, rançons, fin de partie.
   ✅ La « main » du maître pour ramasser et déposer ses créatures. À venir : pièges, portes.
6. ✅ **Graphismes** : pixel art pour les tuiles, les objets et les personnages, animation de marche.
7. ✅ **Pièges et portes** : pointes, rune explosive, porte à casser.
8. ✅ **Menu principal, pause et sauvegarde** (automatique et manuelle).
9. **Sons**, niveaux avec objectifs, équilibrage.

Le jeu doit rester **original** : son propre nom, son univers, ses créatures et ses graphismes.

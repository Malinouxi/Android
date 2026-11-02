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

Aucune image n'est nécessaire : tout est dessiné avec des formes simples. On ajoutera des graphismes plus tard.

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
project.godot              Configuration (rendu mobile, paysage, souris = doigt)
scenes/main.tscn           La scène principale : assemble les morceaux ci-dessous
scripts/main.gd            Chef d'orchestre : relie tout, gère l'or
scripts/dungeon_map.gd     La grille : données, salles, or, dessin, pathfinding, creusage
scripts/worker.gd          Un ouvrier : petite IA à états (attente / marche / creuse / range l'or)
scripts/rooms.gd           Catalogue des salles : nom, prix, couleur, réglages
scripts/camera_controller.gd  Contrôles tactiles : glisser, pincer, toucher
scripts/hud.gd             Interface : or, ouvriers, barre d'outils, messages
```

Les scripts se parlent par **signaux** (`gold_changed`, `tapped`, `summon_pressed`, `tool_selected`) : chaque morceau
reste simple et peut être modifié sans casser les autres.

**Pour expérimenter**, change les constantes en haut des fichiers : `WIDTH`/`HEIGHT` (taille de la carte),
`DIG_HITS` (difficulté à creuser), `GOLD_PER_HIT`, `SPEED` et `CARRY_CAPACITY` des ouvriers, `WORKER_COST`,
les prix et réglages des salles dans `scripts/rooms.gd`…

## Feuille de route

Avancer par petites étapes, chacune jouable :

1. ✅ **Creuser** : grille, marquage, ouvriers, or.
2. ✅ **Construire des salles** : *Trésor* (l'or doit y être porté), *Repaire*, *Champignonnière*.
3. **Créatures** : un portail en attire selon les salles construites ; elles ont des besoins
   (salaire, faim, sommeil) et partent si elles sont mécontentes.
4. **Héros** : des vagues d'aventuriers entrent par la surface et veulent détruire le cœur.
5. **Combat** : points de vie, attaques, le joueur peut ramasser et déposer ses créatures.
6. **Niveaux et sauvegarde**, sons, vrais graphismes (pixel art 32×32), menus.

Le jeu doit rester **original** : son propre nom, son univers, ses créatures et ses graphismes.

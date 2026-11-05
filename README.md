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

**Étape 9 — Territoire, niveaux, sorts, recherche et atelier**

*Territoire revendiqué*
- Quand ils n'ont rien à creuser, les ouvriers **revendiquent** le sol creusé collé à ton territoire
  (halo rouge sous leurs pieds) : il prend la couleur de ton donjon (dalles rouge sombre).
- Salles, pièges et portes ne se construisent que sur **ton** territoire.

*Niveaux des créatures*
- Chaque coup porté rapporte de l'expérience ; la **Salle d'entraînement** aussi (5 XP/s, mais ça fatigue).
- Niveau 1 à 5 (petit chiffre jaune à gauche des barres) : +20 % de vie et de dégâts par niveau,
  mais +25 % de salaire.

*Sorts du maître* (panneau de gauche)
- La **mana** (max 200) se recharge toute seule : 0,25/s + 1/s par tranche de 120 cases de territoire,
  1,5/s au maximum.

  | Sort | Mana | Effet |
  |------|------|-------|
  | Soin | 30 | +60 PV à tes unités dans un rayon de près de 2 cases |
  | Éclair | 40 | 70 dégâts aux héros touchés (à découvrir) |
  | Hâte | 25 | Une de tes unités court 80 % plus vite pendant 15 s (à découvrir) |

*Bibliothèque et Atelier*
- Quand elles n'ont ni faim ni sommeil, les créatures **travaillent** : elles étudient à la **Bibliothèque**
  (les Sorciers 3 fois plus vite), fabriquent à l'**Atelier** (les Orques sont les meilleurs) ou s'entraînent.
- La recherche découvre, dans l'ordre : Atelier, Pointes, Salle d'entraînement, Éclair, Porte, Hâte, Rune.
  Ce qui n'est pas encore découvert est grisé avec un « ? ».
- Les pièges et portes ne s'achètent plus : l'**Atelier les fabrique** (le moins nombreux en priorité,
  9 en stock au maximum). Le bouton indique le stock (« Pointes x2 »). Démolir un piège le remet en stock.

**Étape 10 — Son**
- Une **ambiance de caverne** en boucle (bourdon grave, souffle d'air, gouttes d'eau, cloche lointaine).
- Plus de 30 **effets sonores** : pioche, or, pièces, revendication, construction, pièges, portail, coups
  (poing, épée, magie), morts, pointes, explosion, porte, cœur frappé, cor de guerre des vagues, sorts,
  passage de niveau, découverte, main du maître, clics, erreurs, défaite.
- Les sons sont **placés sur la carte** : ce qui se passe loin de l'écran s'entend moins fort.
- Un même son ne se répète pas trop vite (dix ouvriers qui creusent ne font pas un vacarme).
- **Musique** et **Effets sonores** se coupent dans le menu principal et le menu de pause (réglage mémorisé).

**Étape 11 — Confort tactile**
- **Peindre au doigt** : avec *Creuser*, une salle ou *Démolir*, glisse un doigt sur la carte pour traiter
  toutes les cases survolées. Avec *Creuser*, la première case décide : on marque tout, ou on démarque tout.
- Avec ces outils, on **déplace la vue avec deux doigts** (et on pince pour zoomer). Avec les autres outils
  (main, sorts, pièges), un doigt déplace la vue comme avant. Sur PC : clic droit maintenu pour déplacer la vue.
- **Mini-carte** en bas à gauche : tes unités en vert, les héros en rouge, la zone visible en blanc.
  Touche-la (ou glisse dessus) pour y emmener la vue.
- Bouton **x1 / x2 / x3** à côté de *Pause* pour accélérer le temps.

**Étape 12 — Nouveau contenu**
- **Prison** (60 or/case, à découvrir) : un héros vaincu y est **capturé** au lieu de mourir, s'il reste une
  cellule libre. Tu touches sa rançon, et chaque prisonnier interrogé donne **1 point de recherche par seconde**.
  Démolir sa cellule le libère : il s'évade et redevient un ennemi !
- **Temple** (100 or/case, à découvrir) : les créatures y **prient** (surtout les mécontentes) : +4 humeur/s,
  +3 PV/s, et +0,5 mana/s pour toi par créature en prière.
- Nouvelles créatures : **Araignée** (rapide, ses morsures ralentissent les héros de moitié pendant 3 s ;
  3 Repaire + 4 Prison) et **Démon** (300 PV, 26 dégâts, salaire 120 ; 8 Repaire + 4 Temple + 4 Entraînement).
- Nouveaux héros, dès la vague 3 : **Clerc** (soigne les héros proches toutes les 3 s) et **Archer**
  (tire à plus de 3 cases).

**Étape 13 — Campagne et maître rival**
- Menu principal : **Campagne** (8 niveaux) ou **Partie libre** (sans fin, comme avant).
- Chaque niveau a **sa propre carte**, son or de départ, le rythme de ses vagues et un **objectif**
  (affiché en jaune dans le panneau de gauche) :

  | Niveau | Objectif |
  |--------|----------|
  | 1. Premiers coups de pioche | Amasser 1500 or |
  | 2. La première invasion | Repousser 3 vagues |
  | 3. Une armée digne de ce nom | 5 créatures de niveau 2 ou plus |
  | 4. Le savoir est une arme | 5 découvertes |
  | 5. Les geôles | 3 héros prisonniers en même temps |
  | 6. Le maître voisin | Détruire le cœur rival |
  | 7. Le siège | Repousser 8 vagues |
  | 8. Le dernier rival | Détruire un cœur rival plus solide |

- Victoire : **1 à 3 étoiles** selon l'état de ton cœur (3 si plus de 90 % de vie, 2 si plus de 50 %).
  Le niveau suivant se débloque. Progression enregistrée dans `user://progress.cfg`.
- **Maître rival** (niveaux 6 et 8) : un donjon ennemi, loin du tien, avec son **cœur bleu** et son
  territoire teinté de bleu. Il envoie régulièrement des créatures (bleutées) de plus en plus nombreuses,
  qui creusent jusqu'à ton cœur. Dépose tes créatures près de son cœur (outil *Main*) : elles l'attaquent
  d'elles-mêmes. Tes ouvriers peuvent aussi lui voler son territoire en le revendiquant.

**Étape 14 — Plus de monstres et de héros**
- Des **capacités spéciales** génériques, réglables dans les catalogues (`creatures.gd`, `heroes.gd`) :
  armure, vol de vie, dégâts par ricochet, régénération, ralentissement, creusage rapide, casse-portes.
- Nouvelles créatures :

  | Créature | Il faut au moins | Capacité |
  |----------|------------------|----------|
  | Chauve-souris | 2 Repaire + 2 Champignonnière | très rapide, pas chère (salaire 10), fragile |
  | Golem | 4 Repaire + 4 Atelier | armure : -35 % de dégâts reçus, lent |
  | Vampire | 6 Repaire + 6 Prison | se soigne de 35 % des dégâts infligés |
  | Salamandre | 4 Repaire + 3 Entraînement | souffle de feu à distance, touche les héros autour |

- Nouveaux héros :

  | Héros | Dès la vague | Capacité |
  |-------|--------------|----------|
  | Nain | 2 | creuse 3 fois plus vite |
  | Magicienne | 4 | boules de feu à distance qui touchent plusieurs cibles |
  | Paladin | 6 | armure, se soigne en continu (3 PV/s) |
  | Géant | 8 | 520 PV, défonce les portes 4 fois plus vite |

**Étape 15 — Vue isométrique, éclairage et effets**
- **Vue isométrique** : le sol en losanges, les murs de terre, d'or et de roche en **blocs en relief**
  (dessus + deux faces ombrées). Personnages et objets (cœur, lits, portes, étagères...) restent debout
  et passent derrière les murs qui sont devant eux.
  Astuce de code : toute la logique reste « vue de dessus » ; seul le nœud `World` est incliné
  (voir `scripts/iso.gd`), et les personnages annulent cette inclinaison pour rester debout.
- **Éclairage** : le donjon est dans la pénombre. Le cœur rouge pulse (plus vite quand il est attaqué),
  le portail, l'entrée et le cœur rival brillent, des torches éclairent ton territoire, et les sorts
  et explosions font des éclairs. Réglage **Éclairage : oui/non** dans les menus (à couper sur un
  téléphone modeste).
- **Particules** : poussière en creusant et en construisant, pièces, étincelles des coups, fumée des
  morts et explosions, scintillement de la revendication, magie des sorts.
- **Effets** : chiffres de dégâts qui s'envolent (rouges sur tes unités), tremblement d'écran
  (explosions, éclair, porte enfoncée, cœur frappé), fondu au début de la partie.

**Étape 16 — Interface soignée et couloirs éclairés**
- **Police pixel** « Pixelify Sans » (licence libre OFL, voir `assets/fonts/OFL.txt`).
- **Thème** pierre et bois pour tous les boutons et panneaux (`scripts/ui.gd`, autoload `Ui`) :
  l'outil choisi a une **bordure dorée**.
- **Icônes** sur tous les outils et sorts, et à côté des compteurs (or, ouvriers, créatures, cœur, mana,
  vague).
- **Torches** : tout le territoire revendiqué s'éclaire, couloirs compris : une torche (brasero) toutes
  les 4 cases environ, posée au fur et à mesure que les ouvriers revendiquent. Leurs flammes vacillent.

**Étape 17 — Nouveau menu principal**
- En arrière-plan, un **donjon vivant** en vue isométrique : ouvriers qui creusent, lumière du cœur,
  torches, caméra qui dérive doucement.
- Un panneau à gauche : titre, personnages qui sautillent, grands boutons avec icônes
  (*Continuer* mis en valeur avec une bordure dorée), fenêtre **Réglages** (musique, effets, éclairage),
  crédits.
- L'interface en jeu reçoit enfin la police pixel et le style pierre et bois.

**Étape 18 — Attrapeurs, sacrifices et codex**
- Nouvelle créature : l'**Attrapeur de cauchemar** (2 Repaire + 2 Prison). Avec au moins un Attrapeur et
  une cellule libre, un héros vaincu tombe **assommé** (barre jaune) : un Attrapeur le porte en prison.
  Personne en 30 s ? Il meurt.
- **Sacrifices** : l'Atelier fabrique des **Autels de sacrifice** (2 au maximum). Outil **Sacrifier** :
  touche un prisonnier (poignard rouge), un Attrapeur le conduit à l'autel : 3 fois sa rançon en or.
- **Codex des règles**, depuis le menu principal et le menu de pause : articles + tableaux automatiques
  (créatures, héros, salles, défenses, sorts, recherche) + nouveautés de chaque version des règles.

**Étape 19 — Tout en 32 × 32**
- Toutes les images (94) sont redessinées en **32 × 32** : tuiles, 20 personnages (2 images de marche
  chacun), objets, pièges, coffres du Trésor et icônes. Générées par `tools/art32.py`.
- Le Trésor affiche des **coffres** qui se remplissent d'or.
- Le **codex** s'affiche enfin en plein écran.

**Étape 20 — Animations**
- Chaque personnage a 8 images : **marche** (4, avec balancement des bras), **respiration** à l'arrêt (2,
  chacun à son rythme) et **attaque** (élan puis frappe avec un trait de mouvement).
- L'attaque se joue à chaque coup, quand un héros creuse ou frappe une porte, et à chaque coup de pioche.
- À sa **mort**, un personnage bascule, tombe et s'efface.
- Les poses sont dans `tools/art32.py` (`ANIMATIONS`) ; Godot choisit l'animation dans `unit.gd` (`draw_sprite`).

**Étape 21 — Décor vivant et nouveau contenu**
- **Décor animé** : flammes des torches, tourbillon du portail, enclume qui frappe et lance des étincelles,
  bougies des autels, mannequins qui se balancent, et **cœur qui bat** (plus vite quand il est attaqué).
  Seules les couches qui contiennent un objet animé sont redessinées (6 images par seconde) :
  voir `ANIM_FPS` et `_animated()` dans `dungeon_map.gd`, et `ANIMATED_PROPS` dans `art.gd`.
- **Sorts visibles** : un éclair tombe du ciel sur chaque héros touché, des étincelles vertes montent des
  unités soignées, des traits de vitesse suivent les unités accélérées.
- Nouvelle salle : le **Cimetière** (recherche). Un héros mort y est enterré ; une minute plus tard, il
  se relève en **Revenant**, un squelette guerrier à ton service (il lui faut un lit libre).
- Nouveau héros : le **Champion du royaume**. Il mène une vague sur 5, se soigne, et son cri de guerre
  fait courir les héros autour de lui.
- Nouveau niveau de campagne (9) : **Le Champion du royaume**. Règles en version 1.3.

**Étape 22 — Héros en mission et Cerbère**
- La **Voleuse** est discrète (à moitié transparente, repérée seulement de tout près). Elle file au Trésor,
  vole jusqu'à 150 or et s'enfuit par l'entrée. Abattue, elle lâche un **sac d'or** que les ouvriers rapportent.
- Nouveau héros : le **Moine libérateur**. Il va à la Prison et crochète les cellules (barre bleue) :
  les prisonniers repartent au combat.
- Nouvelle créature : le **Cerbère** (2 Repaire + 6 Trésor). Il ne travaille pas : il **garde le Trésor**
  le plus proche, et flaire les Voleuses de loin. Règles en version 1.4.

**Étape 23 — Portail équilibré** (retour de partie : trop de Cerbères)
- Le portail préfère la **variété** : une espèce déjà présente N fois a (N + 1)² fois moins de chances
  de venir. Avec une Prison et aucun Attrapeur, l'Attrapeur a 4 fois plus de chances.
- **Cerbères limités** : un pour 6 cases de Trésor, 3 au maximum. Règles en version 1.5
  (réglages `PORTAL_BALANCE`, `CATCHER_PRIORITY`, `CERBERUS_TREASURY_TILES`, `MAX_CERBERUS`).

**Étape 24 — Les ouvriers construisent**
- Poser une salle, un piège, une porte ou un autel crée un **chantier** (objet en transparence, barre orange).
  Un ouvrier vient le construire (coups de marteau) ; la case ne sert qu'une fois terminée.
- Durée par case selon l'importance de l'objet (`build_time` dans `rooms.gd` et `defenses.gd`) : de 4 s
  (coffre, pointes) à 12 s (autel du Temple, autel de sacrifice). Réglage global : `BUILD_TIME_FACTOR`.
- Les ouvriers construisent avant de creuser. Démolir un chantier rend l'or ou le piège. Règles 1.6.

**Étape 27 — Prototype 3D** (bouton « Prototype 3D » du menu)
- Une scène à part (`scenes/proto_3d.tscn`, `scripts/proto_3d.gd`) : la carte du niveau 1 en vrais
  blocs 3D, avec les mêmes images pixel art plaquées sur le sol et les murs. Cœur en gemme qui tourne,
  portail en anneau, torches et ouvriers en images qui font face à la caméra (Sprite3D).
- Un doigt pour tourner autour du cœur, deux doigts pour zoomer. Le jeu 2D n'est pas modifié.

**Étape 26 — Décorations**
- Quand ils n'ont plus rien à faire, les ouvriers fabriquent des **tableaux** et des **tapisseries**
  (plaqués sur les faces visibles des murs) et des **tapis** (dans les salles). Durées et limites dans
  `rules.gd` (`DECORATION_TIME`, `MAX_DECORATIONS`) ; les décorations rendent les créatures plus heureuses
  (`DECORATION_MOOD`). Règles 1.7.

**Étape 25 — Codex illustré**
- Correction : la liste du codex (et celle des niveaux) défile au doigt dans les deux sens. Les boutons
  laissent passer le glissement (`MOUSE_FILTER_PASS`), et le texte des articles est dans un ScrollContainer.
- Des **images** en haut de chaque article (clé `"images"` dans `codex_content.gd`) et une colonne
  d'images dans tous les tableaux (créatures, héros, salles, défenses, sorts, recherche). Les tableaux
  des salles et des défenses montrent aussi le temps de construction.

## APK Android (construit par GitHub)

À chaque push, GitHub construit l'APK tout seul (fichier `.github/workflows/android-apk.yml`,
avec Godot 4.7.2 et le réglage d'export `export_presets.cfg`).

- **Où le trouver** : sur la page GitHub du dépôt, rubrique **Releases**, le build le plus récent.
  Aussi dans l'onglet **Actions** > le dernier build > **Artifacts**.
- **L'installer** : ouvre la Release depuis ton téléphone, télécharge `SeigneurDesProfondeurs.apk`
  et ouvre-le. Android demande d'autoriser les « sources inconnues » pour ton navigateur.
- **Mises à jour** : par défaut, chaque build est signé avec une nouvelle clé de **débogage**.
  Android refuse alors de remplacer l'appli installée : désinstalle-la d'abord.
  Pour garder la même clé (et la sauvegarde) d'un build à l'autre :
  1. crée une clé une seule fois sur ton ordinateur :
     `keytool -genkeypair -keystore jeu.keystore -alias jeu -keyalg RSA -keysize 2048 -validity 10000`
  2. convertis-la en texte : `base64 -w0 jeu.keystore` ;
  3. sur GitHub : *Settings > Secrets and variables > Actions*, ajoute trois secrets :
     `ANDROID_KEYSTORE_BASE64` (le texte), `ANDROID_KEYSTORE_ALIAS` (`jeu`) et
     `ANDROID_KEYSTORE_PASSWORD` (ton mot de passe).
  Ne mets jamais le fichier `.keystore` lui-même dans le dépôt.

## Faire évoluer les règles (retours des joueurs)

1. **Note les retours** : ce qui est trop facile, trop dur, pas clair, ou les idées.
2. **Changer un chiffre** (prix, durée, salaire, vagues...) :
   - réglages généraux : `scripts/rules.gd` (tout est commenté) ;
   - créatures, héros, salles, pièges, sorts, recherche : leurs catalogues dans `scripts/`.
     Le codex se met à jour tout seul.
3. **Expliquer une règle** : ajoute ou modifie un article dans `scripts/codex_content.gd`.
4. **Noter le changement** : ajoute une ligne dans `CHANGELOG` de `scripts/rules.gd` et augmente `VERSION`.
   Les joueurs la verront dans *Codex > Nouveautés*.
5. **Une règle vraiment nouvelle** (un nouveau comportement) demande du code : décris-la, et on l'ajoute
   ensemble au bon endroit.

## Modifier les sons

Les sons sont dans `assets/sounds/` (WAV). Ils sont fabriqués par `tools/generate_sounds.py` à partir de
formules (ondes, bruit, enveloppes) : change les chiffres et relance `python3 tools/generate_sounds.py`
(il faut numpy : `pip install numpy`). Tu peux aussi remplacer un WAV par ton propre enregistrement
(garde le même nom). La liste des sons utilisés est dans `scripts/sound.gd`.

## Modifier les graphismes

Les images sont dans `assets/` (`tiles/`, `props/`, `units/`, `icons/`), toutes en **32 × 32 pixels**.

1. **Dessiner toi-même** : ouvre un PNG dans une appli de pixel art (Pixel Studio, LibreSprite, Aseprite…),
   garde la taille 32 × 32 et enregistre par-dessus. Godot recharge l'image tout seul.
2. **Modifier le générateur** `tools/art32.py`, puis lancer `python3 tools/generate_art.py`
   (il faut Pillow et numpy : `pip install pillow numpy`). Attention : ça écrase les PNG de `assets/`.
   - tuiles : fonctions `earth_tile`, `rock_tile`, `room_...` (bruit lissé + détails) ;
   - personnages : fonctions `draw_...`, assemblées avec des pièces ombrées (`Sprite.part`) ;
   - objets et icônes : fonctions `prop_...` et `icon_...`.

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
scripts/spells.gd          Catalogue des sorts : mana, effets, recharge de la mana
scripts/research.gd        La recherche : liste des découvertes et progression
scripts/art.gd             Toutes les images du jeu (chargées depuis assets/)
scripts/iso.gd             La vue isométrique : transformation du monde, personnages debout
scripts/fx.gd              Effets visuels : particules, chiffres de dégâts, tremblements, éclairs
scripts/save_game.gd       Lecture et écriture de la sauvegarde (JSON)
scripts/levels.gd          Les niveaux de la campagne (objectifs, réglages) et la progression
scripts/rules.gd           LES RÈGLES : réglages généraux, version des règles, nouveautés
scripts/codex_content.gd   Les textes du codex (à compléter selon les retours des joueurs)
scripts/codex.gd           L'écran du codex (articles + tableaux automatiques)
scripts/level_select.gd    L'écran de choix des niveaux (scène scenes/level_select.tscn)
scripts/sound.gd           Le son (autoload « Sound ») : effets, ambiance, réglages
scripts/ui.gd              Le thème de l'interface (autoload « Ui ») : police, boutons, panneaux
scripts/camera_controller.gd  Contrôles tactiles : glisser, pincer, toucher, peindre
scripts/minimap.gd         La mini-carte (en bas à gauche)
scripts/hud.gd             Interface : or, ouvriers, barre d'outils, messages
assets/                    Les images PNG (pixel art 32 x 32) et les sons WAV (assets/sounds/)
tools/generate_art.py      Lance la génération de toutes les images
tools/art32.py             Les dessins en 32 x 32 (tuiles, personnages, objets, icônes)
tools/generate_sounds.py   Le script Python qui fabrique tous les sons (WAV)
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
9. ✅ **Territoire, niveaux des créatures, sorts, bibliothèque et atelier** (mécaniques classiques du
   genre, conçues pour ce jeu et le tactile).
10. ✅ **Son** : ambiance et effets sonores originaux, positionnés sur la carte.
11. ✅ Confort tactile, nouveau contenu, campagne de 8 niveaux, maître rival.
12. Équilibrage, tutoriel, export APK.

Le jeu doit rester **original** : son propre nom, son univers, ses créatures et ses graphismes.

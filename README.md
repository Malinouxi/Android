# Seigneur des Profondeurs

Jeu de **gestion de donjon** pour **Android** (et jouable dans un navigateur), fait avec **Godot 4**.
Tu es le maître d'un donjon souterrain : tes ouvriers creusent la roche et récoltent l'or, tu bâtis des
salles qui attirent des créatures, et tu défends ton **cœur** contre les vagues de héros du royaume.

Le jeu s'affiche en **3D** (vue de dessus inclinée, modèles low-poly faits dans Blender) ; une vue
**isométrique 2D** en pixel art reste disponible dans les Réglages (« Vue 3D : non »).

Les chiffres ci-dessous viennent du code ; en cas de doute, la référence est le **codex** du jeu (menu
principal ou pause), dont les tableaux sont tirés automatiquement des catalogues.

## Sommaire

- [Le jeu en bref](#le-jeu-en-bref)
- [Commandes](#commandes)
- [Économie et salles](#économie-et-salles)
- [Créatures](#créatures)
- [Héros et vagues](#héros-et-vagues)
- [Défenses et combos](#défenses-et-combos)
- [Sorts et recherche](#sorts-et-recherche)
- [Campagne, partie libre et sauvegarde](#campagne-partie-libre-et-sauvegarde)
- [Graphismes, effets et réglages](#graphismes-effets-et-réglages)
- [Version web](#version-web-jouer-dans-le-navigateur) · [APK Android](#apk-android-construit-par-github)
- [Modifier le jeu](#faire-évoluer-les-règles-retours-des-joueurs) · [Démarrer](#démarrer) · [Organisation du code](#organisation-du-code)
- [Historique du développement](#historique-du-développement)

## Le jeu en bref

1. **Creuser** : marque la terre et les filons d'or ; les ouvriers creusent, portent l'or au Trésor et
   **revendiquent** le sol creusé (ton territoire, éclairé de torches). On ne bâtit que sur son territoire.
2. **Bâtir** : chaque salle se pose d'un bloc, à la taille de son objet, et les ouvriers la construisent.
3. **Attirer** : relie le **portail violet** à ton donjon ; une créature arrive toutes les 20 s si un lit
   est libre et si tu as les salles qu'elle exige. Elles ont faim, sommeil, un salaire et une humeur.
4. **Défendre** : les héros entrent par l'**entrée grise** et marchent sur ton cœur (1000 PV), en
   creusant s'il le faut. Tes créatures, tes pièges et tes sorts les arrêtent. Cœur détruit : partie perdue.

## Commandes

- **Un doigt** : toucher (grandes salles, Main, sorts, pièges) ou peindre en glissant (Creuser, Démolir,
  salles d'une case). Avec les outils « toucher », un doigt qui glisse déplace la vue.
- **Deux doigts** : déplacer la vue, pincer pour zoomer ; en 3D, tourner les deux doigts fait pivoter.
  Sur PC, la souris fait office de doigt (clic droit ou molette maintenus pour déplacer, molette pour zoomer).
- **Interface** (HUD « pierre et fer ») : en haut, le médaillon du Seigneur (il parle et donne des
  conseils quand on le touche), l'or et le Trésor, la mana, les créatures et les lits, les ouvriers, le
  cœur, la vague et la paie, **+ ouvrier** (100 or), la vitesse **x1/x2/x3** et la **pause**. À gauche,
  les catégories d'outils : Actions, Salles, **Antres**, Défenses, **Sorts**, **Pouvoirs**. En haut à droite,
  l'objectif. En bas, la fiche de la créature touchée, les outils et le journal (30
  messages, flèches pour remonter).
- **Actions** : Creuser, **Se diriger** (glisser un doigt déplace la vue, sans rien toucher), **Main** (ramasser jusqu'à 8 unités et les déposer ailleurs ; déposée sur le
  portail, une créature est renvoyée), Démolir, Sacrifier.
- **Pause** : Reprendre, Sauvegarder, Codex des règles, Sauvegarder et quitter.

## Économie et salles

- Départ : 3 ouvriers et de l'or rangé dans le cœur (200 en partie libre, 300 à 700 en campagne).
- Les ouvriers portent au plus 120 or ; sans place au Trésor, l'or reste dans leurs poches.
- Les filons sont **plus riches loin du cœur** ; 2 **gemmes** inépuisables par carte ; la **roche** se
  creuse lentement et cache parfois un trésor (100 à 300 or).
- **Jour de paie** toutes les 90 s : les salaires sont prélevés, et ton territoire rapporte 1 or par case.

| Salle | Prix (salle entière) | Taille | À quoi elle sert |
|-------|----------------------|--------|------------------|
| Trésor | 50 | 1 x 2 | range 400 or par case |
| Repaire | 40 | 1 x 1 | un lit (une créature) |
| Champignonnière | 50 | 1 x 1 | des champignons poussent (nourriture) |
| Bibliothèque | 300 | 2 x 3 | les créatures étudient : la **recherche** avance |
| Atelier | 260 | 2 x 2 | fabrique pièges, portes et autels |
| Entraînement | 320 | 2 x 4 | les créatures gagnent de l'expérience (niveau 1 à 5) |
| Prison | 200 | 2 x 2 | 4 cellules : héros capturés (rançon, recherche, sacrifice) |
| Temple | 450 | 2 x 3 | prière : humeur, soins et mana |
| Cimetière | 70 | 1 x 1 | un héros mort y est enterré et se relève en Revenant 60 s plus tard |

**Les antres** (onglet Antres, règles 2.7, tout à découvrir par la recherche) : chacune attire sa créature.

| Antre | Prix | Taille | À quoi elle sert |
|-------|------|--------|------------------|
| Taverne | 220 | 2 x 2 | sous 75 d'humeur, une créature boit une chope (un champignon) : +5 humeur/s, -10 % sur sa paie suivante, elle titube 25 s |
| Infirmerie | 240 | 2 x 2 | sous 60 % de vie, une créature s'y couche : 10 PV/s (20 avec une Goule au chevet) |
| Hôtel des monnaies | 400 | 2 x 2 | toutes les 30 s, 2 % d'intérêts sur le Trésor (50 or au plus par Hôtel) ; on y frappe 1 or/s |
| Chambre de torture | 300 | 2 x 2 | avec des prisonniers : 1,5 point de recherche/s, la vague suivante avouée (une fois par vague), prisonnier converti après 45 s |
| Poste de garde | 150 | 1 x 2 | le guetteur voit à 8 cases : démasque les Voleuses, chasse l'éclaireur sans rapport, alarme (10 cases) |
| Puits de mana | 500 | 2 x 2 | +50 mana maximum par puits (3 au plus) ; méditer donne 0,6 mana/s |
| Crypte | 280 | 2 x 2 | 2 places : une créature morte se relève 60 s plus tard pour 60 mana, un niveau plus bas, trait « Revenue » |

Seules les salles « Trésor, Repaire, Champignonnière, Bibliothèque » sont là dès le départ ; les autres
se découvrent par la recherche. Les ouvriers désœuvrés décorent (tapis, tableaux, tapisseries,
chandeliers) : un donjon décoré rend les créatures plus heureuses.

## Créatures

Chaque créature arrive avec 1 ou 2 **traits de caractère** (Avare, Peureuse, Bagarreuse, Rancunière,
Pieuse, Gourmande, Insomniaque, Studieuse, Paresseuse, Coquette, Solitaire, Robuste : voir le codex).
Le portail préfère la variété. Les conditions comptent des **salles entières** (un lit = une salle de
Repaire, une Bibliothèque 2 x 3 = une salle).

| Créature | Il faut au moins | Salaire | Particularité |
|----------|------------------|---------|---------------|
| Kobold | 1 Repaire | 15 | rapide, bon marché |
| Chauve-souris | 2 Repaire + 2 Champignonnière | 10 | très rapide, fragile |
| Orque | 4 Repaire + 4 Champignonnière | 40 | solide ; le meilleur artisan de l'Atelier |
| Attrapeur de cauchemar | 2 Repaire + 1 Prison | 25 | porte les héros assommés en prison (ou à l'autel) |
| Araignée | 3 Repaire + 1 Prison | 30 | ses morsures ralentissent |
| Cerbère | 2 Repaire + 3 Trésor | 35 | garde le Trésor, flaire les Voleuses (1 pour 3 Trésors, 3 au plus) |
| Golem | 4 Repaire + 1 Atelier | 50 | armure (-35 % de dégâts), lent |
| Salamandre | 4 Repaire + 1 Entraînement | 45 | souffle de feu à distance, touche autour de la cible |
| Sorcier | 6 Repaire + 1 Bibliothèque | 70 | attaque à distance, étudie 3 fois plus vite (2 par Bibliothèque, 6 au plus) |
| Vampire | 6 Repaire + 2 Prison | 85 | vol de vie (2 par Prison, 4 au plus) |
| Démon | 8 Repaire + 1 Temple + 1 Entraînement | 120 | le plus fort (1 par Temple, 3 au plus) |
| Revenant | un Cimetière (héros enterré) | 10 | mort-vivant : ni lit, ni faim, ni sommeil (6 au plus) |
| Colosse ancien | vaincre le Colosse endormi | 60 | géant de pierre, unique |
| Renégat | sort Conversion sur un prisonnier | 20 | garde l'allure du héros qu'il était |
| Gobelin brasseur | 2 Repaire + 1 Taverne | 20 | la Taverne lui fait deux fois plus d'effet ; bon artisan |
| Goule rebouteuse | 3 Repaire + 1 Infirmerie | 45 | soigne ses voisines (8 PV toutes les 3 s), double les soins de l'Infirmerie (2 par Infirmerie, 4 au plus) |
| Diablotin argentier | 2 Repaire + 1 Hôtel des monnaies | 25 | vole 3 or par coup porté, frappe la monnaie 3 fois plus vite (3 par Hôtel, 6 au plus) |
| Bourreau | 4 Repaire + 1 Chambre de torture | 75 | dégâts doublés contre un héros sous 30 % de vie, torture 2 fois plus vite (2 par Chambre, 3 au plus) |
| Gargouille | 1 Repaire + 1 Poste de garde | 35 | pierre (ni lit, ni faim), armure, flaire les Voleuses, monte toujours la garde (2 par Poste, 4 au plus) |
| Oracle des ombres | 4 Repaire + 1 Puits de mana | 80 | attaque à distance, médite 3 fois mieux (2 par Puits, 3 au plus) |
| Nécromancien | 5 Repaire + 1 Crypte | 90 | attaque à distance ; les héros qu'il abat se relèvent 30 s pour toi ; veille la Crypte (1 par Crypte, 2 au plus) |

Faim, fatigue, lit manquant ou salaire impayé font baisser l'**humeur** ; à zéro, la créature repart
par le portail. Les créatures prient au Temple, étudient, fabriquent ou s'entraînent quand tout va bien,
et fréquentent les antres (Taverne, Infirmerie, Poste de garde...).

**Au combat** (règles 2.8), elles choisissent leur cible (d'abord qui frappe le cœur, puis Clercs et
Exorcistes, pillards chargés d'or, héros presque morts), **appellent à l'aide** leurs voisines à 10 cases,
accourent toutes quand le **cœur** est frappé (même endormies), et les tireurs (Sorcier, Oracle,
Nécromancien, Salamandre) **reculent** d'un pas après chaque tir quand on les colle. Les **ouvriers**
fuient un héros à moins de 3 cases, puis reprennent le travail. Réglages : `TARGET_*`, `HELP_*`,
`HEART_CALL_*` et `WORKER_*` dans `rules.gd` ; test sans écran : `godot --headless --path . -s res://tools/ai_test.gd`.

En 3D, chaque activité a sa **pose** (`Creature.pose()`, animée par `_animate_pose` dans `view_3d.gd`) :
elles dorment allongées dans leur lit, se couchent à l'Infirmerie, croquent un champignon, trinquent
(chope en main) puis titubent, lisent un grimoire, forgent, prient à genoux, fouettent au chevalet,
montent la garde en scrutant les couloirs, méditent en lévitation, incantent au-dessus des sarcophages.

## Héros et vagues

- Première vague au bout de **7 minutes au moins**, puis une toutes les 100 à 200 s selon le niveau (120 s en partie libre).
  Vague *n* : *n* + 1 héros (8 au plus), tirés parmi ceux qui sont déjà apparus.
- Une vague de 4 héros ou plus se divise en **escouades** (gros de la troupe, flanqueurs, sapeurs) ; dès
  la vague 3, une vague sur deux a un **objectif** (piller le Trésor, libérer les prisonniers, saccager la
  Bibliothèque, chasser les ouvriers, abattre ta meilleure créature). À la vague 5, une **seconde entrée**
  s'ouvre. Un **éclaireur** vient parfois repérer tes pièges.
- Sous 25 % de vie, un héros **fuit** ; s'il s'échappe, il revient une ou deux vagues plus tard en
  **vétéran** nommé, plus fort, qui se souvient de tes pièges.
- Dès la vague 4, les héros **résistent à la magie** (+4 % par vague, 40 % au plus, +10 % par rang de vétéran).

| Héros | Dès la vague | Particularité |
|-------|--------------|---------------|
| Aventurier | 1 | équilibré |
| Voleuse | 2 | discrète, vole l'or du Trésor puis s'enfuit |
| Nain | 2 | creuse 3 fois plus vite ; se tire des éboulements |
| Clerc | 3 | soigne ses alliés et les libère de la Toile et de la Terreur |
| Archer | 3 | tire de loin |
| Moine libérateur | 3 | ouvre les cellules de la Prison ; insensible à la Terreur |
| Chevalier | 4 | très résistant |
| Magicienne | 4 | boules de feu en zone ; insensible à la Toile |
| Exorciste | 5 | dissipe tes sorts autour de lui (au moins un par vague dès la 8) |
| Paladin | 6 | armure, se soigne ; insensible à la Terreur |
| Géant | 8 | 520 PV, défonce les portes ; insensible à la Toile |
| Champion du royaume | une vague sur 5 | chef des héros, cri de guerre, ne fuit jamais |

Un héros vaincu rapporte une **rançon** (au Trésor). Avec un Attrapeur et une cellule libre, il tombe
**assommé** et finit en Prison : il fait avancer la recherche, peut être **sacrifié** sur un autel (3 fois
sa rançon) ou **converti**. Les profondeurs cachent aussi un **Colosse endormi**, un **lac de lave** et une
**ruine oubliée** (avec ses Spectres) : creuser près d'eux donne un indice.

## Défenses et combos

Les pièges, portes et autels sont **fabriqués à l'Atelier** (9 en stock au plus, 2 autels) puis posés
par un ouvrier sur le sol d'un couloir ; le Brasero s'achète en or.

| Défense | Coût | Effet |
|---------|------|-------|
| Pointes | 80 points d'Atelier | 30 dégâts, se réarment en 2,5 s |
| Rune explosive | 120 points d'Atelier | 90 dégâts autour d'elle, puis disparaît |
| Porte | 100 points d'Atelier | 300 PV ; les héros doivent la casser, tes unités passent |
| Autel de sacrifice | 150 points d'Atelier | un Attrapeur y conduit le prisonnier désigné (outil Sacrifier) |
| Brasero | 80 or | éclaire et apaise les créatures à 3 cases |

**10 combos secrets** (le codex en donne un indice tant qu'ils ne sont pas découverts) : Rune de feu,
Réaction en chaîne, Pointes ardentes, Empalement, Détonation, Porte hérissée, Porte électrifiée, Rune
engluée, Brasier runique, Traînée de feu.

## Sorts et recherche

La **mana** (200 au plus) se recharge seule, plus vite avec un grand territoire (0,25 à 1,5 par seconde) ;
la prière au Temple en donne aussi.

| Sort | Onglet | Mana | Effet |
|------|--------|------|-------|
| Soin | Sorts | 30 | +60 PV à tes unités dans la zone |
| Éclair | Sorts | 40 | 70 dégâts aux héros touchés |
| Hâte | Sorts | 25 | une unité court 80 % plus vite 15 s |
| Toile | Sorts | 35 | les héros de la zone sont 2 fois plus lents 8 s |
| Brasier | Sorts | 45 | le sol de la zone brûle 6 s |
| Terreur | Sorts | 50 | les héros de la zone fuient vers l'entrée 6 s |
| Effondrement | Sorts | 60 | un couloir redevient de la terre ; 120 dégâts à ce qui s'y trouve |
| Possession | Sorts | 55 | 15 s : la créature frappe +50 % et va où tu touches (ordres gratuits) |
| Fouet | Pouvoirs | 20 | une unité travaille 2 fois plus vite 30 s (une créature perd un peu d'humeur) |
| Festin | Pouvoirs | 60 | plus de faim pour personne, +15 d'humeur |
| Œil du maître | Pouvoirs | 30 | montre la prochaine vague, démasque les Voleuses, révèle les secrets proches |
| Invocation | Pouvoirs | 40 | un ouvrier fantôme pendant 60 s (4 au plus) |
| Transmutation | Pouvoirs | 50 | 150 or au Trésor |
| Relever les morts | Pouvoirs | 50 | (Cimetière) les tombes se relèvent aussitôt, sinon un Revenant pour 45 s |
| Conversion | Pouvoirs | 70 | (Prison) un prisonnier rejoint ton donjon |
| Sanctuaire | Pouvoirs | 45 | (Temple) tes unités proches prennent 40 % de dégâts en moins 20 s |
| Rappel | Pouvoirs | 40 | toutes tes créatures reviennent autour du cœur |

**La recherche** (Bibliothèque, prisonniers) découvre, dans l'ordre : Atelier, Pointes, Fouet, Prison,
Toile, Salle d'entraînement, Festin, Éclair, Porte, Œil du maître, Temple, Invocation, Hâte, Conversion,
Brasier, Rune explosive, Cimetière, Relever les morts, Sanctuaire, Terreur, Transmutation, Rappel,
Possession, Effondrement (`scripts/research.gd`). Ce qui n'est pas découvert est grisé (« ? »).

## Campagne, partie libre et sauvegarde

Menu principal : **Continuer**, **Campagne** (9 niveaux), **Partie libre** (sans fin), **Codex des
règles**, **Réglages**, **Quitter** (absent de la version web).

| Niveau | Objectif |
|--------|----------|
| 1. Premiers coups de pioche | amasser 1500 or |
| 2. La première invasion | repousser 3 vagues |
| 3. Une armée digne de ce nom | 5 créatures de niveau 2 ou plus |
| 4. Le savoir est une arme | 7 découvertes |
| 5. Les geôles | 3 héros prisonniers en même temps |
| 6. Le maître voisin | détruire le cœur d'un maître rival |
| 7. Le siège | repousser 8 vagues |
| 8. Le dernier rival | détruire un cœur rival plus solide |
| 9. Le Champion du royaume | abattre le Champion (il mène la vague 3) |

- Victoire : 1 à 3 étoiles selon l'état du cœur ; le niveau suivant se débloque (`user://progress.cfg`).
- Le **maître rival** (niveaux 6 et 8) envoie ses créatures bleutées creuser jusqu'à toi ; dépose tes
  créatures près de son cœur pour l'attaquer, et vole son territoire en le revendiquant.
- **Sauvegarde** automatique toutes les minutes, à la mise en arrière-plan sous Android et (version
  web) au changement d'onglet ; aussi depuis la pause. Fichier `user://savegame.json` (texte lisible).
  Une partie perdue efface la sauvegarde.

## Graphismes, effets et réglages

- **3D** (`scripts/view_3d.gd`) : la carte devient des blocs (sol pavé, remparts de pierre taillée),
  personnages et mobilier sont des modèles low-poly **faits dans Blender** (`assets/models/`). Les bipèdes
  (créatures, héros, ouvriers) ont un squelette (coudes, genoux, cape, queue, ailes) et 19 clips
  d'animation joués par `AnimationPlayer` (marche, coup, repos, et une pose par activité : dormir, manger,
  boire, étudier, forger, prier, méditer...) ; les bêtes et le mobilier sont animés par pivots. La salle du trône entoure le cœur ; chaque salle a sa lumière, les torches vacillent.
- **Effets des sorts** modélisés dans Blender (`assets/models/fx/`, affichés par `scripts/fx_3d.gd`) :
  foudre, toile, flammes, rochers, spectre, dôme, œil, main squelettique, cercles magiques ; envoûtements
  visibles sur les unités. Pensé pour un téléphone moyen de gamme : 4 lumières passagères au plus, pas
  d'ombres dynamiques, simples reflets sur les pavés et le sang frais.
- **Sang** au sol et sur les murs là où l'on se bat ; il pâlit et disparaît au bout de 40 s.
- **Son** : musique gothique adaptative (calme / assaut / victoire / défaite) et effets sonores, tout
  composé par calcul ; le Seigneur du médaillon parle.
- **Réglages** (menu principal et pause) : Musique, Effets sonores, **Éclairage** (à couper sur un petit
  téléphone), **Vue 3D**, **Sang**.

## Version web (jouer dans le navigateur)

À chaque push, GitHub construit aussi la **version web** du jeu (`.github/workflows/web.yml`, préréglage
« Web » de `export_presets.cfg`) et la publie sur la branche `gh-pages`.

- **Adresse** : https://malinouxi.github.io/Android/ (PC, tablette ou téléphone, rien à installer).
- **À faire une seule fois** : sur GitHub, *Settings* > *Pages* > *Build and deployment* > Source
  « Deploy from a branch », branche `gh-pages`, dossier `/ (root)`, puis *Save*. Une minute plus tard,
  l'adresse marche.
- **Dépôt privé** : GitHub Pages n'est gratuit que pour un dépôt **public** (sinon il faut GitHub Pro).
  Sans Pages, la version web est quand même dans *Actions* > dernier build « Version web » >
  *Artifacts* > `SeigneurDesProfondeurs-web` (un zip : le décompresser, puis le servir comme indiqué
  plus bas).
- La partie est **sauvegardée dans le navigateur** (toutes les 60 s, et quand tu changes d'onglet).
  Vider les données du site efface la sauvegarde.
- Le premier chargement télécharge environ 20 Mo (compressés), ensuite le navigateur les garde.
  Le son démarre après le premier toucher (règle des navigateurs).
- Sur téléphone, « Ajouter à l'écran d'accueil » l'installe comme une appli (en paysage).
- Pour tester chez toi sans GitHub : exporte avec Godot (*Projet* > *Exporter* > *Web*), puis
  `python3 -m http.server` dans le dossier `build/web` et ouvre http://localhost:8000.

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

## Modifier les sons et la musique

Les sons sont dans `assets/sounds/` (WAV). Ils sont fabriqués par `tools/generate_sounds.py` à partir de
formules (ondes, bruit, enveloppes) et des instruments de `tools/gothic_synth.py` : change les chiffres et
relance `python3 tools/generate_sounds.py` (il faut numpy : `pip install numpy`). Tu peux aussi remplacer
un WAV par ton propre enregistrement (garde le même nom). La liste des sons utilisés est dans `scripts/sound.gd`.

La musique est dans `assets/music/` (OGG). Chaque morceau est une **partition écrite en Python** dans
`tools/generate_music.py` (accords, mélodies du chœur, rythmes des tambours) : modifie-la puis relance
`python3 tools/generate_music.py` (tous les morceaux) ou `python3 tools/generate_music.py combat` (un seul).
Il faut numpy et **ffmpeg** (pour l'encodage en OGG). Les instruments eux-mêmes (timbre de l'orgue,
voyelles du chœur, partiels des cloches, réverbération) se règlent dans `tools/gothic_synth.py`.
Quel morceau joue à quel moment : `play_music` dans `scripts/main.gd` et `scripts/menu.gd`.

## Modifier les graphismes

- **Modèles 3D** (personnages, mobilier, effets des sorts, Seigneur) : scripts Python pour Blender dans
  `tools/blender/` (`cast.py`, `beasts.py`, `rooms.py`, `spell_fx.py`, `lord.py`...), avec les briques de
  `lowpoly.py` et les textures peintes de `textures.py`. Les bipèdes reçoivent un squelette commun
  (`rig.py`) et leurs clips d'animation (`clips.py`, une fonction par clip : la retoucher, puis reconstruire).
  Tout reconstruire :
  `blender --background --python tools/blender/build_all.py` (les effets : `spell_fx.build_all(...)`).
  Ils marchent aussi avec le module Python `bpy` (`pip install bpy`) au lieu de Blender.
  Les antres seules (7 créatures, 9 modèles de salle), avec des aperçus en image :
  `blender --background --python tools/blender/build_dens.py -- --preview <dossier>`.
- **Interface** : icônes peintes, découpées dans les planches `tools/reference/hud_panel*.png` par
  `python3 tools/panel_icons.py` (→ `assets/icons_panel/`, il faut Pillow) ; celles que les planches n'ont pas
  viennent de Blender (`tools/blender/icons.py` → `assets/icons_hd/`). Le jeu prend l'icône peinte si elle
  existe (`Hud.hd` dans `scripts/hud.gd`). Cadres « pierre et braise » (pierre fissurée, liseré rouge, cornes
  et crânes) : `python3 tools/hud_gothic.py` → `assets/ui_hd/` (numpy, sans Blender).
- **Textures HD** du sol et des murs : `tools/textures_hd.py` ; taches de sang : `tools/blood_decals.py`.
- **Pixel art 32 × 32** (vue 2D, portraits, petites icônes) : `tools/art32.py`, lancé par
  `python3 tools/generate_art.py` (il faut Pillow et numpy) ; attention, il écrase les PNG de `assets/`.
  La liste des images est dans `scripts/art.gd`.

## Démarrer

1. Télécharge **Godot 4.7** (version « Standard », pas .NET ; c'est la version des builds GitHub) sur
   https://godotengine.org/download
2. Lance Godot, clique **Importer**, choisis le fichier `project.godot` de ce dossier.
3. Appuie sur **F5** (ou ▶) pour jouer sur ton ordinateur : la souris fait office de doigt.
4. Vérifier l'affichage sans téléphone : `godot --path . -s res://tools/screenshots.gd` (captures du menu,
   du codex, d'une partie, d'un combat...) ; le portrait du Seigneur : `tools/portrait_test.gd` ;
   les antres et les poses des créatures : `tools/dens_test.gd`.

## Tester sur un téléphone Android

Le plus simple : l'APK construit par GitHub (voir plus haut). Pour lancer depuis Godot :

1. **Éditeur > Gérer les modèles d'exportation** : télécharge-les.
2. Installe **OpenJDK 17** et le **SDK Android** (le plus simple : Android Studio), puis indique leurs
   chemins dans **Éditeur > Paramètres de l'éditeur > Export > Android**.
3. Sur le téléphone : **options pour les développeurs** et **débogage USB**, puis branche-le.
4. Le préréglage « Android » est déjà dans `export_presets.cfg` : un bouton Android apparaît en haut à
   droite de l'éditeur pour lancer le jeu sur le téléphone.

**Ne mets jamais** tes clés de signature (`.keystore`) ni leurs mots de passe sur Git.

## Organisation du code

```
project.godot              Configuration (rendu Compatibilité/OpenGL, paysage, souris = doigt, autoloads)
export_presets.cfg         Préréglages d'export « Android » et « Web »
scenes/                    menu.tscn (première scène), main.tscn (la partie), level_select.tscn
scripts/main.gd            Chef d'orchestre : outils, portail, paie, vagues et escouades, sorts, sauvegarde
scripts/dungeon_map.gd     La grille : creusage, salles, or, pièges et combos, feux, sang, secrets, chemins
scripts/unit.gd            Base de tout ce qui marche : chemins, vie, combat, effets des sorts
scripts/worker.gd          Un ouvrier : creuse, porte l'or, construit, revendique, décore, fuit les héros
scripts/creature.gd        Une créature : besoins, humeur, travail, combat (cible, entraide, recul), Attrapeur
scripts/hero.gd            Un héros : marche, creuse, missions, fuite, vétérans, Exorciste, gardien
scripts/creatures.gd       Catalogue des créatures      scripts/heroes.gd    Catalogue des héros
scripts/rooms.gd           Catalogue des salles         scripts/defenses.gd  Catalogue des défenses
scripts/spells.gd          Catalogue des sorts          scripts/research.gd  Ordre des découvertes
scripts/traits.gd          Traits de caractère          scripts/nemeses.gd   Registre des vétérans
scripts/combos.gd          Combos secrets               scripts/levels.gd    Niveaux de la campagne
scripts/rules.gd           LES RÈGLES : réglages généraux, version des règles, nouveautés
scripts/view_3d.gd         La vue 3D (carte, unités, lumières, caméra)
scripts/fx_3d.gd           Effets 3D : sorts, sol qui brûle, envoûtements, sang, budget de lumières
scripts/voxel_models.gd    Chargement des modèles Blender (et modèles en blocs de secours)
scripts/fx.gd              Effets communs 2D/3D : particules, chiffres, tremblements, éclairs
scripts/iso.gd             La vue isométrique 2D
scripts/art.gd             Les images du jeu (assets/)
scripts/hud.gd             L'interface de jeu
scripts/lord_portrait.gd   Le Seigneur animé du médaillon (et sa voix)
scripts/menu.gd            Le menu principal          scripts/level_select.gd  Le choix des niveaux
scripts/codex.gd           L'écran du codex           scripts/codex_content.gd Les textes du codex
scripts/camera_controller.gd  Contrôles tactiles : glisser, pincer, tourner, toucher, peindre
scripts/save_game.gd       Sauvegarde (JSON)
scripts/sound.gd           Autoload « Sound » : sons, musique adaptative, voix, réglages
scripts/ui.gd              Autoload « Ui » : polices, thème, cadres HD
tools/                     Générateurs : images (art32.py, textures_hd.py, blood_decals.py), sons,
                           musique, voix (generate_*.py, gothic_synth.py), Blender (tools/blender/)
.github/workflows/         Builds automatiques : APK Android et version web
```

Les scripts se parlent par **signaux** (`gold_changed`, `tool_selected`, `left_dungeon`, `died`,
`heart_destroyed`, `combo_triggered`...) : chaque morceau reste simple et peut être modifié sans casser
les autres. Pour expérimenter, change d'abord les chiffres de `scripts/rules.gd` et des catalogues.

## Feuille de route

Fait : creuser, salles, créatures, héros et combat, main du maître, pièges et portes, menu et sauvegarde,
territoire, recherche et atelier, son et musique, campagne et maître rival, 3D et modèles Blender,
traits et vétérans, combos, profondeurs, héros tacticiens, 17 sorts, version web, effets 3D et sang,
7 antres et leurs créatures, poses animées.

À venir :
- **Équilibrage** sur téléphone (prix, vagues, sorts, quantité de sang) d'après les retours de partie ;
- un **tutoriel** guidé pour le niveau 1 ;
- une **clé de signature** fixe pour l'APK (voir plus haut), pour garder la sauvegarde entre deux mises à jour.

Le jeu doit rester **original** : son propre nom, son univers, ses créatures et ses graphismes.

## Historique du développement

Résumé des étapes (les détails des règles de chaque version sont dans *Codex > Nouveautés*) :

1. Creuser : carte aléatoire, ouvriers, pathfinding, or.
2. Salles : Trésor, Repaire, Champignonnière ; l'or est porté au Trésor.
3. Créatures : portail, lits, faim, sommeil, paie, humeur.
4. Héros et combat : entrée, vagues, rançons, cœur.
5. La main du maître.
6. Pixel art (16 × 16, puis 32 × 32 à l'étape 19) et animations de marche.
7. Pièges et portes.
8. Menu principal, pause et sauvegarde.
9. Territoire revendiqué, niveaux des créatures, sorts, Bibliothèque et Atelier.
10. Son. 11. Confort tactile (peindre au doigt, vitesse x1/x2/x3, mini-carte).
12. Prison, Temple, Araignée, Démon, Clerc, Archer.
13. Campagne et maître rival. 14. Chauve-souris, Golem, Vampire, Salamandre ; Nain, Magicienne, Paladin, Géant.
15. Vue isométrique, éclairage, particules. 16–17. Interface, torches, nouveau menu.
18. Attrapeurs, sacrifices, codex. 19–20. Tout en 32 × 32, animations d'attaque et de mort.
21. Décor animé, Cimetière et Revenants, Champion du royaume (niveau 9).
22. Voleuse, Moine libérateur, Cerbère. 23. Portail équilibré. 24. Les ouvriers construisent (chantiers).
25. Codex illustré. 26. Décorations. 27–28. Le jeu en 3D.
29–31. Nouvelle interface, salles à objets de plusieurs cases, pierre taillée, icônes HD.
32–34. Personnages et salles modélisés dans Blender, salle du trône, ambiance ; salles en bloc, échafaudages, roche.
35. Musique et sons gothiques. 36. La voix du Seigneur.
37. Traits, vétérans, combos de pièges (règles 2.2). 38. Les profondeurs (2.3). 39. Héros tacticiens (2.4).
40. Le Seigneur modélisé dans Blender. 41. HUD « caverne » et icônes 3D.
42. 14 nouveaux sorts, héros qui résistent à la magie, Exorciste (2.5) ; version web.
43. HUD « pierre et fer » d'après la photo de référence.
44. Effets 3D des sorts, lumières et reflets légers, sang des combats (2.6).
45. Les antres (2.7) : Taverne, Infirmerie, Hôtel des monnaies, Chambre de torture, Poste de garde, Puits de
    mana et Crypte, modélisés dans Blender ; 7 créatures (Gobelin brasseur, Goule rebouteuse, Diablotin
    argentier, Bourreau, Gargouille, Oracle des ombres, Nécromancien) ; poses animées pour chaque activité.
46. L'IA de tes créatures (2.8) : choix de la cible, appel à l'aide, défense du cœur, tireurs qui reculent,
    ouvriers qui fuient les héros ; test sans écran `tools/ai_test.gd`.

class_name Rules
## LES RÈGLES DU JEU EN UN SEUL ENDROIT.
##
## Ce fichier regroupe les principaux réglages de jeu, pour pouvoir les ajuster
## facilement selon les retours des joueurs. Les autres scripts lisent ces
## valeurs (par exemple main.gd écrit WORKER_COST := Rules.WORKER_COST).
##
## Pour faire évoluer les règles :
##   1. change un chiffre ci-dessous ;
##   2. ajoute une ligne dans CHANGELOG, et augmente VERSION ;
##   3. si besoin, mets à jour l'article du codex (scripts/codex_content.gd).
## Les créatures, héros, salles, pièges et sorts ont leurs propres catalogues
## (creatures.gd, heroes.gd, rooms.gd, defenses.gd, spells.gd, research.gd) :
## le codex du jeu les affiche automatiquement.

## Version des règles (affichée dans le codex).
const VERSION := "2.2"

## Les nouveautés, de la plus récente à la plus ancienne (affichées dans le codex).
const CHANGELOG := [
	{"version": "2.2", "changes": [
		"Traits de caractère : chaque créature arrive avec 1 ou 2 traits (Avare, Peureuse, Bagarreuse, Rancunière, Pieuse, Gourmande, Insomniaque, Studieuse, Paresseuse, Coquette, Solitaire, Robuste). Ils sont sur sa fiche et dans le codex.",
		"Les héros battent en retraite : sous 25 % de vie, ils fuient vers l'entrée grise. Rattrape-les !",
		"Les vétérans : un héros qui s'échappe (ou une Voleuse qui s'enfuit) revient 1 ou 2 vagues plus tard avec un nom, plus fort. Il évite les pièges qui l'ont blessé (et ils lui font moins mal), et en veut à l'espèce qui l'a le plus abîmé.",
		"Combos de pièges secrets (6) : Rune de feu, Réaction en chaîne, Pointes ardentes, Empalement, Détonation, Porte hérissée. Le codex donne un indice pour ceux que tu n'as pas encore découverts.",
	]},
	{"version": "2.1", "changes": [
		"Les salles se construisent d'un seul bloc, à leur taille : Bibliothèque 2 x 3, Entraînement 2 x 4, Temple 2 x 3, Atelier 2 x 2, Prison 2 x 2 (4 cellules), Trésor 1 x 2. Le prix est celui de la salle entière.",
		"Les ouvriers montent des échafaudages sur les grands chantiers, et l'objet sort de terre petit à petit.",
		"La roche se creuse (plus lentement) et cache parfois un trésor.",
		"Créatures : les conditions d'arrivée comptent des salles entières (Salamandre : 1 Entraînement, Sorcier : 1 Bibliothèque, Vampire : 2 Prisons...). Sorciers, Démons, Vampires et Cerbères sont limités selon le nombre de leurs salles.",
		"HUD : le portrait du Seigneur, en 3D dans un médaillon, réagit aux événements (colère, rire, inquiétude) et parle. Touche-le pour un conseil.",
		"Nouveau : le Brasero (Défenses, 80 or). Son feu rouge éclaire et apaise les créatures proches. Le maître rival a ses braseros violets.",
		"Les ouvriers désœuvrés accrochent des chandeliers aux murs des salles : ils les éclairent.",
		"Économie : ton territoire rapporte 1 or par case à chaque paie ; les filons sont plus riches loin du cœur ; 2 gemmes inépuisables par carte. Le HUD montre la paie prévue.",
		"La première vague laisse le temps de bâtir un Trésor, une Champignonnière et un Repaire (7 minutes au moins).",
	]},
	{"version": "2.0", "changes": [
		"Les salles se couvrent d'objets de plusieurs cases (coffre 1 x 2, rayonnages 2 x 3, forge 2 x 2, arène 2 x 4, autel 2 x 3...). Une case sans objet ne sert à rien.",
		"Nouvelle interface plus grande (polices gothiques, icônes HD), sans mini-carte.",
		"3D : murs en pierre taillée autour de ton territoire, sol pavé, torches murales, éclairage chaud.",
	]},
	{"version": "1.10", "changes": [
		"Les Revenants n'ont plus besoin de lit (ni de manger, ni de dormir) : ils ne bloquent plus l'arrivée des autres créatures.",
		"Revenants limités à 6. Au-delà, le héros enterré repose en paix et sa tombe se libère.",
		"Déposer une créature avec la Main sur le portail la renvoie (son lit se libère).",
	]},
	{"version": "1.9", "changes": [
		"Tout en 3D : personnages et objets en volumes (blocs), barres de vie et d'humeur, cercles des sorts et particules dans la scène, menu principal en 3D.",
		"3D : toucher le dessus d'un mur vise bien ce mur.",
	]},
	{"version": "1.8", "changes": [
		"Le jeu passe en 3D (réglage « Vue 3D », activé par défaut) : murs en relief, lumières, caméra qu'on déplace, zoome et fait pivoter aux doigts. Les règles ne changent pas.",
	]},
	{"version": "1.7", "changes": [
		"Quand ils n'ont plus rien à faire, les ouvriers fabriquent des décorations : tableaux et tapisseries aux murs, tapis dans les salles. Elles rendent les créatures plus heureuses.",
	]},
	{"version": "1.6", "changes": [
		"Les ouvriers construisent les salles, les pièges, les portes et les autels : chaque case devient un chantier, plus ou moins long selon l'objet. Elle ne sert qu'une fois terminée.",
	]},
	{"version": "1.5", "changes": [
		"Portail équilibré : il favorise les espèces que tu as peu ou pas (un Attrapeur arrive vite si tu as une Prison).",
		"Cerbères limités : un pour 6 cases de Trésor, 3 au maximum.",
	]},
	{"version": "1.4", "changes": [
		"La Voleuse est discrète : elle se faufile jusqu'au Trésor, vole jusqu'à 150 or et s'enfuit par l'entrée. Abattue, elle lâche son sac, que les ouvriers rapportent.",
		"Nouveau héros : le Moine libérateur, qui ouvre les cellules de la Prison.",
		"Nouvelle créature : le Cerbère, gardien du Trésor, qui flaire les voleuses de loin.",
	]},
	{"version": "1.3", "changes": [
		"Nouvelle salle : le Cimetière (recherche). Les héros morts y sont enterrés et se relèvent en Revenants.",
		"Nouveau héros : le Champion du royaume, qui mène une vague sur 5 et accélère les héros par son cri de guerre.",
		"Nouveau niveau de campagne : « Le Champion du royaume ».",
		"Décor animé : flammes, portail, enclume, autels, mannequins, tombes, et cœur qui bat.",
	]},
	{"version": "1.2", "changes": [
		"Nouvelle créature : l'Attrapeur de cauchemar. Les héros vaincus tombent assommés, et les Attrapeurs les emmènent en prison.",
		"Sacrifices : l'Atelier fabrique des Autels de sacrifice. Outil Sacrifier : un prisonnier conduit à l'autel rapporte 3 fois sa rançon.",
		"Ajout du codex des règles.",
	]},
	{"version": "1.1", "changes": [
		"Recharge de la mana ralentie (0,25/s + 1/s par 120 cases de territoire, 1,5/s au maximum).",
	]},
	{"version": "1.0", "changes": [
		"Première version : creuser, salles, créatures, héros, pièges, sorts, campagne et maître rival.",
	]},
]

# --- Économie -------------------------------------------------------------
const START_WORKERS := 3          ## Ouvriers au début d'une partie.
const WORKER_COST := 100          ## Prix d'un ouvrier en plus.
const PAYDAY_INTERVAL := 90.0     ## Secondes entre deux jours de paie.

# --- Construction ------------------------------------------------------------
## Multiplie toutes les durées de construction (rooms.gd et defenses.gd, "build_time").
## 0.5 = deux fois plus rapide, 2.0 = deux fois plus lent.
const BUILD_TIME_FACTOR := 1.0

# --- Roche -----------------------------------------------------------------------
## Coups de pioche pour casser une case de roche (la terre en demande 4, l'or 8).
const ROCK_DIG_HITS := 12
## Chance qu'une case de roche cache un trésor...
const ROCK_TREASURE_CHANCE := 0.15
## ... de tant d'or (au hasard entre les deux), posé par terre : les ouvriers le ramassent.
const ROCK_TREASURE_MIN := 100
const ROCK_TREASURE_MAX := 300

# --- Revenus ---------------------------------------------------------------------
## À chaque jour de paie, ton territoire rapporte tant d'or par case revendiquée.
const TERRITORY_INCOME := 1
## Les filons loin du cœur sont plus riches : jusqu'à +100 % d'or par coup de pioche
## (à partir de DEEP_GOLD_START cases du cœur, au maximum à DEEP_GOLD_FULL cases).
const DEEP_GOLD_BONUS := 1.0
const DEEP_GOLD_START := 8
const DEEP_GOLD_FULL := 24
## Les GEMMES : rares, loin du cœur, inépuisables. Chaque coup de pioche rapporte
## GEM_GOLD_PER_HIT or (lentement : GEM_DIG_SLOWNESS fois plus lent que l'or).
const GEMS_PER_MAP := 2
const GEM_MIN_DISTANCE := 14
const GEM_GOLD_PER_HIT := 12
const GEM_DIG_SLOWNESS := 2.0

# --- Vagues ------------------------------------------------------------------------
## La première vague n'arrive jamais avant ce délai (secondes), quel que soit le niveau :
## le temps de bâtir un Trésor, une Champignonnière et un Repaire.
const FIRST_WAVE_MIN := 420.0

# --- Décorations -----------------------------------------------------------------
## Secondes de travail d'un ouvrier pour fabriquer chaque décoration.
const DECORATION_TIME := {"rug": 6.0, "painting": 8.0, "tapestry": 10.0}
## Nombre maximum de décorations dans le donjon.
const MAX_DECORATIONS := 40

# --- Braseros ------------------------------------------------------------------
## Une créature à moins de BRAZIER_RADIUS cases d'un de tes braseros gagne
## BRAZIER_MOOD d'humeur en plus à chaque mise à jour (un seul brasero compte).
const BRAZIER_RADIUS := 3
const BRAZIER_MOOD := 0.6
## Braseros violets autour du cœur du maître rival.
const RIVAL_BRAZIERS := 2

# --- Chandeliers ---------------------------------------------------------------
## Quand ils n'ont rien à faire, les ouvriers accrochent des CHANDELIERS aux murs
## des salles (avant les autres décorations) : ils éclairent la salle.
const CANDELABRA_TIME := 7.0      ## Secondes de travail pour en poser un.
const MAX_CANDELABRAS := 30       ## Au plus (chaque chandelier est une lumière).
const CANDELABRA_SPACING := 2     ## Pas d'autre chandelier à moins de 2 cases.
## Humeur gagnée chaque seconde par les créatures, par décoration (le « prestige »)...
const DECORATION_MOOD := 0.05
## ... sans dépasser ce bonus.
const MAX_DECORATION_MOOD := 1.0

# --- Créatures ----------------------------------------------------------------
const CREATURE_ARRIVAL_DELAY := 20.0 ## Secondes entre deux arrivées par le portail.
## Portail équilibré : une espèce déjà présente N fois a 1 / (N + 1)^PORTAL_BALANCE
## fois moins de chances de venir. 0 = au hasard, 2 = forte préférence pour la variété.
const PORTAL_BALANCE := 2.0
## Avec une Prison et aucun Attrapeur de cauchemar, ses chances sont multipliées par ceci.
const CATCHER_PRIORITY := 4.0
## Créatures rares, limitées selon le nombre de SALLES (un bloc = une salle) :
## un Cerbère par CERBERUS_TREASURY_ROOMS salles de Trésor (il en faut autant pour
## qu'il vienne), MAX_CERBERUS au plus...
const CERBERUS_TREASURY_ROOMS := 3
const MAX_CERBERUS := 3
## ... 2 Sorciers par Bibliothèque, 1 Démon par Temple, 2 Vampires par Prison.
const WARLOCKS_PER_LIBRARY := 2.0
const MAX_WARLOCKS := 6
const DEMONS_PER_TEMPLE := 1.0
const MAX_DEMONS := 3
const VAMPIRES_PER_PRISON := 2.0
const MAX_VAMPIRES := 4

# --- Prison et sacrifices ------------------------------------------------------
## Secondes pendant lesquelles un héros assommé attend un Attrapeur avant de mourir.
const CAPTURE_WINDOW := 30.0
## Points de recherche par seconde qu'apporte chaque prisonnier interrogé.
const PRISONER_RESEARCH := 1.0
## Un sacrifice rapporte la rançon du héros multipliée par ce nombre.
const SACRIFICE_GOLD_MULTIPLIER := 3
## Nombre maximum d'autels de sacrifice (posés + en stock) que l'Atelier fabrique.
const MAX_ALTARS := 2

# --- Cimetière ----------------------------------------------------------------------
## Secondes entre l'enterrement d'un héros et le moment où il se relève en Revenant
## (il faut aussi un lit libre au Repaire).
const REVENANT_RISE_TIME := 60.0
## Nombre maximum de Revenants dans le donjon.
const MAX_REVENANTS := 6

# --- Héros en mission ------------------------------------------------------------
## Or que la Voleuse emporte d'un coffre.
const THIEF_LOOT := 150
## Distance (pixels) en dessous de laquelle on repère une Voleuse (sauf le Cerbère,
## qui la flaire de bien plus loin).
const STEALTH_RADIUS := 40.0
## Les héros en mission (Voleuse, Moine) ne se battent que si un ennemi est aussi proche.
const MISSION_AGGRO_RADIUS := 40.0
## Secondes qu'il faut au Moine pour ouvrir une cellule de Prison.
const UNLOCK_TIME := 3.0

# --- Retraite des héros et vétérans (voir hero.gd et nemeses.gd) -------------------
## Un héros sous cette part de sa vie bat en retraite vers l'entrée (sauf le
## Champion et les troupes du rival).
const HERO_FLEE_BELOW := 0.25
## La peur donne des ailes : vitesse multipliée pendant la fuite.
const HERO_FLEE_SPEED := 1.15
## Un héros échappé revient entre NEMESIS_RETURN_MIN et NEMESIS_RETURN_MAX vagues plus tard...
const NEMESIS_RETURN_MIN := 1
const NEMESIS_RETURN_MAX := 2
## ... au plus NEMESIS_PER_WAVE par vague.
const NEMESIS_PER_WAVE := 2
## Par rang de vétéran (1 à 3) : +30 % de vie, +20 % de dégâts, +50 % de rançon.
const NEMESIS_HP_BONUS := 0.3
const NEMESIS_DAMAGE_BONUS := 0.2
const NEMESIS_REWARD_BONUS := 0.5
## Rancune : dégâts multipliés contre l'espèce qui l'a le plus abîmé.
const NEMESIS_GRUDGE_DAMAGE := 1.3
## Un piège dont il se souvient ne lui fait que cette part des dégâts...
const NEMESIS_TRAP_DAMAGE := 0.5
## ... et il l'évite : la case « coûte » autant que tant de cases de marche.
const NEMESIS_TRAP_AVOID := 8.0

# --- Combos de pièges (voir combos.gd) --------------------------------------------
## Distance (en cases) entre un Brasero et une Rune ou des Pointes pour le combo.
const COMBO_BRAZIER_RADIUS := 2
## Rune de feu : rayon de l'explosion multiplié, puis le sol brûle.
const FIRE_RUNE_RADIUS := 1.5
const FIRE_TIME := 6.0            ## Secondes pendant lesquelles le sol brûle.
const FIRE_BURN_TIME := 2.0       ## Un héros dans les flammes brûle encore tant de secondes...
const FIRE_BURN_DPS := 12.0       ## ... en perdant tant de vie par seconde.
## Réaction en chaîne : chaque Rune suivante fait tant de fois plus de dégâts.
const CHAIN_DAMAGE := 1.25
## Pointes ardentes : dégâts multipliés, brûlure de tant de secondes et de dégâts par seconde.
const HOT_SPIKES_DAMAGE := 1.5
const HOT_SPIKES_BURN_TIME := 3.0
const HOT_SPIKES_BURN_DPS := 6.0
## Empalement : dégâts des Pointes multipliés sur un héros ralenti.
const IMPALE_DAMAGE := 2.0
## Détonation : dégâts de la Rune multipliés quand l'Éclair la fait exploser.
const DETONATION_DAMAGE := 1.5
## Porte hérissée : temps de réarmement des Pointes collées à une Porte multiplié.
const DOOR_SPIKES_REARM := 0.5

# --- Atelier ----------------------------------------------------------------------
## L'Atelier arrête de fabriquer des pièges quand le stock total atteint ce nombre.
const MAX_TRAP_STOCK := 9

# --- Divers -----------------------------------------------------------------------
const AUTOSAVE_INTERVAL := 60.0   ## Secondes entre deux sauvegardes automatiques.

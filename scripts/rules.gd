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
const VERSION := "2.9"

## Les nouveautés, de la plus récente à la plus ancienne (affichées dans le codex).
const CHANGELOG := [
	{"version": "2.9", "changes": [
		"Repli des blessés : sous 25 % de vie, une créature quitte le combat pour l'Infirmerie (ou son lit) et revient à 70 %. Les Bagarreuses ne reculent jamais, les morts-vivants non plus, et personne ne recule quand ton cœur est frappé.",
		"Postes de défense (onglet Défenses, gratuits, 3 au plus) : plante un étendard dans un couloir. Les créatures sans travail utile y montent la garde, voient les héros de plus loin, et y accourent toutes à l'approche d'une vague.",
		"Le travail est mieux choisi : chaque créature fait ce qui est le plus utile (recherche en retard, Atelier quand le stock de pièges est bas, Puits de mana quand la mana manque, Temple quand elle est malheureuse...), selon ses talents et ses traits, et sans s'entasser au même endroit.",
		"Les héros s'adaptent : ils visent d'abord tes tireurs et ta Goule, peuvent vouloir détruire ton Infirmerie ou ton Poste de garde, et dès la vague 6 certaines vagues attendent à l'entrée que tes créatures s'endorment.",
		"Le maître rival est opportuniste : juste après une vague, si tes créatures sont blessées, il lance ses troupes aussitôt (avec une créature de plus).",
	]},
	{"version": "2.8", "changes": [
		"Tes créatures choisissent mieux leur cible : d'abord les héros qui frappent le cœur, puis les Clercs et les Exorcistes, les pillards chargés d'or et les héros presque morts. Le Bourreau cherche les héros à achever, une Rancunière celui qui l'a blessée.",
		"Les créatures à distance (Sorcier, Oracle, Nécromancien, Salamandre) reculent d'un pas entre deux tirs quand un héros les colle, au lieu de se laisser frapper.",
		"Appel à l'aide : une créature qui engage le combat appelle ses voisines (10 cases) ; celles qui travaillent, mangent ou se promènent accourent. Les endormies ne se réveillent pas (pour cela, il faut l'alarme du Poste de garde).",
		"Le cœur appelle : quand un héros le frappe, toutes tes créatures accourent, même celles qui dorment (sauf les blessés de l'Infirmerie et les Peureuses en fuite).",
		"Les ouvriers ont peur : un héros à moins de 3 cases, ils lâchent leur tâche et s'enfuient, puis reprennent le travail quand le danger est passé.",
	]},
	{"version": "2.7", "changes": [
		"7 nouvelles salles, nouvel onglet « Antres » (à découvrir à la Bibliothèque) : Taverne, Infirmerie, Hôtel des monnaies, Chambre de torture, Poste de garde, Puits de mana et Crypte.",
		"Taverne : une créature de mauvaise humeur va y boire une chope (un champignon de la Champignonnière) : +humeur, et 10 % de salaire en moins à la paie suivante. Elle titube un moment en sortant.",
		"Infirmerie : sous 60 % de vie, une créature va s'y coucher et guérit vite (10 PV/s, deux fois plus avec une Goule rebouteuse au chevet).",
		"Hôtel des monnaies : toutes les 30 s, 2 % d'intérêts sur l'or du Trésor (50 or au plus par Hôtel) ; les créatures y frappent aussi des pièces.",
		"Chambre de torture : les bourreaux font parler les prisonniers (recherche, et composition de la vague suivante), qui finissent par changer de camp. Les Pieuses refusent d'y travailler.",
		"Poste de garde : un guetteur en poste démasque les Voleuses, chasse l'éclaireur sans son rapport et sonne l'alarme : les créatures proches se réveillent et accourent.",
		"Puits de mana : +50 mana au maximum par puits (3 puits au plus) ; les créatures y méditent pour te donner de la mana.",
		"Crypte : une créature morte y repose (2 places par Crypte) et se relève 60 s plus tard pour 60 mana, un niveau plus bas, avec le trait « Revenue ».",
		"7 nouvelles créatures, une par salle : Gobelin brasseur, Goule rebouteuse, Diablotin argentier, Bourreau, Gargouille, Oracle des ombres, Nécromancien.",
		"Le donjon est plus vivant : les créatures s'allongent pour dormir, mangent, étudient, forgent, prient à genoux, trinquent, montent la garde, méditent en lévitation...",
	]},
	{"version": "2.6", "changes": [
		"Vue 3D : les sorts ont leurs effets modélisés dans Blender : foudre qui tombe, toile au sol, flammes du Brasier, rochers de l'Effondrement, spectre de la Terreur, dôme du Sanctuaire, Œil du maître, main qui sort de terre, cercles magiques colorés.",
		"Les envoûtements se voient sur les unités : toile sous les héros englués, dôme autour des unités protégées, cercle rouge sous la créature possédée.",
		"Lumières : les sorts et les feux éclairent la scène (4 lumières passagères au plus, pour les téléphones) ; les pavés et le sang frais luisent à la lumière des torches. Tout cela se coupe avec « Éclairage : non ».",
		"Du sang au sol et sur les murs là où l'on se bat. Il pâlit et disparaît au bout de 40 secondes (60 taches au plus). Les morts-vivants, les golems et les spectres ne saignent pas. Réglage « Sang : oui / non ».",
	]},
	{"version": "2.5", "changes": [
		"14 nouveaux sorts, à découvrir à la Bibliothèque. Onglet Sorts (combat) : Toile, Brasier, Terreur, Effondrement, Possession. Nouvel onglet Pouvoirs (ton donjon) : Fouet, Festin, Œil du maître, Invocation, Transmutation, Relever les morts, Conversion, Sanctuaire, Rappel.",
		"Relever les morts demande un Cimetière, Conversion une Prison, Sanctuaire un Temple.",
		"Les héros s'habituent à ta magie : dès la vague 4, chaque vague leur donne 4 % de résistance aux sorts (40 % au plus), plus 10 % par rang de vétéran. Les dégâts des sorts et la durée des envoûtements baissent d'autant.",
		"Certains héros sont insensibles : Paladin et Moine à la Terreur, Magicienne et Géant à la Toile ; le Nain se tire des éboulements. Le Clerc libère ses alliés de la Toile et de la Terreur.",
		"Nouveau héros, l'Exorciste (dès la vague 5, au moins un par vague dès la 8) : il dissipe tes sorts autour de lui et éteint les flammes du Brasier.",
		"4 nouveaux combos secrets avec les sorts (10 en tout).",
		"Nouvelle créature : le Renégat, un prisonnier converti qui garde l'allure du héros qu'il était.",
		"Niveau 4 (Le savoir est une arme) : 7 découvertes au lieu de 5, car la liste de recherche est plus longue.",
	]},
	{"version": "2.4", "changes": [
		"Escouades : les grandes vagues se divisent en 2 ou 3 groupes. Le gros de la troupe prend le chemin le plus court, les flanqueurs en cherchent un autre, les sapeurs (surtout les Nains) percent un tunnel tout droit vers le cœur.",
		"Objectifs : une vague sur deux (dès la vague 3) a un but annoncé : piller le Trésor, libérer les prisonniers, saccager la Bibliothèque, chasser les ouvriers ou abattre ta meilleure créature.",
		"Tactiques : chaque escouade se regroupe à l'entrée avant d'avancer ; si la moitié tombe, les survivants battent en retraite ensemble ; Clercs, Archers et Magiciennes restent à distance ; les héros fragiles évitent tes créatures redoutables.",
		"Seconde entrée : à la vague 5, un éboulement ouvre une nouvelle entrée grise ailleurs sur la carte. Les escouades se répartissent entre les deux.",
		"Éclaireur : avant certaines vagues, un éclaireur visite ton donjon. S'il ressort vivant, la vague suivante connaît tes pièges et les évite.",
	]},
	{"version": "2.3", "changes": [
		"Les profondeurs : chaque carte cache 3 secrets loin du cœur. Creuser à côté donne un indice ; creuser une case qui les touche les réveille.",
		"Le Colosse endormi : un gardien neutre qui veille sur un trésor. Il ne quitte pas sa caverne, mais frappe fort. Vaincu, il se soumet et te sert.",
		"Le lac de lave : la lave se déverse dans tes couloirs (elle brûle tout ce qui s'y trouve et peut couper un passage), puis se fige en filons d'or volcanique 3 fois plus riches.",
		"La ruine oubliée : son savoir perdu te donne 2 découvertes d'un coup... mais elle libère des spectres qui marchent sur ton cœur.",
		"Le Colosse DORT tant que tu ne l'attaques pas : tes créatures passent devant sa caverne sans le déranger. Quand tu es prêt, le bouton « Attaquer le Colosse » (sous l'objectif) envoie toutes tes créatures ; « Rappeler les troupes » arrête l'assaut.",
	]},
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

# --- Les profondeurs (voir dungeon_map.gd, « Les profondeurs ») ------------------
## Nombre de secrets par carte (un de chaque sorte : Colosse, lave, ruine) ...
const DEEP_SECRETS := 3
## ... à au moins tant de cases (en marchant) du cœur.
const DEEP_SECRET_MIN_DISTANCE := 15
## Le Colosse endormi garde un tas d'or de cette taille.
const COLOSSUS_HOARD := 800
## Il DORT tant que tu ne l'attaques pas (bouton « Attaquer le Colosse », un sort ou un
## piège) : tes créatures passent à côté sans le voir. Réveillé, s'il ne voit plus
## personne pendant tant de secondes, il se rendort.
const GUARDIAN_CALM_TIME := 8.0
## Il ne s'éloigne pas de sa caverne de plus de tant de pixels (une case = 32) ...
const GUARDIAN_RADIUS := 128.0
## ... et, sans ennemi, il regagne tant de vie par seconde.
const GUARDIAN_REGEN := 8.0
## La lave coule sur au plus tant de cases de couloir, une toutes les LAVA_FLOW_INTERVAL s ...
const LAVA_FLOW_CELLS := 6
const LAVA_FLOW_INTERVAL := 0.7
## ... blesse et brûle les unités qu'elle touche ...
const LAVA_DAMAGE := 60.0
const LAVA_BURN_TIME := 4.0
const LAVA_BURN_DPS := 10.0
## ... puis se fige au bout de tant de secondes en or volcanique, tant de fois plus riche.
const LAVA_COOL_TIME := 120.0
const VOLCANIC_GOLD := 3.0
## La ruine oubliée : tant de découvertes d'un coup (ou tant d'or si tout est découvert) ...
const RUIN_DISCOVERIES := 2
const RUIN_FALLBACK_GOLD := 800
## ... et tant de spectres qui se réveillent.
const RUIN_SPECTRES := 3

# --- Tactiques des héros (voir main.gd, « Vagues », et hero.gd) -------------------
## Une vague de tant de héros ou plus se divise en 2 escouades, puis en 3.
const TWO_SQUADS_FROM := 4
const THREE_SQUADS_FROM := 7
## Secondes entre l'arrivée de deux escouades.
const SQUAD_GAP := 6.0
## Une escouade attend ses retardataires à l'entrée, puis encore tant de secondes.
const REGROUP_TIME := 2.0
## Les flanqueurs évitent le chemin de l'escouade principale (coût multiplié).
const FLANK_AVOID_WEIGHT := 6.0
## Pour un sapeur, creuser une case coûte autant que marcher sur tant de cases.
const SAPPER_DIG_WEIGHT := 1.5
## Une escouade d'au moins tant de héros bat en retraite quand la moitié est tombée.
const SQUAD_RETREAT_MIN_SIZE := 3
## Un héros « fragile » (moins de tant de PV) évite les abords (tant de cases) de tes
## créatures redoutables (Démon, Colosse ancien, ou niveau STRONG_LEVEL et plus).
const FRAGILE_HP := 120.0
const STRONG_AVOID_RADIUS := 2
const STRONG_AVOID_WEIGHT := 5.0
const STRONG_LEVEL := 4
## Les héros à distance (et le Clerc) reculent si une créature s'approche à moins de tant de pixels.
const KITE_DISTANCE := 44.0
## Objectifs : dès la vague OBJECTIVE_FIRST_WAVE, une vague sur OBJECTIVE_EVERY en a un.
const OBJECTIVE_FIRST_WAVE := 3
const OBJECTIVE_EVERY := 2
## Les pillards emportent tant d'or chacun.
const RAID_LOOT := 120
## Points de vie d'une salle saccagée, par case.
const ROOM_HP_PER_CELL := 60.0
## Seconde entrée : un éboulement l'ouvre à cette vague (un niveau peut changer ce
## chiffre avec « second_entrance_wave » ; 0 = jamais).
const SECOND_ENTRANCE_WAVE := 5
## L'éclaireur : dès la vague SCOUT_FIRST_WAVE, une vague sur SCOUT_EVERY, il arrive
## SCOUT_LEAD secondes avant elle. Il rebrousse chemin à SCOUT_DEPTH cases du cœur,
## ou au bout de SCOUT_TIME secondes, et repère les pièges à SCOUT_SIGHT cases.
const SCOUT_FIRST_WAVE := 3
const SCOUT_EVERY := 3
const SCOUT_LEAD := 45.0
const SCOUT_DEPTH := 6
const SCOUT_TIME := 40.0
const SCOUT_SIGHT := 3

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
## Porte électrifiée : une Porte frappée par l'Éclair reste chargée tant de secondes ;
## chaque coup qu'un héros lui porte lui renvoie tant de dégâts.
const SHOCK_DOOR_TIME := 20.0
const SHOCK_DOOR_DAMAGE := 12.0
## Rune engluée : un héros pris dans la Toile ne s'écarte pas de la Rune : dégâts multipliés.
const STUCK_RUNE_DAMAGE := 1.6
## Brasier runique : le Brasier fait exploser les Runes de sa zone en Runes de feu.
## Traînée de feu : un Démon sous Hâte laisse derrière lui du sol qui brûle (tant de
## secondes, une flamme tous les FIRE_TRAIL_STEP pixels parcourus).
const FIRE_TRAIL_TIME := 3.0
const FIRE_TRAIL_STEP := 24.0

# --- Magie : les héros s'y habituent (voir spells.gd et hero.gd) -------------------
## Dès la vague SPELL_RESIST_FROM_WAVE, chaque nouvelle vague donne aux héros tant de
## résistance à la magie en plus (dégâts des sorts et durée des envoûtements
## réduits d'autant), sans dépasser SPELL_RESIST_MAX...
const SPELL_RESIST_FROM_WAVE := 4
const SPELL_RESIST_PER_WAVE := 0.04
const SPELL_RESIST_MAX := 0.4
## ... plus tant par rang de vétéran (il a déjà goûté à tes sorts).
const SPELL_RESIST_PER_RANK := 0.1
## L'Exorciste dissipe la magie à moins de tant de pixels, toutes les tant de secondes ...
const EXORCIST_RADIUS := 112.0
const EXORCIST_INTERVAL := 5.0
## ... et dès la vague EXORCIST_SURE_WAVE, chaque vague en compte au moins un.
const EXORCIST_SURE_WAVE := 8
## Le Clerc, en soignant, libère aussi ses alliés de la Toile et de la Terreur.

# --- Sang des combats (voir dungeon_map.gd, add_blood) ---------------------------
## Une tache reste tant de secondes, et pâlit pendant les BLOOD_FADE dernières.
const BLOOD_TIME := 40.0
const BLOOD_FADE := 10.0
## Chance de tacher pour un petit coup (un coup de 30 dégâts ou plus tache presque toujours).
const BLOOD_MIN_CHANCE := 0.25
## Chance d'éclabousser aussi un mur voisin.
const BLOOD_WALL_CHANCE := 0.3
## Au plus tant de taches à la fois (les plus anciennes s'effacent) : léger pour un téléphone.
const MAX_BLOOD := 60

# --- Les antres (règles 2.7, voir creature.gd et main.gd) --------------------------
## Taverne : une créature va boire quand son humeur est sous ce seuil (une Gourmande, toujours).
const TAVERN_MOOD_BELOW := 75.0
## Secondes à boire une chope, et humeur gagnée par seconde (deux fois plus pour le Gobelin).
const TAVERN_DRINK_TIME := 6.0
const TAVERN_MOOD := 5.0
## Après une chope : elle titube tant de secondes, et sa prochaine paie baisse d'autant.
const TIPSY_TIME := 25.0
const TIPSY_SALARY := 0.9
## Infirmerie : sous cette part de sa vie (hors combat), une créature va s'y soigner.
const INFIRMARY_BELOW := 0.6
const INFIRMARY_HEAL := 10.0      ## PV par seconde.
const INFIRMARY_NURSE_BOOST := 2.0 ## Avec une Goule rebouteuse au travail dans l'Infirmerie.
## Hôtel des monnaies : intérêts toutes les MINT_INTERVAL secondes, plafonnés par Hôtel.
const MINT_INTERVAL := 30.0
const MINT_INTEREST := 0.02
const MINT_CAP := 50
const MINT_WORK_GOLD := 1.0       ## Or frappé par seconde de travail (le Diablotin : 3).
## Chambre de torture : secondes de travail pour qu'un prisonnier change de camp.
const TORTURE_CONVERT_TIME := 45.0
const TORTURE_RESEARCH := 1.5     ## Points de recherche par seconde de torture.
const TORTURE_INTEL_TIME := 15.0  ## Secondes de torture pour apprendre la vague suivante (une fois par vague).
## Poste de garde : rayon (en cases) surveillé par un guetteur en poste, et rayon de l'alarme.
const GUARD_RADIUS := 8
const ALARM_RADIUS := 10
const ALARM_COOLDOWN := 20.0
## Puits de mana : mana maximum en plus par puits (MANA_WELL_MAX puits au plus).
const MANA_WELL_BONUS := 50.0
const MANA_WELL_MAX := 3
const MANA_MEDITATION := 0.6      ## Mana par seconde de méditation (l'Oracle : 3 fois plus).
## Crypte : places par Crypte, secondes avant de se relever, et mana que ça coûte.
const CRYPT_SLOTS := 2
const CRYPT_RISE_TIME := 60.0
const CRYPT_MANA := 60.0
## Nouvelles créatures : combien par salle, et au plus.
const GHOULS_PER_INFIRMARY := 2.0
const MAX_GHOULS := 4
const IMPS_PER_MINT := 3.0
const MAX_IMPS := 6
const EXECUTIONERS_PER_TORTURE := 2.0
const MAX_EXECUTIONERS := 3
const GARGOYLES_PER_GUARDPOST := 2.0
const MAX_GARGOYLES := 4
const ORACLES_PER_WELL := 2.0
const MAX_ORACLES := 3
const NECROMANCERS_PER_CRYPT := 1.0
const MAX_NECROMANCERS := 2
## Nécromancien : un héros qu'il abat se relève en Revenant pour tant de secondes.
const NECRO_RAISE_TIME := 30.0

# --- L'IA des créatures et des ouvriers (règles 2.8, voir creature.gd et worker.gd) ----
## CHOIX DE LA CIBLE : une créature attaque le héros le plus proche, mais certaines
## cibles « comptent » comme si elles étaient plus près, de tant de pixels (une case = 32) :
const TARGET_STICKY := 24.0    ## ... celui qu'elle combat déjà (elle ne change pas d'avis sans cesse) ;
const TARGET_WOUNDED := 48.0   ## ... un héros presque mort (en proportion de la vie qu'il a perdue) ;
const TARGET_HEALER := 64.0    ## ... un Clerc ou un Exorciste (ils soutiennent les autres) ;
const TARGET_LOOT := 64.0      ## ... un pillard qui emporte ton or ;
const TARGET_HEART := 96.0     ## ... un héros qui frappe ton cœur ;
const TARGET_GRUDGE := 48.0    ## ... le héros qui a blessé une Rancunière ;
const TARGET_EXECUTE := 64.0   ## ... un héros que le Bourreau peut achever.
## APPEL À L'AIDE : une créature qui engage le combat appelle celles qui sont à moins
## de tant de pixels (elles lâchent leur travail ; les endormies ne se réveillent pas) ...
const HELP_RADIUS := 320.0
## ... et ne rappelle pas avant tant de secondes.
const HELP_COOLDOWN := 6.0
## LE CŒUR APPELLE : frappé depuis moins de tant de secondes, il fait accourir toutes
## les créatures (même endormies) sur les héros à moins de tant de pixels de lui.
const HEART_CALL_TIME := 3.0
const HEART_CALL_RADIUS := 96.0
## LES OUVRIERS ONT PEUR : un héros à moins de tant de pixels, ils lâchent leur tâche
## et s'enfuient à tant de cases de là (le temps que tes créatures arrivent).
const WORKER_FEAR_RADIUS := 96.0
const WORKER_FLEE_CELLS := 5

# --- Règles 2.9 : repli des blessés, postes de défense, travail, héros et rival -------
## LE REPLI : sous tant de vie, une créature blessée quitte le combat pour l'Infirmerie
## (ou son lit) et n'y revient qu'à FLEE_RECOVER (70 %) de sa vie. Pas les Bagarreuses,
## ni les morts-vivants, ni quand le cœur est frappé (le dernier carré). Les Peureuses,
## elles, fuient dès 35 % (leur trait), même quand le cœur est frappé.
const CREATURE_RETREAT_BELOW := 0.25
## LES POSTES DE DÉFENSE : au plus tant d'étendards (gratuits). Une créature y monte
## la garde (à tant de cases au plus de l'étendard) pendant tant de secondes, et y voit
## les héros tant de fois plus loin.
const MAX_RALLY_FLAGS := 3
const RALLY_RADIUS := 1
const RALLY_DURATION := 30.0
const RALLY_AGGRO_BONUS := 1.5
## L'intérêt de la garde, comparé aux travaux (voir « Le travail » ci-dessous) : faible en
## temps calme, très fort quand une vague arrive dans moins de RALLY_WAVE_SOON secondes
## (ou qu'elle est en cours).
const RALLY_SCORE := 0.35
const RALLY_WAVE_SCORE := 3.0
const RALLY_WAVE_SOON := 30.0
## LE TRAVAIL : la créature fait le travail le plus UTILE pour elle (voir creature.gd,
## _job_scores), pas un travail tiré au sort. Chaque créature déjà sur ce travail en
## réduit l'intérêt (1 / (1 + tant x leur nombre)), et un peu de hasard (± tant) départage.
const WORK_CROWD_PENALTY := 0.5
const WORK_JITTER := 0.15
## LES HÉROS CHOISISSENT LEUR CIBLE (comme tes créatures, voir TARGET_*) : ces cibles
## comptent comme si elles étaient plus proches de tant de pixels.
const HERO_TARGET_STICKY := 24.0   ## ... celle qu'ils combattent déjà ;
const HERO_TARGET_WOUNDED := 32.0  ## ... une créature presque morte ;
const HERO_TARGET_RANGED := 48.0   ## ... tes tireurs (Sorcier, Oracle, Salamandre...) ;
const HERO_TARGET_HEALER := 64.0   ## ... la Goule rebouteuse.
## L'EMBUSCADE : dès la vague AMBUSH_FROM_WAVE, une vague sur AMBUSH_EVERY attend à
## l'entrée que tant de tes créatures (en proportion) dorment, au plus tant de secondes.
const AMBUSH_FROM_WAVE := 6
const AMBUSH_EVERY := 2
const AMBUSH_SLEEP_SHARE := 0.25
const AMBUSH_MAX_WAIT := 25.0
## LE RIVAL OPPORTUNISTE : tant de secondes après une vague repoussée, si tes créatures
## n'ont plus en moyenne que tant de leur vie, il lance ses troupes tout de suite (avec
## tant de créatures en plus), sauf si son attaque était déjà prévue dans moins de
## RIVAL_OPPORTUNITY_MIN_TIMER secondes.
const RIVAL_OPPORTUNITY_DELAY := 6.0
const RIVAL_OPPORTUNITY_HP := 0.7
const RIVAL_OPPORTUNITY_BONUS := 1
const RIVAL_OPPORTUNITY_MIN_TIMER := 15.0

# --- Atelier ----------------------------------------------------------------------
## L'Atelier arrête de fabriquer des pièges quand le stock total atteint ce nombre.
const MAX_TRAP_STOCK := 9

# --- Divers -----------------------------------------------------------------------
const AUTOSAVE_INTERVAL := 60.0   ## Secondes entre deux sauvegardes automatiques.

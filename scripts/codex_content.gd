class_name CodexContent
## LES TEXTES DU CODEX (les règles expliquées aux joueurs).
##
## Pour ajouter ou modifier une règle dans le codex, il suffit de changer cette
## liste : chaque article a une catégorie, un titre et un texte. Le texte peut
## utiliser des balises BBCode : [b]gras[/b], [color=#ffd54a]couleur[/color]...
## Les tableaux des créatures, héros, salles, défenses, sorts et recherches sont
## ajoutés AUTOMATIQUEMENT par codex.gd, à partir des catalogues du jeu.

const ARTICLES := [
	{"category": "Bases", "title": "Le but du jeu",
	"text": "Tu es un [b]Seigneur des Profondeurs[/b]. Ton [color=#ff6b6b]cœur[/color] est au centre de ton donjon : s'il est détruit, la partie est perdue.\n\nCreuse, récolte de l'or, construis des salles pour attirer des créatures, et défends-toi contre les héros qui viennent par l'entrée grise."},
	{"category": "Bases", "title": "Creuser et l'or",
	"text": "Avec l'outil [b]Creuser[/b], glisse le doigt sur la terre pour la marquer : tes ouvriers la creusent.\n\nLes filons dorés donnent de l'or. Les ouvriers le portent dans leurs poches (120 au maximum) jusqu'au [b]Trésor[/b]. Sans place au Trésor, l'or reste dans leurs poches."},
	{"category": "Bases", "title": "Le territoire",
	"text": "Quand ils n'ont rien à creuser, les ouvriers [b]revendiquent[/b] le sol creusé qui touche ton territoire (dalles rouges).\n\nOn ne construit des salles et des défenses que sur son territoire. Plus il est grand, plus la mana se recharge vite. Des torches l'éclairent."},
	{"category": "Bases", "title": "Contrôles",
	"text": "- [b]Un doigt[/b] : peindre (creuser, construire, démolir) ou toucher (main, sorts, pièges).\n- [b]Deux doigts[/b] : déplacer la vue ; pincer pour zoomer.\n- [b]Mini-carte[/b] : la toucher pour y aller.\n- [b]x1 / x2 / x3[/b] : vitesse du jeu. [b]Pause[/b] : sauvegarder, réglages, codex."},
	{"category": "Créatures", "title": "Attirer des créatures",
	"text": "Relie le [color=#b388ff]portail violet[/color] à ton donjon en creusant un couloir. Une créature arrive régulièrement si tu as un lit libre (une case de Repaire = un lit) et les salles qu'elle demande (voir le tableau des créatures)."},
	{"category": "Créatures", "title": "Besoins et humeur",
	"text": "Les créatures dorment au Repaire, mangent à la Champignonnière et sont payées à chaque [b]jour de paie[/b].\n\nSi elles ont faim, sont épuisées, n'ont pas de lit ou ne sont pas payées, leur humeur baisse. À zéro, elles repartent par le portail. Le [b]Temple[/b] les rend plus heureuses."},
	{"category": "Créatures", "title": "Travail et niveaux",
	"text": "Quand tout va bien, les créatures travaillent : recherche à la [b]Bibliothèque[/b], fabrication à l'[b]Atelier[/b], entraînement, prière au [b]Temple[/b].\n\nLe combat et l'entraînement donnent de l'expérience : niveau 1 à 5, +20 % de vie et de dégâts par niveau, mais +25 % de salaire."},
	{"category": "Prison", "title": "Capturer les héros",
	"text": "Avec au moins un [b]Attrapeur de cauchemar[/b] et une cellule de [b]Prison[/b] libre, un héros vaincu tombe [b]assommé[/b] au lieu de mourir. Une barre jaune montre le temps qu'il reste.\n\nUn Attrapeur vient le ramasser et le porte en prison : tu touches sa rançon. Si personne n'arrive à temps, il meurt.\n\nChaque prisonnier interrogé fait avancer la recherche. Démolir sa cellule le libère : il s'évade !"},
	{"category": "Prison", "title": "Les sacrifices",
	"text": "L'[b]Atelier[/b] fabrique des [b]Autels de sacrifice[/b] (2 au maximum). Pose-en un dans un couloir de ton territoire.\n\nAvec l'outil [b]Sacrifier[/b], touche un prisonnier (un poignard apparaît au-dessus de lui ; touche-le encore pour annuler). Un Attrapeur le conduit à l'autel : le sacrifice rapporte [color=#ffd54a]3 fois sa rançon[/color] en or."},
	{"category": "Prison", "title": "Le Cimetière",
	"text": "Le [b]Cimetière[/b] se découvre par la recherche. Chaque case est une tombe.\n\nQuand un héros meurt (au combat ou sur l'autel), son corps est enterré dans une tombe libre. Une lueur verte s'en échappe : environ une minute plus tard, il se relève en [b]Revenant[/b], un squelette guerrier qui te sert. Il lui faut un lit libre au Repaire, et il ne demande qu'un petit salaire."},
	{"category": "Défense", "title": "Les héros",
	"text": "Les héros arrivent par vagues à l'entrée grise et marchent vers ton cœur. S'il n'y a pas de couloir, ils creusent (le Nain très vite). Ils préfèrent contourner les portes.\n\nTes créatures les combattent d'elles-mêmes. Avec la [b]Main[/b], dépose tes créatures où il faut."},
	{"category": "Défense", "title": "Voleuses et Moines",
	"text": "Certains héros ont leur propre mission, et ne se battent que si on les coince.\n\nLa [b]Voleuse[/b] est discrète (à moitié transparente) : tes créatures ne la repèrent que de tout près. Elle file au [b]Trésor[/b], vole jusqu'à [color=#ffd54a]150 or[/color] et s'enfuit par l'entrée. Abattue, elle lâche son sac, que tes ouvriers rapportent. Si elle sort, l'or est perdu.\n\nLe [b]Moine libérateur[/b] va droit à la [b]Prison[/b] et crochète les cellules (barre bleue) : les prisonniers repartent au combat. Protège ta Prison avec des portes et des créatures."},
	{"category": "Créatures", "title": "Le Cerbère, gardien du Trésor",
	"text": "Le [b]Cerbère[/b] vient par le portail si tu as 2 cases de Repaire et 6 cases de Trésor. Il ne travaille pas : il [b]rôde dans le Trésor[/b] le plus proche de lui. Pose-le avec la Main près des coffres à protéger.\n\nSes trois truffes flairent les [b]Voleuses[/b] de loin, malgré leur discrétion."},
	{"category": "Défense", "title": "Le Champion du royaume",
	"text": "Toutes les 5 vagues, le [b]Champion du royaume[/b] mène l'attaque. Très résistant, il se soigne en continu, et son [color=#ffd54a]cri de guerre[/color] fait courir les héros autour de lui.\n\nRassemble tes meilleures créatures et garde du mana pour tes sorts. Vaincu, il rapporte une énorme rançon."},
	{"category": "Défense", "title": "Pièges, portes et sorts",
	"text": "Les pièges et les portes sont fabriqués à l'Atelier, puis posés dans les couloirs. Les sorts coûtent de la [color=#64b5f6]mana[/color], qui se recharge seule. Beaucoup de choses se débloquent par la recherche (voir le tableau)."},
	{"category": "Défense", "title": "Le maître rival",
	"text": "Dans certains niveaux, un maître rival a son propre donjon (cœur bleu). Il envoie ses créatures creuser jusqu'à toi. Dépose tes créatures près de son cœur : elles l'attaquent. Tes ouvriers peuvent revendiquer son territoire."},
]

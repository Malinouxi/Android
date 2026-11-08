class_name Spells
## Le catalogue des sorts du maître. Ils coûtent de la MANA, qui se recharge
## toute seule, d'autant plus vite que ton territoire est grand.
## Pour ajouter un sort : un nom À LA FIN de Type (l'ordre compte pour les
## sauvegardes), une entrée dans INFO, un outil dans hud.gd et son effet dans
## main.gd (_cast_spell). Les sorts se débloquent par la recherche (research.gd).
##
## Les héros apprennent à résister à la magie au fil des vagues (voir
## spell_resist dans hero.gd et « Résistance à la magie » dans rules.gd), et
## certains y sont insensibles ("immune" dans heroes.gd). L'Exorciste dissipe
## les sorts autour de lui.

enum Type {
	HEAL,       ## Soin : soigne tes unités dans une zone.
	LIGHTNING,  ## Éclair : foudroie les héros dans une petite zone.
	HASTE,      ## Hâte : une de tes unités court beaucoup plus vite un moment.
	WEB,        ## Toile du maître : les héros de la zone sont englués (ralentis).
	FIRESTORM,  ## Brasier : le sol de la zone s'embrase.
	TERROR,     ## Terreur : les héros de la zone s'enfuient vers l'entrée un moment.
	COLLAPSE,   ## Effondrement : le plafond d'un couloir s'écroule (la case redevient de la terre).
	POSSESSION, ## Possession : tu prends le contrôle d'une de tes créatures.
	WHIP,       ## Fouet : une unité travaille deux fois plus vite (mais son humeur baisse).
	FEAST,      ## Festin : toutes tes créatures sont rassasiées et contentes.
	EYE,        ## Œil du maître : révèle la prochaine vague, les Voleuses et les secrets proches.
	SUMMON,     ## Invocation d'urgence : un ouvrier de plus, pour un temps.
	TRANSMUTE,  ## Transmutation : change de la mana en or.
	RAISE,      ## Relever les morts : les héros enterrés au Cimetière se relèvent.
	CONVERT,    ## Conversion : un prisonnier change de camp.
	SANCTUARY,  ## Sanctuaire : tes unités près du Temple sont protégées.
	RECALL,     ## Rappel : toutes tes créatures reviennent au cœur.
}

## "mana" : prix ; "icon" : icône HD (assets/icons_hd) ; "sound" : son joué ;
## "target" : ce qu'il faut toucher ("zone", "unit", "creature", "cell", "prisoner",
## "anywhere") ; "room" : salle qu'il faut posséder pour le lancer ;
## "help" : la phrase affichée quand on choisit le sort (et dans le codex).
const INFO := {
	Type.HEAL: {"name": "Soin", "mana": 30, "radius": 56.0, "amount": 60.0, "color": Color(0.3, 1.0, 0.4, 0.6),
		"icon": "heal", "sound": "heal", "target": "zone",
		"help": "Soigne de 60 PV tes unités dans la zone touchée."},
	Type.LIGHTNING: {"name": "Éclair", "mana": 40, "radius": 32.0, "damage": 70.0, "color": Color(0.6, 0.85, 1.0, 0.8),
		"icon": "bolt", "sound": "lightning", "target": "zone",
		"help": "Foudroie les héros touchés (70 dégâts)."},
	Type.HASTE: {"name": "Hâte", "mana": 25, "duration": 15.0, "color": Color(0.3, 0.9, 1.0, 0.6),
		"icon": "haste", "sound": "haste", "target": "unit",
		"help": "Une de tes unités court beaucoup plus vite pendant 15 s."},
	Type.WEB: {"name": "Toile", "mana": 35, "radius": 48.0, "duration": 8.0, "color": Color(0.85, 0.85, 0.95, 0.7),
		"icon": "web", "sound": "zap", "target": "zone",
		"help": "Englue les héros de la zone : ils avancent deux fois moins vite pendant 8 s."},
	Type.FIRESTORM: {"name": "Brasier", "mana": 45, "radius": 44.0, "duration": 6.0, "color": Color(1.0, 0.45, 0.1, 0.7),
		"icon": "firestorm", "sound": "explosion", "target": "zone",
		"help": "Le sol de la zone brûle 6 s : les héros qui y passent prennent feu."},
	Type.TERROR: {"name": "Terreur", "mana": 50, "radius": 64.0, "duration": 6.0, "color": Color(0.55, 0.2, 0.75, 0.7),
		"icon": "terror", "sound": "horn", "target": "zone",
		"help": "Les héros de la zone fuient vers l'entrée pendant 6 s (pas les Paladins, Moines, Exorcistes ni le Champion)."},
	Type.COLLAPSE: {"name": "Effondrement", "mana": 60, "damage": 120.0, "color": Color(0.6, 0.45, 0.3, 0.8),
		"icon": "collapse", "sound": "door_break", "target": "cell",
		"help": "Touche un couloir (pas une salle ni un piège) : le plafond s'écroule, la case redevient de la terre et ce qui s'y trouve prend 120 dégâts."},
	Type.POSSESSION: {"name": "Possession", "mana": 55, "duration": 15.0, "damage_bonus": 1.5,
		"color": Color(0.9, 0.2, 0.3, 0.7), "icon": "possession", "sound": "level_up", "target": "creature",
		"help": "Touche une de tes créatures : pendant 15 s elle frappe 50 % plus fort, et va où tu touches (un héros : elle l'attaque)."},
	Type.WHIP: {"name": "Fouet", "mana": 20, "duration": 30.0, "work_factor": 2.0, "mood": 8.0,
		"color": Color(1.0, 0.6, 0.2, 0.6), "icon": "whip", "sound": "punch", "target": "unit",
		"help": "Une unité travaille deux fois plus vite pendant 30 s (une créature perd un peu d'humeur)."},
	Type.FEAST: {"name": "Festin", "mana": 60, "mood": 15.0, "color": Color(0.9, 0.75, 0.3, 0.6),
		"icon": "feast", "sound": "coins", "target": "anywhere",
		"help": "Toutes tes créatures n'ont plus faim et gagnent de l'humeur."},
	Type.EYE: {"name": "Œil du maître", "mana": 30, "duration": 20.0, "radius": 192.0,
		"color": Color(1.0, 0.85, 0.3, 0.5), "icon": "eye", "sound": "discovery", "target": "anywhere",
		"help": "Montre les héros de la prochaine vague, démasque les Voleuses pendant 20 s et révèle les secrets proches de l'endroit touché."},
	Type.SUMMON: {"name": "Invocation", "mana": 40, "duration": 60.0, "max": 4, "color": Color(0.5, 1.0, 0.5, 0.6),
		"icon": "summon", "sound": "portal", "target": "anywhere",
		"help": "Un ouvrier fantôme vient t'aider pendant 60 s (4 au plus à la fois)."},
	Type.TRANSMUTE: {"name": "Transmutation", "mana": 50, "gold": 150, "color": Color(1.0, 0.85, 0.2, 0.6),
		"icon": "transmute", "sound": "gold", "target": "anywhere",
		"help": "Change 50 mana en 150 or (il faut de la place au Trésor)."},
	Type.RAISE: {"name": "Relever les morts", "mana": 50, "duration": 45.0, "room": Rooms.Type.GRAVEYARD,
		"color": Color(0.45, 1.0, 0.3, 0.6), "icon": "raise", "sound": "portal", "target": "anywhere",
		"help": "Les héros enterrés au Cimetière se relèvent aussitôt. Si aucune tombe n'est pleine, un Revenant sort de terre pour 45 s."},
	Type.CONVERT: {"name": "Conversion", "mana": 70, "room": Rooms.Type.PRISON,
		"color": Color(0.7, 0.3, 1.0, 0.6), "icon": "convert", "sound": "capture", "target": "prisoner",
		"help": "Touche un prisonnier : il renie son roi et rejoint ton donjon (il lui faut un lit)."},
	Type.SANCTUARY: {"name": "Sanctuaire", "mana": 45, "duration": 20.0, "radius": 160.0, "protection": 0.4,
		"room": Rooms.Type.TEMPLE, "color": Color(0.75, 0.6, 1.0, 0.6), "icon": "sanctuary", "sound": "heal",
		"target": "temple",
		"help": "Touche ton Temple : tes unités tout autour prennent 40 % de dégâts en moins pendant 20 s."},
	Type.RECALL: {"name": "Rappel", "mana": 40, "color": Color(0.9, 0.3, 0.3, 0.6),
		"icon": "recall", "sound": "portal", "target": "anywhere",
		"help": "Toutes tes créatures disponibles reviennent d'un coup auprès du cœur."},
}

const MAX_MANA := 200.0
const START_MANA := 60.0
## Mana regagnée par seconde, plus 1 par tranche de TILES_PER_REGEN cases revendiquées,
## sans jamais dépasser MAX_REGEN par seconde.
const BASE_REGEN := 0.25
const TILES_PER_REGEN := 120
const MAX_REGEN := 1.5


static func display_name(type: int) -> String:
	return INFO[type]["name"]


static func mana_cost(type: int) -> int:
	return INFO[type]["mana"]


static func icon(type: int) -> String:
	return INFO[type]["icon"]


## La salle qu'il faut posséder pour lancer ce sort (Rooms.Type.NONE s'il n'en faut pas).
static func required_room(type: int) -> int:
	return INFO[type].get("room", Rooms.Type.NONE)


static func regen_per_second(claimed_tiles: int) -> float:
	return minf(MAX_REGEN, BASE_REGEN + float(claimed_tiles) / TILES_PER_REGEN)

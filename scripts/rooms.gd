class_name Rooms
## La liste des salles qu'on peut construire, avec leurs réglages.
##
## Ce script ne s'attache à aucun nœud : c'est juste un « catalogue » que les
## autres scripts consultent, par exemple Rooms.cost(Rooms.Type.TREASURY).
## Pour ajouter une salle : un nouveau nom dans Type, une entrée dans INFO.

enum Type {
	NONE,     ## Pas de salle : simple sol creusé.
	TREASURY, ## Trésor : stocke l'or rapporté par les ouvriers.
	LAIR,     ## Repaire : les créatures y dormiront (étape 3).
	FARM,     ## Champignonnière : fait pousser de la nourriture.
	LIBRARY,  ## Bibliothèque : les créatures y font de la recherche.
	WORKSHOP, ## Atelier : les créatures y fabriquent pièges et portes.
	TRAINING, ## Salle d'entraînement : les créatures y gagnent de l'expérience.
	PRISON,   ## Prison : les héros vaincus y sont capturés (et interrogés).
	TEMPLE,   ## Temple : les créatures y prient (humeur, soin, mana).
	GRAVEYARD, ## Cimetière : les héros morts y sont enterrés, puis se relèvent en Revenants.
	# --- Les « antres » (règles 2.7) : de quoi rendre le donjon plus vivant. ---
	TAVERN,    ## Taverne : la bière de champignons remonte l'humeur (et fait baisser le salaire).
	INFIRMARY, ## Infirmerie : les blessés s'y couchent et guérissent vite.
	MINT,      ## Hôtel des monnaies : intérêts sur l'or du Trésor, on y frappe des pièces.
	TORTURE,   ## Chambre de torture : les prisonniers parlent (vague suivante) et changent de camp.
	GUARDPOST, ## Poste de garde : les guetteurs démasquent Voleuses et éclaireurs, et sonnent l'alarme.
	MANA_WELL, ## Puits de mana : plus de mana au maximum, on y médite.
	CRYPT,     ## Crypte : tes créatures mortes y reposent, puis reviennent à la vie.
}

## Chaque salle se construit D'UN SEUL BLOC, à sa taille (« footprint », largeur x
## profondeur en cases, droite ou tournée d'un quart de tour) : on touche le sol
## et le chantier de toute la salle s'ouvre (voir main.gd, _build).
## "cost" : le prix de la salle entière. "build_time" : secondes de travail d'un
## ouvrier pour CHAQUE case de la salle (plusieurs ouvriers travaillent ensemble).
## "object" : ce qu'on trouve dans la salle (le modèle 3D, voir voxel_models.gd).
const INFO := {
	Type.TREASURY: {"name": "Trésor", "cost": 50, "color": Color("5a4a22"), "build_time": 4.0,
			"footprint": Vector2i(1, 2), "object": "coffre"},
	Type.LAIR: {"name": "Repaire", "cost": 40, "color": Color("3d2f4d"), "build_time": 5.0,
			"footprint": Vector2i(1, 1), "object": "lit"},
	Type.FARM: {"name": "Champignonnière", "cost": 50, "color": Color("2c4630"), "build_time": 5.0,
			"footprint": Vector2i(1, 1), "object": "carré de champignons"},
	Type.LIBRARY: {"name": "Bibliothèque", "cost": 300, "color": Color("2d4363"), "build_time": 8.0,
			"footprint": Vector2i(2, 3), "object": "rayonnages et pupitre"},
	Type.WORKSHOP: {"name": "Atelier", "cost": 260, "color": Color("47423c"), "build_time": 10.0,
			"footprint": Vector2i(2, 2), "object": "forge et enclume"},
	Type.TRAINING: {"name": "Entraînement", "cost": 320, "color": Color("5e352a"), "build_time": 8.0,
			"footprint": Vector2i(2, 4), "object": "arène et mannequins"},
	Type.PRISON: {"name": "Prison", "cost": 200, "color": Color("34343b"), "build_time": 9.0,
			"footprint": Vector2i(2, 2), "object": "4 cellules"},
	Type.TEMPLE: {"name": "Temple", "cost": 450, "color": Color("4a3a6a"), "build_time": 12.0,
			"footprint": Vector2i(2, 3), "object": "autel, statue et braseros"},
	Type.GRAVEYARD: {"name": "Cimetière", "cost": 70, "color": Color("2a3324"), "build_time": 7.0,
			"footprint": Vector2i(1, 1), "object": "tombe"},
	Type.TAVERN: {"name": "Taverne", "cost": 220, "color": Color("5d3a1a"), "build_time": 7.0,
			"footprint": Vector2i(2, 2), "object": "comptoir, tonneaux et cheminée"},
	Type.INFIRMARY: {"name": "Infirmerie", "cost": 240, "color": Color("3e4a3e"), "build_time": 8.0,
			"footprint": Vector2i(2, 2), "object": "paillasses et chaudron d'onguents"},
	Type.MINT: {"name": "Hôtel des monnaies", "cost": 400, "color": Color("6b5a1e"), "build_time": 10.0,
			"footprint": Vector2i(2, 2), "object": "four à fondre et presse à pièces"},
	Type.TORTURE: {"name": "Chambre de torture", "cost": 300, "color": Color("4a1c1c"), "build_time": 9.0,
			"footprint": Vector2i(2, 2), "object": "chevalet, cage et brasero"},
	Type.GUARDPOST: {"name": "Poste de garde", "cost": 150, "color": Color("4a4238"), "build_time": 7.0,
			"footprint": Vector2i(1, 2), "object": "tour de guet et cor d'alarme"},
	Type.MANA_WELL: {"name": "Puits de mana", "cost": 500, "color": Color("1f3550"), "build_time": 12.0,
			"footprint": Vector2i(2, 2), "object": "puits et cristaux de mana"},
	Type.CRYPT: {"name": "Crypte", "cost": 280, "color": Color("2b2733"), "build_time": 9.0,
			"footprint": Vector2i(2, 2), "object": "2 sarcophages et cierges"},
}

## Les salles où les créatures viennent travailler (voir creature.gd).
const WORK_ROOMS := [Type.LIBRARY, Type.WORKSHOP, Type.TRAINING, Type.TEMPLE, Type.TAVERN, Type.INFIRMARY,
		Type.MINT, Type.TORTURE, Type.GUARDPOST, Type.MANA_WELL, Type.CRYPT]
## Les salles faites d'un seul objet de plusieurs cases (un seul modèle 3D par salle).
const MULTI_CELL := [Type.TREASURY, Type.LIBRARY, Type.WORKSHOP, Type.TRAINING, Type.TEMPLE, Type.TAVERN,
		Type.INFIRMARY, Type.MINT, Type.TORTURE, Type.GUARDPOST, Type.MANA_WELL, Type.CRYPT]
## Le nom du modèle Blender de chaque salle (assets/models/rooms/<nom>.glb).
const MODEL_NAMES := {Type.LIBRARY: "library", Type.WORKSHOP: "workshop", Type.TRAINING: "training",
		Type.TEMPLE: "temple", Type.TAVERN: "tavern", Type.INFIRMARY: "infirmary", Type.MINT: "mint",
		Type.TORTURE: "torture", Type.GUARDPOST: "guardpost", Type.MANA_WELL: "mana_well"}

## L'icône HD des antres (assets/icons_hd/, faites dans Blender par tools/blender/icons.py).
const ICONS := {Type.TAVERN: "mug", Type.INFIRMARY: "salve", Type.MINT: "coin_press", Type.TORTURE: "pincers",
		Type.GUARDPOST: "watch_horn", Type.MANA_WELL: "mana_crystal", Type.CRYPT: "sarcophagus"}

## Or que peut contenir une case de trésor.
const TREASURY_CAPACITY := 400
## Secondes pour qu'un champignon pousse sur une case de champignonnière.
const FARM_GROW_TIME := 10.0
## Nombre maximum de champignons par case.
const FARM_MAX_FOOD := 3


static func display_name(type: int) -> String:
	return INFO[type]["name"]


static func cost(type: int) -> int:
	return INFO[type]["cost"]


## Secondes de travail pour construire une case (voir Rules.BUILD_TIME_FACTOR).
static func build_time(type: int) -> float:
	return INFO[type]["build_time"] * Rules.BUILD_TIME_FACTOR


## La taille de l'objet de la salle (voir "footprint").
static func footprint(type: int) -> Vector2i:
	return INFO[type].get("footprint", Vector2i(1, 1))


static func color(type: int) -> Color:
	return INFO[type]["color"]

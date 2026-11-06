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
}

## "footprint" : la taille (largeur x profondeur, en cases) de l'OBJET de la salle
## (le coffre, l'étagère...). Le jeu couvre chaque salle d'autant d'objets que sa
## forme le permet (voir dungeon_map.gd, _refurnish) ; une case qu'aucun objet ne
## couvre ne sert à rien. Les objets peuvent être tournés d'un quart de tour.
## "build_time" : secondes de travail d'un ouvrier pour construire UNE case
## (le coffre, le lit, l'étagère... : plus l'objet est important, plus c'est long).
const INFO := {
	Type.TREASURY: {"name": "Trésor", "cost": 25, "color": Color("5a4a22"), "build_time": 4.0,
			"footprint": Vector2i(1, 2), "object": "coffre"},
	Type.LAIR: {"name": "Repaire", "cost": 40, "color": Color("3d2f4d"), "build_time": 5.0,
			"footprint": Vector2i(1, 1), "object": "lit"},
	Type.FARM: {"name": "Champignonnière", "cost": 60, "color": Color("2c4630"), "build_time": 5.0,
			"footprint": Vector2i(1, 1), "object": "carré de champignons"},
	Type.LIBRARY: {"name": "Bibliothèque", "cost": 70, "color": Color("2d4363"), "build_time": 8.0,
			"footprint": Vector2i(2, 3), "object": "rayonnages et pupitre"},
	Type.WORKSHOP: {"name": "Atelier", "cost": 80, "color": Color("47423c"), "build_time": 10.0,
			"footprint": Vector2i(2, 2), "object": "forge et enclume"},
	Type.TRAINING: {"name": "Entraînement", "cost": 90, "color": Color("5e352a"), "build_time": 8.0,
			"footprint": Vector2i(2, 4), "object": "arène et mannequins"},
	Type.PRISON: {"name": "Prison", "cost": 60, "color": Color("34343b"), "build_time": 9.0,
			"footprint": Vector2i(1, 1), "object": "cellule"},
	Type.TEMPLE: {"name": "Temple", "cost": 100, "color": Color("4a3a6a"), "build_time": 12.0,
			"footprint": Vector2i(2, 3), "object": "autel et braseros"},
	Type.GRAVEYARD: {"name": "Cimetière", "cost": 70, "color": Color("2a3324"), "build_time": 7.0,
			"footprint": Vector2i(1, 1), "object": "tombe"},
}

## Les salles où les créatures viennent travailler (voir creature.gd).
const WORK_ROOMS := [Type.LIBRARY, Type.WORKSHOP, Type.TRAINING, Type.TEMPLE]

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

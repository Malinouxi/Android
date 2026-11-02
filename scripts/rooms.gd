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
}

const INFO := {
	Type.TREASURY: {"name": "Trésor", "cost": 25, "color": Color("5a4a22")},
	Type.LAIR: {"name": "Repaire", "cost": 40, "color": Color("3d2f4d")},
	Type.FARM: {"name": "Champignonnière", "cost": 60, "color": Color("2c4630")},
	Type.LIBRARY: {"name": "Bibliothèque", "cost": 70, "color": Color("2d4363")},
	Type.WORKSHOP: {"name": "Atelier", "cost": 80, "color": Color("47423c")},
	Type.TRAINING: {"name": "Entraînement", "cost": 90, "color": Color("5e352a")},
}

## Les salles où les créatures viennent travailler (voir creature.gd).
const WORK_ROOMS := [Type.LIBRARY, Type.WORKSHOP, Type.TRAINING]

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


static func color(type: int) -> Color:
	return INFO[type]["color"]

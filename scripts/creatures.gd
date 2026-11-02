class_name Creatures
## Le catalogue des créatures : leurs réglages et ce qu'il faut construire
## pour qu'elles viennent par le portail.
## Pour ajouter une créature : un nom dans Type et une entrée dans INFO.

enum Type { KOBOLD, ORC, WARLOCK }

## "requires" : nombre minimum de cases de chaque salle pour attirer la créature.
## "salary" : or versé à chaque jour de paie.
## "hp", "damage", "range" (pixels), "attack_interval" (secondes) : le combat.
const INFO := {
	Type.KOBOLD: {
		"name": "Kobold", "sprite": "kobold", "color": Color("ff9800"), "size": 7.0, "speed": 105.0,
		"salary": 15, "requires": {Rooms.Type.LAIR: 1},
		"hp": 60.0, "damage": 6.0, "range": 26.0, "attack_interval": 0.8,
	},
	Type.ORC: {
		"name": "Orque", "sprite": "orc", "color": Color("4e7d2a"), "size": 10.0, "speed": 75.0,
		"salary": 40, "requires": {Rooms.Type.LAIR: 4, Rooms.Type.FARM: 4},
		"hp": 160.0, "damage": 14.0, "range": 28.0, "attack_interval": 1.1,
	},
	Type.WARLOCK: {
		# Le Sorcier attaque à distance : sa portée fait 3 cases.
		"name": "Sorcier", "sprite": "warlock", "color": Color("8e6bd6"), "size": 8.0, "speed": 85.0,
		"salary": 70, "requires": {Rooms.Type.LAIR: 6, Rooms.Type.TREASURY: 9},
		"hp": 80.0, "damage": 18.0, "range": 96.0, "attack_interval": 1.4,
	},
}


static func info(type: int) -> Dictionary:
	return INFO[type]


## Liste des créatures que le donjon attire actuellement.
static func attracted_types(map: DungeonMap) -> Array[int]:
	var result: Array[int] = []
	for type: int in INFO:
		var requires: Dictionary = INFO[type]["requires"]
		var ok := true
		for room: int in requires:
			if map.count_room_tiles(room) < requires[room]:
				ok = false
		if ok:
			result.append(type)
	return result

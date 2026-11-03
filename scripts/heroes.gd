class_name Heroes
## Le catalogue des héros qui attaquent le donjon.
## Pour ajouter un héros : un nom dans Type et une entrée dans INFO.

enum Type { ADVENTURER, THIEF, KNIGHT, CLERIC, ARCHER }

## "reward" : or gagné quand on le bat (rangé au Trésor s'il y a de la place).
## "first_wave" : numéro de la première vague où il peut apparaître.
const INFO := {
	Type.ADVENTURER: {
		"name": "Aventurier", "sprite": "adventurer", "color": Color("42a5f5"), "size": 8.0, "speed": 70.0,
		"hp": 90.0, "damage": 8.0, "range": 26.0, "attack_interval": 1.0,
		"reward": 40, "first_wave": 1,
	},
	Type.THIEF: {
		"name": "Voleuse", "sprite": "thief", "color": Color("80deea"), "size": 7.0, "speed": 105.0,
		"hp": 50.0, "damage": 6.0, "range": 26.0, "attack_interval": 0.7,
		"reward": 30, "first_wave": 2,
	},
	Type.KNIGHT: {
		"name": "Chevalier", "sprite": "knight", "color": Color("eceff1"), "size": 10.0, "speed": 55.0,
		"hp": 220.0, "damage": 14.0, "range": 28.0, "attack_interval": 1.3,
		"reward": 80, "first_wave": 4,
	},
	Type.CLERIC: {
		# Le clerc soigne les héros proches (voir hero.gd).
		"name": "Clerc", "sprite": "cleric", "color": Color("eceff1"), "size": 8.0, "speed": 65.0,
		"hp": 80.0, "damage": 5.0, "range": 26.0, "attack_interval": 1.2,
		"reward": 60, "first_wave": 3,
	},
	Type.ARCHER: {
		# L'archer tire de loin (portée : un peu plus de 3 cases).
		"name": "Archer", "sprite": "archer", "color": Color("2e7d32"), "size": 8.0, "speed": 75.0,
		"hp": 60.0, "damage": 10.0, "range": 110.0, "attack_interval": 1.2,
		"reward": 50, "first_wave": 3,
	},
}
## Le clerc soigne les héros à moins de CLERIC_HEAL_RADIUS pixels, toutes les CLERIC_HEAL_INTERVAL s.
const CLERIC_HEAL_AMOUNT := 20.0
const CLERIC_HEAL_RADIUS := 80.0
const CLERIC_HEAL_INTERVAL := 3.0


static func info(type: int) -> Dictionary:
	return INFO[type]


## Les héros qui peuvent apparaître à une vague donnée.
static func types_for_wave(wave: int) -> Array[int]:
	var result: Array[int] = []
	for type: int in INFO:
		if wave >= INFO[type]["first_wave"]:
			result.append(type)
	return result

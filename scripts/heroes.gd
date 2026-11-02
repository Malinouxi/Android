class_name Heroes
## Le catalogue des héros qui attaquent le donjon.
## Pour ajouter un héros : un nom dans Type et une entrée dans INFO.

enum Type { ADVENTURER, THIEF, KNIGHT }

## "reward" : or gagné quand on le bat (rangé au Trésor s'il y a de la place).
## "first_wave" : numéro de la première vague où il peut apparaître.
const INFO := {
	Type.ADVENTURER: {
		"name": "Aventurier", "color": Color("42a5f5"), "size": 8.0, "speed": 70.0,
		"hp": 90.0, "damage": 8.0, "range": 26.0, "attack_interval": 1.0,
		"reward": 40, "first_wave": 1,
	},
	Type.THIEF: {
		"name": "Voleuse", "color": Color("80deea"), "size": 7.0, "speed": 105.0,
		"hp": 50.0, "damage": 6.0, "range": 26.0, "attack_interval": 0.7,
		"reward": 30, "first_wave": 2,
	},
	Type.KNIGHT: {
		"name": "Chevalier", "color": Color("eceff1"), "size": 10.0, "speed": 55.0,
		"hp": 220.0, "damage": 14.0, "range": 28.0, "attack_interval": 1.3,
		"reward": 80, "first_wave": 4,
	},
}


static func info(type: int) -> Dictionary:
	return INFO[type]


## Les héros qui peuvent apparaître à une vague donnée.
static func types_for_wave(wave: int) -> Array[int]:
	var result: Array[int] = []
	for type: int in INFO:
		if wave >= INFO[type]["first_wave"]:
			result.append(type)
	return result

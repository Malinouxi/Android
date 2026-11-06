class_name Creatures
## Le catalogue des créatures : leurs réglages et ce qu'il faut construire
## pour qu'elles viennent par le portail.
## Pour ajouter une créature : un nom dans Type et une entrée dans INFO.

enum Type { KOBOLD, ORC, WARLOCK, SPIDER, DEMON, BAT, GOLEM, VAMPIRE, SALAMANDER, CATCHER, REVENANT, CERBERUS }

## "requires" : nombre minimum de SALLES de chaque type pour attirer la créature
## (une salle = un bloc entier : un lit de Repaire, une Bibliothèque 2 x 3...).
## "limit_room", "limit_each", "limit_max" (créatures rares) : au plus limit_each
## créatures de l'espèce par salle limit_room, et jamais plus de limit_max.
## "salary" : or versé à chaque jour de paie.
## "hp", "damage", "range" (pixels), "attack_interval" (secondes) : le combat.
## Capacités spéciales facultatives (voir unit.gd, load_abilities) :
##   "armor" (part des dégâts ignorés), "lifesteal" (part des dégâts regagnée en vie),
##   "splash" (rayon des dégâts par ricochet), "regen" (vie par seconde),
##   "slow" (secondes de ralentissement infligées), "attack_sound" (nom d'un son).
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
		"salary": 70, "requires": {Rooms.Type.LAIR: 6, Rooms.Type.LIBRARY: 1},
		"limit_room": Rooms.Type.LIBRARY, "limit_each": Rules.WARLOCKS_PER_LIBRARY, "limit_max": Rules.MAX_WARLOCKS,
		"hp": 80.0, "damage": 18.0, "range": 96.0, "attack_interval": 1.4,
	},
	Type.SPIDER: {
		# L'araignée : rapide, et ses morsures ralentissent les héros.
		"name": "Araignée", "sprite": "spider", "color": Color("6a3d8f"), "size": 8.0, "speed": 125.0,
		"salary": 30, "requires": {Rooms.Type.LAIR: 3, Rooms.Type.PRISON: 1},
		"hp": 70.0, "damage": 7.0, "range": 26.0, "attack_interval": 0.7, "slow": 3.0,
	},
	Type.DEMON: {
		# Le démon : la créature la plus puissante... et la plus chère.
		"name": "Démon", "sprite": "demon", "color": Color("c62828"), "size": 11.0, "speed": 70.0,
		"salary": 120, "requires": {Rooms.Type.LAIR: 8, Rooms.Type.TEMPLE: 1, Rooms.Type.TRAINING: 1},
		"limit_room": Rooms.Type.TEMPLE, "limit_each": Rules.DEMONS_PER_TEMPLE, "limit_max": Rules.MAX_DEMONS,
		"hp": 300.0, "damage": 26.0, "range": 30.0, "attack_interval": 1.2,
	},
	Type.BAT: {
		# La chauve-souris : très rapide, pas chère, mais fragile.
		"name": "Chauve-souris", "sprite": "bat", "color": Color("6d5a85"), "size": 7.0, "speed": 150.0,
		"salary": 10, "requires": {Rooms.Type.LAIR: 2, Rooms.Type.FARM: 2},
		"hp": 45.0, "damage": 5.0, "range": 26.0, "attack_interval": 0.6,
	},
	Type.GOLEM: {
		# Le golem de pierre : lent, mais son armure arrête un tiers des coups.
		"name": "Golem", "sprite": "golem", "color": Color("8d8d8d"), "size": 10.0, "speed": 50.0,
		"salary": 50, "requires": {Rooms.Type.LAIR: 4, Rooms.Type.WORKSHOP: 1},
		"hp": 260.0, "damage": 14.0, "range": 28.0, "attack_interval": 1.4, "armor": 0.35,
	},
	Type.VAMPIRE: {
		# Le vampire : il se soigne avec une partie des dégâts qu'il inflige.
		"name": "Vampire", "sprite": "vampire", "color": Color("b71c1c"), "size": 9.0, "speed": 90.0,
		"salary": 85, "requires": {Rooms.Type.LAIR: 6, Rooms.Type.PRISON: 2},
		"limit_room": Rooms.Type.PRISON, "limit_each": Rules.VAMPIRES_PER_PRISON, "limit_max": Rules.MAX_VAMPIRES,
		"hp": 160.0, "damage": 17.0, "range": 28.0, "attack_interval": 1.0, "lifesteal": 0.35,
	},
	Type.SALAMANDER: {
		# La salamandre : son souffle de feu touche aussi les héros autour de la cible.
		"name": "Salamandre", "sprite": "salamander", "color": Color("e64a19"), "size": 8.0, "speed": 85.0,
		"salary": 45, "requires": {Rooms.Type.LAIR: 4, Rooms.Type.TRAINING: 1},
		"hp": 110.0, "damage": 12.0, "range": 64.0, "attack_interval": 1.3, "splash": 40.0,
		"attack_sound": "zap",
	},
	Type.CATCHER: {
		# L'Attrapeur de cauchemar : il ramasse les héros assommés et les porte en prison
		# (et conduit les prisonniers à l'autel de sacrifice). Voir creature.gd.
		"name": "Attrapeur de cauchemar", "sprite": "catcher", "color": Color("2f5d6b"), "size": 8.0,
		"speed": 110.0, "salary": 25, "requires": {Rooms.Type.LAIR: 2, Rooms.Type.PRISON: 1},
		"hp": 90.0, "damage": 6.0, "range": 26.0, "attack_interval": 1.0, "catcher": true,
	},
	Type.REVENANT: {
		# Le Revenant : un héros mort, enterré au Cimetière, qui se relève pour te servir.
		# "graveyard" : il ne vient jamais par le portail (voir main.gd, _update_graves).
		"name": "Revenant", "sprite": "revenant", "color": Color("9e9a86"), "size": 9.0, "speed": 70.0,
		# "undead" : un mort-vivant ne dort pas, ne mange pas et n'a pas besoin de lit.
		"salary": 10, "requires": {Rooms.Type.GRAVEYARD: 1}, "graveyard": true, "undead": true,
		"hp": 130.0, "damage": 12.0, "range": 28.0, "attack_interval": 1.1, "armor": 0.15,
	},
	Type.CERBERUS: {
		# Le Cerbère : il ne travaille pas, il GARDE le Trésor (il y rôde sans cesse).
		# Ses trois truffes flairent les Voleuses de loin, malgré leur discrétion.
		"name": "Cerbère", "sprite": "cerberus", "color": Color("3b2a2a"), "size": 11.0, "speed": 95.0,
		"salary": 35, "requires": {Rooms.Type.LAIR: 2, Rooms.Type.TREASURY: Rules.CERBERUS_TREASURY_ROOMS},
		"hp": 200.0, "damage": 16.0, "range": 28.0, "attack_interval": 0.9,
		"guard": Rooms.Type.TREASURY, "keen_nose": true,
		# Limite : un Cerbère par CERBERUS_TREASURY_ROOMS salles de Trésor, « limit_max » au plus.
		"limit_room": Rooms.Type.TREASURY, "limit_each": 1.0 / Rules.CERBERUS_TREASURY_ROOMS,
		"limit_max": Rules.MAX_CERBERUS,
	},
}


static func info(type: int) -> Dictionary:
	return INFO[type]


## Liste des créatures que le donjon attire actuellement.
static func attracted_types(map: DungeonMap) -> Array[int]:
	var result: Array[int] = []
	for type: int in INFO:
		if INFO[type].get("graveyard", false):
			continue # Le Revenant naît au Cimetière, pas au portail.
		var requires: Dictionary = INFO[type]["requires"]
		var ok := true
		for room: int in requires:
			if map.count_rooms(room) < requires[room]:
				ok = false
		if ok:
			result.append(type)
	return result


## Combien de créatures de cette espèce le donjon peut accueillir (-1 = sans limite).
static func allowed_count(type: int, map: DungeonMap) -> int:
	var info: Dictionary = INFO[type]
	if not info.has("limit_room"):
		return -1
	return mini(int(map.count_rooms(info["limit_room"]) * float(info["limit_each"]) + 0.001), info["limit_max"])

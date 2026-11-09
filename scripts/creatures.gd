class_name Creatures
## Le catalogue des créatures : leurs réglages et ce qu'il faut construire
## pour qu'elles viennent par le portail.
## Pour ajouter une créature : un nom dans Type et une entrée dans INFO.

enum Type { KOBOLD, ORC, WARLOCK, SPIDER, DEMON, BAT, GOLEM, VAMPIRE, SALAMANDER, CATCHER, REVENANT, CERBERUS,
		COLOSSUS, RENEGADE, GOBLIN, GHOUL, IMP, EXECUTIONER, GARGOYLE, ORACLE, NECROMANCER }

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
## Talents des créatures des antres (voir creature.gd) :
##   "brewer" (la Taverne lui fait deux fois plus plaisir), "healer" (soigne ses voisines :
##   {"radius", "amount", "interval"}), "nurse" (double les soins de l'Infirmerie où elle
##   travaille), "gold_hit" (or volé à chaque coup), "execute" (dégâts doublés contre un
##   héros sous cette part de sa vie), "work_bonus" ({salle: multiplicateur}),
##   "raise_on_kill" (un héros qu'elle abat se relève en Revenant pour un temps).
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
	Type.COLOSSUS: {
		# Le Colosse ancien : le gardien des profondeurs, vaincu, s'est soumis.
		# "graveyard" : il ne vient jamais par le portail ; "undead" : il ne dort ni ne
		# mange (c'est un être de pierre et de magie). Unique : un seul par Colosse vaincu.
		"name": "Colosse ancien", "sprite": "golem", "color": Color("d0632e"), "size": 14.0, "speed": 55.0,
		"salary": 60, "requires": {}, "graveyard": true, "undead": true, "ancient": true,
		"hp": 800.0, "damage": 30.0, "range": 34.0, "attack_interval": 1.5, "armor": 0.3, "splash": 40.0,
		"tint": Color(1.25, 0.6, 0.35),
	},
	Type.RENEGADE: {
		# Le Renégat : un prisonnier qui a renié son roi (sort Conversion). Il garde
		# l'allure du héros qu'il était, mais porte tes couleurs. Il lui faut un lit.
		# "graveyard" : il ne vient jamais par le portail.
		"name": "Renégat", "sprite": "adventurer", "color": Color("8d6e63"), "size": 8.0, "speed": 75.0,
		"salary": 20, "requires": {}, "graveyard": true, "renegade": true,
		"hp": 120.0, "damage": 11.0, "range": 28.0, "attack_interval": 1.0, "tint": Color(1.2, 0.75, 0.75),
	},	# --- Les créatures des antres (règles 2.7) : une par nouvelle salle. ---
	Type.GOBLIN: {
		# Le Gobelin brasseur : pas cher, bon artisan, et la Taverne le rend deux fois plus heureux.
		"name": "Gobelin brasseur", "sprite": "goblin", "color": Color("7cb342"), "size": 7.5, "speed": 95.0,
		"salary": 20, "requires": {Rooms.Type.LAIR: 2, Rooms.Type.TAVERN: 1},
		"hp": 80.0, "damage": 8.0, "range": 26.0, "attack_interval": 0.9,
		"brewer": true, "work_bonus": {Rooms.Type.WORKSHOP: 1.25, Rooms.Type.TAVERN: 2.0},
	},
	Type.GHOUL: {
		# La Goule rebouteuse : elle recoud ses voisines en plein combat, et soigne à l'Infirmerie.
		"name": "Goule rebouteuse", "sprite": "ghoul", "color": Color("8fa38a"), "size": 8.0, "speed": 85.0,
		"salary": 45, "requires": {Rooms.Type.LAIR: 3, Rooms.Type.INFIRMARY: 1},
		"limit_room": Rooms.Type.INFIRMARY, "limit_each": Rules.GHOULS_PER_INFIRMARY, "limit_max": Rules.MAX_GHOULS,
		"hp": 120.0, "damage": 10.0, "range": 26.0, "attack_interval": 1.0,
		"healer": {"radius": 72.0, "amount": 8.0, "interval": 3.0}, "nurse": true,
	},
	Type.IMP: {
		# Le Diablotin argentier : vif, fragile, il fait les poches des héros à chaque coup.
		"name": "Diablotin argentier", "sprite": "imp", "color": Color("c62828"), "size": 6.5, "speed": 130.0,
		"salary": 25, "requires": {Rooms.Type.LAIR: 2, Rooms.Type.MINT: 1},
		"limit_room": Rooms.Type.MINT, "limit_each": Rules.IMPS_PER_MINT, "limit_max": Rules.MAX_IMPS,
		"hp": 55.0, "damage": 6.0, "range": 26.0, "attack_interval": 0.6, "gold_hit": 3,
		"work_bonus": {Rooms.Type.MINT: 3.0},
	},
	Type.EXECUTIONER: {
		# Le Bourreau : il achève les héros affaiblis, et fait parler les prisonniers deux fois plus vite.
		"name": "Bourreau", "sprite": "executioner", "color": Color("3e2723"), "size": 10.5, "speed": 70.0,
		"salary": 75, "requires": {Rooms.Type.LAIR: 4, Rooms.Type.TORTURE: 1},
		"limit_room": Rooms.Type.TORTURE, "limit_each": Rules.EXECUTIONERS_PER_TORTURE,
		"limit_max": Rules.MAX_EXECUTIONERS,
		"hp": 220.0, "damage": 22.0, "range": 30.0, "attack_interval": 1.3, "execute": 0.3,
		"work_bonus": {Rooms.Type.TORTURE: 2.0},
	},
	Type.GARGOYLE: {
		# La Gargouille : une sentinelle de pierre (ni lit, ni repas). Elle garde le Poste de garde
		# et son regard perce la discrétion des Voleuses.
		"name": "Gargouille", "sprite": "gargoyle", "color": Color("78909c"), "size": 9.5, "speed": 80.0,
		"salary": 35, "requires": {Rooms.Type.LAIR: 1, Rooms.Type.GUARDPOST: 1}, "undead": true,
		"limit_room": Rooms.Type.GUARDPOST, "limit_each": Rules.GARGOYLES_PER_GUARDPOST,
		"limit_max": Rules.MAX_GARGOYLES,
		"hp": 180.0, "damage": 13.0, "range": 28.0, "attack_interval": 1.1, "armor": 0.25,
		"keen_nose": true, "sentinel": true,
	},
	Type.ORACLE: {
		# L'Oracle des ombres : magie à distance, et sa méditation au Puits donne 3 fois plus de mana.
		"name": "Oracle des ombres", "sprite": "oracle", "color": Color("18ffff"), "size": 8.0, "speed": 85.0,
		"salary": 80, "requires": {Rooms.Type.LAIR: 4, Rooms.Type.MANA_WELL: 1},
		"limit_room": Rooms.Type.MANA_WELL, "limit_each": Rules.ORACLES_PER_WELL, "limit_max": Rules.MAX_ORACLES,
		"hp": 90.0, "damage": 16.0, "range": 96.0, "attack_interval": 1.3, "attack_sound": "zap",
		"work_bonus": {Rooms.Type.MANA_WELL: 3.0},
	},
	Type.NECROMANCER: {
		# Le Nécromancien : les héros qu'il abat se relèvent un moment pour toi ; il veille la Crypte
		# (les morts s'y relèvent 3 fois plus vite).
		"name": "Nécromancien", "sprite": "necromancer", "color": Color("76ff03"), "size": 8.5, "speed": 80.0,
		"salary": 90, "requires": {Rooms.Type.LAIR: 5, Rooms.Type.CRYPT: 1},
		"limit_room": Rooms.Type.CRYPT, "limit_each": Rules.NECROMANCERS_PER_CRYPT,
		"limit_max": Rules.MAX_NECROMANCERS,
		"hp": 100.0, "damage": 15.0, "range": 90.0, "attack_interval": 1.4, "attack_sound": "zap",
		"raise_on_kill": Rules.NECRO_RAISE_TIME, "work_bonus": {Rooms.Type.CRYPT: 3.0},
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

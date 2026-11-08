class_name Heroes
## Le catalogue des héros qui attaquent le donjon.
## Pour ajouter un héros : un nom dans Type et une entrée dans INFO.

enum Type { ADVENTURER, THIEF, KNIGHT, CLERIC, ARCHER, RIVAL_KOBOLD, RIVAL_ORC, RIVAL_WARLOCK,
		DWARF, MAGE, PALADIN, GIANT, CHAMPION, MONK, COLOSSUS, SPECTRE, SCOUT }

## "reward" : or gagné quand on le bat (rangé au Trésor s'il y a de la place).
## "first_wave" : numéro de la première vague où il peut apparaître.
## Capacités facultatives : les mêmes que les créatures (voir creatures.gd), plus
##   "dig_speed" (vitesse de creusage, 3.0 = 3 fois plus vite) et
##   "door_damage" (multiplie les dégâts infligés aux portes).
## Et pour les habitants des profondeurs (jamais dans les vagues : "first_wave": 999) :
##   "guardian" (ne quitte pas sa caverne, voir hero.gd), "fearless" (ne fuit jamais),
##   "no_capture" (ne tombe pas assommé, ne finit pas au Cimetière),
##   "tint" (couleur du modèle), "alpha" (transparence).
const INFO := {
	Type.ADVENTURER: {
		"name": "Aventurier", "sprite": "adventurer", "color": Color("42a5f5"), "size": 8.0, "speed": 70.0,
		"hp": 90.0, "damage": 8.0, "range": 26.0, "attack_interval": 1.0,
		"reward": 40, "first_wave": 1,
	},
	Type.THIEF: {
		# La Voleuse : discrète, elle file au Trésor, vole de l'or et s'enfuit (voir hero.gd).
		"name": "Voleuse", "sprite": "thief", "color": Color("80deea"), "size": 7.0, "speed": 105.0,
		"hp": 50.0, "damage": 6.0, "range": 26.0, "attack_interval": 0.7,
		"reward": 30, "first_wave": 2, "stealth": true,
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
	# Les troupes du MAÎTRE RIVAL : elles se comportent comme des héros (elles
	# marchent vers ton cœur), mais ont l'allure de créatures teintées de bleu.
	# "first_wave": 999 -> elles n'apparaissent jamais dans les vagues de héros.
	Type.RIVAL_KOBOLD: {
		"name": "Kobold rival", "sprite": "kobold", "size": 7.0, "speed": 100.0, "rival": true,
		"hp": 70.0, "damage": 7.0, "range": 26.0, "attack_interval": 0.8,
		"reward": 30, "first_wave": 999,
	},
	Type.RIVAL_ORC: {
		"name": "Orque rival", "sprite": "orc", "size": 10.0, "speed": 72.0, "rival": true,
		"hp": 180.0, "damage": 15.0, "range": 28.0, "attack_interval": 1.1,
		"reward": 60, "first_wave": 999,
	},
	Type.RIVAL_WARLOCK: {
		"name": "Sorcier rival", "sprite": "warlock", "size": 8.0, "speed": 82.0, "rival": true,
		"hp": 90.0, "damage": 18.0, "range": 96.0, "attack_interval": 1.4,
		"reward": 70, "first_wave": 999,
	},
	Type.DWARF: {
		# Le nain : petit et costaud, il creuse 3 fois plus vite que les autres.
		"name": "Nain", "sprite": "dwarf", "size": 7.0, "speed": 60.0,
		"hp": 130.0, "damage": 10.0, "range": 26.0, "attack_interval": 1.0,
		"reward": 50, "first_wave": 2, "dig_speed": 3.0, "armor": 0.1,
	},
	Type.MAGE: {
		# La magicienne : boules de feu à distance, qui touchent plusieurs cibles.
		"name": "Magicienne", "sprite": "mage", "size": 8.0, "speed": 65.0,
		"hp": 70.0, "damage": 14.0, "range": 100.0, "attack_interval": 1.6,
		"reward": 70, "first_wave": 4, "splash": 48.0, "attack_sound": "zap",
	},
	Type.PALADIN: {
		# Le paladin : armure dorée, et il se soigne en continu.
		"name": "Paladin", "sprite": "paladin", "size": 9.0, "speed": 55.0,
		"hp": 260.0, "damage": 13.0, "range": 28.0, "attack_interval": 1.2,
		"reward": 110, "first_wave": 6, "armor": 0.25, "regen": 3.0,
	},
	Type.GIANT: {
		# Le géant : énorme et lent ; il défonce les portes 4 fois plus vite.
		"name": "Géant", "sprite": "giant", "size": 13.0, "speed": 45.0,
		"hp": 520.0, "damage": 24.0, "range": 34.0, "attack_interval": 1.8,
		"reward": 160, "first_wave": 8, "door_damage": 4.0, "armor": 0.1,
	},
	Type.CHAMPION: {
		# Le Champion du royaume : le chef des héros. Il mène une vague sur CHAMPION_EVERY
		# (jamais tiré au hasard : "first_wave": 999). Son cri de guerre accélère les
		# héros autour de lui (voir hero.gd, _war_cry).
		"name": "Champion du royaume", "sprite": "champion", "size": 12.0, "speed": 55.0,
		"hp": 900.0, "damage": 26.0, "range": 32.0, "attack_interval": 1.2,
		"reward": 400, "first_wave": 999, "armor": 0.2, "regen": 4.0, "boss": true, "war_cry": true,
	},
	Type.MONK: {
		# Le Moine libérateur : il va droit à la Prison et ouvre les cellules (voir hero.gd).
		"name": "Moine libérateur", "sprite": "monk", "size": 8.0, "speed": 70.0,
		"hp": 100.0, "damage": 6.0, "range": 26.0, "attack_interval": 1.2,
		"reward": 50, "first_wave": 3, "liberator": true,
	},
	Type.COLOSSUS: {
		# Le Colosse endormi : un gardien des profondeurs, neutre. Il ne marche pas sur
		# ton cœur, il défend sa caverne et son trésor. Vaincu, il se soumet et te sert.
		"name": "Colosse endormi", "sprite": "golem", "size": 15.0, "speed": 45.0,
		"hp": 1100.0, "damage": 32.0, "range": 36.0, "attack_interval": 1.7,
		"reward": 300, "first_wave": 999, "armor": 0.3, "splash": 40.0,
		"guardian": true, "fearless": true, "no_capture": true, "tint": Color(1.25, 0.6, 0.35),
	},
	Type.SPECTRE: {
		# Le Spectre : l'esprit d'une ruine oubliée, réveillé quand on la dérange.
		"name": "Spectre", "sprite": "revenant", "size": 9.0, "speed": 85.0,
		"hp": 120.0, "damage": 13.0, "range": 28.0, "attack_interval": 1.0,
		"reward": 30, "first_wave": 999, "lifesteal": 0.2,
		"fearless": true, "no_capture": true, "tint": Color(0.6, 0.8, 1.4), "alpha": 0.7,
	},
	Type.SCOUT: {
		# L'Éclaireur : il arrive avant certaines vagues, repère tes pièges et repart.
		# S'il ressort vivant, la vague suivante les connaît (voir main.gd).
		"name": "Éclaireur", "sprite": "adventurer", "size": 7.0, "speed": 120.0,
		"hp": 70.0, "damage": 6.0, "range": 26.0, "attack_interval": 0.9,
		"reward": 40, "first_wave": 999, "scout": true, "tint": Color(0.7, 1.0, 0.7),
	},
}
## Une vague sur CHAMPION_EVERY est menée par le Champion du royaume.
const CHAMPION_EVERY := 5
## Son cri de guerre : toutes les WAR_CRY_INTERVAL secondes, les héros à moins de
## WAR_CRY_RADIUS pixels courent plus vite pendant WAR_CRY_DURATION secondes.
const WAR_CRY_INTERVAL := 8.0
const WAR_CRY_RADIUS := 110.0
const WAR_CRY_DURATION := 4.0
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

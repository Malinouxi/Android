class_name Traits
## LES TRAITS DE CARACTÈRE DES CRÉATURES.
##
## Chaque créature tire 1 trait en arrivant (et une chance sur deux d'en avoir
## un second) : deux Orques ne sont plus jamais pareils. Les traits sont gardés
## dans la sauvegarde, affichés sur la fiche de la créature et dans le codex.
##
## Pour ajouter un trait : une entrée dans INFO, avec des « effets » parmi ceux-ci
## (creature.gd les lit avec Traits.mult et Traits.value) :
##   multiplicateurs (1.0 = normal) :
##     "salary", "damage", "speed", "hp", "hunger" (faim gagnée), "energy_loss"
##     (fatigue), "sleep" (énergie regagnée en dormant), "research", "craft",
##     "prayer" (effet de la prière), "decor_mood" (effet des décorations et braseros),
##     "aggro" (distance à laquelle elle repère les héros),
##     "treasure_damage" (dégâts à moins de TREASURE_RADIUS cases d'un Trésor),
##     "grudge" (dégâts contre le dernier héros qui l'a blessée),
##     "alone_damage" (dégâts quand aucune autre créature n'est à côté) ;
##   valeurs (0 = rien) :
##     "flee_below" (fuit le combat sous cette part de sa vie),
##     "fight_mood" (humeur gagnée par coup porté), "meal_mood" (humeur par repas),
##     "needs_temple" (humeur perdue par seconde sans Temple),
##     "crowd_mood" (humeur perdue par seconde quand CROWD créatures l'entourent).
## "excludes" : traits incompatibles. "living" : seulement pour les créatures
## vivantes (un Revenant ne mange pas et ne dort pas). "special" : jamais tiré au hasard.

const INFO := {
	"avare": {"name": "Avare", "salary": 1.3, "treasure_damage": 1.3,
		"text": "Salaire +30 %. Se bat 30 % mieux près d'un Trésor (son or !)."},
	"peureuse": {"name": "Peureuse", "speed": 1.2, "flee_below": 0.35, "excludes": ["bagarreuse"],
		"text": "Court 20 % plus vite, mais fuit le combat sous 35 % de vie et va se cacher dans son lit."},
	"bagarreuse": {"name": "Bagarreuse", "damage": 1.15, "aggro": 1.3, "fight_mood": 1.0,
		"excludes": ["peureuse"],
		"text": "+15 % de dégâts, repère les héros de plus loin, et chaque coup porté la rend plus heureuse."},
	"rancuniere": {"name": "Rancunière", "grudge": 1.4,
		"text": "+40 % de dégâts contre le dernier héros qui l'a blessée."},
	"pieuse": {"name": "Pieuse", "prayer": 2.0, "needs_temple": 0.3,
		"text": "Prie deux fois mieux (humeur, soins, mana). Sans Temple, son humeur baisse lentement."},
	"gourmande": {"name": "Gourmande", "hunger": 1.4, "meal_mood": 10.0, "living": true,
		"text": "A faim 40 % plus vite, mais chaque repas la réjouit (+10 d'humeur)."},
	"insomniaque": {"name": "Insomniaque", "energy_loss": 0.6, "sleep": 0.5, "living": true,
		"text": "Se fatigue 40 % moins vite, mais récupère deux fois moins vite en dormant."},
	"studieuse": {"name": "Studieuse", "research": 1.5, "craft": 1.5, "excludes": ["paresseuse"],
		"text": "Recherche et fabrication +50 %."},
	"paresseuse": {"name": "Paresseuse", "research": 0.5, "craft": 0.5, "salary": 0.75,
		"excludes": ["studieuse"],
		"text": "Travaille deux fois moins vite, mais demande 25 % de salaire en moins."},
	"coquette": {"name": "Coquette", "decor_mood": 2.0,
		"text": "Les décorations et les braseros lui font deux fois plus plaisir."},
	"solitaire": {"name": "Solitaire", "alone_damage": 1.25, "crowd_mood": 0.5,
		"text": "+25 % de dégâts quand aucune autre créature n'est près d'elle ; la foule l'agace."},
	"robuste": {"name": "Robuste", "hp": 1.2,
		"text": "+20 % de vie."},
	# « special » : jamais tiré au hasard (la Crypte le donne aux créatures qui reviennent).
	"revenue": {"name": "Revenue", "damage": 1.1, "salary": 0.8, "special": true,
		"text": "Revenue d'entre les morts (Crypte) : +10 % de dégâts, et demande 20 % de salaire en moins."},
}

## Chance d'avoir un second trait.
const SECOND_TRAIT_CHANCE := 0.5
## Rayon (en cases) autour d'un Trésor pour le trait Avare.
const TREASURE_RADIUS := 3
## Rayon (en pixels) dans lequel on compte les créatures voisines (Solitaire).
const NEIGHBOR_RADIUS := 96.0
## Nombre de voisines à partir duquel une Solitaire se sent dans la foule.
const CROWD := 3


## Tire au hasard les traits d'une nouvelle créature.
static func roll(undead: bool) -> Array[String]:
	var result: Array[String] = []
	var count := 2 if randf() < SECOND_TRAIT_CHANCE else 1
	var options: Array = INFO.keys()
	options.shuffle()
	for id: String in options:
		if result.size() >= count:
			break
		if (undead and INFO[id].get("living", false)) or INFO[id].get("special", false):
			continue
		var compatible := true
		for other in result:
			if INFO[id].get("excludes", []).has(other) or INFO[other].get("excludes", []).has(id):
				compatible = false
		if compatible:
			result.append(id)
	return result


## Le produit des multiplicateurs `key` des traits (1.0 si aucun n'en a).
static func mult(traits: Array, key: String) -> float:
	var result := 1.0
	for id in traits:
		if INFO.has(id):
			result *= float(INFO[id].get(key, 1.0))
	return result


## La somme des valeurs `key` des traits (0.0 si aucun n'en a).
static func value(traits: Array, key: String) -> float:
	var result := 0.0
	for id in traits:
		if INFO.has(id):
			result += float(INFO[id].get(key, 0.0))
	return result


## Les noms des traits, séparés par des virgules (« Avare, Bagarreuse »).
static func names(traits: Array) -> String:
	var result: Array[String] = []
	for id in traits:
		if INFO.has(id):
			result.append(INFO[id]["name"])
	return ", ".join(result)

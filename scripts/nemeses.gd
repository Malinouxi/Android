class_name Nemeses
extends RefCounted
## LES HÉROS QUI REVIENNENT (les « vétérans »).
##
## Un héros gravement blessé (sous Rules.HERO_FLEE_BELOW de sa vie) bat en
## retraite vers l'entrée grise (voir hero.gd). S'il sort vivant (ou si une
## Voleuse s'enfuit avec son butin), il n'est pas oublié : il reçoit un NOM et
## revient une ou deux vagues plus tard, plus fort (son rang monte à chaque
## évasion, jusqu'à MAX_RANK). Il se souvient :
##   - des PIÈGES qui l'ont blessé : il les évite, et ils lui font moins mal ;
##   - de l'ESPÈCE qui l'a le plus abîmé : il frappe plus fort ses membres (rancune).
## Abattu ou capturé, il ne reviendra plus.
##
## Ce registre garde les vétérans qui attendent leur retour ; main.gd le
## sauvegarde avec la partie. Une « fiche » de vétéran est un dictionnaire :
##   {"name", "type" (Heroes.Type), "rank", "traps" (liste de cases [x, y]),
##    "grudge" (Creatures.Type, ou -1), "return_wave"}.

const MAX_RANK := 3
## Nombre maximum de cases de pièges dont un vétéran se souvient.
const MAX_TRAPS := 12

const NAMES := ["Aldric", "Gauvain", "Bertrand", "Tristan", "Roland", "Lothaire", "Anselme",
		"Godefroy", "Perceval", "Enguerrand", "Thibaut", "Hugues", "Baudouin", "Ogier", "Amaury",
		"Foulques", "Gontran", "Raoul"]
const NAMES_FEMININE := ["Mélisende", "Aliénor", "Ysolde", "Clémence", "Brunehilde", "Ermengarde",
		"Viviane", "Sibylle", "Hersende", "Aude", "Mahaut", "Iseut"]
## Les héros dont le nom s'accorde au féminin (« la Voleuse »).
const FEMININE := [Heroes.Type.THIEF, Heroes.Type.MAGE]

## Les vétérans qui attendent de revenir.
var waiting: Array = []


## Un héros vient de s'échapper : on met à jour (ou on crée) sa fiche, et il
## reviendra à la vague return_wave. Renvoie la fiche.
func record(hero: Hero, return_wave: int) -> Dictionary:
	var entry: Dictionary = hero.nemesis.duplicate(true)
	if entry.is_empty():
		entry = {"name": _new_name(hero.type), "type": hero.type, "rank": 0, "traps": [], "grudge": -1}
	entry["rank"] = mini(int(entry["rank"]) + 1, MAX_RANK)
	var traps: Array = []
	for cell: Vector2i in hero.known_traps:
		traps.append(SaveGame.cell_to_array(cell))
	entry["traps"] = traps.slice(maxi(0, traps.size() - MAX_TRAPS))
	var grudge := hero.worst_enemy_species()
	if grudge >= 0:
		entry["grudge"] = grudge
	entry["return_wave"] = return_wave
	waiting.append(entry)
	return entry


## Les vétérans qui reviennent à cette vague (au plus max_count), retirés du registre.
func take_due(wave: int, max_count: int) -> Array:
	var due: Array = []
	for entry: Dictionary in waiting.duplicate():
		if due.size() >= max_count:
			break
		if int(entry["return_wave"]) <= wave:
			due.append(entry)
			waiting.erase(entry)
	return due


## Le nom complet d'un vétéran : « Aldric le Chevalier », « Ysolde la Voleuse ».
static func title(entry: Dictionary) -> String:
	var type := int(entry["type"])
	var type_name: String = Heroes.info(type)["name"]
	var article := "la " if FEMININE.has(type) else "le "
	if "AEÉIOUY".contains(type_name.substr(0, 1).to_upper()):
		article = "l'"
	return "%s %s%s" % [entry["name"], article, type_name]


## Pour accorder les messages : vrai si ce héros est une héroïne (la Voleuse...).
static func is_feminine(type: int) -> bool:
	return FEMININE.has(type)


## « vétéran », « vétéran aguerri », « vétéran légendaire » selon le rang.
static func rank_text(rank: int) -> String:
	return ["", "vétéran", "vétéran aguerri", "vétéran légendaire"][clampi(rank, 0, MAX_RANK)]


func _new_name(type: int) -> String:
	var pool: Array = NAMES_FEMININE if FEMININE.has(type) else NAMES
	# On évite de donner deux fois le même nom.
	var used := {}
	for entry: Dictionary in waiting:
		used[entry["name"]] = true
	var free := pool.filter(func(n: String) -> bool: return not used.has(n))
	return (free if not free.is_empty() else pool).pick_random()


func to_save() -> Array:
	return waiting.duplicate(true)


func load_save(data: Array) -> void:
	waiting.clear()
	for entry in data:
		if entry is Dictionary and entry.has("type") and entry.has("name"):
			waiting.append(entry)

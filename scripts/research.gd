class_name Research
extends RefCounted
## La recherche : les créatures qui étudient à la Bibliothèque produisent des
## points de recherche. Les découvertes arrivent dans l'ordre de ITEMS.
## Tout ce qui n'est pas dans ITEMS est disponible dès le début.
## (RefCounted : un simple objet, pas un nœud de la scène.)

## Émis à chaque découverte, avec l'entrée de ITEMS correspondante.
signal discovered(item: Dictionary)

## "kind" : "room", "defense" ou "spell" ; "id" : le type ; "points" : le coût.
const ITEMS := [
	{"name": "Atelier", "kind": "room", "id": Rooms.Type.WORKSHOP, "points": 80},
	{"name": "Pointes", "kind": "defense", "id": Defenses.Type.SPIKES, "points": 60},
	{"name": "Sort Fouet", "kind": "spell", "id": Spells.Type.WHIP, "points": 70},
	{"name": "Prison", "kind": "room", "id": Rooms.Type.PRISON, "points": 100},
	{"name": "Taverne", "kind": "room", "id": Rooms.Type.TAVERN, "points": 110},
	{"name": "Sort Toile", "kind": "spell", "id": Spells.Type.WEB, "points": 110},
	{"name": "Salle d'entraînement", "kind": "room", "id": Rooms.Type.TRAINING, "points": 120},
	{"name": "Infirmerie", "kind": "room", "id": Rooms.Type.INFIRMARY, "points": 140},
	{"name": "Sort Festin", "kind": "spell", "id": Spells.Type.FEAST, "points": 120},
	{"name": "Sort Éclair", "kind": "spell", "id": Spells.Type.LIGHTNING, "points": 150},
	{"name": "Porte", "kind": "defense", "id": Defenses.Type.DOOR, "points": 180},
	{"name": "Poste de garde", "kind": "room", "id": Rooms.Type.GUARDPOST, "points": 170},
	{"name": "Sort Œil du maître", "kind": "spell", "id": Spells.Type.EYE, "points": 160},
	{"name": "Temple", "kind": "room", "id": Rooms.Type.TEMPLE, "points": 200},
	{"name": "Hôtel des monnaies", "kind": "room", "id": Rooms.Type.MINT, "points": 210},
	{"name": "Sort Invocation", "kind": "spell", "id": Spells.Type.SUMMON, "points": 180},
	{"name": "Sort Hâte", "kind": "spell", "id": Spells.Type.HASTE, "points": 220},
	{"name": "Sort Conversion", "kind": "spell", "id": Spells.Type.CONVERT, "points": 230},
	{"name": "Sort Brasier", "kind": "spell", "id": Spells.Type.FIRESTORM, "points": 240},
	{"name": "Rune explosive", "kind": "defense", "id": Defenses.Type.RUNE, "points": 260},
	{"name": "Chambre de torture", "kind": "room", "id": Rooms.Type.TORTURE, "points": 250},
	{"name": "Cimetière", "kind": "room", "id": Rooms.Type.GRAVEYARD, "points": 240},
	{"name": "Crypte", "kind": "room", "id": Rooms.Type.CRYPT, "points": 260},
	{"name": "Sort Relever les morts", "kind": "spell", "id": Spells.Type.RAISE, "points": 260},
	{"name": "Sort Sanctuaire", "kind": "spell", "id": Spells.Type.SANCTUARY, "points": 280},
	{"name": "Puits de mana", "kind": "room", "id": Rooms.Type.MANA_WELL, "points": 300},
	{"name": "Sort Terreur", "kind": "spell", "id": Spells.Type.TERROR, "points": 300},
	{"name": "Sort Transmutation", "kind": "spell", "id": Spells.Type.TRANSMUTE, "points": 300},
	{"name": "Sort Rappel", "kind": "spell", "id": Spells.Type.RECALL, "points": 320},
	{"name": "Sort Possession", "kind": "spell", "id": Spells.Type.POSSESSION, "points": 360},
	{"name": "Sort Effondrement", "kind": "spell", "id": Spells.Type.COLLAPSE, "points": 400},
]

## L'ancienne liste (avant les nouveaux sorts), pour relire les vieilles sauvegardes :
## leur « next_index » comptait dans cet ordre-là.
const OLD_ORDER := ["Atelier", "Pointes", "Prison", "Salle d'entraînement", "Sort Éclair", "Porte",
		"Temple", "Sort Hâte", "Rune explosive", "Cimetière"]
## La liste de la version 2 (avant les antres des règles 2.7), même raison.
const ORDER_V2 := ["Atelier", "Pointes", "Sort Fouet", "Prison", "Sort Toile", "Salle d'entraînement",
		"Sort Festin", "Sort Éclair", "Porte", "Sort Œil du maître", "Temple", "Sort Invocation", "Sort Hâte",
		"Sort Conversion", "Sort Brasier", "Rune explosive", "Cimetière", "Sort Relever les morts",
		"Sort Sanctuaire", "Sort Terreur", "Sort Transmutation", "Sort Rappel", "Sort Possession",
		"Sort Effondrement"]
## Version de la liste, écrite dans la sauvegarde.
const LIST_VERSION := 3

## Indice de la prochaine découverte dans ITEMS.
var next_index := 0
## Points accumulés vers la prochaine découverte.
var points := 0.0


func is_done() -> bool:
	return next_index >= ITEMS.size()


func is_unlocked(kind: String, id: int) -> bool:
	for i in ITEMS.size():
		if ITEMS[i]["kind"] == kind and ITEMS[i]["id"] == id:
			return i < next_index
	return true


func add_points(amount: float) -> void:
	if is_done():
		return
	points += amount
	var cost: float = ITEMS[next_index]["points"]
	if points >= cost:
		points -= cost
		var item: Dictionary = ITEMS[next_index]
		next_index += 1
		discovered.emit(item)


## Texte pour l'interface, par exemple « Recherche : Atelier 40 % ».
func status_text() -> String:
	if is_done():
		return "Recherche : tout est découvert !"
	var item: Dictionary = ITEMS[next_index]
	return "Recherche : %s %d %%" % [item["name"], 100.0 * points / item["points"]]


func to_save() -> Dictionary:
	return {"next_index": next_index, "points": points, "list": LIST_VERSION}


func load_save(data: Dictionary) -> void:
	next_index = int(data.get("next_index", 0))
	points = float(data.get("points", 0.0))
	var version := int(data.get("list", 1))
	if version < LIST_VERSION and next_index > 0:
		# Vieille sauvegarde : on retrouve la dernière découverte dans la nouvelle liste
		# (les nouveautés placées avant elle sont offertes).
		var order: Array = OLD_ORDER if version <= 1 else ORDER_V2
		var last: String = order[mini(next_index, order.size()) - 1]
		for i in ITEMS.size():
			if ITEMS[i]["name"] == last:
				next_index = i + 1
				break

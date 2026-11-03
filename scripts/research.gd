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
	{"name": "Prison", "kind": "room", "id": Rooms.Type.PRISON, "points": 100},
	{"name": "Salle d'entraînement", "kind": "room", "id": Rooms.Type.TRAINING, "points": 120},
	{"name": "Sort Éclair", "kind": "spell", "id": Spells.Type.LIGHTNING, "points": 150},
	{"name": "Porte", "kind": "defense", "id": Defenses.Type.DOOR, "points": 180},
	{"name": "Temple", "kind": "room", "id": Rooms.Type.TEMPLE, "points": 200},
	{"name": "Sort Hâte", "kind": "spell", "id": Spells.Type.HASTE, "points": 220},
	{"name": "Rune explosive", "kind": "defense", "id": Defenses.Type.RUNE, "points": 260},
]

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
	return {"next_index": next_index, "points": points}


func load_save(data: Dictionary) -> void:
	next_index = int(data.get("next_index", 0))
	points = float(data.get("points", 0.0))

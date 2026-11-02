class_name SaveGame
## Lecture et écriture de la sauvegarde.
##
## La partie est enregistrée dans un fichier texte au format JSON, dans le
## dossier « user:// » : c'est un dossier privé que Godot réserve au jeu
## (sur Android, il est dans les données de l'application).
## Le JSON ne connaît pas les Vector2i : on écrit une case sous la forme [x, y].

const PATH := "user://savegame.json"
## À augmenter si le format change : les anciennes sauvegardes seront ignorées.
const VERSION := 1

## Le menu met ceci à true quand le joueur choisit « Continuer » ;
## main.gd le lit au démarrage de la partie. (Une variable « static » garde sa
## valeur même quand on change de scène.)
static var load_requested := false


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func write(data: Dictionary) -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Impossible d'écrire la sauvegarde : %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data))
	return true


## Renvoie la sauvegarde, ou {} si elle est absente, abîmée ou trop ancienne.
static func read() -> Dictionary:
	if not exists():
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != VERSION:
		return {}
	return data


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(PATH)


static func cell_to_array(cell: Vector2i) -> Array:
	return [cell.x, cell.y]


## Le JSON relit les nombres comme des décimaux : on les remet en entiers.
static func array_to_cell(values: Array) -> Vector2i:
	return Vector2i(int(values[0]), int(values[1]))

class_name Unit
extends Node2D
## Base commune à tout ce qui marche dans le donjon : ouvriers, créatures,
## et plus tard les héros.
##
## C'est de l'HÉRITAGE : worker.gd et creature.gd commencent par
## « extends Unit ». Ils reçoivent donc automatiquement tout ce qui est écrit
## ici (suivre un chemin, connaître sa case...) sans le recopier.

var map: DungeonMap
## Vitesse de marche, en pixels par seconde.
var speed := 90.0
## Cases qu'il reste à parcourir.
var path: Array[Vector2i] = []


## À appeler juste après la création de l'unité.
func setup(dungeon_map: DungeonMap, cell: Vector2i) -> void:
	map = dungeon_map
	position = map.cell_to_world(cell)


func current_cell() -> Vector2i:
	return map.world_to_cell(position)


## Suit un chemin déjà calculé (par exemple par map.find_dig_job).
func follow_path(new_path: Array[Vector2i]) -> void:
	path.assign(new_path) # Copie du chemin.
	if not path.is_empty():
		path.remove_at(0) # La première case est celle où l'on se trouve déjà.


## Calcule un chemin vers une case et commence à le suivre.
## Renvoie false si la case est inaccessible.
func go_to(cell: Vector2i) -> bool:
	var new_path := map.find_path(current_cell(), cell)
	if new_path.is_empty():
		return false
	follow_path(new_path)
	return true


## Avance un peu le long du chemin. Renvoie true quand on est arrivé au bout.
func move_along_path(delta: float) -> bool:
	if path.is_empty():
		return true
	var next_position := map.cell_to_world(path[0])
	position = position.move_toward(next_position, speed * delta)
	if position == next_position:
		path.remove_at(0)
	return path.is_empty()

class_name DungeonMap
extends Node2D
## La carte du donjon : une grille de tuiles vue de dessus.
##
## Ce script s'occupe de trois choses :
##   1. les DONNÉES : quel type de tuile se trouve à chaque case ;
##   2. l'AFFICHAGE : il dessine la grille avec des rectangles de couleur
##      (pas besoin d'images pour un prototype) ;
##   3. le PATHFINDING : il sait calculer un chemin entre deux cases,
##      grâce à AStarGrid2D, fourni par Godot.

## Émis quand un ouvrier extrait de l'or d'un filon.
signal gold_mined(amount: int)

## Les différents types de tuiles.
enum Tile {
	EARTH, ## Terre : se creuse.
	GOLD,  ## Filon d'or : se creuse et rapporte de l'or.
	ROCK,  ## Roche : indestructible.
	FLOOR, ## Sol creusé : on peut marcher dessus.
	HEART, ## Le cœur du donjon : ce qu'il faudra protéger plus tard.
}

const TILE_SIZE := 32 ## Taille d'une case, en pixels.
const WIDTH := 48     ## Largeur de la carte, en cases.
const HEIGHT := 32    ## Hauteur de la carte, en cases.

## Nombre de coups de pioche pour creuser chaque type de tuile.
const DIG_HITS := {Tile.EARTH: 4, Tile.GOLD: 8}
## Or gagné à chaque coup de pioche dans un filon.
const GOLD_PER_HIT := 15

## Les 4 directions voisines (pas de diagonale, c'est plus simple).
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

const COLORS := {
	Tile.EARTH: Color("6b4a2f"),
	Tile.GOLD: Color("7a5a2f"),
	Tile.ROCK: Color("3a3a40"),
	Tile.FLOOR: Color("2b2622"),
	Tile.HEART: Color("2b2622"),
}
const MARK_COLOR := Color("ffd54a")
const GOLD_NUGGET_COLOR := Color("ffd54a")

## Le type de chaque case. On range la grille 2D dans un tableau 1D :
## la case (x, y) est à l'indice y * WIDTH + x.
var tiles: PackedInt32Array = PackedInt32Array()
## Coups de pioche déjà reçus par une case : Vector2i -> int.
var damage: Dictionary = {}
## Cases que le joueur a marquées « à creuser » : Vector2i -> true.
var marked: Dictionary = {}
## Case marquée -> ouvrier qui s'en occupe (évite que deux ouvriers
## courent vers la même case).
var reserved: Dictionary = {}
## Position du cœur du donjon.
var heart_cell: Vector2i
## L'outil de Godot qui calcule les chemins sur une grille.
var astar := AStarGrid2D.new()


func _ready() -> void:
	generate(randi())


# ---------------------------------------------------------------------------
# Génération de la carte
# ---------------------------------------------------------------------------

## Crée une nouvelle carte. La même « graine » (seed) donne toujours la même carte.
func generate(seed_value: int) -> void:
	# Le « bruit » de Perlin/Simplex donne des valeurs qui varient en douceur :
	# parfait pour faire des amas de roche ou des filons d'or naturels.
	var rock_noise := FastNoiseLite.new()
	rock_noise.seed = seed_value
	rock_noise.frequency = 0.09
	var gold_noise := FastNoiseLite.new()
	gold_noise.seed = seed_value + 1
	gold_noise.frequency = 0.15

	tiles.resize(WIDTH * HEIGHT)
	for y in HEIGHT:
		for x in WIDTH:
			var tile: int = Tile.EARTH
			var on_border := x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1
			if on_border or rock_noise.get_noise_2d(x, y) > 0.35:
				tile = Tile.ROCK
			elif gold_noise.get_noise_2d(x, y) > 0.45:
				tile = Tile.GOLD
			tiles[y * WIDTH + x] = tile

	# Au centre : une petite salle de départ avec le cœur au milieu.
	heart_cell = Vector2i(int(WIDTH * 0.5), int(HEIGHT * 0.5))
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_set_tile(heart_cell + Vector2i(dx, dy), Tile.FLOOR)
	_set_tile(heart_cell, Tile.HEART)

	damage.clear()
	marked.clear()
	reserved.clear()
	_setup_pathfinding()
	queue_redraw()


func _setup_pathfinding() -> void:
	astar.region = Rect2i(0, 0, WIDTH, HEIGHT)
	astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	# On indique à A* quelles cases sont des murs (« solid »).
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, not is_walkable(cell))


# ---------------------------------------------------------------------------
# Lecture de la carte
# ---------------------------------------------------------------------------

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < HEIGHT


func get_tile(cell: Vector2i) -> int:
	if not is_inside(cell):
		return Tile.ROCK
	return tiles[cell.y * WIDTH + cell.x]


func is_walkable(cell: Vector2i) -> bool:
	return get_tile(cell) == Tile.FLOOR


func is_diggable(cell: Vector2i) -> bool:
	var tile := get_tile(cell)
	return tile == Tile.EARTH or tile == Tile.GOLD


## Centre d'une case, en pixels.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5


## Case qui se trouve sous une position en pixels.
func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))


func get_pixel_size() -> Vector2:
	return Vector2(WIDTH * TILE_SIZE, HEIGHT * TILE_SIZE)


## Chemin (liste de cases) entre deux cases. Vide si c'est impossible.
func find_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	if not is_walkable(from_cell) or not is_walkable(to_cell):
		return []
	return astar.get_id_path(from_cell, to_cell)


## Une case de sol au hasard près du cœur (pour faire apparaître les ouvriers).
func get_spawn_cell() -> Vector2i:
	var candidates: Array[Vector2i] = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cell := heart_cell + Vector2i(dx, dy)
			if is_walkable(cell):
				candidates.append(cell)
	return candidates.pick_random()


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

## Le joueur touche une case : on la marque, ou on enlève la marque.
func toggle_mark(cell: Vector2i) -> void:
	if not is_diggable(cell):
		return
	if marked.has(cell):
		marked.erase(cell)
		reserved.erase(cell)
	else:
		marked[cell] = true
	queue_redraw()


## Un ouvrier donne un coup de pioche. Renvoie true si la case est entièrement creusée.
func dig(cell: Vector2i) -> bool:
	if not is_diggable(cell):
		return true
	var tile := get_tile(cell)
	if tile == Tile.GOLD:
		gold_mined.emit(GOLD_PER_HIT)

	damage[cell] = damage.get(cell, 0) + 1
	var finished: bool = damage[cell] >= DIG_HITS[tile]
	if finished:
		_set_tile(cell, Tile.FLOOR)
		astar.set_point_solid(cell, false)
		damage.erase(cell)
		marked.erase(cell)
		reserved.erase(cell)
	queue_redraw()
	return finished


## Cherche la case marquée la plus proche pour un ouvrier.
## Renvoie un dictionnaire { "target": case à creuser, "path": chemin },
## ou un dictionnaire vide s'il n'y a rien à faire.
func find_dig_job(worker: Node, from_cell: Vector2i) -> Dictionary:
	# 1. On liste les cases marquées que personne d'autre ne creuse déjà.
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in marked:
		if reserved.get(cell, worker) == worker:
			candidates.append(cell)
	# 2. On les trie de la plus proche à la plus lointaine (à vol d'oiseau).
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _manhattan(a, from_cell) < _manhattan(b, from_cell))

	# 3. Pour chaque case, on cherche un vrai chemin vers une case de sol voisine.
	#    On s'arrête vite pour ne pas calculer des centaines de chemins.
	var best := {}
	var tested := 0
	for cell in candidates:
		for direction in DIRECTIONS:
			var path := find_path(from_cell, cell + direction)
			if path.is_empty():
				continue
			if best.is_empty() or path.size() < best["path"].size():
				best = {"target": cell, "path": path}
		tested += 1
		if tested >= 10 and not best.is_empty():
			break

	if not best.is_empty():
		release_jobs(worker)
		reserved[best["target"]] = worker
	return best


## Libère toutes les cases réservées par un ouvrier.
func release_jobs(worker: Node) -> void:
	for cell: Vector2i in reserved.keys():
		if reserved[cell] == worker:
			reserved.erase(cell)


func _set_tile(cell: Vector2i, tile: int) -> void:
	if is_inside(cell):
		tiles[cell.y * WIDTH + cell.x] = tile


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# ---------------------------------------------------------------------------
# Affichage
# ---------------------------------------------------------------------------

## Godot appelle _draw() quand on demande queue_redraw().
func _draw() -> void:
	var size := Vector2(TILE_SIZE, TILE_SIZE)
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell * TILE_SIZE), size)
			var tile := get_tile(cell)
			draw_rect(rect, COLORS[tile])

			match tile:
				Tile.GOLD:
					# Quelques pépites jaunes.
					draw_circle(rect.position + Vector2(9, 10), 3.0, GOLD_NUGGET_COLOR)
					draw_circle(rect.position + Vector2(22, 14), 2.5, GOLD_NUGGET_COLOR)
					draw_circle(rect.position + Vector2(14, 23), 2.0, GOLD_NUGGET_COLOR)
				Tile.HEART:
					draw_circle(rect.get_center(), 12.0, Color("c62828"))
					draw_circle(rect.get_center() - Vector2(3, 3), 4.0, Color("ef5350"))
				Tile.FLOOR:
					draw_rect(rect, Color(1, 1, 1, 0.04), false, 1.0)
				_:
					# Petit relief pour distinguer les blocs.
					draw_rect(rect.grow(-1), Color(0, 0, 0, 0.25), false, 1.0)

			# Plus la case a pris de coups, plus elle s'assombrit.
			if damage.has(cell) and DIG_HITS.has(tile):
				var ratio: float = float(damage[cell]) / DIG_HITS[tile]
				draw_rect(rect, Color(0, 0, 0, ratio * 0.5))

			# Les cases marquées « à creuser » sont entourées de jaune.
			if marked.has(cell):
				draw_rect(rect.grow(-2), MARK_COLOR, false, 2.0)

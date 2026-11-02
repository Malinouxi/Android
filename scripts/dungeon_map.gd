class_name DungeonMap
extends Node2D
## La carte du donjon : une grille de tuiles vue de dessus.
##
## Ce script s'occupe de :
##   1. les DONNÉES : quel type de tuile se trouve à chaque case ;
##   2. les SALLES posées sur le sol (trésor, repaire, champignonnière),
##      les lits des créatures et la nourriture ;
##   3. l'OR du joueur (stocké dans le cœur et dans les salles du trésor) ;
##   4. l'AFFICHAGE : il dessine la grille avec des formes simples ;
##   5. le PATHFINDING : il calcule les chemins avec AStarGrid2D ;
##   6. le CŒUR du donjon et ses points de vie.

## Émis chaque fois que la quantité d'or du joueur change.
signal gold_changed
## Émis quand le cœur perd des points de vie.
signal heart_changed
## Émis une seule fois, quand le cœur est détruit : la partie est perdue.
signal heart_destroyed
## Émis quand les héros ont cassé une porte.
signal door_destroyed(cell: Vector2i)

## Les différents types de tuiles.
enum Tile {
	EARTH, ## Terre : se creuse.
	GOLD,  ## Filon d'or : se creuse et rapporte de l'or.
	ROCK,  ## Roche : indestructible.
	FLOOR, ## Sol creusé : on peut marcher dessus et y construire des salles.
	HEART, ## Le cœur du donjon : ce qu'il faudra protéger plus tard.
	PORTAL, ## Le portail : les créatures arrivent (et repartent) par là.
	ENTRANCE, ## L'entrée des héros.
}

const TILE_SIZE := 32 ## Taille d'une case, en pixels.
const WIDTH := 48     ## Largeur de la carte, en cases.
const HEIGHT := 32    ## Hauteur de la carte, en cases.

## Nombre de coups de pioche pour creuser chaque type de tuile.
const DIG_HITS := {Tile.EARTH: 4, Tile.GOLD: 8}
## Or arraché à chaque coup de pioche dans un filon.
const GOLD_PER_HIT := 15

## Les 4 directions voisines (pas de diagonale, c'est plus simple).
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## Pour les héros, traverser de la terre « coûte » autant que marcher 6 cases :
## ils préfèrent les couloirs existants, mais creusent s'il le faut.
const HERO_DIG_WEIGHT := 6.0
## Une porte « coûte » autant que 10 cases de marche : les héros préfèrent la contourner.
const HERO_DOOR_WEIGHT := 10.0
## Durée de l'effet visuel d'une explosion, en secondes.
const EXPLOSION_TIME := 0.4
const HEART_MAX_HP := 1000.0

const MARK_COLOR := Color("ffd54a")

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
## Un deuxième A* pour les héros : pour eux la terre n'est pas un mur, juste un détour.
var hero_astar := AStarGrid2D.new()
## Points de vie du cœur.
var heart_hp := HEART_MAX_HP

## Les salles construites : Vector2i -> Rooms.Type.
var rooms: Dictionary = {}
## Or rangé dans chaque case de trésor : Vector2i -> int.
var stored_gold: Dictionary = {}
## Or de départ, gardé dans le cœur. On peut le dépenser, mais pas le remplir.
var heart_gold := 0
## Champignons sur chaque case de champignonnière : Vector2i -> int.
var food: Dictionary = {}
## Lits occupés : case de repaire -> créature qui y dort.
var beds: Dictionary = {}
## Position du portail.
var portal_cell: Vector2i
## Position de l'entrée des héros.
var entrance_cell: Vector2i

## Pièges et portes : Vector2i -> { "type": Defenses.Type, "hp", "cooldown", "flash" }.
var defenses: Dictionary = {}

var _farm_timer := 0.0
var _trap_timer := 0.0
## Explosions en cours d'affichage : [{ "position": Vector2, "radius", "time" }].
var _explosions: Array = []


func _ready() -> void:
	generate(randi())


## Les champignons poussent avec le temps.
func _process(delta: float) -> void:
	_update_traps(delta)
	_update_explosions(delta)
	_update_farms(delta)


## Les champignons poussent avec le temps.
func _update_farms(delta: float) -> void:
	_farm_timer += delta
	if _farm_timer < Rooms.FARM_GROW_TIME:
		return
	_farm_timer = 0.0
	var changed := false
	for cell: Vector2i in food:
		if food[cell] < Rooms.FARM_MAX_FOOD:
			food[cell] += 1
			changed = true
	if changed:
		queue_redraw()


# ---------------------------------------------------------------------------
# Génération de la carte
# ---------------------------------------------------------------------------

## Crée une nouvelle carte. La même « graine » (seed) donne toujours la même carte.
func generate(seed_value: int) -> void:
	# Le « bruit » donne des valeurs qui varient en douceur :
	# parfait pour faire des amas de roche ou des filons d'or naturels.
	var rock_noise := FastNoiseLite.new()
	rock_noise.seed = seed_value
	rock_noise.frequency = 0.09
	var gold_noise := FastNoiseLite.new()
	gold_noise.seed = seed_value + 1
	gold_noise.frequency = 0.15

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

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
	heart_hp = HEART_MAX_HP
	portal_cell = _place_gate(rng, Tile.PORTAL, [])
	entrance_cell = _place_gate(rng, Tile.ENTRANCE, [portal_cell])

	damage.clear()
	marked.clear()
	reserved.clear()
	rooms.clear()
	stored_gold.clear()
	food.clear()
	beds.clear()
	defenses.clear()
	_explosions.clear()
	_setup_pathfinding()
	queue_redraw()


## Place une « porte » (portail ou entrée des héros) assez loin du cœur,
## et loin des cases de la liste avoid, dans une petite clairière. Renvoie sa case.
func _place_gate(rng: RandomNumberGenerator, tile: int, avoid: Array[Vector2i]) -> Vector2i:
	var gate := Vector2i(3, 3)
	for _attempt in 200:
		var cell := Vector2i(rng.randi_range(3, WIDTH - 4), rng.randi_range(3, HEIGHT - 4))
		var distance := _manhattan(cell, heart_cell)
		var far_enough := true
		for other in avoid:
			if _manhattan(cell, other) < 12:
				far_enough = false
		if far_enough and distance >= 12 and distance <= 22:
			gate = cell
			break
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_set_tile(gate + Vector2i(dx, dy), Tile.FLOOR)
	_set_tile(gate, tile)

	# On garantit qu'on pourra creuser jusqu'au cœur : sur un chemin en « L »,
	# la roche indestructible est remplacée par de la terre.
	var step := gate
	while step != heart_cell:
		if step.x != heart_cell.x:
			step.x += signi(heart_cell.x - step.x)
		else:
			step.y += signi(heart_cell.y - step.y)
		if get_tile(step) == Tile.ROCK:
			_set_tile(step, Tile.EARTH)
	return gate


func _setup_pathfinding() -> void:
	astar.region = Rect2i(0, 0, WIDTH, HEIGHT)
	astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	hero_astar.region = astar.region
	hero_astar.cell_size = astar.cell_size
	hero_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	hero_astar.update()
	# On indique à A* quelles cases sont des murs (« solid »).
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, not is_walkable(cell))
			var tile := get_tile(cell)
			hero_astar.set_point_solid(cell, tile == Tile.ROCK or tile == Tile.HEART)
			if is_diggable(cell):
				hero_astar.set_point_weight_scale(cell, HERO_DIG_WEIGHT)


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
	var tile := get_tile(cell)
	return tile == Tile.FLOOR or tile == Tile.PORTAL or tile == Tile.ENTRANCE


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
# Creusage
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


## Un ouvrier donne un coup de pioche.
## Renvoie { "finished": la case est entièrement creusée, "gold": or arraché }.
func dig(cell: Vector2i) -> Dictionary:
	if not is_diggable(cell):
		return {"finished": true, "gold": 0}
	var tile := get_tile(cell)
	var gold := GOLD_PER_HIT if tile == Tile.GOLD else 0

	damage[cell] = damage.get(cell, 0) + 1
	var finished: bool = damage[cell] >= DIG_HITS[tile]
	if finished:
		_set_tile(cell, Tile.FLOOR)
		astar.set_point_solid(cell, false)
		hero_astar.set_point_weight_scale(cell, 1.0)
		damage.erase(cell)
		marked.erase(cell)
		reserved.erase(cell)
	queue_redraw()
	return {"finished": finished, "gold": gold}


## Cherche la case marquée la plus proche pour un ouvrier.
## Si allow_gold est faux, on ignore les filons (l'ouvrier a les poches pleines).
## Renvoie { "type": "dig", "target": case, "path": chemin }, ou {} si rien à faire.
func find_dig_job(worker: Node, from_cell: Vector2i, allow_gold := true) -> Dictionary:
	# 1. On liste les cases marquées que personne d'autre ne creuse déjà.
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in marked:
		if not allow_gold and get_tile(cell) == Tile.GOLD:
			continue
		if reserved.get(cell, worker) == worker:
			candidates.append(cell)
	# 2. On les trie de la plus proche à la plus lointaine (à vol d'oiseau).
	_sort_by_distance(candidates, from_cell)

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
				best = {"type": "dig", "target": cell, "path": path}
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


# ---------------------------------------------------------------------------
# Salles
# ---------------------------------------------------------------------------

func get_room(cell: Vector2i) -> int:
	return rooms.get(cell, Rooms.Type.NONE)


## On construit seulement sur du sol creusé, et pas deux salles sur la même case.
func can_build_room(cell: Vector2i) -> bool:
	return get_tile(cell) == Tile.FLOOR and not rooms.has(cell) and not defenses.has(cell)


func count_room_tiles(type: int) -> int:
	var count := 0
	for cell: Vector2i in rooms:
		if rooms[cell] == type:
			count += 1
	return count


func build_room(cell: Vector2i, type: int) -> void:
	rooms[cell] = type
	if type == Rooms.Type.TREASURY:
		stored_gold[cell] = 0
	elif type == Rooms.Type.FARM:
		food[cell] = 0
	queue_redraw()


## Démolit la salle d'une case. L'or qu'elle contenait est déplacé dans les
## autres cases de trésor s'il y a de la place. Renvoie l'or perdu.
func remove_room(cell: Vector2i) -> int:
	if not rooms.has(cell):
		return 0
	rooms.erase(cell)
	food.erase(cell)
	beds.erase(cell) # La créature qui dormait là n'a plus de lit.
	var lost: int = stored_gold.get(cell, 0)
	stored_gold.erase(cell)
	for other: Vector2i in stored_gold:
		var moved := mini(lost, Rooms.TREASURY_CAPACITY - stored_gold[other])
		stored_gold[other] += moved
		lost -= moved
	gold_changed.emit()
	queue_redraw()
	return lost


# ---------------------------------------------------------------------------
# Lits, nourriture et portail (pour les créatures)
# ---------------------------------------------------------------------------

## Donne un lit libre à une créature. Renvoie sa case, ou (-1, -1) s'il n'y en a pas.
func claim_bed(creature: Node) -> Vector2i:
	for cell: Vector2i in rooms:
		if rooms[cell] == Rooms.Type.LAIR and not beds.has(cell):
			beds[cell] = creature
			return cell
	return Vector2i(-1, -1)


func release_bed(creature: Node) -> void:
	for cell: Vector2i in beds.keys():
		if beds[cell] == creature:
			beds.erase(cell)


## Cherche le champignon le plus proche.
## Renvoie { "target": case, "path": chemin }, ou {} s'il n'y en a pas.
func find_food_job(from_cell: Vector2i) -> Dictionary:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in food:
		if food[cell] > 0:
			candidates.append(cell)
	return _find_nearest_reachable(candidates, from_cell)


## Mange un champignon sur une case. Renvoie false s'il n'y en a plus.
func take_food(cell: Vector2i) -> bool:
	if food.get(cell, 0) <= 0:
		return false
	food[cell] -= 1
	queue_redraw()
	return true


## Vrai si un chemin de sol relie le portail au cœur du donjon.
func is_portal_connected() -> bool:
	return is_connected_to_heart(portal_cell)


## Vrai si on peut marcher de cette case jusqu'au cœur.
func is_connected_to_heart(cell: Vector2i) -> bool:
	if not is_walkable(cell):
		return false
	for direction in DIRECTIONS:
		if not find_path(cell, heart_cell + direction).is_empty():
			return true
	return false


# ---------------------------------------------------------------------------
# Défenses : pièges et portes
# ---------------------------------------------------------------------------

## Les défenses se posent sur le sol des couloirs (pas dans les salles).
func can_place_defense(cell: Vector2i) -> bool:
	return get_tile(cell) == Tile.FLOOR and not rooms.has(cell) and not defenses.has(cell)


func place_defense(cell: Vector2i, type: int) -> void:
	defenses[cell] = {
		"type": type,
		"hp": Defenses.INFO[type].get("hp", 0.0),
		"cooldown": 0.0, # Temps avant que le piège soit de nouveau prêt.
		"flash": 0.0,    # Temps pendant lequel les pointes restent sorties.
	}
	if type == Defenses.Type.DOOR:
		hero_astar.set_point_weight_scale(cell, HERO_DOOR_WEIGHT)
	queue_redraw()


func remove_defense(cell: Vector2i) -> void:
	if not defenses.has(cell):
		return
	if defenses[cell]["type"] == Defenses.Type.DOOR:
		hero_astar.set_point_weight_scale(cell, 1.0)
	defenses.erase(cell)
	queue_redraw()


func has_door(cell: Vector2i) -> bool:
	return defenses.has(cell) and defenses[cell]["type"] == Defenses.Type.DOOR


## Un héros frappe une porte. À 0 point de vie, elle est détruite.
func damage_door(cell: Vector2i, amount: float) -> void:
	if not has_door(cell):
		return
	defenses[cell]["hp"] -= amount
	queue_redraw()
	if defenses[cell]["hp"] <= 0.0:
		remove_defense(cell)
		door_destroyed.emit(cell)


## Dix fois par seconde, on regarde si un héros marche sur un piège.
func _update_traps(delta: float) -> void:
	for cell: Vector2i in defenses:
		var defense: Dictionary = defenses[cell]
		defense["cooldown"] = maxf(0.0, defense["cooldown"] - delta)
		if defense["flash"] > 0.0:
			defense["flash"] -= delta
			if defense["flash"] <= 0.0:
				queue_redraw() # Les pointes rentrent.

	_trap_timer -= delta
	if _trap_timer > 0.0:
		return
	_trap_timer = 0.1
	for node in get_tree().get_nodes_in_group("heroes"):
		var hero := node as Unit
		var cell := world_to_cell(hero.position)
		if not defenses.has(cell):
			continue
		var defense: Dictionary = defenses[cell]
		var info: Dictionary = Defenses.INFO[defense["type"]]
		match defense["type"]:
			Defenses.Type.SPIKES:
				if defense["cooldown"] <= 0.0:
					defense["cooldown"] = info["rearm_time"]
					defense["flash"] = 0.4
					hero.take_damage(info["damage"])
					queue_redraw()
			Defenses.Type.RUNE:
				_explode(cell, info["damage"], info["radius"])


## La rune explose : tous les héros proches sont touchés, puis elle disparaît.
func _explode(cell: Vector2i, explosion_damage: float, radius: float) -> void:
	var center := cell_to_world(cell)
	remove_defense(cell)
	_explosions.append({"position": center, "radius": radius, "time": EXPLOSION_TIME})
	for node in get_tree().get_nodes_in_group("heroes"):
		var hero := node as Unit
		if hero.position.distance_to(center) <= radius:
			hero.take_damage(explosion_damage)


func _update_explosions(delta: float) -> void:
	if _explosions.is_empty():
		return
	for explosion in _explosions:
		explosion["time"] -= delta
	_explosions = _explosions.filter(func(e: Dictionary) -> bool: return e["time"] > 0.0)
	queue_redraw()


# ---------------------------------------------------------------------------
# Cœur et héros
# ---------------------------------------------------------------------------

func is_next_to_heart(cell: Vector2i) -> bool:
	return _manhattan(cell, heart_cell) == 1


## Chemin d'un héros vers une case voisine du cœur. Il peut traverser de la
## terre (le héros devra la creuser), mais pas la roche.
func find_hero_path(from_cell: Vector2i) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	if hero_astar.is_point_solid(from_cell):
		return best
	for direction in DIRECTIONS:
		var goal := heart_cell + direction
		if hero_astar.is_point_solid(goal):
			continue
		var candidate := hero_astar.get_id_path(from_cell, goal)
		if not candidate.is_empty() and (best.is_empty() or candidate.size() < best.size()):
			best = candidate
	return best


func damage_heart(amount: float) -> void:
	if heart_hp <= 0.0:
		return
	heart_hp = maxf(0.0, heart_hp - amount)
	heart_changed.emit()
	queue_redraw()
	if heart_hp <= 0.0:
		heart_destroyed.emit()


# ---------------------------------------------------------------------------
# Or
# ---------------------------------------------------------------------------

## Tout l'or du joueur : celui du cœur plus celui des salles du trésor.
func get_total_gold() -> int:
	return heart_gold + get_treasury_stored()


func get_treasury_stored() -> int:
	var total := 0
	for cell: Vector2i in stored_gold:
		total += stored_gold[cell]
	return total


func get_treasury_capacity() -> int:
	return stored_gold.size() * Rooms.TREASURY_CAPACITY


func set_starting_gold(amount: int) -> void:
	heart_gold = amount
	gold_changed.emit()


## Dépense de l'or. Renvoie false (et ne dépense rien) s'il n'y en a pas assez.
func spend_gold(amount: int) -> bool:
	if get_total_gold() < amount:
		return false
	# On vide d'abord les trésors (ça libère de la place), puis le cœur.
	var remaining := amount
	for cell: Vector2i in stored_gold:
		var taken := mini(remaining, stored_gold[cell])
		stored_gold[cell] -= taken
		remaining -= taken
	heart_gold -= remaining
	gold_changed.emit()
	queue_redraw()
	return true


## Range de l'or dans les trésors, où il y a de la place. Renvoie la quantité rangée.
func add_gold_to_treasury(amount: int) -> int:
	var remaining := amount
	for cell: Vector2i in stored_gold:
		var accepted := mini(remaining, Rooms.TREASURY_CAPACITY - stored_gold[cell])
		stored_gold[cell] += accepted
		remaining -= accepted
	if remaining < amount:
		gold_changed.emit()
		queue_redraw()
	return amount - remaining


## Un ouvrier dépose de l'or sur une case de trésor. Renvoie la quantité acceptée.
func deposit_gold(cell: Vector2i, amount: int) -> int:
	if not stored_gold.has(cell):
		return 0
	var accepted := mini(amount, Rooms.TREASURY_CAPACITY - stored_gold[cell])
	stored_gold[cell] += accepted
	if accepted > 0:
		gold_changed.emit()
		queue_redraw()
	return accepted


## Cherche la case de trésor non pleine la plus proche.
## Renvoie { "type": "deposit", "target": case, "path": chemin }, ou {} si aucune.
func find_deposit_job(from_cell: Vector2i) -> Dictionary:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in stored_gold:
		if stored_gold[cell] < Rooms.TREASURY_CAPACITY:
			candidates.append(cell)
	var best := _find_nearest_reachable(candidates, from_cell)
	if not best.is_empty():
		best["type"] = "deposit"
	return best


# ---------------------------------------------------------------------------
# Outils internes
# ---------------------------------------------------------------------------

func _set_tile(cell: Vector2i, tile: int) -> void:
	if is_inside(cell):
		tiles[cell.y * WIDTH + cell.x] = tile


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Parmi des cases où l'on peut marcher, trouve celle au chemin le plus court.
## Renvoie { "target": case, "path": chemin }, ou {} si aucune n'est accessible.
func _find_nearest_reachable(cells: Array[Vector2i], from_cell: Vector2i) -> Dictionary:
	_sort_by_distance(cells, from_cell)
	var best := {}
	var tested := 0
	for cell in cells:
		var path := find_path(from_cell, cell)
		if not path.is_empty() and (best.is_empty() or path.size() < best["path"].size()):
			best = {"target": cell, "path": path}
		tested += 1
		if tested >= 10 and not best.is_empty():
			break
	return best


func _sort_by_distance(cells: Array[Vector2i], from_cell: Vector2i) -> void:
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _manhattan(a, from_cell) < _manhattan(b, from_cell))


# ---------------------------------------------------------------------------
# Affichage
# ---------------------------------------------------------------------------

## Godot appelle _draw() quand on demande queue_redraw().
## Chaque case est une petite image 16 x 16 (voir art.gd) affichée en 32 x 32.
func _draw() -> void:
	var size := Vector2(TILE_SIZE, TILE_SIZE)
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell * TILE_SIZE), size)
			var tile := get_tile(cell)

			match tile:
				Tile.EARTH:
					draw_texture_rect(Art.pick(Art.EARTH, cell), rect, false)
				Tile.GOLD:
					draw_texture_rect(Art.pick(Art.GOLD, cell), rect, false)
				Tile.ROCK:
					draw_texture_rect(Art.pick(Art.ROCK, cell), rect, false)
				_:
					# Sol, cœur, portail ou entrée : d'abord le sol en dessous...
					if rooms.has(cell):
						_draw_room_tile(cell, rect)
					else:
						draw_texture_rect(Art.pick(Art.FLOOR, cell), rect, false)
					# ... puis l'objet par-dessus.
					if tile == Tile.HEART:
						_draw_heart(rect)
					elif tile == Tile.PORTAL:
						draw_texture_rect(Art.PORTAL, rect, false)
					elif tile == Tile.ENTRANCE:
						draw_texture_rect(Art.ENTRANCE, rect, false)
					if defenses.has(cell):
						_draw_defense(cell, rect)

			# Plus la case a pris de coups, plus elle s'assombrit.
			if damage.has(cell) and DIG_HITS.has(tile):
				var ratio: float = float(damage[cell]) / DIG_HITS[tile]
				draw_rect(rect, Color(0, 0, 0, ratio * 0.5))

			# Les cases marquées « à creuser » sont entourées de jaune.
			if marked.has(cell):
				draw_rect(rect.grow(-2), MARK_COLOR, false, 2.0)

	# Les explosions par-dessus tout : un cercle orange qui grandit et s'efface.
	for explosion in _explosions:
		var progress: float = 1.0 - explosion["time"] / EXPLOSION_TIME
		var color := Color(1.0, 0.55, 0.1, 0.8 * (1.0 - progress))
		draw_circle(explosion["position"], explosion["radius"] * (0.4 + 0.6 * progress), color)


func _draw_defense(cell: Vector2i, rect: Rect2) -> void:
	var defense: Dictionary = defenses[cell]
	match defense["type"]:
		Defenses.Type.SPIKES:
			draw_texture_rect(Art.SPIKES_UP if defense["flash"] > 0.0 else Art.SPIKES_DOWN, rect, false)
		Defenses.Type.RUNE:
			draw_texture_rect(Art.RUNE, rect, false)
		Defenses.Type.DOOR:
			draw_texture_rect(Art.DOOR, rect, false)
			var max_hp: float = Defenses.INFO[Defenses.Type.DOOR]["hp"]
			if defense["hp"] < max_hp:
				var bar := Rect2(rect.position + Vector2(2, -6), Vector2(TILE_SIZE - 4, 4))
				draw_rect(bar, Color(0, 0, 0, 0.7))
				bar.size.x *= defense["hp"] / max_hp
				draw_rect(bar, Color("ffa726"))


func _draw_heart(rect: Rect2) -> void:
	draw_texture_rect(Art.HEART, rect, false)
	if heart_hp < HEART_MAX_HP:
		var bar := Rect2(rect.position + Vector2(0, -8), Vector2(TILE_SIZE, 5))
		draw_rect(bar, Color(0, 0, 0, 0.7))
		bar.size.x *= heart_hp / HEART_MAX_HP
		draw_rect(bar, Color("e53935"))


func _draw_room_tile(cell: Vector2i, rect: Rect2) -> void:
	var type := get_room(cell)
	draw_texture_rect(Art.ROOM_FLOORS[type], rect, false)

	# Un bord clair seulement là où la salle s'arrête : on voit sa forme.
	var edge_color := Rooms.color(type).lightened(0.35)
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0),
			rect.end, rect.position + Vector2(0, rect.size.y)]
	if get_room(cell + Vector2i.UP) != type:
		draw_line(corners[0], corners[1], edge_color, 2.0)
	if get_room(cell + Vector2i.RIGHT) != type:
		draw_line(corners[1], corners[2], edge_color, 2.0)
	if get_room(cell + Vector2i.DOWN) != type:
		draw_line(corners[2], corners[3], edge_color, 2.0)
	if get_room(cell + Vector2i.LEFT) != type:
		draw_line(corners[3], corners[0], edge_color, 2.0)

	match type:
		Rooms.Type.TREASURY:
			# Un tas d'or qui grossit avec la quantité stockée (0 à 5 pièces).
			var coins := ceili(5.0 * stored_gold.get(cell, 0) / Rooms.TREASURY_CAPACITY)
			if coins > 0:
				draw_texture_rect(Art.GOLD_PILES[mini(coins, 5) - 1], rect, false)
		Rooms.Type.LAIR:
			draw_texture_rect(Art.BED, rect, false)
		Rooms.Type.FARM:
			# Un champignon (8 x 8 pixels, affiché en 16 x 16) par unité de nourriture.
			var spots := [Vector2(1, 14), Vector2(15, 15), Vector2(8, 2)]
			for i in food.get(cell, 0):
				draw_texture_rect(Art.MUSHROOM, Rect2(rect.position + spots[i], Vector2(16, 16)), false)

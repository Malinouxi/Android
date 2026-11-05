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
## Émis une seule fois, quand le cœur du maître rival est détruit.
signal rival_heart_destroyed
## Émis quand les héros ont cassé une porte.
signal door_destroyed(cell: Vector2i)
## Émis à chaque changement de la carte (la vue 3D se reconstruit alors).
signal redrawn

## Les différents types de tuiles.
enum Tile {
	EARTH, ## Terre : se creuse.
	GOLD,  ## Filon d'or : se creuse et rapporte de l'or.
	ROCK,  ## Roche : indestructible.
	FLOOR, ## Sol creusé : on peut marcher dessus et y construire des salles.
	HEART, ## Le cœur du donjon : ce qu'il faudra protéger plus tard.
	PORTAL, ## Le portail : les créatures arrivent (et repartent) par là.
	ENTRANCE, ## L'entrée des héros.
	RIVAL_HEART, ## Le cœur du maître rival (certains niveaux de la campagne).
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
## Durée des effets visuels (explosion, sorts), en secondes.
const EFFECT_TIME := 0.4
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
## Moment du dernier coup reçu par le cœur (sa lumière bat plus vite, voir main.gd).
var last_heart_hit_msec := -100000

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

## Le maître rival (seulement dans certains niveaux).
var has_rival := false
var rival_heart_cell := Vector2i(-1, -1)
var rival_heart_hp := 0.0
var rival_heart_max_hp := 1.0
## Le territoire du rival (teinté de bleu) : Vector2i -> true.
var rival_claimed: Dictionary = {}
const RIVAL_TINT := Color(0.55, 0.65, 1.35)

## Pièges et portes : Vector2i -> { "type": Defenses.Type, "hp", "cooldown", "flash" }.
var defenses: Dictionary = {}
## Le territoire du donjon : les cases de sol revendiquées par les ouvriers (Vector2i -> true).
var claimed: Dictionary = {}
## Postes de travail occupés dans les salles : case -> créature (voir creature.gd).
var work_spots: Dictionary = {}
## Cellules de prison occupées : case -> héros prisonnier (voir hero.gd).
var prisoners: Dictionary = {}
## Cases où brûle une torche (choisies par main.gd) : Vector2i -> true.
var torch_cells: Dictionary = {}
## Les tombes occupées du Cimetière : case -> secondes avant que le héros enterré
## se relève en Revenant (0 = prêt ; main.gd le fait se relever s'il y a un lit).
var graves: Dictionary = {}

## Les CHANTIERS : salles et défenses que les ouvriers doivent encore construire.
## case -> {"kind": "room" ou "defense", "type", "left" (secondes de travail restantes),
##          "total", "worker" (l'ouvrier qui y travaille, ou null)}.
## Une case en chantier ne sert à rien tant qu'elle n'est pas terminée.
var construction: Dictionary = {}

## Les DÉCORATIONS fabriquées par les ouvriers : case de sol -> {"kind", "side"}.
## kind : "rug" (tapis, à plat), "painting" (tableau) ou "tapestry" (tapisserie).
## side : le mur où le tableau est accroché, vu depuis la case (Vector2i.UP ou
## Vector2i.LEFT : les seuls murs dont on voit la face en vue isométrique),
## ou Vector2i.ZERO pour un tapis.
var decorations: Dictionary = {}
const DECORATION_KINDS := ["rug", "painting", "tapestry"]
const DECORATION_SIDES := [Vector2i.ZERO, Vector2i.UP, Vector2i.LEFT]
## Les tapis ne se posent que dans ces salles.
const RUG_ROOMS := [Rooms.Type.TREASURY, Rooms.Type.LAIR, Rooms.Type.LIBRARY, Rooms.Type.WORKSHOP,
		Rooms.Type.TRAINING, Rooms.Type.TEMPLE]

## L'or tombé par terre (le sac d'une Voleuse abattue) : case -> or.
## Les ouvriers le ramassent et le rapportent au Trésor (voir worker.gd).
var loose_gold: Dictionary = {}

## Le décor animé (torches, portail, cœur...) change d'image ANIM_FPS fois par seconde.
const ANIM_FPS := 6.0
## Le « tic » d'animation du décor : il augmente de 1 à chaque changement d'image.
var anim_tick := 0
var _anim_timer := 0.0
## Les diagonales (couches de dessin) qui contiennent un objet animé : d -> true.
## Seules celles-ci sont redessinées à chaque tic, pour ne pas ralentir le jeu.
var _animated_layers: Dictionary = {}
## Vrai si la diagonale en cours de dessin contient un objet animé.
var _layer_is_animated := false

var _farm_timer := 0.0
var _trap_timer := 0.0
## Explosions en cours d'affichage : [{ "position": Vector2, "radius", "time" }].
var _effects: Array = []


func _ready() -> void:
	_create_layers()
	generate(randi())


## Les champignons poussent avec le temps.
func _process(delta: float) -> void:
	_update_traps(delta)
	_update_effects(delta)
	_update_farms(delta)
	_update_animation(delta)
	for cell: Vector2i in graves:
		graves[cell] = maxf(0.0, graves[cell] - delta)


## Fait avancer le décor animé : on ne redessine que les couches qui en ont besoin.
func _update_animation(delta: float) -> void:
	_anim_timer += delta
	if _anim_timer < 1.0 / ANIM_FPS:
		return
	_anim_timer = 0.0
	anim_tick += 1
	for d: int in _animated_layers:
		_wall_layers[d].queue_redraw()


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
		_redraw_all()


# ---------------------------------------------------------------------------
# Génération de la carte
# ---------------------------------------------------------------------------

## Crée une nouvelle carte. La même « graine » (seed) donne toujours la même carte.
## with_rival : ajoute un donjon rival, dont le cœur a rival_hp points de vie.
func generate(seed_value: int, with_rival := false, rival_hp := 1200.0) -> void:
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
	# La salle de départ appartient déjà au donjon.
	claimed.clear()
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			claimed[heart_cell + Vector2i(dx, dy)] = true
	heart_hp = HEART_MAX_HP
	has_rival = with_rival
	rival_claimed.clear()
	var avoid: Array[Vector2i] = []
	if with_rival:
		_place_rival(rng, rival_hp)
		avoid.append(rival_heart_cell)
	portal_cell = _place_gate(rng, Tile.PORTAL, avoid)
	avoid.append(portal_cell)
	entrance_cell = _place_gate(rng, Tile.ENTRANCE, avoid)

	damage.clear()
	marked.clear()
	reserved.clear()
	rooms.clear()
	stored_gold.clear()
	food.clear()
	beds.clear()
	defenses.clear()
	work_spots.clear()
	prisoners.clear()
	_effects.clear()
	_setup_pathfinding()
	_redraw_all()


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

	_carve_to_heart(gate)
	return gate


## On garantit qu'on pourra creuser de cette case jusqu'au cœur : sur un chemin
## en « L », la roche indestructible est remplacée par de la terre.
func _carve_to_heart(start: Vector2i) -> void:
	var step := start
	while step != heart_cell:
		if step.x != heart_cell.x:
			step.x += signi(heart_cell.x - step.x)
		else:
			step.y += signi(heart_cell.y - step.y)
		if get_tile(step) == Tile.ROCK:
			_set_tile(step, Tile.EARTH)


## Le donjon du rival : le plus loin possible du nôtre, avec son propre territoire.
func _place_rival(rng: RandomNumberGenerator, max_hp: float) -> void:
	var best := Vector2i(4, 4)
	for _attempt in 200:
		var cell := Vector2i(rng.randi_range(4, WIDTH - 5), rng.randi_range(4, HEIGHT - 5))
		if _manhattan(cell, heart_cell) > _manhattan(best, heart_cell):
			best = cell
	rival_heart_cell = best
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cell := best + Vector2i(dx, dy)
			_set_tile(cell, Tile.FLOOR)
			rival_claimed[cell] = true
	_set_tile(best, Tile.RIVAL_HEART)
	rival_heart_max_hp = max_hp
	rival_heart_hp = max_hp
	_carve_to_heart(best)


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
			hero_astar.set_point_solid(cell, tile == Tile.ROCK or tile == Tile.HEART or tile == Tile.RIVAL_HEART)
			if is_diggable(cell):
				hero_astar.set_point_weight_scale(cell, HERO_DIG_WEIGHT)
	for cell: Vector2i in defenses:
		if defenses[cell]["type"] == Defenses.Type.DOOR:
			hero_astar.set_point_weight_scale(cell, HERO_DOOR_WEIGHT)


# ---------------------------------------------------------------------------
# Sauvegarde
# ---------------------------------------------------------------------------

## Tout ce qu'il faut pour reconstruire la carte, sous une forme que le JSON
## sait écrire (nombres, textes, listes, dictionnaires à clés texte).
func to_save() -> Dictionary:
	var marked_list := []
	for cell: Vector2i in marked:
		marked_list.append(SaveGame.cell_to_array(cell))
	var claimed_list := []
	for cell: Vector2i in claimed:
		claimed_list.append(SaveGame.cell_to_array(cell))
	var defense_list := []
	for cell: Vector2i in defenses:
		defense_list.append([cell.x, cell.y, defenses[cell]["type"], defenses[cell]["hp"]])
	return {
		"width": WIDTH,
		"height": HEIGHT,
		"tiles": Array(tiles),
		"heart": SaveGame.cell_to_array(heart_cell),
		"portal": SaveGame.cell_to_array(portal_cell),
		"entrance": SaveGame.cell_to_array(entrance_cell),
		"heart_hp": heart_hp,
		"heart_gold": heart_gold,
		"damage": _cells_to_list(damage),
		"marked": marked_list,
		"rooms": _cells_to_list(rooms),
		"stored_gold": _cells_to_list(stored_gold),
		"food": _cells_to_list(food),
		"defenses": defense_list,
		"claimed": claimed_list,
		"has_rival": has_rival,
		"rival_heart": SaveGame.cell_to_array(rival_heart_cell),
		"rival_heart_hp": rival_heart_hp,
		"rival_heart_max_hp": rival_heart_max_hp,
		"rival_claimed": _cells_to_array_list(rival_claimed),
		"graves": _cells_to_list(graves),
		"loose_gold": _cells_to_list(loose_gold),
		"construction": _construction_to_list(),
		"decorations": _decorations_to_list(),
	}


## Recharge une carte sauvegardée. Renvoie false si la sauvegarde ne convient pas.
func load_save(data: Dictionary) -> bool:
	if int(data.get("width", 0)) != WIDTH or int(data.get("height", 0)) != HEIGHT:
		return false
	var saved_tiles: Array = data["tiles"]
	for i in tiles.size():
		tiles[i] = int(saved_tiles[i])
	heart_cell = SaveGame.array_to_cell(data["heart"])
	portal_cell = SaveGame.array_to_cell(data["portal"])
	entrance_cell = SaveGame.array_to_cell(data["entrance"])
	heart_hp = float(data["heart_hp"])
	heart_gold = int(data["heart_gold"])
	damage = _list_to_cells(data["damage"])
	rooms = _list_to_cells(data["rooms"])
	stored_gold = _list_to_cells(data["stored_gold"])
	food = _list_to_cells(data["food"])
	loose_gold = _list_to_cells(data.get("loose_gold", []))
	decorations.clear()
	for values in data.get("decorations", []):
		decorations[SaveGame.array_to_cell(values)] = {
			"kind": DECORATION_KINDS[int(values[2])], "side": DECORATION_SIDES[int(values[3])]}
	construction.clear()
	for values in data.get("construction", []):
		var kind: String = "room" if int(values[2]) == 0 else "defense"
		var type := int(values[3])
		var total := Rooms.build_time(type) if kind == "room" else Defenses.build_time(type)
		construction[SaveGame.array_to_cell(values)] = {
			"kind": kind, "type": type, "left": float(values[4]), "total": total, "worker": null}
	graves.clear()
	for values in data.get("graves", []):
		graves[SaveGame.array_to_cell(values)] = float(values[2])
	marked.clear()
	for values in data["marked"]:
		marked[SaveGame.array_to_cell(values)] = true
	defenses.clear()
	for values in data["defenses"]:
		defenses[SaveGame.array_to_cell(values)] = {
			"type": int(values[2]), "hp": float(values[3]), "cooldown": 0.0, "flash": 0.0}
	claimed.clear()
	has_rival = bool(data.get("has_rival", false))
	rival_heart_cell = SaveGame.array_to_cell(data.get("rival_heart", [-1, -1]))
	rival_heart_hp = float(data.get("rival_heart_hp", 0.0))
	rival_heart_max_hp = float(data.get("rival_heart_max_hp", 1.0))
	rival_claimed.clear()
	for values in data.get("rival_claimed", []):
		rival_claimed[SaveGame.array_to_cell(values)] = true
	if data.has("claimed"):
		for values in data["claimed"]:
			claimed[SaveGame.array_to_cell(values)] = true
	else:
		# Ancienne sauvegarde, d'avant le territoire : tout le sol creusé est à nous.
		for y in HEIGHT:
			for x in WIDTH:
				if get_tile(Vector2i(x, y)) == Tile.FLOOR:
					claimed[Vector2i(x, y)] = true
		claimed[heart_cell] = true
	reserved.clear()
	beds.clear() # Les créatures rechargées reprendront un lit.
	work_spots.clear()
	prisoners.clear()
	_effects.clear()
	_setup_pathfinding()
	gold_changed.emit()
	_redraw_all()
	return true


## Les décorations -> [[x, y, numéro de la sorte, numéro du côté], ...]
func _decorations_to_list() -> Array:
	var result := []
	for cell: Vector2i in decorations:
		var deco: Dictionary = decorations[cell]
		result.append([cell.x, cell.y, DECORATION_KINDS.find(deco["kind"]), DECORATION_SIDES.find(deco["side"])])
	return result


## Les chantiers -> [[x, y, 0 = salle / 1 = défense, type, secondes restantes], ...]
func _construction_to_list() -> Array:
	var result := []
	for cell: Vector2i in construction:
		var site: Dictionary = construction[cell]
		result.append([cell.x, cell.y, 0 if site["kind"] == "room" else 1, site["type"], site["left"]])
	return result


## { case: true } -> [[x, y], ...]
func _cells_to_array_list(values: Dictionary) -> Array:
	var result := []
	for cell: Vector2i in values:
		result.append(SaveGame.cell_to_array(cell))
	return result


## { case: nombre } -> [[x, y, nombre], ...]
func _cells_to_list(values: Dictionary) -> Array:
	var result := []
	for cell: Vector2i in values:
		result.append([cell.x, cell.y, values[cell]])
	return result


## [[x, y, nombre], ...] -> { case: nombre }
func _list_to_cells(list: Array) -> Dictionary:
	var result := {}
	for values in list:
		result[SaveGame.array_to_cell(values)] = int(values[2])
	return result


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
	_redraw_all()


## Marque (value = true) ou démarque une case, pour la peinture au doigt.
func set_mark(cell: Vector2i, value: bool) -> void:
	if not is_diggable(cell) or marked.has(cell) == value:
		return
	if value:
		marked[cell] = true
	else:
		marked.erase(cell)
		reserved.erase(cell)
	_redraw_all()


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
		# Le mur a disparu : les tableaux qui y étaient accrochés tombent.
		if decorations.get(cell + Vector2i.DOWN, {}).get("side") == Vector2i.UP:
			decorations.erase(cell + Vector2i.DOWN)
		if decorations.get(cell + Vector2i.RIGHT, {}).get("side") == Vector2i.LEFT:
			decorations.erase(cell + Vector2i.RIGHT)
	_redraw_all()
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


# ---------------------------------------------------------------------------
# Territoire
# ---------------------------------------------------------------------------

func is_claimed(cell: Vector2i) -> bool:
	return claimed.has(cell)


func claim(cell: Vector2i) -> void:
	if get_tile(cell) == Tile.FLOOR:
		claimed[cell] = true
		rival_claimed.erase(cell) # On peut voler le territoire du rival !
		reserved.erase(cell)
		_redraw_all()


## Cherche une case de sol pas encore revendiquée, collée au territoire.
## Renvoie { "type": "claim", "target": case, "path": chemin }, ou {} si rien à faire.
func find_claim_job(worker: Node, from_cell: Vector2i) -> Dictionary:
	var candidates: Array[Vector2i] = []
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if get_tile(cell) != Tile.FLOOR or claimed.has(cell):
				continue
			if reserved.get(cell, worker) != worker:
				continue
			for direction in DIRECTIONS:
				if claimed.has(cell + direction):
					candidates.append(cell)
					break
	var best := _find_nearest_reachable(candidates, from_cell)
	if not best.is_empty():
		best["type"] = "claim"
		release_jobs(worker)
		reserved[best["target"]] = worker
	return best


# ---------------------------------------------------------------------------
# Décorations : ce que font les ouvriers quand il n'y a rien d'autre à faire
# ---------------------------------------------------------------------------

## Les décorations possibles sur une case : liste de [sorte, côté].
func _decoration_options(cell: Vector2i) -> Array:
	var options := []
	for side in [Vector2i.UP, Vector2i.LEFT]:
		if _is_wall(cell + side) and is_inside(cell + side):
			options.append(["painting", side])
			options.append(["tapestry", side])
	if RUG_ROOMS.has(get_room(cell)):
		options.append(["rug", Vector2i.ZERO])
	return options


## Vrai s'il y a déjà une décoration sur la case ou juste à côté (pas d'entassement).
func _decoration_near(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if decorations.has(cell + Vector2i(dx, dy)):
				return true
	return false


## Pour un ouvrier sans travail : la case à décorer la plus proche.
## Renvoie aussi la sorte de décoration choisie ("kind") et son côté ("side").
func find_decorate_job(worker: Node, from_cell: Vector2i) -> Dictionary:
	if decorations.size() >= Rules.MAX_DECORATIONS:
		return {}
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in claimed:
		if get_tile(cell) != Tile.FLOOR or construction.has(cell) or defenses.has(cell):
			continue
		if reserved.get(cell, worker) != worker or _decoration_near(cell):
			continue
		if not _decoration_options(cell).is_empty():
			candidates.append(cell)
	var best := _find_nearest_reachable(candidates, from_cell)
	if best.is_empty():
		return best
	var choice: Array = _decoration_options(best["target"]).pick_random()
	best["type"] = "decorate"
	best["kind"] = choice[0]
	best["side"] = choice[1]
	release_jobs(worker)
	reserved[best["target"]] = worker
	return best


## L'ouvrier a fini : la décoration est posée.
func add_decoration(cell: Vector2i, kind: String, side: Vector2i) -> void:
	reserved.erase(cell)
	decorations[cell] = {"kind": kind, "side": side}
	_redraw_all()


## Libère toutes les cases réservées par un ouvrier.
func release_jobs(worker: Node) -> void:
	for cell: Vector2i in reserved.keys():
		if reserved[cell] == worker:
			reserved.erase(cell)
	for cell: Vector2i in construction:
		if construction[cell]["worker"] == worker:
			construction[cell]["worker"] = null


# ---------------------------------------------------------------------------
# Chantiers : les ouvriers construisent les salles et les défenses
# ---------------------------------------------------------------------------

## Ouvre un chantier. kind : "room" ou "defense".
func start_construction(cell: Vector2i, kind: String, type: int) -> void:
	var total := Rooms.build_time(type) if kind == "room" else Defenses.build_time(type)
	construction[cell] = {"kind": kind, "type": type, "left": total, "total": total, "worker": null}
	_redraw_all()


## Pour un ouvrier : le chantier libre le plus proche qu'il peut atteindre.
func find_build_job(worker: Node, from_cell: Vector2i) -> Dictionary:
	if construction.is_empty():
		return {}
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in construction:
		var builder = construction[cell]["worker"]
		if builder == null or not is_instance_valid(builder) or builder == worker:
			candidates.append(cell)
	var best := _find_nearest_reachable(candidates, from_cell)
	if not best.is_empty():
		best["type"] = "build"
		construction[best["target"]]["worker"] = worker
	return best


## Un ouvrier travaille delta secondes sur un chantier. Renvoie true quand c'est fini :
## la salle ou la défense est alors posée pour de bon.
func work_on_construction(cell: Vector2i, delta: float) -> bool:
	if not construction.has(cell):
		return true
	var site: Dictionary = construction[cell]
	site["left"] -= delta
	if site["left"] > 0.0:
		return false
	construction.erase(cell)
	if site["kind"] == "room":
		build_room(cell, site["type"])
	else:
		place_defense(cell, site["type"])
	return true


## Annule un chantier (outil Démolir). Renvoie ce qu'il était, pour rembourser.
func cancel_construction(cell: Vector2i) -> Dictionary:
	var site: Dictionary = construction.get(cell, {})
	construction.erase(cell)
	_redraw_all()
	return site


## L'image de l'objet en construction (dessinée en transparence sur le chantier).
func _site_texture(site: Dictionary) -> Texture2D:
	var type: int = site["type"]
	if site["kind"] == "defense":
		match type:
			Defenses.Type.SPIKES:
				return Art.SPIKES_UP
			Defenses.Type.RUNE:
				return Art.RUNE
			Defenses.Type.DOOR:
				return Art.DOOR
		return Art.SACRIFICE_ALTAR
	match type:
		Rooms.Type.TREASURY:
			return Art.CHESTS[0]
		Rooms.Type.LAIR:
			return Art.BED
		Rooms.Type.FARM:
			return Art.MUSHROOM
	return Art.ROOM_PROPS.get(type, Art.CHESTS[0])


# ---------------------------------------------------------------------------
# Salles
# ---------------------------------------------------------------------------

func get_room(cell: Vector2i) -> int:
	return rooms.get(cell, Rooms.Type.NONE)


## On construit seulement sur du sol creusé, et pas deux salles sur la même case.
func can_build_room(cell: Vector2i) -> bool:
	return get_tile(cell) == Tile.FLOOR and claimed.has(cell) and not rooms.has(cell) \
			and not defenses.has(cell) and not construction.has(cell)


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
	_redraw_all()


## Démolit la salle d'une case. L'or qu'elle contenait est déplacé dans les
## autres cases de trésor s'il y a de la place. Renvoie l'or perdu.
func remove_room(cell: Vector2i) -> int:
	if not rooms.has(cell):
		return 0
	rooms.erase(cell)
	food.erase(cell)
	beds.erase(cell) # La créature qui dormait là n'a plus de lit.
	work_spots.erase(cell)
	graves.erase(cell) # Le héros enterré là ne se relèvera pas.
	prisoners.erase(cell) # Le prisonnier s'évadera (voir hero.gd).
	var lost: int = stored_gold.get(cell, 0)
	stored_gold.erase(cell)
	for other: Vector2i in stored_gold:
		var moved := mini(lost, Rooms.TREASURY_CAPACITY - stored_gold[other])
		stored_gold[other] += moved
		lost -= moved
	gold_changed.emit()
	_redraw_all()
	return lost


# ---------------------------------------------------------------------------
# Lits, nourriture et portail (pour les créatures)
# ---------------------------------------------------------------------------

## Enterre un héros mort dans une tombe libre du Cimetière.
## Renvoie la case de la tombe, ou (-1, -1) s'il n'y a pas de tombe libre.
func bury() -> Vector2i:
	for cell: Vector2i in rooms:
		if rooms[cell] == Rooms.Type.GRAVEYARD and not graves.has(cell):
			graves[cell] = Rules.REVENANT_RISE_TIME
			_redraw_all()
			return cell
	return Vector2i(-1, -1)


## Les tombes dont le héros enterré est prêt à se relever.
func ready_graves() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in graves:
		if graves[cell] <= 0.0:
			result.append(cell)
	return result


## Le Revenant est sorti : la tombe redevient libre.
func empty_grave(cell: Vector2i) -> void:
	graves.erase(cell)
	_redraw_all()


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


## Réserve pour une créature la case libre la plus proche d'une salle de travail
## (bibliothèque, atelier, entraînement). Renvoie { "target", "path" } ou {}.
func find_work_spot(creature: Node, room_type: int, from_cell: Vector2i) -> Dictionary:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in rooms:
		if rooms[cell] == room_type and work_spots.get(cell, creature) == creature:
			candidates.append(cell)
	var best := _find_nearest_reachable(candidates, from_cell)
	if not best.is_empty():
		release_work_spot(creature)
		work_spots[best["target"]] = creature
	return best


## Une case de Prison libre, ou (-1, -1) s'il n'y en a pas.
func find_free_prison_cell() -> Vector2i:
	for cell: Vector2i in rooms:
		if rooms[cell] == Rooms.Type.PRISON and not prisoners.has(cell):
			return cell
	return Vector2i(-1, -1)


func release_work_spot(creature: Node) -> void:
	for cell: Vector2i in work_spots.keys():
		if work_spots[cell] == creature:
			work_spots.erase(cell)


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
	_redraw_all()
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
	return get_tile(cell) == Tile.FLOOR and claimed.has(cell) and not rooms.has(cell) \
			and not defenses.has(cell) and not construction.has(cell)


func place_defense(cell: Vector2i, type: int) -> void:
	defenses[cell] = {
		"type": type,
		"hp": Defenses.INFO[type].get("hp", 0.0),
		"cooldown": 0.0, # Temps avant que le piège soit de nouveau prêt.
		"flash": 0.0,    # Temps pendant lequel les pointes restent sorties.
	}
	if type == Defenses.Type.DOOR:
		hero_astar.set_point_weight_scale(cell, HERO_DOOR_WEIGHT)
	_redraw_all()


func remove_defense(cell: Vector2i) -> void:
	if not defenses.has(cell):
		return
	if defenses[cell]["type"] == Defenses.Type.DOOR:
		hero_astar.set_point_weight_scale(cell, 1.0)
	defenses.erase(cell)
	_redraw_all()


func count_defenses(type: int) -> int:
	var count := 0
	for cell: Vector2i in defenses:
		if defenses[cell]["type"] == type:
			count += 1
	for cell: Vector2i in construction: # Les défenses en cours d'installation comptent aussi.
		if construction[cell]["kind"] == "defense" and construction[cell]["type"] == type:
			count += 1
	return count


## Les cases où se trouve un autel de sacrifice.
func altar_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in defenses:
		if defenses[cell]["type"] == Defenses.Type.ALTAR:
			result.append(cell)
	return result


func has_door(cell: Vector2i) -> bool:
	return defenses.has(cell) and defenses[cell]["type"] == Defenses.Type.DOOR


## Un héros frappe une porte. À 0 point de vie, elle est détruite.
func damage_door(cell: Vector2i, amount: float) -> void:
	if not has_door(cell):
		return
	defenses[cell]["hp"] -= amount
	Sound.play("door_hit", cell_to_world(cell))
	_redraw_all()
	if defenses[cell]["hp"] <= 0.0:
		remove_defense(cell)
		Sound.play("door_break", cell_to_world(cell))
		Fx.burst("dust", cell_to_world(cell), Color("8d6e63"))
		Fx.shake(4.0)
		door_destroyed.emit(cell)


## Dix fois par seconde, on regarde si un héros marche sur un piège.
func _update_traps(delta: float) -> void:
	for cell: Vector2i in defenses:
		var defense: Dictionary = defenses[cell]
		defense["cooldown"] = maxf(0.0, defense["cooldown"] - delta)
		if defense["flash"] > 0.0:
			defense["flash"] -= delta
			if defense["flash"] <= 0.0:
				_redraw_all() # Les pointes rentrent.

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
					Sound.play("spikes", cell_to_world(cell))
					_redraw_all()
			Defenses.Type.RUNE:
				_explode(cell, info["damage"], info["radius"])


## La rune explose : tous les héros proches sont touchés, puis elle disparaît.
func _explode(cell: Vector2i, explosion_damage: float, radius: float) -> void:
	var center := cell_to_world(cell)
	remove_defense(cell)
	add_effect(center, radius, Color(1.0, 0.55, 0.1, 0.8))
	Sound.play("explosion", center)
	Fx.burst("smoke", center)
	Fx.flash_light(center, Color(1.0, 0.6, 0.2), 200.0, 0.5)
	Fx.shake(8.0, 0.35)
	for node in get_tree().get_nodes_in_group("heroes"):
		var hero := node as Unit
		if hero.position.distance_to(center) <= radius:
			hero.take_damage(explosion_damage)


## Affiche un cercle de couleur qui grandit et s'efface (explosion, sort...).
func add_effect(center: Vector2, radius: float, color: Color) -> void:
	_effects.append({"position": center, "radius": radius, "time": EFFECT_TIME, "color": color})
	_effects_layer.queue_redraw()


func _update_effects(delta: float) -> void:
	if _effects.is_empty():
		return
	for explosion in _effects:
		explosion["time"] -= delta
	_effects = _effects.filter(func(e: Dictionary) -> bool: return e["time"] > 0.0)
	_effects_layer.queue_redraw()


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


## Chemin d'un héros vers n'importe quelle case, en creusant la terre au besoin
## (le Moine s'en sert pour rejoindre la Prison). Vide si c'est impossible (roche).
func find_hero_path_to(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	if hero_astar.is_point_solid(from_cell) or hero_astar.is_point_solid(to_cell):
		return []
	return hero_astar.get_id_path(from_cell, to_cell)


func is_next_to_rival_heart(cell: Vector2i) -> bool:
	return has_rival and _manhattan(cell, rival_heart_cell) == 1


func damage_rival_heart(amount: float) -> void:
	if not has_rival or rival_heart_hp <= 0.0:
		return
	rival_heart_hp = maxf(0.0, rival_heart_hp - amount)
	Sound.play("heart_hit", cell_to_world(rival_heart_cell), -4.0)
	_redraw_all()
	if rival_heart_hp <= 0.0:
		Sound.play("explosion", cell_to_world(rival_heart_cell))
		Fx.burst("smoke", cell_to_world(rival_heart_cell))
		Fx.shake(10.0, 0.5)
		add_effect(cell_to_world(rival_heart_cell), 80.0, Color(0.4, 0.6, 1.0, 0.9))
		rival_heart_destroyed.emit()


func damage_heart(amount: float) -> void:
	if heart_hp <= 0.0:
		return
	heart_hp = maxf(0.0, heart_hp - amount)
	heart_changed.emit()
	Sound.play("heart_hit", cell_to_world(heart_cell))
	Fx.shake(3.0, 0.15)
	last_heart_hit_msec = Time.get_ticks_msec()
	_redraw_all()
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
	_redraw_all()
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
		_redraw_all()
	return amount - remaining


## Un ouvrier dépose de l'or sur une case de trésor. Renvoie la quantité acceptée.
func deposit_gold(cell: Vector2i, amount: int) -> int:
	if not stored_gold.has(cell):
		return 0
	var accepted := mini(amount, Rooms.TREASURY_CAPACITY - stored_gold[cell])
	stored_gold[cell] += accepted
	if accepted > 0:
		gold_changed.emit()
		_redraw_all()
	return accepted


## Cherche la case de trésor non pleine la plus proche.
## Renvoie { "type": "deposit", "target": case, "path": chemin }, ou {} si aucune.
## Pour la Voleuse : le coffre plein le plus proche qu'elle peut atteindre.
func find_loot_job(from_cell: Vector2i) -> Dictionary:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in stored_gold:
		if stored_gold[cell] > 0:
			candidates.append(cell)
	return _find_nearest_reachable(candidates, from_cell)


## La Voleuse vide un coffre (jusqu'à amount). Renvoie l'or volé.
func steal_gold(cell: Vector2i, amount: int) -> int:
	var taken := mini(stored_gold.get(cell, 0), amount)
	if taken <= 0:
		return 0
	stored_gold[cell] -= taken
	gold_changed.emit()
	_redraw_all()
	return taken


## Un sac d'or tombe par terre (la Voleuse a été abattue).
func drop_gold(cell: Vector2i, amount: int) -> void:
	if amount <= 0:
		return
	loose_gold[cell] = loose_gold.get(cell, 0) + amount
	_redraw_all()


## Pour les ouvriers : le tas d'or par terre le plus proche.
func find_pickup_job(from_cell: Vector2i) -> Dictionary:
	if loose_gold.is_empty():
		return {}
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in loose_gold:
		candidates.append(cell)
	var best := _find_nearest_reachable(candidates, from_cell)
	if not best.is_empty():
		best["type"] = "pickup"
	return best


## Un ouvrier ramasse jusqu'à amount pièces d'un tas. Renvoie l'or ramassé.
func pick_up_gold(cell: Vector2i, amount: int) -> int:
	var taken := mini(loose_gold.get(cell, 0), amount)
	if taken <= 0:
		return 0
	loose_gold[cell] -= taken
	if loose_gold[cell] <= 0:
		loose_gold.erase(cell)
	_redraw_all()
	return taken


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
# Affichage (vue isométrique, voir iso.gd)
# ---------------------------------------------------------------------------
## Le dessin est réparti en plusieurs « couches » :
##   - ce nœud (DungeonMap) dessine le SOL : dalles, salles, pièges posés à plat ;
##   - une couche par DIAGONALE (les cases où x + y = d) dessine les MURS en relief
##     et les OBJETS debout (cœur, lits, portes...). Les diagonales du fond sont
##     dessinées d'abord (z_index plus petit), celles de devant par-dessus, et les
##     personnages s'intercalent au bon endroit (voir Iso.depth_z) ;
##   - une couche d'EFFETS (cercles des explosions et des sorts) par-dessus tout.
## Ces couches sont de simples Node2D : on branche leur signal « draw » sur une
## fonction d'ici, qui dessine sur elles.

var _wall_layers: Array[Node2D] = []
var _effects_layer: Node2D

const WALL_SHADE_SOUTH := Color(0.78, 0.78, 0.78) ## Face avant-gauche du mur.
const WALL_SHADE_EAST := Color(0.55, 0.55, 0.55)  ## Face avant-droite, plus sombre.


func _create_layers() -> void:
	for d in WIDTH + HEIGHT - 1:
		var layer := Node2D.new()
		layer.z_index = d * 4 + 2
		layer.draw.connect(_draw_diagonal.bind(layer, d))
		add_child(layer)
		_wall_layers.append(layer)
	_effects_layer = Node2D.new()
	_effects_layer.z_index = 1000
	_effects_layer.draw.connect(_draw_effects)
	add_child(_effects_layer)


## Demande à toutes les couches de se redessiner.
func _redraw_all() -> void:
	redrawn.emit()
	queue_redraw()
	for layer in _wall_layers:
		layer.queue_redraw()


func _is_wall(cell: Vector2i) -> bool:
	if not is_inside(cell):
		return true
	var tile := get_tile(cell)
	return tile == Tile.EARTH or tile == Tile.GOLD or tile == Tile.ROCK


## Change les torches, et redessine seulement si quelque chose a changé.
func set_torches(cells: Dictionary) -> void:
	if cells == torch_cells:
		return
	torch_cells = cells
	_redraw_all()


## Le SOL. Godot appelle _draw() quand on demande queue_redraw().
## Chaque image 16 x 16 (voir art.gd) remplit un carré de 32 x 32... que la
## transformation isométrique transforme en losange.
func _draw() -> void:
	var size := Vector2(TILE_SIZE, TILE_SIZE)
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if _is_wall(cell):
				continue
			var rect := Rect2(Vector2(cell * TILE_SIZE), size)
			if rooms.has(cell):
				_draw_room_floor(cell, rect)
			elif rival_claimed.has(cell):
				# Le territoire du rival : les mêmes dalles, teintées de bleu.
				draw_texture_rect(Art.pick(Art.CLAIMED, cell), rect, false, RIVAL_TINT)
			else:
				var floor_images: Array = Art.CLAIMED if claimed.has(cell) else Art.FLOOR
				draw_texture_rect(Art.pick(floor_images, cell), rect, false)
			if decorations.has(cell) and decorations[cell]["kind"] == "rug":
				draw_texture_rect(Art.DECORATIONS["rug"], rect.grow(-3.0), false)
			if construction.has(cell) and construction[cell]["kind"] == "room":
				draw_texture_rect(Art.ROOM_FLOORS[construction[cell]["type"]], rect, false, Color(1, 1, 1, 0.4))
			# Les pièges sont posés à plat sur le sol.
			if defenses.has(cell):
				var defense: Dictionary = defenses[cell]
				if defense["type"] == Defenses.Type.SPIKES:
					draw_texture_rect(Art.SPIKES_UP if defense["flash"] > 0.0 else Art.SPIKES_DOWN, rect, false)
				elif defense["type"] == Defenses.Type.RUNE:
					draw_texture_rect(Art.RUNE, rect, false)


func _draw_room_floor(cell: Vector2i, rect: Rect2) -> void:
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


## Une diagonale : les murs en relief et les objets debout des cases où x + y = d.
func _draw_diagonal(layer: Node2D, d: int) -> void:
	_layer_is_animated = false
	for x in range(maxi(0, d - HEIGHT + 1), mini(WIDTH - 1, d) + 1):
		var cell := Vector2i(x, d - x)
		if _is_wall(cell):
			_draw_wall(layer, cell)
		else:
			_draw_standing_objects(layer, cell)
	layer.draw_set_transform_matrix(Transform2D.IDENTITY)
	# On retient si cette couche devra être redessinée à chaque tic d'animation.
	if _layer_is_animated:
		_animated_layers[d] = true
	else:
		_animated_layers.erase(d)


## L'image actuelle d'un objet animé. Chaque case a son propre décalage :
## les torches ne vacillent pas toutes en même temps.
func _animated(prop: String, cell: Vector2i) -> Texture2D:
	_layer_is_animated = true
	return Art.prop_frame(prop, anim_tick + cell.x * 3 + cell.y * 5)


## Le cœur bat : un « poum-poum » par seconde, bien plus vite s'il est attaqué.
func _heartbeat() -> float:
	_layer_is_animated = true
	var attacked := Time.get_ticks_msec() - last_heart_hit_msec < 3000
	var pattern := [0.09, 0.02, 0.06, 0.0, 0.0, 0.0]
	if attacked:
		pattern = [0.1, 0.0, 0.06]
	return 1.0 + pattern[anim_tick % pattern.size()]


## Un mur en relief : deux faces visibles (seulement si la case voisine est vide)
## et le dessus, remonté de WALL_HEIGHT pixels à l'écran.
func _draw_wall(layer: Node2D, cell: Vector2i) -> void:
	layer.draw_set_transform_matrix(Transform2D.IDENTITY)
	var tile := get_tile(cell)
	var images: Array = Art.ROCK
	if tile == Tile.EARTH:
		images = Art.EARTH
	elif tile == Tile.GOLD:
		images = Art.GOLD
	var texture: Texture2D = Art.pick(images, cell)
	var p := Vector2(cell * TILE_SIZE)
	var s := float(TILE_SIZE)
	var up := Iso.UP * Iso.WALL_HEIGHT

	if not _is_wall(cell + Vector2i.DOWN):
		_draw_face(layer, texture, p + Vector2(0, s), p + Vector2(s, s), up, WALL_SHADE_SOUTH)
	if not _is_wall(cell + Vector2i.RIGHT):
		_draw_face(layer, texture, p + Vector2(s, s), p + Vector2(s, 0), up, WALL_SHADE_EAST)
	# Les tableaux et tapisseries accrochés sur les faces visibles de ce mur.
	var south: Dictionary = decorations.get(cell + Vector2i.DOWN, {})
	if south.get("side") == Vector2i.UP:
		_draw_wall_decoration(layer, south["kind"], p + Vector2(0, s), p + Vector2(s, s), up, WALL_SHADE_SOUTH)
	var east: Dictionary = decorations.get(cell + Vector2i.RIGHT, {})
	if east.get("side") == Vector2i.LEFT:
		_draw_wall_decoration(layer, east["kind"], p + Vector2(s, s), p + Vector2(s, 0), up, WALL_SHADE_EAST)

	var top := Rect2(p + up, Vector2(s, s))
	layer.draw_texture_rect(texture, top, false)
	layer.draw_rect(top, Color(0, 0, 0, 0.25), false, 1.0)
	# Plus le mur a pris de coups, plus il s'assombrit.
	if damage.has(cell) and DIG_HITS.has(tile):
		var ratio: float = float(damage[cell]) / DIG_HITS[tile]
		layer.draw_rect(top, Color(0, 0, 0, ratio * 0.5))
	# Les murs marqués « à creuser » sont entourés de jaune.
	if marked.has(cell):
		layer.draw_rect(top.grow(-2), MARK_COLOR, false, 2.0)


## Un tableau ou une tapisserie, plaqué sur une face de mur (a -> b au sol).
func _draw_wall_decoration(layer: Node2D, kind: String, a: Vector2, b: Vector2, up: Vector2,
		shade: Color) -> void:
	var left := a.lerp(b, 0.2)
	var right := a.lerp(b, 0.8)
	var low := 0.3 if kind == "painting" else 0.12
	var high := 0.88 if kind == "painting" else 0.95
	var points := PackedVector2Array([left + up * low, right + up * low, right + up * high, left + up * high])
	var uvs := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	layer.draw_polygon(points, PackedColorArray([shade.lightened(0.25)]), uvs, Art.DECORATIONS[kind])


## Une face verticale de mur : un quadrilatère entre l'arête au sol (a -> b) et
## la même arête remontée de « up », recouvert par la texture assombrie.
func _draw_face(layer: Node2D, texture: Texture2D, a: Vector2, b: Vector2, up: Vector2, shade: Color) -> void:
	var points := PackedVector2Array([a, b, b + up, a + up])
	var uvs := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	layer.draw_polygon(points, PackedColorArray([shade]), uvs, texture)


## Les objets debout sur une case de sol : cœur, portail, entrée, meubles, portes...
func _draw_standing_objects(layer: Node2D, cell: Vector2i) -> void:
	var center := cell_to_world(cell)
	match get_tile(cell):
		Tile.HEART:
			_billboard(layer, Art.HEART, center, 1.1 * _heartbeat())
			if heart_hp < HEART_MAX_HP:
				_draw_bar(layer, -38.0, heart_hp / HEART_MAX_HP, Color("e53935"))
		Tile.RIVAL_HEART:
			var rival_scale := 1.1 * _heartbeat() if rival_heart_hp > 0.0 else 1.1
			_billboard(layer, Art.HEART, center, rival_scale, Color(0.4, 0.55, 1.6))
			_draw_bar(layer, -38.0, rival_heart_hp / rival_heart_max_hp, Color("42a5f5"))
		Tile.PORTAL:
			_billboard(layer, _animated("portal", cell), center, 1.2)
		Tile.ENTRANCE:
			_billboard(layer, Art.ENTRANCE, center, 1.3)

	if rooms.has(cell):
		var type := get_room(cell)
		match type:
			Rooms.Type.TREASURY:
				# Un coffre : fermé s'il est vide, puis de plus en plus rempli d'or.
				var fill: float = float(stored_gold.get(cell, 0)) / Rooms.TREASURY_CAPACITY
				var level := 0 if fill <= 0.0 else mini(3, 1 + int(fill * 3.0))
				_billboard(layer, Art.CHESTS[level], center, 0.95)
			Rooms.Type.LAIR:
				_billboard(layer, Art.BED, center, 0.9)
			Rooms.Type.FARM:
				# Un petit champignon par unité de nourriture, à trois endroits de la case.
				var spots := [Vector2(-8, 6), Vector2(7, -6), Vector2(4, 9)]
				for i in food.get(cell, 0):
					_billboard(layer, Art.MUSHROOM, center + spots[i], 0.5)
			Rooms.Type.WORKSHOP:
				_billboard(layer, _animated("anvil", cell), center, 1.0)
			Rooms.Type.TRAINING:
				_billboard(layer, _animated("dummy", cell), center, 1.0)
			Rooms.Type.TEMPLE:
				_billboard(layer, _animated("altar", cell), center, 1.0)
			Rooms.Type.GRAVEYARD:
				# Une tombe : ouverte si elle est libre ; sinon une lueur verte s'en échappe.
				if graves.has(cell):
					_billboard(layer, _animated("tomb_full", cell), center, 0.95)
				else:
					_billboard(layer, Art.TOMB_EMPTY, center, 0.95)
			_:
				if Art.ROOM_PROPS.has(type):
					_billboard(layer, Art.ROOM_PROPS[type], center, 1.0)

	# Une torche, sauf si la case est occupée par un meuble ou une défense.
	if torch_cells.has(cell) and not rooms.has(cell) and not defenses.has(cell):
		_billboard(layer, _animated("torch", cell), center, 0.8)

	if construction.has(cell):
		# Un chantier : l'objet en transparence, et une barre de progression.
		_layer_is_animated = true # La barre avance : on redessine à chaque tic.
		var site: Dictionary = construction[cell]
		_billboard(layer, _site_texture(site), center, 0.9, Color(0.7, 0.85, 1.0, 0.45))
		var progress := 1.0 - float(site["left"]) / float(site["total"])
		_draw_bar(layer, -30.0, progress, Color("ffb74d"))

	if loose_gold.has(cell):
		# Un tas d'or par terre, plus gros s'il y a beaucoup d'or.
		var pile := clampi(int(loose_gold[cell]) / 40, 0, Art.GOLD_PILES.size() - 1)
		_billboard(layer, Art.GOLD_PILES[pile], center, 0.75)

	if defenses.has(cell) and defenses[cell]["type"] == Defenses.Type.ALTAR:
		_billboard(layer, _animated("sacrifice_altar", cell), center, 1.1)

	if has_door(cell):
		_billboard(layer, Art.DOOR, center, 1.1)
		var max_hp: float = Defenses.INFO[Defenses.Type.DOOR]["hp"]
		if defenses[cell]["hp"] < max_hp:
			_draw_bar(layer, -36.0, defenses[cell]["hp"] / max_hp, Color("ffa726"))


## Dessine une image « debout » (non inclinée), posée au sol en `center`.
## Après l'appel, la transformation reste celle de l'objet (pour dessiner sa barre).
func _billboard(layer: Node2D, texture: Texture2D, center: Vector2, scale_factor := 1.0,
		modulate_color := Color.WHITE) -> void:
	layer.draw_set_transform_matrix(Iso.billboard(center))
	var size := Vector2(32, 32) * scale_factor
	layer.draw_texture_rect(texture, Rect2(Vector2(-size.x / 2, -size.y + 6), size), false, modulate_color)


## Une barre de vie au-dessus de l'objet qu'on vient de dessiner avec _billboard.
func _draw_bar(layer: Node2D, y: float, ratio: float, color: Color) -> void:
	var bar := Rect2(-16, y, 32, 5)
	layer.draw_rect(bar, Color(0, 0, 0, 0.7))
	bar.size.x *= clampf(ratio, 0.0, 1.0)
	layer.draw_rect(bar, color)


## Les effets : un cercle au sol qui grandit et s'efface (une ellipse, en vue isométrique).
func _draw_effects() -> void:
	for effect in _effects:
		var progress: float = 1.0 - effect["time"] / EFFECT_TIME
		var color: Color = effect["color"]
		color.a *= 1.0 - progress
		_effects_layer.draw_circle(effect["position"], effect["radius"] * (0.4 + 0.6 * progress), color)

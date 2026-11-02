class_name Worker
extends Node2D
## Un ouvrier : il creuse les cases marquées et rapporte l'or au trésor.
##
## Son comportement est une « machine à états » : à chaque instant il est dans
## UN état (IDLE, MOVING ou DIGGING), et chaque état a sa propre fonction.
## C'est la façon la plus simple et la plus lisible de programmer une IA de jeu.
##
## Son travail (« job ») est un petit dictionnaire :
##   { "type": "dig" ou "deposit", "target": case visée, "path": chemin }

enum State {
	IDLE,    ## Ne fait rien : cherche du travail ou se promène.
	MOVING,  ## Suit un chemin.
	DIGGING, ## Creuse une case.
}

const SPEED := 90.0          ## Vitesse de marche, en pixels par seconde.
const DIG_INTERVAL := 0.45   ## Secondes entre deux coups de pioche.
const CARRY_CAPACITY := 120  ## Or qu'un ouvrier peut porter dans ses poches.
const BODY_COLOR := Color("7cb342")

var map: DungeonMap
var state: State = State.IDLE
## Cases qu'il reste à parcourir.
var path: Array[Vector2i] = []
## Travail en cours, ou {} s'il n'en a pas.
var job: Dictionary = {}
## Or transporté.
var carried_gold := 0

var _think_timer := 0.0
var _dig_timer := 0.0
var _swing := 0.0


## Appelée par main.gd juste après la création de l'ouvrier.
func setup(dungeon_map: DungeonMap, cell: Vector2i) -> void:
	map = dungeon_map
	position = map.cell_to_world(cell)
	_think_timer = randf_range(0.0, 0.5)


func current_cell() -> Vector2i:
	return map.world_to_cell(position)


func is_full() -> bool:
	return carried_gold >= CARRY_CAPACITY


## Godot appelle _process() à chaque image (environ 60 fois par seconde).
## « delta » = temps écoulé depuis l'image précédente, en secondes.
func _process(delta: float) -> void:
	match state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.DIGGING:
			_process_digging(delta)
	queue_redraw()


func _process_idle(delta: float) -> void:
	# On ne réfléchit pas à chaque image : deux fois par seconde suffit.
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = 0.5

	job = _choose_job()
	if not job.is_empty():
		_follow(job["path"])
		return

	# Rien à faire : on fait quelques pas au hasard pour paraître vivant.
	var wander_target := current_cell() + Vector2i(randi_range(-2, 2), randi_range(-2, 2))
	var wander_path := map.find_path(current_cell(), wander_target)
	if wander_path.size() > 1 and wander_path.size() <= 5:
		_follow(wander_path)
	_think_timer = randf_range(0.8, 2.0)


## Décide du prochain travail, par ordre de priorité.
func _choose_job() -> Dictionary:
	# 1. On a de l'or sur soi et un trésor a de la place : on va le ranger.
	if carried_gold > 0:
		var deposit := map.find_deposit_job(current_cell())
		if not deposit.is_empty():
			return deposit
	# 2. Sinon on creuse. Avec les poches pleines, on évite les filons d'or.
	return map.find_dig_job(self, current_cell(), not is_full())


func _process_moving(delta: float) -> void:
	# Le joueur a peut-être enlevé la marque ou démoli le trésor entre-temps.
	if not _job_still_valid():
		_stop_job()
		return

	if path.is_empty():
		_arrive()
		return

	var next_position := map.cell_to_world(path[0])
	position = position.move_toward(next_position, SPEED * delta)
	if position == next_position:
		path.remove_at(0)


## Arrivé au bout du chemin : on fait ce qui était prévu.
func _arrive() -> void:
	if job.is_empty():
		state = State.IDLE
	elif job["type"] == "dig":
		state = State.DIGGING
		_dig_timer = DIG_INTERVAL
	else: # "deposit"
		carried_gold -= map.deposit_gold(job["target"], carried_gold)
		_stop_job()
		_think_timer = 0.1


func _process_digging(delta: float) -> void:
	if not _job_still_valid():
		_stop_job()
		return

	_swing += delta * 14.0
	_dig_timer -= delta
	if _dig_timer > 0.0:
		return
	_dig_timer = DIG_INTERVAL

	var result := map.dig(job["target"])
	carried_gold += result["gold"]
	# Case finie, ou poches pleines : on arrête (et on ira vider ses poches).
	if result["finished"] or is_full():
		_stop_job()
		_think_timer = 0.1 # On cherche tout de suite le travail suivant.


func _job_still_valid() -> bool:
	if job.is_empty():
		return true
	if job["type"] == "dig":
		return map.marked.has(job["target"])
	return map.get_room(job["target"]) == Rooms.Type.TREASURY


func _follow(new_path: Array[Vector2i]) -> void:
	path.assign(new_path) # Copie du chemin.
	if not path.is_empty():
		path.remove_at(0) # La première case est celle où l'on se trouve déjà.
	state = State.MOVING


func _stop_job() -> void:
	map.release_jobs(self)
	job = {}
	path.clear()
	state = State.IDLE


func _draw() -> void:
	# Le corps et les yeux.
	draw_circle(Vector2.ZERO, 9.0, BODY_COLOR)
	draw_circle(Vector2(-3, -2), 1.8, Color.BLACK)
	draw_circle(Vector2(3, -2), 1.8, Color.BLACK)
	# Un petit sac doré quand il transporte de l'or.
	if carried_gold > 0:
		draw_circle(Vector2(7, 6), 4.5, Color("ffd54a"))
		draw_arc(Vector2(7, 6), 4.5, 0.0, TAU, 12, Color("8d6e00"), 1.0)
	# Pendant qu'il creuse : une pioche qui se balance vers la case visée.
	if state == State.DIGGING and not job.is_empty():
		var direction := map.cell_to_world(job["target"]) - position
		var angle := direction.angle() + sin(_swing) * 0.7
		var tip := Vector2.from_angle(angle) * 17.0
		draw_line(Vector2.ZERO, tip, Color("8d6e63"), 3.0)
		draw_line(tip - tip.orthogonal().normalized() * 5.0,
				tip + tip.orthogonal().normalized() * 5.0, Color("cfd8dc"), 3.0)

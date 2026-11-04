class_name Worker
extends Unit
## Un ouvrier : il creuse les cases marquées, rapporte l'or au trésor et
## revendique le sol creusé pour agrandir le territoire du donjon.
## (Il hérite de Unit : la marche et les chemins sont écrits dans unit.gd.)
##
## Son comportement est une « machine à états » : à chaque instant il est dans
## UN état (IDLE, MOVING ou DIGGING), et chaque état a sa propre fonction.
## C'est la façon la plus simple et la plus lisible de programmer une IA de jeu.
##
## Son travail (« job ») est un petit dictionnaire :
##   { "type": "dig", "deposit" ou "claim", "target": case visée, "path": chemin }

enum State {
	IDLE,    ## Ne fait rien : cherche du travail ou se promène.
	MOVING,  ## Suit un chemin.
	DIGGING, ## Creuse une case.
	CLAIMING, ## Revendique une case de sol pour le donjon.
}

const DIG_INTERVAL := 0.45   ## Secondes entre deux coups de pioche.
const CARRY_CAPACITY := 120  ## Or qu'un ouvrier peut porter dans ses poches.
const CLAIM_TIME := 1.5      ## Secondes pour revendiquer une case.

var state: State = State.IDLE
## Travail en cours, ou {} s'il n'en a pas.
var job: Dictionary = {}
## Or transporté.
var carried_gold := 0

var _think_timer := 0.0
var _dig_timer := 0.0
var _swing := 0.0


## On complète la fonction setup() de Unit : super() appelle la version d'origine.
func setup(dungeon_map: DungeonMap, cell: Vector2i) -> void:
	super(dungeon_map, cell)
	max_hp = 40.0 # Les ouvriers ne se battent pas, et sont fragiles !
	hp = max_hp
	_think_timer = randf_range(0.0, 0.5)


func display_name() -> String:
	return "Ouvrier"


## Ce qu'il faut pour recréer l'ouvrier au chargement (voir main.gd).
func to_save() -> Dictionary:
	return {"cell": SaveGame.cell_to_array(current_cell()), "hp": hp, "gold": carried_gold}


func is_full() -> bool:
	return carried_gold >= CARRY_CAPACITY


## Godot appelle _process() à chaque image (environ 60 fois par seconde).
## « delta » = temps écoulé depuis l'image précédente, en secondes.
func _process(delta: float) -> void:
	update_effects(delta)
	match state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.DIGGING:
			_process_digging(delta)
		State.CLAIMING:
			_process_claiming(delta)
	queue_redraw()


func _process_idle(delta: float) -> void:
	# On ne réfléchit pas à chaque image : deux fois par seconde suffit.
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = 0.5

	job = _choose_job()
	if not job.is_empty():
		follow_path(job["path"])
		state = State.MOVING
		return

	# Rien à faire : on fait quelques pas au hasard pour paraître vivant.
	var wander_target := current_cell() + Vector2i(randi_range(-2, 2), randi_range(-2, 2))
	var wander_path := map.find_path(current_cell(), wander_target)
	if wander_path.size() > 1 and wander_path.size() <= 5:
		follow_path(wander_path)
		state = State.MOVING
	_think_timer = randf_range(0.8, 2.0)


## Décide du prochain travail, par ordre de priorité.
func _choose_job() -> Dictionary:
	# 1. On a de l'or sur soi et un trésor a de la place : on va le ranger.
	if carried_gold > 0:
		var deposit := map.find_deposit_job(current_cell())
		if not deposit.is_empty():
			return deposit
	# 2. Sinon on creuse. Avec les poches pleines, on évite les filons d'or.
	var dig := map.find_dig_job(self, current_cell(), not is_full())
	if not dig.is_empty():
		return dig
	# 3. Rien à creuser : on agrandit le territoire.
	return map.find_claim_job(self, current_cell())


func _process_moving(delta: float) -> void:
	# Le joueur a peut-être enlevé la marque ou démoli le trésor entre-temps.
	if not _job_still_valid():
		_stop_job()
		return
	if move_along_path(delta):
		_arrive()


## Arrivé au bout du chemin : on fait ce qui était prévu.
func _arrive() -> void:
	if job.is_empty():
		state = State.IDLE
	elif job["type"] == "dig":
		state = State.DIGGING
		_dig_timer = DIG_INTERVAL
	elif job["type"] == "claim":
		state = State.CLAIMING
		_dig_timer = CLAIM_TIME
	else: # "deposit"
		var accepted := map.deposit_gold(job["target"], carried_gold)
		carried_gold -= accepted
		if accepted > 0:
			Sound.play("coins", position, -4.0)
			Fx.burst("coins", position)
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

	var target_position := map.cell_to_world(job["target"])
	play_attack() # Le corps accompagne le coup de pioche.
	var result := map.dig(job["target"])
	Sound.play("dig", target_position)
	Fx.burst("dust", target_position)
	if result["gold"] > 0:
		Sound.play("gold", target_position, -3.0)
		Fx.burst("coins", target_position)
	carried_gold += result["gold"]
	# Case finie, ou poches pleines : on arrête (et on ira vider ses poches).
	if result["finished"] or is_full():
		_stop_job()
		_think_timer = 0.1 # On cherche tout de suite le travail suivant.


## Revendiquer : l'ouvrier reste un moment sur la case, puis elle devient à nous.
func _process_claiming(delta: float) -> void:
	if not _job_still_valid():
		_stop_job()
		return
	_swing += delta * 8.0
	_dig_timer -= delta
	if _dig_timer <= 0.0:
		map.claim(job["target"])
		Sound.play("claim", position, -6.0)
		Fx.burst("claim", position)
		_stop_job()
		_think_timer = 0.1


func _job_still_valid() -> bool:
	if job.is_empty():
		return true
	if job["type"] == "dig":
		return map.marked.has(job["target"])
	if job["type"] == "claim":
		return not map.is_claimed(job["target"])
	return map.get_room(job["target"]) == Rooms.Type.TREASURY


## Ramassé par le joueur : il abandonne son travail (il en cherchera un autre).
func _on_picked_up() -> void:
	_stop_job()


func _on_dropped() -> void:
	_think_timer = 0.2


## Tué par un héros : il libère la case qu'il devait creuser.
func die() -> void:
	map.release_jobs(self)
	super()


func _stop_job() -> void:
	map.release_jobs(self)
	job = {}
	path.clear()
	state = State.IDLE


func _draw() -> void:
	draw_sprite("worker", 0.85)
	# Un petit sac doré quand il transporte de l'or.
	if carried_gold > 0:
		draw_circle(Vector2(8, 6), 4.0, Color("ffd54a"))
		draw_arc(Vector2(8, 6), 4.0, 0.0, TAU, 12, Color("8d6e00"), 1.0)
	# Pendant qu'il creuse : une pioche qui se balance vers la case visée.
	if state == State.DIGGING and not job.is_empty():
		var direction := Iso.to_screen_vector(map.cell_to_world(job["target"]) - position)
		var angle := direction.angle() + sin(_swing) * 0.7
		var tip := Vector2.from_angle(angle) * 17.0
		draw_line(Vector2.ZERO, tip, Color("8d6e63"), 3.0)
		draw_line(tip - tip.orthogonal().normalized() * 5.0,
				tip + tip.orthogonal().normalized() * 5.0, Color("cfd8dc"), 3.0)
	# Pendant qu'il revendique : un halo rouge qui pulse sous ses pieds.
	if state == State.CLAIMING:
		draw_arc(Vector2(0, 8), 10.0 + 2.0 * sin(_swing), 0.0, TAU, 20, Color(0.9, 0.2, 0.3, 0.8), 2.0)
	draw_health_bar(-19.0)

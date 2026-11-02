extends Node2D
## Le « chef d'orchestre » du jeu : il relie la carte, la caméra,
## l'interface et les ouvriers, et applique l'outil choisi quand on touche la carte.
##
## Les différentes parties communiquent par des SIGNAUX : la caméra ne connaît
## pas la carte, elle dit juste « on m'a touchée ici ». C'est main.gd qui décide
## quoi en faire. Ainsi chaque script reste simple et indépendant.

const START_GOLD := 200
const START_WORKERS := 3
const WORKER_COST := 100
## Délai minimum entre deux rappels « construis un trésor ».
const REMINDER_DELAY := 12.0

## Quelle salle construit chaque outil de la barre.
const TOOL_ROOMS := {
	Hud.Tool.TREASURY: Rooms.Type.TREASURY,
	Hud.Tool.LAIR: Rooms.Type.LAIR,
	Hud.Tool.FARM: Rooms.Type.FARM,
}

@onready var map: DungeonMap = $DungeonMap
@onready var workers_root: Node2D = $Workers
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $HUD

var current_tool: int = Hud.Tool.DIG
var _reminder_timer := 0.0


func _ready() -> void:
	# On branche les signaux sur nos fonctions.
	map.gold_changed.connect(_refresh_hud)
	camera.tapped.connect(_on_camera_tapped)
	hud.summon_pressed.connect(_on_summon_pressed)
	hud.tool_selected.connect(_on_tool_selected)

	camera.bounds = Rect2(Vector2.ZERO, map.get_pixel_size())
	camera.position = map.cell_to_world(map.heart_cell)

	map.set_starting_gold(START_GOLD)
	for i in START_WORKERS:
		_spawn_worker()

	hud.set_summon_cost(WORKER_COST)
	_refresh_hud()
	hud.show_message("Creuse, puis construis une salle du Trésor : l'or des filons doit y être rangé !", 7.0)


## Si des ouvriers ont les poches pleines et nulle part où ranger l'or,
## on le rappelle au joueur de temps en temps.
func _process(delta: float) -> void:
	_reminder_timer -= delta
	if _reminder_timer > 0.0:
		return
	_reminder_timer = 1.0
	if map.get_treasury_stored() < map.get_treasury_capacity():
		return
	for worker: Worker in workers_root.get_children():
		if worker.is_full():
			var text := "Tes ouvriers ont les poches pleines d'or : construis (ou agrandis) un Trésor !"
			if map.get_treasury_capacity() == 0:
				text = "Tes ouvriers ont les poches pleines d'or : construis un Trésor !"
			hud.show_message(text, 5.0)
			_reminder_timer = REMINDER_DELAY
			return


func _spawn_worker() -> void:
	var worker := Worker.new()
	workers_root.add_child(worker)
	worker.setup(map, map.get_spawn_cell())


func _refresh_hud() -> void:
	hud.set_gold(map.get_total_gold(), map.get_treasury_stored(), map.get_treasury_capacity())
	hud.set_workers(workers_root.get_child_count())


func _on_tool_selected(tool: int) -> void:
	current_tool = tool


func _on_camera_tapped(screen_position: Vector2, world_position: Vector2) -> void:
	if hud.is_over_ui(screen_position):
		return
	var cell := map.world_to_cell(world_position)
	match current_tool:
		Hud.Tool.DIG:
			map.toggle_mark(cell)
		Hud.Tool.DEMOLISH:
			_demolish(cell)
		_:
			_build(cell, TOOL_ROOMS[current_tool])


func _build(cell: Vector2i, room_type: int) -> void:
	if not map.can_build_room(cell):
		if not map.is_walkable(cell):
			hud.show_message("On ne construit que sur du sol déjà creusé.")
		return
	var cost := Rooms.cost(room_type)
	if not map.spend_gold(cost):
		hud.show_message("Pas assez d'or : %s coûte %d par case." % [Rooms.display_name(room_type), cost])
		return
	map.build_room(cell, room_type)


func _demolish(cell: Vector2i) -> void:
	if map.get_room(cell) == Rooms.Type.NONE:
		return
	var lost := map.remove_room(cell)
	if lost > 0:
		hud.show_message("Plus de place dans le trésor : %d or perdu !" % lost)


func _on_summon_pressed() -> void:
	if not map.spend_gold(WORKER_COST):
		hud.show_message("Pas assez d'or ! Creuse les filons dorés.")
		return
	_spawn_worker()
	_refresh_hud()

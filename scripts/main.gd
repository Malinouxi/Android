extends Node2D
## Le « chef d'orchestre » du jeu : il relie la carte, la caméra,
## l'interface et les ouvriers, et gère le trésor (l'or).
##
## Les différentes parties communiquent par des SIGNAUX : la caméra ne connaît
## pas la carte, elle dit juste « on m'a touchée ici ». C'est main.gd qui décide
## quoi en faire. Ainsi chaque script reste simple et indépendant.

const START_GOLD := 200
const START_WORKERS := 3
const WORKER_COST := 100

@onready var map: DungeonMap = $DungeonMap
@onready var workers_root: Node2D = $Workers
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $HUD

var gold := START_GOLD


func _ready() -> void:
	# On branche les signaux sur nos fonctions.
	map.gold_mined.connect(_on_gold_mined)
	camera.tapped.connect(_on_camera_tapped)
	hud.summon_pressed.connect(_on_summon_pressed)

	camera.bounds = Rect2(Vector2.ZERO, map.get_pixel_size())
	camera.position = map.cell_to_world(map.heart_cell)

	for i in START_WORKERS:
		_spawn_worker()

	hud.set_summon_cost(WORKER_COST)
	_refresh_hud()
	hud.show_message("Touche la terre pour la marquer : tes ouvriers vont la creuser !", 6.0)


func _spawn_worker() -> void:
	var worker := Worker.new()
	workers_root.add_child(worker)
	worker.setup(map, map.get_spawn_cell())


func _refresh_hud() -> void:
	hud.set_gold(gold)
	hud.set_workers(workers_root.get_child_count())


func _on_camera_tapped(screen_position: Vector2, world_position: Vector2) -> void:
	if hud.is_over_ui(screen_position):
		return
	map.toggle_mark(map.world_to_cell(world_position))


func _on_gold_mined(amount: int) -> void:
	gold += amount
	_refresh_hud()


func _on_summon_pressed() -> void:
	if gold < WORKER_COST:
		hud.show_message("Pas assez d'or ! Creuse les filons dorés.")
		return
	gold -= WORKER_COST
	_spawn_worker()
	_refresh_hud()

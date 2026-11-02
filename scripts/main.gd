extends Node2D
## Le « chef d'orchestre » du jeu : il relie la carte, la caméra, l'interface,
## les ouvriers et les créatures. Il gère aussi :
##   - l'outil choisi quand on touche la carte ;
##   - l'arrivée des créatures par le portail ;
##   - le jour de paie.
##
## Les différentes parties communiquent par des SIGNAUX : la caméra ne connaît
## pas la carte, elle dit juste « on m'a touchée ici ». C'est main.gd qui décide
## quoi en faire. Ainsi chaque script reste simple et indépendant.

const START_GOLD := 200
const START_WORKERS := 3
const WORKER_COST := 100
## Secondes entre deux arrivées de créatures (si le donjon les attire).
const CREATURE_ARRIVAL_DELAY := 20.0
## Secondes entre deux jours de paie.
const PAYDAY_INTERVAL := 90.0
## Délai minimum entre deux messages d'aide.
const HINT_DELAY := 15.0

## Quelle salle construit chaque outil de la barre.
const TOOL_ROOMS := {
	Hud.Tool.TREASURY: Rooms.Type.TREASURY,
	Hud.Tool.LAIR: Rooms.Type.LAIR,
	Hud.Tool.FARM: Rooms.Type.FARM,
}

@onready var map: DungeonMap = $DungeonMap
@onready var workers_root: Node2D = $Workers
@onready var creatures_root: Node2D = $Creatures
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $HUD

var current_tool: int = Hud.Tool.DIG

var _portal_connected := false
var _portal_check_timer := 0.0
var _arrival_timer := 5.0
var _payday_timer := PAYDAY_INTERVAL
var _hint_timer := 0.0
var _hud_timer := 0.0


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
	hud.show_message("Creuse un couloir jusqu'au portail violet pour attirer des créatures !", 7.0)


func _process(delta: float) -> void:
	_hint_timer -= delta
	_update_portal(delta)
	_update_payday(delta)
	_check_full_pockets()

	# On rafraîchit l'interface 4 fois par seconde (compte à rebours de la paie...).
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.25
		_refresh_hud()


# ---------------------------------------------------------------------------
# Portail et arrivée des créatures
# ---------------------------------------------------------------------------

func _update_portal(delta: float) -> void:
	# Tant que le portail n'est pas relié au donjon, on vérifie toutes les 2 s.
	if not _portal_connected:
		_portal_check_timer -= delta
		if _portal_check_timer > 0.0:
			return
		_portal_check_timer = 2.0
		_portal_connected = map.is_portal_connected()
		if _portal_connected:
			hud.show_message("Le portail est relié à ton donjon : des créatures vont venir !", 6.0)
		return

	_arrival_timer -= delta
	if _arrival_timer > 0.0:
		return
	_arrival_timer = CREATURE_ARRIVAL_DELAY

	# Une créature ne vient que s'il reste un lit libre.
	if creatures_root.get_child_count() >= map.count_room_tiles(Rooms.Type.LAIR):
		_hint("Construis du Repaire : chaque case est un lit pour une créature.")
		return
	var types := Creatures.attracted_types(map)
	if types.is_empty():
		return
	_spawn_creature(types.pick_random())


func _spawn_creature(type: int) -> void:
	var creature := Creature.new()
	creature.setup_creature(map, map.portal_cell, type)
	creature.left_dungeon.connect(_on_creature_left)
	creatures_root.add_child(creature)
	hud.show_message("%s arrive par le portail ! (salaire : %d or)" % [creature.display_name(), creature.salary()])


func _on_creature_left(creature: Creature) -> void:
	hud.show_message("%s, mécontent, quitte ton donjon !" % creature.display_name(), 5.0)


# ---------------------------------------------------------------------------
# Jour de paie
# ---------------------------------------------------------------------------

func _update_payday(delta: float) -> void:
	_payday_timer -= delta
	if _payday_timer > 0.0:
		return
	_payday_timer = PAYDAY_INTERVAL

	var total_paid := 0
	var unpaid := 0
	for creature: Creature in creatures_root.get_children():
		if creature.is_leaving():
			continue
		var paid := map.spend_gold(creature.salary())
		creature.receive_pay(paid)
		if paid:
			total_paid += creature.salary()
		else:
			unpaid += 1

	if unpaid > 0:
		hud.show_message("Jour de paie : pas assez d'or ! %d créature(s) non payée(s), elles sont furieuses." % unpaid, 6.0)
	elif total_paid > 0:
		hud.show_message("Jour de paie : %d or versés à tes créatures." % total_paid)


# ---------------------------------------------------------------------------
# Messages d'aide
# ---------------------------------------------------------------------------

## Affiche un conseil, mais pas trop souvent.
func _hint(text: String) -> void:
	if _hint_timer > 0.0:
		return
	_hint_timer = HINT_DELAY
	hud.show_message(text, 5.0)


## Si des ouvriers ont les poches pleines et nulle part où ranger l'or, on prévient.
func _check_full_pockets() -> void:
	if _hint_timer > 0.0 or map.get_treasury_stored() < map.get_treasury_capacity():
		return
	for worker: Worker in workers_root.get_children():
		if worker.is_full():
			_hint("Tes ouvriers ont les poches pleines d'or : construis (ou agrandis) un Trésor !")
			return


# ---------------------------------------------------------------------------
# Interface et commandes du joueur
# ---------------------------------------------------------------------------

func _spawn_worker() -> void:
	var worker := Worker.new()
	worker.setup(map, map.get_spawn_cell())
	workers_root.add_child(worker)


func _refresh_hud() -> void:
	hud.set_gold(map.get_total_gold(), map.get_treasury_stored(), map.get_treasury_capacity())
	hud.set_workers(workers_root.get_child_count())
	hud.set_creatures(creatures_root.get_child_count(), map.count_room_tiles(Rooms.Type.LAIR))
	hud.set_payday(ceili(_payday_timer))


func _on_tool_selected(tool: int) -> void:
	current_tool = tool


func _on_camera_tapped(screen_position: Vector2, world_position: Vector2) -> void:
	if hud.is_over_ui(screen_position):
		return
	var cell := map.world_to_cell(world_position)
	match current_tool:
		Hud.Tool.DIG:
			# Toucher une créature affiche son état.
			var creature := _creature_at(world_position)
			if creature:
				hud.show_message(creature.describe(), 5.0)
			else:
				map.toggle_mark(cell)
		Hud.Tool.DEMOLISH:
			_demolish(cell)
		_:
			_build(cell, TOOL_ROOMS[current_tool])


func _creature_at(world_position: Vector2) -> Creature:
	for creature: Creature in creatures_root.get_children():
		if creature.position.distance_to(world_position) < 16.0:
			return creature
	return null


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

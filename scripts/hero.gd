class_name Hero
extends Unit
## Un héros venu détruire le cœur du donjon.
##
## Son IA est simple :
##   1. un ennemi (ouvrier ou créature) est proche -> il le combat ;
##   2. sinon il marche vers le cœur. Si le chemin traverse de la terre,
##      il la creuse lui-même (lentement) ;
##   3. arrivé à côté du cœur, il le frappe.

const AGGRO_RADIUS := 128.0  ## Distance (pixels) à laquelle il repère un ennemi.
const DIG_INTERVAL := 0.6    ## Secondes entre deux coups de pioche.

var type: int

var _target: Unit = null
var _think_timer := 0.0
var _dig_timer := 0.0
## Porte qui nous a bloqué le passage à cette image, ou (-1, -1).
var _door_cell := Vector2i(-1, -1)


## À appeler juste après Hero.new().
func setup_hero(dungeon_map: DungeonMap, cell: Vector2i, hero_type: int) -> void:
	type = hero_type
	team = Team.HEROES
	var info := Heroes.info(type)
	speed = info["speed"]
	max_hp = info["hp"]
	hp = max_hp
	attack_damage = info["damage"]
	attack_range = info["range"]
	attack_interval = info["attack_interval"]
	setup(dungeon_map, cell)


func display_name() -> String:
	return Heroes.info(type)["name"]


func reward() -> int:
	return Heroes.info(type)["reward"]


func _process(delta: float) -> void:
	update_attack_cooldown(delta)

	# Si notre cible a disparu (morte entre-temps), on l'oublie.
	if _target != null and not is_instance_valid(_target):
		_target = null

	# Trois fois par seconde, on regarde s'il y a un ennemi à proximité.
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 0.3
		var enemy := find_nearest_enemy(AGGRO_RADIUS)
		if enemy != _target:
			_target = enemy
			path.clear()

	if _target != null:
		if not fight(_target, delta):
			_target = null
			path.clear()
	else:
		_march(delta)

	# Une porte nous barre la route (en marchant ou en poursuivant) : on la frappe.
	if _door_cell != Vector2i(-1, -1):
		_attack_door(_door_cell)
		_door_cell = Vector2i(-1, -1)
	queue_redraw()


## Les portes arrêtent les héros (les autres unités passent librement).
func _is_blocked(cell: Vector2i) -> bool:
	if map.has_door(cell):
		_door_cell = cell
		return true
	return false


func _attack_door(cell: Vector2i) -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = attack_interval
	show_strike(map.cell_to_world(cell))
	map.damage_door(cell, attack_damage)


func _march(delta: float) -> void:
	if map.is_next_to_heart(current_cell()):
		path.clear()
		_attack_heart()
		return

	if path.is_empty():
		follow_path(map.find_hero_path(current_cell()))
		if path.is_empty():
			return

	var next_cell := path[0]
	if map.is_diggable(next_cell):
		# La case suivante est de la terre : on creuse.
		_dig_timer -= delta
		if _dig_timer <= 0.0:
			_dig_timer = DIG_INTERVAL
			show_strike(map.cell_to_world(next_cell))
			map.dig(next_cell) # L'or éventuel est perdu : les héros ne le rapportent pas !
		return
	if not map.is_walkable(next_cell):
		path.clear() # Chemin bloqué : on en recalculera un.
		return
	move_along_path(delta)


func _attack_heart() -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = attack_interval
	show_strike(map.cell_to_world(map.heart_cell))
	map.damage_heart(attack_damage)


func _draw() -> void:
	var info := Heroes.info(type)
	var sprite_scale: float = info["size"] / 8.0
	draw_sprite(Art.UNITS[info["sprite"]], sprite_scale)
	draw_strike()
	draw_health_bar(-16.0 * sprite_scale - 6.0)

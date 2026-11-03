class_name Hero
extends Unit
## Un héros venu détruire le cœur du donjon.
##
## Son IA est simple :
##   1. un ennemi (ouvrier ou créature) est proche -> il le combat ;
##   2. sinon il marche vers le cœur. Si le chemin traverse de la terre,
##      il la creuse lui-même (lentement) ;
##   3. arrivé à côté du cœur, il le frappe.
##
## Vaincu, il est CAPTURÉ s'il reste une cellule libre en Prison (sinon il meurt).
## Le Clerc soigne régulièrement les héros autour de lui.

## Émis quand le héros est capturé (au lieu de mourir).
signal captured(hero: Hero)

const AGGRO_RADIUS := 128.0  ## Distance (pixels) à laquelle il repère un ennemi.
const DIG_INTERVAL := 0.6    ## Secondes entre deux coups de pioche.

var type: int

var _target: Unit = null
var _think_timer := 0.0
var _dig_timer := 0.0
## Porte qui nous a bloqué le passage à cette image, ou (-1, -1).
var _door_cell := Vector2i(-1, -1)
## Sa cellule de prison s'il est capturé, sinon (-1, -1).
var prison_cell := Vector2i(-1, -1)
var _heal_timer := 0.0


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
	load_abilities(info)
	if info.get("rival", false):
		self_modulate = DungeonMap.RIVAL_TINT # Les troupes du rival sont teintées de bleu.
	setup(dungeon_map, cell)


func to_save() -> Dictionary:
	var data := {"type": type, "cell": SaveGame.cell_to_array(current_cell()), "hp": hp}
	if is_captured():
		data["prison"] = SaveGame.cell_to_array(prison_cell)
	return data


func is_captured() -> bool:
	return prison_cell != Vector2i(-1, -1)


## Vaincu : capturé s'il y a une cellule libre, sinon il meurt vraiment.
func die() -> void:
	if not is_captured():
		var cell := map.find_free_prison_cell()
		if cell != Vector2i(-1, -1):
			capture_at(cell)
			Sound.play("capture", position)
			captured.emit(self)
			return
	super()


## Enferme le héros dans une cellule : il ne bouge plus et n'est plus un ennemi actif.
func capture_at(cell: Vector2i) -> void:
	prison_cell = cell
	map.prisoners[cell] = self
	hp = max_hp * 0.3
	remove_from_group(_group_name(team))
	add_to_group("prisoners")
	position = map.cell_to_world(cell)
	z_index = Iso.depth_z(position, DungeonMap.TILE_SIZE)
	path.clear()
	_target = null


## La cellule a été démolie : le prisonnier s'évade et redevient un héros actif.
func _escape() -> void:
	if map.prisoners.get(prison_cell) == self:
		map.prisoners.erase(prison_cell)
	prison_cell = Vector2i(-1, -1)
	remove_from_group("prisoners")
	add_to_group(_group_name(team))


func display_name() -> String:
	return Heroes.info(type)["name"]


func reward() -> int:
	return Heroes.info(type)["reward"]


func _process(delta: float) -> void:
	if is_captured():
		if map.get_room(prison_cell) != Rooms.Type.PRISON:
			_escape()
		queue_redraw()
		return
	update_attack_cooldown(delta)
	update_effects(delta)
	if type == Heroes.Type.CLERIC:
		_cleric_heal(delta)

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


## Le clerc soigne les héros blessés autour de lui (lui compris).
func _cleric_heal(delta: float) -> void:
	_heal_timer -= delta
	if _heal_timer > 0.0:
		return
	_heal_timer = Heroes.CLERIC_HEAL_INTERVAL
	var healed := false
	for node in get_tree().get_nodes_in_group("heroes"):
		var ally := node as Unit
		if ally != null and ally.hp < ally.max_hp \
				and ally.position.distance_to(position) <= Heroes.CLERIC_HEAL_RADIUS:
			ally.heal(Heroes.CLERIC_HEAL_AMOUNT)
			healed = true
	if healed:
		map.add_effect(position, Heroes.CLERIC_HEAL_RADIUS, Color(1.0, 1.0, 0.6, 0.35))
		Sound.play("heal", position, -8.0)


func _attack_door(cell: Vector2i) -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = attack_interval
	show_strike(map.cell_to_world(cell))
	# Certains héros (le Géant) cassent les portes bien plus vite.
	map.damage_door(cell, attack_damage * Heroes.info(type).get("door_damage", 1.0))


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
			_dig_timer = DIG_INTERVAL / Heroes.info(type).get("dig_speed", 1.0) # Le Nain creuse vite.
			show_strike(map.cell_to_world(next_cell))
			Sound.play("dig", map.cell_to_world(next_cell))
			Fx.burst("dust", map.cell_to_world(next_cell))
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
	if is_captured():
		# Les barreaux de la cellule, par-dessus le prisonnier.
		draw_texture_rect(Art.PRISON_BARS, Rect2(-16, -16, 32, 32), false)

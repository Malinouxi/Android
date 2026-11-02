class_name Creature
extends Unit
## Une créature venue par le portail. Elle a trois besoins :
##   - l'ÉNERGIE baisse avec le temps : elle va dormir dans son lit (Repaire) ;
##   - la FAIM monte : elle va manger un champignon (Champignonnière) ;
##   - le SALAIRE : main.gd la paie à chaque jour de paie.
## Si ses besoins ne sont pas satisfaits, son HUMEUR baisse.
## À 0, elle quitte le donjon par le portail.
## Et quand un héros approche, elle se bat pour défendre le donjon !

## Émis juste avant que la créature disparaisse par le portail.
signal left_dungeon(creature: Creature)

enum State { WANDER, GOING_TO_SLEEP, SLEEPING, GOING_TO_EAT, EATING, LEAVING, FIGHTING }

const STATE_NAMES := {
	State.WANDER: "se promène",
	State.GOING_TO_SLEEP: "va se coucher",
	State.SLEEPING: "dort",
	State.GOING_TO_EAT: "va manger",
	State.EATING: "mange",
	State.LEAVING: "s'en va, furieuse",
	State.FIGHTING: "se bat",
}

const ENERGY_LOSS := 1.2     ## Énergie perdue par seconde (100 -> 0 en ~80 s).
const ENERGY_GAIN := 12.0    ## Énergie regagnée par seconde en dormant.
const HUNGER_GAIN := 1.5     ## Faim gagnée par seconde (0 -> 100 en ~65 s).
const MEAL_VALUE := 60.0     ## Faim enlevée par un champignon.
const EAT_TIME := 1.5        ## Secondes pour manger.
const TIRED_LEVEL := 25.0    ## En dessous : elle va dormir.
const HUNGRY_LEVEL := 65.0   ## Au-dessus : elle va manger.
const HEAL_WHILE_SLEEPING := 5.0 ## Points de vie regagnés par seconde en dormant.
const AGGRO_RADIUS := 192.0  ## Distance (pixels) à laquelle elle repère un héros.
const WAKE_RADIUS := 96.0    ## Un héros plus proche que ça la réveille.
const NO_CELL := Vector2i(-1, -1)

var type: int
var energy := 100.0
var hunger := 0.0
var happiness := 70.0
## Sa case de Repaire (son lit), ou NO_CELL si elle n'en a pas.
var bed_cell := NO_CELL
var state: State = State.WANDER

var _food_cell := NO_CELL
var _think_timer := 0.0
var _mood_timer := 0.0
var _eat_timer := 0.0
var _combat_timer := 0.0
var _enemy: Unit = null


## À appeler juste après Creature.new().
func setup_creature(dungeon_map: DungeonMap, cell: Vector2i, creature_type: int) -> void:
	type = creature_type
	var info := Creatures.info(type)
	speed = info["speed"]
	max_hp = info["hp"]
	hp = max_hp
	attack_damage = info["damage"]
	attack_range = info["range"]
	attack_interval = info["attack_interval"]
	setup(dungeon_map, cell)
	energy = randf_range(60.0, 100.0)
	hunger = randf_range(0.0, 30.0)
	bed_cell = map.claim_bed(self)


func display_name() -> String:
	return Creatures.info(type)["name"]


func salary() -> int:
	return Creatures.info(type)["salary"]


func is_leaving() -> bool:
	return state == State.LEAVING


## Appelée par main.gd au jour de paie.
func receive_pay(paid: bool) -> void:
	happiness = clampf(happiness + (15.0 if paid else -35.0), 0.0, 100.0)


## Petit texte affiché quand on touche la créature.
func describe() -> String:
	return "%s (%s) : vie %d/%d, humeur %d%%, faim %d%%, énergie %d%%, salaire %d or%s" % [
		display_name(), STATE_NAMES[state], hp, max_hp, happiness, hunger, energy, salary(),
		"" if _has_bed() else ", SANS LIT !"]


func _process(delta: float) -> void:
	if state != State.SLEEPING:
		energy = maxf(0.0, energy - ENERGY_LOSS * delta)
	if state != State.EATING:
		hunger = minf(100.0, hunger + HUNGER_GAIN * delta)
	_update_mood(delta)
	update_attack_cooldown(delta)
	_update_combat(delta)

	match state:
		State.WANDER:
			_process_wander(delta)
		State.GOING_TO_SLEEP:
			if not _has_bed():
				state = State.WANDER
			elif move_along_path(delta):
				state = State.SLEEPING
		State.SLEEPING:
			energy += ENERGY_GAIN * delta
			hp = minf(max_hp, hp + HEAL_WHILE_SLEEPING * delta)
			if energy >= 100.0 or not _has_bed():
				energy = minf(energy, 100.0)
				state = State.WANDER
		State.GOING_TO_EAT:
			if move_along_path(delta):
				# Un autre a peut-être mangé le champignon avant nous.
				if map.take_food(_food_cell):
					state = State.EATING
					_eat_timer = EAT_TIME
				else:
					state = State.WANDER
		State.EATING:
			_eat_timer -= delta
			if _eat_timer <= 0.0:
				hunger = maxf(0.0, hunger - MEAL_VALUE)
				state = State.WANDER
		State.LEAVING:
			if move_along_path(delta):
				_leave_now()
		State.FIGHTING:
			if not fight(_enemy, delta):
				_enemy = null
				state = State.WANDER
	queue_redraw()


## Trois fois par seconde : y a-t-il un héros à combattre ?
func _update_combat(delta: float) -> void:
	if state == State.LEAVING:
		return
	_combat_timer -= delta
	if _combat_timer > 0.0:
		return
	_combat_timer = 0.3
	# Une créature endormie ne remarque que les héros tout proches.
	var radius := WAKE_RADIUS if state == State.SLEEPING else AGGRO_RADIUS
	var enemy := find_nearest_enemy(radius)
	if enemy == null:
		return
	if state != State.FIGHTING:
		path.clear()
		state = State.FIGHTING
	_enemy = enemy


func _process_wander(delta: float) -> void:
	# On finit d'abord les quelques pas de promenade en cours.
	if not move_along_path(delta):
		return
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = 0.5

	# Priorité 1 : manger.
	if hunger >= HUNGRY_LEVEL:
		var meal := map.find_food_job(current_cell())
		if not meal.is_empty():
			_food_cell = meal["target"]
			follow_path(meal["path"])
			state = State.GOING_TO_EAT
			return

	# Priorité 2 : dormir.
	if energy <= TIRED_LEVEL and _has_bed() and go_to(bed_cell):
		state = State.GOING_TO_SLEEP
		return

	# Sinon : se promener un peu.
	go_to(current_cell() + Vector2i(randi_range(-3, 3), randi_range(-3, 3)))
	_think_timer = randf_range(1.0, 3.0)


## Une fois par seconde, l'humeur monte ou descend selon les besoins.
func _update_mood(delta: float) -> void:
	_mood_timer += delta
	if _mood_timer < 1.0 or state == State.LEAVING:
		return
	_mood_timer = 0.0

	if not _has_bed():
		bed_cell = map.claim_bed(self) # Un lit s'est peut-être libéré.

	var change := 0.0
	if hunger >= 90.0:
		change -= 3.0
	if energy <= 5.0:
		change -= 3.0
	if not _has_bed():
		change -= 2.0
	if change == 0.0 and hunger < HUNGRY_LEVEL and energy > TIRED_LEVEL:
		change = 1.0
	happiness = clampf(happiness + change, 0.0, 100.0)

	if happiness <= 0.0:
		_start_leaving()


func _has_bed() -> bool:
	return bed_cell != NO_CELL and map.get_room(bed_cell) == Rooms.Type.LAIR \
			and map.beds.get(bed_cell) == self


func _start_leaving() -> void:
	state = State.LEAVING
	map.release_bed(self)
	bed_cell = NO_CELL
	if not go_to(map.portal_cell):
		_leave_now()


## Morte au combat : on libère son lit, puis Unit.die() fait le reste.
func die() -> void:
	map.release_bed(self)
	super()


func _leave_now() -> void:
	left_dungeon.emit(self)
	queue_free()


func _draw() -> void:
	var info := Creatures.info(type)
	var radius: float = info["size"]
	draw_circle(Vector2.ZERO, radius, info["color"])
	draw_circle(Vector2(-radius * 0.35, -radius * 0.2), 1.8, Color.BLACK)
	draw_circle(Vector2(radius * 0.35, -radius * 0.2), 1.8, Color.BLACK)

	# Barre d'humeur au-dessus de la tête : verte = contente, rouge = furieuse.
	var bar_width := 18.0
	var bar_y := -radius - 7.0
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, 3), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width * happiness / 100.0, 3),
			Color.RED.lerp(Color.GREEN, happiness / 100.0))

	draw_health_bar(bar_y - 4.0)
	draw_strike()

	var font := ThemeDB.fallback_font
	if state == State.SLEEPING:
		draw_string(font, Vector2(radius, -radius), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	elif state == State.LEAVING:
		draw_string(font, Vector2(radius, -radius), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.RED)

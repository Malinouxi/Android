class_name Creature
extends Unit
## Une créature venue par le portail. Elle a trois besoins :
##   - l'ÉNERGIE baisse avec le temps : elle va dormir dans son lit (Repaire) ;
##   - la FAIM monte : elle va manger un champignon (Champignonnière) ;
##   - le SALAIRE : main.gd la paie à chaque jour de paie.
## Si ses besoins ne sont pas satisfaits, son HUMEUR baisse.
## À 0, elle quitte le donjon par le portail.
## Et quand un héros approche, elle se bat pour défendre le donjon !
##
## Quand tout va bien, elle TRAVAILLE : elle étudie à la Bibliothèque, fabrique
## des pièges à l'Atelier ou s'entraîne. En combattant et en s'entraînant, elle
## gagne de l'EXPÉRIENCE et monte de NIVEAU (plus forte, mais mieux payée).

## Émis juste avant que la créature disparaisse par le portail.
signal left_dungeon(creature: Creature)
## Émis chaque seconde de travail à la Bibliothèque ou à l'Atelier (main.gd s'en occupe).
signal worked(room_type: int, amount: float)
## Émis quand la créature passe un niveau.
signal leveled_up(creature: Creature)
## Émis quand un Attrapeur dépose un prisonnier sur un autel (main.gd donne l'or).
signal sacrificed(hero: Hero)

## main.gd met à jour ces deux valeurs : y a-t-il encore quelque chose à
## chercher ou à fabriquer ? (« static » : partagées par toutes les créatures.)
static var research_needed := false
static var workshop_needed := false

enum State { WANDER, GOING_TO_SLEEP, SLEEPING, GOING_TO_EAT, EATING, LEAVING, FIGHTING,
		GOING_TO_WORK, WORKING, RAIDING, GOING_TO_CATCH, CARRYING }

const STATE_NAMES := {
	State.WANDER: "se promène",
	State.GOING_TO_SLEEP: "va se coucher",
	State.SLEEPING: "dort",
	State.GOING_TO_EAT: "va manger",
	State.EATING: "mange",
	State.LEAVING: "s'en va, furieuse",
	State.FIGHTING: "se bat",
	State.GOING_TO_WORK: "va travailler",
	State.RAIDING: "attaque le cœur rival",
	State.GOING_TO_CATCH: "va chercher un héros",
	State.CARRYING: "porte un héros",
	State.WORKING: "travaille",
}
const WORK_NAMES := {
	Rooms.Type.LIBRARY: "étudie",
	Rooms.Type.WORKSHOP: "fabrique des pièges",
	Rooms.Type.TRAINING: "s'entraîne",
	Rooms.Type.TEMPLE: "prie",
}

const MAX_LEVEL := 5
## Bonus par niveau au-dessus de 1 : +20 % de vie et de dégâts, +25 % de salaire.
const LEVEL_STAT_BONUS := 0.2
const LEVEL_SALARY_BONUS := 0.25
const TRAINING_XP := 5.0     ## Expérience gagnée par seconde d'entraînement.
const WORK_DURATION := 25.0  ## Durée maximale d'une séance de travail, en secondes.
const TEMPLE_HAPPINESS := 4.0 ## Humeur gagnée par seconde de prière.
const TEMPLE_HEAL := 3.0      ## Points de vie regagnés par seconde de prière.
const TEMPLE_MANA := 0.5      ## Mana donnée au maître par seconde de prière.

const ENERGY_LOSS := 1.2     ## Énergie perdue par seconde (100 -> 0 en ~80 s).
const ENERGY_GAIN := 12.0    ## Énergie regagnée par seconde en dormant.
const HUNGER_GAIN := 1.5     ## Faim gagnée par seconde (0 -> 100 en ~65 s).
const MEAL_VALUE := 60.0     ## Faim enlevée par un champignon.
const EAT_TIME := 1.5        ## Secondes pour manger.
const TIRED_LEVEL := 25.0    ## En dessous : elle va dormir.
const HUNGRY_LEVEL := 65.0   ## Au-dessus : elle va manger.
const HEAL_WHILE_SLEEPING := 5.0 ## Points de vie regagnés par seconde en dormant.
const AGGRO_RADIUS := 192.0  ## Distance (pixels) à laquelle elle repère un héros.
const RAID_RADIUS := 160.0   ## Distance à laquelle elle se jette sur le cœur rival.
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

var level := 1
## Expérience accumulée vers le prochain niveau.
var xp := 0.0
var _work_room: int = Rooms.Type.NONE
var _work_cell := NO_CELL
var _work_timer := 0.0
var _work_tick := 0.0


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
	load_abilities(info)
	if info.get("catcher", false):
		add_to_group("catchers") # Les héros vaincus peuvent alors tomber assommés (hero.gd).
	setup(dungeon_map, cell)
	energy = randf_range(60.0, 100.0)
	hunger = randf_range(0.0, 30.0)
	bed_cell = map.claim_bed(self)


## Expérience nécessaire pour passer au niveau suivant.
func xp_to_next_level() -> float:
	return 100.0 * level


func gain_xp(amount: float) -> void:
	if level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		_apply_level()
		leveled_up.emit(self)


## Recalcule la vie et les dégâts selon le niveau (en gardant le % de vie).
func _apply_level() -> void:
	var info := Creatures.info(type)
	var bonus := 1.0 + LEVEL_STAT_BONUS * (level - 1)
	var health_ratio := hp / max_hp
	max_hp = info["hp"] * bonus
	hp = max_hp * health_ratio
	attack_damage = info["damage"] * bonus


## Chaque coup porté rapporte autant d'expérience que de dégâts.
func _on_hit_landed(_target: Unit, damage_dealt: float) -> void:
	gain_xp(damage_dealt)
	# (Les capacités comme le ralentissement de l'araignée sont gérées par unit.gd.)


## Ce qu'il faut pour recréer la créature au chargement (voir main.gd).
func to_save() -> Dictionary:
	return {
		"type": type, "cell": SaveGame.cell_to_array(current_cell()), "hp": hp,
		"energy": energy, "hunger": hunger, "happiness": happiness,
		"level": level, "xp": xp,
	}


## Remet les valeurs sauvegardées (après setup_creature).
func load_save(data: Dictionary) -> void:
	level = int(data.get("level", 1))
	xp = float(data.get("xp", 0.0))
	_apply_level()
	hp = float(data["hp"])
	energy = float(data["energy"])
	hunger = float(data["hunger"])
	happiness = float(data["happiness"])


func display_name() -> String:
	return Creatures.info(type)["name"]


func salary() -> int:
	var base: int = Creatures.info(type)["salary"]
	return int(base * (1.0 + LEVEL_SALARY_BONUS * (level - 1)))


func is_leaving() -> bool:
	return state == State.LEAVING


## Appelée par main.gd au jour de paie.
func receive_pay(paid: bool) -> void:
	happiness = clampf(happiness + (15.0 if paid else -35.0), 0.0, 100.0)


## Petit texte affiché quand on touche la créature.
func describe() -> String:
	var activity: String = STATE_NAMES[state]
	if state == State.WORKING:
		activity = WORK_NAMES[_work_room]
	elif state == State.WANDER and _guarded_room() != Rooms.Type.NONE:
		activity = "garde le %s" % Rooms.display_name(_guarded_room())
	return "%s niv. %d (%s) : vie %d/%d, humeur %d%%, faim %d%%, énergie %d%%, salaire %d or%s" % [
		display_name(), level, activity, hp, max_hp, happiness, hunger, energy, salary(),
		"" if _has_bed() else ", SANS LIT !"]


func _process(delta: float) -> void:
	if state != State.SLEEPING:
		energy = maxf(0.0, energy - ENERGY_LOSS * delta)
	if state != State.EATING:
		hunger = minf(100.0, hunger + HUNGER_GAIN * delta)
	_update_mood(delta)
	update_attack_cooldown(delta)
	update_effects(delta)
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
			if not is_instance_valid(_enemy) or not fight(_enemy, delta):
				_enemy = null
				state = State.WANDER
		State.GOING_TO_WORK:
			if map.get_room(_work_cell) != _work_room:
				_stop_work()
			elif move_along_path(delta):
				state = State.WORKING
				_work_timer = WORK_DURATION
				_work_tick = 0.0
		State.WORKING:
			_process_working(delta)
		State.RAIDING:
			_process_raiding(delta)
		State.GOING_TO_CATCH:
			_process_going_to_catch(delta)
		State.CARRYING:
			_process_carrying(delta)
	queue_redraw()


# ---------------------------------------------------------------------------
# L'Attrapeur de cauchemar
# ---------------------------------------------------------------------------
## 1. Il cherche un héros assommé (ou un prisonnier à sacrifier) que personne ne
##    vient déjà chercher, et y va (GOING_TO_CATCH).
## 2. Il le soulève et le porte (CARRYING) vers une cellule de Prison libre...
##    ou vers un autel de sacrifice.
## 3. Arrivé : le héros est enfermé (rançon), ou sacrifié (signal sacrificed).

var _catch_target: Hero = null
var _carry_destination := NO_CELL
var _carry_to_altar := false


func is_catcher() -> bool:
	return Creatures.info(type).get("catcher", false)


## Choisit un héros à aller chercher. Renvoie false s'il n'y a rien à faire.
func _start_catch() -> bool:
	var best: Hero = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("knocked_out"):
		var hero := node as Hero
		if hero != null and _is_free_to_catch(hero) and position.distance_to(hero.position) < best_distance:
			best = hero
			best_distance = position.distance_to(hero.position)
	# Pas de héros assommé : un prisonnier à conduire à l'autel ?
	if best == null and not map.altar_cells().is_empty():
		for node in get_tree().get_nodes_in_group("prisoners"):
			var hero := node as Hero
			if hero != null and hero.sacrifice_requested and _is_free_to_catch(hero):
				best = hero
				break
	if best == null or not go_to(best.current_cell()):
		return false
	best.reserved_by = self
	_catch_target = best
	state = State.GOING_TO_CATCH
	return true


func _is_free_to_catch(hero: Hero) -> bool:
	return hero.carrier == null and (hero.reserved_by == null or not is_instance_valid(hero.reserved_by)
			or hero.reserved_by == self)


func _process_going_to_catch(delta: float) -> void:
	if not is_instance_valid(_catch_target) or _catch_target.carrier != null \
			or _catch_target.reserved_by != self:
		_stop_catch()
		return
	if move_along_path(delta) or position.distance_to(_catch_target.position) < 12.0:
		_pick_up_target()


## Soulève le héros, et choisit où le porter.
func _pick_up_target() -> void:
	var hero := _catch_target
	_carry_to_altar = hero.is_captured() and hero.sacrifice_requested
	var destination := NO_CELL
	if _carry_to_altar:
		var best_length := 1000000
		for cell in map.altar_cells():
			var route := map.find_path(current_cell(), cell)
			if not route.is_empty() and route.size() < best_length:
				best_length = route.size()
				destination = cell
	else:
		destination = map.find_free_prison_cell()
		if destination != NO_CELL:
			map.prisoners[destination] = hero # On réserve la cellule.
	if destination == NO_CELL:
		_stop_catch()
		return
	hero.lift(self)
	if not go_to(destination):
		_drop_carried()
		return
	_carry_destination = destination
	state = State.CARRYING
	Sound.play("pickup", position)


func _process_carrying(delta: float) -> void:
	if not is_instance_valid(_catch_target):
		_stop_catch()
		return
	# La destination existe-t-elle encore (cellule démolie, autel retiré) ?
	var still_valid := false
	if _carry_to_altar:
		still_valid = map.defenses.has(_carry_destination) \
				and map.defenses[_carry_destination]["type"] == Defenses.Type.ALTAR
	else:
		still_valid = map.get_room(_carry_destination) == Rooms.Type.PRISON
	if not still_valid:
		_drop_carried()
		return
	if move_along_path(delta):
		_deliver()


func _deliver() -> void:
	var hero := _catch_target
	if _carry_to_altar:
		hero.carrier = null
		sacrificed.emit(hero) # main.gd donne l'or et joue les effets.
		hero.no_ransom = true
		hero.kill()
	else:
		map.prisoners.erase(_carry_destination) # La réservation devient un vrai prisonnier :
		hero.capture_at(_carry_destination)
		hero.captured.emit(hero) # main.gd donne la rançon.
		Sound.play("capture", position)
	gain_xp(20.0)
	_catch_target = null
	_carry_destination = NO_CELL
	state = State.WANDER


## Lâche le héros porté (l'Attrapeur meurt, est ramassé, ou la destination a disparu).
func _drop_carried() -> void:
	if is_instance_valid(_catch_target) and _catch_target.carrier == self:
		if not _carry_to_altar and map.prisoners.get(_carry_destination) == _catch_target:
			map.prisoners.erase(_carry_destination)
		_catch_target.put_down()
	_stop_catch()


func _stop_catch() -> void:
	if is_instance_valid(_catch_target) and _catch_target.reserved_by == self:
		_catch_target.reserved_by = null
	_catch_target = null
	_carry_destination = NO_CELL
	if state == State.GOING_TO_CATCH or state == State.CARRYING:
		state = State.WANDER


## Attaque du cœur rival : on se place à côté, puis on frappe.
func _process_raiding(delta: float) -> void:
	if not map.has_rival or map.rival_heart_hp <= 0.0:
		state = State.WANDER
		return
	var heart_position := map.cell_to_world(map.rival_heart_cell)
	if position.distance_to(heart_position) <= attack_range + 16.0:
		path.clear()
		if _attack_cooldown <= 0.0:
			_attack_cooldown = attack_interval
			show_strike(heart_position)
			map.damage_rival_heart(attack_damage)
			gain_xp(attack_damage)
		return
	if path.is_empty():
		# On cherche une case libre à côté du cœur.
		for direction in DungeonMap.DIRECTIONS:
			if go_to(map.rival_heart_cell + direction):
				break
		if path.is_empty():
			state = State.WANDER # Inaccessible.
			return
	move_along_path(delta)


## Au travail : chaque seconde, un peu d'expérience, de recherche ou de fabrication.
func _process_working(delta: float) -> void:
	if map.get_room(_work_cell) != _work_room:
		_stop_work()
		return
	_work_timer -= delta
	_work_tick += delta
	if _work_tick >= 1.0:
		_work_tick -= 1.0
		match _work_room:
			Rooms.Type.TRAINING:
				gain_xp(TRAINING_XP)
				energy = maxf(0.0, energy - ENERGY_LOSS) # L'entraînement fatigue deux fois plus.
			Rooms.Type.LIBRARY:
				# Les Sorciers étudient 3 fois plus vite.
				worked.emit(_work_room, 3.0 if type == Creatures.Type.WARLOCK else 1.0)
			Rooms.Type.WORKSHOP:
				# Les Orques sont les meilleurs artisans.
				worked.emit(_work_room, 3.0 if type == Creatures.Type.ORC else 2.0)
			Rooms.Type.TEMPLE:
				# Prier rend heureux, soigne, et donne un peu de mana au maître.
				happiness = minf(100.0, happiness + TEMPLE_HAPPINESS)
				heal(TEMPLE_HEAL)
				worked.emit(_work_room, TEMPLE_MANA)
	var stop_training := _work_room == Rooms.Type.TRAINING and level >= MAX_LEVEL
	var stop_research := _work_room == Rooms.Type.LIBRARY and not research_needed
	var stop_workshop := _work_room == Rooms.Type.WORKSHOP and not workshop_needed
	if _work_timer <= 0.0 or hunger >= HUNGRY_LEVEL or energy <= TIRED_LEVEL \
			or stop_training or stop_research or stop_workshop:
		_stop_work()


## Choisit un travail utile et part vers un poste libre. Renvoie false si rien à faire.
func _start_work() -> bool:
	if _guarded_room() != Rooms.Type.NONE:
		return false # Un gardien ne quitte pas son poste pour travailler.
	var options: Array[int] = []
	if research_needed and map.count_room_tiles(Rooms.Type.LIBRARY) > 0:
		options.append(Rooms.Type.LIBRARY)
		if type == Creatures.Type.WARLOCK:
			options.append_array([Rooms.Type.LIBRARY, Rooms.Type.LIBRARY]) # Il adore étudier.
	if workshop_needed and type != Creatures.Type.WARLOCK and map.count_room_tiles(Rooms.Type.WORKSHOP) > 0:
		options.append(Rooms.Type.WORKSHOP)
	if level < MAX_LEVEL and map.count_room_tiles(Rooms.Type.TRAINING) > 0:
		options.append(Rooms.Type.TRAINING)
	if map.count_room_tiles(Rooms.Type.TEMPLE) > 0:
		options.append(Rooms.Type.TEMPLE)
		if happiness < 60.0:
			options.append_array([Rooms.Type.TEMPLE, Rooms.Type.TEMPLE]) # Mécontente : elle va prier.
	if options.is_empty():
		return false
	var room: int = options.pick_random()
	var spot := map.find_work_spot(self, room, current_cell())
	if spot.is_empty():
		return false
	_work_room = room
	_work_cell = spot["target"]
	follow_path(spot["path"])
	state = State.GOING_TO_WORK
	return true


func _stop_work() -> void:
	map.release_work_spot(self)
	_work_room = Rooms.Type.NONE
	_work_cell = NO_CELL
	if state == State.GOING_TO_WORK or state == State.WORKING:
		state = State.WANDER


## Trois fois par seconde : y a-t-il un héros à combattre ?
func _update_combat(delta: float) -> void:
	# (Un Attrapeur en mission ne se laisse pas distraire par les combats.)
	if state == State.LEAVING or state == State.GOING_TO_CATCH or state == State.CARRYING:
		return
	_combat_timer -= delta
	if _combat_timer > 0.0:
		return
	_combat_timer = 0.3
	# Une créature endormie ne remarque que les héros tout proches.
	var radius := WAKE_RADIUS if state == State.SLEEPING else AGGRO_RADIUS
	var enemy := find_nearest_enemy(radius)
	if enemy == null:
		# Personne à combattre, mais le cœur du rival est tout près : à l'attaque !
		if state == State.WANDER and map.has_rival and map.rival_heart_hp > 0.0 \
				and position.distance_to(map.cell_to_world(map.rival_heart_cell)) <= RAID_RADIUS:
			path.clear()
			state = State.RAIDING
		return
	if state != State.FIGHTING:
		map.release_work_spot(self)
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

	# Priorité 0 (Attrapeurs) : ramasser les héros assommés, conduire les sacrifiés.
	if is_catcher() and _start_catch():
		return

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

	# Priorité 3 : travailler (si elle n'a ni faim ni sommeil).
	if energy > TIRED_LEVEL + 15.0 and hunger < HUNGRY_LEVEL and _start_work():
		return

	# Un gardien (le Cerbère) rôde dans la salle qu'il garde.
	if _patrol():
		_think_timer = randf_range(1.5, 3.5)
		return

	# Sinon : se promener un peu.
	go_to(current_cell() + Vector2i(randi_range(-3, 3), randi_range(-3, 3)))
	_think_timer = randf_range(1.0, 3.0)


## La salle que garde cette créature (Rooms.Type.NONE si ce n'est pas un gardien).
func _guarded_room() -> int:
	return Creatures.info(type).get("guard", Rooms.Type.NONE)


## Le gardien va vers une case de sa salle, choisie au hasard parmi les plus
## proches (il reste près de l'endroit où on l'a posé). Renvoie false sans salle.
func _patrol() -> bool:
	var room := _guarded_room()
	if room == Rooms.Type.NONE:
		return false
	var cells: Array[Vector2i] = []
	for cell: Vector2i in map.rooms:
		if map.rooms[cell] == room:
			cells.append(cell)
	if cells.is_empty():
		return false
	var here := current_cell()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - here).length_squared() < (b - here).length_squared())
	var nearest := cells.slice(0, 8)
	for attempt in 3:
		if go_to(nearest.pick_random()):
			return true
	return false


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
	_drop_carried()
	map.release_work_spot(self)
	state = State.LEAVING
	map.release_bed(self)
	bed_cell = NO_CELL
	if not go_to(map.portal_cell):
		_leave_now()


## On ne peut pas retenir une créature qui a décidé de partir !
func can_be_picked_up() -> bool:
	return super() and state != State.LEAVING


func _on_picked_up() -> void:
	_drop_carried()
	_enemy = null
	map.release_work_spot(self)
	state = State.WANDER


## Morte au combat : on libère son lit, puis Unit.die() fait le reste.
func die() -> void:
	_drop_carried()
	map.release_bed(self)
	map.release_work_spot(self)
	super()


func _leave_now() -> void:
	left_dungeon.emit(self)
	queue_free()


func _draw() -> void:
	var info := Creatures.info(type)
	var sprite_scale: float = info["size"] / 8.0 # Taille 8 = image normale (32 pixels).
	draw_sprite(info["sprite"], sprite_scale)
	var radius := 14.0 * sprite_scale

	# Barre d'humeur au-dessus de la tête : verte = contente, rouge = furieuse.
	var bar_width := 18.0
	var bar_y := -radius - 6.0
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width, 3), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-bar_width / 2, bar_y, bar_width * happiness / 100.0, 3),
			Color.RED.lerp(Color.GREEN, happiness / 100.0))

	draw_health_bar(bar_y - 4.0)
	draw_strike()

	var font := ThemeDB.fallback_font
	# Le niveau, en petit à gauche des barres.
	draw_string(font, Vector2(-bar_width / 2 - 9, bar_y + 3), str(level), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 10, Color("ffd54a"))
	if state == State.SLEEPING:
		draw_string(font, Vector2(radius, -radius), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	elif state == State.LEAVING:
		draw_string(font, Vector2(radius, -radius), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.RED)

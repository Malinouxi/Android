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
## Vaincu, il tombe ASSOMMÉ si tu as un Attrapeur de cauchemar et une cellule de
## Prison libre : un Attrapeur vient le chercher et le porte en prison (voir
## creature.gd). Personne n'est venu au bout de Rules.CAPTURE_WINDOW secondes ?
## Il meurt. Sans Attrapeur ou sans cellule libre, il meurt tout de suite.
## Le Clerc soigne régulièrement les héros autour de lui.
##
## Certains héros ont une MISSION au lieu de foncer sur le cœur (voir plus bas) :
##   - la Voleuse se faufile jusqu'au Trésor, vole de l'or et s'enfuit par l'entrée ;
##   - le Moine libérateur va à la Prison et ouvre les cellules.
## En mission, ils ne se battent que si un ennemi est tout près d'eux.

## Émis quand le héros arrive en prison.
signal captured(hero: Hero)
## Émis quand le héros tombe assommé.
signal fell(hero: Hero)
## Émis quand la Voleuse vole de l'or dans un coffre.
signal stole(hero: Hero, amount: int)
## Émis quand la Voleuse sort du donjon avec son butin (il est perdu).
signal escaped(hero: Hero, amount: int)
## Émis quand le Moine ouvre une cellule.
signal freed_prisoner(hero: Hero)
## Émis quand le gardien (le Colosse) se réveille, ou se rendort.
signal guardian_woke(hero: Hero)
signal guardian_slept(hero: Hero)
## Émis quand le héros, gravement blessé, commence à battre en retraite.
signal started_fleeing(hero: Hero)
## Émis quand le héros sort VIVANT par l'entrée (fuite, ou Voleuse avec son butin) :
## il reviendra plus tard en vétéran (voir nemeses.gd).
signal retreated(hero: Hero)

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
var _war_cry_timer := 3.0

## Or volé que porte la Voleuse. Abattue, elle lâche son sac (voir die()).
var loot := 0
const NO_CELL := Vector2i(-1, -1)
var _mission_cell := NO_CELL
var _mission_timer := 0.0
var _prisoner_target: Hero = null
## Temps restant au Moine pour ouvrir la cellule (négatif : il n'ouvre rien).
var _unlock_left := -1.0

## Assommé au sol, en attente d'un Attrapeur.
var knocked_out := false
var _knocked_out_timer := 0.0
## L'Attrapeur qui le porte en ce moment (ou null).
var carrier: Node2D = null
## L'Attrapeur qui vient le chercher (pour que deux Attrapeurs n'y aillent pas ensemble).
var reserved_by: Node = null
## Le joueur a demandé de sacrifier ce prisonnier (outil Sacrifier).
var sacrifice_requested := false
## Vrai s'il a été sacrifié : sa rançon a déjà été payée, on ne la redonne pas à sa mort.
var no_ransom := false
var _dying := false

## LA RETRAITE ET LES VÉTÉRANS (voir nemeses.gd).
## Vrai quand il bat en retraite vers l'entrée (sous Rules.HERO_FLEE_BELOW de sa vie).
var fleeing := false
## Sa fiche de vétéran s'il est déjà revenu (vide sinon).
var nemesis: Dictionary = {}
## Les pièges qui l'ont blessé : case -> true. Il s'en souvient s'il s'échappe.
var known_traps: Dictionary = {}
## Les pièges qu'il connaissait EN ARRIVANT (vétéran) : case -> true.
var _veteran_traps: Dictionary = {}
## Le GARDIEN des profondeurs (le Colosse) ne quitte pas sa caverne : sa case.
var home_cell := Vector2i(-1, -1)
## Le gardien est-il réveillé ? Endormi, il n'attaque personne et tes créatures
## l'ignorent. Il se réveille sur ordre du maître (assaut), ou s'il est blessé.
var awake := false
var _calm_left := 0.0
## Dégâts reçus de chaque espèce de créature : Creatures.Type -> dégâts.
var _damage_by_species: Dictionary = {}


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
	if info.get("stealth", false):
		self_modulate.a = 0.55 # La Voleuse, discrète, est à moitié transparente.
	if info.has("tint"):
		self_modulate = info["tint"] # Les habitants des profondeurs ont leur propre teinte.
	if info.has("alpha"):
		self_modulate.a = info["alpha"]
	setup(dungeon_map, cell)
	home_cell = cell


func to_save() -> Dictionary:
	var data := {"type": type, "cell": SaveGame.cell_to_array(current_cell()), "hp": hp, "loot": loot}
	if not nemesis.is_empty():
		data["nemesis"] = nemesis
	if fleeing:
		data["fleeing"] = true
	if is_guardian():
		data["home"] = SaveGame.cell_to_array(home_cell)
		data["awake"] = awake
		data["assault"] = Creature.assault_target == self
	if not known_traps.is_empty():
		var traps := []
		for cell: Vector2i in known_traps:
			traps.append(SaveGame.cell_to_array(cell))
		data["known_traps"] = traps
	if is_captured():
		data["prison"] = SaveGame.cell_to_array(prison_cell)
		data["sacrifice"] = sacrifice_requested
	elif knocked_out or carrier != null:
		# Porté par un Attrapeur au moment de la sauvegarde : on le retrouvera assommé.
		data["knocked_out"] = _knocked_out_timer if knocked_out else Rules.CAPTURE_WINDOW * 0.5
	return data


func is_captured() -> bool:
	return prison_cell != Vector2i(-1, -1)


## Vaincu : assommé si un Attrapeur peut l'emmener en prison, sinon il meurt vraiment.
func die() -> void:
	if loot > 0:
		# La Voleuse lâche son sac : tes ouvriers viendront le rapporter au Trésor.
		map.drop_gold(current_cell(), loot)
		Fx.burst("coins", position)
		loot = 0
	if not _dying and not is_captured() and not knocked_out and carrier == null \
			and not Heroes.info(type).get("no_capture", false):
		var catchers := get_tree().get_nodes_in_group("catchers")
		if not catchers.is_empty() and map.find_free_prison_cell() != Vector2i(-1, -1):
			fall_down(Rules.CAPTURE_WINDOW)
			Sound.play("death", position, -6.0)
			fell.emit(self)
			return
	super()


## Tue le héros pour de bon (personne n'est venu le chercher, ou il a été sacrifié).
func kill() -> void:
	_dying = true
	hp = 0.0
	knocked_out = false
	carrier = null
	remove_from_group("knocked_out")
	remove_from_group("prisoners")
	if map.prisoners.get(prison_cell) == self:
		map.prisoners.erase(prison_cell)
	die()


## Tombe assommé au sol pendant `seconds` secondes.
func fall_down(seconds: float) -> void:
	knocked_out = true
	_knocked_out_timer = seconds
	carrier = null
	reserved_by = null
	sacrifice_requested = false
	hp = max_hp * 0.3
	remove_from_group(_group_name(team))
	remove_from_group("prisoners")
	add_to_group("knocked_out")
	path.clear()
	_target = null
	z_index = Iso.depth_z(position, DungeonMap.TILE_SIZE)


## Un Attrapeur le soulève (depuis le sol ou depuis sa cellule de prison).
func lift(catcher: Node2D) -> void:
	carrier = catcher
	reserved_by = catcher
	knocked_out = false
	remove_from_group("knocked_out")
	if is_captured():
		if map.prisoners.get(prison_cell) == self:
			map.prisoners.erase(prison_cell)
		prison_cell = Vector2i(-1, -1)
		remove_from_group("prisoners")


## L'Attrapeur l'a lâché en chemin : il retombe assommé (un autre viendra peut-être).
func put_down() -> void:
	fall_down(Rules.CAPTURE_WINDOW * 0.5)


## Enferme le héros dans une cellule : il ne bouge plus et n'est plus un ennemi actif.
func capture_at(cell: Vector2i) -> void:
	knocked_out = false
	carrier = null
	reserved_by = null
	remove_from_group("knocked_out")
	prison_cell = cell
	map.prisoners[cell] = self
	hp = max_hp * 0.3
	remove_from_group(_group_name(team))
	add_to_group("prisoners")
	position = map.cell_to_world(cell)
	z_index = Iso.depth_z(position, DungeonMap.TILE_SIZE)
	path.clear()
	_target = null


## Libéré par un Moine : il sort de sa cellule et reprend le combat.
func release() -> void:
	sacrifice_requested = false
	reserved_by = null # Un Attrapeur qui venait le chercher abandonne.
	_escape()
	hp = maxf(hp, max_hp * 0.6)


## La cellule a été démolie : le prisonnier s'évade et redevient un héros actif.
func _escape() -> void:
	if map.prisoners.get(prison_cell) == self:
		map.prisoners.erase(prison_cell)
	prison_cell = Vector2i(-1, -1)
	remove_from_group("prisoners")
	add_to_group(_group_name(team))


func display_name() -> String:
	if not nemesis.is_empty():
		return Nemeses.title(nemesis)
	return Heroes.info(type)["name"]


func reward() -> int:
	return int(Heroes.info(type)["reward"] * (1.0 + Rules.NEMESIS_REWARD_BONUS * rank()))


# ---------------------------------------------------------------------------
# Les vétérans et la retraite
# ---------------------------------------------------------------------------

## Son rang de vétéran (0 : un héros ordinaire).
func rank() -> int:
	return int(nemesis.get("rank", 0))


func is_veteran() -> bool:
	return not nemesis.is_empty()


## Fait de ce héros un vétéran qui revient (fiche de nemeses.gd) : plus fort, et
## il se souvient des pièges qui l'ont blessé.
func apply_nemesis(entry: Dictionary) -> void:
	nemesis = entry.duplicate(true)
	var info := Heroes.info(type)
	max_hp = info["hp"] * (1.0 + Rules.NEMESIS_HP_BONUS * rank())
	hp = max_hp
	attack_damage = info["damage"] * (1.0 + Rules.NEMESIS_DAMAGE_BONUS * rank())
	for values in nemesis.get("traps", []):
		var cell := SaveGame.array_to_cell(values)
		known_traps[cell] = true
		_veteran_traps[cell] = true


## L'espèce de créature qui l'a le plus abîmé (-1 si aucune).
func worst_enemy_species() -> int:
	var best := -1
	for species: int in _damage_by_species:
		if best < 0 or _damage_by_species[species] > _damage_by_species[best]:
			best = species
	return best


## Rancune : il frappe plus fort l'espèce qui l'a le plus abîmé la dernière fois.
func damage_against(target: Unit) -> float:
	var grudge := int(nemesis.get("grudge", -1))
	if grudge >= 0 and target is Creature and (target as Creature).type == grudge:
		return attack_damage * Rules.NEMESIS_GRUDGE_DAMAGE
	return attack_damage


func _on_damaged(source: Unit, amount: float) -> void:
	if source is Creature:
		var species := (source as Creature).type
		_damage_by_species[species] = _damage_by_species.get(species, 0.0) + amount


## Un piège l'a blessé : il s'en souviendra.
func remember_trap(cell: Vector2i) -> void:
	known_traps[cell] = true


## Vrai s'il connaît ce piège depuis une vague précédente (il lui fait moins mal).
func knows_trap(cell: Vector2i) -> bool:
	return _veteran_traps.has(cell)


## Les pièges qu'il évite en cherchant son chemin (ceux qu'il connaissait en arrivant).
func _avoided_traps() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_veteran_traps.keys())
	return result


## Le Champion et les troupes du rival ne fuient jamais ; les autres oui.
func _can_flee() -> bool:
	var info := Heroes.info(type)
	return not info.get("boss", false) and not info.get("rival", false) and not info.get("fearless", false)


## Un gardien des profondeurs (le Colosse endormi) : neutre, il défend sa caverne.
func is_guardian() -> bool:
	return Heroes.info(type).get("guardian", false)


## Le Colosse endormi n'est pas une cible pour tes créatures, sauf pendant un
## assaut ordonné par le maître (Creature.assault_target).
func ignored_as_enemy() -> bool:
	return is_guardian() and Creature.assault_target != self


## Réveille le gardien (assaut du maître, sort, piège...).
func wake_up() -> void:
	if awake:
		return
	awake = true
	_calm_left = Rules.GUARDIAN_CALM_TIME
	Sound.play("horn", position, -6.0)
	Fx.burst("dust", position)
	Fx.shake(3.0, 0.3)
	guardian_woke.emit(self)


## Un gardien endormi qu'on blesse (sort, piège) se réveille.
func take_damage(amount: float, source: Unit = null) -> void:
	if is_guardian() and not awake and not is_dead():
		wake_up()
	super(amount, source)


## Le gardien : endormi, il se repose dans sa caverne. Réveillé, il frappe ce qui
## s'approche, ne poursuit pas plus loin que Rules.GUARDIAN_RADIUS, et se rendort
## quand il ne voit plus personne pendant Rules.GUARDIAN_CALM_TIME secondes.
func _guard(delta: float) -> void:
	var home := map.cell_to_world(home_cell)
	if not awake:
		_target = null
		if current_cell() == home_cell:
			path.clear()
			heal(Rules.GUARDIAN_REGEN * delta)
		elif path.is_empty():
			go_to(home_cell)
		else:
			move_along_path(delta)
		return
	if _target != null and (not is_instance_valid(_target) or not _target.is_targetable() \
			or _target.position.distance_to(home) > Rules.GUARDIAN_RADIUS + 16.0):
		_target = null
		path.clear()
	_think_timer -= delta
	if _target == null and _think_timer <= 0.0:
		_think_timer = 0.3
		var best_distance := Rules.GUARDIAN_RADIUS
		for node in get_tree().get_nodes_in_group("dungeon"):
			var unit := node as Unit
			if unit != null and unit.is_targetable() and unit.position.distance_to(home) <= best_distance:
				best_distance = unit.position.distance_to(home)
				_target = unit
		if _target != null:
			path.clear()
	if _target != null:
		_calm_left = Rules.GUARDIAN_CALM_TIME
		if not fight(_target, delta):
			_target = null
			path.clear()
		return
	# Plus personne en vue : au bout d'un moment, il se rendort.
	_calm_left -= delta
	if _calm_left <= 0.0 and Creature.assault_target != self:
		awake = false
		guardian_slept.emit(self)
		return
	# Personne : il rentre dans sa caverne et s'y repose.
	if current_cell() != home_cell:
		if path.is_empty() and not go_to(home_cell):
			return
		move_along_path(delta)
	else:
		path.clear()
		heal(Rules.GUARDIAN_REGEN * delta)


## Gravement blessé : il bat en retraite vers l'entrée grise.
func start_fleeing(announce := true) -> void:
	if fleeing:
		return
	fleeing = true
	_target = null
	_unlock_left = -1.0
	_prisoner_target = null
	path.clear()
	_mission_cell = NO_CELL
	speed = Heroes.info(type)["speed"] * Rules.HERO_FLEE_SPEED
	if announce:
		Fx.burst("sparks", position, Color("ffffff"))
		started_fleeing.emit(self)


## La fuite : vers l'entrée, en creusant s'il le faut. Acculé (aucun chemin),
## il se bat là où il est.
func _flee(delta: float) -> void:
	if current_cell() == map.entrance_cell:
		_leave_alive()
		return
	if path.is_empty() or _mission_cell != map.entrance_cell:
		_mission_cell = map.entrance_cell
		follow_path(map.find_hero_path_to(current_cell(), map.entrance_cell, _avoided_traps()))
		if path.is_empty():
			_mission_cell = NO_CELL
			var enemy := find_nearest_enemy(Rules.MISSION_AGGRO_RADIUS)
			if enemy != null:
				fight(enemy, delta)
			return
	_walk_or_dig(delta)


## Il sort vivant du donjon : il reviendra (main.gd le note dans le registre des vétérans).
func _leave_alive() -> void:
	retreated.emit(self)
	remove_from_group(_group_name(team))
	Fx.burst("smoke", position, Color(0.5, 0.5, 0.6, 0.6))
	queue_free()


func _process(delta: float) -> void:
	# Porté par un Attrapeur : il suit son porteur.
	if carrier != null:
		if not is_instance_valid(carrier):
			put_down()
		else:
			position = carrier.position
			z_index = carrier.z_index + 1
		queue_redraw()
		return
	# Assommé : il attend, puis meurt si personne n'est venu.
	if knocked_out:
		_knocked_out_timer -= delta
		if _knocked_out_timer <= 0.0:
			kill()
		queue_redraw()
		return
	if is_captured():
		if map.get_room(prison_cell) != Rooms.Type.PRISON:
			_escape()
		queue_redraw()
		return
	update_attack_cooldown(delta)
	update_effects(delta)
	if type == Heroes.Type.CLERIC:
		_cleric_heal(delta)
	elif type == Heroes.Type.CHAMPION:
		_war_cry(delta)

	if is_guardian():
		_guard(delta)
		queue_redraw()
		return

	# Si notre cible a disparu (morte entre-temps), on l'oublie.
	if _target != null and not is_instance_valid(_target):
		_target = null

	# Gravement blessé : il bat en retraite (et ne s'arrête plus pour se battre).
	if not fleeing and _can_flee() and hp < max_hp * Rules.HERO_FLEE_BELOW:
		start_fleeing()

	# Trois fois par seconde, on regarde s'il y a un ennemi à proximité.
	_think_timer -= delta
	if not fleeing and _think_timer <= 0.0:
		_think_timer = 0.3
		var radius := Rules.MISSION_AGGRO_RADIUS if _has_mission() else AGGRO_RADIUS
		var enemy := find_nearest_enemy(radius)
		if enemy != _target:
			_target = enemy
			path.clear()

	if fleeing:
		_flee(delta)
	elif _target != null:
		_unlock_left = -1.0
		if not fight(_target, delta):
			_target = null
			path.clear()
	elif not _do_mission(delta):
		_march(delta)

	# Une porte nous barre la route (en marchant ou en poursuivant) : on la frappe.
	if _door_cell != Vector2i(-1, -1):
		_attack_door(_door_cell)
		_door_cell = Vector2i(-1, -1)
	queue_redraw()


# ---------------------------------------------------------------------------
# Les missions : la Voleuse et le Moine libérateur
# ---------------------------------------------------------------------------

func _has_mission() -> bool:
	var info := Heroes.info(type)
	return info.get("stealth", false) or info.get("liberator", false)


## Fait avancer la mission. Renvoie false s'il n'y a rien à faire : le héros
## marche alors vers le cœur, comme les autres.
func _do_mission(delta: float) -> bool:
	var info := Heroes.info(type)
	if info.get("stealth", false):
		return _thief_mission(delta)
	if info.get("liberator", false):
		return _liberator_mission(delta)
	return false


## La Voleuse : vers le coffre plein le plus proche, puis vers la sortie avec le butin.
func _thief_mission(delta: float) -> bool:
	if loot > 0:
		if current_cell() == map.entrance_cell:
			_run_away()
			return true
		if path.is_empty() or _mission_cell != map.entrance_cell:
			_mission_cell = map.entrance_cell
			follow_path(map.find_path(current_cell(), map.entrance_cell))
			if path.is_empty():
				return false # Sortie bouchée : elle se fraie un chemin vers le cœur.
		move_along_path(delta)
		return true

	# Un coffre à piller ? (On ne cherche que deux fois par seconde.)
	if _mission_cell == NO_CELL or map.get_room(_mission_cell) != Rooms.Type.TREASURY:
		_mission_timer -= delta
		if _mission_timer > 0.0:
			return false
		_mission_timer = 0.5
		var job := map.find_loot_job(current_cell())
		if job.is_empty():
			_mission_cell = NO_CELL
			return false
		_mission_cell = job["target"]
		follow_path(job["path"])
	if not move_along_path(delta):
		return true
	# Arrivée au coffre : elle le pille.
	loot = map.steal_gold(_mission_cell, Rules.THIEF_LOOT)
	_mission_cell = NO_CELL
	if loot > 0:
		play_attack()
		Sound.play("coins", position)
		Fx.burst("coins", position)
		stole.emit(self, loot)
	return true


## La Voleuse sort par l'entrée : le butin est perdu pour toi.
func _run_away() -> void:
	escaped.emit(self, loot)
	loot = 0
	_leave_alive()


## Le Moine : vers le prisonnier le plus proche, puis il ouvre sa cellule.
func _liberator_mission(delta: float) -> bool:
	if _prisoner_target == null or not is_instance_valid(_prisoner_target) \
			or not _prisoner_target.is_captured():
		_prisoner_target = null
		_unlock_left = -1.0
		_mission_timer -= delta
		if _mission_timer > 0.0:
			return false
		_mission_timer = 0.5
		var best_distance := INF
		for node in get_tree().get_nodes_in_group("prisoners"):
			var prisoner := node as Hero
			if prisoner != null and prisoner.is_captured() \
					and position.distance_to(prisoner.position) < best_distance:
				best_distance = position.distance_to(prisoner.position)
				_prisoner_target = prisoner
		if _prisoner_target == null:
			return false
		path.clear()

	var prisoner := _prisoner_target
	if position.distance_to(prisoner.position) > 20.0:
		if path.is_empty():
			# Sa priorité : la Prison. Pas de couloir ? Il CREUSE droit vers elle.
			follow_path(map.find_hero_path_to(current_cell(), prisoner.prison_cell))
			if path.is_empty():
				_prisoner_target = null # Vraiment inaccessible (de la roche partout).
				return false
		_walk_or_dig(delta)
		return true

	# Devant la cellule : il crochète la serrure.
	path.clear()
	if _unlock_left < 0.0:
		_unlock_left = Rules.UNLOCK_TIME
	_unlock_left -= delta
	if _unlock_left <= 0.0:
		_unlock_left = -1.0
		prisoner.release()
		Sound.play("door_break", position, -4.0)
		Fx.burst("dust", prisoner.position)
		freed_prisoner.emit(prisoner)
		_prisoner_target = null
	return true


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


## Le cri de guerre du Champion : les héros autour de lui (lui compris) courent plus vite.
func _war_cry(delta: float) -> void:
	_war_cry_timer -= delta
	if _war_cry_timer > 0.0:
		return
	_war_cry_timer = Heroes.WAR_CRY_INTERVAL
	for node in get_tree().get_nodes_in_group("heroes"):
		var ally := node as Unit
		if ally != null and ally.position.distance_to(position) <= Heroes.WAR_CRY_RADIUS:
			ally.apply_haste(Heroes.WAR_CRY_DURATION)
	play_attack() # Il lève son épée.
	map.add_effect(position, Heroes.WAR_CRY_RADIUS, Color(1.0, 0.85, 0.3, 0.35))
	Fx.burst("sparks", position, Color("ffd54a"))
	Fx.flash_light(position, Color(1.0, 0.85, 0.4), 150.0, 0.5)
	Sound.play("horn", position, -10.0)


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
		follow_path(map.find_hero_path(current_cell(), _avoided_traps()))
		if path.is_empty():
			return
	_walk_or_dig(delta)


## Avance d'un pas sur le chemin, en creusant la case suivante si c'est de la terre.
func _walk_or_dig(delta: float) -> void:
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


func sprite_info() -> Array:
	var info := Heroes.info(type)
	return [info["sprite"], info["size"] / 8.0]


func _draw() -> void:
	var info := Heroes.info(type)
	if knocked_out or carrier != null:
		_draw_lying(info)
		return
	var sprite_scale: float = info["size"] / 8.0
	draw_sprite(info["sprite"], sprite_scale)
	draw_strike()
	draw_health_bar(-16.0 * sprite_scale - 6.0)
	var title := overhead_text()
	if title != "":
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(-width / 2, -16.0 * sprite_scale - 10.0), title, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 10, Color("ffd54a") if is_veteran() else Color.WHITE)
	if loot > 0:
		# Le sac d'or volé, sur l'épaule.
		draw_circle(Vector2(9, -4), 5.0, Color("ffd54a"))
		draw_arc(Vector2(9, -4), 5.0, 0.0, TAU, 12, Color("8d6e00"), 1.0)
	if _unlock_left >= 0.0:
		# Le Moine crochète une serrure : une barre bleue qui se remplit.
		var progress := 1.0 - _unlock_left / Rules.UNLOCK_TIME
		draw_rect(Rect2(-14, -36, 28, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, -36, 28 * progress, 4), Color("64b5f6"))
	if is_captured():
		# Les barreaux de la cellule, par-dessus le prisonnier.
		draw_texture_rect(Art.PRISON_BARS, Rect2(-16, -16, 32, 32), false)
		if sacrifice_requested:
			# Un poignard rouge au-dessus : il sera conduit à l'autel.
			draw_texture_rect(SACRIFICE_ICON, Rect2(-8, -34, 16, 16), false)


## Le texte au-dessus de sa tête : son nom s'il est vétéran, « fuit ! » en retraite.
func overhead_text() -> String:
	if knocked_out or carrier != null or is_captured():
		return ""
	var text := String(nemesis["name"]) if is_veteran() else ""
	if fleeing:
		text = (text + " fuit !") if text != "" else "fuit !"
	return text


const SACRIFICE_ICON := preload("res://assets/icons/dagger.png")


## Assommé (couché au sol) ou porté (couché au-dessus de l'Attrapeur).
func _draw_lying(info: Dictionary) -> void:
	var lift_height := -30.0 if carrier != null else -6.0
	draw_set_transform_matrix(Iso.billboard(Vector2.ZERO, Vector2(0, lift_height)) * Transform2D(PI / 2, Vector2.ZERO))
	var size: float = 32.0 * info["size"] / 8.0
	draw_texture_rect(Art.unit_frames(info["sprite"], "idle")[0], Rect2(-size / 2, -size / 2, size, size), false)
	if knocked_out:
		# Une barre jaune : le temps qu'il reste pour venir le chercher.
		draw_set_transform_matrix(Iso.billboard(Vector2.ZERO, Vector2(0, -22)))
		draw_rect(Rect2(-14, 0, 28, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, 0, 28 * _knocked_out_timer / Rules.CAPTURE_WINDOW, 4), Color("ffd54a"))

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
## AU COMBAT (voir « Trois fois par seconde », plus bas), elle n'est pas bête :
##   - elle CHOISIT sa cible (_target_score) : qui frappe le cœur, les soigneurs,
##     les pillards, les héros presque morts... et pas seulement le plus proche ;
##   - elle APPELLE À L'AIDE ses voisines en engageant le combat (_call_for_help) ;
##   - elle accourt quand le CŒUR est frappé, même endormie (_heart_attacker) ;
##   - si elle se bat de loin, elle RECULE d'un pas entre deux tirs (_should_back_off).
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
## Émis quand un Diablotin fait les poches d'un héros (main.gd range l'or au Trésor).
signal gold_stolen(amount: int, where: Vector2)
## Émis quand un Nécromancien abat un héros : il se relève pour un temps (main.gd).
signal raised_hero(where: Vector2, duration: float)

## main.gd met à jour ces deux valeurs : y a-t-il encore quelque chose à
## chercher ou à fabriquer ? (« static » : partagées par toutes les créatures.)
static var research_needed := false
static var workshop_needed := false
## L'ASSAUT ordonné par le maître (bouton « Attaquer le Colosse ») : toutes les
## créatures disponibles marchent sur cette cible (un gardien des profondeurs), ou null.
static var assault_target = null

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
	Rooms.Type.TAVERN: "boit une chope",
	Rooms.Type.INFIRMARY: "soigne les blessés",
	Rooms.Type.MINT: "frappe la monnaie",
	Rooms.Type.TORTURE: "fait parler les prisonniers",
	Rooms.Type.GUARDPOST: "monte la garde",
	Rooms.Type.MANA_WELL: "médite",
	Rooms.Type.CRYPT: "veille les morts",
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
## Secondes avant de pouvoir rappeler ses voisines à l'aide.
var _help_cooldown := 0.0
## Vrai pendant le pas en arrière d'une créature à distance (entre deux tirs).
var _backing_off := false

var level := 1
## Expérience accumulée vers le prochain niveau.
var xp := 0.0
var _work_room: int = Rooms.Type.NONE
var _work_cell := NO_CELL
var _work_timer := 0.0
var _work_tick := 0.0

## Ses TRAITS de caractère (voir traits.gd), tirés à son arrivée.
var traits: Array[String] = []
## Le dernier héros qui l'a blessée (trait Rancunière).
var _grudge_target = null # (Pas de type : le héros a pu disparaître depuis.)
## Vrai quand une créature Peureuse a fui le combat : elle ne se bat plus avant
## d'avoir repris des forces (FLEE_RECOVER de sa vie).
var fleeing := false
const FLEE_RECOVER := 0.7

## Possession (sort du maître) : pendant ce temps, c'est toi qui la diriges.
var possessed_left := 0.0
## Son ordre : le héros à attaquer (pas de type : il a pu disparaître) ou la case où aller.
var _command_target = null
var _command_cell := NO_CELL
var _possession_bonus := 1.0
## Le Renégat (sort Conversion) garde l'allure du héros qu'il était.
var sprite_override := ""
## Taverne : secondes pendant lesquelles elle titube encore, et la remise sur sa
## prochaine paie (une chope rend conciliant).
var tipsy_left := 0.0
var _pay_discount := false
## Infirmerie : vrai quand elle y est couchée pour se soigner (sinon, elle y soigne).
var _patient := false
## La Goule : secondes avant de soigner de nouveau ses voisines.
var _heal_timer := 0.0
## Traînée de feu (Démon sous Hâte) : distance parcourue depuis la dernière flamme.
var _trail_distance := 0.0
var _last_position := Vector2.ZERO


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
	if info.has("tint"):
		self_modulate = info["tint"] # (Le Colosse ancien garde la couleur de la lave.)
	traits = Traits.roll(is_undead())
	_apply_level()
	hp = max_hp
	if info.get("catcher", false):
		add_to_group("catchers") # Les héros vaincus peuvent alors tomber assommés (hero.gd).
	setup(dungeon_map, cell)
	energy = randf_range(60.0, 100.0)
	hunger = randf_range(0.0, 30.0)
	if not is_undead():
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
	max_hp = info["hp"] * bonus * Traits.mult(traits, "hp")
	hp = max_hp * health_ratio
	attack_damage = info["damage"] * bonus * Traits.mult(traits, "damage")
	speed = info["speed"] * Traits.mult(traits, "speed")


## Chaque coup porté rapporte autant d'expérience que de dégâts.
func _on_hit_landed(target: Unit, damage_dealt: float) -> void:
	gain_xp(damage_dealt)
	# Bagarreuse : se battre la rend heureuse.
	happiness = minf(100.0, happiness + Traits.value(traits, "fight_mood"))
	var info := Creatures.info(type)
	# Le Diablotin argentier fait les poches des héros (pas des troupes du rival).
	if info.has("gold_hit") and target is Hero:
		gold_stolen.emit(int(info["gold_hit"]), target.position)
	# Le Nécromancien : le héros qu'il vient d'abattre se relève pour le servir.
	if info.has("raise_on_kill") and target is Hero and target.is_dead():
		raised_hero.emit(target.position, float(info["raise_on_kill"]))


## Les traits changent la force de ses coups selon la situation.
func damage_against(target: Unit) -> float:
	var damage := attack_damage
	if is_instance_valid(_grudge_target) and target == _grudge_target:
		damage *= Traits.mult(traits, "grudge") # Rancunière : elle se venge.
	var treasure_bonus := Traits.mult(traits, "treasure_damage")
	if treasure_bonus != 1.0 and _near_room(Rooms.Type.TREASURY, Traits.TREASURE_RADIUS):
		damage *= treasure_bonus # Avare : on ne touche pas à SON or.
	var alone_bonus := Traits.mult(traits, "alone_damage")
	if alone_bonus != 1.0 and _neighbors() == 0:
		damage *= alone_bonus # Solitaire : elle se bat mieux seule.
	if possessed_left > 0.0:
		damage *= _possession_bonus # Possédée : la rage du maître guide ses coups.
	# Le Bourreau achève les héros affaiblis.
	var execute: float = Creatures.info(type).get("execute", 0.0)
	if execute > 0.0 and target.hp < target.max_hp * execute:
		damage *= 2.0
	return damage


## Rancunière : elle retient le dernier héros qui l'a blessée.
func _on_damaged(source: Unit, _amount: float) -> void:
	if source.team != team:
		_grudge_target = source


## Vrai si une salle de ce type est à moins de radius cases.
func _near_room(room: int, radius: int) -> bool:
	var here := current_cell()
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if map.get_room(here + Vector2i(dx, dy)) == room:
				return true
	return false


## Le nombre d'autres créatures tout près (trait Solitaire).
func _neighbors() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("dungeon"):
		if node != self and node is Creature \
				and (node as Creature).position.distance_to(position) <= Traits.NEIGHBOR_RADIUS:
			count += 1
	return count
	# (Les capacités comme le ralentissement de l'araignée sont gérées par unit.gd.)


## Ce qu'il faut pour recréer la créature au chargement (voir main.gd).
func to_save() -> Dictionary:
	var data := {
		"type": type, "cell": SaveGame.cell_to_array(current_cell()), "hp": hp,
		"energy": energy, "hunger": hunger, "happiness": happiness,
		"level": level, "xp": xp, "traits": traits,
	}
	if sprite_override != "":
		data["sprite"] = sprite_override
		data["tint"] = self_modulate.to_html()
	return data


## Remet les valeurs sauvegardées (après setup_creature).
func load_save(data: Dictionary) -> void:
	level = int(data.get("level", 1))
	xp = float(data.get("xp", 0.0))
	if data.has("sprite"):
		sprite_override = str(data["sprite"])
		self_modulate = Color.html(str(data.get("tint", "ffffff")))
	if data.has("traits"): # (Une ancienne sauvegarde garde les traits tirés à l'arrivée.)
		traits.clear()
		for id in data["traits"]:
			if Traits.INFO.has(str(id)):
				traits.append(str(id))
	_apply_level()
	hp = float(data["hp"])
	energy = float(data["energy"])
	hunger = float(data["hunger"])
	happiness = float(data["happiness"])


## La Crypte la ramène à la vie (voir main.gd, _update_crypt) : un niveau plus bas,
## ses traits d'avant, et le trait « Revenue ».
func revive(body: Dictionary) -> void:
	level = maxi(1, int(body.get("level", 1)) - 1)
	traits.clear()
	for id in body.get("traits", []):
		if Traits.INFO.has(str(id)) and str(id) != "revenue":
			traits.append(str(id))
	traits.append("revenue")
	var sprite := str(body.get("sprite", ""))
	if sprite != "":
		sprite_override = sprite
		self_modulate = Color.html(str(body.get("tint", "ffffff")))
	_apply_level()
	hp = max_hp
	happiness = 80.0


func display_name() -> String:
	return Creatures.info(type)["name"]


func salary() -> int:
	var base: int = Creatures.info(type)["salary"]
	var discount := Rules.TIPSY_SALARY if _pay_discount else 1.0 # Une chope à la Taverne.
	return int(base * (1.0 + LEVEL_SALARY_BONUS * (level - 1)) * Traits.mult(traits, "salary") * discount)


func is_leaving() -> bool:
	return state == State.LEAVING


## Appelée par main.gd au jour de paie.
func receive_pay(paid: bool) -> void:
	happiness = clampf(happiness + (15.0 if paid else -35.0), 0.0, 100.0)
	_pay_discount = false


## Ce que fait la créature en ce moment (pour sa fiche, voir hud.gd).
func activity_text() -> String:
	if possessed_left > 0.0:
		return "possédée par le maître"
	if fleeing and state != State.SLEEPING:
		return "fuit, apeurée"
	if state == State.WORKING:
		return _work_name()
	if state == State.WANDER and _guarded_room() != Rooms.Type.NONE:
		return "garde le %s" % Rooms.display_name(_guarded_room())
	if state == State.WANDER and tipsy_left > 0.0:
		return "titube, un peu éméchée"
	return STATE_NAMES[state]


## Le travail en cours, en toutes lettres.
func _work_name() -> String:
	if _work_room == Rooms.Type.INFIRMARY and _patient:
		return "se fait soigner"
	return WORK_NAMES[_work_room]


## La POSE à jouer en 3D selon ce qu'elle fait (voir view_3d.gd, _animate) :
## "sleep", "eat", "study", "hammer", "train", "pray", "drink", "lie", "tend",
## "coin", "torture", "guard", "meditate", "cast", "tipsy", ou "" (normal).
func pose() -> String:
	if possessed_left > 0.0:
		return ""
	match state:
		State.SLEEPING:
			return "sleep"
		State.EATING:
			return "eat"
		State.WORKING:
			match _work_room:
				Rooms.Type.LIBRARY:
					return "study"
				Rooms.Type.WORKSHOP:
					return "hammer"
				Rooms.Type.TRAINING:
					return "train"
				Rooms.Type.TEMPLE:
					return "pray"
				Rooms.Type.TAVERN:
					return "drink"
				Rooms.Type.INFIRMARY:
					return "lie" if _patient else "tend"
				Rooms.Type.MINT:
					return "coin"
				Rooms.Type.TORTURE:
					return "torture"
				Rooms.Type.GUARDPOST:
					return "guard"
				Rooms.Type.MANA_WELL:
					return "meditate"
				Rooms.Type.CRYPT:
					return "cast"
	if tipsy_left > 0.0 and state != State.FIGHTING:
		return "tipsy"
	return ""


## Le point (en pixels) vers lequel elle se tourne pendant son travail : le milieu
## de l'objet de la salle (l'enclume, le comptoir, le puits...). Vector2.INF sinon.
func focus_point() -> Vector2:
	if state != State.WORKING or not map.cell_furniture.has(_work_cell):
		return Vector2.INF
	var item: Dictionary = map.furniture.get(map.cell_furniture[_work_cell], {})
	if item.is_empty():
		return Vector2.INF
	var origin: Vector2i = item["origin"]
	var size: Vector2i = item["size"]
	return (Vector2(origin) + Vector2(size) * 0.5) * DungeonMap.TILE_SIZE

## Petit texte affiché quand on touche la créature.
func describe() -> String:
	var activity: String = STATE_NAMES[state]
	if possessed_left > 0.0:
		activity = "possédée"
	elif state == State.WORKING:
		activity = _work_name()
	elif state == State.WANDER and _guarded_room() != Rooms.Type.NONE:
		activity = "garde le %s" % Rooms.display_name(_guarded_room())
	return "%s niv. %d [%s] (%s) : vie %d/%d, humeur %d%%, faim %d%%, énergie %d%%, salaire %d or%s" % [
		display_name(), level, Traits.names(traits), activity, hp, max_hp, happiness, hunger, energy,
		salary(), "" if _has_bed() or is_undead() else ", SANS LIT !"]


## Les morts-vivants et les êtres de pierre ne saignent pas.
func bleeds() -> bool:
	return not is_undead() and type != Creatures.Type.GOLEM


## Un mort-vivant (le Revenant) : pas de lit, pas de sommeil, pas de faim.
func is_undead() -> bool:
	return Creatures.info(type).get("undead", false)


## Renvoyée par le maître (déposée sur le portail) : elle s'en va tout de suite.
func dismiss() -> void:
	_drop_carried()
	map.release_bed(self)
	map.release_work_spot(self)
	queue_free()


func _process(delta: float) -> void:
	if is_undead():
		energy = 100.0
		hunger = 0.0
	if state != State.SLEEPING:
		energy = maxf(0.0, energy - ENERGY_LOSS * Traits.mult(traits, "energy_loss") * delta)
	if state != State.EATING:
		hunger = minf(100.0, hunger + HUNGER_GAIN * Traits.mult(traits, "hunger") * delta)
	_update_mood(delta)
	update_attack_cooldown(delta)
	update_effects(delta)
	if not is_inside_tree() or is_queued_for_deletion():
		return # Une créature temporaire vient de s'effacer (voir vanish).
	_update_fire_trail()
	tipsy_left = maxf(0.0, tipsy_left - delta)
	_update_healer(delta)
	# Possédée : elle n'obéit plus qu'au maître.
	if possessed_left > 0.0:
		_process_possessed(delta)
		redraw()
		return
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
			energy += ENERGY_GAIN * Traits.mult(traits, "sleep") * delta
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
				happiness = minf(100.0, happiness + Traits.value(traits, "meal_mood")) # Gourmande.
				state = State.WANDER
		State.LEAVING:
			if move_along_path(delta):
				_leave_now()
		State.FIGHTING:
			if not is_instance_valid(_enemy):
				_enemy = null
				state = State.WANDER
			elif _backing_off or _should_back_off():
				_back_off(delta)
			elif not fight(_enemy, delta):
				_enemy = null
				state = State.WANDER
		State.GOING_TO_WORK:
			if map.get_room(_work_cell) != _work_room:
				_stop_work()
			elif move_along_path(delta):
				_arrive_at_work()
		State.WORKING:
			_process_working(delta * work_factor()) # Le Fouet la fait travailler plus vite.
		State.RAIDING:
			_process_raiding(delta)
		State.GOING_TO_CATCH:
			_process_going_to_catch(delta)
		State.CARRYING:
			_process_carrying(delta)
	redraw()


# ---------------------------------------------------------------------------
# Les sorts du maître : Possession, Traînée de feu, unités temporaires
# ---------------------------------------------------------------------------

## Possession : le maître la dirige pendant duration secondes (dégâts multipliés).
func possess(duration: float, damage_bonus: float) -> void:
	_drop_carried()
	map.release_work_spot(self)
	_work_room = Rooms.Type.NONE
	_work_cell = NO_CELL
	_enemy = null
	fleeing = false
	path.clear()
	state = State.WANDER
	possessed_left = duration
	_possession_bonus = damage_bonus
	_command_target = null
	_command_cell = NO_CELL
	apply_haste(duration)


## Un ordre du maître à la créature possédée : un héros à attaquer, ou une case où aller.
func command(target: Unit, cell: Vector2i) -> void:
	_command_target = target
	_command_cell = cell if target == null else NO_CELL
	path.clear()


func is_possessed() -> bool:
	return possessed_left > 0.0


func _end_possession() -> void:
	possessed_left = 0.0
	_command_target = null
	_command_cell = NO_CELL
	path.clear()
	state = State.WANDER


func _process_possessed(delta: float) -> void:
	possessed_left -= delta
	if possessed_left <= 0.0:
		_end_possession()
		return
	# 1. Le héros désigné par le maître, où qu'il soit.
	if _command_target != null:
		if is_instance_valid(_command_target) and _command_target.is_targetable() \
				and fight(_command_target, delta):
			return
		_command_target = null
		path.clear()
	# 2. La case désignée.
	if _command_cell != NO_CELL:
		if current_cell() == _command_cell:
			_command_cell = NO_CELL
			path.clear()
		elif path.is_empty() and not go_to(_command_cell):
			_command_cell = NO_CELL
		else:
			move_along_path(delta)
		return
	# 3. Sans ordre : elle se jette sur le héros le plus proche.
	var enemy := find_nearest_enemy(AGGRO_RADIUS)
	if enemy != null:
		fight(enemy, delta)


## L'Exorciste chasse aussi l'esprit du maître.
func dispel() -> bool:
	var had := super()
	if possessed_left > 0.0:
		_end_possession()
		had = true
	return had


## Traînée de feu (combo) : un Démon sous Hâte enflamme le sol derrière lui.
func _update_fire_trail() -> void:
	if type != Creatures.Type.DEMON or not is_hasted():
		_last_position = position
		_trail_distance = 0.0
		return
	_trail_distance += position.distance_to(_last_position)
	_last_position = position
	if _trail_distance >= Rules.FIRE_TRAIL_STEP:
		_trail_distance = 0.0
		map.add_fire(position, 18.0, Rules.FIRE_TRAIL_TIME)
		map.combo_triggered.emit("trainee_de_feu", position)


## Rappel (sort du maître) : elle apparaît d'un coup sur cette case, prête à se battre.
func recall_to(cell: Vector2i) -> void:
	_drop_carried()
	map.release_work_spot(self)
	_work_room = Rooms.Type.NONE
	_work_cell = NO_CELL
	_enemy = null
	fleeing = false
	path.clear()
	state = State.WANDER
	position = map.cell_to_world(cell)
	_last_position = position


## Une créature temporaire (Revenant relevé) s'efface : elle libère tout.
func vanish() -> void:
	_drop_carried()
	map.release_bed(self)
	map.release_work_spot(self)
	super()


## Effondrement : la case suivante s'est bouchée, elle abandonne ce qu'elle faisait.
func on_path_blocked() -> void:
	super()
	match state:
		State.GOING_TO_WORK:
			_stop_work()
		State.GOING_TO_CATCH:
			_stop_catch()
		State.CARRYING:
			_drop_carried()
		State.LEAVING:
			if not go_to(map.portal_cell):
				_leave_now()
			return
	if state != State.FIGHTING and state != State.SLEEPING and state != State.EATING and state != State.WORKING:
		state = State.WANDER


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
				# Les Sorciers étudient 3 fois plus vite (et les Studieuses 50 % plus vite).
				var study := 3.0 if type == Creatures.Type.WARLOCK else 1.0
				worked.emit(_work_room, study * Traits.mult(traits, "research") * _work_bonus())
			Rooms.Type.WORKSHOP:
				# Les Orques sont les meilleurs artisans.
				var craft := 3.0 if type == Creatures.Type.ORC else 2.0
				worked.emit(_work_room, craft * Traits.mult(traits, "craft") * _work_bonus())
			Rooms.Type.TAVERN:
				# Une chope : l'humeur remonte (deux fois plus vite pour le Gobelin brasseur).
				happiness = minf(100.0, happiness + Rules.TAVERN_MOOD * _work_bonus())
			Rooms.Type.INFIRMARY:
				if _patient:
					var boost := Rules.INFIRMARY_NURSE_BOOST if _nurse_on_duty(get_tree()) else 1.0
					heal(Rules.INFIRMARY_HEAL * boost)
					happiness = minf(100.0, happiness + 0.5)
				else:
					gain_xp(1.0) # La Goule apprend en recousant.
			Rooms.Type.MINT:
				worked.emit(_work_room, Rules.MINT_WORK_GOLD * Traits.mult(traits, "craft") * _work_bonus())
			Rooms.Type.TORTURE:
				worked.emit(_work_room, _work_bonus())
				happiness = minf(100.0, happiness + 0.5) # Le métier a ses plaisirs.
			Rooms.Type.MANA_WELL:
				worked.emit(_work_room, Rules.MANA_MEDITATION * Traits.mult(traits, "prayer") * _work_bonus())
			Rooms.Type.CRYPT:
				worked.emit(_work_room, _work_bonus())
			Rooms.Type.TEMPLE:
				# Prier rend heureux, soigne, et donne un peu de mana au maître (deux fois plus si Pieuse).
				var prayer := Traits.mult(traits, "prayer")
				happiness = minf(100.0, happiness + TEMPLE_HAPPINESS * prayer)
				heal(TEMPLE_HEAL * prayer)
				worked.emit(_work_room, TEMPLE_MANA * prayer)
	var stop_training := _work_room == Rooms.Type.TRAINING and level >= MAX_LEVEL
	var stop_research := _work_room == Rooms.Type.LIBRARY and not research_needed
	var stop_workshop := _work_room == Rooms.Type.WORKSHOP and not workshop_needed
	var stop_den := false
	match _work_room:
		Rooms.Type.TAVERN:
			if _work_timer <= 0.0:
				tipsy_left = Rules.TIPSY_TIME # Elle sort en titubant...
				_pay_discount = true          # ... et se montre conciliante à la paie.
		Rooms.Type.INFIRMARY:
			if _patient:
				# Couchée, elle reste jusqu'à guérison (même affamée ou fatiguée).
				if hp >= max_hp:
					_stop_work()
				return
			stop_den = _patients() == 0
		Rooms.Type.TORTURE:
			stop_den = map.prisoners.is_empty()
	if _work_timer <= 0.0 or hunger >= HUNGRY_LEVEL or energy <= TIRED_LEVEL \
			or stop_training or stop_research or stop_workshop or stop_den:
		_stop_work()


## Choisit un travail utile et part vers un poste libre. Renvoie false si rien à faire.
func _start_work() -> bool:
	if _guarded_room() != Rooms.Type.NONE:
		return false # Un gardien ne quitte pas son poste pour travailler.
	var info := Creatures.info(type)
	# La Gargouille ne fait qu'une chose : monter la garde.
	if info.get("sentinel", false):
		return _go_to_room(Rooms.Type.GUARDPOST)
	var options: Array[int] = []
	_add_den_options(options, info)
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
		if Traits.mult(traits, "prayer") > 1.0:
			options.append_array([Rooms.Type.TEMPLE, Rooms.Type.TEMPLE]) # Pieuse : elle adore prier.
	if options.is_empty():
		return false
	return _go_to_room(options.pick_random())


## Part vers un poste libre d'une salle de travail. Renvoie false s'il n'y en a pas.
func _go_to_room(room: int) -> bool:
	if map.count_room_tiles(room) == 0:
		return false
	var spot := map.find_work_spot(self, room, current_cell())
	if spot.is_empty():
		return false
	_patient = false
	_work_room = room
	_work_cell = spot["target"]
	follow_path(spot["path"])
	state = State.GOING_TO_WORK
	return true


## Les antres (règles 2.7) : ce que la créature peut y faire, selon son humeur et ses goûts.
func _add_den_options(options: Array[int], info: Dictionary) -> void:
	# La Taverne : quand l'humeur baisse (une Gourmande, toujours), s'il reste des champignons.
	if map.count_room_tiles(Rooms.Type.TAVERN) > 0 and not is_undead() and map.has_food() \
			and (happiness < Rules.TAVERN_MOOD_BELOW or Traits.value(traits, "meal_mood") > 0.0):
		options.append(Rooms.Type.TAVERN)
		if happiness < 45.0 or info.get("brewer", false):
			options.append_array([Rooms.Type.TAVERN, Rooms.Type.TAVERN])
	# L'Hôtel des monnaies : frapper des pièces (le Diablotin adore ça).
	if map.count_room_tiles(Rooms.Type.MINT) > 0 and type != Creatures.Type.WARLOCK:
		options.append(Rooms.Type.MINT)
		if type == Creatures.Type.IMP:
			options.append_array([Rooms.Type.MINT, Rooms.Type.MINT, Rooms.Type.MINT])
	# La Chambre de torture : seulement s'il y a des prisonniers (les Pieuses refusent).
	if map.count_room_tiles(Rooms.Type.TORTURE) > 0 and not map.prisoners.is_empty() \
			and Traits.mult(traits, "prayer") <= 1.0:
		options.append(Rooms.Type.TORTURE)
		if type == Creatures.Type.EXECUTIONER:
			options.append_array([Rooms.Type.TORTURE, Rooms.Type.TORTURE, Rooms.Type.TORTURE])
	# Le Poste de garde : quelqu'un doit bien guetter.
	if map.count_room_tiles(Rooms.Type.GUARDPOST) > 0:
		options.append(Rooms.Type.GUARDPOST)
	# Le Puits de mana : méditer (l'Oracle y passe sa vie).
	if map.count_room_tiles(Rooms.Type.MANA_WELL) > 0:
		options.append(Rooms.Type.MANA_WELL)
		if type == Creatures.Type.ORACLE or type == Creatures.Type.WARLOCK:
			options.append_array([Rooms.Type.MANA_WELL, Rooms.Type.MANA_WELL])
	# La Crypte : seul le Nécromancien veille les morts.
	if type == Creatures.Type.NECROMANCER and map.count_room_tiles(Rooms.Type.CRYPT) > 0:
		options.append_array([Rooms.Type.CRYPT, Rooms.Type.CRYPT, Rooms.Type.CRYPT])
	# L'Infirmerie : la Goule va au chevet des blessés.
	if info.get("nurse", false) and _patients() > 0:
		options.append_array([Rooms.Type.INFIRMARY, Rooms.Type.INFIRMARY, Rooms.Type.INFIRMARY])


## Arrivée au poste de travail.
func _arrive_at_work() -> void:
	state = State.WORKING
	_work_timer = WORK_DURATION
	_work_tick = 0.0
	if _work_room == Rooms.Type.TAVERN:
		# Une chope de bière de champignons : on la prend à la Champignonnière.
		if not map.take_any_food():
			_stop_work()
			return
		_work_timer = Rules.TAVERN_DRINK_TIME
		Sound.play("coins", position, -14.0)
	elif _work_room == Rooms.Type.INFIRMARY and _patient:
		_work_timer = 999.0 # Elle reste couchée jusqu'à guérison.


## Une créature blessée (hors combat) qui ferait bien de passer à l'Infirmerie.
func _needs_care() -> bool:
	return not is_undead() and hp < max_hp * Rules.INFIRMARY_BELOW \
			and map.count_room_tiles(Rooms.Type.INFIRMARY) > 0


## Le nombre de blessés couchés à l'Infirmerie.
func _patients() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("dungeon"):
		var other := node as Creature
		if other != null and other.is_patient():
			count += 1
	return count


func is_patient() -> bool:
	return _work_room == Rooms.Type.INFIRMARY and _patient \
			and (state == State.WORKING or state == State.GOING_TO_WORK)


## Vrai si elle monte la garde à son poste en ce moment (main.gd s'en sert).
func on_guard_duty() -> bool:
	return state == State.WORKING and _work_room == Rooms.Type.GUARDPOST


## Vrai si une Goule soigne à l'Infirmerie en ce moment.
static func _nurse_on_duty(tree: SceneTree) -> bool:
	for node in tree.get_nodes_in_group("dungeon"):
		var other := node as Creature
		if other != null and other.state == State.WORKING and other._work_room == Rooms.Type.INFIRMARY \
				and not other._patient:
			return true
	return false


## L'alarme du Poste de garde : elle se réveille (ou lâche son travail) et court au héros.
## wake = false (l'appel à l'aide d'une voisine) : les endormies ne se réveillent pas.
func alert(enemy: Unit, wake := true) -> void:
	if possessed_left > 0.0 or fleeing or is_catcher() or not is_instance_valid(enemy):
		return
	if state != State.SLEEPING and state != State.WORKING and state != State.WANDER \
			and state != State.GOING_TO_WORK and state != State.EATING:
		return
	if state == State.SLEEPING and not wake:
		return
	if is_patient():
		return # Les blessés restent couchés.
	map.release_work_spot(self)
	_work_room = Rooms.Type.NONE
	_work_cell = NO_CELL
	path.clear()
	_backing_off = false
	_enemy = enemy
	state = State.FIGHTING


## La Goule rebouteuse soigne les créatures blessées autour d'elle, même en combat.
func _update_healer(delta: float) -> void:
	var healer: Variant = Creatures.info(type).get("healer")
	if healer == null or healer.is_empty() or state == State.SLEEPING:
		return
	_heal_timer -= delta
	if _heal_timer > 0.0:
		return
	_heal_timer = healer["interval"]
	var healed := false
	for node in get_tree().get_nodes_in_group("dungeon"):
		var other := node as Unit
		if other != null and other != self and not other.is_dead() and other.hp < other.max_hp \
				and other.position.distance_to(position) <= healer["radius"]:
			other.heal(healer["amount"])
			healed = true
	if healed:
		Fx.burst("heal", position, Color("b2ff59"))


## Le talent de l'espèce pour le travail en cours (catalogue : "work_bonus").
func _work_bonus() -> float:
	return Creatures.info(type).get("work_bonus", {}).get(_work_room, 1.0)


func _stop_work() -> void:
	map.release_work_spot(self)
	_patient = false
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
	_help_cooldown = maxf(0.0, _help_cooldown - 0.3)
	# Peureuse : sous un certain seuil de vie, elle fuit le combat et va se cacher.
	var flee_below := Traits.value(traits, "flee_below")
	if flee_below > 0.0:
		if not fleeing and hp < max_hp * flee_below and state == State.FIGHTING:
			_flee()
			return
		if fleeing:
			if hp >= max_hp * FLEE_RECOVER:
				fleeing = false
			else:
				return
	# Une créature endormie ne remarque que les héros tout proches.
	var radius := WAKE_RADIUS if state == State.SLEEPING else AGGRO_RADIUS * Traits.mult(traits, "aggro")
	var enemy := find_nearest_enemy(radius)
	# Assaut du maître : sans ennemi plus proche, on marche sur le Colosse (même de loin).
	if enemy == null and state != State.SLEEPING and is_instance_valid(assault_target) \
			and assault_target.is_targetable() and not is_catcher():
		enemy = assault_target
	# Le cœur est frappé : tout le monde accourt, même de loin, même endormi.
	if enemy == null and not is_catcher() and not is_patient():
		enemy = _heart_attacker()
	if enemy == null:
		# Personne à combattre, mais le cœur du rival est tout près : à l'attaque !
		if state == State.WANDER and map.has_rival and map.rival_heart_hp > 0.0 \
				and position.distance_to(map.cell_to_world(map.rival_heart_cell)) <= RAID_RADIUS:
			path.clear()
			state = State.RAIDING
		return
	if state != State.FIGHTING or not is_instance_valid(_enemy) or _enemy != enemy:
		if state != State.FIGHTING:
			_call_for_help(enemy)
		map.release_work_spot(self)
		path.clear()
		_backing_off = false
		state = State.FIGHTING
	_enemy = enemy


## Ses cibles préférées « comptent » comme si elles étaient plus proches (la note la
## plus basse gagne, voir unit.gd et les réglages TARGET_* de rules.gd).
func _target_score(enemy: Unit, distance: float) -> float:
	var score := distance
	if enemy == _enemy:
		score -= Rules.TARGET_STICKY # Elle ne change pas de cible pour un rien.
	score -= (1.0 - enemy.hp / enemy.max_hp) * Rules.TARGET_WOUNDED # On achève les blessés.
	if is_instance_valid(_grudge_target) and enemy == _grudge_target and Traits.mult(traits, "grudge") > 1.0:
		score -= Rules.TARGET_GRUDGE # Rancunière : elle veut SA vengeance.
	var execute: float = Creatures.info(type).get("execute", 0.0)
	if execute > 0.0 and enemy.hp < enemy.max_hp * execute:
		score -= Rules.TARGET_EXECUTE # Le Bourreau flaire les héros à achever.
	var hero := enemy as Hero
	if hero != null:
		if hero.type == Heroes.Type.CLERIC or hero.type == Heroes.Type.EXORCIST:
			score -= Rules.TARGET_HEALER # Sans leur soutien, les autres tombent plus vite.
		if hero.loot > 0:
			score -= Rules.TARGET_LOOT # Il emporte l'or du maître !
		if map.is_next_to_heart(hero.current_cell()):
			score -= Rules.TARGET_HEART # Il frappe le cœur : rien n'est plus urgent.
	return score


## En engageant le combat, elle appelle ses voisines : celles qui travaillent, mangent
## ou se promènent accourent (les endormies ne l'entendent pas).
func _call_for_help(enemy: Unit) -> void:
	if _help_cooldown > 0.0 or enemy == assault_target:
		return
	_help_cooldown = Rules.HELP_COOLDOWN
	for node in get_tree().get_nodes_in_group("dungeon"):
		var other := node as Creature
		if other != null and other != self and other.state != State.FIGHTING \
				and other.position.distance_to(position) <= Rules.HELP_RADIUS:
			other._help_cooldown = Rules.HELP_COOLDOWN # (Pas d'appels en cascade.)
			other.alert(enemy, false)


## Le héros qui frappe le cœur en ce moment (le plus proche de nous), ou null.
func _heart_attacker() -> Unit:
	if Time.get_ticks_msec() - map.last_heart_hit_msec > Rules.HEART_CALL_TIME * 1000.0:
		return null
	var heart := map.cell_to_world(map.heart_cell)
	var best: Unit = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		var hero := node as Unit
		if hero == null or not hero.is_targetable() or hero.ignored_as_enemy() \
				or hero.position.distance_to(heart) > Rules.HEART_CALL_RADIUS:
			continue
		var distance := position.distance_to(hero.position)
		if distance < best_distance:
			best = hero
			best_distance = distance
	return best


## Une créature à distance recule quand un héros au corps à corps la colle... mais
## d'UN SEUL pas, juste après son tir (dans les BACK_OFF_WINDOW secondes qui suivent) :
## elle gagne du temps sans devenir intouchable, et tire de nouveau dès qu'elle le peut.
const BACK_OFF_WINDOW := 0.3
func _should_back_off() -> bool:
	return is_ranged() and _attack_cooldown > attack_interval - BACK_OFF_WINDOW \
			and _enemy.is_targetable() and not _enemy.is_ranged() \
			and position.distance_to(_enemy.position) < Rules.KITE_DISTANCE


## Le pas en arrière (une case). Acculée, elle se bat sur place.
func _back_off(delta: float) -> void:
	if not _backing_off:
		if not step_away_from(_enemy.position):
			if not fight(_enemy, delta):
				_enemy = null
				state = State.WANDER
			return
		_backing_off = true
	if path.is_empty() or move_along_path(delta):
		_backing_off = false


## Peureuse : elle quitte le combat et court se cacher dans son lit (où elle se soigne).
## Le maître rappelle ses troupes : on cesse de se battre contre le Colosse et on rentre.
func call_back() -> void:
	if state == State.FIGHTING and is_instance_valid(_enemy) and _enemy is Hero and (_enemy as Hero).is_guardian():
		_enemy = null
		path.clear()
		state = State.WANDER
		go_to(map.heart_cell + Vector2i(randi_range(-2, 2), randi_range(-2, 2)))


func _flee() -> void:
	fleeing = true
	_enemy = null
	path.clear()
	state = State.WANDER
	if _has_bed() and go_to(bed_cell):
		state = State.GOING_TO_SLEEP
	elif not go_to(map.heart_cell + Vector2i(randi_range(-2, 2), randi_range(-2, 2))):
		go_to(current_cell() + Vector2i(randi_range(-4, 4), randi_range(-4, 4)))
	Fx.burst("sparks", position, Color("80deea"))


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

	# Priorité 2 bis : blessée, elle va se faire soigner à l'Infirmerie.
	if _needs_care() and _go_to_room(Rooms.Type.INFIRMARY):
		_patient = true
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

	if not _has_bed() and not is_undead():
		bed_cell = map.claim_bed(self) # Un lit s'est peut-être libéré.

	var change := 0.0
	if hunger >= 90.0:
		change -= 3.0
	if energy <= 5.0:
		change -= 3.0
	if not _has_bed() and not is_undead():
		change -= 2.0
	if change == 0.0 and hunger < HUNGRY_LEVEL and energy > TIRED_LEVEL:
		change = 1.0
	# Le prestige : un donjon bien décoré rend les créatures plus heureuses
	# (deux fois plus les Coquettes).
	var decor := Traits.mult(traits, "decor_mood")
	change += minf(map.decorations.size() * Rules.DECORATION_MOOD, Rules.MAX_DECORATION_MOOD) * decor
	# Le feu rouge du cœur : près d'un brasero, on se sent chez soi.
	if map.near_brazier(map.world_to_cell(position), Rules.BRAZIER_RADIUS):
		change += Rules.BRAZIER_MOOD * decor
	# Pieuse : sans Temple, elle s'inquiète pour son âme.
	var needs_temple := Traits.value(traits, "needs_temple")
	if needs_temple > 0.0 and map.count_room_tiles(Rooms.Type.TEMPLE) == 0:
		change -= needs_temple
	# Solitaire : la foule l'agace.
	var crowd_mood := Traits.value(traits, "crowd_mood")
	if crowd_mood > 0.0 and _neighbors() >= Traits.CROWD:
		change -= crowd_mood
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


func sprite_info() -> Array:
	var info := Creatures.info(type)
	return [sprite_override if sprite_override != "" else info["sprite"], info["size"] / 8.0]


func _draw() -> void:
	var info := Creatures.info(type)
	var sprite_scale: float = info["size"] / 8.0 # Taille 8 = image normale (32 pixels).
	if possessed_left > 0.0:
		draw_arc(Vector2.ZERO, 11.0 * sprite_scale, 0.0, TAU, 20, Color(1.0, 0.2, 0.3, 0.8), 2.0)
	draw_sprite(sprite_info()[0], sprite_scale)
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

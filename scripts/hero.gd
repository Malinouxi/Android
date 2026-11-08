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
##
## LES TACTIQUES (voir plus bas, « Escouades, objectifs et tactiques ») : chaque
## héros appartient à une ESCOUADE (squad) avec un rôle (« main » : le chemin le
## plus court ; « flank » : un autre chemin ; « sapper » : un tunnel tout droit),
## et parfois un OBJECTIF (piller le Trésor, libérer les prisonniers, saccager la
## Bibliothèque, chasser les ouvriers, abattre ta meilleure créature, ou explorer
## pour l'éclaireur). Main.gd forme les escouades et gère leur retraite.

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
## LES ESCOUADES (voir main.gd) : numéro, rôle et objectif.
var squad := -1
var role := "main"
var objective := ""
## Secondes pendant lesquelles il attend son escouade à l'entrée.
var hold_left := 0.0
## Le chemin de l'escouade principale, que les flanqueurs évitent : case -> true.
var flank_avoid: Dictionary = {}
## Les pièges signalés par un éclaireur (il les évite) : case -> true.
var scouted_traps: Dictionary = {}
## (L'éclaireur) Les pièges qu'il a repérés : case -> true.
var seen_traps: Dictionary = {}
## Sa perte a déjà été comptée pour son escouade (main.gd).
var loss_counted := false
var _prey = null # (Pas de type : la proie a pu disparaître.)
var _objective_timer := 0.0
var _scout_time := 0.0
## Dégâts reçus de chaque espèce de créature : Creatures.Type -> dégâts.
var _damage_by_species: Dictionary = {}
## Terreur (sort du maître) : il fuit vers l'entrée pendant ce temps, puis reprend sa route.
var _terror_left := 0.0
## L'Exorciste : temps avant sa prochaine dissipation.
var _exorcise_timer := 2.0


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
	var data := {"type": type, "cell": SaveGame.cell_to_array(current_cell()), "hp": hp, "loot": loot,
		"resist": spell_resist}
	if not nemesis.is_empty():
		data["nemesis"] = nemesis
	if fleeing:
		data["fleeing"] = true
	if is_scout():
		data["scout"] = true
	if squad >= 0:
		data["squad"] = squad
		data["role"] = role
		data["objective"] = objective
		data["hold"] = hold_left
	for key in ["flank_avoid", "scouted_traps", "seen_traps"]:
		var cells: Dictionary = get(key)
		if not cells.is_empty():
			var list := []
			for cell: Vector2i in cells:
				list.append(SaveGame.cell_to_array(cell))
			data[key] = list
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
	# Il a déjà goûté à tes sorts : il y résiste mieux.
	spell_resist = minf(0.75, spell_resist + Rules.SPELL_RESIST_PER_RANK * rank())
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


# ---------------------------------------------------------------------------
# Face aux sorts du maître (voir spells.gd)
# ---------------------------------------------------------------------------

## Insensible à ce sort ? ("immune" dans heroes.gd ; ceux qui ne fuient jamais
## ne craignent pas la Terreur.)
func is_immune(spell: String) -> bool:
	var info := Heroes.info(type)
	if spell in info.get("immune", []):
		return true
	return spell == "terror" and not _can_flee()


## Sa résistance à la magie, selon la vague où il arrive et son rang de vétéran.
func set_spell_resist(wave: int) -> void:
	var from_waves := maxf(0.0, wave - Rules.SPELL_RESIST_FROM_WAVE + 1) * Rules.SPELL_RESIST_PER_WAVE
	spell_resist = minf(Rules.SPELL_RESIST_MAX, from_waves) + Rules.SPELL_RESIST_PER_RANK * rank()
	spell_resist = minf(spell_resist, 0.75)


## Terreur : il court vers l'entrée pendant duration secondes. Renvoie false s'il y
## est insensible.
func frighten(duration: float) -> bool:
	if is_immune("terror") or fleeing or is_guardian():
		return false
	_terror_left = maxf(_terror_left, resisted(duration))
	_target = null
	_mission_cell = NO_CELL
	_unlock_left = -1.0
	path.clear()
	return true


func is_terrified() -> bool:
	return _terror_left > 0.0


## Les envoûtements du maître le quittent (Exorciste, Clerc).
func dispel() -> bool:
	var had := super()
	if _terror_left > 0.0:
		had = true
		_terror_left = 0.0
		path.clear()
		_mission_cell = NO_CELL
	return had


## Terrifié : il court vers l'entrée la plus proche et y attend que ça passe.
func _run_in_terror(delta: float) -> void:
	_terror_left -= delta
	if _terror_left <= 0.0:
		path.clear()
		_mission_cell = NO_CELL
		return
	var exit := map.nearest_entrance(current_cell())
	if current_cell() == exit:
		path.clear()
		return
	if path.is_empty() or _mission_cell != exit:
		_mission_cell = exit
		follow_path(map.find_hero_path_to(current_cell(), exit, _avoided_traps(), _path_weights()))
		if path.is_empty():
			return
	_walk_or_dig(delta)


## L'Exorciste dissipe les sorts autour de lui : il libère ses alliés, retire leurs
## sorts à tes unités (Hâte, Sanctuaire, Fouet, Possession) et éteint les flammes.
func _exorcise(delta: float) -> void:
	_exorcise_timer -= delta
	if _exorcise_timer > 0.0:
		return
	_exorcise_timer = Rules.EXORCIST_INTERVAL
	var dispelled := map.extinguish_fires(position, Rules.EXORCIST_RADIUS)
	for group in ["heroes", "dungeon"]:
		for node in get_tree().get_nodes_in_group(group):
			var unit := node as Unit
			if unit != null and unit.position.distance_to(position) <= Rules.EXORCIST_RADIUS and unit.dispel():
				dispelled = true
				Fx.burst("sparks", unit.position, Color("e1f5fe"))
	if dispelled:
		play_attack()
		map.add_effect(position, Rules.EXORCIST_RADIUS, Color(0.85, 0.95, 1.0, 0.45))
		Fx.flash_light(position, Color(0.8, 0.9, 1.0), 150.0, 0.5)
		Sound.play("zap", position, -6.0)


## Gravement blessé : il bat en retraite vers l'entrée grise.
func start_fleeing(announce := true) -> void:
	if fleeing:
		return
	fleeing = true
	_terror_left = 0.0
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
	var exit := map.nearest_entrance(current_cell())
	if current_cell() == exit:
		_leave_alive()
		return
	if path.is_empty() or _mission_cell != exit:
		_mission_cell = exit
		follow_path(map.find_hero_path_to(current_cell(), exit, _avoided_traps(), _path_weights()))
		if path.is_empty():
			_mission_cell = NO_CELL
			var enemy := find_nearest_enemy(Rules.MISSION_AGGRO_RADIUS)
			if enemy != null:
				fight(enemy, delta)
			return
	_walk_or_dig(delta)


## Il sort vivant du donjon : il reviendra (main.gd le note dans le registre des vétérans).
func _leave_alive() -> void:
	if loot > 0: # Un pillard sort avec ton or : il est perdu.
		escaped.emit(self, loot)
		loot = 0
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
	elif type == Heroes.Type.EXORCIST:
		_exorcise(delta)
	if stealthy:
		self_modulate.a = 0.55 if is_stealthy() else 1.0 # L'Œil du maître la démasque.

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

	# Terrifié (sort du maître) : il ne pense qu'à s'enfuir.
	if _terror_left > 0.0 and not fleeing:
		_run_in_terror(delta)
		queue_redraw()
		return

	# Trois fois par seconde, on regarde s'il y a un ennemi à proximité.
	_think_timer -= delta
	if not fleeing and _think_timer <= 0.0:
		_think_timer = 0.3
		var radius := Rules.MISSION_AGGRO_RADIUS if _has_mission() else AGGRO_RADIUS
		var enemy := find_nearest_enemy(radius)
		# Un chasseur se jette sur sa proie dès qu'il la voit.
		if _is_hunting() and is_instance_valid(_prey) and _prey.is_targetable() \
				and position.distance_to(_prey.position) <= AGGRO_RADIUS:
			enemy = _prey
		if enemy != _target:
			_target = enemy
			path.clear()

	if fleeing:
		_flee(delta)
	elif _target != null:
		_unlock_left = -1.0
		if _should_keep_distance():
			_keep_distance(delta)
		elif not fight(_target, delta):
			_target = null
			path.clear()
	elif hold_left > 0.0:
		# Il attend son escouade à l'entrée avant d'avancer.
		hold_left -= delta
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
	return info.get("stealth", false) or info.get("liberator", false) or objective != "" \
			or type == Heroes.Type.CLERIC


## Fait avancer la mission. Renvoie false s'il n'y a rien à faire : le héros
## marche alors vers le cœur, comme les autres.
func _do_mission(delta: float) -> bool:
	match objective:
		"treasury":
			return _raid_mission(delta)
		"prison":
			return _liberator_mission(delta)
		"library":
			return _wreck_mission(delta)
		"workers", "assassinate":
			return _hunt_mission(delta)
		"scout":
			return _scout_mission(delta)
	if type == Heroes.Type.CLERIC and _support(delta):
		return true
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
			follow_path(map.find_hero_path_to(current_cell(), prisoner.prison_cell, _avoided_traps(), _path_weights()))
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


# ---------------------------------------------------------------------------
# Escouades, objectifs et tactiques
# ---------------------------------------------------------------------------

## Les cases que ce héros préfère éviter en cherchant son chemin, avec leur
## surcoût : le chemin de l'escouade principale (flanqueurs), les pièges signalés
## par l'éclaireur, et les abords des créatures redoutables (héros fragiles).
func _path_weights() -> Dictionary:
	var weights := {}
	for cell: Vector2i in flank_avoid:
		weights[cell] = Rules.FLANK_AVOID_WEIGHT
	for cell: Vector2i in scouted_traps:
		if map.defenses.has(cell):
			weights[cell] = maxf(weights.get(cell, 1.0), Rules.NEMESIS_TRAP_AVOID)
	if max_hp < Rules.FRAGILE_HP:
		var r := Rules.STRONG_AVOID_RADIUS
		for node in get_tree().get_nodes_in_group("dungeon"):
			var creature := node as Creature
			if creature == null or not _is_formidable(creature):
				continue
			var center := creature.current_cell()
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var cell := center + Vector2i(dx, dy)
					weights[cell] = maxf(weights.get(cell, 1.0), Rules.STRONG_AVOID_WEIGHT)
	return weights


## Une créature qui fait peur aux héros fragiles.
static func _is_formidable(creature: Creature) -> bool:
	return creature.type == Creatures.Type.DEMON or creature.type == Creatures.Type.COLOSSUS \
			or creature.level >= Rules.STRONG_LEVEL


## Le rapport de l'éclaireur : la vague connaît ces pièges et les évite.
func learn_traps(cells: Array) -> void:
	for cell in cells:
		scouted_traps[cell] = true


## Les héros à distance (et le Clerc) reculent quand une créature les colle.
func _should_keep_distance() -> bool:
	if attack_range <= 50.0 and type != Heroes.Type.CLERIC:
		return false
	return is_instance_valid(_target) and position.distance_to(_target.position) < Rules.KITE_DISTANCE


## Recule d'une case (celle qui l'éloigne le plus). Acculé, il se bat.
func _keep_distance(delta: float) -> void:
	if path.is_empty():
		var here := current_cell()
		var best := here
		var best_distance := position.distance_to(_target.position)
		for direction in DungeonMap.DIRECTIONS:
			var cell: Vector2i = here + direction
			if map.is_walkable(cell) and not map.has_door(cell):
				var distance := map.cell_to_world(cell).distance_to(_target.position)
				if distance > best_distance + 4.0:
					best = cell
					best_distance = distance
		if best == here:
			if not fight(_target, delta):
				_target = null
			return
		path.assign([best])
	move_along_path(delta)


## Le Clerc reste derrière ses compagnons (il les soigne) au lieu de foncer.
func _support(delta: float) -> bool:
	_objective_timer -= delta
	if _objective_timer > 0.0 and not path.is_empty():
		_walk_or_dig(delta)
		return true
	_objective_timer = 0.6
	var ally: Hero = null
	var best := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		var other := node as Hero
		if other == null or other == self or other.type == Heroes.Type.CLERIC or other.is_guardian():
			continue
		var distance := position.distance_to(other.position)
		if other.squad == squad and squad >= 0:
			distance *= 0.5 # Il suit d'abord son escouade.
		if distance < best:
			best = distance
			ally = other
	if ally == null:
		return false # Seul : il marche vers le cœur comme les autres.
	if position.distance_to(ally.position) <= 56.0:
		path.clear()
		return true
	follow_path(map.find_hero_path_to(current_cell(), ally.current_cell(), _avoided_traps(), _path_weights()))
	if path.is_empty():
		return false
	_walk_or_dig(delta)
	return true


## Objectif « piller le Trésor » : au coffre le plus proche, puis il s'enfuit avec l'or.
func _raid_mission(delta: float) -> bool:
	if loot > 0:
		start_fleeing(false)
		return true
	if _mission_cell == NO_CELL or int(map.stored_gold.get(_mission_cell, 0)) <= 0:
		_objective_timer -= delta
		if _objective_timer > 0.0:
			return false
		_objective_timer = 1.0
		_mission_cell = _nearest_cell(map.stored_gold.keys().filter(
				func(c: Vector2i) -> bool: return int(map.stored_gold[c]) > 0))
		path.clear()
		if _mission_cell == NO_CELL:
			objective = "" # Plus rien à piller : il marche sur le cœur.
			return false
	if current_cell() == _mission_cell:
		loot = map.steal_gold(_mission_cell, Rules.RAID_LOOT)
		_mission_cell = NO_CELL
		if loot > 0:
			play_attack()
			Sound.play("coins", position)
			Fx.burst("coins", position)
			stole.emit(self, loot)
			start_fleeing(false)
		return true
	return _go_toward(_mission_cell, delta)


## Objectif « saccager la Bibliothèque » : il frappe la salle jusqu'à la détruire.
func _wreck_mission(delta: float) -> bool:
	if map.get_room(current_cell()) == Rooms.Type.LIBRARY:
		_mission_cell = current_cell()
	if map.get_room(_mission_cell) != Rooms.Type.LIBRARY:
		_objective_timer -= delta
		if _objective_timer > 0.0:
			return false
		_objective_timer = 1.0
		var cells: Array = []
		for cell: Vector2i in map.rooms:
			if map.rooms[cell] == Rooms.Type.LIBRARY:
				cells.append(cell)
		_mission_cell = _nearest_cell(cells)
		path.clear()
		if _mission_cell == NO_CELL:
			objective = ""
			return false
	if current_cell() == _mission_cell:
		path.clear()
		if _attack_cooldown <= 0.0:
			_attack_cooldown = attack_interval
			show_strike(map.cell_to_world(_mission_cell) + Vector2(0, -8))
			if map.damage_room(_mission_cell, attack_damage * 2.0):
				objective = "" # La salle est détruite : maintenant, le cœur !
				_mission_cell = NO_CELL
		return true
	return _go_toward(_mission_cell, delta)


## Objectifs « chasser les ouvriers » et « abattre ta meilleure créature ».
func _is_hunting() -> bool:
	return objective == "workers" or objective == "assassinate"


func _hunt_mission(delta: float) -> bool:
	_objective_timer -= delta
	if not is_instance_valid(_prey) or _prey.is_dead() or not _prey.is_targetable():
		if _objective_timer > 0.0:
			return false
		_objective_timer = 1.0
		_prey = _find_prey()
		path.clear()
		if _prey == null:
			objective = ""
			return false
	if _objective_timer <= 0.0:
		_objective_timer = 1.5
		path.clear() # La proie bouge : on recalcule régulièrement.
	return _go_toward(_prey.current_cell(), delta)


func _find_prey() -> Unit:
	var best: Unit = null
	var best_score := -INF
	for node in get_tree().get_nodes_in_group("dungeon"):
		var unit := node as Unit
		if unit == null or not unit.is_targetable():
			continue
		var score := 0.0
		if objective == "workers":
			if not unit is Worker:
				continue
			score = -position.distance_to(unit.position) # Le plus proche.
		else:
			var creature := unit as Creature
			if creature == null:
				continue
			score = creature.level * 1000.0 + creature.max_hp # La plus forte.
		if score > best_score:
			best_score = score
			best = unit
	return best


## L'éclaireur : il avance vers le cœur en notant les pièges, puis rebrousse chemin.
func _scout_mission(delta: float) -> bool:
	_scout_time += delta
	_objective_timer -= delta
	if _objective_timer <= 0.0:
		_objective_timer = 0.4
		var here := current_cell()
		for cell: Vector2i in map.defenses:
			var kind: int = map.defenses[cell]["type"]
			if kind != Defenses.Type.SPIKES and kind != Defenses.Type.RUNE and kind != Defenses.Type.DOOR:
				continue
			if maxi(absi(cell.x - here.x), absi(cell.y - here.y)) <= Rules.SCOUT_SIGHT:
				seen_traps[cell] = true
	var depth := absi(current_cell().x - map.heart_cell.x) + absi(current_cell().y - map.heart_cell.y)
	if _scout_time >= Rules.SCOUT_TIME or depth <= Rules.SCOUT_DEPTH:
		start_fleeing(false) # Il en a assez vu : il repart faire son rapport.
		return true
	return false # (Il avance vers le cœur, comme les autres.)


func is_scout() -> bool:
	return objective == "scout"


## Avance vers une case (en creusant s'il le faut). Renvoie false si c'est impossible.
func _go_toward(cell: Vector2i, delta: float) -> bool:
	if path.is_empty():
		follow_path(map.find_hero_path_to(current_cell(), cell, _avoided_traps(), _path_weights()))
		if path.is_empty():
			return false
	_walk_or_dig(delta)
	return true


## La case la plus proche (en ligne droite) parmi une liste, ou NO_CELL.
func _nearest_cell(cells: Array) -> Vector2i:
	var best := NO_CELL
	var best_distance := INF
	for cell: Vector2i in cells:
		var distance := position.distance_to(map.cell_to_world(cell))
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


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
		if ally == null or ally.position.distance_to(position) > Heroes.CLERIC_HEAL_RADIUS:
			continue
		if ally.hp < ally.max_hp:
			ally.heal(Heroes.CLERIC_HEAL_AMOUNT)
			healed = true
		# Il libère aussi ses alliés de la Toile et de la Terreur du maître.
		if (ally.is_webbed() or (ally is Hero and (ally as Hero).is_terrified())) and ally.dispel():
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
	map.damage_door(cell, attack_damage * Heroes.info(type).get("door_damage", 1.0), self)


func _march(delta: float) -> void:
	if map.is_next_to_heart(current_cell()):
		path.clear()
		_attack_heart()
		return

	if path.is_empty():
		if role == "sapper":
			follow_path(map.find_sapper_path(current_cell())) # Un tunnel tout droit vers le cœur.
		else:
			follow_path(map.find_hero_path(current_cell(), _avoided_traps(), _path_weights()))
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
	var status := ""
	if fleeing:
		status = "fuit !"
	elif _terror_left > 0.0:
		status = "terrifié !"
	elif is_webbed():
		status = "englué"
	if status != "":
		text = (text + " " + status) if text != "" else status
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

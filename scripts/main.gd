extends Node2D
## Le « chef d'orchestre » du jeu : il relie la carte, la caméra, l'interface,
## les ouvriers et les créatures. Il gère aussi :
##   - l'outil choisi quand on touche la carte ;
##   - l'arrivée des créatures par le portail ;
##   - le jour de paie ;
##   - les vagues de héros et la fin de partie ;
##   - la sauvegarde, le chargement et la pause ;
##   - la mana et les sorts, la recherche et la fabrication des pièges ;
##   - le niveau de campagne en cours : objectif, victoire, maître rival.
##
## Les différentes parties communiquent par des SIGNAUX : la caméra ne connaît
## pas la carte, elle dit juste « on m'a touchée ici ». C'est main.gd qui décide
## quoi en faire. Ainsi chaque script reste simple et indépendant.

## Les principaux réglages viennent de scripts/rules.gd (les règles du jeu en un seul endroit).
const START_GOLD := 200
const START_WORKERS := Rules.START_WORKERS
const WORKER_COST := Rules.WORKER_COST
## Secondes entre deux arrivées de créatures (si le donjon les attire).
const CREATURE_ARRIVAL_DELAY := Rules.CREATURE_ARRIVAL_DELAY
## Secondes entre deux jours de paie.
const PAYDAY_INTERVAL := Rules.PAYDAY_INTERVAL
## Délai minimum entre deux messages d'aide.
const HINT_DELAY := 15.0
## Secondes avant la première vague de héros, puis entre deux vagues.
const FIRST_WAVE_DELAY := 180.0
const WAVE_INTERVAL := 120.0
## Secondes entre l'arrivée de deux héros d'une même vague.
const HERO_SPAWN_GAP := 1.5
## Nombre maximum de héros par vague.
const MAX_HEROES_PER_WAVE := 8
## Nombre d'unités que la main du maître peut tenir à la fois.
const HAND_CAPACITY := 8
## Secondes entre deux sauvegardes automatiques.
const AUTOSAVE_INTERVAL := Rules.AUTOSAVE_INTERVAL
const MENU_SCENE := "res://scenes/menu.tscn"

## Quelle salle construit chaque outil de la barre.
const TOOL_ROOMS := {
	Hud.Tool.TREASURY: Rooms.Type.TREASURY,
	Hud.Tool.LAIR: Rooms.Type.LAIR,
	Hud.Tool.FARM: Rooms.Type.FARM,
	Hud.Tool.LIBRARY: Rooms.Type.LIBRARY,
	Hud.Tool.WORKSHOP: Rooms.Type.WORKSHOP,
	Hud.Tool.TRAINING: Rooms.Type.TRAINING,
	Hud.Tool.PRISON: Rooms.Type.PRISON,
	Hud.Tool.TEMPLE: Rooms.Type.TEMPLE,
	Hud.Tool.GRAVEYARD: Rooms.Type.GRAVEYARD,
}
## Points de recherche par seconde qu'apporte chaque prisonnier interrogé.
const PRISONER_RESEARCH := Rules.PRISONER_RESEARCH
## Quel sort lance chaque bouton du panneau de gauche.
const TOOL_SPELLS := {
	Hud.Tool.SPELL_HEAL: Spells.Type.HEAL,
	Hud.Tool.SPELL_LIGHTNING: Spells.Type.LIGHTNING,
	Hud.Tool.SPELL_HASTE: Spells.Type.HASTE,
}
## L'atelier arrête de fabriquer quand le stock total atteint ce nombre.
const MAX_TRAP_STOCK := Rules.MAX_TRAP_STOCK
const MAX_ALTARS := Rules.MAX_ALTARS
## Quelle défense pose chaque outil de la barre.
const TOOL_DEFENSES := {
	Hud.Tool.SPIKES: Defenses.Type.SPIKES,
	Hud.Tool.RUNE: Defenses.Type.RUNE,
	Hud.Tool.DOOR: Defenses.Type.DOOR,
	Hud.Tool.ALTAR: Defenses.Type.ALTAR,
}

## Le monde incliné en vue isométrique (voir iso.gd) : la carte et toutes les unités.
@onready var world_root: Node2D = $World
@onready var map: DungeonMap = $World/DungeonMap
@onready var workers_root: Node2D = $World/Workers
@onready var creatures_root: Node2D = $World/Creatures
@onready var heroes_root: Node2D = $World/Heroes
@onready var effects_root: Node2D = $FxLayer/Effects
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $HUD

var current_tool: int = Hud.Tool.DIG
## Les unités tenues dans la main. On dépose toujours la dernière ramassée.
var hand: Array[Unit] = []

var _portal_connected := false
var _portal_check_timer := 0.0
var _arrival_timer := 5.0
var _payday_timer := PAYDAY_INTERVAL
var _hint_timer := 0.0
var _hud_timer := 0.0

## Le niveau joué (voir levels.gd) et ses réglages.
var level: Dictionary = Levels.FREE_PLAY
var _wave_interval := WAVE_INTERVAL
var _goal_timer := 0.0
var _rival_timer := 80.0
var _rival_squads := 0

var _wave_timer := FIRST_WAVE_DELAY
var _next_wave := 1
var _waves_survived := 0
var _wave_in_progress := false
var _wave_warned := false
var _pending_heroes: Array[int] = []
var _hero_spawn_timer := 0.0
## Nombre de Champions du royaume vaincus (objectif du niveau 9).
var _champions_defeated := 0
var _grave_timer := 0.0

## La recherche de la Bibliothèque (voir research.gd).
var research := Research.new()
var mana := Spells.START_MANA
## Points de fabrication accumulés par l'Atelier vers le prochain piège.
var workshop_points := 0.0
## Pièges et portes fabriqués, prêts à être posés : Defenses.Type -> nombre.
var trap_stock := {Defenses.Type.SPIKES: 0, Defenses.Type.RUNE: 0, Defenses.Type.DOOR: 0, Defenses.Type.ALTAR: 0}

var _autosave_timer := AUTOSAVE_INTERVAL
var _game_over := false

# Peinture au doigt (voir camera_controller.gd) : cases déjà traitées pendant ce geste.
var _paint_active := false
var _paint_cells := {}
var _paint_mark := true
var _paint_failed := false
## Position à l'écran du dernier toucher (pour savoir quel personnage est touché).
var _screen_tap := Vector2.ZERO

## Éclairage (voir _setup_lighting).
const DARKNESS := Color(0.42, 0.38, 0.48) ## La pénombre du donjon (1, 1, 1 = pleine lumière).
const MAX_TORCHES := 24
## Écart minimum entre deux torches, en cases.
const TORCH_SPACING := 4
var _canvas_modulate: CanvasModulate
var _lights_root: Node2D
var _heart_light: PointLight2D
var _rival_light: PointLight2D
var _torches := {} ## case -> lumière
var _torch_timer := 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	# La vue isométrique : tout le monde est incliné par cette transformation.
	world_root.transform = Iso.TRANSFORM
	camera.world_transform = Iso.TRANSFORM
	Sound.world_transform = Iso.TRANSFORM
	Fx.layer = effects_root
	Fx.world = world_root
	Fx.camera = camera
	Sound.reset_music_volume() # Au cas où la défaite l'avait baissée.
	# On branche les signaux sur nos fonctions.
	map.gold_changed.connect(_refresh_hud)
	camera.tapped.connect(_on_camera_tapped)
	camera.paint_started.connect(_on_paint_started)
	camera.painted.connect(func(screen_world_position: Vector2) -> void:
		if _paint_active:
			_paint_cell(map.world_to_cell(_to_map(screen_world_position))))
	camera.paint_ended.connect(func() -> void: _paint_active = false)
	hud.summon_pressed.connect(_on_summon_pressed)
	hud.tool_selected.connect(_on_tool_selected)
	hud.restart_pressed.connect(_on_restart_pressed)
	map.heart_changed.connect(_on_heart_changed)
	map.heart_destroyed.connect(_on_heart_destroyed)
	map.rival_heart_destroyed.connect(func() -> void:
		hud.show_message("Le cœur du maître rival est détruit !", 5.0)
		_check_goal())
	hud.next_level_pressed.connect(_on_next_level_pressed)
	map.door_destroyed.connect(func(_cell: Vector2i) -> void:
		hud.show_message("Les héros ont enfoncé une porte !", 3.0))
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.resume_pressed.connect(_on_resume_pressed)
	hud.save_pressed.connect(func() -> void:
		if save_game():
			hud.show_message("Partie sauvegardée."))
	hud.menu_pressed.connect(_on_menu_pressed)
	research.discovered.connect(_on_research_discovered)

	camera.bounds = _iso_bounds()
	camera.paint_mode = true # L'outil de départ est « Creuser ».
	hud.add_minimap(map, camera)
	camera.center_on(map.cell_to_world(map.heart_cell))
	hud.set_summon_cost(WORKER_COST)

	# Le menu a demandé de continuer la partie sauvegardée ?
	var loaded := false
	if SaveGame.load_requested:
		SaveGame.load_requested = false
		loaded = _load_game(SaveGame.read())
		if not loaded:
			hud.show_message("Impossible de lire la sauvegarde : nouvelle partie.", 5.0)
	if not loaded:
		_start_new_game()
	_refresh_hud()
	_setup_lighting()
	hud.fade_in()


func _start_new_game() -> void:
	level = Levels.current()
	# Chaque niveau a sa propre carte (une « graine » fixe). 0 = carte au hasard.
	var seed_value: int = level.get("seed", 0)
	if seed_value == 0:
		seed_value = randi()
	map.generate(seed_value, level.get("rival", false), level.get("rival_hp", 1200.0))
	map.set_starting_gold(level.get("start_gold", START_GOLD))
	_wave_timer = level.get("first_wave", FIRST_WAVE_DELAY)
	_wave_interval = level.get("wave_interval", WAVE_INTERVAL)
	_rival_timer = level.get("rival_interval", 80.0)
	for i in START_WORKERS:
		_spawn_worker()
	var intro: String = level.get("intro", "")
	hud.show_message(intro + " Creuse jusqu'au portail violet pour attirer des créatures.", 10.0)


func _process(delta: float) -> void:
	_update_lighting(delta)
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_INTERVAL
		save_game()

	# La mana se recharge, plus vite avec un grand territoire.
	mana = minf(Spells.MAX_MANA, mana + Spells.regen_per_second(map.claimed.size()) * delta)
	# On dit aux créatures s'il reste quelque chose à chercher ou à fabriquer.
	Creature.research_needed = not research.is_done()
	Creature.workshop_needed = _workshop_target() >= 0
	# Les prisonniers interrogés font avancer la recherche.
	research.add_points(map.prisoners.size() * PRISONER_RESEARCH * delta)

	_hint_timer -= delta
	_update_portal(delta)
	_update_payday(delta)
	_update_waves(delta)
	_update_rival(delta)
	_update_graves(delta)
	_goal_timer -= delta
	if _goal_timer <= 0.0:
		_goal_timer = 1.0
		_check_goal()
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
	var type := _choose_arrival(Creatures.attracted_types(map))
	if type < 0:
		return
	_spawn_creature(type)


## Le portail équilibré : chaque espèce attirée reçoit un « poids » (ses chances),
## plus petit si tu en as déjà beaucoup. Les espèces limitées (le Cerbère) ne
## viennent plus une fois leur limite atteinte. Renvoie -1 si personne ne vient.
func _choose_arrival(types: Array[int]) -> int:
	var counts := {}
	for creature: Creature in creatures_root.get_children():
		counts[creature.type] = counts.get(creature.type, 0) + 1
	var weights := {}
	var total := 0.0
	for type in types:
		var info := Creatures.info(type)
		var count: int = counts.get(type, 0)
		if info.has("limit_room"):
			var allowed := mini(map.count_room_tiles(info["limit_room"]) / int(info["limit_per"]), info["limit_max"])
			if count >= allowed:
				continue
		var weight := 1.0 / pow(count + 1.0, Rules.PORTAL_BALANCE)
		if info.get("catcher", false) and count == 0 and map.count_room_tiles(Rooms.Type.PRISON) > 0:
			weight *= Rules.CATCHER_PRIORITY
		weights[type] = weight
		total += weight
	if total <= 0.0:
		return -1
	var roll := randf() * total
	for type: int in weights:
		roll -= weights[type]
		if roll <= 0.0:
			return type
	return weights.keys().back()


func _spawn_creature(type: int) -> void:
	var creature := _add_creature(type, map.portal_cell)
	Sound.play("portal", map.cell_to_world(map.portal_cell))
	hud.show_message("%s arrive par le portail ! (salaire : %d or)" % [creature.display_name(), creature.salary()])


## Crée une créature sur une case (sert aussi au chargement d'une partie).
func _add_creature(type: int, cell: Vector2i) -> Creature:
	var creature := Creature.new()
	creature.setup_creature(map, cell, type)
	creature.left_dungeon.connect(_on_creature_left)
	creature.died.connect(_on_creature_died)
	creature.worked.connect(_on_creature_worked)
	creature.sacrificed.connect(_on_creature_sacrificed)
	creature.leveled_up.connect(func(c: Creature) -> void:
		Sound.play("level_up", c.position)
		hud.show_message("%s passe au niveau %d !" % [c.display_name(), c.level], 3.0))
	creatures_root.add_child(creature)
	return creature


# ---------------------------------------------------------------------------
# Bibliothèque (recherche) et Atelier (fabrication)
# ---------------------------------------------------------------------------

func _on_creature_worked(room_type: int, amount: float) -> void:
	if room_type == Rooms.Type.LIBRARY:
		research.add_points(amount)
	elif room_type == Rooms.Type.WORKSHOP:
		_add_workshop_points(amount)
	elif room_type == Rooms.Type.TEMPLE:
		mana = minf(Spells.MAX_MANA, mana + amount)


func _on_research_discovered(item: Dictionary) -> void:
	Sound.play("discovery")
	hud.show_message("Découverte : %s ! Regarde ta barre d'outils." % item["name"], 5.0)


## Le piège que l'atelier fabrique en ce moment : le moins nombreux parmi ceux
## déjà découverts. Renvoie -1 s'il n'y a rien à fabriquer.
func _workshop_target() -> int:
	# L'autel de sacrifice passe en premier tant qu'on n'en a aucun (posé ou en stock).
	var altars: int = trap_stock[Defenses.Type.ALTAR] + map.count_defenses(Defenses.Type.ALTAR)
	if altars == 0:
		return Defenses.Type.ALTAR
	var total := 0
	for type: int in trap_stock:
		if type != Defenses.Type.ALTAR:
			total += trap_stock[type]
	var best := -1
	for type: int in trap_stock:
		if type == Defenses.Type.ALTAR:
			if altars >= MAX_ALTARS:
				continue
		elif total >= MAX_TRAP_STOCK or not research.is_unlocked("defense", type):
			continue
		if best < 0 or trap_stock[type] < trap_stock[best]:
			best = type
	return best


func _add_workshop_points(amount: float) -> void:
	var target := _workshop_target()
	if target < 0:
		return
	workshop_points += amount
	var cost := Defenses.cost(target)
	if workshop_points >= cost:
		workshop_points -= cost
		trap_stock[target] += 1
		Sound.play("trap_place", null, -4.0)
		hud.show_message("L'atelier a fabriqué : %s." % Defenses.display_name(target), 3.0)


# ---------------------------------------------------------------------------
# Sorts du maître
# ---------------------------------------------------------------------------

func _cast_spell(type: int, world_position: Vector2) -> void:
	var info: Dictionary = Spells.INFO[type]
	if mana < info["mana"]:
		_fail("Pas assez de mana : %s coûte %d." % [info["name"], info["mana"]])
		return
	var cast := false
	match type:
		Spells.Type.HEAL:
			for unit in _units_near("dungeon", world_position, info["radius"]):
				unit.heal(info["amount"])
				Fx.burst("heal", unit.position) # Des étincelles vertes montent de chaque unité.
				cast = true
		Spells.Type.LIGHTNING:
			for unit in _units_near("heroes", world_position, info["radius"]):
				Fx.lightning(unit.position) # Un éclair tombe sur chaque héros touché.
				unit.take_damage(info["damage"])
				cast = true
		Spells.Type.HASTE:
			var targets := _units_near("dungeon", world_position, 20.0)
			if not targets.is_empty():
				targets[0].apply_haste(info["duration"])
				Fx.burst("haste", targets[0].position)
				cast = true
	if not cast:
		_fail("Aucune cible ici : touche %s." % (
				"un héros" if type == Spells.Type.LIGHTNING else "une de tes unités"))
		return
	mana -= info["mana"]
	Sound.play(["heal", "lightning", "haste"][type], world_position)
	map.add_effect(world_position, info.get("radius", 24.0), info["color"])
	var spell_color: Color = info["color"]
	Fx.burst("magic", world_position, Color(spell_color, 1.0))
	Fx.flash_light(world_position, Color(spell_color, 1.0), 160.0)
	if type == Spells.Type.LIGHTNING:
		Fx.shake(6.0)


## Les unités d'un groupe (« dungeon » ou « heroes ») à moins de radius pixels.
func _units_near(group: String, world_position: Vector2, radius: float) -> Array[Unit]:
	var result: Array[Unit] = []
	for node in get_tree().get_nodes_in_group(group):
		var unit := node as Unit
		if unit != null and not unit.is_dead() and unit.position.distance_to(world_position) <= radius:
			result.append(unit)
	return result


func _on_creature_left(creature: Creature) -> void:
	Sound.play("leave", creature.position)
	hud.show_message("%s, mécontent, quitte ton donjon !" % creature.display_name(), 5.0)


func _on_creature_died(unit: Unit) -> void:
	hud.show_message("Ton %s est mort au combat !" % (unit as Creature).display_name(), 4.0)


# ---------------------------------------------------------------------------
# Vagues de héros
# ---------------------------------------------------------------------------

func _update_waves(delta: float) -> void:
	# Les héros d'une vague entrent un par un.
	if not _pending_heroes.is_empty():
		_hero_spawn_timer -= delta
		if _hero_spawn_timer <= 0.0:
			_hero_spawn_timer = HERO_SPAWN_GAP
			_spawn_hero(_pending_heroes.pop_front())
	elif _wave_in_progress and get_tree().get_nodes_in_group("heroes").is_empty():
		# Plus aucun héros vivant : la vague est repoussée.
		_wave_in_progress = false
		_waves_survived += 1
		Sound.play("discovery")
		hud.show_message("Vague repoussée ! Bravo, ton donjon tient bon.", 5.0)

	_wave_timer -= delta
	if _wave_timer <= 10.0 and not _wave_warned:
		_wave_warned = true
		Sound.play("horn", null, -12.0)
		hud.show_message("Des héros approchent de l'entrée grise ! Prépare tes créatures.", 5.0)
	if _wave_timer > 0.0:
		return
	_start_wave()


func _start_wave() -> void:
	_wave_timer = _wave_interval
	_wave_warned = false
	var count := mini(1 + _next_wave, MAX_HEROES_PER_WAVE)
	var types := Heroes.types_for_wave(_next_wave)
	for i in count:
		_pending_heroes.append(types.pick_random())
	_hero_spawn_timer = 0.0
	_wave_in_progress = true
	Sound.play("horn")
	if _champion_leads_wave(_next_wave):
		_pending_heroes.push_front(Heroes.Type.CHAMPION) # Il entre le premier.
		Fx.shake(5.0, 0.5)
		hud.show_message("Vague %d : le CHAMPION DU ROYAUME mène %d héros contre toi !" % [_next_wave, count], 6.0)
	else:
		hud.show_message("Vague %d : %d héros entrent dans ton donjon !" % [_next_wave, count], 5.0)
	_next_wave += 1


## Le Champion mène-t-il cette vague ? Par défaut, une vague sur Heroes.CHAMPION_EVERY.
## Un niveau peut choisir sa vague (« champion_wave ») : il revient alors à chaque
## vague suivante tant qu'il n'a pas été vaincu.
func _champion_leads_wave(wave: int) -> bool:
	var champion_wave: int = level.get("champion_wave", 0)
	if champion_wave <= 0:
		return wave % Heroes.CHAMPION_EVERY == 0
	if wave < champion_wave or _champions_defeated > 0:
		return false
	for node in heroes_root.get_children():
		if node is Hero and (node as Hero).type == Heroes.Type.CHAMPION:
			return false # Il est encore dans le donjon.
	return true


func _spawn_hero(type: int) -> void:
	_add_hero(type, map.entrance_cell)


func _add_hero(type: int, cell: Vector2i) -> Hero:
	var hero := Hero.new()
	hero.setup_hero(map, cell, type)
	hero.died.connect(_on_hero_died)
	hero.captured.connect(_on_hero_captured)
	hero.fell.connect(func(_hero: Hero) -> void:
		_hint("Un héros est assommé ! Tes Attrapeurs de cauchemar vont l'emmener en prison."))
	hero.stole.connect(func(thief: Hero, amount: int) -> void:
		Sound.play("horn", thief.position, -14.0)
		hud.show_message("Une Voleuse a pillé ton Trésor : %d or ! Arrête-la avant qu'elle ne sorte !" % amount, 5.0))
	hero.escaped.connect(func(_thief: Hero, amount: int) -> void:
		Sound.play("error")
		hud.show_message("La Voleuse s'est enfuie avec %d or. Un Cerbère au Trésor l'aurait flairée..." % amount, 5.0))
	hero.freed_prisoner.connect(func(prisoner: Hero) -> void:
		hud.show_message("Un Moine a ouvert une cellule : %s s'évade !" % prisoner.display_name(), 4.0))
	heroes_root.add_child(hero)
	return hero


## Un Attrapeur a conduit un prisonnier à l'autel : le sacrifice rapporte de l'or.
func _on_creature_sacrificed(hero: Hero) -> void:
	var gold: int = hero.reward() * Rules.SACRIFICE_GOLD_MULTIPLIER
	var stored := map.add_gold_to_treasury(gold)
	Sound.play("sacrifice", hero.position)
	Fx.burst("magic", hero.position, Color("ff1744"))
	Fx.flash_light(hero.position, Color(1.0, 0.15, 0.1), 180.0, 0.8)
	Fx.shake(4.0, 0.3)
	if stored < gold:
		hud.show_message("%s est sacrifié : +%d or (%d perdus, plus de place au Trésor)." %
				[hero.display_name(), stored, gold - stored], 4.0)
	else:
		hud.show_message("%s est sacrifié : +%d or !" % [hero.display_name(), stored], 4.0)


## Outil Sacrifier : toucher un prisonnier le désigne (ou annule) pour l'autel.
func _request_sacrifice(world_position: Vector2) -> void:
	var hero := _unit_at(world_position, heroes_root) as Hero
	if hero == null or not hero.is_captured():
		_fail("Touche un héros prisonnier, dans sa cellule.")
		return
	if map.altar_cells().is_empty():
		_fail("Pose d'abord un Autel de sacrifice (l'Atelier le fabrique).")
		return
	if get_tree().get_nodes_in_group("catchers").is_empty():
		_fail("Il faut un Attrapeur de cauchemar pour conduire le prisonnier à l'autel.")
		return
	hero.sacrifice_requested = not hero.sacrifice_requested
	Sound.play("click")
	if hero.sacrifice_requested:
		hud.show_message("%s sera conduit à l'autel par un Attrapeur." % hero.display_name())
	else:
		hud.show_message("Sacrifice annulé.")


## Un héros vaincu finit en Prison : il rapporte sa rançon, et sera interrogé.
func _on_hero_captured(hero: Hero) -> void:
	if hero.type == Heroes.Type.CHAMPION:
		_champions_defeated += 1
	var stored := map.add_gold_to_treasury(hero.reward())
	hud.show_message("%s capturé ! +%d or de rançon. Interrogé, il fera avancer la recherche." %
			[hero.display_name(), stored], 4.0)


## Un héros vaincu rapporte une rançon, rangée au trésor s'il y a de la place.
func _on_hero_died(unit: Unit) -> void:
	var hero := unit as Hero
	if hero.type == Heroes.Type.CHAMPION:
		_champions_defeated += 1
		Fx.shake(8.0, 0.5)
		hud.show_message("Le Champion du royaume est tombé ! Sa rançon est immense.", 5.0)
	_bury(hero)
	if hero.no_ransom:
		return # Sacrifié : l'or a déjà été donné.
	var stored := map.add_gold_to_treasury(hero.reward())
	if stored > 0:
		Sound.play("coins", null, -6.0)
		hud.show_message("%s vaincu ! +%d or de rançon." % [hero.display_name(), stored], 3.0)
	else:
		hud.show_message("%s vaincu ! Sa rançon est perdue : pas de place au Trésor." % hero.display_name(), 3.0)


## Un héros mort est enterré au Cimetière, s'il y a une tombe libre.
func _bury(hero: Hero) -> void:
	if Heroes.info(hero.type).get("rival", false):
		return # Les troupes du rival ne sont pas des héros.
	var grave := map.bury()
	if grave == Vector2i(-1, -1):
		return
	var grave_position := map.cell_to_world(grave)
	Fx.burst("dust", grave_position)
	Fx.burst("magic", grave_position, Color("76ff03"))
	_hint("%s est enterré au Cimetière. Bientôt, il se relèvera en Revenant !" % hero.display_name())


## Les héros enterrés se relèvent en Revenants (il faut un lit libre au Repaire).
func _update_graves(delta: float) -> void:
	_grave_timer -= delta
	if _grave_timer > 0.0:
		return
	_grave_timer = 1.0
	for cell in map.ready_graves():
		if creatures_root.get_child_count() >= map.count_room_tiles(Rooms.Type.LAIR):
			_hint("Un Revenant attend un lit libre au Repaire pour se relever.")
			return
		map.empty_grave(cell)
		var revenant := _add_creature(Creatures.Type.REVENANT, cell)
		Sound.play("portal", revenant.position, -4.0)
		Fx.burst("magic", revenant.position, Color("76ff03"))
		Fx.burst("dust", revenant.position)
		Fx.flash_light(revenant.position, Color(0.5, 1.0, 0.3), 140.0, 0.6)
		hud.show_message("Un Revenant se relève du Cimetière pour te servir !", 4.0)


func _on_heart_changed() -> void:
	_hint("Ton cœur est attaqué ! Envoie tes créatures le défendre.")


func _on_heart_destroyed() -> void:
	_game_over = true
	SaveGame.delete() # Une partie perdue ne se reprend pas !
	get_tree().paused = true # Tout s'arrête, sauf l'interface (voir hud.gd).
	Sound.set_music_volume(-20.0)
	Sound.play("game_over")
	hud.show_game_over(_waves_survived)


# ---------------------------------------------------------------------------
# Objectif du niveau, victoire et maître rival
# ---------------------------------------------------------------------------

## Avancement de l'objectif : [valeur actuelle, valeur à atteindre], ou [] en partie libre.
func _goal_progress() -> Array:
	if not level.has("goal"):
		return []
	var goal: Dictionary = level["goal"]
	match goal["type"]:
		"gold":
			return [map.get_total_gold(), goal["amount"]]
		"survive":
			return [_waves_survived, goal["waves"]]
		"creatures":
			var count := 0
			for creature: Creature in creatures_root.get_children():
				if creature.level >= goal["level"]:
					count += 1
			return [count, goal["count"]]
		"research":
			return [research.next_index, goal["count"]]
		"prisoners":
			return [map.prisoners.size(), goal["count"]]
		"champion":
			return [_champions_defeated, 1]
		"rival":
			var damage_done := map.rival_heart_max_hp - map.rival_heart_hp
			return [roundi(100.0 * damage_done / map.rival_heart_max_hp), 100]
	return []


func _goal_status_text() -> String:
	var progress := _goal_progress()
	if progress.is_empty():
		return "Partie libre"
	var suffix := " %" if level["goal"]["type"] == "rival" else ""
	return "Objectif : %s\n(%d%s / %d%s)" % [Levels.goal_text(level), progress[0], suffix, progress[1], suffix]


func _check_goal() -> void:
	if _game_over:
		return
	var progress := _goal_progress()
	if not progress.is_empty() and progress[0] >= progress[1]:
		_on_victory()


## Objectif atteint ! Les étoiles dépendent de l'état du cœur.
func _on_victory() -> void:
	_game_over = true # Plus de sauvegarde automatique : la partie est finie.
	SaveGame.delete()
	var health := map.heart_hp / DungeonMap.HEART_MAX_HP
	var stars := 3 if health >= 0.9 else (2 if health >= 0.5 else 1)
	Levels.record_victory(level.get("id", 0), stars)
	Engine.time_scale = 1.0
	get_tree().paused = true
	Sound.play("discovery")
	Sound.play("level_up")
	hud.show_victory(level.get("name", ""), stars, Levels.has_next(level.get("id", 0)))


func _on_next_level_pressed() -> void:
	Levels.current_id = level.get("id", 0) + 1
	SaveGame.load_requested = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


## Le maître rival envoie régulièrement des troupes de plus en plus nombreuses.
func _update_rival(delta: float) -> void:
	if not map.has_rival or map.rival_heart_hp <= 0.0:
		return
	_rival_timer -= delta
	if _rival_timer > 0.0:
		return
	_rival_timer = level.get("rival_interval", 80.0)
	_rival_squads += 1
	var types: Array[int] = [Heroes.Type.RIVAL_KOBOLD]
	if _rival_squads >= 3:
		types.append(Heroes.Type.RIVAL_ORC)
	if _rival_squads >= 5:
		types.append(Heroes.Type.RIVAL_WARLOCK)
	var spawn_cells: Array[Vector2i] = []
	for direction in DungeonMap.DIRECTIONS:
		if map.is_walkable(map.rival_heart_cell + direction):
			spawn_cells.append(map.rival_heart_cell + direction)
	if spawn_cells.is_empty():
		return
	var count := mini(1 + int(_rival_squads * 0.5), 6)
	for i in count:
		_add_hero(types.pick_random(), spawn_cells.pick_random())
	Sound.play("portal", map.cell_to_world(map.rival_heart_cell))
	hud.show_message("Le maître rival envoie %d de ses créatures vers ton cœur !" % count, 4.0)


func _on_restart_pressed() -> void:
	SaveGame.load_requested = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ---------------------------------------------------------------------------
# Pause, sauvegarde et chargement
# ---------------------------------------------------------------------------

func _on_pause_pressed() -> void:
	if _game_over:
		return
	get_tree().paused = true
	hud.hide_message()
	hud.show_pause_menu()


func _on_resume_pressed() -> void:
	hud.hide_pause_menu()
	get_tree().paused = false


func _on_menu_pressed() -> void:
	save_game() # Ne fait rien si la partie est perdue.
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MENU_SCENE)


## Godot prévient le jeu quand l'appli passe en arrière-plan (Android) ou quand
## on ferme la fenêtre : on sauvegarde pour ne rien perdre.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_game()


## Écrit toute la partie dans le fichier de sauvegarde. Renvoie true si c'est réussi.
func save_game() -> bool:
	if _game_over or not is_node_ready():
		return false
	var workers := []
	for worker: Worker in workers_root.get_children():
		if not worker.is_dead():
			workers.append(worker.to_save())
	var creatures := []
	for creature: Creature in creatures_root.get_children():
		if not creature.is_dead() and not creature.is_leaving():
			creatures.append(creature.to_save())
	var heroes := []
	for hero: Hero in heroes_root.get_children():
		if not hero.is_dead():
			heroes.append(hero.to_save())

	var data := {
		"version": SaveGame.VERSION,
		"level_id": level.get("id", 0),
		"summary": {
			"wave": _next_wave,
			"level_name": level.get("name", ""),
			"gold": map.get_total_gold(),
			"date": Time.get_datetime_string_from_system(false, true),
		},
		"map": map.to_save(),
		"workers": workers,
		"creatures": creatures,
		"heroes": heroes,
		"state": {
			"payday_timer": _payday_timer,
			"wave_timer": _wave_timer,
			"next_wave": _next_wave,
			"waves_survived": _waves_survived,
			"wave_in_progress": _wave_in_progress,
			"pending_heroes": _pending_heroes,
			"arrival_timer": _arrival_timer,
			"portal_connected": _portal_connected,
			"rival_timer": _rival_timer,
			"rival_squads": _rival_squads,
			"champions_defeated": _champions_defeated,
		},
		"camera": [camera.position.x, camera.position.y, camera.zoom.x],
		"research": research.to_save(),
		"mana": mana,
		"workshop_points": workshop_points,
		"trap_stock": [trap_stock[Defenses.Type.SPIKES], trap_stock[Defenses.Type.RUNE],
				trap_stock[Defenses.Type.DOOR], trap_stock[Defenses.Type.ALTAR]],
	}
	return SaveGame.write(data)


## Recrée la partie à partir d'une sauvegarde. Renvoie false si elle est inutilisable.
func _load_game(data: Dictionary) -> bool:
	if data.is_empty() or not map.load_save(data["map"]):
		return false

	for values in data["workers"]:
		var worker := _add_worker(SaveGame.array_to_cell(values["cell"]))
		worker.hp = float(values["hp"])
		worker.carried_gold = int(values["gold"])
	for values in data["creatures"]:
		var creature := _add_creature(int(values["type"]), SaveGame.array_to_cell(values["cell"]))
		creature.load_save(values)
	for values in data["heroes"]:
		var hero := _add_hero(int(values["type"]), SaveGame.array_to_cell(values["cell"]))
		if values.has("prison"):
			hero.capture_at(SaveGame.array_to_cell(values["prison"]))
			hero.sacrifice_requested = bool(values.get("sacrifice", false))
		elif values.has("knocked_out"):
			hero.fall_down(float(values["knocked_out"]))
		hero.hp = float(values["hp"])
		hero.loot = int(values.get("loot", 0))

	Levels.current_id = int(data.get("level_id", 0))
	level = Levels.current()
	_wave_interval = level.get("wave_interval", WAVE_INTERVAL)
	var state: Dictionary = data["state"]
	_rival_timer = float(state.get("rival_timer", level.get("rival_interval", 80.0)))
	_rival_squads = int(state.get("rival_squads", 0))
	_champions_defeated = int(state.get("champions_defeated", 0))
	_payday_timer = float(state["payday_timer"])
	_wave_timer = float(state["wave_timer"])
	_next_wave = int(state["next_wave"])
	_waves_survived = int(state["waves_survived"])
	_wave_in_progress = bool(state["wave_in_progress"])
	_arrival_timer = float(state["arrival_timer"])
	_portal_connected = bool(state["portal_connected"])
	_pending_heroes.clear()
	for type in state["pending_heroes"]:
		_pending_heroes.append(int(type))

	research.load_save(data.get("research", {}))
	mana = float(data.get("mana", Spells.START_MANA))
	workshop_points = float(data.get("workshop_points", 0.0))
	var stock: Array = data.get("trap_stock", [0, 0, 0])
	trap_stock[Defenses.Type.SPIKES] = int(stock[0])
	trap_stock[Defenses.Type.RUNE] = int(stock[1])
	trap_stock[Defenses.Type.DOOR] = int(stock[2])
	trap_stock[Defenses.Type.ALTAR] = int(stock[3]) if stock.size() > 3 else 0

	var view: Array = data["camera"]
	camera.position = Vector2(float(view[0]), float(view[1]))
	camera.zoom = Vector2.ONE * float(view[2])
	hud.show_message("Partie chargée. Bon retour, Seigneur des Profondeurs !", 4.0)
	return true


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
		Sound.play("error")
		hud.show_message("Jour de paie : pas assez d'or ! %d créature(s) non payée(s), elles sont furieuses." % unpaid, 6.0)
	elif total_paid > 0:
		Sound.play("coins")
		hud.show_message("Jour de paie : %d or versés à tes créatures." % total_paid)


# ---------------------------------------------------------------------------
# Messages d'aide
# ---------------------------------------------------------------------------

## Un ordre impossible (pas assez d'or, de mana...) : petit son d'erreur + message.
func _fail(text: String, duration := 3.0) -> void:
	# Pendant un geste de peinture, un seul message d'erreur suffit.
	if _paint_active:
		if _paint_failed:
			return
		_paint_failed = true
	Sound.play("error")
	hud.show_message(text, duration)


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
	_add_worker(map.get_spawn_cell())


## Crée un ouvrier sur une case (sert aussi au chargement d'une partie).
func _add_worker(cell: Vector2i) -> Worker:
	var worker := Worker.new()
	worker.setup(map, cell)
	worker.died.connect(func(_unit: Unit) -> void:
		hud.show_message("Un ouvrier a été tué par les héros !", 3.0))
	workers_root.add_child(worker)
	return worker


func _refresh_hud() -> void:
	hud.set_gold(map.get_total_gold(), map.get_treasury_stored(), map.get_treasury_capacity())
	hud.set_workers(workers_root.get_child_count())
	hud.set_creatures(creatures_root.get_child_count(), map.count_room_tiles(Rooms.Type.LAIR))
	hud.set_payday(ceili(_payday_timer))
	hud.set_heart(map.heart_hp, DungeonMap.HEART_MAX_HP)
	hud.set_next_wave(_next_wave, ceili(_wave_timer))
	hud.set_mana(mana, Spells.MAX_MANA)
	hud.set_goal(_goal_status_text())
	var research_text := research.status_text()
	var workshop_target := _workshop_target()
	if workshop_target >= 0 and map.count_room_tiles(Rooms.Type.WORKSHOP) > 0:
		research_text += "\nAtelier : %s %d %%" % [Defenses.display_name(workshop_target),
				100.0 * workshop_points / Defenses.cost(workshop_target)]
	hud.set_research(research_text)
	_refresh_tools()


## Met à jour le texte des outils (prix, stock) et grise ceux pas encore découverts.
func _refresh_tools() -> void:
	for tool: int in TOOL_ROOMS:
		var room: int = TOOL_ROOMS[tool]
		var text := "%s (%d)" % [Rooms.display_name(room), Rooms.cost(room)]
		_set_tool(tool, text, Rooms.display_name(room), research.is_unlocked("room", room))
	for tool: int in TOOL_DEFENSES:
		var defense: int = TOOL_DEFENSES[tool]
		var text := "%s x%d" % [Defenses.display_name(defense), trap_stock[defense]]
		var unlocked := research.is_unlocked("defense", defense)
		if defense == Defenses.Type.ALTAR:
			unlocked = research.is_unlocked("room", Rooms.Type.WORKSHOP) # L'Atelier le fabrique.
		_set_tool(tool, text, Defenses.display_name(defense), unlocked)
	_set_tool(Hud.Tool.SACRIFICE, "Sacrifier", "Sacrifier", research.is_unlocked("room", Rooms.Type.WORKSHOP))
	for tool: int in TOOL_SPELLS:
		var spell: int = TOOL_SPELLS[tool]
		var text := "%s (%d)" % [Spells.display_name(spell), Spells.mana_cost(spell)]
		_set_tool(tool, text, Spells.display_name(spell), research.is_unlocked("spell", spell))


## Un outil pas encore découvert affiche « ? Nom » et ne peut pas être choisi.
func _set_tool(tool: int, text: String, name_text: String, unlocked: bool) -> void:
	if unlocked:
		hud.set_tool_state(tool, text, false)
	else:
		hud.set_tool_state(tool, "? " + name_text, true)


func _on_tool_selected(tool: int) -> void:
	current_tool = tool
	# Creuser, construire et démolir se font en glissant le doigt sur la carte.
	camera.paint_mode = tool == Hud.Tool.DIG or tool == Hud.Tool.DEMOLISH or TOOL_ROOMS.has(tool)
	if tool == Hud.Tool.HAND:
		hud.show_message("Touche une créature ou un ouvrier pour le prendre, puis touche le sol pour le déposer.", 5.0)
	elif tool == Hud.Tool.SPELL_HEAL:
		hud.show_message("Touche tes unités blessées pour les soigner.", 3.0)
	elif tool == Hud.Tool.SPELL_LIGHTNING:
		hud.show_message("Touche un héros pour le foudroyer.", 3.0)
	elif tool == Hud.Tool.SPELL_HASTE:
		hud.show_message("Touche une de tes unités pour qu'elle coure plus vite.", 3.0)


## Le doigt se pose en mode peinture.
# ---------------------------------------------------------------------------
# Éclairage
# ---------------------------------------------------------------------------
## Un CanvasModulate assombrit tout le monde du jeu (pas l'interface) ; des
## PointLight2D l'éclairent par endroits. Les lumières sont posées dans le monde
## incliné : leur halo rond devient une ellipse au sol, comme il se doit.
## L'éclairage se coupe dans les réglages (pour les téléphones modestes).

func _setup_lighting() -> void:
	if Fx.light_texture == null:
		Fx.light_texture = Fx.make_light_texture()
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.color = DARKNESS
	add_child(_canvas_modulate)
	_lights_root = Node2D.new()
	world_root.add_child(_lights_root)
	_heart_light = _make_light(map.cell_to_world(map.heart_cell), Color(1.0, 0.4, 0.35), 260.0, 1.3)
	_make_light(map.cell_to_world(map.portal_cell), Color(0.75, 0.4, 1.0), 200.0, 1.1)
	_make_light(map.cell_to_world(map.entrance_cell), Color(0.8, 0.85, 1.0), 170.0, 0.8)
	if map.has_rival:
		_rival_light = _make_light(map.cell_to_world(map.rival_heart_cell), Color(0.4, 0.6, 1.0), 240.0, 1.2)
	_refresh_torches()
	_apply_lighting_setting()


func _make_light(map_position: Vector2, color: Color, radius: float, energy: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = Fx.light_texture
	light.texture_scale = radius / 128.0
	light.color = color
	light.energy = energy
	light.position = map_position
	_lights_root.add_child(light)
	return light


func _update_lighting(delta: float) -> void:
	if _heart_light == null:
		return
	# Le cœur « bat » : sa lumière pulse, bien plus vite s'il vient d'être frappé.
	var attacked := Time.get_ticks_msec() - map.last_heart_hit_msec < 3000
	var beat_speed := 10.0 if attacked else 3.0
	_heart_light.energy = 1.2 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * beat_speed)
	if _rival_light != null and map.rival_heart_hp <= 0.0:
		_rival_light.energy = 0.0
	# Les flammes vacillent un peu (chaque torche à son rythme).
	var time := Time.get_ticks_msec() / 1000.0
	for cell: Vector2i in _torches:
		_torches[cell].energy = 0.85 + 0.12 * sin(time * 7.0 + cell.x * 1.7 + cell.y * 2.3)
	_torch_timer -= delta
	if _torch_timer <= 0.0:
		_torch_timer = 1.5
		_refresh_torches()
		_apply_lighting_setting()


## Des torches éclairent le territoire revendiqué, couloirs compris : on parcourt
## les cases dans l'ordre où elles ont été revendiquées (en partant du cœur), et on
## pose une torche sur chaque case à au moins TORCH_SPACING cases des autres.
## L'ordre ne change jamais : les torches déjà posées restent à leur place.
func _refresh_torches() -> void:
	var chosen: Array[Vector2i] = []
	for cell: Vector2i in map.claimed:
		if chosen.size() >= MAX_TORCHES:
			break
		if map.get_tile(cell) != DungeonMap.Tile.FLOOR:
			continue
		var far_enough := true
		for other in chosen:
			if maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < TORCH_SPACING:
				far_enough = false
				break
		if far_enough:
			chosen.append(cell)

	var wanted := {}
	for cell in chosen:
		wanted[cell] = true
	for cell: Vector2i in _torches.keys():
		if not wanted.has(cell):
			_torches[cell].queue_free()
			_torches.erase(cell)
	for cell: Vector2i in wanted:
		if not _torches.has(cell):
			_torches[cell] = _make_light(map.cell_to_world(cell), Color(1.0, 0.72, 0.4), 150.0, 0.9)
	map.set_torches(wanted) # Pour dessiner le brasero sur chaque case.


func _apply_lighting_setting() -> void:
	_canvas_modulate.visible = Sound.lighting_enabled
	_lights_root.visible = Sound.lighting_enabled


## La caméra donne des positions « à l'écran » (dans le monde incliné) :
## on les ramène en coordonnées de la carte, vues de dessus.
func _to_map(screen_world_position: Vector2) -> Vector2:
	return world_root.to_local(screen_world_position)


## Les limites de la caméra : le losange de la carte, vu à l'écran.
func _iso_bounds() -> Rect2:
	var size := map.get_pixel_size()
	var bounds := Rect2(Iso.TRANSFORM * Vector2.ZERO, Vector2.ZERO)
	for corner in [Vector2(size.x, 0), Vector2(0, size.y), size]:
		bounds = bounds.expand(Iso.TRANSFORM * corner)
	return bounds


func _on_paint_started(screen_position: Vector2, world_position: Vector2) -> void:
	_screen_tap = world_position
	world_position = _to_map(world_position)
	_paint_cells.clear()
	_paint_failed = false
	_paint_active = not hud.is_over_ui(screen_position)
	if not _paint_active:
		return
	var cell := map.world_to_cell(world_position)
	if current_tool == Hud.Tool.DIG:
		# Toucher une créature affiche son état (au lieu de creuser).
		var creature := _creature_at(world_position)
		if creature:
			hud.show_message(creature.describe(), 5.0)
			_paint_active = false
			return
		# La première case décide : on marque tout... ou on démarque tout.
		_paint_mark = not map.marked.has(cell)
		Sound.play("click", null, -8.0)
	_paint_cell(cell)


## Applique l'outil sur une case, une seule fois par geste.
func _paint_cell(cell: Vector2i) -> void:
	if _paint_cells.has(cell):
		return
	_paint_cells[cell] = true
	if current_tool == Hud.Tool.DIG:
		map.set_mark(cell, _paint_mark)
	elif current_tool == Hud.Tool.DEMOLISH:
		_demolish(cell)
	elif TOOL_ROOMS.has(current_tool):
		_build(cell, TOOL_ROOMS[current_tool])


func _on_camera_tapped(screen_position: Vector2, world_position: Vector2) -> void:
	_screen_tap = world_position
	world_position = _to_map(world_position)
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
		Hud.Tool.HAND:
			_use_hand(cell, world_position)
		Hud.Tool.SACRIFICE:
			_request_sacrifice(world_position)
		Hud.Tool.DEMOLISH:
			_demolish(cell)
		_:
			if TOOL_ROOMS.has(current_tool):
				_build(cell, TOOL_ROOMS[current_tool])
			elif TOOL_DEFENSES.has(current_tool):
				_place_defense(cell, TOOL_DEFENSES[current_tool])
			elif TOOL_SPELLS.has(current_tool):
				_cast_spell(TOOL_SPELLS[current_tool], world_position)


func _creature_at(world_position: Vector2) -> Creature:
	return _unit_at(world_position, creatures_root) as Creature


## L'unité (pas déjà dans la main) sous le doigt, parmi les enfants de root.
## On compare à l'écran : le personnage est dessiné debout, AU-DESSUS de sa
## position au sol, donc on vise le milieu de son corps.
func _unit_at(_map_position: Vector2, root: Node) -> Unit:
	for unit: Unit in root.get_children():
		if unit.in_hand:
			continue
		var body_center := world_root.to_global(unit.position) + Vector2(0, -14)
		if body_center.distance_to(_screen_tap) < 22.0:
			return unit
	return null


## La main du maître : toucher une unité la ramasse, toucher le sol dépose
## la dernière ramassée.
func _use_hand(cell: Vector2i, world_position: Vector2) -> void:
	var unit := _unit_at(world_position, creatures_root)
	if unit == null:
		unit = _unit_at(world_position, workers_root)

	if unit != null:
		if hand.size() >= HAND_CAPACITY:
			_fail("Ta main est pleine : dépose d'abord quelqu'un.")
		elif not unit.can_be_picked_up():
			_fail("Elle a décidé de partir : impossible de la retenir !")
		else:
			unit.pick_up()
			Sound.play("pickup")
			hand.append(unit)
			_refresh_hand()
		return

	if hand.is_empty():
		return
	if not map.is_connected_to_heart(cell):
		_fail("Dépose-la sur un sol relié à ton donjon.")
		return
	var dropped: Unit = hand.pop_back()
	dropped.drop_at(cell)
	Sound.play("drop", map.cell_to_world(cell))
	_refresh_hand()


func _refresh_hand() -> void:
	var names: Array[String] = []
	for unit in hand:
		names.append(unit.display_name())
	hud.set_hand(names, HAND_CAPACITY)


func _build(cell: Vector2i, room_type: int) -> void:
	if not map.can_build_room(cell):
		if not map.is_walkable(cell):
			_fail("On ne construit que sur du sol déjà creusé.")
		elif not map.is_claimed(cell):
			_fail("Ce sol n'est pas encore à toi : tes ouvriers doivent d'abord le revendiquer.")
		return
	var cost := Rooms.cost(room_type)
	if not map.spend_gold(cost):
		_fail("Pas assez d'or : %s coûte %d par case." % [Rooms.display_name(room_type), cost])
		return
	# Les ouvriers viendront construire la case (voir worker.gd) : en attendant,
	# c'est un chantier, qui ne sert à rien.
	map.start_construction(cell, "room", room_type)
	Sound.play("build", map.cell_to_world(cell), -8.0)
	_hint("Tes ouvriers vont construire : un chantier ne sert qu'une fois terminé.")


## Les pièges et portes ne s'achètent pas : on pose ceux fabriqués par l'Atelier.
func _place_defense(cell: Vector2i, type: int) -> void:
	if not map.can_place_defense(cell):
		_fail("Les pièges et les portes se posent sur le sol revendiqué des couloirs.")
		return
	if trap_stock[type] <= 0:
		_fail("Aucun(e) %s en stock : construis un Atelier, tes créatures en fabriqueront." %
				Defenses.display_name(type))
		return
	trap_stock[type] -= 1
	map.start_construction(cell, "defense", type) # Un ouvrier viendra l'installer.
	Sound.play("trap_place", map.cell_to_world(cell))


func _demolish(cell: Vector2i) -> void:
	if map.construction.has(cell):
		# Chantier annulé : on rend l'or de la salle, ou le piège à son stock.
		var site := map.cancel_construction(cell)
		if site["kind"] == "room":
			var refund := Rooms.cost(site["type"])
			var stored := map.add_gold_to_treasury(refund)
			map.heart_gold += refund - stored # Pas de place au Trésor : l'or revient au cœur.
			map.gold_changed.emit()
		else:
			trap_stock[site["type"]] += 1
		Sound.play("build", map.cell_to_world(cell), -6.0)
		return
	if map.defenses.has(cell):
		# Le piège retourne dans le stock (une porte abîmée est réparée au passage).
		trap_stock[map.defenses[cell]["type"]] += 1
		map.remove_defense(cell)
		Sound.play("build", map.cell_to_world(cell), -6.0)
		return
	if map.get_room(cell) == Rooms.Type.NONE:
		return
	var lost := map.remove_room(cell)
	Sound.play("build", map.cell_to_world(cell), -6.0)
	if lost > 0:
		hud.show_message("Plus de place dans le trésor : %d or perdu !" % lost)


func _on_summon_pressed() -> void:
	if not map.spend_gold(WORKER_COST):
		_fail("Pas assez d'or ! Creuse les filons dorés.")
		return
	_spawn_worker()
	Sound.play("portal", map.cell_to_world(map.heart_cell), -6.0)
	_refresh_hud()

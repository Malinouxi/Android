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
const FIRST_WAVE_DELAY := 420.0
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
	Hud.Tool.TAVERN: Rooms.Type.TAVERN,
	Hud.Tool.INFIRMARY: Rooms.Type.INFIRMARY,
	Hud.Tool.MINT: Rooms.Type.MINT,
	Hud.Tool.TORTURE: Rooms.Type.TORTURE,
	Hud.Tool.GUARDPOST: Rooms.Type.GUARDPOST,
	Hud.Tool.MANA_WELL: Rooms.Type.MANA_WELL,
	Hud.Tool.CRYPT: Rooms.Type.CRYPT,
}
## Points de recherche par seconde qu'apporte chaque prisonnier interrogé.
const PRISONER_RESEARCH := Rules.PRISONER_RESEARCH
## Quel sort lance chaque bouton du panneau de gauche.
const TOOL_SPELLS := {
	Hud.Tool.SPELL_HEAL: Spells.Type.HEAL,
	Hud.Tool.SPELL_LIGHTNING: Spells.Type.LIGHTNING,
	Hud.Tool.SPELL_HASTE: Spells.Type.HASTE,
	Hud.Tool.SPELL_WEB: Spells.Type.WEB,
	Hud.Tool.SPELL_FIRESTORM: Spells.Type.FIRESTORM,
	Hud.Tool.SPELL_TERROR: Spells.Type.TERROR,
	Hud.Tool.SPELL_COLLAPSE: Spells.Type.COLLAPSE,
	Hud.Tool.SPELL_POSSESSION: Spells.Type.POSSESSION,
	Hud.Tool.SPELL_WHIP: Spells.Type.WHIP,
	Hud.Tool.SPELL_FEAST: Spells.Type.FEAST,
	Hud.Tool.SPELL_EYE: Spells.Type.EYE,
	Hud.Tool.SPELL_SUMMON: Spells.Type.SUMMON,
	Hud.Tool.SPELL_TRANSMUTE: Spells.Type.TRANSMUTE,
	Hud.Tool.SPELL_RAISE: Spells.Type.RAISE,
	Hud.Tool.SPELL_CONVERT: Spells.Type.CONVERT,
	Hud.Tool.SPELL_SANCTUARY: Spells.Type.SANCTUARY,
	Hud.Tool.SPELL_RECALL: Spells.Type.RECALL,
}
## Conversion : les troupes du rival redeviennent des créatures de leur espèce ;
## les autres héros deviennent des Renégats (voir creatures.gd).
const CONVERTED_TYPES := {
	Heroes.Type.RIVAL_KOBOLD: Creatures.Type.KOBOLD,
	Heroes.Type.RIVAL_ORC: Creatures.Type.ORC,
	Heroes.Type.RIVAL_WARLOCK: Creatures.Type.WARLOCK,
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
	Hud.Tool.BRAZIER: Defenses.Type.BRAZIER,
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
## L'escouade de chaque héros en attente (même ordre que _pending_heroes).
var _pending_squads: Array[int] = []
## Les ESCOUADES de la vague (voir _start_wave) : numéro -> {"role", "entrance",
## "objective", "size", "lost", "retreated", "avoid" (chemin à éviter), "scouted"}.
var _squads: Dictionary = {}
var _next_squad_id := 0
var _last_spawned_squad := -1
## L'éclaireur : la vague pour laquelle il est venu, et son rapport (cases de pièges).
var _scout_wave := 0
var _scout_report: Array = []
var _hero_spawn_timer := 0.0
## Nombre de Champions du royaume vaincus (objectif du niveau 9).
var _champions_defeated := 0
var _grave_timer := 0.0
## Les antres (règles 2.7) : minuteurs de l'Hôtel des monnaies et du Poste de garde,
## or frappé pas encore rangé, aveux sous la torture (vague déjà révélée, progrès),
## et progrès de la torture de chaque prisonnier (identifiant -> secondes).
var _mint_timer := Rules.MINT_INTERVAL
var _mint_gold := 0.0
var _guard_timer := 0.0
var _alarm_cooldown := 0.0
var _intel_wave := 0
var _intel_progress := 0.0
var _torture_progress := {}
## Les héros échappés qui reviendront en vétérans (voir nemeses.gd)...
var nemeses := Nemeses.new()
## ... et ceux de la vague en cours qui attendent d'entrer (ils entrent les premiers).
var _pending_veterans: Array = []
## Pour ne pas répéter le message de retraite à chaque héros d'une débandade.
var _flee_message_timer := 0.0
## Dernier affichage de chaque combo (on ne l'écrit pas plus d'une fois par seconde).
var _combo_shown := {}

## La recherche de la Bibliothèque (voir research.gd).
var research := Research.new()
var mana := Spells.START_MANA
## La créature possédée (sort Possession), ou null.
var _possessed: Creature = null
## La prochaine vague, tirée à l'avance (l'Œil du maître la montre) : {"wave", "heroes"}.
var _wave_plan: Dictionary = {}
## Points de fabrication accumulés par l'Atelier vers le prochain piège.
var workshop_points := 0.0
## Pièges et portes fabriqués, prêts à être posés : Defenses.Type -> nombre.
var trap_stock := {Defenses.Type.SPIKES: 0, Defenses.Type.RUNE: 0, Defenses.Type.DOOR: 0, Defenses.Type.ALTAR: 0}

var _autosave_timer := AUTOSAVE_INTERVAL
var _game_over := false

## Musique adaptative : on passe en musique de combat tant que des héros sont dans
## le donjon, et on revient au calme quelques secondes après le dernier.
const CALM_MUSIC_DELAY := 8.0
var _music_timer := 0.0
var _calm_countdown := 0.0

# Peinture au doigt (voir camera_controller.gd) : cases déjà traitées pendant ce geste.
var _paint_active := false
var _paint_cells := {}
var _paint_mark := true
var _paint_failed := false
## Position à l'écran du dernier toucher (pour savoir quel personnage est touché).
var _screen_tap := Vector2.ZERO
## Position à l'écran (vraie, en pixels) du dernier toucher : sert en vue 3D.
var _screen_touch := Vector2.ZERO

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
	Sound.play_music("calm")
	# On branche les signaux sur nos fonctions.
	map.gold_changed.connect(_refresh_hud)
	camera.tapped.connect(_on_camera_tapped)
	camera.paint_started.connect(_on_paint_started)
	camera.painted.connect(func(screen_world_position: Vector2) -> void:
		if _paint_active:
			_paint_cell(map.world_to_cell(_to_map(screen_world_position))))
	camera.paint_ended.connect(func() -> void: _paint_active = false)
	hud.summon_pressed.connect(_on_summon_pressed)
	hud.portrait.advice_requested.connect(_on_advice_requested)
	hud.tool_selected.connect(_on_tool_selected)
	hud.restart_pressed.connect(_on_restart_pressed)
	map.heart_changed.connect(_on_heart_changed)
	map.heart_destroyed.connect(_on_heart_destroyed)
	map.treasure_found.connect(func(cell: Vector2i, amount: int) -> void:
		hud.show_message("Trésor caché dans la roche : %d pièces d'or !" % amount, 4.0)
		Sound.play("gold", map.cell_to_world(cell))
		Fx.burst("sparks", map.cell_to_world(cell), Color("ffd54a")))
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
	map.combo_triggered.connect(_on_combo_triggered)
	map.secret_hinted.connect(_on_secret_hinted)
	map.secret_revealed.connect(_on_secret_revealed)
	map.lava_flowed.connect(_on_lava_flowed)
	hud.assault_pressed.connect(_on_assault_pressed)
	Creature.assault_target = null # (Variable partagée : on repart de zéro à chaque partie.)

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
	if Sound.view_3d_enabled:
		_enable_3d()
	else:
		Fx.view3d = null # (Le menu en 3D l'avait peut-être réglée.)
	hud.fade_in()


## La VUE 3D (voir view_3d.gd) : le jeu reste le même, seul l'affichage change.
## On cache le monde 2D, et on branche la caméra et les effets sur la 3D.
var _view3d: View3D = null


func _enable_3d() -> void:
	_view3d = View3D.new()
	add_child(_view3d)
	_view3d.setup(map, [workers_root, creatures_root, heroes_root] as Array[Node])
	world_root.visible = false
	$FxLayer.follow_viewport_enabled = false # Les effets se placent à l'écran (Fx.to_screen).
	Fx.view3d = _view3d
	camera.view3d = _view3d
	_view3d.set_zoom(camera.zoom.x)


func _start_new_game() -> void:
	level = Levels.current()
	# Chaque niveau a sa propre carte (une « graine » fixe). 0 = carte au hasard.
	var seed_value: int = level.get("seed", 0)
	if seed_value == 0:
		seed_value = randi()
	map.generate(seed_value, level.get("rival", false), level.get("rival_hp", 1200.0))
	map.set_starting_gold(level.get("start_gold", START_GOLD))
	_wave_timer = maxf(level.get("first_wave", FIRST_WAVE_DELAY), Rules.FIRST_WAVE_MIN)
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
	mana = minf(_max_mana(), mana + Spells.regen_per_second(map.claimed.size()) * delta)
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
	_update_dens(delta)
	_goal_timer -= delta
	if _goal_timer <= 0.0:
		_goal_timer = 1.0
		_check_goal()
	_check_full_pockets()
	_update_music(delta)

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
	if _creatures_needing_beds() >= map.count_room_tiles(Rooms.Type.LAIR):
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
		var allowed := Creatures.allowed_count(type, map)
		if allowed >= 0 and count >= allowed:
			continue # Espèce rare : sa limite est atteinte (voir creatures.gd).
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
	hud.show_message("%s (%s) arrive par le portail ! (salaire : %d or)" %
			[creature.display_name(), Traits.names(creature.traits), creature.salary()])


## Crée une créature sur une case (sert aussi au chargement d'une partie).
func _add_creature(type: int, cell: Vector2i) -> Creature:
	var creature := Creature.new()
	creature.setup_creature(map, cell, type)
	creature.left_dungeon.connect(_on_creature_left)
	creature.died.connect(_on_creature_died)
	creature.worked.connect(_on_creature_worked)
	creature.sacrificed.connect(_on_creature_sacrificed)
	creature.gold_stolen.connect(_on_gold_stolen)
	creature.raised_hero.connect(_on_hero_raised)
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
	elif room_type == Rooms.Type.TEMPLE or room_type == Rooms.Type.MANA_WELL:
		mana = minf(_max_mana(), mana + amount)
	elif room_type == Rooms.Type.MINT:
		_mint_gold += amount
		if _mint_gold >= 1.0:
			var coins := int(_mint_gold)
			_mint_gold -= coins
			map.add_gold_to_treasury(coins)
	elif room_type == Rooms.Type.TORTURE:
		_torture(amount)
	elif room_type == Rooms.Type.CRYPT:
		# Le Nécromancien veille : le premier mort de la Crypte se relève plus vite.
		if not map.crypt_bodies.is_empty():
			map.crypt_bodies[0]["time"] = float(map.crypt_bodies[0]["time"]) - amount


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
	# Possession : donner un ordre à la créature déjà possédée ne coûte rien.
	if type == Spells.Type.POSSESSION and _command_possessed(world_position):
		return
	if mana < info["mana"]:
		_fail("Pas assez de mana : %s coûte %d." % [info["name"], info["mana"]])
		return
	var room := Spells.required_room(type)
	if room != Rooms.Type.NONE and map.count_room_tiles(room) == 0:
		_fail("%s : il te faut d'abord un %s." % [info["name"], Rooms.display_name(room)])
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
				unit.take_damage(info["damage"] * (1.0 - unit.spell_resist))
				cast = true
			# Combo Détonation : la foudre fait sauter les runes dans la zone.
			if map.detonate_runes(world_position, info["radius"]) > 0:
				Fx.lightning(world_position)
				cast = true
			# Combo Porte électrifiée : la foudre charge les portes de la zone.
			if map.electrify_doors(world_position, info["radius"]) > 0:
				Fx.lightning(world_position)
				cast = true
		Spells.Type.HASTE:
			var target := _my_unit_at(world_position)
			if target != null:
				target.apply_haste(info["duration"])
				Fx.burst("haste", target.position)
				cast = true
		Spells.Type.WEB:
			cast = _enchant_heroes(world_position, info, func(hero: Hero) -> bool:
				return hero.apply_web(info["duration"]))
		Spells.Type.FIRESTORM:
			if map.is_walkable(map.world_to_cell(world_position)):
				map.add_fire(world_position, info["radius"], info["duration"])
				map.ignite_runes(world_position, info["radius"]) # Combo Brasier runique.
				Fx.burst("sparks", world_position, Color("ff7a1a"))
				cast = true
		Spells.Type.TERROR:
			cast = _enchant_heroes(world_position, info, func(hero: Hero) -> bool:
				return hero.frighten(info["duration"]))
		Spells.Type.COLLAPSE:
			cast = _collapse(map.world_to_cell(world_position), info)
		Spells.Type.POSSESSION:
			var creature := _my_unit_at(world_position, false) as Creature
			if creature != null and not creature.is_leaving():
				if is_instance_valid(_possessed) and _possessed != creature and _possessed.is_possessed():
					_possessed.possessed_left = 0.01 # Le maître lâche l'ancienne.
				creature.possess(info["duration"], info["damage_bonus"])
				_possessed = creature
				hud.show_message("%s est possédée : touche un héros pour qu'elle l'attaque, ou le sol pour l'y envoyer." %
						creature.display_name(), 4.0)
				cast = true
		Spells.Type.WHIP:
			var target := _my_unit_at(world_position)
			if target != null:
				target.apply_whip(info["duration"], info["work_factor"])
				if target is Creature:
					var whipped := target as Creature
					whipped.happiness = maxf(0.0, whipped.happiness - info["mood"])
				Fx.burst("sparks", target.position, Color("ffb74d"))
				cast = true
		Spells.Type.FEAST:
			for creature: Creature in creatures_root.get_children():
				if creature.is_dead() or creature.is_leaving() or creature.is_undead():
					continue
				creature.hunger = 0.0
				creature.happiness = minf(100.0, creature.happiness + info["mood"])
				Fx.burst("heal", creature.position, Color("ffd54a"))
				cast = true
			if cast:
				hud.show_message("Festin ! Tes créatures se régalent.", 3.0)
		Spells.Type.EYE:
			cast = true
			_master_eye(world_position, info)
		Spells.Type.SUMMON:
			cast = _summon_worker(world_position, info)
		Spells.Type.TRANSMUTE:
			if map.get_treasury_capacity() - map.get_treasury_stored() < info["gold"]:
				_fail("Transmutation : il faut %d or de place libre au Trésor." % info["gold"])
				return
			map.add_gold_to_treasury(info["gold"])
			Fx.burst("coins", world_position)
			hud.show_message("Transmutation : %d mana deviennent %d or." % [info["mana"], info["gold"]], 3.0)
			cast = true
		Spells.Type.RAISE:
			cast = _raise_dead(info)
		Spells.Type.CONVERT:
			cast = _convert_prisoner(world_position)
		Spells.Type.SANCTUARY:
			if not _near_room_tile(map.world_to_cell(world_position), Rooms.Type.TEMPLE, 3):
				_fail("Sanctuaire : touche ton Temple (ou juste à côté).")
				return
			for unit in _units_near("dungeon", world_position, info["radius"]):
				unit.apply_ward(info["duration"], info["protection"])
				Fx.burst("magic", unit.position, Color(0.75, 0.6, 1.0))
			cast = true # (Même sans personne : le Temple rayonne pour rien.)
		Spells.Type.RECALL:
			cast = _recall_creatures()
	if not cast:
		_fail("Aucune cible ici : %s" % _target_hint(type))
		return
	mana -= info["mana"]
	Fx.spell(type, world_position) # Les effets 3D (modèles Blender).
	Sound.play(info.get("sound", "zap"), world_position)
	map.add_effect(world_position, info.get("radius", 24.0), info["color"])
	var spell_color: Color = info["color"]
	Fx.burst("magic", world_position, Color(spell_color, 1.0))
	Fx.flash_light(world_position, Color(spell_color, 1.0), 160.0)
	if type == Spells.Type.LIGHTNING or type == Spells.Type.COLLAPSE:
		Fx.shake(6.0)


## Ce qu'il fallait toucher pour ce sort (message d'erreur).
func _target_hint(type: int) -> String:
	match Spells.INFO[type]["target"]:
		"zone":
			return "touche des héros." if type != Spells.Type.HEAL else "touche tes unités blessées."
		"unit":
			return "touche une de tes créatures ou un ouvrier."
		"creature":
			return "touche une de tes créatures."
		"cell":
			return "touche un couloir de ton donjon (pas une salle ni un piège)."
		"prisoner":
			return "touche un héros enfermé dans ta Prison."
	return Spells.INFO[type]["help"]


## Envoûte les héros d'une zone (Toile, Terreur). apply(hero) renvoie false si le
## héros y est insensible. Renvoie true si au moins un héros est envoûté.
func _enchant_heroes(world_position: Vector2, info: Dictionary, apply: Callable) -> bool:
	var heroes := _units_near("heroes", world_position, info["radius"])
	var color: Color = info["color"]
	var count := 0
	var immune := 0
	for unit in heroes:
		var hero := unit as Hero
		if hero == null or hero.is_guardian():
			continue
		if apply.call(hero):
			count += 1
			Fx.burst("magic", hero.position, Color(color, 1.0))
		else:
			immune += 1
			Fx.text(hero.position, "insensible", Color("e1f5fe"))
	if count == 0 and immune > 0:
		_fail("%s : ces héros y sont insensibles !" % info["name"])
		return false
	return count > 0


## Une de tes unités sous le doigt (créature, ou ouvrier si with_workers), ou null.
func _my_unit_at(world_position: Vector2, with_workers := true) -> Unit:
	var unit := _unit_at(world_position, creatures_root)
	if unit == null and with_workers:
		unit = _unit_at(world_position, workers_root)
	if unit != null and not unit.is_dead():
		return unit
	# Pas de personnage sous le doigt : le plus proche du point touché.
	var best: Unit = null
	var best_distance := 24.0
	for candidate in _units_near("dungeon", world_position, best_distance):
		if candidate is Worker and not with_workers:
			continue
		if not (candidate is Worker or candidate is Creature) or candidate.in_hand:
			continue
		var distance := candidate.position.distance_to(world_position)
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	return best


## Le héros sous le doigt (vivant, pas prisonnier), ou null.
func _hero_at(world_position: Vector2) -> Hero:
	var hero := _unit_at(world_position, heroes_root) as Hero
	if hero != null and hero.is_targetable():
		return hero
	var best: Hero = null
	var best_distance := 28.0
	for unit in _units_near("heroes", world_position, best_distance):
		if unit is Hero and unit.position.distance_to(world_position) <= best_distance:
			best = unit as Hero
			best_distance = unit.position.distance_to(world_position)
	return best


## Vrai si une case de cette salle se trouve à moins de radius cases.
func _near_room_tile(cell: Vector2i, room: int, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if map.get_room(cell + Vector2i(dx, dy)) == room:
				return true
	return false


## Possession : un toucher donne un ordre à la créature déjà possédée (gratuit).
## Renvoie false si le toucher n'est pas un ordre (on lance alors le sort).
func _command_possessed(world_position: Vector2) -> bool:
	if not is_instance_valid(_possessed) or not _possessed.is_possessed():
		_possessed = null
		return false
	var touched := _my_unit_at(world_position, false)
	if touched != null:
		return touched == _possessed # Une autre créature : on la possède à sa place.
	var hero := _hero_at(world_position)
	if hero != null:
		_possessed.command(hero, Vector2i(-1, -1))
		Fx.text(hero.position, "Cible !", Color("ff5252"))
		return true
	var cell := map.world_to_cell(world_position)
	if map.is_walkable(cell):
		_possessed.command(null, cell)
		map.add_effect(map.cell_to_world(cell), 14.0, Color(1.0, 0.2, 0.3, 0.7))
		return true
	return false


## Effondrement : le plafond d'un couloir s'écroule. Les unités qui s'y trouvent sont
## écrasées et repoussées sur une case voisine ; les chemins qui passaient là sont coupés.
func _collapse(cell: Vector2i, info: Dictionary) -> bool:
	var exit := Vector2i(-1, -1)
	for direction in DungeonMap.DIRECTIONS:
		if map.is_walkable(cell + direction):
			exit = cell + direction
			break
	if not map.can_collapse(cell) or exit == Vector2i(-1, -1):
		_fail("Effondrement : touche un couloir (pas une salle, un piège ou un cul-de-sac fermé).")
		return false
	# On repère les unités avant que la case ne se bouche.
	var crushed: Array[Unit] = []
	for root in [workers_root, creatures_root, heroes_root]:
		for node in root.get_children():
			var unit := node as Unit
			if unit == null or unit.is_dead() or unit.in_hand:
				continue
			var hero := unit as Hero
			if hero != null and (hero.is_captured() or hero.knocked_out or hero.carrier != null):
				continue
			if unit.current_cell() == cell:
				crushed.append(unit)
			elif unit.path.has(cell) and hero == null:
				unit.on_path_blocked() # (Les héros, eux, creuseront.)
	map.collapse(cell)
	var center := map.cell_to_world(cell)
	Fx.burst("dust", center, Color("8d6e63"))
	Fx.burst("smoke", center, Color(0.5, 0.4, 0.3, 0.7))
	for unit in crushed:
		unit.position = map.cell_to_world(exit)
		unit.path.clear()
		var crush: float = info["damage"]
		if unit is Hero:
			crush *= 1.0 - unit.spell_resist
			if unit.is_immune("collapse"):
				crush *= 0.25 # Le Nain sait se tirer d'un éboulement.
		unit.take_damage(crush)
	return true


## Œil du maître : la prochaine vague, les Voleuses démasquées, les secrets proches.
func _master_eye(world_position: Vector2, info: Dictionary) -> void:
	hud.show_message("L'Œil du maître voit la %s" % _wave_intel_text(), 8.0)
	# Les héros discrets (la Voleuse) sont démasqués.
	for node in get_tree().get_nodes_in_group("heroes"):
		var hero := node as Hero
		if hero != null and hero.stealthy:
			hero.unmask(info["duration"])
			Fx.burst("magic", hero.position, Color("ffd54a"))
	# Les secrets des profondeurs proches du point touché donnent leur indice.
	var cell := map.world_to_cell(world_position)
	var radius := int(info["radius"] / DungeonMap.TILE_SIZE)
	for secret: Dictionary in map.secrets:
		var center: Vector2i = secret["center"]
		if secret["revealed"] or maxi(absi(center.x - cell.x), absi(center.y - cell.y)) > radius:
			continue
		secret["hinted"] = true
		map.add_effect(map.cell_to_world(center), 48.0, Color(1.0, 0.85, 0.3, 0.6))
		Fx.text(map.cell_to_world(center), "?", Color("ffd54a"))
		_on_secret_hinted(secret["kind"], center)


## Invocation : un ouvrier fantôme pour un temps, sur la case touchée (ou près du cœur).
func _summon_worker(world_position: Vector2, info: Dictionary) -> bool:
	var summoned := 0
	for worker: Worker in workers_root.get_children():
		if worker.is_summoned():
			summoned += 1
	if summoned >= info["max"]:
		_fail("Invocation : déjà %d ouvriers fantômes à l'œuvre." % summoned)
		return false
	var cell := map.world_to_cell(world_position)
	if not map.is_walkable(cell) or not map.is_claimed(cell):
		cell = map.get_spawn_cell()
	var worker := _add_worker(cell)
	worker.lifetime = info["duration"]
	worker.self_modulate = Color(0.6, 1.0, 0.7, 0.7) # Un fantôme verdâtre.
	Fx.burst("magic", worker.position, Color("69f0ae"))
	hud.show_message("Un ouvrier fantôme vient t'aider pendant %d s." % info["duration"], 3.0)
	return true


## Relever les morts : les tombes pleines se vident tout de suite ; sinon, un
## Revenant temporaire sort de terre au Cimetière.
func _raise_dead(info: Dictionary) -> bool:
	if not map.graves.is_empty():
		for cell: Vector2i in map.graves:
			map.graves[cell] = 0.0
		_grave_timer = 0.0 # Ils se relèvent à la prochaine image (voir _update_graves).
		return true
	var spots: Array[Vector2i] = []
	for cell: Vector2i in map.rooms:
		if map.rooms[cell] == Rooms.Type.GRAVEYARD and map.is_walkable(cell):
			spots.append(cell)
	if spots.is_empty():
		return false
	var revenant := _add_creature(Creatures.Type.REVENANT, spots.pick_random())
	revenant.lifetime = info["duration"]
	revenant.happiness = 100.0
	Fx.burst("magic", revenant.position, Color("76ff03"))
	Fx.burst("dust", revenant.position)
	hud.show_message("Aucune tombe n'est pleine : un Revenant sort de terre pour %d s." % info["duration"], 4.0)
	return true


## Conversion : le prisonnier touché change de camp.
func _convert_prisoner(world_position: Vector2) -> bool:
	var cell := map.world_to_cell(world_position)
	var hero: Hero = map.prisoners.get(cell)
	if hero == null:
		var best_distance := 28.0
		for prison_cell: Vector2i in map.prisoners:
			var candidate: Hero = map.prisoners[prison_cell]
			var distance := map.cell_to_world(prison_cell).distance_to(world_position)
			if is_instance_valid(candidate) and candidate.is_captured() and distance <= best_distance:
				hero = candidate
				best_distance = distance
	if hero == null or not is_instance_valid(hero) or not hero.is_captured():
		return false
	var former := hero.display_name()
	var at := hero.prison_cell
	var creature_type: int = CONVERTED_TYPES.get(hero.type, Creatures.Type.RENEGADE)
	# Le prisonnier quitte sa cellule sans mourir : ni rançon, ni tombe.
	map.prisoners.erase(at)
	hero.remove_from_group("prisoners")
	hero.prison_cell = Vector2i(-1, -1)
	hero.queue_free()
	var creature := _add_creature(creature_type, at)
	if creature_type == Creatures.Type.RENEGADE:
		creature.sprite_override = Heroes.info(hero.type)["sprite"]
		creature.self_modulate = Creatures.info(Creatures.Type.RENEGADE)["tint"]
	creature.happiness = 80.0
	Fx.burst("magic", creature.position, Color("b388ff"))
	Fx.flash_light(creature.position, Color(0.7, 0.4, 1.0), 150.0, 0.6)
	hud.show_message("%s renie son roi et rejoint ton donjon (%s) !" % [former, creature.display_name()], 5.0)
	return true


# ---------------------------------------------------------------------------
# Les antres (règles 2.7) : Hôtel des monnaies, Torture, Poste de garde, Puits, Crypte
# ---------------------------------------------------------------------------

## La mana maximum : un peu plus avec chaque Puits de mana (MANA_WELL_MAX au plus).
func _max_mana() -> float:
	var wells := mini(map.count_rooms(Rooms.Type.MANA_WELL), Rules.MANA_WELL_MAX)
	return Spells.MAX_MANA + Rules.MANA_WELL_BONUS * wells


func _update_dens(delta: float) -> void:
	_update_mint(delta)
	_update_guards(delta)
	_update_crypt(delta)


## L'Hôtel des monnaies : les intérêts sur l'or rangé au Trésor.
func _update_mint(delta: float) -> void:
	_mint_timer -= delta
	if _mint_timer > 0.0:
		return
	_mint_timer = Rules.MINT_INTERVAL
	var mints := map.count_rooms(Rooms.Type.MINT)
	if mints == 0:
		return
	var interest := mini(int(map.get_treasury_stored() * Rules.MINT_INTEREST), Rules.MINT_CAP * mints)
	if interest <= 0:
		return
	var stored := map.add_gold_to_treasury(interest)
	if stored > 0:
		Sound.play("coins", null, -10.0)
		hud.show_message("Hôtel des monnaies : +%d or d'intérêts." % stored, 3.0)


## Le Diablotin argentier a fait les poches d'un héros.
func _on_gold_stolen(amount: int, where: Vector2) -> void:
	if map.add_gold_to_treasury(amount) > 0:
		Fx.burst("coins", where)


## Le Nécromancien a abattu un héros : il se relève en Revenant, pour un temps.
func _on_hero_raised(where: Vector2, duration: float) -> void:
	var cell := map.world_to_cell(where)
	if not map.is_walkable(cell):
		return
	var revenant := _add_creature(Creatures.Type.REVENANT, cell)
	revenant.lifetime = duration
	revenant.happiness = 100.0
	Fx.burst("magic", revenant.position, Color("76ff03"))
	Fx.burst("dust", revenant.position)
	hud.show_message("Le Nécromancien relève le héros abattu : il te sert pour %d s !" % int(duration), 3.0)


## La Chambre de torture : chaque seconde de travail fait parler un prisonnier.
## Il donne de la recherche, une fois par vague la composition de la vague suivante,
## et, brisé, il finit par changer de camp (comme le sort Conversion).
func _torture(amount: float) -> void:
	research.add_points(Rules.TORTURE_RESEARCH * amount)
	_intel_progress += amount
	if _intel_progress >= Rules.TORTURE_INTEL_TIME and _intel_wave != _next_wave:
		_intel_progress = 0.0
		_intel_wave = _next_wave
		hud.show_message("Sous la torture, un prisonnier avoue : %s" % _wave_intel_text(), 8.0)
	# On travaille le prisonnier le plus avancé (ou le premier venu).
	var victim: Hero = null
	for cell: Vector2i in map.prisoners:
		var hero: Hero = map.prisoners[cell]
		if not is_instance_valid(hero) or not hero.is_captured():
			continue
		if victim == null or float(_torture_progress.get(hero.get_instance_id(), 0.0)) 				> float(_torture_progress.get(victim.get_instance_id(), 0.0)):
			victim = hero
	if victim == null:
		return
	var id := victim.get_instance_id()
	_torture_progress[id] = float(_torture_progress.get(id, 0.0)) + amount
	if _torture_progress[id] >= Rules.TORTURE_CONVERT_TIME:
		_torture_progress.erase(id)
		var name := victim.display_name()
		if _convert_prisoner(map.cell_to_world(victim.prison_cell)):
			hud.show_message("%s, brisé par la torture, rejoint ton donjon !" % name, 5.0)


## Le Poste de garde : les guetteurs en poste démasquent les héros discrets, chassent
## l'éclaireur avant qu'il ait tout vu, et sonnent l'alarme.
func _update_guards(delta: float) -> void:
	_alarm_cooldown -= delta
	_guard_timer -= delta
	if _guard_timer > 0.0:
		return
	_guard_timer = 0.5
	var spotted: Hero = null
	var lookout: Creature = null
	for creature: Creature in creatures_root.get_children():
		if not creature.on_guard_duty():
			continue
		var post := creature.current_cell()
		for node in get_tree().get_nodes_in_group("heroes"):
			var hero := node as Hero
			if hero == null or not hero.is_targetable() or hero.ignored_as_enemy():
				continue
			var cell := hero.current_cell()
			if maxi(absi(cell.x - post.x), absi(cell.y - post.y)) > Rules.GUARD_RADIUS:
				continue
			if hero.stealthy:
				hero.unmask(1.0) # Le guetteur la voit : tout le monde la voit.
			if hero.is_scout() and not hero.has_meta("spotted"):
				hero.set_meta("spotted", true)
				hero.seen_traps.clear()
				hero.start_fleeing(false)
				Fx.text(hero.position, "Repéré !", Color("ffd54a"))
				hud.show_message("Le guetteur a repéré l'éclaireur : il détale sans avoir rien vu !", 4.0)
			spotted = hero
			lookout = creature
	if spotted == null or _alarm_cooldown > 0.0:
		return
	# L'alarme : les créatures proches se réveillent (ou lâchent leur travail) et accourent.
	_alarm_cooldown = Rules.ALARM_COOLDOWN
	Sound.play("horn", lookout.position, -6.0)
	Fx.text(lookout.position, "Alarme !", Color("ff5252"))
	var post_cell := lookout.current_cell()
	var roused := 0
	for creature: Creature in creatures_root.get_children():
		var cell := creature.current_cell()
		if creature != lookout and maxi(absi(cell.x - post_cell.x), absi(cell.y - post_cell.y)) <= Rules.ALARM_RADIUS:
			var before := creature.state
			creature.alert(spotted)
			if creature.state != before:
				roused += 1
	hud.show_message("Alarme au Poste de garde ! %d créature%s accourent." % [roused, "s" if roused > 1 else ""], 4.0)


## La Crypte : les morts se relèvent quand leur temps est venu (et s'il y a la mana).
func _update_crypt(delta: float) -> void:
	var bodies := map.crypt_bodies
	# Une Crypte démolie : les corps en trop reposent en paix.
	while bodies.size() > map.crypt_capacity():
		bodies.pop_back()
	if bodies.is_empty():
		return
	for body: Dictionary in bodies:
		body["time"] = float(body["time"]) - delta
	var body: Dictionary = bodies[0]
	if float(body["time"]) > 0.0:
		return
	if mana < Rules.CRYPT_MANA:
		if not body.get("waiting", false):
			body["waiting"] = true
			_hint("Un mort attend dans la Crypte : il faut %d mana pour le relever." % int(Rules.CRYPT_MANA))
		return
	var spots: Array[Vector2i] = []
	for cell: Vector2i in map.rooms:
		if map.rooms[cell] == Rooms.Type.CRYPT and map.is_walkable(cell):
			spots.append(cell)
	if spots.is_empty():
		return
	mana -= Rules.CRYPT_MANA
	bodies.pop_front()
	var creature := _add_creature(int(body["type"]), spots.pick_random())
	creature.revive(body)
	Fx.burst("magic", creature.position, Color("b388ff"))
	Fx.burst("dust", creature.position)
	Fx.flash_light(creature.position, Color(0.6, 0.4, 1.0), 120.0, 0.6)
	Sound.play("level_up", creature.position)
	hud.show_message("%s se relève de la Crypte, plus faible mais revenue d'entre les morts !" %
			creature.display_name(), 4.0)


## La vague suivante, en toutes lettres (Œil du maître, aveux sous la torture).
func _wave_intel_text() -> String:
	var heroes := _planned_heroes(_next_wave)
	var counts := {}
	for type in heroes:
		counts[type] = counts.get(type, 0) + 1
	var parts: Array[String] = []
	for type: int in counts:
		parts.append("%d %s" % [counts[type], Heroes.info(type)["name"]])
	var champion := " Le Champion du royaume les mène !" if _champion_leads_wave(_next_wave) else ""
	var veterans := nemeses.waiting.filter(func(e: Dictionary) -> bool: return int(e["return_wave"]) <= _next_wave)
	var veteran_text := (" Et %d vétéran%s." % [veterans.size(), "s" if veterans.size() > 1 else ""]) if not veterans.is_empty() else ""
	return "vague %d : %s.%s%s" % [_next_wave, ", ".join(parts), champion, veteran_text]


## Rappel : toutes les créatures disponibles apparaissent autour du cœur.
func _recall_creatures() -> bool:
	var spots: Array[Vector2i] = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var cell := map.heart_cell + Vector2i(dx, dy)
			if map.is_walkable(cell) and map.get_tile(cell) == DungeonMap.Tile.FLOOR:
				spots.append(cell)
	if spots.is_empty():
		_fail("Rappel : il n'y a pas de place autour de ton cœur.")
		return false
	var count := 0
	for creature: Creature in creatures_root.get_children():
		if creature.is_dead() or creature.is_leaving() or creature.in_hand:
			continue
		creature.recall_to(spots.pick_random())
		Fx.burst("magic", creature.position, Color("ff5252"))
		count += 1
	if count > 0:
		Fx.flash_light(map.cell_to_world(map.heart_cell), Color(1.0, 0.3, 0.3), 220.0, 0.6)
		hud.show_message("Rappel : %d créature%s accourent au cœur !" % [count, "s" if count > 1 else ""], 3.0)
	return count > 0


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
	var creature := unit as Creature
	hud.show_message("Ton %s est mort au combat !" % creature.display_name(), 4.0)
	# La Crypte : s'il reste une place, son corps y repose en attendant de revenir.
	if creature.lifetime > 0.0 or map.crypt_bodies.size() >= map.crypt_capacity():
		return
	map.crypt_bodies.append({"type": creature.type, "level": creature.level, "traits": creature.traits.duplicate(),
			"sprite": creature.sprite_override, "tint": creature.self_modulate.to_html(),
			"time": Rules.CRYPT_RISE_TIME})
	_hint("Le corps de ton %s repose dans la Crypte. Il se relèvera bientôt (%d mana)." %
			[creature.display_name(), int(Rules.CRYPT_MANA)])


# ---------------------------------------------------------------------------
# Vagues de héros
# ---------------------------------------------------------------------------

func _update_waves(delta: float) -> void:
	_flee_message_timer -= delta
	# Les héros d'une vague entrent un par un (les vétérans qui reviennent d'abord),
	# escouade par escouade.
	if not _pending_veterans.is_empty() or not _pending_heroes.is_empty():
		_hero_spawn_timer -= delta
		if _hero_spawn_timer <= 0.0:
			_hero_spawn_timer = HERO_SPAWN_GAP
			if not _pending_veterans.is_empty():
				_spawn_veteran(_pending_veterans.pop_front())
			else:
				var squad_id: int = _pending_squads.pop_front() if not _pending_squads.is_empty() else -1
				_spawn_hero(_pending_heroes.pop_front(), squad_id)
				# L'escouade suivante attend un peu avant d'entrer.
				if not _pending_squads.is_empty() and _pending_squads[0] != squad_id:
					_hero_spawn_timer = Rules.SQUAD_GAP
	elif _wave_in_progress and _invader_count() == 0:
		# Plus aucun héros vivant : la vague est repoussée.
		_wave_in_progress = false
		_waves_survived += 1
		Sound.play("discovery")
		hud.show_message("Vague repoussée ! Bravo, ton donjon tient bon.", 5.0)

	_wave_timer -= delta
	# L'éclaireur arrive un peu avant certaines vagues.
	if _wave_timer <= Rules.SCOUT_LEAD and _scout_wave != _next_wave and _scout_due(_next_wave):
		_scout_wave = _next_wave
		_send_scout()
	if _wave_timer <= 10.0 and not _wave_warned:
		_wave_warned = true
		_maybe_open_second_entrance()
		Sound.play("horn", null, -12.0)
		hud.show_message("Des héros approchent de l'entrée grise ! Prépare tes créatures.", 5.0)
	if _wave_timer > 0.0:
		return
	_start_wave()


func _update_music(delta: float) -> void:
	if _game_over:
		return
	_calm_countdown -= delta
	_music_timer -= delta
	if _music_timer > 0.0:
		return
	_music_timer = 0.5
	if _invader_count() > 0:
		_calm_countdown = CALM_MUSIC_DELAY
	Sound.play_music("combat" if _calm_countdown > 0.0 else "calm")


func _start_wave() -> void:
	_wave_timer = _wave_interval
	_wave_warned = false
	var wave_heroes := _planned_heroes(_next_wave)
	_wave_plan = {}
	var count := wave_heroes.size()
	var champion := _champion_leads_wave(_next_wave)
	if champion:
		wave_heroes.push_front(Heroes.Type.CHAMPION) # Il entre le premier.
	var main_squad := _form_squads(wave_heroes, _next_wave)
	_hero_spawn_timer = 0.0
	_wave_in_progress = true
	Sound.play("horn")
	if champion:
		Fx.shake(5.0, 0.5)
		hud.show_message("Vague %d : le CHAMPION DU ROYAUME mène %d héros contre toi !" % [_next_wave, count], 6.0)
	else:
		hud.show_message("Vague %d : %d héros entrent dans ton donjon !" % [_next_wave, count], 5.0)
	# Les héros qui t'ont échappé reviennent, plus forts (voir nemeses.gd).
	var veterans := nemeses.take_due(_next_wave, Rules.NEMESIS_PER_WAVE)
	if not veterans.is_empty():
		for entry: Dictionary in veterans:
			entry["squad"] = main_squad # Les vétérans entrent avec le gros de la troupe.
		_pending_veterans.append_array(veterans)
		var names: Array[String] = []
		for entry: Dictionary in veterans:
			names.append("%s (%s)" % [Nemeses.title(entry), Nemeses.rank_text(int(entry["rank"]))])
		hud.show_message("Ils reviennent se venger : %s !" % ", ".join(names), 6.0)
	_next_wave += 1


## Les héros d'une vague, tirés au sort une seule fois (l'Œil du maître peut les
## voir à l'avance). Dès la vague Rules.EXORCIST_SURE_WAVE, il y a toujours au
## moins un Exorciste : le royaume a compris que tu maîtrises la magie.
func _planned_heroes(wave: int) -> Array[int]:
	var heroes: Array[int] = []
	if int(_wave_plan.get("wave", -1)) == wave:
		for type in _wave_plan["heroes"]:
			heroes.append(int(type))
		return heroes
	var count := mini(1 + wave, MAX_HEROES_PER_WAVE)
	var types := Heroes.types_for_wave(wave)
	types = types.filter(func(t: int) -> bool: return not Heroes.info(t).get("scout", false))
	for i in count:
		heroes.append(types.pick_random())
	if wave >= Rules.EXORCIST_SURE_WAVE and not heroes.has(Heroes.Type.EXORCIST):
		heroes[randi() % heroes.size()] = Heroes.Type.EXORCIST
	_wave_plan = {"wave": wave, "heroes": heroes.duplicate()}
	return heroes


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


## Les ennemis qui attaquent le donjon (le Colosse endormi, qui garde sa caverne
## sans en sortir, ne compte pas : il n'empêche pas une vague d'être repoussée).
func _invader_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("heroes"):
		if node is Hero and not (node as Hero).is_guardian():
			count += 1
	return count


# ---------------------------------------------------------------------------
# Les profondeurs (voir dungeon_map.gd) : Colosse endormi, lac de lave, ruine oubliée
# ---------------------------------------------------------------------------

const SECRET_HINTS := {
	"colossus": "Un souffle énorme résonne derrière la roche... Quelque chose dort là. Continuer à creuser le réveillera.",
	"lava": "La roche est brûlante ici, et un grondement sourd monte des profondeurs... Prudence en creusant.",
	"ruin": "Des murmures anciens filtrent à travers la terre... Une ruine oubliée est toute proche.",
}


func _on_secret_hinted(kind: String, cell: Vector2i) -> void:
	Sound.play("horn", map.cell_to_world(cell), -16.0)
	hud.show_message(SECRET_HINTS[kind], 6.0)


func _on_secret_revealed(kind: String, center: Vector2i) -> void:
	var at := map.cell_to_world(center)
	Fx.shake(6.0, 0.5)
	Fx.burst("dust", at)
	match kind:
		"colossus":
			var colossus := _add_hero(Heroes.Type.COLOSSUS, center)
			Sound.play("door_break", at)
			Fx.flash_light(at, Color(1.0, 0.5, 0.2), 200.0, 0.8)
			hud.show_message("Tes ouvriers ont découvert le COLOSSE ENDORMI ! Il garde un trésor (%d or). Tant qu'il dort, tes créatures l'ignorent : quand tu seras prêt, touche « Attaquer le Colosse ». Vaincu, il te servira." %
					Rules.COLOSSUS_HOARD, 8.0)
			colossus.queue_redraw()
		"lava":
			Sound.play("explosion", at)
			Fx.flash_light(at, Color(1.0, 0.4, 0.1), 260.0, 1.0)
			hud.show_message("Un LAC DE LAVE se déverse dans tes couloirs ! Éloigne tes ouvriers. Refroidie, la lave deviendra de l'or volcanique (%d fois plus riche)." %
					int(Rules.VOLCANIC_GOLD), 7.0)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					_on_lava_flowed(center + Vector2i(dx, dy))
		"ruin":
			Sound.play("discovery", at)
			Fx.burst("magic", at, Color("b388ff"))
			Fx.flash_light(at, Color(0.6, 0.4, 1.0), 220.0, 1.0)
			var learned: Array[String] = []
			for i in Rules.RUIN_DISCOVERIES:
				if research.is_done():
					break
				learned.append(Research.ITEMS[research.next_index]["name"])
				research.add_points(Research.ITEMS[research.next_index]["points"] - research.points)
			if learned.is_empty():
				var stored := map.add_gold_to_treasury(Rules.RUIN_FALLBACK_GOLD)
				map.heart_gold += Rules.RUIN_FALLBACK_GOLD - stored
				map.gold_changed.emit()
				hud.show_message("Une RUINE OUBLIÉE ! Tout est déjà découvert : ses reliques valent %d or." %
						Rules.RUIN_FALLBACK_GOLD, 6.0)
			else:
				hud.show_message("Une RUINE OUBLIÉE ! Son savoir perdu te révèle : %s." % ", ".join(learned), 6.0)
			for i in Rules.RUIN_SPECTRES:
				var spectre := _add_hero(Heroes.Type.SPECTRE, center + Vector2i(randi_range(-1, 1), randi_range(-1, 1)))
				Fx.burst("magic", spectre.position, Color("80d8ff"))
			Sound.play("horn", at, -6.0)
			hud.show_message("%d spectres gardiens se réveillent et marchent sur ton cœur !" % Rules.RUIN_SPECTRES, 5.0)


## Le Colosse des profondeurs encore en vie (ou null).
func _guardian() -> Hero:
	for node in heroes_root.get_children():
		var hero := node as Hero
		if hero != null and hero.is_guardian() and not hero.is_dead() and not hero.is_queued_for_deletion():
			return hero
	return null


func _refresh_assault_button() -> void:
	var guardian := _guardian()
	if guardian == null:
		Creature.assault_target = null
		hud.set_assault_button("")
	elif Creature.assault_target == guardian:
		hud.set_assault_button("Rappeler les troupes", true)
	else:
		hud.set_assault_button("Attaquer le Colosse")


## Le bouton d'assaut : toutes tes créatures disponibles marchent sur le Colosse
## (il se réveille) ; un second appui les rappelle.
func _on_assault_pressed() -> void:
	var guardian := _guardian()
	if guardian == null:
		return
	if Creature.assault_target == guardian:
		Creature.assault_target = null
		for node in creatures_root.get_children():
			(node as Creature).call_back()
		hud.show_message("Tes créatures se replient. Le Colosse se rendormira bientôt.", 4.0)
	else:
		Creature.assault_target = guardian
		guardian.wake_up()
		camera.center_on(guardian.position)
		Sound.play("horn")
		hud.show_message("À l'assaut du Colosse ! Toutes tes créatures disponibles marchent sur sa caverne.", 5.0)
	_refresh_assault_button()


## La lave coule sur une case : les unités qui s'y trouvent sont brûlées et
## repoussées sur une case voisine ; les chemins qui la traversaient sont oubliés.
func _on_lava_flowed(cell: Vector2i) -> void:
	for root in [workers_root, creatures_root, heroes_root]:
		for node in root.get_children():
			var unit := node as Unit
			if unit == null or unit.is_dead() or unit.in_hand:
				continue
			if unit.path.has(cell):
				unit.path.clear()
			if unit.current_cell() != cell:
				continue
			var hero := unit as Hero
			if hero != null and (hero.is_captured() or hero.knocked_out or hero.carrier != null):
				continue
			for direction in DungeonMap.DIRECTIONS:
				if map.is_walkable(cell + direction):
					unit.position = map.cell_to_world(cell + direction)
					break
			unit.apply_burn(Rules.LAVA_BURN_TIME, Rules.LAVA_BURN_DPS)
			unit.take_damage(Rules.LAVA_DAMAGE)


func _spawn_hero(type: int, squad_id := -1) -> void:
	var squad: Dictionary = _squads.get(squad_id, {})
	var cell := map.entrance_cell
	if squad.has("entrance"):
		cell = SaveGame.array_to_cell(squad["entrance"])
	var hero := _add_hero(type, cell)
	_join_squad(hero, squad_id)


# ---------------------------------------------------------------------------
# Les escouades, leurs objectifs, l'éclaireur et la seconde entrée
# ---------------------------------------------------------------------------

const ROLE_NAMES := {"main": "le gros de la troupe", "flank": "des flanqueurs", "sapper": "des sapeurs"}
const OBJECTIVE_TEXTS := {
	"treasury": "piller ton Trésor",
	"prison": "libérer tes prisonniers",
	"library": "saccager ta Bibliothèque",
	"workers": "massacrer tes ouvriers",
	"assassinate": "abattre ta meilleure créature",
}


## Répartit les héros d'une vague en escouades et les met dans la file d'attente.
## Renvoie le numéro de l'escouade principale.
func _form_squads(wave_heroes: Array[int], wave: int) -> int:
	var total := wave_heroes.size()
	var squad_count := 1
	if total >= Rules.THREE_SQUADS_FROM:
		squad_count = 3
	elif total >= Rules.TWO_SQUADS_FROM:
		squad_count = 2
	var gates := map.entrances()
	var objective := _choose_objective(wave)
	var ids: Array[int] = []
	for i in squad_count:
		var id := _next_squad_id
		_next_squad_id += 1
		ids.append(id)
		var gate: Vector2i = gates[i % gates.size()]
		_squads[id] = {"role": ["main", "flank", "sapper"][i], "entrance": SaveGame.cell_to_array(gate),
				"objective": "", "size": 0, "lost": 0, "retreated": false, "avoid": [],
				"scouted": _scout_report.duplicate()}
	# L'objectif est confié aux flanqueurs (au gros de la troupe s'il est seul).
	_squads[ids[1 if squad_count > 1 else 0]]["objective"] = objective
	# Les flanqueurs évitent le chemin du gros de la troupe.
	if squad_count > 1:
		var main_gate := SaveGame.array_to_cell(_squads[ids[0]]["entrance"])
		var route := map.find_hero_path(main_gate)
		var avoid := []
		for i in range(2, maxi(2, route.size() - 3)): # (Ni l'entrée, ni les abords du cœur.)
			avoid.append(SaveGame.cell_to_array(route[i]))
		_squads[ids[1]]["avoid"] = avoid
	# Les Nains vont chez les sapeurs ; le Champion reste avec le gros de la troupe.
	var buckets: Array = []
	for i in squad_count:
		buckets.append([])
	var others: Array[int] = []
	for type in wave_heroes:
		if squad_count == 3 and type == Heroes.Type.DWARF:
			buckets[2].append(type)
		elif type == Heroes.Type.CHAMPION:
			buckets[0].append(type)
		else:
			others.append(type)
	var target_size := int(ceil(float(total) / squad_count))
	var next := 0
	for type in others:
		# Chacun rejoint la première escouade pas encore pleine (dans l'ordre).
		var tries := 0
		while buckets[next].size() >= target_size and tries < squad_count:
			next = (next + 1) % squad_count
			tries += 1
		buckets[next].append(type)
		next = (next + 1) % squad_count
	for i in squad_count:
		_squads[ids[i]]["size"] = buckets[i].size()
		for type in buckets[i]:
			_pending_heroes.append(type)
			_pending_squads.append(ids[i])
	# On annonce le plan des héros.
	if squad_count > 1:
		var parts: Array[String] = []
		for i in squad_count:
			if buckets[i].is_empty():
				continue
			var gate_text := " (par la seconde entrée)" if SaveGame.array_to_cell(_squads[ids[i]]["entrance"]) != map.entrance_cell else ""
			parts.append("%s : %d%s" % [ROLE_NAMES[_squads[ids[i]]["role"]], buckets[i].size(), gate_text])
		hud.show_message("Les héros arrivent en %d escouades — %s." % [squad_count, ", ".join(parts)], 6.0)
	if objective != "":
		hud.show_message("Leur objectif : %s !" % OBJECTIVE_TEXTS[objective], 6.0)
	if not _scout_report.is_empty():
		hud.show_message("Grâce à leur éclaireur, ils connaissent %d de tes pièges et vont les éviter." %
				_scout_report.size(), 5.0)
	_scout_report.clear()
	return ids[0]


## L'objectif de la vague (ou "" : le cœur). Une vague sur Rules.OBJECTIVE_EVERY,
## parmi ceux qui ont un sens dans ton donjon.
func _choose_objective(wave: int) -> String:
	if wave < Rules.OBJECTIVE_FIRST_WAVE or (wave - Rules.OBJECTIVE_FIRST_WAVE) % Rules.OBJECTIVE_EVERY != 0:
		return ""
	var options: Array[String] = ["workers"]
	if map.get_treasury_stored() > 0:
		options.append("treasury")
	if not map.prisoners.is_empty():
		options.append("prison")
	if map.count_room_tiles(Rooms.Type.LIBRARY) > 0:
		options.append("library")
	if creatures_root.get_child_count() > 0:
		options.append("assassinate")
	return options.pick_random()


## Un héros rejoint son escouade : son rôle, son objectif, le chemin à éviter, et
## le temps qu'il attendra ses compagnons à l'entrée.
func _join_squad(hero: Hero, squad_id: int) -> void:
	if not _squads.has(squad_id):
		return
	var squad: Dictionary = _squads[squad_id]
	hero.squad = squad_id
	hero.role = squad["role"]
	var info := Heroes.info(hero.type)
	if squad["objective"] != "" and not info.get("stealth", false) and not info.get("liberator", false) \
			and not info.get("boss", false):
		hero.objective = squad["objective"]
	for values in squad["avoid"]:
		hero.flank_avoid[SaveGame.array_to_cell(values)] = true
	var scouted: Array = []
	for values in squad["scouted"]:
		scouted.append(SaveGame.array_to_cell(values))
	hero.learn_traps(scouted)
	var waiting := _pending_squads.count(squad_id)
	hero.hold_left = waiting * HERO_SPAWN_GAP + Rules.REGROUP_TIME


## Un héros d'une escouade est tombé (mort, assommé ou capturé). Si la moitié de
## l'escouade est tombée, les survivants battent en retraite ensemble.
func _on_squad_loss(hero: Hero) -> void:
	if hero.loss_counted or not _squads.has(hero.squad):
		return
	hero.loss_counted = true
	var squad: Dictionary = _squads[hero.squad]
	squad["lost"] = int(squad["lost"]) + 1
	if squad["retreated"] or int(squad["size"]) < Rules.SQUAD_RETREAT_MIN_SIZE \
			or int(squad["lost"]) * 2 < int(squad["size"]):
		return
	squad["retreated"] = true
	# Ceux qui n'étaient pas encore entrés ne viennent plus.
	for i in range(_pending_squads.size() - 1, -1, -1):
		if _pending_squads[i] == hero.squad:
			_pending_squads.remove_at(i)
			_pending_heroes.remove_at(i)
	var fleeing := 0
	for node in heroes_root.get_children():
		var other := node as Hero
		if other == null or other == hero or other.squad != hero.squad or other.is_dead() \
				or other.is_captured() or other.knocked_out or other.carrier != null or not other._can_flee():
			continue
		other.start_fleeing(false)
		fleeing += 1
	if fleeing > 0:
		Sound.play("horn", hero.position, -8.0)
		hud.show_message("L'escouade a perdu la moitié des siens : %d héros battent en retraite ! Rattrape-les, sinon ils reviendront." %
				fleeing, 5.0)


func _scout_due(wave: int) -> bool:
	return wave >= Rules.SCOUT_FIRST_WAVE and (wave - Rules.SCOUT_FIRST_WAVE) % Rules.SCOUT_EVERY == 0


func _send_scout() -> void:
	var gates := map.entrances()
	var scout := _add_hero(Heroes.Type.SCOUT, gates.pick_random())
	scout.objective = "scout"
	Sound.play("horn", scout.position, -16.0)
	hud.show_message("Un éclaireur se faufile dans ton donjon ! S'il ressort vivant, la prochaine vague connaîtra tes pièges.", 5.0)


## L'éclaireur est ressorti : la prochaine vague évitera les pièges qu'il a vus.
func _on_scout_returned(scout: Hero) -> void:
	_scout_report.clear()
	for cell: Vector2i in scout.seen_traps:
		_scout_report.append(SaveGame.cell_to_array(cell))
	Sound.play("error")
	hud.show_message("L'éclaireur est reparti faire son rapport : la prochaine vague connaît %d de tes pièges." %
			_scout_report.size(), 5.0)


## À la vague Rules.SECOND_ENTRANCE_WAVE, un éboulement ouvre une seconde entrée.
func _maybe_open_second_entrance() -> void:
	var from_wave: int = level.get("second_entrance_wave", Rules.SECOND_ENTRANCE_WAVE)
	if from_wave <= 0 or _next_wave < from_wave or map.hidden_entrance == Vector2i(-1, -1):
		return
	var gate := map.open_hidden_entrance()
	var at := map.cell_to_world(gate)
	Sound.play("explosion", at)
	Fx.shake(8.0, 0.6)
	Fx.burst("dust", at)
	if _lights_root != null:
		_make_light(at, Color(0.8, 0.85, 1.0), 170.0, 0.8)
	if _view3d != null:
		_view3d.add_entrance_light(gate)
	hud.show_message("Un éboulement ouvre une SECONDE ENTRÉE grise ! Désormais, les escouades de héros se répartissent entre les deux.", 7.0)


## Un vétéran revient par l'entrée : plus fort, et il se souvient de tes pièges.
func _spawn_veteran(entry: Dictionary) -> void:
	var squad_id := int(entry.get("squad", -1))
	var cell := map.entrance_cell
	if _squads.has(squad_id):
		cell = SaveGame.array_to_cell(_squads[squad_id]["entrance"])
	var hero := _add_hero(int(entry["type"]), cell)
	hero.apply_nemesis(entry)
	_join_squad(hero, squad_id)
	Sound.play("horn", hero.position, -6.0)
	Fx.burst("sparks", hero.position, Color("ffd54a"))
	Fx.flash_light(hero.position, Color(1.0, 0.85, 0.4), 140.0, 0.5)


## Un héros gravement blessé bat en retraite.
func _on_hero_started_fleeing(hero: Hero) -> void:
	if _flee_message_timer > 0.0:
		return
	_flee_message_timer = 4.0
	var she := Nemeses.is_feminine(hero.type)
	hud.show_message("%s bat en retraite ! Rattrape-%s avant l'entrée grise, sinon %s reviendra plus fort%s." %
			[hero.display_name(), "la" if she else "le", "elle" if she else "il", "e" if she else ""], 4.0)


## Un héros est sorti vivant : il reviendra en vétéran, une ou deux vagues plus tard.
func _on_hero_retreated(hero: Hero) -> void:
	if _game_over:
		return
	if hero.is_scout():
		_on_scout_returned(hero) # Un éclaireur ne revient pas en vétéran : il fait son rapport.
		return
	var return_wave := _next_wave + randi_range(Rules.NEMESIS_RETURN_MIN, Rules.NEMESIS_RETURN_MAX) - 1
	var entry := nemeses.record(hero, return_wave)
	Sound.play("horn", hero.position, -12.0)
	var she := Nemeses.is_feminine(hero.type)
	var memory := ""
	if not hero.known_traps.is_empty():
		memory = " %s se souviendra de tes pièges." % ("Elle" if she else "Il")
	hud.show_message("%s s'est échappé%s ! %s reviendra à la vague %d, en %s.%s" %
			[Nemeses.title(entry), "e" if she else "", "Elle" if she else "Il", return_wave,
			Nemeses.rank_text(int(entry["rank"])), memory], 5.0)


## Un combo de pièges vient de se déclencher (voir combos.gd).
func _on_combo_triggered(id: String, world_position: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_combo_shown.get(id, -100000)) > 1000:
		_combo_shown[id] = now
		Fx.text(world_position, Combos.INFO[id]["name"] + " !", Color("ffb74d"))
	if Combos.discover(id):
		Sound.play("discovery")
		Fx.flash_light(world_position, Color(1.0, 0.7, 0.3), 180.0, 0.6)
		hud.show_message("Combo découvert : %s ! %s (%d / %d dans le codex)" % [Combos.INFO[id]["name"],
				Combos.INFO[id]["text"], Combos.discovered_count(), Combos.INFO.size()], 6.0)


func _add_hero(type: int, cell: Vector2i) -> Hero:
	var hero := Hero.new()
	hero.setup_hero(map, cell, type)
	if hero.is_guardian():
		map.guarded[cell] = true # Ses abords sont interdits aux ouvriers tant qu'il vit.
		hero.guardian_woke.connect(func(_h: Hero) -> void:
			if Creature.assault_target != _h:
				hud.show_message("Le Colosse s'est réveillé ! Éloigne tes créatures, ou touche « Attaquer le Colosse ».", 5.0))
		hero.guardian_slept.connect(func(_h: Hero) -> void:
			hud.show_message("Le Colosse se rendort dans sa caverne.", 3.0))
	hero.died.connect(_on_hero_died)
	hero.captured.connect(_on_hero_captured)
	hero.fell.connect(func(fallen: Hero) -> void:
		_on_squad_loss(fallen)
		_hint("Un héros est assommé ! Tes Attrapeurs de cauchemar vont l'emmener en prison."))
	hero.stole.connect(func(thief: Hero, amount: int) -> void:
		Sound.play("horn", thief.position, -14.0)
		hud.show_message("%s a pillé ton Trésor : %d or ! Arrête-le avant qu'il ne sorte !" % [thief.display_name(), amount], 5.0))
	hero.escaped.connect(func(thief: Hero, amount: int) -> void:
		Sound.play("error")
		if thief.type == Heroes.Type.THIEF:
			hud.show_message("La Voleuse s'est enfuie avec %d or. Un Cerbère au Trésor l'aurait flairée..." % amount, 5.0)
		else:
			hud.show_message("%s s'est enfui avec %d or de ton Trésor." % [thief.display_name(), amount], 5.0))
	hero.started_fleeing.connect(_on_hero_started_fleeing)
	hero.retreated.connect(_on_hero_retreated)
	hero.freed_prisoner.connect(func(prisoner: Hero) -> void:
		hud.show_message("Un Moine a ouvert une cellule : %s s'évade !" % prisoner.display_name(), 4.0))
	# Plus les vagues passent, plus les héros résistent à tes sorts (voir rules.gd).
	hero.set_spell_resist(_next_wave - 1)
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
	_on_squad_loss(hero)
	if hero.type == Heroes.Type.CHAMPION:
		_champions_defeated += 1
	if hero.is_veteran():
		hud.show_message("%s finit dans tes geôles : %s ne s'échappera plus !" %
				[hero.display_name(), "elle" if Nemeses.is_feminine(hero.type) else "il"], 4.0)
	var stored := map.add_gold_to_treasury(hero.reward())
	hud.show_message("%s capturé ! +%d or de rançon. Interrogé, il fera avancer la recherche." %
			[hero.display_name(), stored], 4.0)


## Un héros vaincu rapporte une rançon, rangée au trésor s'il y a de la place.
func _on_hero_died(unit: Unit) -> void:
	var hero := unit as Hero
	_on_squad_loss(hero)
	if hero.is_scout():
		hud.show_message("L'éclaireur est mort : la prochaine vague arrivera à l'aveugle.", 4.0)
	if hero.type == Heroes.Type.CHAMPION:
		_champions_defeated += 1
		Fx.shake(8.0, 0.5)
		hud.show_message("Le Champion du royaume est tombé ! Sa rançon est immense.", 5.0)
	if hero.is_guardian():
		map.guarded.erase(hero.home_cell)
		# Le Colosse vaincu se soumet : il rejoint ton donjon.
		var ancient := _add_creature(Creatures.Type.COLOSSUS, hero.current_cell())
		ancient.happiness = 100.0
		Fx.burst("magic", ancient.position, Color("ff8a50"))
		Fx.flash_light(ancient.position, Color(1.0, 0.5, 0.2), 200.0, 0.8)
		Sound.play("level_up", ancient.position)
		hud.show_message("Le Colosse est vaincu ! Il s'incline devant toi : le Colosse ancien rejoint ton donjon.", 6.0)
	if hero.is_veteran() and not hero.no_ransom:
		Fx.shake(4.0, 0.3)
		var she := Nemeses.is_feminine(hero.type)
		hud.show_message("%s est tombé%s pour de bon : %s ne reviendra plus !" %
				[hero.display_name(), "e" if she else "", "elle" if she else "il"], 4.0)
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
	if Heroes.info(hero.type).get("rival", false) or Heroes.info(hero.type).get("no_capture", false):
		return # Les troupes du rival ne sont pas des héros (ni les habitants des profondeurs).
	var grave := map.bury()
	if grave == Vector2i(-1, -1):
		return
	var grave_position := map.cell_to_world(grave)
	Fx.burst("dust", grave_position)
	Fx.burst("magic", grave_position, Color("76ff03"))
	_hint("%s est enterré au Cimetière. Bientôt, il se relèvera en Revenant !" % hero.display_name())


## Les créatures qui ont besoin d'un lit (les morts-vivants n'en ont pas besoin).
func _creatures_needing_beds() -> int:
	var count := 0
	for creature: Creature in creatures_root.get_children():
		if not creature.is_undead():
			count += 1
	return count


func _count_creatures(type: int) -> int:
	var count := 0
	for creature: Creature in creatures_root.get_children():
		if creature.type == type and not creature.is_queued_for_deletion():
			count += 1
	return count


## Les héros enterrés se relèvent en Revenants (pas besoin de lit : ce sont des
## morts-vivants). Au-delà de Rules.MAX_REVENANTS, le héros repose en paix.
func _update_graves(delta: float) -> void:
	_grave_timer -= delta
	if _grave_timer > 0.0:
		return
	_grave_timer = 1.0
	for cell in map.ready_graves():
		map.empty_grave(cell)
		if _count_creatures(Creatures.Type.REVENANT) >= Rules.MAX_REVENANTS:
			_hint("Assez de Revenants : ce héros repose en paix, sa tombe se libère.")
			continue
		var revenant := _add_creature(Creatures.Type.REVENANT, cell)
		Fx.raise_hand(revenant.position)
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
	Sound.play_music("defeat")
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
	Sound.play_music("victory")
	Sound.play("discovery")
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
## Dans un navigateur (version web), fermer l'onglet ne prévient pas le jeu : on
## sauvegarde donc dès que la page perd le focus (changement d'onglet, clic ailleurs).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("web"):
		save_game()


## Écrit toute la partie dans le fichier de sauvegarde. Renvoie true si c'est réussi.
func save_game() -> bool:
	if _game_over or not is_node_ready():
		return false
	var workers := []
	# (Les unités temporaires, invoquées par un sort, ne sont pas sauvegardées.)
	for worker: Worker in workers_root.get_children():
		if not worker.is_dead() and worker.lifetime <= 0.0:
			workers.append(worker.to_save())
	var creatures := []
	for creature: Creature in creatures_root.get_children():
		if not creature.is_dead() and not creature.is_leaving() and creature.lifetime <= 0.0:
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
			"pending_squads": _pending_squads,
			"squads": _squads,
			"next_squad_id": _next_squad_id,
			"scout_wave": _scout_wave,
			"scout_report": _scout_report,
			"arrival_timer": _arrival_timer,
			"portal_connected": _portal_connected,
			"rival_timer": _rival_timer,
			"rival_squads": _rival_squads,
			"champions_defeated": _champions_defeated,
			"pending_veterans": _pending_veterans,
			"wave_plan": _wave_plan,
		},
		"nemeses": nemeses.to_save(),
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
		if values.has("nemesis"):
			hero.apply_nemesis(values["nemesis"])
		for cell_values in values.get("known_traps", []):
			hero.remember_trap(SaveGame.array_to_cell(cell_values))
		if values.has("squad"):
			hero.squad = int(values["squad"])
			hero.role = String(values.get("role", "main"))
			hero.objective = String(values.get("objective", ""))
			hero.hold_left = float(values.get("hold", 0.0))
		elif values.get("scout", false):
			hero.objective = "scout"
		for key in ["flank_avoid", "scouted_traps", "seen_traps"]:
			var cells: Dictionary = hero.get(key)
			for cell_values in values.get(key, []):
				cells[SaveGame.array_to_cell(cell_values)] = true
		if values.get("fleeing", false):
			hero.start_fleeing(false)
		if values.has("home"):
			map.guarded.erase(hero.home_cell)
			hero.home_cell = SaveGame.array_to_cell(values["home"])
			map.guarded[hero.home_cell] = true
			hero.awake = bool(values.get("awake", false))
			if values.get("assault", false):
				Creature.assault_target = hero
		hero.hp = float(values["hp"])
		hero.loot = int(values.get("loot", 0))
		hero.spell_resist = float(values.get("resist", 0.0))

	Levels.current_id = int(data.get("level_id", 0))
	level = Levels.current()
	_wave_interval = level.get("wave_interval", WAVE_INTERVAL)
	var state: Dictionary = data["state"]
	_rival_timer = float(state.get("rival_timer", level.get("rival_interval", 80.0)))
	_rival_squads = int(state.get("rival_squads", 0))
	_champions_defeated = int(state.get("champions_defeated", 0))
	_pending_veterans = state.get("pending_veterans", []).duplicate(true)
	_wave_plan = state.get("wave_plan", {}).duplicate(true)
	nemeses.load_save(data.get("nemeses", []))
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
	_pending_squads.clear()
	for id in state.get("pending_squads", []):
		_pending_squads.append(int(id))
	while _pending_squads.size() < _pending_heroes.size(): # (Ancienne sauvegarde.)
		_pending_squads.append(-1)
	_squads.clear()
	var saved_squads: Dictionary = state.get("squads", {})
	for key in saved_squads: # (Le JSON a changé les numéros en textes.)
		_squads[int(key)] = saved_squads[key]
	_next_squad_id = int(state.get("next_squad_id", 0))
	_scout_wave = int(state.get("scout_wave", 0))
	_scout_report = state.get("scout_report", []).duplicate(true)

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

	# D'abord les revenus : ton territoire rapporte un peu d'or (voir Rules.TERRITORY_INCOME).
	var income := _territory_income()
	if income > 0:
		var stored := map.add_gold_to_treasury(income)
		map.heart_gold += income - stored # Pas de place au Trésor : l'or va au cœur.
		map.gold_changed.emit()
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
	elif total_paid > 0 or income > 0:
		Sound.play("coins")
		hud.show_message("Jour de paie : +%d or d'impôts du territoire, %d or versés à tes créatures." %
				[income, total_paid])


## L'or que rapporte le territoire à chaque paie.
func _territory_income() -> int:
	return map.claimed.size() * Rules.TERRITORY_INCOME


## Le total des salaires de la prochaine paie.
func _salaries_due() -> int:
	var total := 0
	for creature: Creature in creatures_root.get_children():
		if not creature.is_leaving():
			total += creature.salary()
	return total


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
	hud.set_creatures(_creatures_needing_beds(), map.count_room_tiles(Rooms.Type.LAIR))
	var due := _salaries_due()
	var income := _territory_income()
	hud.set_payday(ceili(_payday_timer), due, income, map.get_total_gold() + income >= due)
	hud.set_heart(map.heart_hp, DungeonMap.HEART_MAX_HP)
	hud.set_next_wave(_next_wave, ceili(_wave_timer))
	hud.set_mana(mana, _max_mana())
	hud.set_goal(_goal_status_text())
	var research_text := research.status_text()
	var workshop_target := _workshop_target()
	if workshop_target >= 0 and map.count_room_tiles(Rooms.Type.WORKSHOP) > 0:
		research_text += "\nAtelier : %s %d %%" % [Defenses.display_name(workshop_target),
				100.0 * workshop_points / Defenses.cost(workshop_target)]
	hud.set_research(research_text)
	_refresh_assault_button()
	_refresh_tools()


## Met à jour le texte des outils (prix, stock) et grise ceux pas encore découverts.
func _refresh_tools() -> void:
	for tool: int in TOOL_ROOMS:
		var room: int = TOOL_ROOMS[tool]
		var size := Rooms.footprint(room)
		var text := "%s (%d)" % [Rooms.display_name(room), Rooms.cost(room)]
		if size != Vector2i.ONE:
			text = "%s %dx%d (%d)" % [Rooms.display_name(room), size.x, size.y, Rooms.cost(room)]
		_set_tool(tool, text, Rooms.display_name(room), research.is_unlocked("room", room))
	for tool: int in TOOL_DEFENSES:
		var defense: int = TOOL_DEFENSES[tool]
		if Defenses.bought_with_gold(defense):
			_set_tool(tool, "%s (%d)" % [Defenses.display_name(defense), Defenses.cost(defense)],
					Defenses.display_name(defense), true)
			continue
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
	# Les salles d'une case se « peignent » au doigt ; les grandes se posent d'un toucher.
	camera.paint_mode = tool == Hud.Tool.DIG or tool == Hud.Tool.DEMOLISH \
			or (TOOL_ROOMS.has(tool) and Rooms.footprint(TOOL_ROOMS[tool]) == Vector2i.ONE)
	if tool == Hud.Tool.HAND:
		hud.show_message("Touche une créature ou un ouvrier pour le prendre, puis touche le sol pour le déposer.", 5.0)
	elif TOOL_SPELLS.has(tool):
		var spell: int = TOOL_SPELLS[tool]
		var help: String = Spells.INFO[spell]["help"]
		var room := Spells.required_room(spell)
		if room != Rooms.Type.NONE and map.count_room_tiles(room) == 0:
			help += " Il te faut d'abord un %s." % Rooms.display_name(room)
		hud.show_message("%s : %s" % [Spells.display_name(spell), help], 4.0)


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
	for gate in map.extra_entrances:
		_make_light(map.cell_to_world(gate), Color(0.8, 0.85, 1.0), 170.0, 0.8)
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
	# Les flammes vacillent un peu (chaque torche à son rythme). En vue 3D, le monde 2D
	# et ses lumières sont cachés : inutile de les animer.
	if world_root.visible:
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
	_screen_touch = screen_position
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
			hud.select_unit(creature) # Sa fiche s'affiche en bas à gauche.
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
	_screen_touch = screen_position
	world_position = _to_map(world_position)
	if hud.is_over_ui(screen_position):
		return
	var cell := map.world_to_cell(world_position)
	match current_tool:
		Hud.Tool.DIG:
			# Toucher une créature affiche son état.
			var creature := _creature_at(world_position)
			if creature:
				hud.select_unit(creature) # Sa fiche s'affiche en bas à gauche.
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
		if _view3d != null:
			# En 3D : on compare à l'écran avec le milieu du corps du personnage.
			if _view3d.unproject(unit.position, 0.45).distance_to(_screen_touch) < 40.0:
				return unit
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
	if dropped is Creature and cell == map.portal_cell:
		# Déposée sur le portail : la créature est renvoyée, son lit se libère.
		var creature := dropped as Creature
		hud.show_message("%s est renvoyé par le portail." % creature.display_name(), 3.0)
		Sound.play("leave", creature.position)
		Fx.burst("magic", creature.position)
		creature.dismiss()
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
	# La salle se pose d'un seul bloc, à la taille de son objet, autour de la case touchée.
	var spot := map.find_block_spot(cell, room_type)
	if spot.is_empty():
		var size := Rooms.footprint(room_type)
		_fail("Pas la place : la salle %s fait %d x %d cases de sol revendiqué et libre." %
				[Rooms.display_name(room_type), size.x, size.y])
		return
	var cost := Rooms.cost(room_type)
	if not map.spend_gold(cost):
		_fail("Pas assez d'or : la salle %s coûte %d." % [Rooms.display_name(room_type), cost])
		return
	# Les ouvriers viendront construire toutes les cases (voir worker.gd) : en
	# attendant, c'est un chantier, qui ne sert à rien.
	map.start_room_block(spot["origin"], spot["size"], room_type)
	Sound.play("build", map.cell_to_world(cell), -8.0)
	_hint("Tes ouvriers vont construire : un chantier ne sert qu'une fois terminé.")


## Les pièges et portes ne s'achètent pas : on pose ceux fabriqués par l'Atelier.
func _place_defense(cell: Vector2i, type: int) -> void:
	if not map.can_place_defense(cell):
		_fail("Les pièges et les portes se posent sur le sol revendiqué des couloirs.")
		return
	if Defenses.bought_with_gold(type):
		# Le brasero s'achète : un ouvrier viendra l'installer.
		if not map.spend_gold(Defenses.cost(type)):
			_fail("Pas assez d'or : le %s coûte %d." % [Defenses.display_name(type), Defenses.cost(type)])
			return
		map.start_construction(cell, "defense", type)
		Sound.play("build", map.cell_to_world(cell), -8.0)
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
		# Chantier annulé (toute la salle s'il s'agit d'un bloc) : on rend l'or de
		# la salle, ou le piège à son stock.
		var site := map.cancel_construction(cell)
		if site["kind"] == "room":
			var refund := Rooms.cost(site["type"])
			var stored := map.add_gold_to_treasury(refund)
			map.heart_gold += refund - stored # Pas de place au Trésor : l'or revient au cœur.
			map.gold_changed.emit()
		elif Defenses.bought_with_gold(site["type"]):
			_refund(Defenses.cost(site["type"]))
		else:
			trap_stock[site["type"]] += 1
		Sound.play("build", map.cell_to_world(cell), -6.0)
		return
	if map.defenses.has(cell):
		# Le piège retourne dans le stock (une porte abîmée est réparée au passage).
		# Un brasero démoli rend la moitié de son prix.
		var defense_type: int = map.defenses[cell]["type"]
		if Defenses.bought_with_gold(defense_type):
			_refund(Defenses.cost(defense_type) / 2)
		else:
			trap_stock[defense_type] += 1
		map.remove_defense(cell)
		Sound.play("build", map.cell_to_world(cell), -6.0)
		return
	if map.get_room(cell) == Rooms.Type.NONE:
		return
	var lost := map.remove_room(cell)
	Sound.play("build", map.cell_to_world(cell), -6.0)
	if lost > 0:
		hud.show_message("Plus de place dans le trésor : %d or perdu !" % lost)


## On touche le portrait du Seigneur : il donne un conseil selon la situation.
func _on_advice_requested() -> void:
	Sound.play("click")
	hud.portrait.react("?", false)
	hud.portrait.say(_advice(), 5.0)


## Le conseil le plus utile en ce moment (du plus urgent au plus général).
func _advice() -> String:
	var gold := map.get_total_gold()
	if not map.is_portal_connected():
		return "Creuse un couloir jusqu'au portail violet : mes serviteurs viendront par là."
	if map.count_rooms(Rooms.Type.TREASURY) == 0:
		return "Bâtis un Trésor : mon or doit être rangé quelque part !"
	if map.count_rooms(Rooms.Type.LAIR) == 0:
		return "Sans Repaire, aucune créature ne viendra. Il leur faut des lits."
	if map.count_rooms(Rooms.Type.FARM) == 0 and creatures_root.get_child_count() > 0:
		return "Mes créatures auront faim : une Champignonnière, vite !"
	if gold + _territory_income() < _salaries_due():
		return "La paie approche et l'or manque. Creuse des filons, loin du cœur !"
	if _wave_timer < 60.0:
		return "Des héros arrivent dans %d secondes. Prépare pièges et portes !" % ceili(_wave_timer)
	if _creatures_needing_beds() >= map.count_rooms(Rooms.Type.LAIR):
		return "Tous les lits sont pris : ajoute des lits au Repaire pour accueillir d'autres créatures."
	if map.count_rooms(Rooms.Type.LIBRARY) == 0 and gold >= Rooms.cost(Rooms.Type.LIBRARY):
		return "Une Bibliothèque ferait venir des Sorciers et découvrir de nouveaux secrets."
	return ["Les filons loin du cœur sont plus riches.",
			"Un brasero apaise mes créatures. Mets-en près de leurs salles.",
			"Plus mon territoire est grand, plus il rapporte à chaque paie.",
			"Les gemmes bleues ne s'épuisent jamais..."].pick_random()


## Rend de l'or (au Trésor, ou au cœur s'il n'y a plus de place).
func _refund(amount: int) -> void:
	var stored := map.add_gold_to_treasury(amount)
	map.heart_gold += amount - stored
	map.gold_changed.emit()


func _on_summon_pressed() -> void:
	if not map.spend_gold(WORKER_COST):
		_fail("Pas assez d'or ! Creuse les filons dorés.")
		return
	_spawn_worker()
	Sound.play("portal", map.cell_to_world(map.heart_cell), -6.0)
	_refresh_hud()

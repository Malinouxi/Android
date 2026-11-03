extends Node2D
## Le « chef d'orchestre » du jeu : il relie la carte, la caméra, l'interface,
## les ouvriers et les créatures. Il gère aussi :
##   - l'outil choisi quand on touche la carte ;
##   - l'arrivée des créatures par le portail ;
##   - le jour de paie ;
##   - les vagues de héros et la fin de partie ;
##   - la sauvegarde, le chargement et la pause ;
##   - la mana et les sorts, la recherche et la fabrication des pièges.
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
const AUTOSAVE_INTERVAL := 60.0
const MENU_SCENE := "res://scenes/menu.tscn"

## Quelle salle construit chaque outil de la barre.
const TOOL_ROOMS := {
	Hud.Tool.TREASURY: Rooms.Type.TREASURY,
	Hud.Tool.LAIR: Rooms.Type.LAIR,
	Hud.Tool.FARM: Rooms.Type.FARM,
	Hud.Tool.LIBRARY: Rooms.Type.LIBRARY,
	Hud.Tool.WORKSHOP: Rooms.Type.WORKSHOP,
	Hud.Tool.TRAINING: Rooms.Type.TRAINING,
}
## Quel sort lance chaque bouton du panneau de gauche.
const TOOL_SPELLS := {
	Hud.Tool.SPELL_HEAL: Spells.Type.HEAL,
	Hud.Tool.SPELL_LIGHTNING: Spells.Type.LIGHTNING,
	Hud.Tool.SPELL_HASTE: Spells.Type.HASTE,
}
## L'atelier arrête de fabriquer quand le stock total atteint ce nombre.
const MAX_TRAP_STOCK := 9
## Quelle défense pose chaque outil de la barre.
const TOOL_DEFENSES := {
	Hud.Tool.SPIKES: Defenses.Type.SPIKES,
	Hud.Tool.RUNE: Defenses.Type.RUNE,
	Hud.Tool.DOOR: Defenses.Type.DOOR,
}

@onready var map: DungeonMap = $DungeonMap
@onready var workers_root: Node2D = $Workers
@onready var creatures_root: Node2D = $Creatures
@onready var heroes_root: Node2D = $Heroes
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

var _wave_timer := FIRST_WAVE_DELAY
var _next_wave := 1
var _waves_survived := 0
var _wave_in_progress := false
var _wave_warned := false
var _pending_heroes: Array[int] = []
var _hero_spawn_timer := 0.0

## La recherche de la Bibliothèque (voir research.gd).
var research := Research.new()
var mana := Spells.START_MANA
## Points de fabrication accumulés par l'Atelier vers le prochain piège.
var workshop_points := 0.0
## Pièges et portes fabriqués, prêts à être posés : Defenses.Type -> nombre.
var trap_stock := {Defenses.Type.SPIKES: 0, Defenses.Type.RUNE: 0, Defenses.Type.DOOR: 0}

var _autosave_timer := AUTOSAVE_INTERVAL
var _game_over := false


func _ready() -> void:
	Sound.reset_music_volume() # Au cas où la défaite l'avait baissée.
	# On branche les signaux sur nos fonctions.
	map.gold_changed.connect(_refresh_hud)
	camera.tapped.connect(_on_camera_tapped)
	hud.summon_pressed.connect(_on_summon_pressed)
	hud.tool_selected.connect(_on_tool_selected)
	hud.restart_pressed.connect(_on_restart_pressed)
	map.heart_changed.connect(_on_heart_changed)
	map.heart_destroyed.connect(_on_heart_destroyed)
	map.door_destroyed.connect(func(_cell: Vector2i) -> void:
		hud.show_message("Les héros ont enfoncé une porte !", 3.0))
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.resume_pressed.connect(_on_resume_pressed)
	hud.save_pressed.connect(func() -> void:
		if save_game():
			hud.show_message("Partie sauvegardée."))
	hud.menu_pressed.connect(_on_menu_pressed)
	research.discovered.connect(_on_research_discovered)

	camera.bounds = Rect2(Vector2.ZERO, map.get_pixel_size())
	camera.position = map.cell_to_world(map.heart_cell)
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


func _start_new_game() -> void:
	map.set_starting_gold(START_GOLD)
	for i in START_WORKERS:
		_spawn_worker()
	hud.show_message("Creuse jusqu'au portail violet pour attirer des créatures. Les héros arriveront par l'entrée grise !", 8.0)


func _process(delta: float) -> void:
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_INTERVAL
		save_game()

	# La mana se recharge, plus vite avec un grand territoire.
	mana = minf(Spells.MAX_MANA, mana + Spells.regen_per_second(map.claimed.size()) * delta)
	# On dit aux créatures s'il reste quelque chose à chercher ou à fabriquer.
	Creature.research_needed = not research.is_done()
	Creature.workshop_needed = _workshop_target() >= 0

	_hint_timer -= delta
	_update_portal(delta)
	_update_payday(delta)
	_update_waves(delta)
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


func _on_research_discovered(item: Dictionary) -> void:
	Sound.play("discovery")
	hud.show_message("Découverte : %s ! Regarde ta barre d'outils." % item["name"], 5.0)


## Le piège que l'atelier fabrique en ce moment : le moins nombreux parmi ceux
## déjà découverts. Renvoie -1 s'il n'y a rien à fabriquer.
func _workshop_target() -> int:
	var total := 0
	for type: int in trap_stock:
		total += trap_stock[type]
	if total >= MAX_TRAP_STOCK:
		return -1
	var best := -1
	for type: int in trap_stock:
		if research.is_unlocked("defense", type) and (best < 0 or trap_stock[type] < trap_stock[best]):
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
				cast = true
		Spells.Type.LIGHTNING:
			for unit in _units_near("heroes", world_position, info["radius"]):
				unit.take_damage(info["damage"])
				cast = true
		Spells.Type.HASTE:
			var targets := _units_near("dungeon", world_position, 20.0)
			if not targets.is_empty():
				targets[0].apply_haste(info["duration"])
				cast = true
	if not cast:
		_fail("Aucune cible ici : touche %s." % (
				"un héros" if type == Spells.Type.LIGHTNING else "une de tes unités"))
		return
	mana -= info["mana"]
	Sound.play(["heal", "lightning", "haste"][type], world_position)
	map.add_effect(world_position, info.get("radius", 24.0), info["color"])


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
	_wave_timer = WAVE_INTERVAL
	_wave_warned = false
	var count := mini(1 + _next_wave, MAX_HEROES_PER_WAVE)
	var types := Heroes.types_for_wave(_next_wave)
	for i in count:
		_pending_heroes.append(types.pick_random())
	_hero_spawn_timer = 0.0
	_wave_in_progress = true
	Sound.play("horn")
	hud.show_message("Vague %d : %d héros entrent dans ton donjon !" % [_next_wave, count], 5.0)
	_next_wave += 1


func _spawn_hero(type: int) -> void:
	_add_hero(type, map.entrance_cell)


func _add_hero(type: int, cell: Vector2i) -> Hero:
	var hero := Hero.new()
	hero.setup_hero(map, cell, type)
	hero.died.connect(_on_hero_died)
	heroes_root.add_child(hero)
	return hero


## Un héros vaincu rapporte une rançon, rangée au trésor s'il y a de la place.
func _on_hero_died(unit: Unit) -> void:
	var hero := unit as Hero
	var stored := map.add_gold_to_treasury(hero.reward())
	if stored > 0:
		Sound.play("coins", null, -6.0)
		hud.show_message("%s vaincu ! +%d or de rançon." % [hero.display_name(), stored], 3.0)
	else:
		hud.show_message("%s vaincu ! Sa rançon est perdue : pas de place au Trésor." % hero.display_name(), 3.0)


func _on_heart_changed() -> void:
	_hint("Ton cœur est attaqué ! Envoie tes créatures le défendre.")


func _on_heart_destroyed() -> void:
	_game_over = true
	SaveGame.delete() # Une partie perdue ne se reprend pas !
	get_tree().paused = true # Tout s'arrête, sauf l'interface (voir hud.gd).
	Sound.set_music_volume(-20.0)
	Sound.play("game_over")
	hud.show_game_over(_waves_survived)


func _on_restart_pressed() -> void:
	SaveGame.load_requested = false
	get_tree().paused = false
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
		"summary": {
			"wave": _next_wave,
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
		},
		"camera": [camera.position.x, camera.position.y, camera.zoom.x],
		"research": research.to_save(),
		"mana": mana,
		"workshop_points": workshop_points,
		"trap_stock": [trap_stock[Defenses.Type.SPIKES], trap_stock[Defenses.Type.RUNE],
				trap_stock[Defenses.Type.DOOR]],
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
		hero.hp = float(values["hp"])

	var state: Dictionary = data["state"]
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
		_set_tool(tool, text, Defenses.display_name(defense), research.is_unlocked("defense", defense))
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
	if tool == Hud.Tool.HAND:
		hud.show_message("Touche une créature ou un ouvrier pour le prendre, puis touche le sol pour le déposer.", 5.0)
	elif tool == Hud.Tool.SPELL_HEAL:
		hud.show_message("Touche tes unités blessées pour les soigner.", 3.0)
	elif tool == Hud.Tool.SPELL_LIGHTNING:
		hud.show_message("Touche un héros pour le foudroyer.", 3.0)
	elif tool == Hud.Tool.SPELL_HASTE:
		hud.show_message("Touche une de tes unités pour qu'elle coure plus vite.", 3.0)


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
		Hud.Tool.HAND:
			_use_hand(cell, world_position)
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
func _unit_at(world_position: Vector2, root: Node) -> Unit:
	for unit: Unit in root.get_children():
		if not unit.in_hand and unit.position.distance_to(world_position) < 16.0:
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
	map.build_room(cell, room_type)
	Sound.play("build", map.cell_to_world(cell))


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
	map.place_defense(cell, type)
	Sound.play("trap_place", map.cell_to_world(cell))


func _demolish(cell: Vector2i) -> void:
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

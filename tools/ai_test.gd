extends SceneTree
## Test de l'IA (règles 2.8 et 2.9) : choix de la cible, appel à l'aide, défense du
## cœur, recul des tireurs, fuite des ouvriers ; repli des blessés, choix du travail,
## postes de défense, cibles et embuscade des héros, rival opportuniste. Sans écran :
##   godot --headless --path . -s res://tools/ai_test.gd
## Affiche « TEST OK » ou « TEST FAIL » par vérification ; code de sortie 1 s'il y a un échec.
var _game: Node
var _map: Node
var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= root.get_process_delta_time()

func _check(label: String, ok: bool) -> void:
	print("TEST ", "OK   " if ok else "FAIL ", label)
	if not ok:
		_fails += 1

func _open(cell: Vector2i) -> void:
	if not _map.is_walkable(cell):
		_map.dig(cell)
		var guard := 0
		while not _map.is_walkable(cell) and guard < 50:
			_map.dig(cell)
			guard += 1
	if _map.get_tile(cell) == 3: # DungeonMap.Tile.FLOOR : on revendique (pour bâtir).
		_map.claimed[cell] = true


func _room(origin: Vector2i, size: Vector2i, type: int) -> void:
	if not _map.can_build_block(origin, size):
		print("TEST : pas la place pour la salle ", type, " en ", origin)
		return
	_map.finish_block_now(_map.start_room_block(origin, size, type))


## Une créature figée (elle ne pense pas), sans traits.
func _still(type: int, cell: Vector2i) -> Node:
	var unit: Node = _game._add_creature(type, cell)
	unit.traits.clear()
	unit.set_process(false)
	return unit

func _run() -> void:
	# Toujours la même carte de partie libre (sinon une gemme ou le portail peut tomber
	# là où le test creuse et bâtit). SEED=<n> dans l'environnement pour en essayer une autre.
	var seed_text := OS.get_environment("SEED")
	seed(int(seed_text) if seed_text != "" else 4)
	Levels.current_id = 0
	SaveGame.load_requested = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(60)
	_game = current_scene
	_map = _game.get_node("World/DungeonMap")
	# Nos fouilles ne doivent réveiller aucun secret des profondeurs (Colosse, lave, ou
	# ruine dont les spectres marcheraient sur le cœur en plein test).
	_map.secrets.clear()
	var heart: Vector2i = _map.heart_cell
	for dy in range(-4, 5):
		for dx in range(2, 24):
			_open(heart + Vector2i(dx, dy))
	for w in _game.workers_root.get_children():
		w.queue_free()
	await _frames(5)

	# 1. Choix de cible : un Chevalier (2) proche, un Clerc (3?) un peu plus loin.
	var H := {}
	var heroes_script = load("res://scripts/heroes.gd")
	var creatures_script = load("res://scripts/creatures.gd")
	var HT: Dictionary = heroes_script.Type
	var CT: Dictionary = creatures_script.Type
	var kobold: Node = _game._add_creature(CT["KOBOLD"], heart + Vector2i(2, 0))
	kobold.traits.clear()
	var sleeper: Node = _game._add_creature(CT["KOBOLD"], heart + Vector2i(2, 1))
	sleeper.traits.clear()
	sleeper.state = sleeper.State.SLEEPING
	sleeper.energy = 10.0
	sleeper.set_process(false) # (Elle reste endormie : pas de lit dans ce test.)
	var orc: Node = _game._add_creature(CT["ORC"], heart + Vector2i(10, 0))
	orc.traits.clear()
	orc.set_process(false) # (Le temps de l'interroger sur sa cible.)
	var knight: Node = _game._add_hero(HT["KNIGHT"], heart + Vector2i(13, 0))
	var cleric: Node = _game._add_hero(HT["CLERIC"], heart + Vector2i(14, 1))
	knight.hold_left = 99.0
	cleric.hold_left = 99.0
	var chosen = orc.find_nearest_enemy(192.0)
	_check("l'orque préfère le Clerc au Chevalier plus proche", chosen == cleric)
	cleric.queue_free()
	await _frames(2)
	_check("sans Clerc, il prend le Chevalier", orc.find_nearest_enemy(192.0) == knight)
	orc.set_process(true)

	# 2. Appel à l'aide : un kobold à 9 cases (hors de vue : 6 cases) accourt.
	await _wait(1.5)
	print("  distance kobold-chevalier au départ : 11 cases (vue : 6)")
	print("  orc state=", orc.state, " kobold state=", kobold.state, " sleeper=", sleeper.state)
	_check("l'orque se bat", orc.state == orc.State.FIGHTING)
	_check("le kobold lointain vient aider", kobold.state == kobold.State.FIGHTING and kobold._enemy == knight)
	_check("l'endormi n'a pas été appelé", sleeper.state != sleeper.State.FIGHTING)
	knight.queue_free()
	orc.queue_free(); kobold.queue_free(); sleeper.queue_free()
	await _frames(5)

	# 3. Le cœur appelle : un héros frappe le cœur, une créature loin et endormie accourt.
	var far: Node = _game._add_creature(CT["ORC"], heart + Vector2i(20, 0))
	far.traits.clear()
	far.state = far.State.SLEEPING
	far.energy = 50.0
	await _frames(30)
	_check("avant : elle n'est pas au combat", far.state != far.State.FIGHTING)
	var raider: Node = _game._add_hero(HT["KNIGHT"], heart + Vector2i(2, 0))
	var hp_before: float = _map.heart_hp
	await _frames(90)
	print("  heart ", hp_before, " -> ", _map.heart_hp, " far state=", far.state)
	_check("le cœur est frappé", _map.heart_hp < hp_before)
	_check("la créature lointaine accourt", far.state == far.State.FIGHTING and far._enemy == raider)
	raider.queue_free(); far.queue_free()
	await _frames(5)
	_map.last_heart_hit_msec = -100000

	# 4. Recul des tireurs : un Sorcier collé par un Chevalier doit s'éloigner entre deux tirs.
	var warlock: Node = _game._add_creature(CT["WARLOCK"], heart + Vector2i(12, 0))
	warlock.traits.clear()
	warlock.max_hp = 5000.0; warlock.hp = 5000.0
	var brute: Node = _game._add_hero(HT["KNIGHT"], heart + Vector2i(13, 0))
	brute.max_hp = 5000.0; brute.hp = 5000.0
	var backed := 0
	var shots_hp: float = brute.hp
	var t := 0.0
	while t < 14.0:
		await process_frame
		t += root.get_process_delta_time()
		if not is_instance_valid(warlock) or not is_instance_valid(brute):
			break
		if warlock._backing_off:
			backed += 1
	print("  frames en recul=", backed, " dégâts infligés=", shots_hp - brute.hp, " reçus=", 5000.0 - warlock.hp,
			" pos=", warlock.current_cell() - heart)
	_check("le Sorcier recule", backed > 10)
	_check("le Sorcier tire à son rythme (>= 8 tirs en 14 s)", shots_hp - brute.hp >= 18.0 * 8)
	_check("le Sorcier a survécu au test", is_instance_valid(warlock) and is_instance_valid(brute))
	if is_instance_valid(warlock):
		_check("le Chevalier finit quand même par le toucher", warlock.hp < warlock.max_hp)
		warlock.queue_free()
	if is_instance_valid(brute):
		brute.queue_free()
	await _frames(5)

	# 5. Les ouvriers fuient.
	var worker: Node = _game._add_worker(heart + Vector2i(12, 0))
	var scary: Node = _game._add_hero(HT["KNIGHT"], heart + Vector2i(14, 0))
	scary.hold_left = 99.0 # Il ne bouge pas (mais se battrait).
	var start: Vector2 = worker.position
	var fled := false
	var t2 := 0.0
	while t2 < 2.5:
		await process_frame
		t2 += root.get_process_delta_time()
		if is_instance_valid(worker) and worker.state == worker.State.FLEEING:
			fled = true
	var alive: bool = is_instance_valid(worker) and not worker.is_dead()
	_check("l'ouvrier a fui", fled)
	_check("l'ouvrier est vivant et plus loin", alive and worker.position.distance_to(scary.position) > start.distance_to(scary.position))
	if is_instance_valid(worker):
		worker.queue_free()
	scary.queue_free()
	await _frames(5)
	await _test_2_9(heart, HT, CT)
	print("TEST terminé, échecs = ", _fails)
	quit(1 if _fails > 0 else 0)


func _test_2_9(heart: Vector2i, HT: Dictionary, CT: Dictionary) -> void:
	var RT: Dictionary = load("res://scripts/rooms.gd").Type
	var creatures_script = load("res://scripts/creatures.gd")
	_game._wave_timer = 999.0
	# Des salles sous le couloir : un Repaire, un Temple, une Bibliothèque.
	for dy in range(5, 12):
		for dx in range(2, 24):
			_open(heart + Vector2i(dx, dy))
	for dx in range(2, 24):
		_open(heart + Vector2i(dx, 4))
	_room(heart + Vector2i(3, 6), Vector2i(1, 1), RT["LAIR"])
	_room(heart + Vector2i(6, 6), Vector2i(2, 3), RT["TEMPLE"])
	_room(heart + Vector2i(10, 6), Vector2i(2, 3), RT["LIBRARY"])
	await _frames(5)

	# 6. Le repli des blessés.
	_map.last_heart_hit_msec = -100000
	var hurt: Node = _game._add_creature(CT["ORC"], heart + Vector2i(14, 0))
	hurt.traits.clear()
	hurt.max_hp = 1000.0
	hurt.hp = 200.0
	_check("l'orque blessée a un lit", hurt._has_bed())
	var foe: Node = _game._add_hero(HT["KNIGHT"], heart + Vector2i(16, 0))
	foe.max_hp = 5000.0; foe.hp = 5000.0
	await _wait(1.0)
	print("  blessée : fleeing=", hurt.fleeing, " state=", hurt.state, " (", hurt.activity_text(), ")")
	_check("sous 25 %, elle se replie vers son lit", hurt.fleeing and hurt.state == hurt.State.GOING_TO_SLEEP)
	hurt.queue_free()
	var brawler: Node = _game._add_creature(CT["ORC"], heart + Vector2i(15, 0))
	brawler.traits.assign(["bagarreuse"])
	brawler.max_hp = 1000.0
	brawler.hp = 200.0
	await _wait(1.0)
	_check("une Bagarreuse ne recule jamais", not brawler.fleeing and brawler.state == brawler.State.FIGHTING)
	brawler.queue_free()
	var last: Node = _game._add_creature(CT["ORC"], heart + Vector2i(15, 0))
	last.traits.clear()
	last.max_hp = 1000.0
	last.hp = 200.0
	_map.last_heart_hit_msec = Time.get_ticks_msec()
	await _wait(1.0)
	_check("cœur frappé : personne ne recule", not last.fleeing)
	_map.last_heart_hit_msec = -100000
	last.queue_free(); foe.queue_free()
	await _frames(5)

	# 7. Le travail le plus utile.
	var scholar: Node = _still(CT["WARLOCK"], heart + Vector2i(20, 0))
	scholar.happiness = 90.0
	var scores: Dictionary = scholar._job_scores(creatures_script.info(CT["WARLOCK"]))
	print("  Sorcier : ", scores)
	_check("un Sorcier heureux préfère étudier", scores.get(RT["LIBRARY"], 0.0) > scores.get(RT["TEMPLE"], 0.0))
	var pious: Node = _still(CT["KOBOLD"], heart + Vector2i(20, 1))
	pious.traits.assign(["pieuse"])
	pious.happiness = 20.0
	scores = pious._job_scores(creatures_script.info(CT["KOBOLD"]))
	print("  Pieuse malheureuse : ", scores)
	_check("une Pieuse malheureuse va prier", scores.get(RT["TEMPLE"], 0.0) > scores.get(RT["LIBRARY"], 0.0))
	scholar.queue_free(); pious.queue_free()
	await _frames(5)

	# 8. Les postes de défense : une vague approche, la créature rejoint l'étendard.
	var flag_cell := heart + Vector2i(19, 0)
	_game._toggle_rally_flag(heart + Vector2i(6, 7)) # Dans le Temple : refusé.
	_check("pas d'étendard dans une salle", not _map.rally_flags.has(heart + Vector2i(6, 7)))
	_game._toggle_rally_flag(flag_cell)
	_check("l'étendard est planté", _map.rally_flags.has(flag_cell))
	var sentry: Node = _game._add_creature(CT["KOBOLD"], heart + Vector2i(12, 0))
	sentry.traits.clear()
	sentry.happiness = 90.0
	sentry.energy = 100.0
	sentry.hunger = 0.0
	_game._wave_timer = 20.0 # Une vague dans 20 s.
	var reached := false
	var t := 0.0
	while t < 10.0 and not reached:
		await process_frame
		t += root.get_process_delta_time()
		reached = sentry.state == sentry.State.RALLYING and sentry.path.is_empty() \
				and sentry.position.distance_to(_map.cell_to_world(flag_cell)) <= 48.0
	print("  garde : state=", sentry.state, " (", sentry.activity_text(), ") pose=", sentry.pose())
	_check("à l'approche d'une vague, elle monte la garde à l'étendard", reached and sentry.pose() == "guard")
	_game._toggle_rally_flag(flag_cell)
	await _frames(3)
	_check("étendard arraché : elle quitte la garde", sentry.state != sentry.State.RALLYING)
	_game._wave_timer = 999.0
	sentry.queue_free()
	await _frames(5)

	# 9. Les héros visent tes tireurs.
	var hunter: Node = _game._add_hero(HT["KNIGHT"], heart + Vector2i(14, 0))
	hunter.set_process(false)
	var brute: Node = _still(CT["ORC"], heart + Vector2i(15, 0))
	var mage: Node = _still(CT["WARLOCK"], heart + Vector2i(16, 1))
	_check("le héros préfère le Sorcier à l'orque plus proche", hunter.find_nearest_enemy(128.0) == mage)
	hunter.queue_free(); brute.queue_free(); mage.queue_free()
	await _frames(5)

	# 10. L'embuscade : il attend que tes créatures dorment.
	var lurker: Node = _game._add_hero(HT["KNIGHT"], heart + Vector2i(22, 10))
	lurker.hold_left = 0.0
	lurker.ambush_left = 25.0
	var watcher: Node = _still(CT["KOBOLD"], heart + Vector2i(3, 0))
	var from: Vector2 = lurker.position
	await _wait(1.5)
	_check("en embuscade, il attend", lurker.position == from and lurker.ambush_left > 0.0)
	watcher.state = watcher.State.SLEEPING
	await _wait(1.5)
	_check("ta créature dort : il attaque", lurker.ambush_left == 0.0 and lurker.position != from)
	lurker.queue_free(); watcher.queue_free()
	await _frames(5)

	# 11. Le rival opportuniste (niveau 6, « Le maître voisin »).
	Levels.current_id = 6
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(60)
	_game = current_scene
	_map = _game.get_node("World/DungeonMap")
	var orc: Node = _still(CT["ORC"], _map.heart_cell + Vector2i(0, 2))
	_game._rival_timer = 60.0
	_game._rival_opportunity = 0.1
	await _wait(0.5)
	_check("créatures en forme : le rival attend son heure", _game._rival_squads == 0)
	orc.hp = orc.max_hp * 0.3
	_game._rival_opportunity = 0.1
	await _wait(0.5)
	print("  rival : escouades=", _game._rival_squads, " minuteur=", _game._rival_timer)
	_check("créatures blessées : le rival attaque aussitôt", _game._rival_squads == 1 and _game._rival_timer > 60.0)

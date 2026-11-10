extends SceneTree
## Test de l'IA des créatures et des ouvriers (règles 2.8) : choix de la cible, appel à
## l'aide, défense du cœur, recul des tireurs, fuite des ouvriers. Sans écran :
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

func _run() -> void:
	Levels.current_id = 0
	SaveGame.load_requested = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(60)
	_game = current_scene
	_map = _game.get_node("World/DungeonMap")
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
		if warlock._backing_off:
			backed += 1
	print("  frames en recul=", backed, " dégâts infligés=", shots_hp - brute.hp, " reçus=", 5000.0 - warlock.hp,
			" pos=", warlock.current_cell() - heart)
	_check("le Sorcier recule", backed > 10)
	_check("le Sorcier tire à son rythme (>= 8 tirs en 14 s)", shots_hp - brute.hp >= 18.0 * 8)
	_check("le Chevalier finit quand même par le toucher", warlock.hp < warlock.max_hp)
	warlock.queue_free(); brute.queue_free()
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
	print("TEST terminé, échecs = ", _fails)
	quit(1 if _fails > 0 else 0)

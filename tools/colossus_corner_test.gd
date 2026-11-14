extends SceneTree
## Test : le Colosse réveillé par un coup de pioche dans un COIN de sa caverne doit
## rester accessible à l'assaut. Sans écran :
##   godot --headless --path . -s res://tools/colossus_corner_test.gd
var _game: Node
var _map: Node
var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(label: String, ok: bool) -> void:
	print("TEST ", "OK   " if ok else "FAIL ", label)
	if not ok:
		_fails += 1

func _run() -> void:
	var corner_arg := Vector2i(2, 2)
	for a in OS.get_cmdline_user_args():
		var p := a.split(",")
		if p.size() == 2:
			corner_arg = Vector2i(int(p[0]), int(p[1]))
	Levels.current_id = 0
	SaveGame.load_requested = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(60)
	_game = current_scene
	_map = _game.get_node("World/DungeonMap")
	var heart: Vector2i = _map.heart_cell
	var center := Vector2i(-1, -1)
	var centers: Array[Vector2i] = []
	for s in _map.secrets:
		centers.append(s["center"])
		if s["kind"] == "colossus":
			center = s["center"]
	var corner: Vector2i = center + corner_arg
	var outside: Vector2i = corner + Vector2i(signi(corner_arg.x), 0)
	# Un couloir (BFS) du cœur jusqu'à la case à côté du coin, sans approcher des secrets.
	var prev := {heart: heart}
	var frontier: Array[Vector2i] = [heart]
	while not frontier.is_empty() and not prev.has(outside):
		var c: Vector2i = frontier.pop_front()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if prev.has(n) or n.x < 1 or n.y < 1 or n.x >= _map.WIDTH - 1 or n.y >= _map.HEIGHT - 1:
				continue
			var ok := true
			for sc in centers:
				if maxi(absi(n.x - sc.x), absi(n.y - sc.y)) <= 2:
					ok = false
			if not ok:
				continue
			prev[n] = c
			frontier.append(n)
	var cell: Vector2i = outside
	while cell != heart:
		if not _map.is_walkable(cell) and _map.get_tile(cell) != _map.Tile.HEART:
			_map._set_tile(cell, _map.Tile.FLOOR)
			_map._refresh_pathing(cell)
		cell = prev[cell]
	for w in _game.workers_root.get_children():
		w.queue_free()
	# Le coup de pioche dans le coin.
	var guard := 0
	while not _map.is_walkable(corner) and guard < 50:
		_map.dig(corner)
		guard += 1
	await _frames(5)
	_check("le Colosse est réveillé", _game._guardian() != null)
	var path: Array = _map.find_path(heart + Vector2i(1, 0), center)
	print("  centre=", center, " coin=", corner, " chemin=", path.size())
	_check("un chemin mène du cœur au Colosse", not path.is_empty())
	var CT: Dictionary = load("res://scripts/creatures.gd").Type
	var orc: Node = null
	for dx in [1, -1, 2, -2]:
		if _map.is_walkable(heart + Vector2i(dx, 0)) or _map.is_walkable(heart + Vector2i(0, dx)):
			pass
	orc = _game._add_creature(CT["ORC"], _map.get_spawn_cell())
	orc.traits.clear()
	orc.max_hp = 50000.0; orc.hp = 50000.0
	var guardian: Node = _game._guardian()
	var hp0: float = guardian.hp
	_game._on_assault_pressed()
	var t := 0.0
	var best := INF
	while t < 60.0 and guardian.hp >= hp0:
		await process_frame
		t += root.get_process_delta_time()
		best = minf(best, orc.position.distance_to(guardian.position))
	print("  t=", t, " orc state=", orc.state, " cell=", orc.current_cell(), " dist min=", best,
			" colosse cell=", guardian.current_cell(), " hp ", hp0, " -> ", guardian.hp)
	_check("l'orque frappe le Colosse", guardian.hp < hp0)
	print("RESULT ", "PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)

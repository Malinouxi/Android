extends SceneTree
## Test des antres (règles 2.7) : construit les 7 nouvelles salles près du cœur, fait
## venir les 7 nouvelles créatures, les laisse vivre (boire, soigner, torturer, garder,
## méditer, veiller les morts...), affiche ce qu'elles font et prend des captures.
##   godot --path . -s res://tools/dens_test.gd
## Les captures vont dans le dossier SCREENSHOT_DIR (sinon user://dens_test).
## Les types sont des nombres : citer Rooms ou Creatures ici ferait compiler la carte
## avant les autoloads (Sound, Ui).

var _out := ""
var _game: Node
var _map: Node


func _initialize() -> void:
	_out = OS.get_environment("SCREENSHOT_DIR")
	if _out == "":
		_out = OS.get_user_data_dir().path_join("dens_test")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	Levels.current_id = 0 # Partie libre.
	SaveGame.load_requested = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(120)
	_game = current_scene
	_map = _game.get_node("World/DungeonMap")
	var heart: Vector2i = _map.heart_cell
	# Une grande salle creusée à droite du cœur, tout revendiquée.
	for dy in range(-6, 5):
		for dx in range(3, 15):
			_open(heart + Vector2i(dx, dy))
	for dy in range(-1, 2):
		_open(heart + Vector2i(2, dy))
	# [décalage, taille, salle] : 10 Taverne, 11 Infirmerie, 12 Hôtel des monnaies,
	# 13 Torture, 14 Poste de garde, 15 Puits de mana, 16 Crypte, 7 Prison, 2 Repaire, 3 Champignonnière.
	var plans := [[Vector2i(4, -5), Vector2i(2, 2), 10], [Vector2i(7, -5), Vector2i(2, 2), 11],
			[Vector2i(10, -5), Vector2i(2, 2), 12], [Vector2i(12, -2), Vector2i(2, 2), 7],
			[Vector2i(4, 1), Vector2i(2, 2), 13], [Vector2i(7, 1), Vector2i(1, 2), 14],
			[Vector2i(9, 1), Vector2i(2, 2), 15], [Vector2i(12, 1), Vector2i(2, 2), 16],
			[Vector2i(3, -1), Vector2i(1, 1), 2], [Vector2i(3, 3), Vector2i(1, 1), 2],
			[Vector2i(13, 3), Vector2i(1, 1), 3]]
	for x in range(4, 14): # Assez de lits pour que personne ne parte, furieux.
		plans.append([Vector2i(x, -6), Vector2i(1, 1), 2])
	for plan in plans:
		var origin: Vector2i = heart + plan[0]
		if not _map.can_build_block(origin, plan[1]):
			print("TEST : pas la place pour ", plan)
			continue
		_map.finish_block_now(_map.start_room_block(origin, plan[1], plan[2]))
	_map.food[heart + Vector2i(13, 3)] = 3
	_map.add_gold_to_treasury(2000)
	_map.heart_gold += 3000
	print("TEST : objets = ", _map.furniture.size())
	# Un prisonnier pour la Chambre de torture (KNIGHT = 2).
	var prison_cell: Vector2i = _map.find_free_prison_cell()
	if prison_cell != Vector2i(-1, -1):
		var knight: Node = _game._add_hero(2, prison_cell)
		knight.capture_at(prison_cell)
	# Les 7 nouvelles créatures (14 à 20), un orc blessé et un kobold fatigué.
	var spawn: Vector2i = heart + Vector2i(8, -1)
	var creatures := []
	for type in range(14, 21):
		creatures.append(_game._add_creature(type, spawn))
	var orc: Node = _game._add_creature(1, spawn)
	orc.hp = orc.max_hp * 0.3
	var kobold: Node = _game._add_creature(0, spawn)
	kobold.energy = 1.0
	var drinker: Node = _game._add_creature(1, spawn)
	drinker.happiness = 30.0
	_game.mana = 200.0
	var view: Node = _game.get("_view3d")
	if view != null:
		view.center_on(_map.cell_to_world(heart + Vector2i(8, -1)))
		view.set_zoom(1.4)
	Engine.time_scale = 3.0
	for step in 2:
		await _frames(150)
		_report("t%d" % step, creatures + [orc, kobold, drinker])
	Engine.time_scale = 1.0
	_shot("01_antres")
	if view != null:
		view.set_zoom(4.5)
		for target in [orc, drinker, kobold, creatures[3], creatures[5], creatures[6]]:
			if is_instance_valid(target):
				view.center_on(target.position)
				await _frames(25)
				_shot("pose_%s_%s" % [target.sprite_info()[0], target.pose()])
		view.set_zoom(1.4)
	for step in 2:
		await _frames(150)
		_report("t%d" % (step + 2), creatures + [orc, kobold, drinker])
	if view != null:
		view.center_on(_map.cell_to_world(heart + Vector2i(6, -4)))
		view.set_zoom(2.6)
		await _frames(30)
		_shot("02_taverne_infirmerie")
		view.center_on(_map.cell_to_world(heart + Vector2i(8, 2)))
		await _frames(30)
		_shot("03_torture_garde_puits")
	# La Crypte : on tue un kobold ; il doit y reposer, puis se relever.
	var victim: Node = _game._add_creature(0, spawn)
	await _frames(5)
	victim.take_damage(9999.0)
	await _frames(5)
	print("TEST crypte : corps = ", _map.crypt_bodies.size())
	if not _map.crypt_bodies.is_empty():
		_map.crypt_bodies[0]["time"] = 0.5
	await _frames(90)
	print("TEST crypte : après = ", _map.crypt_bodies.size(), ", mana = ", _game.mana)
	if view != null:
		view.center_on(_map.cell_to_world(heart + Vector2i(12, 2)))
		await _frames(20)
		_shot("04_crypte")
	print("TEST TERMINÉ")
	quit()


func _open(cell: Vector2i) -> void:
	var guard := 0
	while _map.is_diggable(cell) and guard < 40:
		_map.dig(cell)
		guard += 1
	if _map.get_tile(cell) == 3: # DungeonMap.Tile.FLOOR
		_map.claimed[cell] = true


func _report(label: String, units: Array) -> void:
	var parts := []
	for unit in units:
		if is_instance_valid(unit):
			parts.append("%s=%s[%s] %d/%d" % [unit.display_name(), unit.activity_text(), unit.pose(), unit.hp,
					unit.max_hp])
	print("TEST ", label, " : ", ", ".join(parts))


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("CAPTURE ", path)

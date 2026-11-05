extends SceneTree
## Prend des captures d'écran du jeu, pour vérifier l'affichage sans téléphone.
## Lancé par GitHub Actions (voir .github/workflows/android-apk.yml) :
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/screenshots.gd
## Les images sont rangées dans le dossier donné par la variable SCREENSHOT_DIR.

var _out := ""


func _initialize() -> void:
	_out = OS.get_environment("SCREENSHOT_DIR")
	if _out == "":
		_out = OS.get_user_data_dir().path_join("screens")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/menu.tscn")
	await _frames(90)
	_shot("01_menu")

	# On charge le codex au dernier moment : au démarrage de ce script, les autoloads
	# (Sound, Ui) n'existent pas encore, et le codex en a besoin.
	var codex: Control = load("res://scripts/codex.gd").new()
	var layer := CanvasLayer.new()
	layer.layer = 50 # Par-dessus le panneau du menu.
	root.add_child(layer)
	layer.add_child(codex)
	await _frames(20)
	_shot("02_codex_menu")
	layer.queue_free()

	Levels.current_id = 1
	SaveGame.load_requested = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(240)
	_shot("03_partie")

	# Un petit combat près du cœur, pour voir les animations d'attaque.
	var game := current_scene
	print("ÉTAPE combat : scène = ", game, ", carte = ", game.get("map"))
	var map_node: Node = game.get_node("World/DungeonMap")
	var heart: Vector2i = map_node.heart_cell
	# Entiers (KNIGHT = 2, ORC = 1) : citer Heroes/Creatures ferait compiler la carte avant Sound.
	game._add_hero(2, heart + Vector2i(1, 1))
	game._add_creature(1, heart + Vector2i(-1, 1))
	print("ÉTAPE combat : unités ajoutées")
	await _frames(70)
	_shot("04_combat")

	# Le nouveau contenu : un Cimetière (deux tombes occupées), le Champion du
	# royaume, un Revenant, et un éclair qui tombe sur le Champion.
	var built := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cell: Vector2i = heart + Vector2i(dx, dy)
			if built < 3 and map_node.can_build_room(cell):
				map_node.build_room(cell, 9) # Rooms.Type.GRAVEYARD
				built += 1
	map_node.bury()
	map_node.bury()
	var champion: Node2D = game._add_hero(12, heart + Vector2i(2, -1)) # Heroes.Type.CHAMPION
	game._add_creature(10, heart + Vector2i(1, -2)) # Creatures.Type.REVENANT
	print("ÉTAPE contenu : cimetière (", built, " cases), champion et revenant ajoutés")
	await _frames(40)
	game.mana = 200.0
	game._cast_spell(1, champion.position) # Spells.Type.LIGHTNING
	await _frames(3)
	_shot("06_contenu")

	# Les héros en mission : une Voleuse avec son butin, un Moine libérateur,
	# un Cerbère qui les flaire, et un sac d'or tombé par terre.
	var thief: Node2D = game._add_hero(1, heart + Vector2i(-2, -1)) # Heroes.Type.THIEF
	thief.loot = 150
	game._add_hero(13, heart + Vector2i(2, 1)) # Heroes.Type.MONK
	game._add_creature(11, heart + Vector2i(-1, -2)) # Creatures.Type.CERBERUS
	map_node.drop_gold(heart + Vector2i(0, 2), 150)
	# Deux chantiers : une Bibliothèque et une porte (les ouvriers vont les construire).
	for cell: Vector2i in [heart + Vector2i(2, 2), heart + Vector2i(-2, 2)]:
		if map_node.can_build_room(cell):
			map_node.start_construction(cell, "room" if cell.x > heart.x else "defense", 4 if cell.x > heart.x else 2)
	print("ÉTAPE missions : voleuse, moine, cerbère et sac d'or ajoutés")
	await _frames(25)
	_shot("07_missions")

	var hud := game.get_node("HUD")
	hud.codex_pressed.emit()
	await _frames(20)
	_shot("05_codex_partie")
	print("CAPTURES TERMINÉES")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("CAPTURE ", path)

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

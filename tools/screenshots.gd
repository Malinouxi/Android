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

	var codex := Codex.new()
	root.add_child(codex)
	await _frames(20)
	_shot("02_codex_menu")
	codex.queue_free()

	Levels.current_id = 1
	SaveGame.load_requested = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(240)
	_shot("03_partie")

	var hud := current_scene.get_node("HUD")
	hud.codex_pressed.emit()
	await _frames(20)
	_shot("04_codex_partie")
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

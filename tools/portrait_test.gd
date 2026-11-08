extends SceneTree
## Capture le portrait du Seigneur dans chaque humeur, en grand (vérification).
##   godot --path . -s res://tools/portrait_test.gd
## Les images vont dans SCREENSHOT_DIR (ou user://screens).

var _out := ""


func _initialize() -> void:
	_out = OS.get_environment("SCREENSHOT_DIR")
	if _out == "":
		_out = OS.get_user_data_dir().path_join("screens")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0.12, 0.08, 0.07)
	back.size = Vector2(1280, 720)
	layer.add_child(back)
	var portrait: Control = load("res://scripts/lord_portrait.gd").new()
	portrait.position = Vector2(40, 40)
	portrait.scale = Vector2(4, 4) # En grand, pour voir les détails.
	layer.add_child(portrait)
	await _frames(30)
	_shot("portrait_repos")
	for pair: Array in [["!", "colere"], ["$", "joie"], ["?", "inquiet"]]:
		portrait.mood = 0 # Repos : sinon la colère empêche les autres humeurs.
		portrait.react(pair[0], false)
		await _frames(40)
		_shot("portrait_" + pair[1])
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(shot_name: String) -> void:
	var path := _out.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)

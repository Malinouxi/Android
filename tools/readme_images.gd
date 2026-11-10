extends SceneTree
## Les images du README (dossier docs/readme/, ignoré par Godot : rien ne part dans l'APK).
##   - un PORTRAIT de chaque créature et de chaque héros : son modèle 3D du jeu, de
##     trois quarts, sur fond transparent, 160 x 160 (creatures/<nom>.png, heroes/<nom>.png) ;
##   - quelques CAPTURES du jeu (menu, donjon, antres, combat), en JPEG (plus léger).
## Il faut un projet importé (godot --headless --path . --import) et un écran (la 3D
## ne se dessine pas en --headless) ; sur un serveur, xvfb :
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --resolution 1280x720 -s res://tools/readme_images.gd
## Les noms de types sont lus à l'exécution (load) : citer Creatures ou Rooms ici
## ferait compiler la carte avant les autoloads (Sound, Ui).

const PORTRAIT := 256     ## Taille du rendu...
const PORTRAIT_SAVED := 160 ## ... et de l'image enregistrée (réduite : plus nette, plus légère).
var _out := ""
var _game: Node
var _map: Node


func _initialize() -> void:
	_out = ProjectSettings.globalize_path("res://docs/readme")
	DirAccess.make_dir_recursive_absolute(_out.path_join("creatures"))
	DirAccess.make_dir_recursive_absolute(_out.path_join("heroes"))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_jpg(_out.path_join(file_name + ".jpg"), 0.84)
	print("IMAGE ", file_name)


func _run() -> void:
	seed(4) # Toujours la même carte de partie libre.
	# Deux passes (IMAGES=portraits, puis IMAGES=captures) : charger les catalogues
	# pour les portraits avant la partie dérangerait la carte. Sans IMAGES : les deux.
	var mode := OS.get_environment("IMAGES")
	if mode != "captures":
		await _frames(10)
		await _portraits()
	if mode != "portraits":
		change_scene_to_file("res://scenes/menu.tscn")
		await _frames(90)
		await _shot("menu")
		await _scenes()
	print("IMAGES TERMINÉES")
	quit()


# ---------------------------------------------------------------------------
# Les portraits
# ---------------------------------------------------------------------------

func _portraits() -> void:
	var creatures = load("res://scripts/creatures.gd")
	var heroes = load("res://scripts/heroes.gd")
	var studio := _studio()
	for type: int in creatures.INFO:
		var info: Dictionary = creatures.INFO[type]
		var tint: Color = info.get("tint", Color.WHITE)
		await _portrait(studio, info["sprite"], info["size"] / 8.0, tint,
				"creatures/" + String(creatures.Type.find_key(type)).to_lower())
	for type: int in heroes.INFO:
		var info: Dictionary = heroes.INFO[type]
		var tint: Color = info.get("tint", Color.WHITE)
		if info.get("rival", false):
			tint = load("res://scripts/dungeon_map.gd").RIVAL_TINT
		await _portrait(studio, info["sprite"], info["size"] / 8.0, tint,
				"heroes/" + String(heroes.Type.find_key(type)).to_lower())
	studio["viewport"].queue_free()


## Un petit studio photo : une vue à part (fond transparent), une caméra orthogonale,
## l'éclairage des icônes (chaud en haut à gauche, contre-jour rouge, braise par en dessous).
func _studio() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(PORTRAIT, PORTRAIT)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.6, 0.55)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	for spec in [[Vector3(-40, -35, 0), Color(1.0, 0.86, 0.7), 1.6], [Vector3(-20, 160, 0), Color(1.0, 0.3, 0.15), 1.4],
			[Vector3(60, 10, 0), Color(1.0, 0.45, 0.2), 0.3]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	var stage := Node3D.new()
	viewport.add_child(stage)
	return {"viewport": viewport, "camera": camera, "stage": stage}


func _portrait(studio: Dictionary, sprite: String, size: float, tint: Color, file_name: String) -> void:
	var stage: Node3D = studio["stage"]
	for child in stage.get_children():
		child.queue_free()
	var model: Node3D = load("res://scripts/voxel_models.gd").character(sprite, Color(tint.r, tint.g, tint.b), 1.0)
	model.scale = Vector3.ONE * size
	model.rotation.y = 0.55 # De trois quarts.
	stage.add_child(model)
	await _frames(2)
	# On cadre au plus près : la boîte de tous ses morceaux, vue de face, un peu d'en haut.
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	var center := box.get_center()
	var camera: Camera3D = studio["camera"]
	camera.position = center + Vector3(0, 0.9, 3.0) * maxf(box.size.y, 1.0)
	camera.look_at(center)
	camera.size = maxf(box.size.y, maxf(box.size.x, box.size.z)) * 1.15
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = studio["viewport"].get_texture().get_image()
	image.resize(PORTRAIT_SAVED, PORTRAIT_SAVED, Image.INTERPOLATE_LANCZOS)
	image.save_png(_out.path_join(file_name + ".png"))
	print("PORTRAIT ", file_name)


# ---------------------------------------------------------------------------
# Les captures du jeu
# ---------------------------------------------------------------------------

func _open(cell: Vector2i) -> void:
	var guard := 0
	while _map.is_diggable(cell) and guard < 40:
		_map.dig(cell)
		guard += 1
	if _map.get_tile(cell) == 3: # DungeonMap.Tile.FLOOR
		_map.claimed[cell] = true


func _room(origin: Vector2i, size: Vector2i, type: int) -> void:
	if _map.can_build_block(origin, size):
		_map.finish_block_now(_map.start_room_block(origin, size, type))
	else:
		print("IMAGES : pas la place pour la salle ", type, " en ", origin)


func _scenes() -> void:
	var rooms: Dictionary = load("res://scripts/rooms.gd").Type
	var creature_types: Dictionary = load("res://scripts/creatures.gd").Type
	var hero_types: Dictionary = load("res://scripts/heroes.gd").Type
	Levels.current_id = 0
	SaveGame.load_requested = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(90)
	_game = current_scene
	_map = _game.get_node("World/DungeonMap")
	_map.secrets.clear()
	_game._wave_timer = 9999.0
	var heart: Vector2i = _map.heart_cell
	# Un donjon tout bâti : les salles à droite du cœur, les antres en dessous.
	for dy in range(-7, 12):
		for dx in range(3, 22):
			_open(heart + Vector2i(dx, dy))
	for dy in range(-1, 2):
		_open(heart + Vector2i(2, dy))
	var plans := [[Vector2i(4, -6), Vector2i(1, 2), rooms["TREASURY"]], [Vector2i(6, -6), Vector2i(2, 3), rooms["LIBRARY"]],
			[Vector2i(9, -6), Vector2i(2, 2), rooms["WORKSHOP"]], [Vector2i(12, -6), Vector2i(2, 3), rooms["TEMPLE"]],
			[Vector2i(15, -6), Vector2i(4, 2), rooms["TRAINING"]], [Vector2i(15, -3), Vector2i(2, 2), rooms["PRISON"]],
			[Vector2i(4, 3), Vector2i(2, 2), rooms["TAVERN"]], [Vector2i(7, 3), Vector2i(2, 2), rooms["INFIRMARY"]],
			[Vector2i(10, 3), Vector2i(2, 2), rooms["MINT"]], [Vector2i(13, 3), Vector2i(2, 2), rooms["TORTURE"]],
			[Vector2i(16, 3), Vector2i(1, 2), rooms["GUARDPOST"]], [Vector2i(4, 7), Vector2i(2, 2), rooms["MANA_WELL"]],
			[Vector2i(7, 7), Vector2i(2, 2), rooms["CRYPT"]]]
	for x in range(4, 19):
		plans.append([Vector2i(x, 10), Vector2i(1, 1), rooms["LAIR"]])
	for x in range(10, 14):
		plans.append([Vector2i(x, 7), Vector2i(1, 1), rooms["FARM"]])
	for plan in plans:
		_room(heart + plan[0], plan[1], plan[2])
	for x in range(10, 14):
		_map.food[heart + Vector2i(x, 7)] = 3
	_map.add_gold_to_treasury(800)
	_map.heart_gold += 3000
	var prison_cell: Vector2i = _map.find_free_prison_cell()
	if prison_cell != Vector2i(-1, -1):
		_game._add_hero(hero_types["KNIGHT"], prison_cell).capture_at(prison_cell)
	_game.mana = 200.0
	# Des créatures de toutes sortes.
	var spawn := heart + Vector2i(10, 0)
	for name in ["ORC", "ORC", "WARLOCK", "DEMON", "GOLEM", "VAMPIRE", "SPIDER", "SALAMANDER", "KOBOLD", "KOBOLD",
			"BAT", "GOBLIN", "GHOUL", "IMP", "EXECUTIONER", "GARGOYLE", "ORACLE", "NECROMANCER", "CATCHER"]:
		var creature: Node = _game._add_creature(creature_types[name], spawn + Vector2i(randi_range(-4, 4), randi_range(-1, 1)))
		creature.energy = 100.0
		creature.happiness = 80.0
	for i in 4:
		_game._add_worker(heart + Vector2i(3 + i, 0))
	var view: Node = _game.get("_view3d")
	Engine.time_scale = 3.0
	await _frames(400)
	Engine.time_scale = 1.0
	# 1. Le donjon, avec l'interface.
	view.center_on(_map.cell_to_world(heart + Vector2i(9, -2)))
	view.set_zoom(1.15)
	await _frames(40)
	await _shot("donjon")
	# 2. Les antres, de près, sans l'interface.
	_game.hud.visible = false
	view.center_on(_map.cell_to_world(heart + Vector2i(10, 5)))
	view.set_zoom(2.2)
	await _frames(40)
	await _shot("antres")
	# 3. Un combat : un étendard, tes créatures, une vague qui entre (sans l'interface).
	var flag := heart + Vector2i(19, 0)
	_map.set_rally_flag(flag, true)
	for name in ["KNIGHT", "ARCHER", "CLERIC", "DWARF", "MAGE"]:
		_game._add_hero(hero_types[name], heart + Vector2i(21, randi_range(-2, 2)))
	await _frames(45)
	view.center_on(_map.cell_to_world(heart + Vector2i(18, 0)))
	view.set_zoom(2.3)
	await _frames(20)
	await _shot("combat")

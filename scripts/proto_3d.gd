extends Node3D
## PROTOTYPE 3D : le donjon en vraie 3D, pour voir le rendu sur téléphone.
##
## Ce n'est pas encore le jeu : seulement la carte (générée par la même
## DungeonMap que le jeu), quelques ouvriers qui se promènent et une caméra qu'on
## fait tourner au doigt. Rien du jeu 2D n'est modifié.
##
## Comment c'est construit :
##   - chaque case de sol est un carré à plat, chaque mur un bloc (dessus + côtés
##     visibles), avec les MÊMES images pixel art que le jeu 2D, plaquées dessus ;
##   - toutes les faces qui ont la même image sont réunies en un seul « mesh »
##     (SurfaceTool), pour que le téléphone n'ait que quelques objets à dessiner ;
##   - les personnages sont des Sprite3D : des images 2D qui font toujours face à
##     la caméra (comme dans beaucoup de jeux des années 90) ;
##   - des lumières (OmniLight3D) pour le cœur, le portail et les torches.
##
## Contrôles : un doigt = tourner autour du cœur ; deux doigts = zoomer.
## Sur ordinateur : clic gauche glissé = tourner, molette = zoomer.

const MENU_SCENE := "res://scenes/menu.tscn"
const WALL_HEIGHT := 1.3   ## Hauteur des murs (une case = 1 unité de large).
const PIXEL_SIZE := 0.026  ## Taille d'un pixel des personnages (32 pixels -> 0,83 unité).
const LEVEL_SEED := 1101   ## La carte du niveau 1 de la campagne.

var _map: DungeonMap
var _camera: Camera3D
var _target := Vector3.ZERO
var _yaw := 0.6
var _pitch := 0.95
var _distance := 14.0
var _touches := {}          ## Doigts posés : index -> position.
var _pinch_start := 0.0
var _distance_start := 0.0
var _heart: MeshInstance3D
var _heart_light: OmniLight3D
var _time := 0.0
var _materials := {}        ## Image -> matériau (un seul matériau par image).
var _workers: Array = []    ## [{sprite, path, frame_time}]
var _torches: Array = []    ## [{sprite, light, offset}]


func _ready() -> void:
	# La carte : on se sert de la DungeonMap du jeu, cachée, juste pour ses cases.
	_map = DungeonMap.new()
	_map.visible = false
	add_child(_map)
	_map.generate(LEVEL_SEED)
	_carve_demo_rooms()

	_build_environment()
	_build_terrain()
	_build_heart_and_portal()
	_build_torches()
	_build_workers()
	_build_camera()
	_build_ui()


# ---------------------------------------------------------------------------
# La carte
# ---------------------------------------------------------------------------

## Pour la démonstration : on creuse deux salles près du cœur (Trésor, Repaire).
func _carve_demo_rooms() -> void:
	var heart := _map.heart_cell
	var rooms := [[Vector2i(-7, -2), Rooms.Type.TREASURY], [Vector2i(4, -2), Rooms.Type.LAIR]]
	for entry in rooms:
		var corner: Vector2i = heart + entry[0]
		for dy in 5:
			for dx in 4:
				var cell := corner + Vector2i(dx, dy)
				while _map.is_diggable(cell):
					_map.dig(cell)
				if _map.get_tile(cell) == DungeonMap.Tile.FLOOR:
					_map.claimed[cell] = true
					_map.rooms[cell] = entry[1]
	# Des couloirs entre les salles et la salle du cœur.
	for dx in range(-8, 9):
		var cell := heart + Vector2i(dx, 0)
		while _map.is_diggable(cell):
			_map.dig(cell)
		_map.claimed[cell] = true


func _is_wall(cell: Vector2i) -> bool:
	if not _map.is_inside(cell):
		return true
	var tile := _map.get_tile(cell)
	return tile == DungeonMap.Tile.EARTH or tile == DungeonMap.Tile.GOLD or tile == DungeonMap.Tile.ROCK


## L'image du sol d'une case (la même que dans le jeu 2D).
func _floor_texture(cell: Vector2i) -> Texture2D:
	if _map.rooms.has(cell):
		return Art.ROOM_FLOORS[_map.rooms[cell]]
	if _map.claimed.has(cell):
		return Art.pick(Art.CLAIMED, cell)
	return Art.pick(Art.FLOOR, cell)


func _wall_texture(cell: Vector2i) -> Texture2D:
	if not _map.is_inside(cell):
		return Art.ROCK[0]
	match _map.get_tile(cell):
		DungeonMap.Tile.EARTH:
			return Art.pick(Art.EARTH, cell)
		DungeonMap.Tile.GOLD:
			return Art.pick(Art.GOLD, cell)
	return Art.pick(Art.ROCK, cell)


## Un matériau par image : pixels nets (filtre « nearest »), pas de reflets.
func _material(texture: Texture2D) -> StandardMaterial3D:
	if not _materials.has(texture):
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED # Les faces se voient des deux côtés.
		_materials[texture] = material
	return _materials[texture]


## Construit le sol et les murs : un SurfaceTool par image, puis un seul mesh.
func _build_terrain() -> void:
	var tools := {} # image -> SurfaceTool
	for y in DungeonMap.HEIGHT:
		for x in DungeonMap.WIDTH:
			var cell := Vector2i(x, y)
			var x0 := float(x)
			var z0 := float(y)
			if not _is_wall(cell):
				_quad(_tool(tools, _floor_texture(cell)),
						Vector3(x0, 0, z0), Vector3(x0 + 1, 0, z0), Vector3(x0 + 1, 0, z0 + 1), Vector3(x0, 0, z0 + 1))
				continue
			var texture := _wall_texture(cell)
			var st := _tool(tools, texture)
			var h := WALL_HEIGHT
			# Le dessus du bloc.
			_quad(st, Vector3(x0, h, z0), Vector3(x0 + 1, h, z0), Vector3(x0 + 1, h, z0 + 1), Vector3(x0, h, z0 + 1))
			# Les côtés, seulement là où il y a du sol à côté (sinon on ne les voit jamais).
			if not _is_wall(cell + Vector2i.DOWN):
				_quad(st, Vector3(x0, h, z0 + 1), Vector3(x0 + 1, h, z0 + 1), Vector3(x0 + 1, 0, z0 + 1), Vector3(x0, 0, z0 + 1))
			if not _is_wall(cell + Vector2i.UP):
				_quad(st, Vector3(x0 + 1, h, z0), Vector3(x0, h, z0), Vector3(x0, 0, z0), Vector3(x0 + 1, 0, z0))
			if not _is_wall(cell + Vector2i.RIGHT):
				_quad(st, Vector3(x0 + 1, h, z0 + 1), Vector3(x0 + 1, h, z0), Vector3(x0 + 1, 0, z0), Vector3(x0 + 1, 0, z0 + 1))
			if not _is_wall(cell + Vector2i.LEFT):
				_quad(st, Vector3(x0, h, z0), Vector3(x0, h, z0 + 1), Vector3(x0, 0, z0 + 1), Vector3(x0, 0, z0))
	var mesh := ArrayMesh.new()
	for texture: Texture2D in tools:
		var st: SurfaceTool = tools[texture]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(texture))
	var terrain := MeshInstance3D.new()
	terrain.mesh = mesh
	add_child(terrain)


func _tool(tools: Dictionary, texture: Texture2D) -> SurfaceTool:
	if not tools.has(texture):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[texture] = st
	return tools[texture]


## Un carré texturé (a, b, c, d dans le sens des aiguilles d'une montre vu de devant :
## a = coin haut-gauche de l'image, b = haut-droit, c = bas-droit, d = bas-gauche).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var points := [a, b, c, d]
	var normal := (c - a).cross(b - a).normalized() # La face regarde de ce côté (pour la lumière).
	for index in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[index])
		st.add_vertex(points[index])


## Le centre d'une case, au sol.
func _cell_position(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


# ---------------------------------------------------------------------------
# Lumières, objets et personnages
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b0809")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.38, 0.5)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	# Une faible lumière venue d'en haut, pour donner du relief aux murs.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 35, 0)
	sun.light_energy = 0.35
	sun.light_color = Color(0.7, 0.65, 0.9)
	add_child(sun)


func _build_heart_and_portal() -> void:
	# Le cœur : une gemme rouge qui tourne et brille, au-dessus du sol.
	_heart = MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = 0.35
	gem.height = 0.9
	gem.radial_segments = 6
	gem.rings = 2
	_heart.mesh = gem
	var heart_material := StandardMaterial3D.new()
	heart_material.albedo_color = Color("c62828")
	heart_material.emission_enabled = true
	heart_material.emission = Color("ff5252")
	heart_material.emission_energy_multiplier = 0.8
	heart_material.metallic = 0.3
	heart_material.roughness = 0.3
	_heart.material_override = heart_material
	_heart.position = _cell_position(_map.heart_cell) + Vector3(0, 0.75, 0)
	add_child(_heart)
	_heart_light = _light(_heart.position + Vector3(0, 0.3, 0), Color(1.0, 0.35, 0.3), 7.0, 2.2)
	_target = _cell_position(_map.heart_cell)

	# Le portail : un anneau violet dressé.
	var portal := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.45
	portal.mesh = ring
	var portal_material := StandardMaterial3D.new()
	portal_material.albedo_color = Color("6a1b9a")
	portal_material.emission_enabled = true
	portal_material.emission = Color("b388ff")
	portal.material_override = portal_material
	portal.position = _cell_position(_map.portal_cell) + Vector3(0, 0.55, 0)
	portal.rotation_degrees = Vector3(90, 0, 0)
	add_child(portal)
	_light(portal.position, Color(0.7, 0.4, 1.0), 5.0, 1.6)


func _light(at: Vector3, color: Color, light_range: float, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = energy
	add_child(light)
	return light


## Une image debout qui fait toujours face à la caméra (en tournant sur elle-même).
func _sprite(texture: Texture2D, at: Vector3) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = PIXEL_SIZE
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.offset = Vector2(0, 16) # Les pieds posés au sol.
	sprite.position = at
	add_child(sprite)
	return sprite


## Quelques torches le long des couloirs et dans les salles (8 au plus : les
## téléphones n'aiment pas les lumières trop nombreuses).
func _build_torches() -> void:
	var chosen: Array[Vector2i] = []
	for cell: Vector2i in _map.claimed:
		if chosen.size() >= 8 or _map.get_tile(cell) != DungeonMap.Tile.FLOOR or cell == _map.heart_cell:
			continue
		var far := true
		for other in chosen:
			if maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < 4:
				far = false
		if far:
			chosen.append(cell)
	for cell in chosen:
		var at := _cell_position(cell)
		var sprite := _sprite(Art.prop_frame("torch", 0), at)
		var light := _light(at + Vector3(0, 1.0, 0), Color(1.0, 0.7, 0.4), 4.5, 1.4)
		_torches.append({"sprite": sprite, "light": light, "offset": randf() * 10.0})


## Des ouvriers qui se promènent d'une case à l'autre du territoire.
func _build_workers() -> void:
	var floor_cells: Array[Vector2i] = []
	for cell: Vector2i in _map.claimed:
		if _map.is_walkable(cell):
			floor_cells.append(cell)
	for i in 5:
		var start: Vector2i = floor_cells.pick_random()
		var sprite := _sprite(Art.unit_frames("worker", "idle")[0], _cell_position(start))
		_workers.append({"sprite": sprite, "cells": floor_cells, "path": [], "wait": randf() * 2.0})


func _update_workers(delta: float) -> void:
	for worker: Dictionary in _workers:
		var sprite: Sprite3D = worker["sprite"]
		var path: Array = worker["path"]
		if path.is_empty():
			worker["wait"] -= delta
			sprite.texture = Art.unit_frames("worker", "idle")[int(_time * 2.0) % 2]
			if worker["wait"] <= 0.0:
				var here := Vector2i(int(sprite.position.x), int(sprite.position.z))
				var goal: Vector2i = worker["cells"].pick_random()
				var route := _map.find_path(here, goal)
				if route.size() > 1 and route.size() < 14:
					worker["path"] = Array(route).slice(1)
				worker["wait"] = randf_range(1.0, 3.0)
			continue
		var next := _cell_position(path[0])
		sprite.position = sprite.position.move_toward(next, delta * 1.6)
		sprite.texture = Art.unit_frames("worker", "walk")[int(_time * 8.0) % 4]
		if sprite.position.distance_to(next) < 0.01:
			path.remove_at(0)


# ---------------------------------------------------------------------------
# Caméra et contrôles
# ---------------------------------------------------------------------------

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()
	_update_camera()


## La caméra tourne autour du cœur (yaw), plus ou moins penchée (pitch) et loin.
func _update_camera() -> void:
	_pitch = clampf(_pitch, 0.35, 1.45)
	_distance = clampf(_distance, 5.0, 30.0)
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.position = _target + offset
	_camera.look_at(_target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			var points := _touches.values()
			_pinch_start = points[0].distance_to(points[1])
			_distance_start = _distance
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_yaw -= event.relative.x * 0.008
			_pitch += event.relative.y * 0.006
		elif _touches.size() == 2 and _pinch_start > 0.0:
			var points := _touches.values()
			var spread: float = points[0].distance_to(points[1])
			_distance = _distance_start * _pinch_start / maxf(spread, 1.0)
		_update_camera()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT \
			and DisplayServer.is_touchscreen_available() == false:
		_yaw -= event.relative.x * 0.008
		_pitch += event.relative.y * 0.006
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance *= 1.1
		_update_camera()


func _process(delta: float) -> void:
	_time += delta
	# Le cœur tourne et bat ; les torches vacillent.
	_heart.rotation.y += delta * 0.8
	var beat := 1.0 + 0.08 * maxf(0.0, sin(_time * 6.0))
	_heart.scale = Vector3.ONE * beat
	_heart_light.light_energy = 1.9 + 0.5 * sin(_time * 3.0)
	for torch: Dictionary in _torches:
		var t: float = _time + torch["offset"]
		torch["light"].light_energy = 1.3 + 0.25 * sin(t * 9.0) + 0.1 * sin(t * 23.0)
		torch["sprite"].texture = Art.prop_frame("torch", int(t * 6.0))
	_update_workers(delta)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = get_tree().root.theme
	layer.add_child(root)
	var title := Label.new()
	title.text = "Prototype 3D\nUn doigt : tourner   -   Deux doigts : zoomer"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ffd54a"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	root.add_child(title)
	var back := Button.new()
	back.text = "Retour au menu"
	back.custom_minimum_size = Vector2(220, 56)
	back.add_theme_font_size_override("font_size", 22)
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -240
	back.offset_right = -20
	back.offset_top = 14
	back.offset_bottom = 70
	back.pressed.connect(func() -> void:
		Sound.play("click")
		get_tree().change_scene_to_file(MENU_SCENE))
	root.add_child(back)

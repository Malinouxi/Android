class_name View3D
extends Node3D
## LA VUE 3D DU JEU.
##
## Tout le jeu (carte, ouvriers, combats, sauvegarde...) continue de fonctionner
## exactement comme avant, en coordonnées 2D « vues de dessus ». Cette vue se
## contente de le MONTRER en 3D :
##   - la carte devient des blocs : sol à plat, murs en relief, avec les mêmes
##     images pixel art (reconstruite quand la carte change, signal « redrawn ») ;
##   - les objets (coffres, lits, torches, portes...) et les personnages sont des
##     Sprite3D : des images qui font toujours face à la caméra ;
##   - le cœur est une gemme, le portail un anneau, avec des lumières.
## main.gd cache alors le monde 2D et branche la caméra (camera_controller.gd) et
## les effets (fx.gd) sur cette vue.
##
## Conversion : une case de 32 pixels = 1 unité 3D. Le point (x, y) de la carte
## devient (x / 32, hauteur, y / 32) : le « y » de la carte est le « z » de la 3D.

const TILE := 32.0
const WALL_HEIGHT := 1.3    ## Hauteur des murs (une case = 1 de large).
const PIXEL_SIZE := 0.026   ## Taille d'un pixel d'image (32 pixels -> 0,83 de haut).
const CHUNK := 8            ## La carte est découpée en blocs de 8 x 8 cases (voir _rebuild).
const REBUILD_DELAY := 0.2  ## Au plus 5 reconstructions par seconde.
const BASE_DISTANCE := 15.0 ## Distance de la caméra au zoom 1.
## Assombrissement du dessus des murs (0 = comme les côtés, 1 = noir).
const TOP_DARKEN := 0.5
const DECORATION_OFFSET := 0.012 ## Les tableaux sont décollés du mur, pour ne pas clignoter.

var map: DungeonMap
var camera: Camera3D
## Les nœuds qui contiennent les personnages (ouvriers, créatures, héros).
var unit_roots: Array[Node] = []

var _target := Vector3.ZERO ## Le point regardé, au sol.
var _yaw := PI / 4          ## Comme la vue isométrique 2D au départ.
var _pitch := 0.95
var _zoom := 1.0
var _dirty := true
var _rebuild_timer := 0.0
var _chunks: Array[MeshInstance3D] = []
var _materials := {}
var _props_root: Node3D
var _animated_props: Array = [] ## [[Sprite3D, nom de l'objet animé, case]]
var _unit_sprites := {}         ## Unit -> Sprite3D
var _torch_lights := {}         ## case -> OmniLight3D
var _heart: MeshInstance3D
var _heart_light: OmniLight3D
var _rival_heart: MeshInstance3D
var _environment: Environment
var _shake_time := 0.0
var _shake_strength := 0.0
var _time := 0.0


## À appeler juste après l'avoir ajoutée à la scène.
func setup(dungeon_map: DungeonMap, roots: Array[Node]) -> void:
	map = dungeon_map
	unit_roots = roots
	map.redrawn.connect(func() -> void: _dirty = true)
	_props_root = Node3D.new()
	add_child(_props_root)
	_build_environment()
	_build_heart_and_portal()
	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.make_current()
	center_on(map.cell_to_world(map.heart_cell))
	_rebuild()


# ---------------------------------------------------------------------------
# Conversions et caméra (appelées par camera_controller.gd, fx.gd, main.gd)
# ---------------------------------------------------------------------------

## Un point de la carte (en pixels 2D) -> un point 3D.
static func to_3d(map_position: Vector2, height := 0.0) -> Vector3:
	return Vector3(map_position.x / TILE, height, map_position.y / TILE)


## Le point de l'écran -> le point visé (en pixels de la carte).
## On suit le rayon qui part du doigt : il s'arrête sur le premier MUR qu'il
## touche (son dessus ou son côté), sinon sur le sol. (Viser seulement le sol
## donnait la case de derrière quand on touchait le dessus d'un mur.)
func screen_to_map(screen_position: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if direction.y > -0.0001:
		return target_map()
	# On commence là où le rayon descend à la hauteur des murs : rien avant.
	var point := origin + direction * maxf(0.0, (WALL_HEIGHT - origin.y) / direction.y)
	var step := direction * 0.04
	for i in 2000:
		var cell := Vector2i(floori(point.x), floori(point.z))
		if point.y <= WALL_HEIGHT and _is_wall(cell):
			return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE # Le centre du mur touché.
		if point.y <= 0.0:
			break
		point += step
	var hit := origin + direction * (-origin.y / direction.y) # Le sol.
	return Vector2(hit.x, hit.z) * TILE


## Le point de la carte -> sa position à l'écran (pour les effets et les touchers).
func unproject(map_position: Vector2, height := 0.0) -> Vector2:
	var point := to_3d(map_position, height)
	if camera.is_position_behind(point):
		return Vector2(-10000, -10000)
	return camera.unproject_position(point)


## Le point regardé, en pixels de la carte (pour la mini-carte).
func target_map() -> Vector2:
	return Vector2(_target.x, _target.z) * TILE


func center_on(map_position: Vector2) -> void:
	_target = to_3d(map_position)
	_clamp_target()


## Glisser le doigt : la carte suit le doigt.
func pan(screen_relative: Vector2) -> void:
	var height := float(get_viewport().get_visible_rect().size.y)
	var meters_per_pixel := 2.0 * _distance() * tan(deg_to_rad(camera.fov * 0.5)) / maxf(height, 1.0)
	var right := camera.global_transform.basis.x
	right.y = 0.0
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	_target -= right.normalized() * screen_relative.x * meters_per_pixel
	_target += forward.normalized() * screen_relative.y * meters_per_pixel / maxf(sin(_pitch), 0.3)
	_clamp_target()


func set_zoom(value: float) -> void:
	_zoom = value


func rotate_view(angle: float) -> void:
	_yaw -= angle


func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength / 80.0)
	_shake_time = maxf(_shake_time, duration)


## Un éclair de lumière bref (explosion, sort).
func flash(map_position: Vector2, color: Color, radius: float, duration: float) -> void:
	var light := OmniLight3D.new()
	light.position = to_3d(map_position, 1.0)
	light.light_color = color
	light.omni_range = radius / TILE * 1.5
	light.light_energy = 3.0
	add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration)
	tween.tween_callback(light.queue_free)


func _distance() -> float:
	return BASE_DISTANCE / _zoom


func _clamp_target() -> void:
	_target.x = clampf(_target.x, 0.0, DungeonMap.WIDTH)
	_target.z = clampf(_target.z, 0.0, DungeonMap.HEIGHT)
	_target.y = 0.0


func _update_camera(delta: float) -> void:
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance()
	camera.position = _target + offset
	camera.look_at(_target, Vector3.UP)
	if _shake_time > 0.0:
		_shake_time -= delta
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		if _shake_time <= 0.0:
			_shake_strength = 0.0


# ---------------------------------------------------------------------------
# Chaque image
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_rebuild_timer -= delta
	if _dirty and _rebuild_timer <= 0.0:
		_rebuild()
	_update_camera(delta)
	_update_units()
	# Le décor animé suit le « tic » d'animation de la carte (voir dungeon_map.gd).
	for entry: Array in _animated_props:
		var cell: Vector2i = entry[2]
		entry[0].texture = Art.prop_frame(entry[1], map.anim_tick + cell.x * 3 + cell.y * 5)
	# Le cœur tourne et bat (plus vite s'il est attaqué) ; les torches vacillent.
	var attacked := Time.get_ticks_msec() - map.last_heart_hit_msec < 3000
	_heart.rotation.y += delta * (2.5 if attacked else 0.8)
	_heart.scale = Vector3.ONE * (1.0 + 0.08 * maxf(0.0, sin(_time * (14.0 if attacked else 6.0))))
	_heart_light.light_energy = 1.9 + 0.5 * sin(_time * 3.0)
	if _rival_heart != null:
		_rival_heart.visible = map.rival_heart_hp > 0.0
		_rival_heart.rotation.y -= delta * 0.8
	for cell: Vector2i in _torch_lights:
		var t := _time + cell.x * 1.7 + cell.y * 2.3
		_torch_lights[cell].light_energy = 1.2 + 0.25 * sin(t * 9.0) + 0.1 * sin(t * 23.0)


## Les personnages : un Sprite3D par unité, qui recopie sa position et son image.
func _update_units() -> void:
	for root in unit_roots:
		for node in root.get_children():
			var unit := node as Unit
			if unit == null:
				continue
			var sprite: Sprite3D = _unit_sprites.get(unit)
			if sprite == null:
				sprite = _make_sprite(null, Vector3.ZERO, 1.0)
				_unit_sprites[unit] = sprite
			_show_unit(unit, sprite)
	# Les unités disparues (mortes, parties) : on retire leur image.
	for unit in _unit_sprites.keys():
		if not is_instance_valid(unit):
			_unit_sprites[unit].queue_free()
			_unit_sprites.erase(unit)


func _show_unit(unit: Unit, sprite: Sprite3D) -> void:
	sprite.visible = not unit.in_hand and not unit.is_queued_for_deletion()
	if not sprite.visible:
		return
	var info := unit.sprite_info()
	sprite.texture = unit.animation_frame(info[0])
	sprite.pixel_size = PIXEL_SIZE * float(info[1])
	sprite.flip_h = unit.is_facing_left()
	sprite.modulate = unit.modulate * unit.self_modulate
	var height := 0.0
	var lying := false
	var hero := unit as Hero
	if hero != null:
		lying = hero.knocked_out or hero.carrier != null
		if hero.carrier != null:
			height = 0.9 # Porté au-dessus de l'Attrapeur.
		if hero.is_captured():
			sprite.modulate = sprite.modulate.darkened(0.35) # Derrière les barreaux.
	# Un héros assommé est couché au sol : l'image est posée à plat.
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED if lying else BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.rotation_degrees = Vector3(-90, 0, 0) if lying else Vector3.ZERO
	sprite.position = to_3d(unit.position, height + (0.05 if lying else 0.0))


# ---------------------------------------------------------------------------
# Construction de la carte en 3D
# ---------------------------------------------------------------------------

func _is_wall(cell: Vector2i) -> bool:
	if not map.is_inside(cell):
		return true
	var tile := map.get_tile(cell)
	return tile == DungeonMap.Tile.EARTH or tile == DungeonMap.Tile.GOLD or tile == DungeonMap.Tile.ROCK


## Reconstruit le sol, les murs et les objets. La carte est découpée en morceaux
## de 8 x 8 cases : chaque morceau n'est éclairé que par les lumières proches
## (les téléphones limitent le nombre de lumières par objet).
func _rebuild() -> void:
	_dirty = false
	_rebuild_timer = REBUILD_DELAY
	for chunk in _chunks:
		chunk.queue_free()
	_chunks.clear()
	for cy in range(0, DungeonMap.HEIGHT, CHUNK):
		for cx in range(0, DungeonMap.WIDTH, CHUNK):
			var tools := {}
			for y in range(cy, mini(cy + CHUNK, DungeonMap.HEIGHT)):
				for x in range(cx, mini(cx + CHUNK, DungeonMap.WIDTH)):
					_add_cell(tools, Vector2i(x, y))
			var mesh := ArrayMesh.new()
			for key: String in tools:
				var st: SurfaceTool = tools[key][0]
				st.commit(mesh)
				mesh.surface_set_material(mesh.get_surface_count() - 1, tools[key][1])
			var chunk := MeshInstance3D.new()
			chunk.mesh = mesh
			add_child(chunk)
			_chunks.append(chunk)
	_rebuild_props()


## Le SurfaceTool d'un matériau (une image, une teinte, transparente ou non).
func _tool(tools: Dictionary, texture: Texture2D, tint := Color.WHITE, transparent := false) -> SurfaceTool:
	var key := "%d|%s|%s" % [texture.get_instance_id(), tint.to_html(), transparent]
	if not tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = [st, _material(key, texture, tint, transparent)]
	return tools[key][0]


func _material(key: String, texture: Texture2D, tint: Color, transparent: bool) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.albedo_color = tint
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if transparent:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_materials[key] = material
	return _materials[key]


## Un carré texturé : a = coin haut-gauche de l'image, b = haut-droit, c = bas-droit, d = bas-gauche.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var points := [a, b, c, d]
	for index in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[index])
		st.add_vertex(points[index])


## Un carré à plat (sol), un peu rétréci de « inset » de chaque côté.
func _flat(st: SurfaceTool, cell: Vector2i, height: float, inset := 0.0) -> void:
	var x0 := cell.x + inset
	var z0 := cell.y + inset
	var x1 := cell.x + 1.0 - inset
	var z1 := cell.y + 1.0 - inset
	_quad(st, Vector3(x0, height, z0), Vector3(x1, height, z0), Vector3(x1, height, z1), Vector3(x0, height, z1), Vector3.UP)


## Une face verticale du bloc « cell », du côté « direction ». u0..u1 : la partie de
## la largeur couverte ; h0..h1 : la partie de la hauteur ; offset : décollée du mur.
func _side(st: SurfaceTool, cell: Vector2i, direction: Vector2i, u0 := 0.0, u1 := 1.0,
		h0 := 0.0, h1 := WALL_HEIGHT, offset := 0.0) -> void:
	var normal := Vector3(direction.x, 0, direction.y)
	var center := Vector3(cell.x + 0.5, 0.0, cell.y + 0.5) + normal * (0.5 + offset)
	var right := Vector3.UP.cross(normal) # La droite, vue depuis l'extérieur du mur.
	var a := center + right * (u0 - 0.5) + Vector3.UP * h1
	var b := center + right * (u1 - 0.5) + Vector3.UP * h1
	var c := center + right * (u1 - 0.5) + Vector3.UP * h0
	var d := center + right * (u0 - 0.5) + Vector3.UP * h0
	_quad(st, a, b, c, d, normal)


func _add_cell(tools: Dictionary, cell: Vector2i) -> void:
	if not _is_wall(cell):
		_add_floor(tools, cell)
		return
	var tile := map.get_tile(cell) if map.is_inside(cell) else DungeonMap.Tile.ROCK
	var images: Array = Art.ROCK
	if tile == DungeonMap.Tile.EARTH:
		images = Art.EARTH
	elif tile == DungeonMap.Tile.GOLD:
		images = Art.GOLD
	var texture: Texture2D = Art.pick(images, cell)
	# Teinte : jaune si la case est marquée « à creuser », plus sombre si elle est entamée.
	var tint := Color.WHITE
	if map.marked.has(cell):
		tint = Color(1.0, 0.85, 0.35)
	if map.damage.has(cell) and DungeonMap.DIG_HITS.has(tile):
		tint = tint.darkened(0.5 * float(map.damage[cell]) / DungeonMap.DIG_HITS[tile])
	var st := _tool(tools, texture, tint)
	# Le dessus des murs est plus sombre que le sol : on voit mieux le relief.
	# (Sauf s'il est marqué : le jaune doit bien se voir.)
	var top_tint := tint if map.marked.has(cell) else tint.darkened(TOP_DARKEN)
	_flat(_tool(tools, texture, top_tint), cell, WALL_HEIGHT)
	for direction in DungeonMap.DIRECTIONS:
		var neighbour: Vector2i = cell + direction
		if _is_wall(neighbour):
			continue # Face cachée par le bloc voisin : inutile de la dessiner.
		_side(st, cell, direction)
		# Un tableau ou une tapisserie accroché sur cette face, vu depuis la case voisine ?
		var deco: Dictionary = map.decorations.get(neighbour, {})
		if deco.get("side") == -direction:
			var kind: String = deco["kind"]
			var low := 0.4 if kind == "painting" else 0.15
			_side(_tool(tools, Art.DECORATIONS[kind], Color.WHITE, true), cell, direction, 0.2, 0.8,
					low, WALL_HEIGHT - 0.12, DECORATION_OFFSET)


func _add_floor(tools: Dictionary, cell: Vector2i) -> void:
	var texture: Texture2D
	var tint := Color.WHITE
	if map.rooms.has(cell):
		texture = Art.ROOM_FLOORS[map.get_room(cell)]
	elif map.rival_claimed.has(cell):
		texture = Art.pick(Art.CLAIMED, cell)
		tint = Color(0.6, 0.7, 1.0)
	elif map.claimed.has(cell):
		texture = Art.pick(Art.CLAIMED, cell)
	else:
		texture = Art.pick(Art.FLOOR, cell)
	_flat(_tool(tools, texture, tint), cell, 0.0)
	# Ce qui est posé à plat sur le sol, juste au-dessus pour ne pas clignoter.
	if map.construction.has(cell) and map.construction[cell]["kind"] == "room":
		_flat(_tool(tools, Art.ROOM_FLOORS[map.construction[cell]["type"]], Color(1, 1, 1, 0.5), true), cell, 0.005)
	if map.decorations.has(cell) and map.decorations[cell]["kind"] == "rug":
		_flat(_tool(tools, Art.DECORATIONS["rug"], Color.WHITE, true), cell, 0.01, 0.1)
	if map.defenses.has(cell):
		var defense: Dictionary = map.defenses[cell]
		if defense["type"] == Defenses.Type.SPIKES:
			_flat(_tool(tools, Art.SPIKES_UP if defense["flash"] > 0.0 else Art.SPIKES_DOWN), cell, 0.01)
		elif defense["type"] == Defenses.Type.RUNE:
			_flat(_tool(tools, Art.RUNE, Color.WHITE, true), cell, 0.01)


# ---------------------------------------------------------------------------
# Les objets debout (des images qui font face à la caméra)
# ---------------------------------------------------------------------------

func _make_sprite(texture: Texture2D, at: Vector3, scale_factor: float, parent: Node = null) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = PIXEL_SIZE * scale_factor
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.offset = Vector2(0, 16) # Les pieds posés au sol.
	sprite.position = at
	(parent if parent != null else self).add_child(sprite)
	return sprite


func _prop(texture: Texture2D, cell: Vector2i, scale_factor := 1.0, offset := Vector2.ZERO,
		tint := Color.WHITE) -> Sprite3D:
	var at := Vector3(cell.x + 0.5 + offset.x, 0.0, cell.y + 0.5 + offset.y)
	var sprite := _make_sprite(texture, at, scale_factor, _props_root)
	sprite.modulate = tint
	return sprite


func _animated_prop(prop: String, cell: Vector2i, scale_factor := 1.0) -> void:
	var sprite := _prop(Art.prop_frame(prop, 0), cell, scale_factor)
	_animated_props.append([sprite, prop, cell])


## Recrée tous les objets debout (la même liste que dungeon_map.gd, _draw_standing_objects).
func _rebuild_props() -> void:
	for child in _props_root.get_children():
		child.queue_free()
	_animated_props.clear()
	var wanted_torches := {}
	for y in DungeonMap.HEIGHT:
		for x in DungeonMap.WIDTH:
			var cell := Vector2i(x, y)
			if _is_wall(cell):
				continue
			if map.get_tile(cell) == DungeonMap.Tile.ENTRANCE:
				_prop(Art.ENTRANCE, cell, 1.3)
			if map.rooms.has(cell):
				_room_prop(cell)
			if map.torch_cells.has(cell) and not map.rooms.has(cell) and not map.defenses.has(cell):
				_animated_prop("torch", cell, 0.8)
				wanted_torches[cell] = true
			if map.defenses.has(cell):
				match int(map.defenses[cell]["type"]):
					Defenses.Type.ALTAR:
						_animated_prop("sacrifice_altar", cell, 1.1)
					Defenses.Type.DOOR:
						_prop(Art.DOOR, cell, 1.1)
			if map.loose_gold.has(cell):
				var pile := clampi(int(map.loose_gold[cell]) / 40, 0, Art.GOLD_PILES.size() - 1)
				_prop(Art.GOLD_PILES[pile], cell, 0.75)
			if map.construction.has(cell):
				# Un chantier : l'objet en transparence bleutée.
				_prop(map._site_texture(map.construction[cell]), cell, 0.9, Vector2.ZERO, Color(0.7, 0.85, 1.0, 0.5))
	# Les lumières des torches : on garde celles qui existent déjà.
	for cell: Vector2i in _torch_lights.keys():
		if not wanted_torches.has(cell):
			_torch_lights[cell].queue_free()
			_torch_lights.erase(cell)
	for cell: Vector2i in wanted_torches:
		if not _torch_lights.has(cell):
			_torch_lights[cell] = _light(Vector3(cell.x + 0.5, 1.0, cell.y + 0.5), Color(1.0, 0.7, 0.4), 4.5, 1.3)


func _room_prop(cell: Vector2i) -> void:
	match map.get_room(cell):
		Rooms.Type.TREASURY:
			var fill: float = float(map.stored_gold.get(cell, 0)) / Rooms.TREASURY_CAPACITY
			_prop(Art.CHESTS[0 if fill <= 0.0 else mini(3, 1 + int(fill * 3.0))], cell, 0.95)
		Rooms.Type.LAIR:
			_prop(Art.BED, cell, 0.9)
		Rooms.Type.FARM:
			var spots := [Vector2(-0.25, 0.2), Vector2(0.22, -0.2), Vector2(0.12, 0.28)]
			for i in int(map.food.get(cell, 0)):
				_prop(Art.MUSHROOM, cell, 0.5, spots[i])
		Rooms.Type.WORKSHOP:
			_animated_prop("anvil", cell)
		Rooms.Type.TRAINING:
			_animated_prop("dummy", cell)
		Rooms.Type.TEMPLE:
			_animated_prop("altar", cell)
		Rooms.Type.GRAVEYARD:
			if map.graves.has(cell):
				_animated_prop("tomb_full", cell, 0.95)
			else:
				_prop(Art.TOMB_EMPTY, cell, 0.95)
		Rooms.Type.LIBRARY:
			_prop(Art.ROOM_PROPS[Rooms.Type.LIBRARY], cell)


# ---------------------------------------------------------------------------
# Lumières, cœur et portail
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("0b0809")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.45, 0.38, 0.5)
	# Sans « éclairage » (réglages), tout est bien éclairé.
	_environment.ambient_light_energy = 0.55 if Sound.lighting_enabled else 1.4
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 35, 0)
	sun.light_energy = 0.35
	sun.light_color = Color(0.7, 0.65, 0.9)
	add_child(sun)


func _light(at: Vector3, color: Color, light_range: float, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = energy
	add_child(light)
	return light


func _gem(color: Color, glow: Color) -> MeshInstance3D:
	var gem := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.35
	shape.height = 0.9
	shape.radial_segments = 6
	shape.rings = 2
	gem.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = 0.8
	material.metallic = 0.3
	material.roughness = 0.3
	gem.material_override = material
	add_child(gem)
	return gem


func _build_heart_and_portal() -> void:
	_heart = _gem(Color("c62828"), Color("ff5252"))
	_heart.position = to_3d(map.cell_to_world(map.heart_cell), 0.75)
	_heart_light = _light(_heart.position + Vector3(0, 0.3, 0), Color(1.0, 0.35, 0.3), 7.0, 2.2)
	if map.has_rival:
		_rival_heart = _gem(Color("1565c0"), Color("64b5f6"))
		_rival_heart.position = to_3d(map.cell_to_world(map.rival_heart_cell), 0.75)
		_light(_rival_heart.position, Color(0.4, 0.6, 1.0), 6.0, 1.8)

	var portal := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.45
	portal.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6a1b9a")
	material.emission_enabled = true
	material.emission = Color("b388ff")
	portal.material_override = material
	portal.position = to_3d(map.cell_to_world(map.portal_cell), 0.55)
	portal.rotation_degrees = Vector3(90, 45, 0)
	add_child(portal)
	_light(portal.position, Color(0.7, 0.4, 1.0), 5.0, 1.6)
	_light(to_3d(map.cell_to_world(map.entrance_cell), 1.2), Color(0.8, 0.85, 1.0), 4.0, 1.0)

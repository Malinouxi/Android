class_name View3D
extends Node3D
## LA VUE 3D DU JEU.
##
## Tout le jeu (carte, ouvriers, combats, sauvegarde...) continue de fonctionner
## exactement comme avant, en coordonnées 2D « vues de dessus ». Cette vue se
## contente de le MONTRER en 3D :
##   - la carte devient des blocs : sol à plat, murs en relief, avec les images
##     pixel art (reconstruite quand la carte change, signal « redrawn ») ;
##   - les personnages et les objets sont des modèles en blocs (voxel_models.gd),
##     animés ici : marche, attaque, ailes, flammes...
##   - les effets sont dans la scène : barres de vie, cercles au sol, particules.
## main.gd (et menu.gd) cachent alors le monde 2D et branchent la caméra
## (camera_controller.gd) et les effets (fx.gd) sur cette vue.
##
## Conversion : une case de 32 pixels = 1 unité 3D. Le point (x, y) de la carte
## devient (x / 32, hauteur, y / 32) : le « y » de la carte est le « z » de la 3D.

const TILE := 32.0
const WALL_HEIGHT := 1.3    ## Hauteur des murs (une case = 1 de large).
const CHUNK := 8            ## La carte est découpée en blocs de 8 x 8 cases (voir _rebuild).
const REBUILD_DELAY := 0.2  ## Au plus 5 reconstructions par seconde.
const BASE_DISTANCE := 15.0 ## Distance de la caméra au zoom 1.
## Assombrissement du dessus des murs (0 = comme les côtés, 1 = noir).
const TOP_DARKEN := 0.2
const DECORATION_OFFSET := 0.012 ## Les tableaux sont décollés du mur, pour ne pas clignoter.
const BAR_WIDTH := 0.5      ## Largeur des barres de vie au-dessus des têtes.

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
## L'empreinte de chaque morceau (voir _chunk_key) : seuls ceux qui ont changé sont reconstruits.
var _chunk_keys: Array[int] = []
var _materials := {}
var _flat_materials := {}   ## Couleur -> matériau sans ombrage (barres, cercles).
var _cell_props := {}       ## case -> {"sig": texte, "node": Node3D, "anims": [...]}
var _units := {}            ## Unit -> données de son modèle (voir _make_unit)
var _torch_lights := {}     ## case -> OmniLight3D
var _dig_icons := {}
const COBBLES := [preload("res://assets/tiles_hd/cobble_0.png"), preload("res://assets/tiles_hd/cobble_1.png")]
## Les textures peintes de tools/blender/textures.py : gros moellons des murs de ton
## territoire, dalles du dessus des murs et du sol des salles.
const WALL_STONE := preload("res://assets/tiles_hd/wall_stone.png")
const WALL_TOP := preload("res://assets/tiles_hd/wall_top.png")
const FLOOR_STONE := preload("res://assets/tiles_hd/floor_stone.png")
const TORCH_COLOR := Color(1.0, 0.58, 0.26)
const GEM_TINT := Color(0.55, 0.75, 1.0)
## Le feu des braseros : rouge comme ton cœur, violet pour le maître rival.
const HEART_FIRE := Color(1.0, 0.22, 0.12)
const RIVAL_FIRE := Color(0.7, 0.3, 1.0)
const LAVA_GLOW := Color(1.0, 0.38, 0.08)  ## La lueur de la lave.
const RUIN_GLOW := Color(0.55, 0.4, 1.0)   ## La lueur du grimoire d'une ruine.
var _brazier_lights := {} ## case -> OmniLight3D
## Les salles dont l'objet occupe plusieurs cases (un seul modèle par objet).
const MULTI_CELL_ROOMS := Rooms.MULTI_CELL        ## case marquée « à creuser » -> Sprite3D (une pioche)
const PICKAXE_ICON := preload("res://assets/icons/pickaxe.png")
var _effect_discs: Array[MeshInstance3D] = []
var _heart: MeshInstance3D
var _heart_light: OmniLight3D
var _throne_anim := {}      ## Les flammes du trône du cœur (voir _build_heart_and_portal).
var _rival_heart: MeshInstance3D
var _environment: Environment
var _shake_time := 0.0
var _shake_strength := 0.0
var _time := 0.0
var _flash_material: StandardMaterial3D
## Les effets des sorts, le sol qui brûle et le sang (voir fx_3d.gd).
var fx3d: Fx3D


## À appeler juste après l'avoir ajoutée à la scène.
func setup(dungeon_map: DungeonMap, roots: Array[Node]) -> void:
	map = dungeon_map
	unit_roots = roots
	map.redrawn.connect(func() -> void: _dirty = true)
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = Color(1, 1, 1, 0.6)
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_build_environment()
	_build_heart_and_portal()
	fx3d = Fx3D.new()
	fx3d.setup(map)
	add_child(fx3d)
	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.make_current()
	center_on(map.cell_to_world(map.heart_cell))
	_update_camera(0.0)
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


## Le point de la carte -> sa position à l'écran (pour les chiffres et les touchers).
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
## (Au plus Fx3D.MAX_LIGHTS à la fois : voir fx_3d.gd.)
func flash(map_position: Vector2, color: Color, radius: float, duration: float) -> void:
	fx3d.flash(to_3d(map_position, 1.0), color, radius / TILE * 1.5, duration)


## Une gerbe de particules en 3D (les réglages viennent de Fx.BURSTS).
## Les vitesses et la gravité sont en pixels 2D : on les divise par 32.
func burst(map_position: Vector2, settings: Dictionary, color: Color) -> void:
	var particles := CPUParticles3D.new()
	var cube := BoxMesh.new()
	var size: float = settings["size"] * 0.012
	cube.size = Vector3(size, size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cube.material = material
	particles.mesh = cube
	particles.position = to_3d(map_position, 0.4)
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = settings["amount"]
	particles.lifetime = settings["life"]
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = settings["speed"] / TILE * 0.5
	particles.initial_velocity_max = settings["speed"] / TILE
	particles.gravity = Vector3(0, -settings["gravity"] / TILE, 0)
	particles.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(settings["life"] + 0.3).timeout.connect(particles.queue_free)


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
	_update_props()
	_update_effects()
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
		_torch_lights[cell].light_energy = 1.05 + 0.22 * sin(t * 9.0) + 0.09 * sin(t * 23.0)


## Un matériau sans ombrage (qui ne dépend pas de la lumière), toujours visible.
func _flat_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _flat_materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		material.no_depth_test = true # Les barres se voient même derrière un mur.
		material.render_priority = 10
		if color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flat_materials[key] = material
	return _flat_materials[key]


func _quad_mesh(size: Vector2) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	return mesh


# ---------------------------------------------------------------------------
# Les personnages
# ---------------------------------------------------------------------------

## Crée le modèle 3D d'une unité, avec son ombre, ses barres et ses accessoires.
func _make_unit(unit: Unit) -> Dictionary:
	var info := unit.sprite_info()
	var holder := Node3D.new()
	add_child(holder)
	var tint := Color(unit.self_modulate.r, unit.self_modulate.g, unit.self_modulate.b)
	var model := VoxelModels.character(info[0], tint, unit.self_modulate.a)
	model.scale = Vector3.ONE * float(info[1])
	holder.add_child(model)
	# Une ombre ronde au sol (bleutée sous les héros, comme en 2D).
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28 * float(info[1])
	disc.bottom_radius = disc.top_radius
	disc.height = 0.01
	disc.radial_segments = 16
	shadow.mesh = disc
	var shadow_color := Color(0.2, 0.45, 1.0, 0.45) if unit.team == Unit.Team.HEROES else Color(0, 0, 0, 0.45)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.albedo_color = shadow_color
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = shadow_material
	shadow.position.y = 0.012
	holder.add_child(shadow)
	# L'anneau bleu d'une unité accélérée (sort Hâte, cri de guerre).
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.4
	ring.mesh = torus
	ring.material_override = VoxelModels.material(Color(0.3, 0.9, 1.0), true)
	ring.position.y = 0.03
	ring.visible = false
	holder.add_child(ring)
	# Le sac d'or (ouvrier chargé, Voleuse avec son butin), sur le dos.
	var sack := VoxelModels.sphere(model, 0.09, Vector3(0, 0.5, -0.16), Color("ffd54a"), true)
	sack.visible = false
	# Les barres au-dessus de la tête : vie (rouge) et humeur (créatures).
	var bars := Node3D.new()
	bars.position.y = 1.0 * float(info[1]) + 0.15
	holder.add_child(bars)
	var hp_back := MeshInstance3D.new()
	hp_back.mesh = _quad_mesh(Vector2(BAR_WIDTH, 0.07))
	hp_back.material_override = _flat_material(Color(0, 0, 0, 0.7))
	bars.add_child(hp_back)
	var hp_bar := MeshInstance3D.new()
	hp_bar.mesh = _quad_mesh(Vector2(BAR_WIDTH, 0.05))
	hp_bar.material_override = _flat_material(Color("e53935"))
	hp_bar.position.z = 0.001
	bars.add_child(hp_bar)
	var mood_bar: MeshInstance3D = null
	if unit is Creature:
		mood_bar = MeshInstance3D.new()
		mood_bar.mesh = _quad_mesh(Vector2(BAR_WIDTH, 0.04))
		mood_bar.position.y = 0.08
		bars.add_child(mood_bar)
	# Au-dessus des héros : le nom d'un vétéran, « fuit ! » pendant une retraite.
	var title: Label3D = null
	if unit is Hero:
		title = Label3D.new()
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.no_depth_test = true
		title.fixed_size = false
		title.pixel_size = 0.004
		title.font_size = 48
		title.outline_size = 12
		title.outline_modulate = Color(0, 0, 0, 0.9)
		title.position.y = bars.position.y + 0.22
		title.visible = false
		holder.add_child(title)
	var rig: Dictionary = model.get_meta("rig")
	var held := _make_held_props(unit, rig)
	var parts: Array[MeshInstance3D] = []
	_collect_parts(model, parts)
	var body: Node3D = rig["body"]
	return {"holder": holder, "model": model, "rig": rig, "ring": ring, "sack": sack,
			"bars": bars, "hp": hp_bar, "hp_back": hp_back, "mood": mood_bar, "mood_index": -1,
			"parts": parts, "flash": false, "last": unit.position, "phase": randf() * TAU, "title": title,
			"held": held, "shown": "", "head": body.get_node_or_null("head"),
			"has_gold": "carried_gold" in unit, "has_loot": "loot" in unit}


## Les objets qu'une créature tient pendant certaines activités (voir _animate) :
## une chope (Taverne), un champignon (repas), un grimoire (Bibliothèque), un fouet
## (Chambre de torture). Ils sont cachés le reste du temps.
func _make_held_props(unit: Unit, rig: Dictionary) -> Dictionary:
	var held := {}
	var arms: Array = rig["arms"]
	if not unit is Creature or arms.size() < 2 or rig["kind"] != "humanoid":
		return held
	var left: Node3D = arms[0]
	var right: Node3D = arms[1]
	# La main, par rapport au pivot du bras (ou au point de prise, avec un squelette).
	var hand: Vector3 = rig.get("hand", Vector3(0.0, -0.31, 0.04))
	# La chope de bière, mousse comprise.
	var mug := Node3D.new()
	left.add_child(mug)
	mug.position = hand
	VoxelModels.cylinder(mug, 0.04, 0.045, 0.09, Vector3(0, 0.02, 0.03), Color("8d5a2b"))
	VoxelModels.cylinder(mug, 0.046, 0.046, 0.015, Vector3(0, -0.01, 0.03), Color("5c646b"))
	VoxelModels.sphere(mug, 0.04, Vector3(0, 0.07, 0.03), Color("fff8e1"))
	VoxelModels.box(mug, Vector3(0.015, 0.05, 0.03), Vector3(0.055, 0.02, 0.03), Color("6d4c41"))
	held["drink"] = mug
	# Un champignon à croquer.
	var food := Node3D.new()
	left.add_child(food)
	food.position = hand
	VoxelModels.cylinder(food, 0.015, 0.015, 0.06, Vector3(0, 0.0, 0.03), Color("efebe9"))
	VoxelModels.sphere(food, 0.045, Vector3(0, 0.04, 0.03), Color("d32f2f"))
	held["eat"] = food
	# Un grimoire ouvert, tenu devant soi.
	var book := Node3D.new()
	left.add_child(book)
	book.position = hand + Vector3(0.08, 0.0, 0.04)
	VoxelModels.box(book, Vector3(0.18, 0.02, 0.13), Vector3.ZERO, Color("8e1b1b"))
	VoxelModels.box(book, Vector3(0.16, 0.025, 0.11), Vector3(0, 0.005, 0), Color("efe6d8"))
	held["study"] = book
	# Le fouet du bourreau : un manche et une lanière qui pend.
	var whip := Node3D.new()
	right.add_child(whip)
	whip.position = hand
	VoxelModels.box(whip, Vector3(0.025, 0.12, 0.025), Vector3(0, 0, 0.04), Color("4e342e"))
	VoxelModels.box(whip, Vector3(0.012, 0.32, 0.012), Vector3(0, -0.2, 0.05), Color("3e2723"))
	held["torture"] = whip
	for node: Node3D in held.values():
		node.visible = false
	return held


## Les plans de la vue de la caméra, recalculés à chaque image (voir _on_screen).
var _frustum: Array[Plane] = []
## Les matériaux de la barre d'humeur, par dixième d'humeur (0 à 10).
var _mood_materials: Array[StandardMaterial3D] = []


## Vrai si un point (avec une marge de « margin » cases) peut être à l'écran.
## Hors de l'écran, on ne prend pas la peine d'animer bras, jambes et flammes.
func _on_screen(point: Vector3, margin := 1.5) -> bool:
	for plane in _frustum:
		if plane.distance_to(point) > margin:
			return false
	return true


func _mood_material(happy: float) -> StandardMaterial3D:
	if _mood_materials.is_empty():
		for i in 11:
			_mood_materials.append(_flat_material(Color.RED.lerp(Color.GREEN, i / 10.0)))
	return _mood_materials[clampi(roundi(snappedf(happy, 0.1) * 10.0), 0, 10)]


func _collect_parts(node: Node, parts: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			parts.append(child)
		_collect_parts(child, parts)


func _update_units() -> void:
	_frustum = camera.get_frustum()
	for root in unit_roots:
		for node in root.get_children():
			var unit := node as Unit
			if unit == null or unit.is_queued_for_deletion():
				continue
			if not _units.has(unit):
				_units[unit] = _make_unit(unit)
			_show_unit(unit, _units[unit])
	# Les unités disparues (mortes, parties) : leur modèle bascule, puis s'efface.
	for unit in _units.keys():
		if not is_instance_valid(unit) or unit.is_queued_for_deletion():
			var data: Dictionary = _units[unit]
			_units.erase(unit)
			_fall_and_vanish(data)


func _fall_and_vanish(data: Dictionary) -> void:
	var holder: Node3D = data["holder"]
	var model: Node3D = data["model"]
	data["bars"].visible = false
	data["ring"].visible = false
	if data["title"] != null:
		data["title"].visible = false
	var tween := holder.create_tween()
	tween.tween_property(model, "rotation:x", -PI / 2, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.4)
	tween.tween_property(holder, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tween.tween_callback(holder.queue_free)


func _show_unit(unit: Unit, data: Dictionary) -> void:
	var holder: Node3D = data["holder"]
	holder.visible = not unit.in_hand
	if not holder.visible:
		return
	var model: Node3D = data["model"]
	var rig: Dictionary = data["rig"]
	# Position, et orientation : le modèle se tourne doucement vers où il va.
	var height := 0.0
	var lying := false
	var hero := unit as Hero
	if hero != null:
		lying = hero.knocked_out or hero.carrier != null
		if hero.carrier != null:
			height = 0.85 # Porté au-dessus de l'Attrapeur.
	holder.position = to_3d(unit.position, height)
	var moved: Vector2 = unit.position - data["last"]
	data["last"] = unit.position
	var pose := unit.pose()
	var walking := unit.is_walking()
	# Endormie dans son lit ou couchée à l'Infirmerie : allongée, la tête vers le chevet.
	var resting: bool = (pose == "sleep" or pose == "lie") and rig["kind"] == "humanoid" and not walking
	if moved.length() > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(moved.x, moved.y), 0.3)
	elif resting:
		model.rotation.y = PI / 2
	else:
		# Au travail, elle se tourne vers l'objet de la salle (l'enclume, le comptoir...).
		var focus := unit.focus_point()
		if focus != Vector2.INF and focus.distance_to(unit.position) > 2.0:
			var facing := atan2(focus.x - unit.position.x, focus.y - unit.position.y)
			if pose == "guard":
				facing += PI + sin(_time * 0.6 + data["phase"]) * 1.1 # Le guetteur scrute les couloirs.
			model.rotation.y = lerp_angle(model.rotation.y, facing, 0.08)
	model.rotation.x = -PI / 2 if lying or resting else 0.0 # Assommé ou couché : sur le dos.
	model.position = Vector3.ZERO
	if lying:
		model.position.y = 0.15
	elif resting:
		# Sur le lit (ou la paillasse), le corps centré sur la couche.
		var size := float(unit.sprite_info()[1])
		model.position = Vector3(0.38 * size, 0.3 if pose == "sleep" else 0.1, 0.0)
	# Hors de l'écran : seuls la position, l'orientation et le flash sont tenus à jour
	# (le reste n'est que décor, refait dès que l'unité revient dans la vue).
	var visible_now := _on_screen(holder.position + Vector3(0.0, 0.5, 0.0))
	data["lying"] = lying
	if rig.get("anim") != null:
		rig["anim"].active = visible_now # Hors de l'écran, le squelette ne calcule rien.
	if visible_now:
		_animate(unit, rig, data, pose, walking)
	# Le flash blanc quand l'unité est touchée (unit.gd met modulate à 2,5).
	var flashing := unit.modulate.r > 1.3
	if flashing != data["flash"]:
		data["flash"] = flashing
		for part: MeshInstance3D in data["parts"]:
			part.material_overlay = _flash_material if flashing else null
	data["ring"].visible = unit.is_hasted()
	if not visible_now:
		return
	var title: Label3D = data["title"]
	if title != null:
		var text: String = hero.overhead_text()
		title.visible = text != ""
		if title.visible:
			title.text = text
			title.modulate = Color("ffd54a") if hero.is_veteran() else Color.WHITE
	var gold := 0
	if data["has_gold"]:
		gold += int(unit.get("carried_gold"))
	if data["has_loot"]:
		gold += int(unit.get("loot"))
	data["sack"].visible = gold > 0
	# Les barres : la vie (si blessée), l'humeur des créatures. Elles font face à la caméra.
	var bars: Node3D = data["bars"]
	var creature := unit as Creature
	bars.visible = not lying and (unit.hp < unit.max_hp or creature != null)
	if bars.visible:
		bars.global_basis = camera.global_basis
		var hp_bar: MeshInstance3D = data["hp"]
		var ratio := clampf(unit.hp / unit.max_hp, 0.0, 1.0)
		hp_bar.visible = unit.hp < unit.max_hp
		data["hp_back"].visible = hp_bar.visible
		hp_bar.scale.x = maxf(ratio, 0.001)
		hp_bar.position.x = -BAR_WIDTH * 0.5 * (1.0 - ratio)
		if creature != null:
			var mood: MeshInstance3D = data["mood"]
			var happy := clampf(creature.happiness / 100.0, 0.0, 1.0)
			mood.scale.x = maxf(happy, 0.001)
			mood.position.x = -BAR_WIDTH * 0.5 * (1.0 - happy)
			mood.material_override = _mood_material(happy)


## Les mouvements : jambes et bras qui balancent en marchant, bras qui frappe,
## ailes qui battent, queue qui remue.
func _animate(unit: Unit, rig: Dictionary, data: Dictionary, pose: String, walking: bool) -> void:
	if rig.get("anim") != null:
		_animate_clips(unit, rig, data, pose, walking)
		return
	var phase: float = data["phase"] + _time * 11.0
	var legs: Array = rig["legs"]
	var arms: Array = rig["arms"]
	var body: Node3D = rig["body"]
	match rig["kind"]:
		"spider":
			for i in legs.size():
				legs[i].rotation.y = sin(phase + i * 1.3) * (0.35 if walking else 0.05)
		"quadruped":
			for i in legs.size():
				legs[i].rotation.x = sin(phase + (PI if i == 1 or i == 2 else 0.0)) * (0.6 if walking else 0.0)
		_:
			for i in legs.size():
				legs[i].rotation.x = sin(phase + i * PI) * (0.7 if walking else 0.0)
			for i in arms.size():
				arms[i].rotation.x = -sin(phase + i * PI) * (0.6 if walking else 0.05 * sin(_time * 2.0 + i))
	# Respiration : le corps monte et descend un peu.
	var bob := 0.012 * sin(_time * 2.5 + data["phase"])
	body.position.y = (0.45 if rig["kind"] == "bat" else 0.0) + bob + (0.03 * absf(sin(phase)) if walking else 0.0)
	# L'attaque : le bras droit frappe (ou tout le corps bondit, pour les bêtes).
	var attack := unit.attack_progress()
	if attack > 0.0:
		var swing := sin((1.0 - attack) * PI)
		if arms.size() >= 2:
			arms[1].rotation.x = -2.2 * swing
		else:
			body.position.z = 0.15 * swing
	else:
		body.position.z = 0.0
	for i in rig["wings"].size():
		var side := -1.0 if i == 0 else 1.0
		var speed := 16.0 if rig["kind"] == "bat" else 5.0
		rig["wings"][i].rotation.z = sin(_time * speed + data["phase"]) * 0.6 * side
	if rig["tail"] != null:
		rig["tail"].rotation.y = sin(_time * 4.0 + data["phase"]) * 0.4
	_animate_pose(rig, data, "" if walking and pose != "tipsy" else pose, attack)


## Les bipèdes à squelette (modèles Blender, tools/blender/clips.py) : on choisit
## le clip selon ce que fait l'unité. Les boucles démarrent à un moment au hasard
## (« phase ») pour que deux créatures ne bougent pas en même temps ; le coup est
## calé sur sa progression.
func _animate_clips(unit: Unit, rig: Dictionary, data: Dictionary, pose: String, walking: bool) -> void:
	var player: AnimationPlayer = rig["anim"]
	var attack := unit.attack_progress()
	var clip := "idle"
	if attack > 0.0:
		clip = "attack"
	elif data.get("lying", false):
		clip = "lie"
	elif walking:
		clip = "walk_tipsy" if pose == "tipsy" else "walk"
	elif pose != "":
		clip = pose
	if not player.has_animation(clip):
		clip = "idle"
	_show_held(data, "" if walking and pose != "tipsy" else pose)
	if data.get("clip", "") != clip:
		data["clip"] = clip
		player.play(clip, 0.05 if clip == "attack" else 0.25)
		if clip != "attack":
			player.seek(fmod(data["phase"], TAU) / TAU * player.current_animation_length)
	if clip == "attack":
		player.seek((1.0 - attack) * player.current_animation_length, true)


## Les objets tenus : seulement pendant l'activité qui va avec.
func _show_held(data: Dictionary, pose: String) -> void:
	var held: Dictionary = data["held"]
	if data["shown"] != pose:
		data["shown"] = pose
		for key: String in held:
			held[key].visible = key == pose


## Les poses des créatures selon leur activité (voir Creature.pose) : elles dorment
## allongées, mangent, trinquent, forgent, prient à genoux, montent la garde,
## méditent en lévitation... Le temps est décalé pour chaque créature (« phase »).
func _animate_pose(rig: Dictionary, data: Dictionary, pose: String, attack: float) -> void:
	var body: Node3D = rig["body"]
	var arms: Array = rig["arms"]
	var legs: Array = rig["legs"]
	var head: Node3D = data["head"]
	var t: float = _time + data["phase"]
	# On repart de la pose normale (sauf ce que _animate vient de régler).
	body.rotation = Vector3.ZERO
	for arm: Node3D in arms:
		arm.rotation.z = 0.0
		arm.rotation.y = 0.0
	if head != null:
		head.rotation = Vector3.ZERO
	_show_held(data, pose)
	var humanoid: bool = rig["kind"] == "humanoid" and arms.size() >= 2
	if not humanoid:
		# Les bêtes : elles se tassent pour dormir, et c'est tout.
		if pose == "sleep" or pose == "lie":
			body.position.y -= 0.06
			body.scale = Vector3(1.0, 0.85 + 0.03 * sin(t * 1.5), 1.0)
		else:
			body.scale = Vector3.ONE
		return
	if attack > 0.0:
		return # En plein coup : on ne touche à rien.
	match pose:
		"sleep", "lie":
			# Bras le long du corps, souffle lent (l'allongement est réglé dans _show_unit).
			for arm: Node3D in arms:
				arm.rotation.x = 0.1
			for leg: Node3D in legs:
				leg.rotation.x = 0.0
			body.position.y = 0.015 * sin(t * 1.2)
			if head != null:
				head.rotation.y = 0.3 * sin(t * 0.2) # Elle tourne la tête dans son sommeil.
		"eat":
			arms[0].rotation.x = -2.3 + 0.35 * maxf(0.0, sin(t * 7.0))
			arms[1].rotation.x = -0.6
			if head != null:
				head.rotation.x = 0.08 * sin(t * 14.0) # Elle mâche.
		"drink":
			# Elle porte la chope à sa bouche, renverse la tête, puis la repose en se balançant.
			var gulp := fmod(t, 3.2) < 1.8
			arms[0].rotation.x = -2.6 if gulp else -1.2
			arms[0].rotation.z = -0.25
			arms[1].rotation.x = -0.3 + 0.15 * sin(t * 3.0)
			if head != null:
				head.rotation.x = -0.45 if gulp else 0.05
			body.rotation.z = 0.06 * sin(t * 1.7)
		"study":
			arms[0].rotation.x = -1.1
			arms[1].rotation.x = -1.0 + (0.5 if fmod(t, 4.0) < 0.3 else 0.0) # Elle tourne une page.
			arms[0].rotation.z = 0.35
			arms[1].rotation.z = -0.35
			if head != null:
				head.rotation.x = 0.35 + 0.05 * sin(t * 0.8)
		"hammer", "coin":
			# Lever lentement, frapper d'un coup sec (deux mains en alternance pour la monnaie).
			var speed := 1.4 if pose == "hammer" else 2.2
			var k := fmod(t * speed, 1.0)
			var lift := k / 0.75 if k < 0.75 else 1.0 - (k - 0.75) / 0.25
			arms[1].rotation.x = -0.3 - 2.3 * lift
			if pose == "coin":
				var k2 := fmod(t * speed + 0.5, 1.0)
				arms[0].rotation.x = -0.3 - 1.4 * (k2 / 0.75 if k2 < 0.75 else 1.0 - (k2 - 0.75) / 0.25)
			else:
				arms[0].rotation.x = -0.7
			body.rotation.x = 0.15 * lift
		"train":
			var k := fmod(t * 1.8, 1.0)
			var swing := sin(k * PI)
			arms[1].rotation.x = -2.4 * swing
			arms[0].rotation.x = -0.8
			body.position.z = 0.08 * swing
			body.rotation.y = 0.3 * sin(t * 1.8 * PI)
		"pray":
			# À genoux, les bras levés vers l'autel, le front qui s'incline.
			body.position.y = -0.13
			for leg: Node3D in legs:
				leg.rotation.x = 1.45
			var raise := 0.5 + 0.5 * sin(t * 1.3)
			arms[0].rotation.x = -2.0 - 0.7 * raise
			arms[1].rotation.x = -2.0 - 0.7 * raise
			arms[0].rotation.z = -0.3
			arms[1].rotation.z = 0.3
			body.rotation.x = 0.25 * (1.0 - raise)
		"tend":
			# La Goule penchée sur un blessé, les mains qui recousent.
			body.rotation.x = 0.4
			arms[0].rotation.x = -1.3 + 0.2 * sin(t * 6.0)
			arms[1].rotation.x = -1.3 + 0.2 * sin(t * 6.0 + PI)
			if head != null:
				head.rotation.x = 0.3
		"torture":
			# Un grand coup de fouet toutes les 1,6 s.
			var k := fmod(t / 1.6, 1.0)
			var lash := (k / 0.7) if k < 0.7 else 1.0 - (k - 0.7) / 0.3
			arms[1].rotation.x = -0.4 - 2.6 * lash
			arms[1].rotation.z = 0.4 * lash
			arms[0].rotation.x = -0.4
			body.rotation.y = -0.3 * lash
		"guard":
			# Droite comme une lance, l'arme levée ; elle tourne la tête (et le corps, _show_unit).
			arms[1].rotation.x = -0.9
			arms[0].rotation.x = 0.05
			for leg: Node3D in legs:
				leg.rotation.x = 0.0
			if head != null:
				head.rotation.y = 0.5 * sin(t * 1.1)
		"meditate":
			# En lévitation au-dessus du puits, jambes croisées, paumes ouvertes.
			body.position.y = 0.1 + 0.05 * sin(t * 1.6)
			for i in legs.size():
				legs[i].rotation.x = -1.4
				legs[i].rotation.z = 0.5 * (1.0 if i == 0 else -1.0)
			arms[0].rotation.z = -0.9 - 0.1 * sin(t * 1.6)
			arms[1].rotation.z = 0.9 + 0.1 * sin(t * 1.6)
			arms[0].rotation.x = -0.4
			arms[1].rotation.x = -0.4
			body.rotation.y = 0.3 * sin(t * 0.4)
		"cast":
			# Les bras levés au-dessus des sarcophages, qui ondulent.
			arms[0].rotation.x = -2.5 + 0.35 * sin(t * 2.4)
			arms[1].rotation.x = -2.5 + 0.35 * sin(t * 2.4 + PI)
			arms[0].rotation.z = -0.4
			arms[1].rotation.z = 0.4
			body.position.y = 0.02 * sin(t * 4.0)
			if head != null:
				head.rotation.x = -0.25
		"tipsy":
			# Elle titube : le corps penche d'un côté puis de l'autre, la tête dodeline.
			body.rotation.z = 0.18 * sin(t * 2.6)
			body.rotation.x = 0.06 * sin(t * 1.3)
			arms[0].rotation.z = -0.4 * absf(sin(t * 2.6))
			if head != null:
				head.rotation.z = 0.25 * sin(t * 1.7)
	if pose != "meditate":
		for leg: Node3D in legs:
			leg.rotation.z = 0.0


# ---------------------------------------------------------------------------
# Construction de la carte en 3D
# ---------------------------------------------------------------------------

## (Appelée des milliers de fois par reconstruction : on lit map.tiles directement.)
func _is_wall(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= DungeonMap.WIDTH or cell.y >= DungeonMap.HEIGHT:
		return true
	var tile := map.tiles[cell.y * DungeonMap.WIDTH + cell.x]
	return tile == DungeonMap.Tile.EARTH or tile == DungeonMap.Tile.GOLD or tile == DungeonMap.Tile.ROCK \
			or tile == DungeonMap.Tile.GEM


## Reconstruit le sol, les murs et les objets. La carte est découpée en morceaux
## de 8 x 8 cases : chaque morceau n'est éclairé que par les lumières proches
## (les téléphones limitent le nombre de lumières par objet). Seuls les morceaux
## dont le contenu a changé sont refaits (un coup de pioche ne refait qu'un morceau).
func _rebuild() -> void:
	_dirty = false
	_rebuild_timer = REBUILD_DELAY
	var codes := _geometry_codes()
	var index := 0
	for cy in range(0, DungeonMap.HEIGHT, CHUNK):
		for cx in range(0, DungeonMap.WIDTH, CHUNK):
			var key := _chunk_key(codes, cx, cy)
			if index < _chunks.size() and _chunk_keys[index] == key:
				index += 1
				continue
			var mesh := _build_chunk_mesh(cx, cy)
			if index < _chunks.size():
				_chunks[index].mesh = mesh
				_chunk_keys[index] = key
			else:
				var chunk := MeshInstance3D.new()
				chunk.mesh = mesh
				add_child(chunk)
				_chunks.append(chunk)
				_chunk_keys.append(key)
			index += 1
	_rebuild_props()


func _build_chunk_mesh(cx: int, cy: int) -> ArrayMesh:
	var tools := {}
	for y in range(cy, mini(cy + CHUNK, DungeonMap.HEIGHT)):
		for x in range(cx, mini(cx + CHUNK, DungeonMap.WIDTH)):
			_add_cell(tools, Vector2i(x, y))
	var mesh := ArrayMesh.new()
	for key: String in tools:
		var st: SurfaceTool = tools[key][0]
		var before := mesh.get_surface_count()
		st.commit(mesh)
		if mesh.get_surface_count() > before: # Rien de dessiné : pas de surface.
			mesh.surface_set_material(mesh.get_surface_count() - 1, tools[key][1])
	return mesh


## Ce que _add_cell lit d'une case, résumé en un nombre (une case par élément,
## dans l'ordre de map.tiles) : la tuile, les coups de pioche, la salle, le territoire,
## le chantier de salle, la Rune, la décoration. On parcourt les dictionnaires de la
## carte plutôt que toutes les cases : c'est bien plus rapide.
func _geometry_codes() -> PackedInt64Array:
	var codes := PackedInt64Array()
	codes.resize(map.tiles.size())
	for i in map.tiles.size():
		codes[i] = map.tiles[i]
	for cell: Vector2i in map.damage:
		if map.is_inside(cell):
			codes[_index(cell)] |= clampi(int(map.damage[cell]), 0, 1023) << 4
	for cell: Vector2i in map.rooms:
		if map.is_inside(cell):
			codes[_index(cell)] |= (int(map.rooms[cell]) + 1) << 14
	for cell: Vector2i in map.claimed:
		if map.is_inside(cell):
			codes[_index(cell)] |= 1 << 20
	for cell: Vector2i in map.rival_claimed:
		if map.is_inside(cell):
			codes[_index(cell)] |= 1 << 21
	for cell: Vector2i in map.construction:
		var site: Dictionary = map.construction[cell]
		if map.is_inside(cell) and site.get("kind") == "room":
			codes[_index(cell)] |= (int(site["type"]) + 1) << 22
	for cell: Vector2i in map.defenses:
		if map.is_inside(cell) and map.defenses[cell].get("type", -1) == Defenses.Type.RUNE:
			codes[_index(cell)] |= 1 << 28
	for cell: Vector2i in map.decorations:
		if not map.is_inside(cell):
			continue
		var deco: Dictionary = map.decorations[cell]
		var side: Variant = deco.get("side")
		var side_code: int = (side.x + 1) * 3 + side.y + 1 if side is Vector2i else 9
		var kind := DungeonMap.DECORATION_KINDS.find(deco.get("kind", "")) + 1
		codes[_index(cell)] |= (kind * 16 + side_code + 1) << 29
	return codes


static func _index(cell: Vector2i) -> int:
	return cell.y * DungeonMap.WIDTH + cell.x


## L'empreinte d'un morceau : les codes de ses cases et de la bordure d'une case
## autour (les murs regardent leurs voisines). Deux empreintes égales donnent la
## même géométrie (les cases hors de la carte ne changent jamais).
func _chunk_key(codes: PackedInt64Array, cx: int, cy: int) -> int:
	var values := PackedInt64Array()
	var x0 := maxi(cx - 1, 0)
	var x1 := mini(cx + CHUNK + 1, DungeonMap.WIDTH)
	for y in range(maxi(cy - 1, 0), mini(cy + CHUNK + 1, DungeonMap.HEIGHT)):
		values.append_array(codes.slice(y * DungeonMap.WIDTH + x0, y * DungeonMap.WIDTH + x1))
	return hash(values)


## Le matériau de la lave : il brille tout seul (émission), même dans le noir.
func _lava_tool(tools: Dictionary) -> SurfaceTool:
	if not tools.has("lava"):
		if not _materials.has("lava"):
			var material := StandardMaterial3D.new()
			material.albedo_texture = Art.FLOOR[0]
			material.albedo_color = Color(1.0, 0.45, 0.12)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.emission_enabled = true
			material.emission = Color(1.0, 0.32, 0.05)
			material.emission_energy_multiplier = 1.6
			material.emission_texture = Art.FLOOR[0]
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_materials["lava"] = material
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools["lava"] = [st, _materials["lava"]]
	return tools["lava"][0]


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
		# Les images HD (pierre taillée, pavés) sont lissées ; le pixel art reste net.
		if texture.get_width() > 32:
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		else:
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.roughness = 1.0
		# Les pavés du sol luisent un peu : les torches et les sorts s'y reflètent
		# (un simple reflet spéculaire, gratuit sur téléphone ; coupé sans éclairage).
		if Sound.lighting_enabled and (texture in COBBLES or texture == FLOOR_STONE):
			material.roughness = 0.5
			material.metallic_specular = 0.65
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if transparent:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_materials[key] = material
	return _materials[key]


## Un carré texturé : a = coin haut-gauche de l'image, b = haut-droit, c = bas-droit, d = bas-gauche.
## « uv » : la part de l'image couverte (1 x 1 = l'image entière).
## (Deux triangles a-b-c et a-c-d ; la normale reste la même pour les 6 sommets.)
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
		uv := Vector2.ONE) -> void:
	st.set_normal(normal)
	st.set_uv(Vector2.ZERO)
	st.add_vertex(a)
	st.set_uv(Vector2(uv.x, 0.0))
	st.add_vertex(b)
	st.set_uv(uv)
	st.add_vertex(c)
	st.set_uv(Vector2.ZERO)
	st.add_vertex(a)
	st.set_uv(uv)
	st.add_vertex(c)
	st.set_uv(Vector2(0.0, uv.y))
	st.add_vertex(d)


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
	elif tile == DungeonMap.Tile.GOLD or tile == DungeonMap.Tile.GEM:
		images = Art.GOLD
	var texture: Texture2D = Art.pick(images, cell)
	# Teinte : plus sombre si la case est entamée par les pioches.
	# (Les cases à creuser sont signalées par une pioche, voir _update_dig_icons.)
	var tint := Color.WHITE
	if tile == DungeonMap.Tile.GEM:
		tint = GEM_TINT # Une gemme : le filon devient bleu-violet, bien visible.
	if map.damage.has(cell) and DungeonMap.DIG_HITS.has(tile):
		tint = tint.darkened(0.5 * float(map.damage[cell]) / DungeonMap.DIG_HITS[tile])
	var st := _tool(tools, texture, tint)
	# Les murs de ton territoire sont en PIERRE TAILLÉE (ceux qui bordent un sol
	# revendiqué ou une salle) ; le reste est de la roche brute. Les filons d'or
	# gardent leur image, pour qu'on les repère.
	var reinforced := tile != DungeonMap.Tile.GOLD and tile != DungeonMap.Tile.GEM and _borders_territory(cell)
	var top_texture: Texture2D = WALL_TOP if reinforced else texture
	# Le dessus des murs est un peu plus sombre que le sol : on voit mieux le relief.
	_flat(_tool(tools, top_texture, tint.darkened(TOP_DARKEN)), cell, WALL_HEIGHT)
	for direction in DungeonMap.DIRECTIONS:
		var neighbour: Vector2i = cell + direction
		if _is_wall(neighbour):
			continue # Face cachée par le bloc voisin : inutile de la dessiner.
		var face_tool := st
		if reinforced and _is_territory(neighbour):
			face_tool = _tool(tools, WALL_STONE, tint)
			_rampart(_tool(tools, WALL_STONE, tint.darkened(0.15)), cell, direction)
		_side(face_tool, cell, direction)
		# Un tableau ou une tapisserie accroché sur cette face, vu depuis la case voisine ?
		var deco: Dictionary = map.decorations.get(neighbour, {})
		if deco.get("side") == -direction:
			var kind: String = deco["kind"]
			var low := 0.4 if kind == "painting" else 0.15
			_side(_tool(tools, Art.DECORATIONS[kind], Color.WHITE, true), cell, direction, 0.2, 0.8,
					low, WALL_HEIGHT - 0.12, DECORATION_OFFSET)


## Les murs de ton territoire, comme des remparts : une plinthe en bas, une
## corniche en haut et deux merlons (créneaux) sur le bord, côté « direction ».
func _rampart(st: SurfaceTool, cell: Vector2i, direction: Vector2i) -> void:
	var normal := Vector3(direction.x, 0, direction.y)
	var right := Vector3.UP.cross(normal)
	var center := Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)
	_box(st, center + normal * 0.52 + Vector3.UP * 0.07, right, normal, Vector3(1.0, 0.14, 0.08))
	_box(st, center + normal * 0.5 + Vector3.UP * (WALL_HEIGHT - 0.05), right, normal, Vector3(1.0, 0.1, 0.14))
	for u in [-0.25, 0.25]:
		_box(st, center + normal * 0.38 + right * u + Vector3.UP * (WALL_HEIGHT + 0.12), right, normal,
				Vector3(0.3, 0.24, 0.22))


## Une boîte texturée (sans dessous) : « size » = largeur (le long de « right »),
## hauteur, épaisseur (le long de « normal »). La texture garde son échelle.
func _box(st: SurfaceTool, center: Vector3, right: Vector3, normal: Vector3, size: Vector3) -> void:
	var r := right * size.x * 0.5
	var u := Vector3.UP * size.y * 0.5
	var n := normal * size.z * 0.5
	var faces := [[n, r, size.x], [-n, -r, size.x], [r, -n, size.z], [-r, n, size.z]]
	for face: Array in faces:
		var out: Vector3 = face[0]
		var side: Vector3 = face[1]
		var width: float = face[2]
		_quad(st, center + out - side + u, center + out + side + u, center + out + side - u, center + out - side - u,
				out.normalized(), Vector2(width, size.y / WALL_HEIGHT))
	_quad(st, center + u - r - n, center + u + r - n, center + u + r + n, center + u - r + n, Vector3.UP,
			Vector2(size.x, size.z))


func _add_floor(tools: Dictionary, cell: Vector2i) -> void:
	var texture: Texture2D
	var tint := Color.WHITE
	if map.is_lava(cell):
		# La lave (un secret des profondeurs) : lumineuse, même dans le noir.
		_flat(_lava_tool(tools), cell, 0.0)
		return
	if map.rooms.has(cell):
		# Les salles ont un sol de dalles, à peine teinté de leur couleur.
		texture = FLOOR_STONE
		tint = Color.WHITE.lerp(Rooms.INFO[map.get_room(cell)]["color"].lightened(0.55), 0.4)
	elif map.rival_claimed.has(cell):
		texture = Art.pick(Art.CLAIMED, cell)
		tint = Color(0.6, 0.7, 1.0)
	elif map.claimed.has(cell):
		texture = COBBLES[(cell.x * 7 + cell.y * 13) % COBBLES.size()] # Les pavés de ton territoire.
	else:
		texture = Art.pick(Art.FLOOR, cell)
	_flat(_tool(tools, texture, tint), cell, 0.0)
	# Ce qui est posé à plat sur le sol, juste au-dessus pour ne pas clignoter.
	if map.construction.has(cell) and map.construction[cell]["kind"] == "room":
		_flat(_tool(tools, Art.ROOM_FLOORS[map.construction[cell]["type"]], Color(1, 1, 1, 0.5), true), cell, 0.005)
	if map.decorations.has(cell) and map.decorations[cell]["kind"] == "rug":
		_flat(_tool(tools, Art.DECORATIONS["rug"], Color.WHITE, true), cell, 0.01, 0.1)
	if map.defenses.has(cell) and map.defenses[cell]["type"] == Defenses.Type.RUNE:
		_flat(_tool(tools, Art.RUNE, Color.WHITE, true), cell, 0.01)


# ---------------------------------------------------------------------------
# Les objets (modèles en blocs)
# ---------------------------------------------------------------------------

## La liste des objets d'une case, sous forme de texte (« chest_2,torch »...).
## Si elle n'a pas changé depuis la dernière fois, on garde les modèles existants.
func _cell_signature(cell: Vector2i) -> String:
	var parts: Array[String] = []
	if map.get_tile(cell) == DungeonMap.Tile.ENTRANCE:
		parts.append("entrance")
	# Les objets de plusieurs cases (Trésor, Bibliothèque, Atelier, Entraînement,
	# Temple) : un seul modèle, posé sur la case d'origine de l'objet.
	var furniture_id: int = map.cell_furniture.get(cell, -1)
	var room := map.get_room(cell)
	if furniture_id >= 0 and room in MULTI_CELL_ROOMS:
		var item: Dictionary = map.furniture[furniture_id]
		if item["origin"] == cell:
			var size: Vector2i = item["size"]
			var extra := 0
			if room == Rooms.Type.TREASURY:
				var stored := 0
				for dy in size.y:
					for dx in size.x:
						stored += int(map.stored_gold.get(cell + Vector2i(dx, dy), 0))
				var fill := float(stored) / (Rooms.TREASURY_CAPACITY * size.x * size.y)
				extra = 0 if stored <= 0 else mini(3, 1 + int(fill * 3.0))
			elif room == Rooms.Type.CRYPT:
				# Les sarcophages occupés (les morts sont rangés dans l'ordre des Cryptes).
				var index := 0
				for other: int in map.furniture:
					if map.furniture[other]["room"] == Rooms.Type.CRYPT and other < furniture_id:
						index += 1
				extra = clampi(map.crypt_bodies.size() - index * Rules.CRYPT_SLOTS, 0, Rules.CRYPT_SLOTS)
			parts.append("furn_%d_%d_%d_%d" % [room, size.x, size.y, extra])
	elif furniture_id >= 0:
		match room:
			Rooms.Type.LAIR:
				parts.append("bed")
			Rooms.Type.FARM:
				if int(map.food.get(cell, 0)) > 0:
					parts.append("mushrooms_%d" % int(map.food[cell]))
			Rooms.Type.PRISON:
				parts.append("prison")
			Rooms.Type.GRAVEYARD:
				parts.append("tomb_full" if map.graves.has(cell) else "tomb_empty")
	if map.candelabras.has(cell):
		parts.append("candelabra")
	if map.torch_cells.has(cell) and not map.rooms.has(cell) and not map.defenses.has(cell):
		parts.append("wall_torch" if _wall_side(cell) != Vector2i.ZERO else "torch")
	elif map.claimed.has(cell) and not map.rooms.has(cell) and not map.defenses.has(cell) \
			and posmod(cell.x * 3 + cell.y * 5, 7) == 0 and _wall_side(cell) != Vector2i.ZERO \
			and maxi(absi(cell.x - map.heart_cell.x), absi(cell.y - map.heart_cell.y)) > 2:
		parts.append("banner") # Une bannière au trident, de temps en temps, le long des couloirs.
	if map.defenses.has(cell):
		var defense: Dictionary = map.defenses[cell]
		match int(defense["type"]):
			Defenses.Type.ALTAR:
				parts.append("sacrifice_altar")
			Defenses.Type.DOOR:
				parts.append("door")
			Defenses.Type.SPIKES:
				parts.append("spikes_up" if defense["flash"] > 0.0 else "spikes")
			Defenses.Type.BRAZIER:
				parts.append("brazier")
	if map.rival_braziers.has(cell):
		parts.append("brazier_rival")
	if map.ruins.has(cell):
		parts.append("ruin_" + String(map.ruins[cell])) # Colonne brisée ou pupitre au grimoire.
	if map.loose_gold.has(cell):
		parts.append("gold_%d" % clampi(int(map.loose_gold[cell]) / 40, 0, 4))
	if map.construction.has(cell):
		var site: Dictionary = map.construction[cell]
		if site.has("block"):
			# Une salle en chantier : un seul modèle (échafaudages), sur sa case d'origine.
			var block: Dictionary = map.blocks.get(site["block"], {})
			if not block.is_empty() and block["origin"] == cell:
				var step := clampi(int(map.block_progress(site["block"]) * 4.0), 0, 3)
				parts.append("build_%d_%d_%d_%d" % [block["room"], block["size"].x, block["size"].y, step])
		else:
			parts.append("site")
	return ",".join(parts)


## Une pioche flotte au-dessus de chaque case marquée « à creuser ».
func _update_dig_icons() -> void:
	for cell: Vector2i in _dig_icons.keys():
		if not map.marked.has(cell):
			_dig_icons[cell].queue_free()
			_dig_icons.erase(cell)
	for cell: Vector2i in map.marked:
		if _dig_icons.has(cell):
			continue
		var icon := Sprite3D.new()
		icon.texture = PICKAXE_ICON
		icon.pixel_size = 0.016
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		icon.shaded = false # Toujours bien visible, même dans le noir.
		icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		icon.position = Vector3(cell.x + 0.5, WALL_HEIGHT + 0.35, cell.y + 0.5)
		add_child(icon)
		_dig_icons[cell] = icon


func _rebuild_props() -> void:
	_update_dig_icons()
	var wanted_torches := {}
	var wanted_braziers := {} # case -> couleur du feu
	for y in DungeonMap.HEIGHT:
		for x in DungeonMap.WIDTH:
			var cell := Vector2i(x, y)
			var sig := "" if _is_wall(cell) else _cell_signature(cell)
			if sig != "":
				if sig.contains("torch"):
					wanted_torches[cell] = _wall_side(cell)
				if sig.contains("brazier_rival"):
					wanted_braziers[cell] = RIVAL_FIRE
				elif sig.contains("brazier"):
					wanted_braziers[cell] = HEART_FIRE
				if sig.contains("candelabra"):
					wanted_torches[cell] = map.candelabras[cell] # Le chandelier éclaire aussi.
			if map.is_lava(cell) and posmod(x + y * 2, 3) == 0:
				wanted_braziers[cell] = LAVA_GLOW # La lave éclaire la caverne (une lumière sur trois cases).
			if sig != "" and sig.contains("ruin_lectern"):
				wanted_braziers[cell] = RUIN_GLOW
			var old: Dictionary = _cell_props.get(cell, {})
			if old.get("sig", "") == sig:
				continue
			if old.has("node"):
				old["node"].queue_free()
			if sig == "":
				_cell_props.erase(cell)
				continue
			var holder := Node3D.new()
			holder.position = Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)
			add_child(holder)
			var anims := []
			for kind in sig.split(","):
				var model := VoxelModels.prop(kind)
				holder.add_child(model)
				anims.append(model.get_meta("anim"))
				if kind.begins_with("build_"):
					var build_parts := kind.split("_")
					model.position = Vector3((int(build_parts[2]) - 1) * 0.5, 0.0, (int(build_parts[3]) - 1) * 0.5)
				elif kind.begins_with("furn_"):
					# L'objet est centré sur son emprise (plusieurs cases).
					var parts := kind.split("_")
					model.position = Vector3((int(parts[2]) - 1) * 0.5, 0.0, (int(parts[3]) - 1) * 0.5)
					_add_furniture_light(model, int(parts[1]), Vector2i(int(parts[2]), int(parts[3])))
				elif kind == "door" or kind == "entrance":
					# Portes et entrées : dans l'axe du couloir.
					if _is_wall(cell + Vector2i.UP) and _is_wall(cell + Vector2i.DOWN):
						model.rotation.y = PI / 2
				elif kind == "candelabra":
					# Accroché au mur choisi par l'ouvrier.
					var wall: Vector2i = map.candelabras[cell]
					model.position = Vector3(wall.x, 0.0, wall.y) * 0.42
					model.rotation.y = atan2(-wall.x, -wall.y)
				elif kind == "wall_torch" or kind == "banner":
					# Accroché au mur voisin (le support part vers le mur).
					var side := _wall_side(cell)
					model.position = Vector3(side.x, 0.0, side.y) * 0.42
					model.rotation.y = atan2(-side.x, -side.y)
			_cell_props[cell] = {"sig": sig, "node": holder, "anims": anims}
	# Les lumières des braseros (rouge pour toi, violet pour le rival).
	for cell: Vector2i in _brazier_lights.keys():
		if wanted_braziers.get(cell) != _brazier_lights[cell].light_color:
			_brazier_lights[cell].queue_free()
			_brazier_lights.erase(cell)
	for cell: Vector2i in wanted_braziers:
		if not _brazier_lights.has(cell):
			_brazier_lights[cell] = _light(Vector3(cell.x + 0.5, 1.1, cell.y + 0.5), wanted_braziers[cell], 6.0, 1.6)
	# Les lumières des torches : on garde celles qui existent déjà.
	for cell: Vector2i in _torch_lights.keys():
		if not wanted_torches.has(cell):
			_torch_lights[cell].queue_free()
			_torch_lights.erase(cell)
	for cell: Vector2i in wanted_torches:
		if not _torch_lights.has(cell):
			var side: Vector2i = wanted_torches[cell]
			var at := Vector3(cell.x + 0.5 + side.x * 0.3, 1.2, cell.y + 0.5 + side.y * 0.3)
			_torch_lights[cell] = _light(at, TORCH_COLOR, 5.0, 1.1)


## Le mur le plus proche d'une case (pour y accrocher une torche), ou ZERO.
func _wall_side(cell: Vector2i) -> Vector2i:
	for direction in DungeonMap.DIRECTIONS:
		if _is_wall(cell + direction):
			return direction
	return Vector2i.ZERO


## Une case de ton territoire (sol revendiqué ou salle).
func _is_territory(cell: Vector2i) -> bool:
	return map.claimed.has(cell) or map.rooms.has(cell)


## Un mur qui borde ton territoire (il devient de la pierre taillée).
func _borders_territory(cell: Vector2i) -> bool:
	for direction in DungeonMap.DIRECTIONS:
		if _is_territory(cell + direction):
			return true
	return false


## Chaque grande salle baigne dans sa lumière, comme sur l'image de référence : l'or
## du Trésor, le vert du laboratoire (Bibliothèque) et du Temple, l'orange de la forge.
func _add_furniture_light(model: Node3D, room: int, size: Vector2i) -> void:
	var color := Color.BLACK
	var energy := 1.4
	match room:
		Rooms.Type.TREASURY:
			color = Color(1.0, 0.72, 0.25)
			energy = 1.2
		Rooms.Type.LIBRARY:
			color = Color(0.4, 1.0, 0.3)
			energy = 1.5
		Rooms.Type.WORKSHOP:
			color = Color(1.0, 0.45, 0.15)
			energy = 1.6
		Rooms.Type.TRAINING:
			color = Color(1.0, 0.7, 0.45)
			energy = 1.0
		Rooms.Type.TEMPLE:
			color = Color(0.45, 1.0, 0.3)
		Rooms.Type.TAVERN:
			color = Color(1.0, 0.6, 0.25) # Le feu de la cheminée.
			energy = 1.3
		Rooms.Type.INFIRMARY:
			color = Color(0.7, 1.0, 0.55) # Les onguents qui luisent.
			energy = 1.0
		Rooms.Type.MINT:
			color = Color(1.0, 0.55, 0.15) # Le four à fondre l'or.
			energy = 1.5
		Rooms.Type.TORTURE:
			color = Color(1.0, 0.25, 0.15) # Les braises rouges.
			energy = 1.3
		Rooms.Type.GUARDPOST:
			color = Color(1.0, 0.65, 0.3)
			energy = 1.1
		Rooms.Type.MANA_WELL:
			color = Color(0.3, 0.8, 1.0) # La mana bleue.
			energy = 1.8
		Rooms.Type.CRYPT:
			color = Color(0.65, 0.45, 1.0) # Les cierges et les âmes violettes.
			energy = 1.1
		_:
			return
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 3.5 + maxf(size.x, size.y)
	light.light_energy = energy
	light.position = Vector3(0, 1.0, 0)
	model.add_child(light)


## Le décor animé : flammes qui vacillent, mannequins qui se balancent, lueurs.
func _update_props() -> void:
	# Les pioches se balancent doucement.
	for cell: Vector2i in _dig_icons:
		var icon: Sprite3D = _dig_icons[cell]
		icon.position.y = WALL_HEIGHT + 0.35 + 0.06 * sin(_time * 3.0 + cell.x + cell.y)
	for cell: Vector2i in _cell_props:
		var anims: Array = _cell_props[cell]["anims"]
		if anims.is_empty() or not _on_screen(Vector3(cell.x + 0.5, 0.8, cell.y + 0.5), 2.5):
			continue # Hors de l'écran, les flammes peuvent attendre.
		var t := _time + cell.x * 1.3 + cell.y * 0.7
		for anim: Dictionary in anims:
			_animate_prop(anim, t)
	_animate_prop(_throne_anim, _time)


func _animate_prop(anim: Dictionary, t: float) -> void:
	if anim.has("flame"):
		anim["flame"].scale = Vector3.ONE * (1.0 + 0.18 * sin(t * 13.0) + 0.08 * sin(t * 31.0))
	if anim.has("flames"):
		for flame: Node3D in anim["flames"]:
			flame.scale.y = 1.0 + 0.4 * sin(t * 11.0 + flame.position.x * 9.0)
	if anim.has("sway"):
		anim["sway"].rotation.z = sin(t * 2.0) * 0.08
	if anim.has("sways"):
		for i in anim["sways"].size():
			anim["sways"][i].rotation.z = sin(t * 2.0 + i * 1.7) * 0.1
	if anim.has("wisp"):
		anim["wisp"].position.y = anim.get("wisp_y", 0.3) + 0.12 * sin(t * 2.0)
	if anim.has("glow"):
		anim["glow"].scale.x = 1.0 + 0.1 * sin(t * 6.0)


# ---------------------------------------------------------------------------
# Effets au sol : les cercles des explosions et des sorts (dungeon_map.gd, _effects)
# ---------------------------------------------------------------------------

func _update_effects() -> void:
	var effects: Array = map._effects
	while _effect_discs.size() < effects.size():
		var disc := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 1.0
		shape.bottom_radius = 1.0
		shape.height = 0.02
		shape.radial_segments = 24
		disc.mesh = shape
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc.material_override = material
		add_child(disc)
		_effect_discs.append(disc)
	for i in _effect_discs.size():
		var disc := _effect_discs[i]
		disc.visible = i < effects.size()
		if not disc.visible:
			continue
		var effect: Dictionary = effects[i]
		var progress: float = 1.0 - effect["time"] / DungeonMap.EFFECT_TIME
		var radius: float = effect["radius"] / TILE * (0.4 + 0.6 * progress)
		disc.position = to_3d(effect["position"], 0.03)
		disc.scale = Vector3(radius, 1.0, radius)
		var color: Color = effect["color"]
		color.a *= 1.0 - progress
		(disc.material_override as StandardMaterial3D).albedo_color = color


# ---------------------------------------------------------------------------
# Lumières, cœur et portail
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("0b0809")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Une ambiance chaude : pénombre brun-rouge, et un halo autour des flammes (glow).
	_environment.ambient_light_color = Color(0.55, 0.36, 0.3)
	# Sans « éclairage » (réglages), tout est bien éclairé. Avec, une pénombre plus
	# profonde, où chaque salle se détache dans sa propre lumière.
	_environment.ambient_light_energy = 0.24 if Sound.lighting_enabled else 1.4
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_exposure = 1.15
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.85
	_environment.glow_bloom = 0.12
	_environment.glow_hdr_threshold = 1.0
	# Une brume sombre qui noie le lointain.
	_environment.fog_enabled = Sound.lighting_enabled
	_environment.fog_light_color = Color(0.06, 0.035, 0.03)
	_environment.fog_density = 0.012
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 35, 0)
	sun.light_energy = 0.15
	sun.light_color = Color(0.75, 0.6, 0.6)
	add_child(sun)


## La lueur d'une entrée des héros (la seconde s'ouvre en cours de partie).
func add_entrance_light(cell: Vector2i) -> void:
	_light(to_3d(map.cell_to_world(cell), 1.2), Color(0.8, 0.85, 1.0), 4.0, 1.0)


func _light(at: Vector3, color: Color, light_range: float, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = energy
	add_child(light)
	return light


func _gem(color: Color, glow: Color, size := 1.0) -> MeshInstance3D:
	var gem := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.35 * size
	shape.height = 0.9 * size
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
	var heart_at := to_3d(map.cell_to_world(map.heart_cell))
	# La salle du trône (modèle Blender « throne ») : le cœur flotte devant la gueule
	# du démon sculpté. Sans le modèle, la gemme reste seule, comme avant.
	var throne := VoxelModels.prop("throne")
	throne.position = heart_at
	add_child(throne)
	_throne_anim = throne.get_meta("anim")
	var has_throne := throne.get_child_count() > 0
	if has_throne:
		_heart = _gem(Color("c62828"), Color("ff5252"), 0.6)
		_heart.position = heart_at + Vector3(0, 1.05, -0.3)
		for side in [-1.0, 1.0]: # Les bassins de lave.
			_light(heart_at + Vector3(1.55 * side, 0.4, -0.65), Color(1.0, 0.4, 0.12), 3.0, 1.2)
	else:
		_heart = _gem(Color("c62828"), Color("ff5252"))
		_heart.position = heart_at + Vector3(0, 0.75, 0)
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
	for gate in map.extra_entrances:
		add_entrance_light(gate)

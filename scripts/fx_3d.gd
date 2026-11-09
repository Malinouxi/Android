class_name Fx3D
extends Node3D
## LES EFFETS EN 3D : les sorts du maître (modèles Blender de assets/models/fx,
## voir tools/blender/spell_fx.py), le sol qui brûle, les envoûtements visibles
## sur les unités (toile, sanctuaire, possession) et le SANG des combats.
## Créé par view_3d.gd ; Fx (fx.gd) et main.gd l'appellent par Fx.spell(...).
##
## Pensé pour un téléphone moyen de gamme :
##   - les modèles sont légers (quelques centaines de faces) et ÉMISSIFS ;
##   - les lumières dynamiques sont limitées à MAX_LIGHTS à la fois (les plus
##     anciennes s'éteignent), et coupées si « Éclairage : non » ;
##   - au plus MAX_FIRE_LIGHTS feux éclairent la scène ;
##   - le sang est fait de simples carrés texturés (60 au plus), mis à jour
##     seulement quand la liste change, et pâlis 4 fois par seconde.

const FX_MODELS := "res://assets/models/fx/%s.glb"
const MAX_LIGHTS := 4
const MAX_FIRE_LIGHTS := 2
const TILE := 32.0

var map: DungeonMap
var _scenes := {}
## Les lumières passagères (sorts, explosions), de la plus ancienne à la plus récente.
var _lights: Array = [] # (Sans type : une lumière éteinte est déjà libérée.)
## Feux au sol : un modèle « flames » par feu de map.fires (réutilisés).
var _fire_models: Array[Node3D] = []
var _fire_lights: Array[OmniLight3D] = []
## Envoûtements visibles : clé "<id de l'unité>|<genre>" -> modèle.
var _status := {}
var _status_timer := 0.0
## Le sang : un carré par tache (reconstruits quand map.blood_version change).
var _blood_nodes: Array[MeshInstance3D] = []
var _blood_version := -1
var _blood_timer := 0.0
var _blood_materials := {}
var _time := 0.0


func setup(dungeon_map: DungeonMap) -> void:
	map = dungeon_map


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

static func to_3d(map_position: Vector2, height := 0.0) -> Vector3:
	return Vector3(map_position.x / TILE, height, map_position.y / TILE)


## Une copie d'un modèle d'effet, teinte de « color » (émissive, transparente si
## alpha < 1). Chaque copie a ses propres matériaux, pour s'effacer seule.
func model(model_name: String, color := Color.WHITE, glow := 2.0) -> Node3D:
	var path := FX_MODELS % model_name
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _scenes[path]
	var root: Node3D = scene.instantiate() if scene != null else Node3D.new()
	var materials: Array[StandardMaterial3D] = []
	_tint(root, color, glow, materials)
	root.set_meta("materials", materials)
	root.set_meta("glow", glow)
	add_child(root)
	return root


func _tint(node: Node, color: Color, glow: float, materials: Array[StandardMaterial3D]) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		for i in mesh.mesh.get_surface_count():
			var old := mesh.get_active_material(i) as StandardMaterial3D
			var copy: StandardMaterial3D = old.duplicate() if old != null else StandardMaterial3D.new()
			if color != Color.WHITE:
				# Les parties claires prennent la couleur du sort ; les sombres restent sombres.
				var base := copy.albedo_color
				var light := (base.r + base.g + base.b) / 3.0
				copy.albedo_color = Color(color.r * light, color.g * light, color.b * light)
				if copy.emission_enabled:
					copy.emission = Color(color.r, color.g, color.b)
			if copy.emission_enabled:
				copy.emission_energy_multiplier = glow
			# Opaque tant qu'il n'a pas besoin de pâlir (plus net, et moins coûteux).
			copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
			copy.albedo_color.a = color.a
			copy.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(i, copy)
			materials.append(copy)
	for child in node.get_children():
		_tint(child, color, glow, materials)


## Fait pâlir un modèle jusqu'à l'effacer (alpha 0), en « duration » secondes, puis le supprime.
func fade_out(root: Node3D, duration: float, delay := 0.0) -> void:
	var tween := root.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(func(alpha: float) -> void: _set_alpha(root, alpha), _alpha(root), 0.0, duration)
	tween.tween_callback(root.queue_free)


func _alpha(root: Node3D) -> float:
	var materials: Array = root.get_meta("materials", [])
	return (materials[0] as StandardMaterial3D).albedo_color.a if not materials.is_empty() else 1.0


func _set_alpha(root: Node3D, alpha: float) -> void:
	if not is_instance_valid(root):
		return
	for material: StandardMaterial3D in root.get_meta("materials", []):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = alpha
		if material.emission_enabled:
			material.emission_energy_multiplier = maxf(0.0, alpha) * float(root.get_meta("glow", 2.0))


## Une lumière passagère, si l'éclairage est activé. Au plus MAX_LIGHTS à la fois :
## au-delà, la plus ancienne s'éteint (un téléphone n'aime pas les lumières en trop).
func flash(at: Vector3, color: Color, light_range: float, duration: float, energy := 3.0) -> void:
	if not Sound.lighting_enabled:
		return
	_lights = _lights.filter(func(l) -> bool: return is_instance_valid(l))
	while _lights.size() >= MAX_LIGHTS:
		var oldest = _lights.pop_front()
		oldest.queue_free()
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = energy
	light.shadow_enabled = false
	add_child(light)
	_lights.append(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration)
	tween.tween_callback(light.queue_free)


# ---------------------------------------------------------------------------
# Les sorts
# ---------------------------------------------------------------------------

## L'effet d'un sort lancé à « map_position » (en pixels de la carte).
func spell(type: int, map_position: Vector2) -> void:
	var info: Dictionary = Spells.INFO[type]
	var color: Color = info["color"]
	color.a = 1.0
	var radius: float = info.get("radius", 32.0) / TILE
	var at := to_3d(map_position)
	match type:
		Spells.Type.WEB:
			var web := model("web")
			web.position = at + Vector3(0, 0.02, 0)
			web.scale = Vector3.ONE * 0.2
			web.rotation.y = randf() * TAU
			var tween := web.create_tween()
			tween.tween_property(web, "scale", Vector3.ONE * radius, 0.25).set_trans(Tween.TRANS_BACK)
			fade_out(web, 0.8, info["duration"] - 0.8)
		Spells.Type.TERROR:
			var ghost := model("ghost", Color(0.8, 0.7, 1.0))
			ghost.position = at
			ghost.scale = Vector3.ONE * 0.3
			var tween := ghost.create_tween().set_parallel()
			tween.tween_property(ghost, "scale", Vector3.ONE * 1.3, 0.6).set_trans(Tween.TRANS_BACK)
			tween.tween_property(ghost, "position:y", 1.2, 1.6)
			tween.tween_property(ghost, "rotation:y", PI, 1.6)
			fade_out(ghost, 0.9, 0.7)
			_circle(at, color, radius, 1.2)
			flash(at + Vector3(0, 1.2, 0), Color(0.6, 0.3, 1.0), 4.0, 0.8)
		Spells.Type.COLLAPSE:
			var rocks := model("rocks")
			rocks.position = at
			for i in rocks.get_child_count():
				var rock := rocks.get_child(i) as Node3D
				if rock == null or not String(rock.name).begins_with("rock"):
					continue
				var ground := rock.position.y
				rock.position.y = 3.0 + i * 0.35
				var tween := rock.create_tween()
				tween.tween_interval(i * 0.05)
				tween.tween_property(rock, "position:y", ground, 0.35 + i * 0.04).set_trans(Tween.TRANS_QUAD) \
						.set_ease(Tween.EASE_IN)
				tween.tween_property(rock, "position:y", ground + 0.12, 0.08)
				tween.tween_property(rock, "position:y", ground, 0.08)
			fade_out(rocks, 0.5, 1.4)
		Spells.Type.SANCTUARY:
			var dome := model("dome", Color(0.75, 0.6, 1.0, 0.35), 1.2)
			dome.position = at
			dome.scale = Vector3(0.2, 0.1, 0.2)
			var tween := dome.create_tween()
			tween.tween_property(dome, "scale", Vector3(radius, radius * 0.6, radius), 0.4).set_trans(Tween.TRANS_BACK)
			fade_out(dome, 0.8, 0.6)
			_circle(at, color, radius, 1.4)
			flash(at + Vector3(0, 1.0, 0), Color(0.75, 0.6, 1.0), 5.0, 0.8)
		Spells.Type.EYE:
			var eye := model("eye", Color.WHITE, 0.9)
			eye.position = at + Vector3(0, 0.2, 0)
			eye.scale = Vector3.ONE * 0.1
			var tween := eye.create_tween()
			tween.tween_property(eye, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
			tween.tween_property(eye, "rotation:y", TAU, 2.2)
			fade_out(eye, 0.6, 2.3)
			flash(at + Vector3(0, 1.5, 0), Color(1.0, 0.8, 0.3), 5.0, 1.5)
		Spells.Type.RAISE:
			raise_hand(map_position)
			_circle(at, color, 1.0, 1.2)
		Spells.Type.FIRESTORM:
			flash(at + Vector3(0, 0.8, 0), Color(1.0, 0.45, 0.1), 4.0, 0.6, 4.0)
			_circle(at, color, radius, 0.8)
		Spells.Type.LIGHTNING:
			_circle(at, color, radius * 1.4, 0.6)
		_:
			# Les autres sorts : un cercle magique de leur couleur, qui tourne et s'efface.
			_circle(at, color, maxf(radius, 0.7), 1.2)
			flash(at + Vector3(0, 0.8, 0), color, 3.5, 0.6)


## Un cercle magique au sol qui grandit, tourne et s'efface.
func _circle(at: Vector3, color: Color, radius: float, duration: float) -> void:
	var circle := model("rune_circle", color, 2.5)
	circle.position = at + Vector3(0, 0.03, 0)
	circle.scale = Vector3.ONE * radius * 0.3
	var tween := circle.create_tween().set_parallel()
	tween.tween_property(circle, "scale", Vector3.ONE * radius, duration * 0.35).set_trans(Tween.TRANS_BACK)
	tween.tween_property(circle, "rotation:y", PI * 0.75, duration)
	fade_out(circle, duration * 0.5, duration * 0.5)


## La foudre tombe sur un point (l'Éclair, une Porte électrifiée...).
func bolt(map_position: Vector2) -> void:
	var at := to_3d(map_position)
	var strike := model("bolt", Color(0.75, 0.9, 1.0), 4.0)
	strike.position = at
	strike.rotation.y = randf() * TAU
	strike.scale = Vector3(1.0, 0.05, 1.0)
	var tween := strike.create_tween()
	tween.tween_property(strike, "scale", Vector3.ONE, 0.06)
	tween.tween_callback(func() -> void: strike.visible = false).set_delay(0.06)
	tween.tween_callback(func() -> void: strike.visible = true).set_delay(0.05)
	fade_out(strike, 0.25, 0.12)
	flash(at + Vector3(0, 1.5, 0), Color(0.65, 0.85, 1.0), 5.0, 0.35, 5.0)


## Une main squelettique sort de terre (Relever les morts).
func raise_hand(map_position: Vector2) -> void:
	var hand := model("hand")
	hand.position = to_3d(map_position)
	var arm := hand.get_node_or_null("hand") as Node3D
	if arm != null:
		arm.position.y = -0.7
		var tween := arm.create_tween()
		tween.tween_property(arm, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(arm, "rotation:y", 0.6, 0.4)
	fade_out(hand, 0.6, 1.6)
	flash(hand.position + Vector3(0, 0.6, 0), Color(0.5, 1.0, 0.3), 3.5, 1.0)


# ---------------------------------------------------------------------------
# Chaque image : feux, envoûtements, sang
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if map == null:
		return
	_time += delta
	_update_fires()
	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = 0.15
		_update_status()
	_animate_status()
	_blood_timer -= delta
	if map.blood_version != _blood_version:
		_rebuild_blood()
	elif _blood_timer <= 0.0:
		_blood_timer = 0.25
		_fade_blood()


## Le sol qui brûle (Brasier, Rune de feu, Traînée de feu) : des flammes Blender.
func _update_fires() -> void:
	var fires: Array = map.fires
	while _fire_models.size() < fires.size():
		var flames := model("flames", Color.WHITE, 1.3)
		_fire_models.append(flames)
	for i in _fire_models.size():
		var flames := _fire_models[i]
		flames.visible = i < fires.size()
		if not flames.visible:
			continue
		var fire: Dictionary = fires[i]
		var size := clampf(float(fire["radius"]) / TILE, 0.4, 2.5)
		var life := clampf(float(fire["time"]) / 1.0, 0.0, 1.0) # Elles retombent la dernière seconde.
		flames.position = to_3d(fire["position"])
		for child in flames.get_children():
			var flame := child as Node3D
			if flame != null and String(flame.name).begins_with("flame"):
				flame.scale = Vector3(1, 1.0 + 0.35 * sin(_time * 11.0 + flame.position.x * 9.0), 1) * life
		flames.scale = Vector3(size, size, size)
	# Les feux qui éclairent (les premiers seulement).
	if not Sound.lighting_enabled:
		return
	while _fire_lights.size() < MAX_FIRE_LIGHTS:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.15)
		light.omni_range = 4.0
		add_child(light)
		_fire_lights.append(light)
	for i in _fire_lights.size():
		var light := _fire_lights[i]
		light.visible = i < fires.size()
		if light.visible:
			light.position = to_3d(fires[i]["position"], 0.8)
			light.light_energy = 1.6 + 0.4 * sin(_time * 13.0 + i)


## Les envoûtements portés par les unités : une toile sous les héros englués, un
## petit dôme autour des unités protégées, un cercle rouge sous la créature possédée.
func _update_status() -> void:
	var wanted := {}
	for node in get_tree().get_nodes_in_group("heroes"):
		var unit := node as Unit
		if unit != null and unit.is_webbed():
			wanted["%d|web" % unit.get_instance_id()] = unit
	for node in get_tree().get_nodes_in_group("dungeon"):
		var unit := node as Unit
		if unit == null:
			continue
		if unit.is_warded():
			wanted["%d|ward" % unit.get_instance_id()] = unit
		if unit is Creature and (unit as Creature).is_possessed():
			wanted["%d|possessed" % unit.get_instance_id()] = unit
	for key: String in _status.keys():
		if not wanted.has(key):
			var old: Node3D = _status[key]["node"]
			_status.erase(key)
			if is_instance_valid(old):
				fade_out(old, 0.3)
	for key: String in wanted:
		if _status.has(key):
			continue
		var kind := key.get_slice("|", 1)
		var node: Node3D
		match kind:
			"web":
				node = model("web")
				node.scale = Vector3.ONE * 0.45
			"ward":
				node = model("dome", Color(0.75, 0.6, 1.0, 0.3), 1.0)
				node.scale = Vector3(0.45, 0.55, 0.45)
			_:
				node = model("rune_circle", Color(1.0, 0.15, 0.25), 2.5)
				node.scale = Vector3.ONE * 0.5
		_status[key] = {"node": node, "unit": wanted[key], "kind": kind}


func _animate_status() -> void:
	for key: String in _status:
		var entry: Dictionary = _status[key]
		var node: Node3D = entry["node"]
		var unit = entry["unit"]
		if not is_instance_valid(unit) or not is_instance_valid(node):
			continue
		node.position = to_3d((unit as Unit).position, 0.03)
		if entry["kind"] == "possessed":
			node.rotation.y = _time * 2.0
		elif entry["kind"] == "ward":
			node.scale.y = 0.55 + 0.04 * sin(_time * 4.0)


# --- Le sang ---------------------------------------------------------------------

func _blood_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Du sang frais, luisant : les torches s'y reflètent (simple reflet spéculaire).
	material.roughness = 0.22 if Sound.lighting_enabled else 1.0
	material.metallic_specular = 0.8
	return material


## La liste a changé : on recrée les carrés (au plus Rules.MAX_BLOOD).
func _rebuild_blood() -> void:
	_blood_version = map.blood_version
	var stains: Array = map.blood
	while _blood_nodes.size() < stains.size():
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		quad.mesh = mesh
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(quad)
		_blood_nodes.append(quad)
	for i in _blood_nodes.size():
		var quad := _blood_nodes[i]
		quad.visible = i < stains.size()
		if not quad.visible:
			continue
		var stain: Dictionary = stains[i]
		var key := str(stain["id"])
		if quad.get_meta("key", "") != key:
			quad.set_meta("key", key)
			var wall: Vector2i = stain["wall"]
			var texture: Texture2D = (DungeonMap.BLOOD_WALL if wall != Vector2i.ZERO else DungeonMap.BLOOD_FLOOR)[stain["kind"]]
			quad.material_override = _blood_material(texture)
			var size: float = float(stain["size"]) * (1.1 if wall != Vector2i.ZERO else 1.7)
			if wall == Vector2i.ZERO:
				# Au sol : à plat, tourné au hasard, à peine au-dessus des pavés.
				quad.position = to_3d(stain["position"], 0.035 + (i % 7) * 0.002)
				quad.rotation = Vector3(-PI / 2, float(stain["angle"]), 0)
			else:
				# Sur le mur : collé à sa face, à mi-hauteur.
				var center := map.cell_to_world(stain["cell"])
				var normal := Vector3(wall.x, 0, wall.y)
				var side := Vector3(-wall.y, 0, wall.x)
				quad.position = to_3d(center, 0.5) + normal * 0.49 + side * float(stain.get("offset", 0.0))
				quad.look_at(quad.position - normal, Vector3.UP)
			quad.scale = Vector3(size, size, 1)
	_fade_blood()


func _fade_blood() -> void:
	var stains: Array = map.blood
	for i in mini(stains.size(), _blood_nodes.size()):
		var material := _blood_nodes[i].material_override as StandardMaterial3D
		if material != null:
			material.albedo_color.a = DungeonMap.blood_alpha(stains[i])

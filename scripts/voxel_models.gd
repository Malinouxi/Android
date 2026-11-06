class_name VoxelModels
## LES MODÈLES 3D DU JEU, construits en blocs (style « voxel ») par du code.
##
## Pas de fichiers 3D à dessiner dans un logiciel : chaque personnage et chaque
## objet est un assemblage de boîtes (BoxMesh), de cylindres et de sphères
## colorés. Pour changer l'allure d'un personnage, modifie sa fiche dans
## CHARACTERS (couleurs, chapeau, arme...).
##
## Les personnages ont un « squelette » simple : des pivots pour les jambes, les
## bras, les ailes, la queue... que view_3d.gd fait bouger (marche, attaque).
## Échelle : un personnage de taille 8 (voir creatures.gd) fait 0,9 de haut ;
## une case fait 1 de large.

## Les matériaux déjà créés : "couleur|alpha|lumineux" -> matériau (partagés).
static var _materials := {}
## Les formes déjà créées : "boîte|taille" -> BoxMesh (partagées).
static var _meshes := {}

## Les fiches des personnages humanoïdes :
##   skin (peau), top (torse), legs, boots, robe (au lieu des jambes),
##   head : "ears", "horns", "hood", "helmet", "plumed", "crown", "hair",
##          "pointy_hat", "tonsure", "skull", "snout", "helm_gold", "spiky_hair" ;
##   head_color, eyes (couleur des yeux, lumineux), weapon : "sword", "axe",
##   "staff", "pickaxe", "dagger", "bow", "club", "hammer", "keys", "big_sword" ;
##   orb (couleur de l'orbe du bâton), shield (couleur), cape (couleur),
##   tail (couleur), wings (couleur), beard (couleur), tusks, stocky (petit et large).
const CHARACTERS := {
	"worker": {"skin": "7cb342", "top": "8d6e63", "legs": "5d4037", "boots": "3e2723", "head": "ears",
		"eyes": "ffeb3b", "weapon": "pickaxe"},
	"kobold": {"skin": "ff9800", "top": "ffb74d", "legs": "ff9800", "boots": "c66900", "head": "horns",
		"head_color": "c66900", "tail": "ff9800", "eyes": "ffffff", "weapon": "dagger"},
	"orc": {"skin": "4e7d2a", "top": "6d4c41", "legs": "5d4037", "boots": "3e2723", "head": "hair",
		"head_color": "212121", "tusks": true, "eyes": "ff5252", "weapon": "axe"},
	"warlock": {"skin": "2a1b3d", "robe": "5e35b1", "top": "5e35b1", "head": "hood", "head_color": "4527a0",
		"eyes": "ffee58", "weapon": "staff", "orb": "ffee58"},
	"demon": {"skin": "c62828", "top": "b71c1c", "legs": "8e1b1b", "boots": "3b0a0a", "head": "horns",
		"head_color": "ffd54f", "wings": "4a0e0e", "tail": "8e1b1b", "eyes": "ffeb3b", "weapon": "club"},
	"golem": {"skin": "8d8d8d", "top": "8d8d8d", "legs": "757575", "boots": "616161", "stocky": true,
		"eyes": "4dd0e1"},
	"vampire": {"skin": "e0e0e0", "top": "311b92", "legs": "212121", "boots": "121212", "head": "spiky_hair",
		"head_color": "212121", "cape": "1a1a2e", "eyes": "ff1744"},
	"salamander": {"skin": "e64a19", "top": "ffcc80", "legs": "bf360c", "boots": "7f2207", "head": "snout",
		"head_color": "ff7043", "tail": "ff9800", "eyes": "ffeb3b"},
	"catcher": {"skin": "05080a", "robe": "1f3a44", "top": "1f3a44", "head": "hood", "head_color": "2f5d6b",
		"eyes": "ffeb3b", "weapon": "keys"},
	"revenant": {"skin": "d8d2bf", "top": "6d5a46", "legs": "d8d2bf", "boots": "3a2f26", "head": "skull",
		"eyes": "76ff03", "weapon": "sword", "blade": "8d6e63"},
	"adventurer": {"skin": "ffccbc", "top": "1e88e5", "legs": "5d4037", "boots": "3e2723", "head": "hair",
		"head_color": "6d4c41", "eyes": "1a1a1a", "weapon": "sword"},
	"thief": {"skin": "ffccbc", "top": "37474f", "legs": "263238", "boots": "1c1c1c", "head": "hood",
		"head_color": "26a69a", "eyes": "ffffff", "weapon": "dagger"},
	"knight": {"skin": "90a4ae", "top": "90a4ae", "legs": "78909c", "boots": "455a64", "head": "plumed",
		"head_color": "b0bec5", "eyes": "1c2833", "weapon": "sword", "shield": "1565c0"},
	"cleric": {"skin": "ffccbc", "robe": "eceff1", "top": "eceff1", "head": "hair", "head_color": "8d6e63",
		"eyes": "1a1a1a", "weapon": "staff", "orb": "ffca28"},
	"archer": {"skin": "ffccbc", "top": "2e7d32", "legs": "5d4037", "boots": "3e2723", "head": "hood",
		"head_color": "1b5e20", "eyes": "1a1a1a", "weapon": "bow"},
	"dwarf": {"skin": "ffccbc", "top": "6d4c41", "legs": "4e342e", "boots": "3e2723", "head": "helmet",
		"head_color": "9e9e9e", "beard": "ff8f00", "stocky": true, "eyes": "1a1a1a", "weapon": "axe"},
	"mage": {"skin": "ffccbc", "robe": "3949ab", "top": "3949ab", "head": "pointy_hat", "head_color": "283593",
		"eyes": "1a1a1a", "weapon": "staff", "orb": "ff7043"},
	"paladin": {"skin": "fbc02d", "top": "eceff1", "legs": "f9a825", "boots": "795548", "head": "helm_gold",
		"head_color": "fdd835", "eyes": "3e2a00", "weapon": "hammer", "shield": "1565c0"},
	"giant": {"skin": "c8a27a", "top": "558b2f", "legs": "c8a27a", "boots": "3e2723", "head": "hair",
		"head_color": "4e342e", "stocky": true, "eyes": "1a1a1a", "weapon": "club"},
	"champion": {"skin": "ffccbc", "top": "eceff1", "legs": "90a4ae", "boots": "37474f", "head": "crown",
		"head_color": "ffca28", "beard": "8d6e63", "cape": "1a237e", "eyes": "1a1a1a", "weapon": "big_sword"},
	"monk": {"skin": "ffccbc", "robe": "795548", "top": "795548", "head": "tonsure", "head_color": "8d6e63",
		"eyes": "1a1a1a", "weapon": "keys"},
}


# ---------------------------------------------------------------------------
# Briques de base
# ---------------------------------------------------------------------------

static func material(color: Color, glow := false, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [color.to_html(false), alpha, glow]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color, alpha)
		m.roughness = 0.9
		if glow:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 1.2
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = m
	return _materials[key]


## Une boîte colorée, ajoutée à « parent » à la position « at » (son centre).
static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var key := "box|%s" % size
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	var part := MeshInstance3D.new()
	part.mesh = _meshes[key]
	part.material_override = material(color, glow)
	part.position = at
	parent.add_child(part)
	return part


static func sphere(parent: Node3D, radius: float, at: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var key := "sphere|%.3f" % radius
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 8
		mesh.rings = 4
		_meshes[key] = mesh
	var part := MeshInstance3D.new()
	part.mesh = _meshes[key]
	part.material_override = material(color, glow)
	part.position = at
	parent.add_child(part)
	return part


## Un cylindre (ou un cône si top = 0).
static func cylinder(parent: Node3D, bottom: float, top: float, height: float, at: Vector3, color: Color,
		glow := false) -> MeshInstance3D:
	var key := "cyl|%.3f|%.3f|%.3f" % [bottom, top, height]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = bottom
		mesh.top_radius = top
		mesh.height = height
		mesh.radial_segments = 8
		mesh.rings = 1
		_meshes[key] = mesh
	var part := MeshInstance3D.new()
	part.mesh = _meshes[key]
	part.material_override = material(color, glow)
	part.position = at
	parent.add_child(part)
	return part


## Un pivot (point de rotation) : ce qu'on y accroche tourne avec lui.
static func pivot(parent: Node3D, at: Vector3, pivot_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = pivot_name
	node.position = at
	parent.add_child(node)
	return node


# ---------------------------------------------------------------------------
# Personnages
# ---------------------------------------------------------------------------

## Construit le modèle d'un personnage. « tint » teinte toutes ses couleurs (les
## troupes du rival sont bleutées) ; « alpha » < 1 le rend transparent (Voleuse).
## Le modèle regarde vers +z ; ses pivots sont rangés dans les métadonnées
## « rig » : {"legs": [...], "arms": [gauche, droit], "wings": [...], "tail": ...}.
static func character(sprite: String, tint := Color.WHITE, alpha := 1.0) -> Node3D:
	var root := _blender_character(sprite)
	if root == null:
		root = Node3D.new()
		var body := pivot(root, Vector3.ZERO, "body")
		var rig := {"body": body, "legs": [], "arms": [], "wings": [], "tail": null, "kind": "humanoid"}
		match sprite:
			"spider":
				_spider(body, rig)
			"bat":
				_bat(body, rig)
			"cerberus":
				_cerberus(body, rig)
			_:
				_humanoid(body, rig, CHARACTERS.get(sprite, CHARACTERS["worker"]))
		root.set_meta("rig", rig)
	if tint != Color.WHITE or alpha < 1.0:
		_recolor(root, tint, alpha)
	return root


## Les modèles low-poly faits dans Blender (scripts de tools/blender/) : s'il
## existe assets/models/<sprite>.glb, il remplace le modèle en blocs. Ses pivots
## portent les mêmes noms : body, leg_*, arm_l, arm_r, wing_l, wing_r, tail.
const BLENDER_MODELS := "res://assets/models/%s.glb"
## Le genre de squelette des bêtes (pour les animer comme leur modèle en blocs).
const RIG_KINDS := {"spider": "spider", "bat": "bat", "cerberus": "quadruped"}
## Le mobilier des salles (assets/models/rooms/<nom>.glb) : ses parties animées
## sont des pivots nommés flame_*, sway_* et wisp (voir _blender_room).
const BLENDER_ROOMS := "res://assets/models/rooms/%s.glb"
## Les modèles déjà chargés : chemin -> PackedScene (ou null s'il n'y en a pas).
static var _blender_scenes := {}


## Une copie du modèle Blender rangé à « path », ou null s'il n'existe pas.
static func _blender_model(path: String) -> Node3D:
	if not _blender_scenes.has(path):
		_blender_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _blender_scenes[path]
	return null if scene == null else scene.instantiate() as Node3D


static func _blender_character(sprite: String) -> Node3D:
	var root := _blender_model(BLENDER_MODELS % sprite)
	if root == null:
		return null
	var body := root.get_node("body") as Node3D
	var rig := {"body": body, "legs": [], "arms": [], "wings": [], "tail": body.get_node_or_null("tail"),
			"kind": RIG_KINDS.get(sprite, "humanoid")}
	for child in body.get_children():
		if String(child.name).begins_with("leg"):
			rig["legs"].append(child)
	rig["legs"].sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	for pivot_name in ["arm_l", "arm_r"]:
		if body.has_node(pivot_name):
			rig["arms"].append(body.get_node(pivot_name))
	for pivot_name in ["wing_l", "wing_r"]:
		if body.has_node(pivot_name):
			rig["wings"].append(body.get_node(pivot_name))
	root.set_meta("rig", rig)
	return root


## Un objet de salle fait dans Blender, avec ses parties animées rangées comme
## celles des modèles en blocs : {"flames": [...], "sways": [...], "wisp": ...}.
static func _blender_room(model_name: String) -> Node3D:
	var root := _blender_model(BLENDER_ROOMS % model_name)
	if root == null:
		return null
	# Les pivots seulement (pas leurs maillages « flame_0_mesh »...).
	var is_pivot := func(node: Node) -> bool: return not node is MeshInstance3D
	var anim := {"flames": root.find_children("flame_*", "", true, false).filter(is_pivot),
			"sways": root.find_children("sway_*", "", true, false).filter(is_pivot)}
	if root.has_node("wisp"):
		anim["wisp"] = root.get_node("wisp")
	root.set_meta("anim", anim)
	return root


## Teinte et transparence : on remplace les matériaux de toutes les pièces.
static func _recolor(node: Node, tint: Color, alpha: float) -> void:
	for child in node.get_children():
		var part := child as MeshInstance3D
		if part != null and part.material_override is StandardMaterial3D:
			var old: StandardMaterial3D = part.material_override
			var color := old.albedo_color * Color(tint.r, tint.g, tint.b)
			part.material_override = material(color.clamp(), old.emission_enabled, alpha)
		elif part != null and part.mesh != null:
			# Un modèle Blender : ses matériaux sont dans le maillage (un par surface).
			for i in part.mesh.get_surface_count():
				var old := part.get_active_material(i) as BaseMaterial3D
				if old == null:
					continue
				var copy := old.duplicate() as BaseMaterial3D
				copy.albedo_color = Color((old.albedo_color * Color(tint.r, tint.g, tint.b)).clamp(), alpha)
				if alpha < 1.0:
					copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				part.set_surface_override_material(i, copy)
		_recolor(child, tint, alpha)


static func _c(spec: Dictionary, key: String, fallback := "ff00ff") -> Color:
	return Color(spec.get(key, fallback))


static func _humanoid(body: Node3D, rig: Dictionary, spec: Dictionary) -> void:
	var stocky: bool = spec.get("stocky", false)
	var width := 1.2 if stocky else 1.0
	var skin := _c(spec, "skin")
	var top := _c(spec, "top")
	var hip := 0.3
	# Les jambes (ou une robe, avec de petits pieds qui dépassent).
	for side: int in [-1, 1]:
		var leg := pivot(body, Vector3(0.08 * side * width, hip, 0), "leg")
		if spec.has("robe"):
			box(leg, Vector3(0.1, 0.06, 0.14), Vector3(0, -0.27, 0.02), _c(spec, "boots", "3e2723"))
		else:
			box(leg, Vector3(0.11, 0.22, 0.11), Vector3(0, -0.11, 0), _c(spec, "legs"))
			box(leg, Vector3(0.13, 0.07, 0.15), Vector3(0, -0.26, 0.02), _c(spec, "boots"))
		rig["legs"].append(leg)
	if spec.has("robe"):
		box(body, Vector3(0.32 * width, 0.3, 0.22), Vector3(0, 0.17, 0), _c(spec, "robe"))
	# Le torse.
	box(body, Vector3(0.3 * width, 0.3, 0.18), Vector3(0, 0.45, 0), top)
	if spec.has("cape"):
		box(body, Vector3(0.34 * width, 0.52, 0.03), Vector3(0, 0.32, -0.11), _c(spec, "cape"))
	if spec.has("wings"):
		for side: int in [-1, 1]:
			var wing := pivot(body, Vector3(0.1 * side, 0.52, -0.1), "wing")
			wing.rotation.y = 0.5 * side
			box(wing, Vector3(0.4, 0.28, 0.02), Vector3(0.2 * side, 0.05, 0), _c(spec, "wings"))
			rig["wings"].append(wing)
	if spec.has("tail"):
		var tail := pivot(body, Vector3(0, 0.3, -0.1), "tail")
		box(tail, Vector3(0.07, 0.07, 0.3), Vector3(0, -0.03, -0.15), _c(spec, "tail"))
		rig["tail"] = tail
	# Les bras (pivots aux épaules), avec les mains.
	for side: int in [-1, 1]:
		var arm := pivot(body, Vector3(0.2 * side * width, 0.58, 0), "arm")
		box(arm, Vector3(0.09, 0.24, 0.09), Vector3(0, -0.11, 0), top if not spec.has("robe") else _c(spec, "robe"))
		box(arm, Vector3(0.08, 0.07, 0.08), Vector3(0, -0.26, 0), skin)
		rig["arms"].append(arm)
	_weapon(rig["arms"][1], spec)
	if spec.has("shield"):
		box(rig["arms"][0], Vector3(0.04, 0.22, 0.2), Vector3(-0.07, -0.18, 0.04), _c(spec, "shield"))
	# La tête.
	var head := pivot(body, Vector3(0, 0.74, 0), "head")
	_head(head, spec, skin)


## La tête et son couvre-chef. Le visage regarde vers +z.
static func _head(head: Node3D, spec: Dictionary, skin: Color) -> void:
	var hat := _c(spec, "head_color", "212121")
	var eyes := _c(spec, "eyes", "1a1a1a")
	var glowing := eyes.v > 0.6 # Des yeux clairs brillent un peu (dans l'ombre des capuches).
	var kind: String = spec.get("head", "")
	match kind:
		"hood":
			box(head, Vector3(0.3, 0.3, 0.28), Vector3(0, 0.02, -0.01), hat)
			box(head, Vector3(0.2, 0.16, 0.02), Vector3(0, -0.01, 0.13), skin.darkened(0.7))
		"skull":
			box(head, Vector3(0.24, 0.24, 0.22), Vector3.ZERO, skin)
			box(head, Vector3(0.06, 0.05, 0.02), Vector3(-0.06, 0.02, 0.11), Color("1a1a1a"))
			box(head, Vector3(0.06, 0.05, 0.02), Vector3(0.06, 0.02, 0.11), Color("1a1a1a"))
		_:
			box(head, Vector3(0.26, 0.24, 0.24), Vector3.ZERO, skin)
	# Les yeux.
	for side: int in [-1, 1]:
		box(head, Vector3(0.05, 0.04, 0.02), Vector3(0.06 * side, 0.02, 0.125), eyes, glowing)
	match kind:
		"ears":
			for side: int in [-1, 1]:
				box(head, Vector3(0.14, 0.06, 0.04), Vector3(0.18 * side, 0.03, 0), skin)
		"horns":
			for side: int in [-1, 1]:
				var horn := box(head, Vector3(0.05, 0.14, 0.05), Vector3(0.09 * side, 0.17, 0), hat)
				horn.rotation.z = -0.4 * side
		"hair":
			box(head, Vector3(0.28, 0.08, 0.26), Vector3(0, 0.12, -0.01), hat)
			box(head, Vector3(0.28, 0.16, 0.06), Vector3(0, 0.02, -0.11), hat)
		"spiky_hair":
			box(head, Vector3(0.28, 0.07, 0.26), Vector3(0, 0.12, -0.01), hat)
			box(head, Vector3(0.06, 0.08, 0.06), Vector3(0, 0.18, 0.06), hat)
		"helmet", "helm_gold", "plumed":
			box(head, Vector3(0.3, 0.14, 0.28), Vector3(0, 0.08, 0), hat)
			if kind != "helmet":
				box(head, Vector3(0.24, 0.03, 0.02), Vector3(0, 0.0, 0.13), Color("1c2833"))
			if kind == "plumed":
				box(head, Vector3(0.04, 0.14, 0.14), Vector3(0, 0.2, -0.02), Color("e53935"))
		"crown":
			box(head, Vector3(0.28, 0.06, 0.26), Vector3(0, 0.14, 0), hat, true)
			for x in [-0.1, 0.0, 0.1]:
				box(head, Vector3(0.04, 0.07, 0.04), Vector3(x, 0.2, 0.1), hat, true)
		"pointy_hat":
			cylinder(head, 0.22, 0.22, 0.03, Vector3(0, 0.12, 0), hat)
			cylinder(head, 0.13, 0.0, 0.32, Vector3(0, 0.28, 0), hat)
		"tonsure":
			box(head, Vector3(0.28, 0.07, 0.26), Vector3(0, 0.07, 0), hat)
		"snout":
			box(head, Vector3(0.16, 0.1, 0.12), Vector3(0, -0.05, 0.16), hat)
	if spec.has("beard"):
		box(head, Vector3(0.24, 0.16, 0.06), Vector3(0, -0.14, 0.11), _c(spec, "beard"))
	if spec.get("tusks", false):
		for side: int in [-1, 1]:
			box(head, Vector3(0.03, 0.06, 0.03), Vector3(0.06 * side, -0.1, 0.13), Color("fffde7"))


## L'arme, tenue dans la main droite (au bout du bras, pointée vers l'avant et le haut).
static func _weapon(arm: Node3D, spec: Dictionary) -> void:
	var hand := pivot(arm, Vector3(0, -0.27, 0.02), "weapon")
	hand.rotation.x = 1.2 # L'arme pointe vers l'avant quand le bras pend.
	var wood := Color("8d6e63")
	var steel := Color(spec.get("blade", "cfd8dc"))
	match spec.get("weapon", ""):
		"sword":
			box(hand, Vector3(0.03, 0.34, 0.015), Vector3(0, 0.19, 0), steel)
			box(hand, Vector3(0.12, 0.025, 0.04), Vector3(0, 0.02, 0), Color("8d6e63"))
		"big_sword":
			box(hand, Vector3(0.05, 0.5, 0.02), Vector3(0, 0.27, 0), Color("eceff1"))
			box(hand, Vector3(0.16, 0.03, 0.05), Vector3(0, 0.02, 0), Color("ffca28"))
		"dagger":
			box(hand, Vector3(0.025, 0.16, 0.012), Vector3(0, 0.1, 0), steel)
		"axe":
			box(hand, Vector3(0.03, 0.36, 0.03), Vector3(0, 0.14, 0), wood)
			box(hand, Vector3(0.02, 0.12, 0.14), Vector3(0, 0.28, 0.06), steel)
		"pickaxe":
			box(hand, Vector3(0.03, 0.3, 0.03), Vector3(0, 0.12, 0), wood)
			box(hand, Vector3(0.03, 0.04, 0.26), Vector3(0, 0.26, 0), Color("9e9e9e"))
		"hammer", "club":
			box(hand, Vector3(0.035, 0.3, 0.035), Vector3(0, 0.12, 0), wood)
			var head_color := Color("bdbdbd") if spec["weapon"] == "hammer" else Color("795548")
			box(hand, Vector3(0.12, 0.1, 0.1), Vector3(0, 0.28, 0), head_color)
		"staff":
			box(hand, Vector3(0.03, 0.6, 0.03), Vector3(0, 0.15, 0), Color("6d4c41"))
			sphere(hand, 0.05, Vector3(0, 0.47, 0), _c(spec, "orb", "ffee58"), true)
		"bow":
			box(hand, Vector3(0.025, 0.44, 0.025), Vector3(0, 0.1, 0.04), wood)
			box(hand, Vector3(0.005, 0.4, 0.005), Vector3(0, 0.1, -0.02), Color("eceff1"))
		"keys":
			box(hand, Vector3(0.08, 0.08, 0.01), Vector3(0, 0.05, 0), Color("ffca28"), true)


static func _spider(body: Node3D, rig: Dictionary) -> void:
	rig["kind"] = "spider"
	var dark := Color("2a1838")
	box(body, Vector3(0.34, 0.2, 0.4), Vector3(0, 0.22, -0.08), Color("6a3d8f"))
	box(body, Vector3(0.22, 0.16, 0.2), Vector3(0, 0.2, 0.2), Color("4a2a66"))
	for side: int in [-1, 1]:
		box(body, Vector3(0.04, 0.04, 0.02), Vector3(0.05 * side, 0.24, 0.31), Color("ff1744"), true)
		for i in 4:
			var leg := pivot(body, Vector3(0.12 * side, 0.22, 0.12 - i * 0.1), "leg")
			var upper := box(leg, Vector3(0.24, 0.035, 0.035), Vector3(0.12 * side, 0.03, 0), dark)
			upper.rotation.z = 0.35 * side
			var lower := box(leg, Vector3(0.035, 0.22, 0.035), Vector3(0.24 * side, -0.07, 0), dark)
			lower.rotation.z = -0.2 * side
			rig["legs"].append(leg)


static func _bat(body: Node3D, rig: Dictionary) -> void:
	rig["kind"] = "bat"
	body.position.y = 0.45 # Elle vole.
	box(body, Vector3(0.18, 0.2, 0.16), Vector3.ZERO, Color("6d5a85"))
	box(body, Vector3(0.16, 0.14, 0.14), Vector3(0, 0.15, 0.03), Color("5d4a75"))
	for side: int in [-1, 1]:
		box(body, Vector3(0.04, 0.08, 0.03), Vector3(0.06 * side, 0.25, 0.03), Color("5d4a75"))
		box(body, Vector3(0.03, 0.03, 0.02), Vector3(0.04 * side, 0.17, 0.1), Color("ff5252"), true)
		var wing := pivot(body, Vector3(0.08 * side, 0.04, 0), "wing")
		box(wing, Vector3(0.36, 0.18, 0.02), Vector3(0.18 * side, 0, 0), Color("3e2f52"))
		rig["wings"].append(wing)


static func _cerberus(body: Node3D, rig: Dictionary) -> void:
	rig["kind"] = "quadruped"
	var fur := Color("3b2a2a")
	box(body, Vector3(0.34, 0.3, 0.62), Vector3(0, 0.42, -0.04), fur)
	box(body, Vector3(0.38, 0.06, 0.08), Vector3(0, 0.5, 0.22), Color("8d6e63")) # collier
	for x in [-0.12, 0.12]:
		for z in [0.18, -0.26]:
			var leg := pivot(body, Vector3(x, 0.3, z), "leg")
			box(leg, Vector3(0.1, 0.3, 0.1), Vector3(0, -0.15, 0), fur.darkened(0.2))
			rig["legs"].append(leg)
	for i in 3: # Trois têtes !
		var x := (i - 1) * 0.15
		var head := pivot(body, Vector3(x, 0.62 + (0.06 if i == 1 else 0.0), 0.3), "head")
		box(head, Vector3(0.15, 0.15, 0.17), Vector3.ZERO, fur)
		box(head, Vector3(0.1, 0.07, 0.1), Vector3(0, -0.03, 0.12), Color("4e3434"))
		for side: int in [-1, 1]:
			box(head, Vector3(0.03, 0.03, 0.02), Vector3(0.04 * side, 0.03, 0.09), Color("ff3d00"), true)
			box(head, Vector3(0.03, 0.06, 0.03), Vector3(0.05 * side, 0.1, -0.02), fur)
	var tail := pivot(body, Vector3(0, 0.5, -0.36), "tail")
	box(tail, Vector3(0.05, 0.05, 0.28), Vector3(0, 0.06, -0.12), fur)
	rig["tail"] = tail


# ---------------------------------------------------------------------------
# Objets
# ---------------------------------------------------------------------------

## Construit un objet. « kind » : "chest_0" à "chest_3", "bed", "mushrooms_N",
## "bookshelf", "anvil", "dummy", "altar", "sacrifice_altar", "door", "torch",
## "tomb_empty", "tomb_full", "spikes", "spikes_up", "gold_N", "entrance",
## "prison", "site". Les parties animées sont notées dans la métadonnée « anim ».
static func prop(kind: String) -> Node3D:
	if kind.begins_with("furn_"):
		# Un objet de salle : "furn_<salle>_<largeur>_<profondeur>_<remplissage>".
		var parts := kind.split("_")
		return furniture(int(parts[1]), Vector2i(int(parts[2]), int(parts[3])), int(parts[4]))
	if kind.begins_with("build_"):
		# Un chantier de salle : "build_<salle>_<largeur>_<profondeur>_<étape 0 à 3>".
		var parts := kind.split("_")
		return scaffold(int(parts[1]), Vector2i(int(parts[2]), int(parts[3])), int(parts[4]))
	# Lit, champignons, cellule, tombes : le modèle Blender s'il existe.
	var model := _blender_room(kind)
	if model != null:
		return model
	var root := Node3D.new()
	var anim := {}
	var wood := Color("6d4c41")
	var stone := Color("78909c")
	if kind.begins_with("chest_"):
		var level := int(kind.substr(6))
		box(root, Vector3(0.5, 0.3, 0.34), Vector3(0, 0.15, 0), Color("8d5a2b"))
		box(root, Vector3(0.52, 0.04, 0.36), Vector3(0, 0.08, 0), Color("455a64"))
		box(root, Vector3(0.52, 0.04, 0.36), Vector3(0, 0.24, 0), Color("455a64"))
		if level == 0:
			box(root, Vector3(0.5, 0.1, 0.34), Vector3(0, 0.35, 0), Color("7a4a22")) # couvercle fermé
		else:
			for i in level * 3: # De l'or qui déborde.
				sphere(root, 0.06, Vector3(randf_range(-0.18, 0.18), 0.3 + 0.04 * (i % 3), randf_range(-0.1, 0.1)),
						Color("f2b632"), true)
			var lid := box(root, Vector3(0.5, 0.06, 0.34), Vector3(0, 0.42, -0.2), Color("7a4a22"))
			lid.rotation.x = -1.2
	elif kind == "bed":
		box(root, Vector3(0.7, 0.14, 0.42), Vector3(0, 0.1, 0), wood)
		box(root, Vector3(0.66, 0.08, 0.38), Vector3(0, 0.2, 0), Color("c8a165"))
		box(root, Vector3(0.18, 0.08, 0.3), Vector3(-0.22, 0.27, 0), Color("d7ccc8"))
		box(root, Vector3(0.42, 0.06, 0.4), Vector3(0.1, 0.26, 0), Color("7e57c2"))
	elif kind.begins_with("mushrooms_"):
		var count := int(kind.substr(10))
		var spots := [Vector3(-0.2, 0, 0.15), Vector3(0.18, 0, -0.15), Vector3(0.1, 0, 0.22)]
		for i in count:
			var at: Vector3 = spots[i]
			cylinder(root, 0.04, 0.04, 0.16, at + Vector3(0, 0.08, 0), Color("efebe9"))
			cylinder(root, 0.12, 0.05, 0.08, at + Vector3(0, 0.19, 0), Color("e53935"))
			sphere(root, 0.025, at + Vector3(0.04, 0.22, 0.05), Color.WHITE)
	elif kind == "bookshelf":
		box(root, Vector3(0.7, 0.9, 0.24), Vector3(0, 0.45, -0.25), wood)
		var colors := ["c62828", "1565c0", "2e7d32", "f9a825", "6a1b9a", "ef6c00"]
		for shelf in 3:
			for i in 7:
				box(root, Vector3(0.07, 0.2, 0.18), Vector3(-0.27 + i * 0.09, 0.2 + shelf * 0.27, -0.2),
						Color(colors[(i + shelf * 2) % colors.size()]))
	elif kind == "anvil":
		box(root, Vector3(0.24, 0.2, 0.24), Vector3(0, 0.1, 0), Color("795548"))
		box(root, Vector3(0.18, 0.12, 0.14), Vector3(0, 0.26, 0), Color("546e7a"))
		box(root, Vector3(0.46, 0.1, 0.2), Vector3(0.04, 0.37, 0), Color("78909c"))
		var hot := box(root, Vector3(0.2, 0.03, 0.06), Vector3(0, 0.44, 0), Color("ff7043"), true)
		anim["glow"] = hot
	elif kind == "dummy":
		var sway := pivot(root, Vector3.ZERO, "sway")
		box(sway, Vector3(0.05, 0.4, 0.05), Vector3(0, 0.2, 0), wood)
		box(sway, Vector3(0.5, 0.06, 0.06), Vector3(0, 0.55, 0), wood)
		box(sway, Vector3(0.26, 0.3, 0.2), Vector3(0, 0.55, 0), Color("d4a85a"))
		box(sway, Vector3(0.16, 0.16, 0.16), Vector3(0, 0.8, 0), Color("d4a85a"))
		box(sway, Vector3(0.1, 0.1, 0.02), Vector3(0, 0.55, 0.11), Color("c62828"))
		anim["sway"] = sway
	elif kind == "altar":
		box(root, Vector3(0.6, 0.4, 0.34), Vector3(0, 0.2, 0), stone)
		box(root, Vector3(0.66, 0.06, 0.4), Vector3(0, 0.43, 0), Color("90a4ae"))
		box(root, Vector3(0.24, 0.36, 0.02), Vector3(0, 0.22, 0.18), Color("6a1b9a"))
		anim["flames"] = _candles(root, [Vector3(-0.25, 0.46, 0), Vector3(0.25, 0.46, 0)], Color("eceff1"), Color("ffb300"))
	elif kind == "sacrifice_altar":
		box(root, Vector3(0.6, 0.36, 0.4), Vector3(0, 0.18, 0), Color("2a2a30"))
		box(root, Vector3(0.66, 0.08, 0.46), Vector3(0, 0.4, 0), Color("4a4a52"))
		box(root, Vector3(0.5, 0.01, 0.04), Vector3(0, 0.445, 0.1), Color("c62828"))
		sphere(root, 0.09, Vector3(0, 0.53, 0), Color("e0e0e0"))
		anim["flames"] = _candles(root, [Vector3(-0.28, 0.44, 0.1), Vector3(0.28, 0.44, 0.1)], Color("b71c1c"), Color("ff5252"))
	elif kind == "door":
		box(root, Vector3(0.12, 0.95, 0.2), Vector3(-0.44, 0.48, 0), stone)
		box(root, Vector3(0.12, 0.95, 0.2), Vector3(0.44, 0.48, 0), stone)
		box(root, Vector3(1.0, 0.14, 0.2), Vector3(0, 0.98, 0), stone)
		box(root, Vector3(0.76, 0.9, 0.08), Vector3(0, 0.45, 0), Color("8d6e63"))
		box(root, Vector3(0.78, 0.05, 0.1), Vector3(0, 0.25, 0), Color("37474f"))
		box(root, Vector3(0.78, 0.05, 0.1), Vector3(0, 0.68, 0), Color("37474f"))
	elif kind == "wall_torch":
		# Une torche fixée au mur (le support pointe vers -z, là où est le mur).
		box(root, Vector3(0.06, 0.06, 0.3), Vector3(0, 0.95, -0.15), Color("37474f"))
		cylinder(root, 0.09, 0.05, 0.12, Vector3(0, 1.0, 0.0), Color("5d4037"))
		var wall_flame := sphere(root, 0.09, Vector3(0, 1.12, 0.0), Color("ff9100"), true)
		sphere(wall_flame, 0.05, Vector3(0, 0.02, 0), Color("ffee58"), true)
		anim["flame"] = wall_flame
	elif kind == "torch":
		box(root, Vector3(0.08, 0.6, 0.08), Vector3(0, 0.3, 0), Color("5d4037"))
		cylinder(root, 0.14, 0.08, 0.1, Vector3(0, 0.64, 0), Color("6d4c41"))
		var flame := sphere(root, 0.1, Vector3(0, 0.76, 0), Color("ff9800"), true)
		sphere(flame, 0.06, Vector3(0, 0.02, 0), Color("ffeb3b"), true)
		anim["flame"] = flame
	elif kind.begins_with("tomb"):
		box(root, Vector3(0.32, 0.46, 0.1), Vector3(0, 0.23, -0.25), Color("7d8580"))
		box(root, Vector3(0.12, 0.03, 0.02), Vector3(0, 0.35, -0.19), Color("4f5650"))
		box(root, Vector3(0.03, 0.14, 0.02), Vector3(0, 0.33, -0.19), Color("4f5650"))
		if kind == "tomb_full":
			box(root, Vector3(0.36, 0.08, 0.5), Vector3(0, 0.04, 0.08), Color("5d4430"))
			var wisp := sphere(root, 0.06, Vector3(0.1, 0.25, 0.1), Color("76ff03"), true)
			anim["wisp"] = wisp
		else:
			box(root, Vector3(0.36, 0.02, 0.5), Vector3(0, 0.01, 0.08), Color("1e140c"))
			box(root, Vector3(0.18, 0.1, 0.18), Vector3(0.24, 0.05, 0.24), Color("6d5641"))
	elif kind == "spikes" or kind == "spikes_up":
		var height := 0.22 if kind == "spikes_up" else 0.04
		for x in [-0.25, 0.0, 0.25]:
			for z in [-0.25, 0.0, 0.25]:
				cylinder(root, 0.05, 0.0, height, Vector3(x, height * 0.5, z), Color("b0bec5"))
	elif kind.begins_with("gold_"):
		var count := int(kind.substr(5)) + 1
		for i in count * 2:
			sphere(root, 0.06, Vector3(randf_range(-0.15, 0.15), 0.04 + 0.05 * (i / 3), randf_range(-0.15, 0.15)),
					Color("f2b632"), true)
	elif kind == "entrance":
		for x in [-0.42, 0.42]:
			box(root, Vector3(0.16, 1.2, 0.3), Vector3(x, 0.6, 0), Color("78909c"))
		box(root, Vector3(1.0, 0.2, 0.3), Vector3(0, 1.25, 0), Color("90a4ae"))
		box(root, Vector3(0.68, 1.0, 0.08), Vector3(0, 0.5, -0.05), Color("5d4037"))
		box(root, Vector3(0.02, 1.0, 0.1), Vector3(0, 0.5, -0.04), Color("2e1d16"))
	elif kind == "prison":
		# Une cage : des barreaux aux quatre coins et sur les côtés.
		for x in [-0.45, -0.15, 0.15, 0.45]:
			for z in [-0.45, 0.45]:
				box(root, Vector3(0.04, 0.9, 0.04), Vector3(x, 0.45, z), Color("78909c"))
				box(root, Vector3(0.04, 0.9, 0.04), Vector3(z, 0.45, x), Color("78909c"))
		box(root, Vector3(1.0, 0.05, 0.05), Vector3(0, 0.9, -0.45), Color("546e7a"))
		box(root, Vector3(1.0, 0.05, 0.05), Vector3(0, 0.9, 0.45), Color("546e7a"))
	elif kind == "site":
		# Un chantier : des poutres et une palissade.
		for x in [-0.35, 0.35]:
			for z in [-0.35, 0.35]:
				box(root, Vector3(0.06, 0.6, 0.06), Vector3(x, 0.3, z), Color("a1887f"))
		box(root, Vector3(0.76, 0.05, 0.06), Vector3(0, 0.58, -0.35), Color("a1887f"))
		box(root, Vector3(0.76, 0.05, 0.06), Vector3(0, 0.58, 0.35), Color("a1887f"))
		box(root, Vector3(0.3, 0.12, 0.2), Vector3(0.1, 0.06, 0.05), Color("8d6e63"))
	root.set_meta("anim", anim)
	return root


## Le chantier d'une salle entière, centré sur son milieu : l'objet de la salle
## sort de terre petit à petit (étape 0 à 3), et sur les grands chantiers (4 cases
## et plus) les ouvriers montent des échafaudages, un étage de plus à chaque étape.
static func scaffold(type: int, size: Vector2i, step: int) -> Node3D:
	var root := Node3D.new()
	var w := float(size.x)
	var d := float(size.y)
	var pole := Color("a1887f")
	var plank := Color("c8a165")
	var dark := Color("6d4c41")
	# 1. L'objet de la salle, encore tout petit.
	var object := Node3D.new()
	root.add_child(object)
	if type in [Rooms.Type.TREASURY, Rooms.Type.LIBRARY, Rooms.Type.WORKSHOP, Rooms.Type.TRAINING,
			Rooms.Type.TEMPLE]:
		object.add_child(furniture(type, size, 0))
	else:
		var piece_kind: String = {Rooms.Type.LAIR: "bed", Rooms.Type.FARM: "mushrooms_1",
				Rooms.Type.PRISON: "prison", Rooms.Type.GRAVEYARD: "tomb_empty"}.get(type, "site")
		for dz in size.y:
			for dx in size.x:
				var piece := prop(piece_kind)
				piece.position = Vector3(dx - (w - 1.0) * 0.5, 0.0, dz - (d - 1.0) * 0.5)
				object.add_child(piece)
	object.scale.y = 0.12 + 0.24 * step
	# 2. Les matériaux : une pile de planches et une caisse dans deux coins.
	var corner := Vector3(w * 0.5 - 0.3, 0.0, d * 0.5 - 0.25)
	for i in 3:
		box(root, Vector3(0.5, 0.04, 0.12), Vector3(-corner.x + 0.05, 0.02 + i * 0.045, corner.z - i * 0.02), plank)
	box(root, Vector3(0.22, 0.22, 0.22), Vector3(corner.x, 0.11, -corner.z), dark)
	box(root, Vector3(0.23, 0.03, 0.23), Vector3(corner.x, 0.2, -corner.z), pole)
	if type == Rooms.Type.TEMPLE or type == Rooms.Type.LIBRARY or type == Rooms.Type.PRISON:
		for i in 3: # Des blocs de pierre taillée.
			box(root, Vector3(0.18, 0.14, 0.18), Vector3(corner.x - 0.2 * i, 0.07, corner.z), Color("8d8d96"))
	if size.x * size.y < 4:
		# Petit chantier : quatre piquets et une corde.
		var px := w * 0.5 - 0.08
		var pz := d * 0.5 - 0.08
		for x in [-px, px]:
			for z in [-pz, pz]:
				box(root, Vector3(0.05, 0.36, 0.05), Vector3(x, 0.18, z), pole)
		box(root, Vector3(w - 0.16, 0.02, 0.02), Vector3(0, 0.32, -pz), Color("e0c080"))
		box(root, Vector3(w - 0.16, 0.02, 0.02), Vector3(0, 0.32, pz), Color("e0c080"))
		box(root, Vector3(0.02, 0.02, d - 0.16), Vector3(-px, 0.32, 0), Color("e0c080"))
		box(root, Vector3(0.02, 0.02, d - 0.16), Vector3(px, 0.32, 0), Color("e0c080"))
		root.set_meta("anim", {})
		return root
	# 3. Les échafaudages : des poteaux tout autour, des traverses et des
	#    planchers à chaque étage, des croix de bois, et une échelle.
	var level_h := 0.36
	var levels := step + 1
	var top := level_h * levels + 0.12
	var ex := w * 0.5 - 0.06
	var ez := d * 0.5 - 0.06
	for i in size.x + 1:
		var x := clampf(-w * 0.5 + i, -ex, ex)
		for z in [-ez, ez]:
			box(root, Vector3(0.06, top, 0.06), Vector3(x, top * 0.5, z), pole)
	for i in range(1, size.y):
		var z := -d * 0.5 + i
		for x in [-ex, ex]:
			box(root, Vector3(0.06, top, 0.06), Vector3(x, top * 0.5, z), pole)
	for k in range(1, levels + 1):
		var y := k * level_h
		for z in [-ez, ez]:
			box(root, Vector3(w - 0.08, 0.04, 0.05), Vector3(0, y, z), pole)
			# Le plancher, côté intérieur.
			box(root, Vector3(w - 0.12, 0.03, 0.2), Vector3(0, y + 0.03, z - signf(z) * 0.12), plank)
		for x in [-ex, ex]:
			box(root, Vector3(0.05, 0.04, d - 0.08), Vector3(x, y, 0), pole)
		# Des croix de bois sur une travée sur deux.
		for i in size.x:
			if (i + k) % 2 != 0:
				continue
			var brace := box(root, Vector3(0.03, sqrt(1.0 + level_h * level_h), 0.03),
					Vector3(-w * 0.5 + i + 0.5, y - level_h * 0.5, -ez - 0.03), dark)
			brace.rotation.z = -atan2(1.0, level_h) if k % 2 == 0 else atan2(1.0, level_h)
	# L'échelle, contre le premier poteau.
	for x in [-ex + 0.14, -ex + 0.34]:
		box(root, Vector3(0.03, top, 0.03), Vector3(x, top * 0.5, ez + 0.04), dark)
	var rung := 0.12
	while rung < top:
		box(root, Vector3(0.22, 0.02, 0.02), Vector3(-ex + 0.24, rung, ez + 0.04), dark)
		rung += 0.14
	# Un petit fanion tout en haut.
	box(root, Vector3(0.03, 0.3, 0.03), Vector3(ex, top + 0.15, -ez), dark)
	box(root, Vector3(0.18, 0.1, 0.01), Vector3(ex - 0.1, top + 0.24, -ez), Color("b71c1c"))
	root.set_meta("anim", {})
	return root


## Des bougies, et leurs flammes (renvoyées pour les faire vaciller).
static func _candles(parent: Node3D, spots: Array, wax: Color, fire: Color) -> Array:
	var flames := []
	for at: Vector3 in spots:
		box(parent, Vector3(0.05, 0.16, 0.05), at + Vector3(0, 0.08, 0), wax)
		flames.append(box(parent, Vector3(0.04, 0.06, 0.04), at + Vector3(0, 0.2, 0), fire, true))
	return flames


# ---------------------------------------------------------------------------
# Le mobilier des salles (objets de plusieurs cases, voir dungeon_map.gd, _refurnish)
# ---------------------------------------------------------------------------

## Le modèle d'un objet de salle de « size » cases (x = largeur, y = profondeur),
## centré sur son milieu. « extra » : le remplissage du Trésor (0 à 3).
## Les modèles sont dessinés dans le sens « long = profondeur (z) », puis tournés
## d'un quart de tour si l'objet est posé dans l'autre sens.
static func furniture(type: int, size: Vector2i, extra := 0) -> Node3D:
	var root := Node3D.new()
	var inner := Node3D.new()
	root.add_child(inner)
	var short := float(mini(size.x, size.y))
	var long := float(maxi(size.x, size.y))
	if size.x > size.y:
		inner.rotation.y = PI / 2
	var anim := {"flames": [], "sways": []}
	var model_name: String = {Rooms.Type.TREASURY: "treasury_%d" % clampi(extra, 0, 3),
			Rooms.Type.LIBRARY: "library", Rooms.Type.WORKSHOP: "workshop", Rooms.Type.TRAINING: "training",
			Rooms.Type.TEMPLE: "temple"}.get(type, "")
	var model := _blender_room(model_name) if Vector2i(short, long) == Rooms.footprint(type) else null
	if model != null:
		# Le modèle Blender est fait à la taille de la salle (« footprint »).
		inner.add_child(model)
		root.set_meta("anim", model.get_meta("anim"))
		return root
	match type:
		Rooms.Type.TREASURY:
			_treasure_hoard(inner, short, long, extra, anim)
		Rooms.Type.LIBRARY:
			_library(inner, short, long, anim)
		Rooms.Type.WORKSHOP:
			_workshop(inner, short, long, anim)
		Rooms.Type.TRAINING:
			_arena(inner, short, long, anim)
		Rooms.Type.TEMPLE:
			_temple(inner, short, long, anim)
	root.set_meta("anim", anim)
	return root


## Le Trésor : un coffre ouvert et un tas d'or qui déborde, plus haut s'il est plein.
static func _treasure_hoard(node: Node3D, w: float, d: float, level: int, anim: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var chest_z := -d * 0.5 + 0.35
	box(node, Vector3(0.62, 0.36, 0.4), Vector3(0, 0.18, chest_z), Color("8d5a2b"))
	box(node, Vector3(0.64, 0.05, 0.42), Vector3(0, 0.1, chest_z), Color("546e7a"))
	box(node, Vector3(0.64, 0.05, 0.42), Vector3(0, 0.3, chest_z), Color("546e7a"))
	var lid := box(node, Vector3(0.62, 0.06, 0.4), Vector3(0, 0.5, chest_z - 0.2), Color("7a4a22"))
	lid.rotation.x = -1.1
	if level <= 0:
		return
	# Le tas d'or : des pièces en monticule, du coffre jusqu'au bout de la place.
	var coins := 10 + level * 14
	for i in coins:
		var t := rng.randf()
		var z := lerpf(chest_z + 0.15, d * 0.5 - 0.15, t)
		var spread := (1.0 - absf(t - 0.4)) * 0.35
		var height := (0.12 + 0.12 * level) * (1.0 - absf(t - 0.35) * 1.2)
		sphere(node, rng.randf_range(0.05, 0.09),
				Vector3(rng.randf_range(-spread, spread), maxf(0.04, rng.randf_range(0.0, height)), z),
				Color("f2b632"), true)
	# Quelques pièces qui débordent du coffre.
	for i in level * 3:
		sphere(node, 0.05, Vector3(rng.randf_range(-0.22, 0.22), 0.38, chest_z + rng.randf_range(-0.1, 0.1)),
				Color("ffd54a"), true)


## La Bibliothèque : deux rayonnages pleins de livres le long des grands côtés,
## un pupitre avec un livre ouvert et une bougie, un tapis rouge au milieu.
static func _library(node: Node3D, w: float, d: float, anim: Dictionary) -> void:
	var wood := Color("5d3a24")
	var colors := [Color("8e1b1b"), Color("1a3a6b"), Color("2e5b2a"), Color("8d6e00"), Color("4a148c"), Color("6d4c41")]
	box(node, Vector3(w * 0.36, 0.02, d - 0.4), Vector3(0, 0.011, 0), Color("7f1d2d"))  # tapis
	for side: int in [-1, 1]:
		var x := side * (w * 0.5 - 0.2)
		box(node, Vector3(0.3, 1.35, d - 0.2), Vector3(x, 0.675, 0), wood)   # le meuble
		var count := int((d - 0.3) / 0.38)
		for shelf in 4:
			var y := 0.18 + shelf * 0.31
			box(node, Vector3(0.32, 0.03, d - 0.2), Vector3(x, y - 0.03, 0), Color("3e2716"))
			for i in count:
				var z := -d * 0.5 + 0.3 + i * 0.38
				var height := 0.2 + 0.04 * ((i + shelf) % 3)
				box(node, Vector3(0.22, height, 0.33), Vector3(x - side * 0.03, y + height * 0.5, z),
						colors[(i * 3 + shelf * 2 + (1 if side > 0 else 0)) % colors.size()])
	# Le pupitre au milieu, avec un livre ouvert et une bougie.
	box(node, Vector3(0.5, 0.06, 0.4), Vector3(0, 0.62, 0), wood)
	box(node, Vector3(0.1, 0.6, 0.1), Vector3(0, 0.3, 0), wood)
	box(node, Vector3(0.34, 0.03, 0.26), Vector3(0, 0.67, 0), Color("efe6d8"))
	box(node, Vector3(0.04, 0.12, 0.04), Vector3(0.2, 0.72, 0.12), Color("f5f5f5"))
	anim["flames"].append(box(node, Vector3(0.04, 0.06, 0.04), Vector3(0.2, 0.81, 0.12), Color("ffb300"), true))


## L'Atelier : une forge aux braises rougeoyantes, une enclume, un établi et un tonneau.
static func _workshop(node: Node3D, w: float, d: float, anim: Dictionary) -> void:
	var stone := Color("4e4440")
	# La forge, dans un coin, avec sa hotte.
	box(node, Vector3(0.7, 0.55, 0.6), Vector3(-w * 0.5 + 0.45, 0.275, -d * 0.5 + 0.4), stone)
	var coals := box(node, Vector3(0.56, 0.05, 0.46), Vector3(-w * 0.5 + 0.45, 0.57, -d * 0.5 + 0.4),
			Color("ff6d00"), true)
	anim["flames"].append(coals)
	box(node, Vector3(0.5, 0.55, 0.4), Vector3(-w * 0.5 + 0.45, 1.15, -d * 0.5 + 0.35), Color("3a302c"))
	# L'enclume, au milieu.
	box(node, Vector3(0.22, 0.22, 0.22), Vector3(0.1, 0.11, 0.1), Color("795548"))
	box(node, Vector3(0.16, 0.12, 0.12), Vector3(0.1, 0.28, 0.1), Color("546e7a"))
	box(node, Vector3(0.44, 0.1, 0.18), Vector3(0.14, 0.39, 0.1), Color("78909c"))
	anim["flames"].append(box(node, Vector3(0.18, 0.03, 0.05), Vector3(0.1, 0.455, 0.1), Color("ff7043"), true))
	# L'établi avec ses outils, et un tonneau.
	box(node, Vector3(0.9, 0.08, 0.36), Vector3(w * 0.5 - 0.55, 0.55, d * 0.5 - 0.3), Color("6d4c41"))
	for x in [-0.35, 0.35]:
		box(node, Vector3(0.07, 0.5, 0.07), Vector3(w * 0.5 - 0.55 + x, 0.26, d * 0.5 - 0.3), Color("4e342e"))
	box(node, Vector3(0.3, 0.04, 0.06), Vector3(w * 0.5 - 0.65, 0.61, d * 0.5 - 0.3), Color("b0bec5"))
	box(node, Vector3(0.05, 0.04, 0.22), Vector3(w * 0.5 - 0.35, 0.61, d * 0.5 - 0.3), Color("8d6e63"))
	cylinder(node, 0.18, 0.18, 0.5, Vector3(-w * 0.5 + 0.3, 0.25, d * 0.5 - 0.3), Color("795548"))


## L'Entraînement : une arène sablée entourée d'une palissade, des mannequins
## et un râtelier d'armes.
static func _arena(node: Node3D, w: float, d: float, anim: Dictionary) -> void:
	var wood := Color("6d4c41")
	box(node, Vector3(w - 0.2, 0.02, d - 0.2), Vector3(0, 0.011, 0), Color("b8955a"))
	# La palissade : des poteaux et deux barres sur les grands côtés.
	for side: int in [-1, 1]:
		var x := side * (w * 0.5 - 0.12)
		for i in int(d / 0.5) + 1:
			box(node, Vector3(0.07, 0.42, 0.07), Vector3(x, 0.21, -d * 0.5 + 0.12 + i * (d - 0.24) / int(d / 0.5)), wood)
		box(node, Vector3(0.05, 0.05, d - 0.2), Vector3(x, 0.36, 0), wood)
		box(node, Vector3(0.05, 0.05, d - 0.2), Vector3(x, 0.2, 0), wood)
	# Deux mannequins qui se balancent.
	for z in [-d * 0.25, d * 0.25]:
		var sway := pivot(node, Vector3(0, 0, z), "sway")
		box(sway, Vector3(0.06, 0.45, 0.06), Vector3(0, 0.22, 0), wood)
		box(sway, Vector3(0.5, 0.06, 0.06), Vector3(0, 0.6, 0), wood)
		box(sway, Vector3(0.28, 0.32, 0.22), Vector3(0, 0.6, 0), Color("d4a85a"))
		box(sway, Vector3(0.18, 0.18, 0.18), Vector3(0, 0.86, 0), Color("d4a85a"))
		box(sway, Vector3(0.1, 0.1, 0.02), Vector3(0, 0.62, 0.12), Color("c62828"))
		anim["sways"].append(sway)
	# Le râtelier d'armes, au bout.
	box(node, Vector3(0.7, 0.06, 0.1), Vector3(0, 0.7, d * 0.5 - 0.18), wood)
	for i in 4:
		box(node, Vector3(0.03, 0.6, 0.02), Vector3(-0.24 + i * 0.16, 0.45, d * 0.5 - 0.22), Color("cfd8dc"))


## Le Temple : une estrade à marches, un autel drapé, un tapis rouge, deux
## braseros aux flammes vertes et une statue cornue.
static func _temple(node: Node3D, w: float, d: float, anim: Dictionary) -> void:
	var stone := Color("5f5a5f")
	box(node, Vector3(w * 0.34, 0.02, d - 0.6), Vector3(0, 0.011, 0.3), Color("7f1d2d"))     # tapis
	box(node, Vector3(w - 0.3, 0.12, 1.0), Vector3(0, 0.06, -d * 0.5 + 0.6), stone)          # estrade
	box(node, Vector3(w - 0.6, 0.12, 0.7), Vector3(0, 0.18, -d * 0.5 + 0.5), stone.lightened(0.1))
	box(node, Vector3(0.7, 0.42, 0.4), Vector3(0, 0.45, -d * 0.5 + 0.45), Color("78909c"))   # autel
	box(node, Vector3(0.3, 0.38, 0.02), Vector3(0, 0.45, -d * 0.5 + 0.66), Color("6a1b9a"))
	for x in [-0.28, 0.28]:
		box(node, Vector3(0.05, 0.14, 0.05), Vector3(x, 0.73, -d * 0.5 + 0.45), Color("f5f5f5"))
		anim["flames"].append(box(node, Vector3(0.04, 0.06, 0.04), Vector3(x, 0.83, -d * 0.5 + 0.45),
				Color("ffb300"), true))
	# La statue cornue derrière l'autel.
	box(node, Vector3(0.3, 0.6, 0.25), Vector3(0, 0.6, -d * 0.5 + 0.15), Color("4a4248"))
	box(node, Vector3(0.24, 0.24, 0.22), Vector3(0, 1.02, -d * 0.5 + 0.15), Color("4a4248"))
	for side: int in [-1, 1]:
		var horn := box(node, Vector3(0.05, 0.2, 0.05), Vector3(side * 0.12, 1.2, -d * 0.5 + 0.15), Color("cfc6b8"))
		horn.rotation.z = -0.5 * side
		box(node, Vector3(0.04, 0.03, 0.02), Vector3(side * 0.06, 1.04, -d * 0.5 + 0.27), Color("76ff03"), true)
	# Les braseros aux flammes vertes, de chaque côté du tapis.
	for x in [-w * 0.5 + 0.3, w * 0.5 - 0.3]:
		cylinder(node, 0.06, 0.06, 0.5, Vector3(x, 0.25, d * 0.15), Color("37474f"))
		cylinder(node, 0.18, 0.1, 0.12, Vector3(x, 0.55, d * 0.15), Color("455a64"))
		var flame := sphere(node, 0.13, Vector3(x, 0.68, d * 0.15), Color("76ff03"), true)
		anim["flames"].append(flame)

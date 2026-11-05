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
	var root := Node3D.new()
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


## Teinte et transparence : on remplace les matériaux de toutes les pièces.
static func _recolor(node: Node, tint: Color, alpha: float) -> void:
	for child in node.get_children():
		var part := child as MeshInstance3D
		if part != null and part.material_override is StandardMaterial3D:
			var old: StandardMaterial3D = part.material_override
			var color := old.albedo_color * Color(tint.r, tint.g, tint.b)
			part.material_override = material(color.clamp(), old.emission_enabled, alpha)
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
	for side in [-1, 1]:
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
		for side in [-1, 1]:
			var wing := pivot(body, Vector3(0.1 * side, 0.52, -0.1), "wing")
			wing.rotation.y = 0.5 * side
			box(wing, Vector3(0.4, 0.28, 0.02), Vector3(0.2 * side, 0.05, 0), _c(spec, "wings"))
			rig["wings"].append(wing)
	if spec.has("tail"):
		var tail := pivot(body, Vector3(0, 0.3, -0.1), "tail")
		box(tail, Vector3(0.07, 0.07, 0.3), Vector3(0, -0.03, -0.15), _c(spec, "tail"))
		rig["tail"] = tail
	# Les bras (pivots aux épaules), avec les mains.
	for side in [-1, 1]:
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
	for side in [-1, 1]:
		box(head, Vector3(0.05, 0.04, 0.02), Vector3(0.06 * side, 0.02, 0.125), eyes, glowing)
	match kind:
		"ears":
			for side in [-1, 1]:
				box(head, Vector3(0.14, 0.06, 0.04), Vector3(0.18 * side, 0.03, 0), skin)
		"horns":
			for side in [-1, 1]:
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
		for side in [-1, 1]:
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
	for side in [-1, 1]:
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
	for side in [-1, 1]:
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
		for side in [-1, 1]:
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


## Des bougies, et leurs flammes (renvoyées pour les faire vaciller).
static func _candles(parent: Node3D, spots: Array, wax: Color, fire: Color) -> Array:
	var flames := []
	for at: Vector3 in spots:
		box(parent, Vector3(0.05, 0.16, 0.05), at + Vector3(0, 0.08, 0), wax)
		flames.append(box(parent, Vector3(0.04, 0.06, 0.04), at + Vector3(0, 0.2, 0), fire, true))
	return flames

class_name LordPortrait
extends Control
## Le portrait animé du Seigneur des Profondeurs, en haut à gauche du HUD.
##
## Un visage de démon en 3D « low-poly » (facettes plates), modélisé dans Blender
## (tools/blender/lord.py -> assets/models/lord.glb), rendu en direct dans un petit
## monde 3D à part (SubViewport), au centre d'un médaillon HD lui aussi fait dans
## Blender (tools/blender/hud.py -> assets/ui_hd/medallion.png). Sans ces fichiers,
## on retombe sur le visage construit en code (_build_face) et le cadre dessiné.
## Il réagit à ce qui se passe sur la carte (voir react, appelé par hud.gd pour
## chaque message du journal) : colère, joie, inquiétude ; au repos il cligne
## des yeux, regarde autour de lui, souffle de la fumée, frémit des oreilles,
## retrousse une babine ou se lèche les crocs. Pupilles fendues qui suivent le
## regard, naseaux qui se dilatent, langue fourchue qui sort quand il rit. Il parle dans une
## bulle (say), d'une voix grave et caverneuse (assets/voice/, fabriquée par
## tools/generate_voice.py), et sa mâchoire bouge en rythme. Le toucher demande
## un conseil (signal advice_requested).

signal advice_requested

enum Mood { IDLE, ANGRY, HAPPY, WORRIED }

const SIZE := 132.0          ## Taille du médaillon, en pixels.
const MODEL := "res://assets/models/lord.glb"
## Le cadre HD : son bord extérieur et l'ouverture du visage, en fractions de la
## demi-largeur de l'image (OUTER et INNER de tools/blender/hud.py).
const FRAME_OUTER := 0.955 / 1.25
const FRAME_INNER := 0.708 / 1.25
const MOOD_TIME := 3.5       ## Secondes pendant lesquelles une émotion dure.
const BUBBLE_TIME := 3.0     ## Secondes d'affichage d'une réplique.

## Couleurs du visage.
const SKIN := Color("9c1f1f")
const SKIN_DARK := Color("5e0f12")
const HORN := Color("e8dcc0")
const HORN_TIP := Color("3a2a22")

## Les répliques, par émotion (une au hasard).
const LINES := {
	Mood.ANGRY: ["Des intrus !", "Qu'ils périssent !", "Mon donjon ! Défendez-le !", "Grrr..."],
	Mood.HAPPY: ["Ha ha ha !", "Excellent...", "Mon or !", "Délicieux.", "Encore !"],
	Mood.WORRIED: ["Hmm...", "Ça ne me plaît pas.", "Fais attention...", "Ennuyeux."],
}

## Les voix : assets/voice/<12 premiers caractères du MD5 du texte>.ogg.
const VOICE_PATH := "res://assets/voice/%s.ogg"
## Répliques qui changent (un nombre dedans) : la voix dit une phrase fixe à la
## place (même table que ALIASES dans tools/generate_voice.py).
const VOICE_ALIASES := {
	"Des héros arrivent dans": "Des héros arrivent bientôt. Prépare pièges et portes !",
}

var mood: int = Mood.IDLE
var _mood_left := 0.0
var _time := 0.0
var _blink := 0.0            ## > 0 : les paupières sont fermées.
var _next_blink := 2.0
var _look := Vector2.ZERO    ## Où il regarde (de -1 à 1).
var _look_target := Vector2.ZERO
var _next_look := 1.5
var _next_smoke := 4.0
var _smoke: Array[MeshInstance3D] = []
var _smoke_from := Vector3(0, -0.08, 0.5) ## D'où part la fumée (les naseaux).
var _next_twitch := 2.5      ## Prochain frémissement d'oreille.
var _twitch := 0.0           ## > 0 : une oreille frémit.
var _twitch_side := 0
var _next_sneer := 5.0       ## Prochaine babine retroussée (au repos).
var _sneer := 0.0
var _sneer_side := 0
var _next_lick := 9.0        ## Prochain coup de langue (au repos).
var _lick := 0.0

var _viewport: SubViewport
var _head: Node3D            ## Tout le visage (il bouge d'un bloc).
var _jaw: Node3D             ## La mâchoire (s'ouvre pour rire ou rugir).
var _brows: Array[Node3D] = []
var _lids: Array[Node3D] = []
## Les pièces ajoutées par le modèle Blender (vides avec le visage en code).
var _pupils: Array[Node3D] = []
var _lips: Array[Node3D] = []
var _nostrils: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _tongue: Node3D
## La pose de départ de chaque pièce animée [position, rotation], pour bouger autour.
var _rest := {}
var _glow: Control           ## Le fond rougeoyant, qui découpe aussi le visage en rond.
var _frame: TextureRect      ## Le cadre HD (null : cadre dessiné dans _draw).
var _eye_material: StandardMaterial3D
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_left := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_viewport()
	_build_bubble()


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build_viewport() -> void:
	var frame_texture := Ui.hd_texture("medallion")
	# L'ouverture du médaillon : le fond rougeoyant y est dessiné, et le visage y est
	# découpé en rond (clip_children : les enfants ne débordent pas du disque).
	var opening := SIZE * 0.5 - 10.0
	if frame_texture != null:
		opening = SIZE * 0.5 * (FRAME_INNER / FRAME_OUTER) + 2.0
	_glow = Control.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.position = Vector2(SIZE, SIZE) * 0.5 - Vector2(opening, opening)
	_glow.size = Vector2(opening, opening) * 2.0
	_glow.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	# Le visage est rendu en double résolution puis réduit : net sur téléphone.
	var container := SubViewportContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.size = _glow.size * 2.0
	container.scale = Vector2(0.5, 0.5)
	_glow.add_child(container)
	if frame_texture != null:
		# Le cadre HD par-dessus : son bord extérieur tombe sur le bord du contrôle
		# (les cornes et le crâne dépassent un peu).
		_frame = TextureRect.new()
		_frame.texture = frame_texture
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frame.size = Vector2(SIZE, SIZE) / FRAME_OUTER
		_frame.position = (Vector2(SIZE, SIZE) - _frame.size) * 0.5
		add_child(_frame)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true # Son propre petit monde : rien à voir avec la carte.
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(container.size)
	container.add_child(_viewport)

	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.position = Vector3(0, 0.12, 2.75)
	_viewport.add_child(camera)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.85, 0.7)
	key.light_energy = 1.3
	key.rotation_degrees = Vector3(-30, -35, 0)
	_viewport.add_child(key)
	var rim := OmniLight3D.new() # Une lueur de braise par en dessous.
	rim.light_color = Color(1.0, 0.35, 0.1)
	rim.light_energy = 2.0
	rim.omni_range = 3.0
	rim.position = Vector3(0.4, -0.9, 0.8)
	_viewport.add_child(rim)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.35, 0.2, 0.2)
	_viewport.add_child(environment)

	if not _load_model():
		_head = Node3D.new()
		_viewport.add_child(_head)
		_build_face()
	for node: Node3D in _brows + _pupils + _lips + _nostrils + _ears:
		_rest[node] = [node.position, node.rotation]
	if _tongue != null:
		_rest[_tongue] = [_tongue.position, _tongue.rotation]
	for lid in _lids:
		lid.scale.y = 0.05 # Les paupières démarrent ouvertes.
	_build_smoke()


## Le visage modélisé dans Blender (assets/models/lord.glb) : on retrouve ses pièces
## mobiles par le nom de leur pivot (voir tools/blender/lord.py). Faux s'il manque.
func _load_model() -> bool:
	if not ResourceLoader.exists(MODEL):
		return false
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	_head = model.find_child("head") as Node3D
	_jaw = model.find_child("jaw") as Node3D
	if _head == null or _jaw == null:
		model.free()
		return false
	_viewport.add_child(model)
	_eye_material = _material(Color("ffd54a"), true)
	for side: String in ["_l", "_r"]:
		_brows.append(model.find_child("brow" + side) as Node3D)
		_lids.append(model.find_child("lid" + side) as Node3D)
		_pupils.append(model.find_child("pupil" + side) as Node3D)
		_lips.append(model.find_child("lip" + side) as Node3D)
		_nostrils.append(model.find_child("nostril" + side) as Node3D)
		_ears.append(model.find_child("ear" + side) as Node3D)
		# Les yeux : leur matériau change de couleur avec l'humeur.
		for child in (model.find_child("eye" + side) as Node3D).get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = _eye_material
	_tongue = model.find_child("tongue") as Node3D
	var smoke_point := model.find_child("smoke") as Node3D
	if smoke_point != null:
		_smoke_from = smoke_point.position
	return true


func _build_face() -> void:
	# Le crâne, un peu allongé, et les pommettes.
	_part(_head, _sphere(0.5, 9, 6), Vector3(0, 0.08, 0), SKIN, Vector3(0.92, 1.05, 0.9))
	_part(_head, _sphere(0.22, 6, 4), Vector3(-0.24, -0.12, 0.3), SKIN, Vector3(1.0, 0.8, 0.7))
	_part(_head, _sphere(0.22, 6, 4), Vector3(0.24, -0.12, 0.3), SKIN, Vector3(1.0, 0.8, 0.7))
	# Le nez crochu.
	var nose := _part(_head, _cone(0.09, 0.0, 0.26, 4), Vector3(0, -0.02, 0.46), SKIN_DARK)
	nose.rotation_degrees = Vector3(70, 0, 0)
	# Les oreilles pointues.
	for side: int in [-1, 1]:
		var ear := _part(_head, _cone(0.1, 0.0, 0.4, 4), Vector3(side * 0.46, 0.08, -0.02), SKIN_DARK)
		ear.rotation_degrees = Vector3(0, 0, -side * 75)
	# Les cornes : deux segments qui s'incurvent vers l'arrière.
	for side: int in [-1, 1]:
		var base := Node3D.new()
		base.position = Vector3(side * 0.28, 0.42, -0.02)
		base.rotation_degrees = Vector3(-20, 0, -side * 35)
		_head.add_child(base)
		_part(base, _cone(0.11, 0.07, 0.32, 6), Vector3(0, 0.16, 0), HORN)
		var tip := _part(base, _cone(0.07, 0.0, 0.34, 6), Vector3(0, 0.42, -0.06), HORN_TIP)
		tip.rotation_degrees = Vector3(-35, 0, side * 10)
	# Les yeux qui brillent, et leurs paupières.
	_eye_material = _material(Color("ffd54a"), true)
	for side: int in [-1, 1]:
		_part(_head, _sphere(0.1, 6, 4), Vector3(side * 0.18, 0.1, 0.38), Color("1a0505"), Vector3(1.2, 0.8, 0.5))
		var eye := MeshInstance3D.new()
		eye.mesh = _sphere(0.065, 6, 4)
		eye.material_override = _eye_material
		eye.position = Vector3(side * 0.18, 0.1, 0.43)
		eye.scale = Vector3(1.1, 0.75, 0.6)
		_head.add_child(eye)
		var lid := Node3D.new()
		lid.position = Vector3(side * 0.18, 0.17, 0.44)
		_head.add_child(lid)
		_part(lid, _box(Vector3(0.2, 0.1, 0.06)), Vector3(0, -0.04, 0), SKIN)
		lid.scale = Vector3(1, 0.05, 1)
		_lids.append(lid)
		# Les sourcils : des arêtes osseuses qui bougent avec les émotions.
		var brow := Node3D.new()
		brow.position = Vector3(side * 0.18, 0.24, 0.42)
		_head.add_child(brow)
		_part(brow, _box(Vector3(0.24, 0.06, 0.1)), Vector3.ZERO, SKIN_DARK)
		_brows.append(brow)
	# La bouche : une fente sombre, des crocs, et la mâchoire (avec un bouc).
	_part(_head, _box(Vector3(0.36, 0.08, 0.1)), Vector3(0, -0.24, 0.36), Color("1a0505"))
	for x in [-0.12, 0.12]:
		var fang := _part(_head, _cone(0.035, 0.0, 0.1, 4), Vector3(x, -0.26, 0.4), Color("f5f0e0"))
		fang.rotation_degrees = Vector3(180, 0, 0)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.24, 0.05)
	_head.add_child(_jaw)
	_part(_jaw, _sphere(0.3, 7, 4), Vector3(0, -0.1, 0.12), SKIN, Vector3(1.05, 0.55, 1.0))
	var goatee := _part(_jaw, _cone(0.08, 0.0, 0.26, 5), Vector3(0, -0.3, 0.28), Color("2a0a0a"))
	goatee.rotation_degrees = Vector3(180, 0, 0)


## La fumée des naseaux : quelques volutes réutilisées.
func _build_smoke() -> void:
	for i in 4:
		var puff := MeshInstance3D.new()
		puff.mesh = _faceted(_sphere(0.06, 6, 4))
		puff.material_override = _material(Color(0.5, 0.45, 0.45), false, 0.0)
		puff.visible = false
		_head.add_child(puff)
		_smoke.append(puff)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.03, 0.02, 0.92)
	style.border_color = Color("c0392b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.corner_radius_top_left = 2
	style.set_content_margin_all(8)
	var hd := Ui.hd_frame("bubble", 10) # Le cadre HD de Blender, s'il existe.
	_bubble.add_theme_stylebox_override("panel", hd if hd != null else style)
	_bubble.position = Vector2(SIZE - 6.0, SIZE * 0.62)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_size_override("font_size", 20)
	_bubble_label.add_theme_color_override("font_color", Color("ffcc80"))
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size.x = 240
	_bubble.add_child(_bubble_label)
	_bubble.visible = false
	add_child(_bubble)


## Une pièce du visage : un maillage à facettes plates, de couleur unie.
func _part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, scale_by := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = _faceted(mesh)
	part.material_override = _material(color)
	part.position = at
	part.scale = scale_by
	parent.add_child(part)
	return part


func _material(color: Color, glow := false, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = 0.75
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Le style « low-poly » : chaque triangle a sa propre normale (facettes nettes).
func _faceted(mesh: Mesh) -> Mesh:
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()


func _sphere(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


func _cone(bottom: float, top: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _box(box_size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return mesh


# ---------------------------------------------------------------------------
# Le médaillon (dessiné en 2D autour du visage)
# ---------------------------------------------------------------------------

## Le fond de l'ouverture : un creux sombre qui rougeoie selon l'humeur (il
## découpe aussi le visage en rond, voir _build_viewport).
func _draw_glow() -> void:
	var radius := _glow.size.x * 0.5
	var center := Vector2(radius, radius)
	var glow := Color(0.35, 0.05, 0.02)
	match mood:
		Mood.ANGRY:
			glow = Color(0.7, 0.05, 0.02)
		Mood.HAPPY:
			glow = Color(0.55, 0.32, 0.02)
		Mood.WORRIED:
			glow = Color(0.25, 0.08, 0.3)
	_glow.draw_circle(center, radius, Color(0.03, 0.01, 0.01))
	for i in 6:
		var t := float(i) / 6.0
		_glow.draw_circle(center + Vector2(0, radius * 0.25), radius * (1.0 - t * 0.8), Color(glow, 0.12 + t * 0.06))


## Le cadre dessiné, si l'image HD du médaillon n'existe pas.
func _draw() -> void:
	if _frame != null:
		return
	var center := Vector2(SIZE, SIZE) * 0.5
	var radius := SIZE * 0.5
	# L'anneau de pierre, le liseré de fer et les rivets.
	draw_arc(center, radius - 5.0, 0.0, TAU, 48, Color("3b2a24"), 10.0, true)
	draw_arc(center, radius - 5.0, 0.0, TAU, 48, Color("6d4c41"), 3.0, true)
	draw_arc(center, radius - 11.0, 0.0, TAU, 48, Color("1a0f0c"), 2.0, true)
	draw_arc(center, radius - 1.5, 0.0, TAU, 48, Color("c0392b").darkened(0.3), 2.0, true)
	for i in 8:
		var angle := TAU * i / 8.0 + PI / 8.0
		var at := center + Vector2(cos(angle), sin(angle)) * (radius - 5.0)
		draw_circle(at, 4.0, Color("8d6e63"))
		draw_circle(at - Vector2(1, 1), 1.6, Color("d7ccc8"))
	# Deux petites cornes de fer sur le haut du cadre.
	for side: int in [-1, 1]:
		var base := center + Vector2(side * radius * 0.55, -radius * 0.78)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 4), base + Vector2(6, 4),
				base + Vector2(side * 10, -16)]), Color("4e342e"))


# ---------------------------------------------------------------------------
# Animation et réactions
# ---------------------------------------------------------------------------

## Réagit à un message du journal. kind : la sorte du message (voir hud.gd,
## MESSAGE_KINDS) : "!" attaque, "?" conseil ou erreur, "$" or, "*" savoir, "+" arrivée.
func react(kind: String, speak := true) -> void:
	var new_mood: int = {"!": Mood.ANGRY, "?": Mood.WORRIED, "$": Mood.HAPPY, "*": Mood.HAPPY,
			"+": Mood.HAPPY}.get(kind, -1)
	if new_mood < 0:
		return
	# Une émotion forte (la colère) n'est pas effacée par une petite joie.
	if mood == Mood.ANGRY and _mood_left > 1.0 and new_mood != Mood.ANGRY:
		return
	mood = new_mood
	_mood_left = MOOD_TIME
	_glow.queue_redraw()
	if speak and randf() < 0.6 and (_bubble_left <= 0.0 or new_mood == Mood.ANGRY):
		say(LINES[new_mood].pick_random())


## Une réplique dans la bulle, à côté du médaillon.
func say(text: String, duration := BUBBLE_TIME) -> void:
	_bubble_label.text = text
	_bubble.visible = true
	_bubble.reset_size()
	var spoken := Sound.play_voice(_voice_for(text))
	_bubble_left = maxf(duration, spoken + 0.4) # La bulle reste tant qu'il parle.


## La voix enregistrée d'une réplique, ou null s'il n'y en a pas.
func _voice_for(text: String) -> AudioStream:
	for prefix: String in VOICE_ALIASES:
		if text.begins_with(prefix):
			text = VOICE_ALIASES[prefix]
	var path := VOICE_PATH % text.md5_text().substr(0, 12)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		accept_event()
		advice_requested.emit()


func _process(delta: float) -> void:
	_time += delta
	if _mood_left > 0.0:
		_mood_left -= delta
		if _mood_left <= 0.0:
			mood = Mood.IDLE
			_glow.queue_redraw()
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0:
			_bubble.visible = false
	_animate(delta)


func _animate(delta: float) -> void:
	var t := _time
	# Le regard : de temps en temps, il tourne la tête vers un autre point.
	_next_look -= delta
	if _next_look <= 0.0:
		_next_look = randf_range(1.2, 3.5)
		_look_target = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) if mood == Mood.IDLE else Vector2.ZERO
		if mood == Mood.WORRIED: # Inquiet, il jette des coups d'œil de côté.
			_look_target = Vector2(randf_range(-1, 1), 0.0)
	_look = _look.lerp(_look_target, minf(1.0, delta * 4.0))
	# Le clignement des yeux.
	_next_blink -= delta
	if _next_blink <= 0.0:
		_next_blink = randf_range(2.0, 5.0)
		_blink = 0.14
	_blink = maxf(0.0, _blink - delta)
	_animate_tics(delta)

	var head_rot := Vector3(-_look.y * 0.15, _look.x * 0.35, 0.0)
	var head_pos := Vector3(0, sin(t * 1.6) * 0.02, 0)
	var jaw_open := 0.05 + 0.03 * sin(t * 1.3)
	var brow_tilt := 0.12  # > 0 : sourcils froncés (colère), < 0 : relevés (inquiétude).
	var brow_height := 0.0
	var lid := 0.18        # Toujours un peu mi-clos : un regard mauvais.
	var eye_color := Color("ffd54a")
	var snarl := 0.15      # Babines retroussées (0 à 1).
	var flare := 0.08 + 0.08 * (0.5 + 0.5 * sin(t * 1.6)) # Les naseaux respirent.
	var tongue_out := _lick
	var pupil_width := 1.0 # < 1 : pupilles fendues, > 1 : dilatées.
	var ears := Vector2(0.0, 0.0) # x : couchées en arrière, y : dressées.
	match mood:
		Mood.ANGRY:
			jaw_open = 0.35 + 0.1 * sin(t * 18.0) # Il rugit.
			head_pos.x = sin(t * 30.0) * 0.012
			head_pos.z = 0.06 # Il avance la tête vers toi.
			head_rot.x = 0.12
			brow_tilt = 0.5
			brow_height = -0.035
			lid = 0.35
			eye_color = Color("ff3d00")
			snarl = 1.0
			flare = 0.4 + 0.12 * sin(t * 14.0)
			pupil_width = 0.45
			ears = Vector2(0.55, -0.1)
		Mood.HAPPY:
			jaw_open = 0.18 + 0.14 * absf(sin(t * 10.0)) # Il rit.
			head_rot.x = -0.15 + 0.06 * sin(t * 10.0)
			head_pos.y += absf(sin(t * 10.0)) * 0.03
			brow_tilt = 0.15
			brow_height = 0.03
			lid = 0.3
			eye_color = Color("ffe082")
			snarl = 0.55
			tongue_out = maxf(tongue_out, 0.6 + 0.25 * sin(t * 10.0))
			ears = Vector2(0.0, 0.3)
		Mood.WORRIED:
			jaw_open = 0.04
			head_rot.z = 0.1 * sin(t * 2.0)
			brow_tilt = -0.4
			brow_height = 0.04
			lid = 0.08
			eye_color = Color("ffb74d")
			snarl = 0.0
			pupil_width = 1.9
			ears = Vector2(0.3, -0.25)
	# Quand il parle, la mâchoire suit le volume de sa voix.
	var voice := Sound.voice_level()
	if voice > 0.0:
		jaw_open = maxf(jaw_open * 0.5, 0.04 + voice * 0.42)
		snarl = maxf(snarl, voice * 0.8)
	if tongue_out > 0.0:
		jaw_open = maxf(jaw_open, 0.12 + tongue_out * 0.12)
	if _blink > 0.0:
		lid = 1.0
	var k := minf(1.0, delta * 10.0)
	_head.rotation = _head.rotation.lerp(head_rot, minf(1.0, delta * 8.0))
	_head.position = _head.position.lerp(head_pos, minf(1.0, delta * 15.0))
	_jaw.rotation.x = lerpf(_jaw.rotation.x, jaw_open, minf(1.0, delta * 12.0))
	for i in _brows.size():
		var side := -1.0 if i == 0 else 1.0
		var rest: Array = _rest[_brows[i]]
		_brows[i].rotation.z = lerpf(_brows[i].rotation.z, rest[1].z - side * brow_tilt, k)
		_brows[i].position.y = lerpf(_brows[i].position.y, rest[0].y + brow_height, k)
	for eyelid in _lids:
		eyelid.scale.y = lerpf(eyelid.scale.y, maxf(lid, 0.05), minf(1.0, delta * 25.0))
	# Les pupilles suivent le regard, se fendent de colère, se dilatent d'inquiétude.
	for pupil in _pupils:
		var rest: Array = _rest[pupil]
		pupil.position = pupil.position.lerp(rest[0] + Vector3(_look.x * 0.035, _look.y * 0.012, 0.0), k)
		pupil.scale.x = lerpf(pupil.scale.x, pupil_width, k)
	# Les babines : chaque moitié se relève (côté du croc), plus fort du côté du rictus.
	for i in _lips.size():
		var side := -1.0 if i == 0 else 1.0
		var amount := snarl
		if _sneer > 0.0 and i == _sneer_side:
			amount = maxf(amount, sin(minf(_sneer, 0.9) / 0.9 * PI) * 0.9)
		var rest: Array = _rest[_lips[i]]
		_lips[i].rotation.x = lerpf(_lips[i].rotation.x, rest[1].x - amount * 0.45, k)
		_lips[i].rotation.z = lerpf(_lips[i].rotation.z, rest[1].z + side * amount * 0.35, k)
	for nostril in _nostrils:
		nostril.scale = nostril.scale.lerp(Vector3.ONE * (1.0 + flare), k)
	# Les oreilles : couchées (colère), dressées (joie), et un frémissement de temps en temps.
	for i in _ears.size():
		var side := -1.0 if i == 0 else 1.0
		var twitch := 0.0
		if _twitch > 0.0 and i == _twitch_side:
			twitch = sin(_twitch * 40.0) * 0.25 * minf(1.0, _twitch * 4.0)
		var rest: Array = _rest[_ears[i]]
		_ears[i].rotation.y = lerpf(_ears[i].rotation.y, rest[1].y + side * ears.x, k)
		_ears[i].rotation.z = rest[1].z + side * (ears.y + twitch) + side * 0.03 * sin(t * 1.6)
	# La langue fourchue : elle sort et ondule.
	if _tongue != null:
		var rest: Array = _rest[_tongue]
		_tongue.position = _tongue.position.lerp(rest[0] + Vector3(0.0, -0.02, 0.17) * tongue_out, k)
		_tongue.rotation.x = lerpf(_tongue.rotation.x, rest[1].x + tongue_out * 0.35, k)
		_tongue.rotation.y = rest[1].y + sin(t * 16.0) * 0.35 * tongue_out
	_eye_material.albedo_color = _eye_material.albedo_color.lerp(eye_color, minf(1.0, delta * 6.0))
	_eye_material.emission = _eye_material.albedo_color
	_eye_material.emission_energy_multiplier = 2.0 + (1.5 if mood == Mood.ANGRY else 0.0) \
			+ 0.4 * sin(t * 3.0)
	_animate_smoke(delta)


## Les petits tics au repos : une oreille qui frémit, une babine qui se retrousse,
## un coup de langue sur les crocs.
func _animate_tics(delta: float) -> void:
	_twitch = maxf(0.0, _twitch - delta)
	_sneer = maxf(0.0, _sneer - delta)
	_lick = maxf(0.0, _lick - delta * 1.5)
	_next_twitch -= delta
	if _next_twitch <= 0.0:
		_next_twitch = randf_range(2.0, 6.0)
		_twitch = 0.35
		_twitch_side = randi() % 2
	if mood != Mood.IDLE:
		return
	_next_sneer -= delta
	if _next_sneer <= 0.0:
		_next_sneer = randf_range(5.0, 10.0)
		_sneer = 0.9
		_sneer_side = randi() % 2
	_next_lick -= delta
	if _next_lick <= 0.0:
		_next_lick = randf_range(8.0, 16.0)
		_lick = 1.0


## Il souffle de la fumée par les naseaux : de petites volutes grises au repos (ou
## inquiet), des jets rougeoyants et rapprochés quand il est en colère.
func _animate_smoke(delta: float) -> void:
	_next_smoke -= delta
	if _next_smoke <= 0.0 and mood != Mood.HAPPY:
		var angry := mood == Mood.ANGRY
		_next_smoke = randf_range(0.5, 0.9) if angry else randf_range(3.0, 6.0)
		for i in _smoke.size():
			var puff := _smoke[i]
			puff.visible = true
			puff.position = _smoke_from + Vector3((i % 2 - 0.5) * 0.1, 0.0, 0.0)
			puff.scale = Vector3.ONE
			puff.set_meta("age", -i * (0.08 if angry else 0.2))
			puff.set_meta("side", 1.0 if i % 2 == 1 else -1.0)
			var material := puff.material_override as StandardMaterial3D
			var color := Color(0.45, 0.12, 0.08) if angry else Color(0.5, 0.45, 0.45)
			material.albedo_color = Color(color, 0.0)
		for nostril in _nostrils: # Les naseaux se gonflent au moment du souffle.
			nostril.scale = Vector3.ONE * 1.6
	for puff in _smoke:
		if not puff.visible:
			continue
		var age: float = puff.get_meta("age", 0.0) + delta
		puff.set_meta("age", age)
		if age < 0.0:
			continue
		# Le souffle part vers le bas et en avant, s'écarte, puis la fumée monte.
		var side: float = puff.get_meta("side", 1.0)
		puff.position += Vector3(side * 0.08, -0.2 + age * 0.5, 0.3) * delta
		puff.scale = Vector3.ONE * (1.0 + age * 2.5)
		var material := puff.material_override as StandardMaterial3D
		material.albedo_color.a = clampf(0.6 - age * 0.45, 0.0, 0.6)
		if age > 1.4:
			puff.visible = false

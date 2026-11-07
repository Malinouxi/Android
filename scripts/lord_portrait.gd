class_name LordPortrait
extends Control
## Le portrait animé du Seigneur des Profondeurs, en haut à gauche du HUD.
##
## Un visage de démon en 3D « low-poly » (facettes plates), rendu en direct dans
## un petit monde 3D à part (SubViewport), au centre d'un médaillon gothique.
## Il réagit à ce qui se passe sur la carte (voir react, appelé par hud.gd pour
## chaque message du journal) : colère, joie, inquiétude ; au repos il cligne
## des yeux, regarde autour de lui et souffle de la fumée. Il parle dans une
## bulle (say), d'une voix grave et caverneuse (assets/voice/, fabriquée par
## tools/generate_voice.py), et sa mâchoire bouge en rythme. Le toucher demande
## un conseil (signal advice_requested).

signal advice_requested

enum Mood { IDLE, ANGRY, HAPPY, WORRIED }

const SIZE := 120.0          ## Taille du médaillon, en pixels.
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

var _viewport: SubViewport
var _head: Node3D            ## Tout le visage (il bouge d'un bloc).
var _jaw: Node3D             ## La mâchoire (s'ouvre pour rire ou rugir).
var _brows: Array[Node3D] = []
var _lids: Array[Node3D] = []
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
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := 12.0
	container.position = Vector2(inset, inset)
	container.size = Vector2(SIZE - inset * 2.0, SIZE - inset * 2.0)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true # Son propre petit monde : rien à voir avec la carte.
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.size = Vector2i(container.size)
	container.add_child(_viewport)

	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.position = Vector3(0, 0.05, 2.5)
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

	_head = Node3D.new()
	_viewport.add_child(_head)
	_build_face()


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
	# La fumée des naseaux (au repos).
	for i in 3:
		var puff := MeshInstance3D.new()
		puff.mesh = _sphere(0.06, 5, 3)
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
	_bubble.add_theme_stylebox_override("panel", style)
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

func _draw() -> void:
	var center := Vector2(SIZE, SIZE) * 0.5
	var radius := SIZE * 0.5
	# Le fond : un creux sombre qui rougeoie selon l'humeur.
	var glow := Color(0.35, 0.05, 0.02)
	match mood:
		Mood.ANGRY:
			glow = Color(0.7, 0.05, 0.02)
		Mood.HAPPY:
			glow = Color(0.55, 0.32, 0.02)
		Mood.WORRIED:
			glow = Color(0.25, 0.08, 0.3)
	draw_circle(center, radius - 4.0, Color(0.03, 0.01, 0.01))
	for i in 6:
		var t := float(i) / 6.0
		draw_circle(center + Vector2(0, radius * 0.2), (radius - 10.0) * (1.0 - t * 0.8),
				Color(glow, 0.12 + t * 0.06))
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
	queue_redraw()
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
			queue_redraw()
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
	_look = _look.lerp(_look_target, minf(1.0, delta * 4.0))
	# Le clignement des yeux.
	_next_blink -= delta
	if _next_blink <= 0.0:
		_next_blink = randf_range(2.0, 5.0)
		_blink = 0.14
	_blink = maxf(0.0, _blink - delta)

	var head_rot := Vector3(-_look.y * 0.15, _look.x * 0.35, 0.0)
	var head_pos := Vector3(0, sin(t * 1.6) * 0.02, 0)
	var jaw_open := 0.05 + 0.03 * sin(t * 1.3)
	var brow_tilt := 0.0  # > 0 : sourcils froncés (colère), < 0 : relevés (inquiétude).
	var brow_height := 0.0
	var lid := 0.05
	var eye_color := Color("ffd54a")
	match mood:
		Mood.ANGRY:
			jaw_open = 0.35 + 0.1 * sin(t * 18.0) # Il rugit.
			head_pos.x = sin(t * 30.0) * 0.012
			head_rot.x = 0.12
			brow_tilt = 0.45
			brow_height = -0.03
			lid = 0.35
			eye_color = Color("ff3d00")
		Mood.HAPPY:
			jaw_open = 0.18 + 0.14 * absf(sin(t * 10.0)) # Il rit.
			head_rot.x = -0.15 + 0.06 * sin(t * 10.0)
			head_pos.y += absf(sin(t * 10.0)) * 0.03
			brow_tilt = 0.1
			brow_height = 0.03
			lid = 0.3
			eye_color = Color("ffe082")
		Mood.WORRIED:
			jaw_open = 0.04
			head_rot.z = 0.1 * sin(t * 2.0)
			brow_tilt = -0.4
			brow_height = 0.04
			eye_color = Color("ffb74d")
	# Quand il parle, la mâchoire suit le volume de sa voix.
	var voice := Sound.voice_level()
	if voice > 0.0:
		jaw_open = maxf(jaw_open * 0.5, 0.04 + voice * 0.42)
	if _blink > 0.0:
		lid = 1.0
	_head.rotation = _head.rotation.lerp(head_rot, minf(1.0, delta * 8.0))
	_head.position = head_pos
	_jaw.rotation.x = lerpf(_jaw.rotation.x, jaw_open, minf(1.0, delta * 12.0))
	for i in _brows.size():
		var side := -1.0 if i == 0 else 1.0
		_brows[i].rotation.z = lerpf(_brows[i].rotation.z, -side * brow_tilt, minf(1.0, delta * 10.0))
		_brows[i].position.y = lerpf(_brows[i].position.y, 0.24 + brow_height, minf(1.0, delta * 10.0))
	for eyelid in _lids:
		eyelid.scale.y = lerpf(eyelid.scale.y, maxf(lid, 0.05), minf(1.0, delta * 25.0))
	_eye_material.albedo_color = _eye_material.albedo_color.lerp(eye_color, minf(1.0, delta * 6.0))
	_eye_material.emission = _eye_material.albedo_color
	_eye_material.emission_energy_multiplier = 2.0 + (1.5 if mood == Mood.ANGRY else 0.0) \
			+ 0.4 * sin(t * 3.0)
	_animate_smoke(delta)


## Au repos (ou inquiet), il souffle de petites volutes de fumée par les naseaux.
func _animate_smoke(delta: float) -> void:
	_next_smoke -= delta
	if _next_smoke <= 0.0 and (mood == Mood.IDLE or mood == Mood.WORRIED):
		_next_smoke = randf_range(3.0, 6.0)
		for i in _smoke.size():
			var puff := _smoke[i]
			puff.visible = true
			puff.position = Vector3((i - 1) * 0.05, -0.08, 0.5)
			puff.set_meta("age", -i * 0.2)
	for puff in _smoke:
		if not puff.visible:
			continue
		var age: float = puff.get_meta("age", 0.0) + delta
		puff.set_meta("age", age)
		if age < 0.0:
			continue
		puff.position += Vector3(0.0, 0.25, 0.12) * delta
		puff.scale = Vector3.ONE * (1.0 + age * 2.5)
		var material := puff.material_override as StandardMaterial3D
		material.albedo_color.a = clampf(0.6 - age * 0.45, 0.0, 0.6)
		if age > 1.4:
			puff.visible = false
